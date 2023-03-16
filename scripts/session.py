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

		self.session_id = firstEvent.session_id
		self.user_id = firstEvent.user_id
		self.Events = events
		self.timestamp = firstEvent.timestamp
		self.version = firstEvent.version
		self.version_text = firstEvent.version_text
		self.is_studio = firstEvent.is_studio

		# Get duration
		self.start_datetime = util.timestamp_to_datetime(firstEvent.timestamp)
		self.finish_datetime = util.timestamp_to_datetime(lastEvent.timestamp)
		self.duration = util.get_seconds_between_datetimes(self.finish_datetime, self.start_datetime)
		self.revenue = 0
		for event in events:
			if "Spending" in event.data:
				spendingData = event.data["Spending"]
				if "Spending" in spendingData:
					self.revenue = max(self.revenue, spendingData["Spending"])

		self.index = -1
	
	def __lt__(self, other):
		t1 = self.start_datetime
		t2 = other.start_datetime
		return t1 < t2

	def serialize(self):
		return {
			"SESSION_ID": self.session_id,
			"USER_ID": self.user_id,
			"TIMESTAMP": self.timestamp,
			"VERSION": self.version,
			"INDEX": self.index,
			"EVENT_COUNT": len(self.Events),
			"REVENUE": self.revenue,
			"DURATION": self.duration,
		}


def get_survival_rate(sessions: list[Session]) -> float:
	missingEventCount = 0
	foundEventCount = 0
	for session in sessions:
		for event in session.Events:
			foundEventCount += 1
			if event.is_sequential == False:
				highestPriorEvent = None
				for previous in session.Events:
					if highestPriorEvent == None and previous.index < event.index:
						highestPriorEvent = previous
					elif highestPriorEvent != None and highestPriorEvent.index < previous.index and previous.index < event.index:
						highestPriorEvent = previous

				if highestPriorEvent != None:
					missingEventCount += event.index - highestPriorEvent.index - 1
	totalEventCount = missingEventCount + foundEventCount
			
	return foundEventCount / max(totalEventCount, 1)

def get_sessions_from_events(events: list[Event]) -> list[Event]:
	session_events: dict[str, list[Event]] = {}

	for event in events:
		if not event.session_id in session_events:
			session_events[event.session_id] = []

		session_events[event.session_id].append(event)		
		
	sessions: list[Session] = []
	for sessionId in session_events:
		# print("SiD" + sessionId)
		sessionList = session_events[sessionId]

		if len(sessionList) > 0:
			session = Session(sessionList)
			sessions.append(session)

	userSessionLists: dict[str, list[Session]] = {}
	for session in sessions:
		userId = session.user_id
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
			if current.index == 2:
				previous.first_event_found = True
				previous.is_sequential = True
				current.first_event_found = True
				current.is_sequential = True

			if previous != None:
				current.first_event_found = previous.first_event_found
				if previous.index == current.index - 1:
					current.is_sequential = True
					assert(previous.index == current.index - 1)

					if FILL_DOWN_ENABLED == True:
						if RECURSIVE_FILL_DOWN_ENABLED == False:
							event.fill_down_event_from_previous(previous, current)
						else:
							event.fill_down_events(sessionEventList, current, current.index - 1, 0)
				
	return sessions