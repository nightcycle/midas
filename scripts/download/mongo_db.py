# download mongoexport.exe from here https://www.mongodb.com/docs/database-tools/mongoexport/
# you'll need to create an app under app-services, that will provide you with a bot username and password to use.
# this script exports a table as a .json file
# I personally recommend converting it to another format, like an SQLite compatible .db, however you do you
import os
import json

# for simple mass downloading of data
def download(
	mongo_export_exe_path: str, # local path to your mongoexport.exe
	out_json_path: str, # local path to where it will write the file
	database_name: str, # name of the database on mongodb
	collection_name: str, # name of the collection on mongodb
	mongo_app_bot_username: str, #name of the app bot user you've created to download data
	mongo_app_bot_password: str, #password of the app bot user you've created to download data
	mongo_db_url: str # the url provided in the example for  under the example "data import and export tools", something like `"db-name.abcdef.mongodb.net"
):

	command_tags = [
		os.path.abspath(mongo_export_exe_path),
		f"--uri mongodb+srv://{mongo_app_bot_username}:{mongo_app_bot_password}@{mongo_db_url}/{database_name}",
		f"--collection {collection_name}",
		f"--out {out_json_path}"
	]
	command = " ".join(command_tags)
	os.system(command)

	data = []
	with open(out_json_path, "r", encoding='utf-8') as json_file:
		content = json_file.read()
		for line in content.splitlines():
			entry = json.loads(line)
			data.append(entry)

	with open(out_json_path, "w") as json_write_file:
		json_write_file.write(json.dumps(data, indent=5))
