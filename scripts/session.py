from event import Event
import event
import util
import toml

CONFIG = toml.load("./midas.toml")["format"]

FILL_DOWN_CONFIG = CONFIG["fill_down"]
RECURSIVE_FILL_DOWN_ENABLED = FILL_DOWN_CONFIG["recursive"]
FILL_DOWN_ENABLED = FILL_DOWN_CONFIG["enabled"]

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
		self.StartDateTime = util.timestampToDateTime(firstEvent.Timestamp)
		self.FinishDateTime = util.timestampToDateTime(lastEvent.Timestamp)
		self.Duration = util.getSecondsBetweenDateTimes(self.FinishDateTime, self.StartDateTime)
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

	def serialize(self):
		return {
			"SESSION_ID": self.SessionId,
			"USER_ID": self.UserId,
			"TIMESTAMP": self.Timestamp,
			"VERSION": self.Version,
			"INDEX": self.Index,
			"EVENT_COUNT": len(self.Events),
			"REVENUE": self.Revenue,
			"DURATION": self.Duration,
		}


def getSurvivalRate(sessions: list[Session]) -> float:
	missingEventCount = 0
	foundEventCount = 0
	for session in sessions:
		for event in session.Events:
			foundEventCount += 1
			if event.IsSequential == False:
				highestPriorEvent = None
				for previous in session.Events:
					if highestPriorEvent == None and previous.Index < event.Index:
						highestPriorEvent = previous
					elif highestPriorEvent != None and highestPriorEvent.Index < previous.Index and previous.Index < event.Index:
						highestPriorEvent = previous

				if highestPriorEvent != None:
					missingEventCount += event.Index - highestPriorEvent.Index - 1
	totalEventCount = missingEventCount + foundEventCount
			
	return foundEventCount / max(totalEventCount, 1)

def getSessionsFromEventList(events: list[Event]) -> list[Event]:
	session_events: dict[str, list[Event]] = {}

	for event in events:
		if not event.SessionId in session_events:
			session_events[event.SessionId] = []

		session_events[event.SessionId].append(event)		
		
	sessions: list[Session] = []
	for sessionId in session_events:
		# print("SiD" + sessionId)
		sessionList = session_events[sessionId]

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

	# Sort session events by timestamp
	session_events: dict[str, list[Event]] = {}
	for sessionId in session_events:
		sessionEventList = session_events[sessionId]
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
							event.fillDownEventData(previous, current)
						else:
							event.totalFillDownEventData(sessionEventList, current, current.Index - 1, 0)
				
	return sessions