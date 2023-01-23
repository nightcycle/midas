from azure.kusto.data.exceptions import KustoServiceError
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder, ClientRequestProperties
from adal import AuthenticationContext
import toml
import json
import requests

def main():
	print("Starting import")

	CLUSTER = "https://insights.playfab.com"

	# These parameters are taken from your Azure app
	CONFIG = toml.load("./auth.toml")["playfab"]
	CLIENT_ID = CONFIG["client_id"]
	CLIENT_SECRET = CONFIG["client_secret"]
	TENANT = CONFIG["tenant"]
	TITLE_ID = CONFIG["title_id"]
	TEST_PERIOD_START = CONFIG["test_start"]
	TEST_DAY_COUNT = CONFIG["test_day_count"]
	AUTH_URL = "https://login.microsoftonline.com/" + TENANT
	context = AuthenticationContext(AUTH_URL)

	# Acquire a token from AAD to pass to PlayFab
	resource = "https://help.kusto.windows.net"

	print("Authenticating")

	token_response = context.acquire_token_with_client_credentials(resource, CLIENT_ID, CLIENT_SECRET)
	token = None
	if token_response:
		if token_response['accessToken']:
			token = token_response['accessToken']

	kcsb = KustoConnectionStringBuilder.with_aad_application_token_authentication(CLUSTER, token)
	client = KustoClient(kcsb)

	def getQuery(index: int, size: int) -> str:
		query = """// run in data explorer
// Used to create a list of relevant sessions"""
		query += "\nlet TEST_PERIOD_START = datetime("+TEST_PERIOD_START+");"
		query +="\nlet TEST_PERIOD_END = datetime_add(\"day\", "+TEST_DAY_COUNT+", TEST_PERIOD_START);"
		query += "\n// Used to reduce the entire dataset into downloadable chunks"
		query += "\nlet USER_START_INDEX = "+str(index)+";"
		query += "\nlet USER_FINISH_INDEX = USER_START_INDEX + "+str(size)+";"
		query += """\n// get a list of join events
let joinEvents = materialize(
['events.all']
| where Timestamp >= TEST_PERIOD_START
| where Timestamp <= TEST_PERIOD_END
| where FullName_Name == "player_logged_in"
| extend USER_ID = tostring(EventData["PlatformUserId"])
| extend Entity_Id = tostring(EventData["EntityId"])
);
// assemble list of sessions
joinEvents
| summarize JOIN_TIMESTAMP = min(Timestamp) by USER_ID
| sort by JOIN_TIMESTAMP
| serialize USER_INDEX = row_number()
| where USER_INDEX > USER_START_INDEX
| where USER_INDEX <= USER_FINISH_INDEX
| join kind=rightsemi joinEvents on USER_ID
| join kind=rightsemi (
	['events.all']
	| where FullName_Namespace != "com.playfab"
	| where Entity_Type == "player"
) on Entity_Id
| extend DATA = EventData["State"]
| where isnotempty(DATA)
| extend ID_DATA = DATA["Id"]
| extend VERSION = tostring(DATA["Version"])
| where isnotempty(VERSION)
| where isnotempty(ID_DATA)
| extend USER_ID = tostring(ID_DATA["User"])
| where isnotempty(USER_ID)
| extend EVENT = FullName_Name
| extend VERSION_TEXT = EventData["Version"]
| extend EVENT_ID = EventData["EventId"]
| extend TIMESTAMP = todatetime(EventData["Timestamp"])
| project-keep TIMESTAMP, EVENT_ID, VERSION_TEXT, VERSION, DATA, EVENT"""
		return query

	# Force Kusto to use the v1 query endpoint
	client._query_endpoint = CLUSTER + "/v1/rest/query"

	crp = ClientRequestProperties()
	crp.application = "KustoPythonSDK"

	def getData(start: int, finish: int):
		print("Importing Users: ", start, finish)
		query = getQuery(start, finish)
		response = client.execute(TITLE_ID, query)

		# Response processing
		result = str(response[0])
		data = json.loads(result)["data"]

		return data

	fullData = []

	global index
	index = 0

	global size
	size = 150

	while True:
		global data
		try:
			data = getData(index, index+size)
			print("LEN", len(data))
			if len(data) <= 0:
				break
			else:
				print("Success")
				fullData.append(data)
				index += size
		except:
			print("Failed")
			size -= 25

	print("Import complete")

	

main()