import toml
import requests
import json
import sys
import time
from lxml import html
from datetime import datetime

GROUP_ID = 4181328
PLACE_ID = 6683160653

RECORDING_INTERVAL = 60 #seconds

AUTH = toml.load("./auth.toml")
RBX_AUTH = AUTH["roblox"]
RBX_AUTH_COOKIE = RBX_AUTH["cookie"]

GAME_URL_PREFIX = "https://www.roblox.com/games/"

session = requests.Session()
session.cookies.update({
	".ROBLOSECURITY": RBX_AUTH_COOKIE
})

def dumpElement(element) -> str:
	return (html.tostring(element)).decode('utf-8')

def recordAds():

	def getAds():

		response = session.get("https://www.roblox.com/develop/groups/"+str(GROUP_ID)+"?Page=ads")

		tree = html.fromstring(response.text)

		ads = []

		for tabl in tree.xpath('//table[@data-ad-type]'):
			# get title
			ad_id = tabl.get("data-item-id")
			ad_type = tabl.get("data-ad-type")
			place_id: int
			ad_title: str
			for title in tabl.xpath('.//td[@colspan="6"]'):
			
				for span in title.xpath(".//span[not(@href) and @class='title']"):
					ad_title = span.text

				for a in title.xpath('.//a[@href]'):
					a_url = a.get("href")
					if GAME_URL_PREFIX in a_url:
						url_end = a_url.replace(GAME_URL_PREFIX, "")
						place_id = int(url_end.split("/")[0])

			# get stats
			clicks: int
			total_clicks: int
			ctr: float
			total_ctr: float
			bid: int
			total_bid: int
			impressions: int
			total_impressions: int
			is_running: bool = len(tabl.xpath("//*[text()='Not running']")) == 0
			for stats in tabl.xpath('.//td[@class="stats-col"]'):
				for div in stats.xpath(".//div[not(@title) and @class='totals-label']"):
					for span in div.xpath(".//span"):
						if "Clicks" in div.text:
							clicks = int(span.text)
						elif "Bid" in div.text:
							bid = int(span.text)
						elif "CTR" in div.text:
							ctr = float(span.text.replace("%", ""))/100
						elif "Impressions" in div.text:
							impressions = int(span.text)

				for div in stats.xpath(".//div[@title and @class='totals-label']"):
					for span in div.xpath(".//span"):
						if "Clicks" in div.text:
							total_clicks = int(span.text)
						elif "Bid" in div.text:
							total_bid = int(span.text)
						elif "CTR" in div.text:
							total_ctr = float(span.text.replace("%", ""))/100
						elif "Impr" in div.text:
							total_impressions = int(span.text)

			ad_data = {
				"Title": ad_title,
				"Id": ad_id,
				"Type": ad_type,
				"IsRunning": is_running,
				"Clicks": {
					"Current": clicks,
					"Total": total_clicks,
				},
				"CTR": {
					"Current": ctr,
					"Total": total_ctr,
				},
				"Bid": {
					"Current": bid,
					"Total": total_bid,
				},
				"Impressions": {
					"Current": impressions,
					"Total": total_impressions,
				},
				"CPC": {
					"Current": float(bid)/float(max(clicks,1)),
					"Total": float(total_bid)/float(max(total_clicks,1)),
				},
			}
			if PLACE_ID == place_id:
				ads.append(ad_data)

		return ads

	adData = {
		"Timestamp": datetime.now().timestamp(),
		"PlaceId": PLACE_ID,
		"Advertisements":  getAds(),
	}

	file = open("./dashboard/input/marketing/advertisement/"+str(adData["Timestamp"]).replace(".", "_")+".json", "w")
	file.write(json.dumps(adData, indent=4))
	file.close()

index = 0
while True:
	index += 1
	print("Recording #"+str(index))
	
	try:
		recordAds()
	except:
		print("Recording failed")

	time.sleep(RECORDING_INTERVAL)
