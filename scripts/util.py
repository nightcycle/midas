import pandas
import os
import datetime
import json
import data_encoder
from xmlrpc.client import DateTime

SECONDS_IN_DAY = 24 * 60 * 60

def export_to_parquet(path: str, data_list: list[dict[any]]):
	tableDataFrame = pandas.DataFrame(data_list)
	tableDataFrame.to_csv(path+".csv")
	tableCSV = pandas.read_csv(path+".csv", low_memory=False)
	tableCSV.to_parquet(path+".parquet", engine="fastparquet")
	os.remove(path+".csv")


def get_seconds_between_datetimes(finish: DateTime, start: DateTime):
	difference = finish - start
	datetime.timedelta(0, 8, 562000)
	mins, seconds = divmod(difference.days * SECONDS_IN_DAY + difference.seconds, 60)
	return mins * 60 + seconds
	
# define session and user classes
def timestamp_to_datetime(timestamp: str):
	# print(timestamp)
	timestamp = timestamp.replace('Z', '')
	if "." in timestamp:
		return datetime.datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S.%f%z')
	elif "+" in timestamp:
		return datetime.datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S%z')
	else:
		return datetime.datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%S')\


def get_cell(eventColumnData: dict, columName: str, rowIndex: int):
	return eventColumnData[columName][rowIndex]

def get_row_data(eventColumnData: dict, rowIndex: int):
	return data_encoder.decode(json.loads(get_cell(eventColumnData, "DATA", rowIndex)))

def get_row_category_data(eventColumnData: dict, rowIndex: int, categoryName: str):
	rowData = get_row_data(eventColumnData, rowIndex)
	if categoryName in rowData:
		return rowData[categoryName]
	return {}

def export(objects: list, path: str):
	data_list = []
	for obj in objects:
		data_list.append(obj.serialize())

	export_to_parquet(path, data_list)