from session import Session
import datetime
from xmlrpc.client import DateTime

class User:

	def __init__(self, sessions: list[Session]):
		sessions.sort()

		firstSession = sessions[0]

		self.user_id = firstSession.user_id
		self.Sessions = sessions
		self.timestamp = firstSession.timestamp
		self.start_datetime = firstSession.start_datetime

		lastSession = sessions[len(sessions)-1]
		self.last_datetime = lastSession.finish_datetime
		
		self.revenue = 0
		self.duration = 0
	
		index = 0
		for session in sessions:
			index += 1
			session.index = index
			self.revenue += session.revenue
			self.duration += session.duration

		def get_sessions_count_between(start: DateTime, finish: DateTime):
			sessionsBetween = []

			for session in sessions:
				if session.start_datetime >= start and session.start_datetime <= finish:
					sessionsBetween.append(session)

			return sessionsBetween

		def get_retention_status(day: int, threshold: int):
			start = self.start_datetime + datetime.timedelta(days=day)
			finish = start + datetime.timedelta(days=1)
			return len(get_sessions_count_between(start, finish)) > threshold

		self.retained = [
			get_retention_status(0, 1),
			get_retention_status(1, 0),
			get_retention_status(2, 0),	
			get_retention_status(3, 0),	
			get_retention_status(4, 0),	
			get_retention_status(5, 0),
			get_retention_status(6, 0),
			get_retention_status(7, 0),
		]

		self.index = -1

	def __lt__(self, other):
		t1 = self.start_datetime
		t2 = other.start_datetime
		return t1 < t2

	def serialize(self):
		return {
			"USER_ID": self.user_id,
			"TIMESTAMP": self.timestamp,
			"INDEX": self.index,
			"SESSION_COUNT": len(self.Sessions),
			"REVENUE": self.revenue,
			"DURATION": self.duration,
			"D0_RETAINED": self.retained[0],
			"D1_RETAINED": self.retained[1],
			"D2_RETAINED": self.retained[2],
			"D3_RETAINED": self.retained[3],
			"D4_RETAINED": self.retained[4],
			"D5_RETAINED": self.retained[5],
			"D6_RETAINED": self.retained[6],
			"D7_RETAINED": self.retained[7],		
		}

def get_users_from_session_list(sessions: list[Session]):
	
	userSessionLists: dict[str, list[Session]] = {}
	for session in sessions:
		userId = session.user_id
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
		user.index = userIndex

	return users