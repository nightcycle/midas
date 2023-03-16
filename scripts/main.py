from cv2 import exp
from more_itertools import first
from session import Session
from event import Event
from user import User
import toml
import util
import importer

CONFIG = toml.load("./midas.toml")["format"]
OUTPUT_CONFIG = CONFIG["output"]
OUTPUT_PATH = OUTPUT_CONFIG["path"]
OUTPUT_KPI_PATH = OUTPUT_PATH + "/kpi"
OUTPUT_EVENTS_PATH = OUTPUT_PATH + "/event"

# Assemble data
events, sessions, users = importer.deserialize()

# export
print("Constructing event table")
categories = []
for event in events:
	if not event.category in categories:
		categories.append(event.category)

for category in categories:
	category_events = []

	for event in events:
		if event.category == category:
			category_events.append(event)

	util.export(category_events, OUTPUT_EVENTS_PATH+"/category")
	

print("Constructing session table")
util.export(sessions, OUTPUT_KPI_PATH+"/sessions")

print("Constructing user table")
util.export(users, OUTPUT_KPI_PATH+"/users")

print("Done")

