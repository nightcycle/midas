---
sidebar_position: 3
---

# PlayFab
In favor of producing a more accessible framework that doesn't require 3 hours of debugging cloud APIs for each user, we've gone with a more low-tech manual method for retrieving data from PlayFab. The basic plan is that we'll be running a KQL script in the PlayFab data explorer, then exporting the data as a CSV.

## Why PlayFab?
The online service PlayFab will allow you [100,000 users worth of data-storage for free per game](https://playfab.com/pricing/). You're welcome to shop-around for better options, but it is in my experience more than adequate for kickstarting a new game. If you have an established game with larger a larger audience, they offer a pay-as-you-go option, and at $99 a month the amount of players that can be stored becomes unlimited.

## I don't want to use PlayFab
Alright, all you technicall need is a CSV of data that meets this format:
```csv
"DATA","TIMESTAMP","VERSION","VERSION_TEXT","EVENT_ID", "EVENT",
```
The header order doesn't matter. Here's what needs to be under each column
- DATA: This should be an encoded JSON table provided in the body of the API post request at "State"
- TIMESTAMP: A string that can be parsed into a DateTime object. For example: "2022-09-28T21:53:49.859Z"
- VERSION: An encoded JSON table provided within the DATA JSON table.
- VERSION_TEXT: A readable version string provided at key "Version" in the API post request.
- EVENT_ID: A 32 character string that is unique for each event.
- EVENT: The name of the event fired.

So long as whatever your method in results in a CSV file that fits the above conditions, you do not need to use PlayFab to use this Framework. If there is enough demand for a separate workflow that does this for you (for example, with GameAnalytics), I am not against adding it, I'm just unmotivated at this time.

## Retrieving the Data via PlayFab
This is how you can get your data out of PlayFab after it's been recorded.If you haven't already, first [create an account and a "Title" entity for your game](https://doc.photonengine.com/en-us/bolt/current/demos-and-tutorials/playfab-integration/playfab-101-setup-game-title#:~:text=Login%20or%20create%20a%20new,to%20the%20Game%20Title%20dashboard.). After completing that, go into your new Title's profile and on the menu on the left side at the very bottom click the "Data" button under the "Analyze" category. Once you've done that you will now be looking at the "Data Explorer (basic)". At the top of the page is a tab for "Data Explorer (advanced)". Click that tab, and you'll be taken to one of the most cluttered and temperamental code editing UX I have ever used. 

This is the KQL editor, and you can use it to run KQL code which will output data at the bottom. First, copy the text in the [export.kql](https://github.com/nightcycle/midas/blob/main/scripts/export.kql) file. The way this code works, is it starts by finding players who were recorded in your game between the TIME_RANGE_START and TIME_RANGE_END variables. It then searches the entire database for all events relating to those users. This is so that the user profiles are accurate - if a person played your game 100 times in the last year, but only 1 time in the time range, you'll want to know that. As a bonus, this also easily allows you to compare how a current version of the game is performing against a previous version. You may also set a PLAYER_COUNT limit, this will arbitrarily limit the amount of users recorded.

Once you've pasted and configured the KQL code into the PlayFab editor, press "Run" in the upper left hand corner of the editor. If it runs correctly you should see a table appear at the bottom. If you do, select the dropdown menu labeled "File" in the upper right side of the editor, and press the option "Export to CSV". This will download the data to your computer.

## Troubleshooting PlayFab
The less you have the troubleshoot PlayFab the happier you will be. Most of the errors tell you "An Error Occurrred" and nothing else. Here are some potential reasons an error could have occurred.

### Your Authentication Expired
So, for whatever reason sometimes if I keep a PlayFab tab open for a few hours, when I run a query - even a very simple one, it errors. I'm still logged in, but I guess some internal authentication key needs to be updated. To fix this, just refresh the page and try again. Don't trust the editor to save your code though - I almost always write it in VSCode then copy it over because of this.

### The Code Isn't Selected
You didn't select the code you wanted to run. In KQL the entire query needs to be a single block of text (though you can connect things with comments if this is too annoying). It will be slightly highlighted if it's selected. Also, the selection detection is not bulletproof, feel free to click the code again and retry. KQL is one of the few languages where just running the code again can fix the problem. 

### Query Is Too Big
Many users, especially those with established games, will not be able to export all their data at once. Depending on the amount you store + the number of events per session, you can usually get around 500-2000 sessions of data in a single go. This is why the KQL script I provided has a start / end time variable. If your data is too big, I recommend downloading it in chunks. You can import as many CSVs as you want into the upcoming Power Bi step - all you need to do is put them under the same folder, you don't even need to name them anything. The python script ahead will deduplicate the data as needed.

## Can I Automate This?
Yes you can. It will require you to create an AAD account in your microsoft workspace, and then using its credentials to perform API calls to retrieve the data. From there you can manually write it into a CSV or bypass the CSV step entirely and modify the upcoming Python script to work with the data you've retrieved. This is a process that took me hours to get right, and whenever I had to set up a new project it would take another hour because I'd forget. Automation is possible, but I'm not sure it's worth it for most devs.

Doing it manually takes around 3-5 boring minutes. You don't have to worry about rate limits. And you only have to do this once per update. The goal of Midas is not to provide a live feed of how your game is doing, it's meant to allow you to do an in-depth study into how an update has influenced the player experiences in your game. I have gone through this process over a dozen times, and frankly all trying to automate it seems to accomplish for me is headaches.
