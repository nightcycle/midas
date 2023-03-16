import pandas
import os
import datetime
import json
from xmlrpc.client import DateTime

SECONDS_IN_DAY = 24 * 60 * 60

def exportToParquet(path: str, data_list: list[dict[any]]):
	tableDataFrame = pandas.DataFrame(data_list)
	tableDataFrame.to_csv(path+".csv")
	tableCSV = pandas.read_csv(path+".csv", low_memory=False)
	tableCSV.to_parquet(path+".parquet", engine="fastparquet")
	os.remove(path+".csv")


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
	elif "+" in timestamp:
		return datetime.datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S%z')
	else:
		return datetime.datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%S')\


def getCell(eventColumnData: dict, columName: str, rowIndex: int):
	return eventColumnData[columName][rowIndex]

def getRowData(eventColumnData: dict, rowIndex: int):
	return json.loads(getCell(eventColumnData, "DATA", rowIndex))

def getRowCategoryData(eventColumnData: dict, rowIndex: int, categoryName: str):
	rowData = getRowData(eventColumnData, rowIndex)
	if categoryName in rowData:
		return rowData[categoryName]
	return {}

def export(objects: list, path: str):
	data_list = []
	for obj in objects:
		data_list.append(obj.serialize())

	exportToParquet(path, data_list)