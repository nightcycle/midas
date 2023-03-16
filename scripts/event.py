import util
import re
import os
import copy
import json
import pandas

class Event: 

	def __init__(self, name: str, sessionId: str, userId: str, placeId: str, index: int, eventId: str, timestamp: str, versionText: str, isStudio: bool, version: dict[str, int | str], data: dict[str, any]):
		catBase = name.replace('User', '')
		m = re.search(r'^([^A-Z]*[A-Z]){2}', catBase);
		nxtCap = m.span()[1] or len(catBase)

		self.SessionId = sessionId
		self.Name = name
		self.Category = catBase[0:(nxtCap-1)]
		self.UserId = userId
		self.PlaceId = placeId
		self.Index = index
		self.EventId = eventId
		self.IsStudio = isStudio
		self.Timestamp = timestamp
		self.VersionText = versionText
		self.Version = version
		self.FirstEventFound = False
		self.Data = data
		self.IsSequential = False

	def __lt__(self, other):
		t1 = self.Index
		t2 = other.Index
		return t1 < t2


	def serialize(self):
		# print("EL", event.SankeyLabel, "ED", event.SankeyDestination)
		rowFinal = {
			"SESSION_ID": self.SessionId,
			"EVENT": self.Name,
			"CATEGORY": self.Category,
			"USER_ID": self.UserId,
			"PLACE_ID": self.PlaceId,
			"EVENT_ID": self.EventId,
			"TIMESTAMP": self.Timestamp,
			"VERSION.TEXT": self.VersionText,
			"VERSION.MAJOR": self.Version["Major"],
			"VERSION.MINOR": self.Version["Minor"],
			"VERSION.PATCH": self.Version["Patch"],
			"VERSION.BUILD": self.Version["Build"],
			"FIRST_EVENT_FOUND": self.FirstEventFound,
			"IS_STUDIO": self.IsStudio,
			"INDEX": self.Index,
			"IS_SEQUENTIAL": self.IsSequential
		}

		if "Hotfix" in self.Version:
			rowFinal["VERSION.HOTFIX"] = self.Version["Hotfix"]

		if "Tag" in self.Version:
			rowFinal["VERSION.TAG"] = self.Version["Tag"]

		if "TestGroup" in self.Version:
			rowFinal["VERSION.TEST_GROUP"] = self.Version["TestGroup"]

		return rowFinal
		

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

	for key in previous.Data:
		val = previous.Data[key]
		if not key in current.Data:
			current.Data[key] = {}

		if type(val) == dict:
			current.Data[key] = fillDown(current.Data[key], previous.Data[key])

def totalFillDownEventData(sessionEventList: list[Event], current: Event, targetIndex: int, depth: int):
	depth += 1
	if depth > 100:
		return

	for previous in sessionEventList:
		if previous.Index == targetIndex:
			fillDownEventData(previous, current)
			break
	if targetIndex > 1:
		totalFillDownEventData(sessionEventList, current, targetIndex-1, depth)

def flattenTable(all_event_data: dict[str, dict], columnPrefix: str, row_data: dict):
	for key in all_event_data:
		val = all_event_data[key]
		if type(val) == dict:
			flattenTable(val, columnPrefix+key+".", row_data)
		else:
			all_event_data[(columnPrefix+key).upper()] = val

def getEventsFromCSVs(csv_directory: str) -> list[Event]:
	events: list[Event] = []
	
	for export in os.listdir(csv_directory):
		eventSource = pandas.read_csv(csv_directory+"/"+export)
		eventColumnData = {}

		for col in eventSource.columns:
			eventColumnData[col] = eventSource[col].tolist()


		def getRowCategoryDataValue(rowIndex: int, categoryName: str, keyName: str):
			categoryData = util.getRowCategoryData(eventColumnData,rowIndex, categoryName)
			if keyName in categoryData:
				return categoryData[keyName]
			return None

		for index in eventSource.index.values:
			userId = getRowCategoryDataValue(index, "Id", "User")
			sessionId = getRowCategoryDataValue(index, "Id", "Session")

			if type(getRowCategoryDataValue(index, "Index", "Total")) == int:
				event = Event(
					sessionId = sessionId,
					name = util.getCell(eventColumnData,"EVENT", index),
					userId = userId,
					placeId = getRowCategoryDataValue(index, "Id", "Place"),
					index = getRowCategoryDataValue(index, "Index", "Total"),
					isStudio = util.getRowCategoryData(eventColumnData,index, "IsStudio"),
					eventId = util.getCell(eventColumnData,"EVENT_ID", index),
					timestamp = util.getCell(eventColumnData,"TIMESTAMP", index),
					versionText = util.getCell(eventColumnData,"VERSION_TEXT", index),
					version = json.loads(util.getCell(eventColumnData,"VERSION", index)),
					data = util.getRowData(eventColumnData, index) or {},
				)
				events.append(event)

	return events