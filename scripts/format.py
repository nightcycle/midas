from xmlrpc.client import DateTime
from cv2 import exp
from more_itertools import first
import pandas
import fastparquet
import os
import json
import copy
import toml
import datetime
import re

CONFIG = toml.load("./midas.toml")["format"]

FILL_DOWN_CONFIG = CONFIG["fill_down"]
RECURSIVE_FILL_DOWN_ENABLED = FILL_DOWN_CONFIG["recursive"]
FILL_DOWN_ENABLED = FILL_DOWN_CONFIG["enabled"]

INPUT_CONFIG = CONFIG["input"]
INPUT_PATH = INPUT_CONFIG["path"]
INPUT_EVENTS_PATH = INPUT_PATH + "/event"

OUTPUT_CONFIG = CONFIG["output"]
OUTPUT_PATH = OUTPUT_CONFIG["path"]
OUTPUT_EVENTS_PATH = OUTPUT_PATH + "/event"
OUTPUT_KPI_PATH = OUTPUT_PATH + "/kpi"

SECONDS_IN_DAY = 24 * 60 * 60

eventExports = os.listdir(INPUT_EVENTS_PATH)

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
		self.SankeyLabel = ""
		self.SankeyDestination = ""
		self.FirstEventFound = False
		self.Data = data
		self.IsSequential = False

	def __lt__(self, other):
		t1 = self.Index
		t2 = other.Index
		return t1 < t2

userEventLists: dict[str, list[Event]] = {}
sessionEventLists: dict[str, list[Event]] = {}
eventRegistry: dict[str, Event] = {}
userIds = []

# Assemble session event series lists
print("Assembling event lists")
sessionCount = 0
userCount = 0


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


def flattenTable(data: dict[str, any], columnPrefix: str, row: dict[str, any]):
	for key in data:
		val = data[key]
		if type(val) == dict:
			flattenTable(val, columnPrefix+key+".", row)
		else:
			row[(columnPrefix+key).upper()] = val

def exportToParquet(path: str, dataList: list[dict[any]]):
	tableDataFrame = pandas.DataFrame(dataList)
	tableDataFrame.to_csv(path+".csv")
	tableCSV = pandas.read_csv(path+".csv", low_memory=False)
	tableCSV.to_parquet(path+".parquet", engine="fastparquet")

def getRowFromEvent(event: Event, data: dict[str, any] | None):
	# print("EL", event.SankeyLabel, "ED", event.SankeyDestination)
	rowFinal = {
		"SESSION_ID": event.SessionId,
		"EVENT": event.Name,
		"CATEGORY": event.Category,
		"USER_ID": event.UserId,
		"PLACE_ID": event.PlaceId,
		"EVENT_ID": event.EventId,
		"TIMESTAMP": event.Timestamp,
		"VERSION.TEXT": event.VersionText,
		"VERSION.MAJOR": event.Version["Major"],
		"VERSION.MINOR": event.Version["Minor"],
		"VERSION.PATCH": event.Version["Patch"],
		"VERSION.BUILD": event.Version["Build"],
		"FIRST_EVENT_FOUND": event.FirstEventFound,
		"SANKEY_LABEL": event.SankeyLabel,
		"SANKEY_DESTINATION": event.SankeyDestination,
		"IS_STUDIO": event.IsStudio,
		"INDEX": event.Index,
		"IS_SEQUENTIAL": event.IsSequential
	}

	if "Hotfix" in event.Version:
		rowFinal["VERSION.HOTFIX"] = event.Version["Hotfix"]

	if "Tag" in event.Version:
		rowFinal["VERSION.TAG"] = event.Version["Tag"]

	if "TestGroup" in event.Version:
		rowFinal["VERSION.TEST_GROUP"] = event.Version["TestGroup"]

	if data != None:
		flattenTable(data, "", rowFinal)

	return rowFinal
	
def createTable(category: str):
	print("Constructing "+category)

	dataList = []
	for sessionId in sessionEventLists:
		sessionEventList = sessionEventLists[sessionId]
		for event in sessionEventList:
			# print(event.Category.upper(), ":", event.Index)
			# if event.Category.upper() == category.upper():
			if category in event.Data and event.Data[category] != None:
				dataList.append(getRowFromEvent(event, event.Data[category]))
			else:
				dataList.append(getRowFromEvent(event, None))

	exportToParquet(OUTPUT_EVENTS_PATH+"/"+category.lower(), dataList)

#Assemble state categories from data
dataCategoriesStorage = {}

for export in eventExports:
	print("Importing "+str(export))
	eventSource = pandas.read_csv(INPUT_EVENTS_PATH+"/"+export)

	for datastring in eventSource["DATA"]:
		data = json.loads(datastring)

		for k in data:
			if k != "Id" and k != "Version" and k != "IsStudio":
				v = data[k]
				if type(v) == dict:
					dataCategoriesStorage[k] = True

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

	for index in eventSource.index.values:
		userId = getRowCategoryDataValue(index, "Id", "User")
		userIds.append(userId)
		sessionId = getRowCategoryDataValue(index, "Id", "Session")
		if sessionId != None:

			if not userId in userEventLists:
				userCount += 1
				userEventLists[userId] = []

			if not sessionId in sessionEventLists:
				sessionCount += 1
				sessionEventLists[sessionId] = []

			sessionEventList = sessionEventLists[sessionId]
			userEventList = userEventLists[userId]
			# Package up an event
			if type(getRowCategoryDataValue(index, "Index", "Total")) == int:
				event = Event(
					sessionId = sessionId,
					name = getCell("EVENT", index),
					userId = userId,
					placeId = getRowCategoryDataValue(index, "Id", "Place"),
					index = getRowCategoryDataValue(index, "Index", "Total"),
					isStudio = getRowCategoryData(index, "IsStudio"),
					eventId = getCell("EVENT_ID", index),
					timestamp = getCell("TIMESTAMP", index),
					versionText = getCell("VERSION_TEXT", index),
					version = json.loads(getCell("VERSION", index)),
					data = getRowData(index) or {},
				)
				# print("INDX", event.Index)
				if not event.EventId in eventRegistry:
					eventRegistry[event.EventId] = event
					sessionEventList.append(event)
					userEventList.append(event)
				# Update registry
				sessionEventLists[sessionId] = sessionEventList

userIds = list(dict.fromkeys(userIds))

print("USER COUNT", len(userIds))
print("SESSION COUNT", sessionCount)



print("Validating and organizing event data")
# Sort session events by timestamp
for sessionId in sessionEventLists:
	sessionEventList = sessionEventLists[sessionId]
	# print("Formatting session: "+str(sessionId))
	sessionEventList.sort()
	for previous, current in zip(sessionEventList, sessionEventList[1:]):
		if current.Index == 2:
			previous.FirstEventFound = True
			previous.IsSequential = True
			current.FirstEventFound = True
			current.IsSequential = True

		if previous != None:
			current.FirstEventFound = previous.FirstEventFound
			if previous.Index == current.Index - 1:
				current.IsSequential = True
				assert(previous.Index == current.Index - 1)

				if FILL_DOWN_ENABLED == True:
					if RECURSIVE_FILL_DOWN_ENABLED == False:
						fillDownEventData(previous, current)
					else:
						totalFillDownEventData(sessionEventList, current, current.Index - 1, 0)
				
				if current.Category != "Issues":
					# rep = 0
					# for prevRepEvent in sessionEventList:
					# 	if prevRepEvent.Name == current.Name and prevRepEvent.Index < current.Index and prevRepEvent.Category == current.Category:
					# 		rep += 1
				
					current.SankeyLabel = current.Name #+ str(rep)
					# print(current.SankeyLabel)
	if current.Category != "Issues":
		for event in sessionEventList:
			dest: Event | None = None
			for nxt in sessionEventList:
				if nxt.Index > event.Index:
					if dest != None:
						if dest.Index > nxt.Index:
							dest = nxt
					else:
						dest = nxt

			if dest != None:
				event.SankeyDestination = dest.SankeyLabel


dataCategories = []
for k in dataCategoriesStorage:
	dataCategories.append(k)

for category in dataCategories:
	createTable(category)

# Calculate survival rate
missingEventCount = 0
foundEventCount = 0
for sessionId in sessionEventLists:

	sessionEventList = sessionEventLists[sessionId]
	for event in sessionEventList:
		foundEventCount += 1
		if event.IsSequential == False:
			highestPriorEvent = None
			for previous in sessionEventList:
				if highestPriorEvent == None and previous.Index < event.Index:
					highestPriorEvent = previous
				elif highestPriorEvent != None and highestPriorEvent.Index < previous.Index and previous.Index < event.Index:
					highestPriorEvent = previous

			if highestPriorEvent != None:
				missingEventCount += event.Index - highestPriorEvent.Index - 1
totalEventCount = missingEventCount + foundEventCount
		
eventSuccessRate = foundEventCount / max(totalEventCount, 1)

print("Event Survival Rate: "+str(round(eventSuccessRate*1000)/10)+"%")

def getSecondsBetweenDateTimes(finish: DateTime, start: DateTime):
	difference = finish - start
	datetime.timedelta(0, 8, 562000)
	mins, seconds = divmod(difference.days * SECONDS_IN_DAY + difference.seconds, 60)
	return mins * 60 + seconds
	
# define session and user classes
def timestampToDateTime(timestamp: str):
	# print(timestamp)
	timestamp = timestamp.replace('Z', '')
	if "." in timestamp:
		return datetime.datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S.%f%z')
	else:
		return datetime.datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%S')\

class Session: 

	def __init__(self, events: list[Event]):
		firstEvent = events[0]
		lastEvent = events[len(events)-1]

		self.SessionId = firstEvent.SessionId
		self.UserId = firstEvent.UserId
		self.Events = events
		self.Timestamp = firstEvent.Timestamp
		self.Version = firstEvent.Version
		self.VersionText = firstEvent.VersionText
		self.IsStudio = firstEvent.IsStudio

		# Get duration
		self.StartDateTime = timestampToDateTime(firstEvent.Timestamp)
		self.FinishDateTime = timestampToDateTime(lastEvent.Timestamp)
		self.Duration = getSecondsBetweenDateTimes(self.FinishDateTime, self.StartDateTime)
		self.Revenue = 0
		for event in events:
			if "Spending" in event.Data:
				spendingData = event.Data["Spending"]
				if "Spending" in spendingData:
					self.Revenue = max(self.Revenue, spendingData["Spending"])

		self.Index = -1
	
	def __lt__(self, other):
		t1 = self.StartDateTime
		t2 = other.StartDateTime
		return t1 < t2


class User:

	def __init__(self, sessions: list[Session]):
		sessions.sort()

		firstSession = sessions[0]

		self.UserId = firstSession.UserId
		self.Sessions = sessions
		self.Timestamp = firstSession.Timestamp
		self.StartDateTime = firstSession.StartDateTime

		lastSession = sessions[len(sessions)-1]
		self.LastDateTime = lastSession.FinishDateTime
		
		self.Revenue = 0
		self.Duration = 0
	
		index = 0
		for session in sessions:
			index += 1
			session.Index = index
			self.Revenue += session.Revenue
			self.Duration += session.Duration

		def getSessionsCountBetween(start: DateTime, finish: DateTime):
			sessionsBetween = []

			for session in sessions:
				if session.StartDateTime >= start and session.StartDateTime <= finish:
					sessionsBetween.append(session)

			return sessionsBetween

		def getRetentionStatus(day: int, threshold: int):
			start = self.StartDateTime + datetime.timedelta(days=day)
			finish = start + datetime.timedelta(days=1)
			return len(getSessionsCountBetween(start, finish)) > threshold

		self.Retained = [
			getRetentionStatus(0, 1),
			getRetentionStatus(1, 0),
			getRetentionStatus(2, 0),	
			getRetentionStatus(3, 0),	
			getRetentionStatus(4, 0),	
			getRetentionStatus(5, 0),
			getRetentionStatus(6, 0),
			getRetentionStatus(7, 0),
		]

		self.Index = -1

	def __lt__(self, other):
		t1 = self.StartDateTime
		t2 = other.StartDateTime
		return t1 < t2

print("Constructing session objects")
sessions: list[Session] = []
for sessionId in sessionEventLists:
	# print("SiD" + sessionId)
	sessionList = sessionEventLists[sessionId]

	if len(sessionList) > 0:
		session = Session(sessionList)
		sessions.append(session)

userSessionLists: dict[str, list[Session]] = {}
for session in sessions:
	userId = session.UserId
	if not userId in userSessionLists:
		userSessionLists[userId] = []

	userSessionList = userSessionLists[userId]
	userSessionList.append(session)

print("Constructing user objects")
users: list[User] = []
for userId in userSessionLists:
	users.append(User(userSessionLists[userId]))

users.sort()

userIndex = 0
for user in users:
	userIndex += 1
	user.Index = userIndex

# create user and session tables
print("Constructing session table")

sessionDataList = []
for session in sessions:

	rowFinal = {
		"SESSION_ID": session.SessionId,
		"USER_ID": session.UserId,
		"TIMESTAMP": session.Timestamp,
		"VERSION": session.Version,
		"INDEX": session.Index,
		"EVENT_COUNT": len(session.Events),
		"REVENUE": session.Revenue,
		"DURATION": session.Duration,
	}

	sessionDataList.append(rowFinal)

exportToParquet(OUTPUT_KPI_PATH+"/sessions", sessionDataList)

print("Constructing user table")

userDataList = []
for user in users:

	rowFinal = {
		"USER_ID": user.UserId,
		"TIMESTAMP": user.Timestamp,
		"INDEX": user.Index,
		"SESSION_COUNT": len(user.Sessions),
		"REVENUE": user.Revenue,
		"DURATION": user.Duration,
		"D0_RETAINED": user.Retained[0],
		"D1_RETAINED": user.Retained[1],
		"D2_RETAINED": user.Retained[2],
		"D3_RETAINED": user.Retained[3],
		"D4_RETAINED": user.Retained[4],
		"D5_RETAINED": user.Retained[5],
		"D6_RETAINED": user.Retained[6],
		"D7_RETAINED": user.Retained[7],		
	}

	userDataList.append(rowFinal)

exportToParquet(OUTPUT_KPI_PATH+"/users", userDataList)

# experience table

#


print("Done")
# eventSource.to_parquet(OUTPUT_EVENTS_PATH+'/main.parquet', engine='fastparquet')

