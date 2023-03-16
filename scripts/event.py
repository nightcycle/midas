import util
import re
import os
import copy
import json
import pandas

class Event: 

	def __init__(self, name: str, session_id: str, user_id: str, place_id: str, index: int, event_id: str, timestamp: str, version_text: str, isStudio: bool, version: dict[str, int | str], data: dict[str, any]):
		catBase = name.replace('User', '')
		m = re.search(r'^([^A-Z]*[A-Z]){2}', catBase);
		nxt_cap = m.span()[1] or len(catBase)

		self.session_id = session_id
		self.name = name
		self.category = catBase[0:(nxt_cap-1)]
		self.user_id = user_id
		self.place_id = place_id
		self.index = index
		self.event_id = event_id
		self.is_studio = isStudio
		self.timestamp = timestamp
		self.version_text = version_text
		self.version = version
		self.first_event_found = False
		self.data = data
		self.is_sequential = False

	def __lt__(self, other):
		t1 = self.index
		t2 = other.index
		return t1 < t2


	def serialize(self):
		# print("EL", event.SankeyLabel, "ED", event.SankeyDestination)
		rowFinal = {
			"SESSION_ID": self.session_id,
			"EVENT": self.name,
			"CATEGORY": self.category,
			"USER_ID": self.user_id,
			"PLACE_ID": self.place_id,
			"EVENT_ID": self.event_id,
			"TIMESTAMP": self.timestamp,
			"VERSION.TEXT": self.version_text,
			"VERSION.MAJOR": self.version["Major"],
			"VERSION.MINOR": self.version["Minor"],
			"VERSION.PATCH": self.version["Patch"],
			"VERSION.BUILD": self.version["Build"],
			"FIRST_EVENT_FOUND": self.first_event_found,
			"IS_STUDIO": self.is_studio,
			"INDEX": self.index,
			"IS_SEQUENTIAL": self.is_sequential
		}

		if "Hotfix" in self.version:
			rowFinal["VERSION.HOTFIX"] = self.version["Hotfix"]

		if "Tag" in self.version:
			rowFinal["VERSION.TAG"] = self.version["Tag"]

		if "TestGroup" in self.version:
			rowFinal["VERSION.TEST_GROUP"] = self.version["TestGroup"]

		return rowFinal
		

# fill down event data when previous index is available
def fill_down_event_from_previous(previous: Event, current: Event): 

	def fill_down(curData: dict[str, any], prevData: dict[str, any]):
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
				fill_down(curData[key], prevData[key])
			else:
				curData[key] = val

		return curData

	for key in previous.data:
		val = previous.data[key]
		if not key in current.data:
			current.data[key] = {}

		if type(val) == dict:
			current.data[key] = fill_down(current.data[key], previous.data[key])

def fill_down_events(session_events: list[Event], current: Event, targetIndex: int, depth: int):
	depth += 1
	if depth > 100:
		return

	for previous in session_events:
		if previous.index == targetIndex:
			fill_down_event_from_previous(previous, current)
			break
	if targetIndex > 1:
		fill_down_events(session_events, current, targetIndex-1, depth)

def flatten_table(all_event_data: dict[str, dict], column_prefix: str, row_data: dict):
	for key in all_event_data:
		val = all_event_data[key]
		if type(val) == dict:
			flatten_table(val, column_prefix+key+".", row_data)
		else:
			all_event_data[(column_prefix+key).upper()] = val

def get_events_from_csv_folder(csv_directory: str) -> list[Event]:
	events: list[Event] = []
	
	for export in os.listdir(csv_directory):
		eventSource = pandas.read_csv(csv_directory+"/"+export)
		eventColumnData = {}

		for col in eventSource.columns:
			eventColumnData[col] = eventSource[col].tolist()


		def get_row_category_data_value(rowIndex: int, categoryName: str, keyName: str):
			categoryData = util.get_row_category_data(eventColumnData,rowIndex, categoryName)
			if keyName in categoryData:
				return categoryData[keyName]
			return None

		for index in eventSource.index.values:
			user_id = get_row_category_data_value(index, "Id", "User")
			session_id = get_row_category_data_value(index, "Id", "Session")

			if type(get_row_category_data_value(index, "Index", "Total")) == int:
				event = Event(
					session_id = session_id,
					name = util.get_cell(eventColumnData,"EVENT", index),
					user_id = user_id,
					place_id = get_row_category_data_value(index, "Id", "Place"),
					index = get_row_category_data_value(index, "Index", "Total"),
					isStudio = util.get_row_category_data(eventColumnData,index, "IsStudio"),
					event_id = util.get_cell(eventColumnData,"EVENT_ID", index),
					timestamp = util.get_cell(eventColumnData,"TIMESTAMP", index),
					version_text = util.get_cell(eventColumnData,"VERSION_TEXT", index),
					version = json.loads(util.get_cell(eventColumnData,"VERSION", index)),
					data = util.get_row_data(eventColumnData, index) or {},
				)
				events.append(event)

	return events