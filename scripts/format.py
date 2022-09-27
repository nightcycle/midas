from asyncore import write
from email import header
from sqlite3 import Date
import numpy
import pandas
import fastparquet
import os
import json
import copy

INPUT_PATH = "./dashboard/input"
INPUT_EVENTS_PATH = INPUT_PATH + "/events"
OUTPUT_PATH = "./dashboard/output"
OUTPUT_EVENTS_PATH = OUTPUT_PATH + "/events"

eventExports = os.listdir(INPUT_EVENTS_PATH)

eventSources = []
for export in eventExports:
	eventSources.append(pandas.read_csv(INPUT_EVENTS_PATH+"/"+export))

eventSource = pandas.concat(eventSources)

# Caches column data for later reference
eventColumnData = {}
for col in eventSource.columns:
	eventColumnData[col] = eventSource[col].tolist()

def getCell(columName: str, rowIndex: int):
	return eventColumnData[columName][rowIndex]

def getRowData(rowIndex: int):
	return json.loads(getCell("DATA", rowIndex))

def getRowCategoryData(rowIndex: int, categoryName: str):
	rowData = getRowData(rowIndex)
	if categoryName in rowData:
		return rowData[categoryName]
	return {}

def getRowCategoryDataValue(rowIndex: int, categoryName: str, keyName: str):
	categoryData = getRowCategoryData(rowIndex, categoryName)
	if keyName in categoryData:
		return categoryData[keyName]
	return None

class Event: 

	def __init__(self, sessionId: str, userId: str, placeId: str, index: int, eventId: str, timestamp: str, version: str, data: dict[str, any]):
		self.SESSION_ID = sessionId
		self.USER_ID = userId
		self.PLACE_ID = placeId
		self.INDEX = index
		self.EVENT_ID = eventId
		self.TIMESTAMP = timestamp
		self.VERSION = version
		self.DATA = data
		self.IS_SEQUENTIAL = False
	
	def __lt__(self, other):
		t1 = self.INDEX
		t2 = other.INDEX
		return t1 < t2

sessionEventLists: dict[str, list[Event]] = {}
eventRegistry: dict[str, Event] = {}

# Assemble session event series lists
for index in eventSource.index.values:
	sessionId = getRowCategoryDataValue(index, "Id", "Session")
	if sessionId != None:

		if not sessionId in sessionEventLists:
			sessionEventLists[sessionId] = []

		sessionEventList = sessionEventLists[sessionId]

		# Package up an event
		event = Event(
			sessionId = sessionId,
			userId = getRowCategoryDataValue(index, "Id", "User"),
			placeId = getRowCategoryDataValue(index, "Id", "Place"),
			index = getRowCategoryDataValue(index, "Index", "Total"),
			eventId = getCell("EVENT_ID", index),
			timestamp = getCell("TIMESTAMP", index),
			version = getCell("VERSION", index),
			data = getRowData(index) or {},
		)
		if not event.EVENT_ID in eventRegistry:
			eventRegistry[event.EVENT_ID] = event
			sessionEventList.append(event)

		# Update registry
		sessionEventLists[sessionId] = sessionEventList

# fill down event data when previous index is available
def fillDownEventData(previous: Event, current: Event): 

	def fillDown(curData: dict[str, any], prevData: dict[str, any]):
		if curData == None:
			curData = {}

		if prevData == None:
			return curData

		for key in prevData:
			val = prevData[key]
			if not key in curData:
				curData[key] = copy.deepcopy(prevData[key])

				return curData

			if type(val) == dict:
				fillDown(curData[key], prevData[key])
			else:
				curData[key] = val

		return curData

	for key in current.DATA:
		val = current.DATA[key]
		if type(val) == dict and key in previous.DATA:
			current.DATA[key] = fillDown(current.DATA[key], previous.DATA[key])

def totalFillDownEventData(sessionEventList: list[Event], current: Event, targetIndex: int):
	for previous in sessionEventList:
		if previous.INDEX == targetIndex:
			fillDownEventData(previous, current)
			if targetIndex > 0:
				totalFillDownEventData(sessionEventList, current, targetIndex-1)
				return


# Sort session events by timestamp
for sessionId in sessionEventLists:
	sessionEventList = sessionEventLists[sessionId]
	print("Formatting session: "+str(sessionId))
	sessionEventList.sort()
	for previous, current in zip(sessionEventList, sessionEventList[1:]):
		if current.INDEX == 1:
			current.IS_SEQUENTIAL = True

		if previous != None and previous.INDEX == current.INDEX - 1:
			current.IS_SEQUENTIAL = True
			assert(previous.INDEX == current.INDEX - 1)
			fillDownEventData(previous, current)
			# totalFillDownEventData(sessionEventList, current, current.INDEX - 1)


def flattenTable(data: dict[str, any], columnPrefix: str, row: dict[str, any]):
	for key in data:
		val = data[key]
		if type(val) == dict:
			flattenTable(val, columnPrefix+key+".", row)
		else:
			row[(columnPrefix+key).upper()] = val

def createTable(category: str):
	print("Constructing "+category)
	dataList = []
	for sessionId in sessionEventLists:
		sessionEventList = sessionEventLists[sessionId]
		for event in sessionEventList:
			rowFinal = {
				"SESSION_ID": event.SESSION_ID,
				"USER_ID": event.USER_ID,
				"PLACE_ID": event.PLACE_ID,
				"EVENT_ID": event.EVENT_ID,
				"TIMESTAMP": event.TIMESTAMP,
				"VERSION": event.VERSION,
				"INDEX": event.INDEX,
				"IS_SEQUENTIAL": event.IS_SEQUENTIAL
			}

			if category in event.DATA and event.DATA[category] != None:
				flattenTable(event.DATA[category], "", rowFinal)

			dataList.append(rowFinal)

	tableDataFrame = pandas.DataFrame(dataList)
	tablePath = OUTPUT_EVENTS_PATH+"/"+category.lower()

	tableDataFrame.to_csv(tablePath+".csv")
	tableCSV = pandas.read_csv(tablePath+".csv")
	tableCSV.to_parquet(tablePath+".parquet", engine="fastparquet")

#Assemble state categories from data
dataCategoriesStorage = {}
for datastring in eventSource["DATA"]:

	data = json.loads(datastring)

	for k in data:
		if k != "Id":
			v = data[k]
			if type(v) == dict:
				dataCategoriesStorage[k] = True

dataCategories = []
for k in dataCategoriesStorage:
	dataCategories.append(k)

for category in dataCategories:
	createTable(category)

missingEventCount = 0
foundEventCount = 0
for sessionId in sessionEventLists:

	sessionEventList = sessionEventLists[sessionId]
	for event in sessionEventList:
		foundEventCount += 1
		if event.IS_SEQUENTIAL == False:
			highestPriorEvent = None
			for previous in sessionEventList:
				if highestPriorEvent == None and previous.INDEX < event.INDEX:
					highestPriorEvent = previous
				elif highestPriorEvent != None and highestPriorEvent.INDEX < previous.INDEX and previous.INDEX < event.INDEX:
					highestPriorEvent = previous

			if highestPriorEvent != None:
				missingEventCount += event.INDEX - highestPriorEvent.INDEX - 1
totalEventCount = missingEventCount + foundEventCount
		
eventSuccessRate = foundEventCount / totalEventCount

print("Event Survival Rate: "+str(round(eventSuccessRate*1000)/10)+"%")

print("Done")
# eventSource.to_parquet(OUTPUT_EVENTS_PATH+'/main.parquet', engine='fastparquet')

