from session import Session
import datetime
from xmlrpc.client import DateTime

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

	def serialize(self):
		return {
			"USER_ID": self.UserId,
			"TIMESTAMP": self.Timestamp,
			"INDEX": self.Index,
			"SESSION_COUNT": len(self.Sessions),
			"REVENUE": self.Revenue,
			"DURATION": self.Duration,
			"D0_RETAINED": self.Retained[0],
			"D1_RETAINED": self.Retained[1],
			"D2_RETAINED": self.Retained[2],
			"D3_RETAINED": self.Retained[3],
			"D4_RETAINED": self.Retained[4],
			"D5_RETAINED": self.Retained[5],
			"D6_RETAINED": self.Retained[6],
			"D7_RETAINED": self.Retained[7],		
		}

def getUsersFromSessionList(sessions: list[Session]):
	
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

	return users