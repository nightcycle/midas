---
sidebar_position: 4
---

# Power BI
Power BI is an amazing tool for working with complex data. It honestly feels like cheating, after you've been restricted to static graphs in other services. Unlike Tableau, it's also free to use. There is a paid verison for $10 a month that I use - it unlocks a bunch of cool extra visualization options, however it's by no means mandatory.

## Querying in Power BI
One thing though that I don't enjoy very much about Power BI, is the querying language. It's called M Script, and it's quite similar to KQL and SQL, except you have to write it in their garbage code editor. Like KQL and SQL it's also a very different type of programming language to what many game devs are familiar with. It took me almost a week to learn KQL and run basic queries in it within PlayFab - my brain just couldn't wrap itself around the various table datastructures and operations that needed to be used to effectively create and store tables. 

That being said - I wouldn't have been able to make this framework without that, and if you want to work with massive amounts of data a lot of the quirks in KQL and SQL exist for the purpose of speed. That being said - most people here are game devs, not data scientists, and my goal for the framework is to allow you to improve your game without having to become one.

So, to avoid you having to learn M Script I've created a Python script which you can run that will assemble a series of neat tables that you can load directly into Power BI. 

# Formatting the Data with Python
Python is a much easier language to work with if you grew up on languages like Lua, Javascript, or any C language. The main reason why you would use SQL over Python, is that SQL is much faster. As the point of this framework is for you to download a lot of data in one go then study it for a while, I felt that using Python was acceptable. 

## Setting Up the Python Script
First, if you haven't already, download [Python](https://www.python.org/downloads/). Once it's installed, you also need to install something called [PIP](https://pypi.org/project/pip/) which is essentially the Python version of Lua's Wally or Javascript's NPM. It allows you to download packages that you can use in your code. If you know how to use a terminal, you can run a [command in VSCode to automatically download all the required packages](https://note.nkmk.me/en/python-pip-install-requirements/).

Once you have this done, you will need to run the [format.py](https://github.com/nightcycle/midas/blob/main/scripts/format.py) script. It's under the midas repository, so clone that. Before running the Python script, edit the [format.toml](https://github.com/nightcycle/midas/blob/main/format.toml) file. This file allows you to configure the behavior of the format.py script.

## Configuring the Python Script
The "fill_down" category in the toml file has to do with how the python script handles missing data. If you set your in-game analytics package to only send the delta-state (aka, just the changes rather than a copy of the entire state tree), then you are likely to have many gaps in your data. To remedy this, you can enable fill down. If fill down is enabled it will check the prior indexed event in the table for any existing value. If not event exists at the prior index it will return nothing. If it finds one it will copy the data stored. The recursive property allows it to keep checking earlier and earlier events until it finds data. These processes increase the risk of data contamination, especially the recursive one. This allows you to store much less data, and your mileage may vary as to whether or not it's worth the risk.

The input and output path variables refer to where it will get and put the data. All the CSVs you downloaded in the previous step should be stored under a folder named "event" at this path location. The CSVs do not need to be named anything specific, and any duplicate events will be ignored. The output folder should have an "event" and a "kpi" folder. After you run the script you will find labelled CSV and parquet files at these locations. If you've never heard of a parquet file, it's basically a CSV file stored in binary, allowing the computer to read and write it much faster. 

## Running the Python Script
Once you've set the TOML, you can either run the script in the console or right click it in the VSCode explorer and press "Run Python File in Terminal". Depending on the size of your data this script can take anywhere between 15 seconds and an hour. Once it's done, it'll write to the output and you're good to import it into Power BI!

# Working in Power BI
I've included a copy of my [Dashboard](https://github.com/nightcycle/midas/blob/main/dashboard/main.pbix) for you to experiment with, but it's not neccessary. Working with data in Power BI (sans querying) is no more difficult than Excel / Google Sheets. 

## Importing the Data
On the upper left side of the screen under the home ribbon, you can press "Get Data". From there, a window will pop-up that allows you to select the type of source. Type "Parquet" into source and a button with a blue diamond icon alongside matching text will appear in the list. You can then select that, then press the yellow "Connect" button at the bottom.

From there, a URL will pop up. This URL can also be a system path, for example the one I used to import the sessions.parquet file was ``C:\Users\coyer\Documents\GitHub\midas\dashboard\output\kpi\sessions.parquet``, in fact you can even right click the file in VSCode and copy the path directly. I haven't been able to get it to work with relative paths unfortunately, otherwise I'd have done this for you.

Go through and import each table. After applying it to Power BI you should see it appear in the panel on the right side of the screen. You are now free to begin messing around with the data!

## Relationships and Models
To begin setting up relationships between data, go to the Models view on the left menu bar of the main Power BI dashboard page. 

One awesome thing about Power BI is the dynamic filtering. For example, if you set up a relationship between the session id on the sessions table, and the session id on the performance table, you can use a filter to hide all the sessions that lasted less than 30 seconds, and it will also hide all the performance data linked to those sessions in the connected performance table.

You can even set relationships to be both ways, meaning that if you filter out all the events from a specific user, that user will also be filtered. This allows for really helpful dynamic KPI measure. For example if you filter the events to just the "Completed Onbaording" equivalent event, it will filter out every user who didn't have that event. This then updated the various measures and visualizations, allowing you to engage with this user group in isolation and even see what your KPIs would be if all players were like this. 

## Measures
Often times you need to summarize data - whether that be get the average revenue across your users, or finding the max ping of a group - you need to be able to define ways to simplify data. There are quick measures you can make by either dragging a variable directly into a visual, however you can also manually create these measures as permanent added-on variables that can do more complicated math in an excel like language called DAX. 

## Groups / Bins
You can create "groups" from variables by right clicking and selecting "New Group" from the menu, allowing you to establish bins of various sizes - really useful for creating histograms. Groups are sometimes referred to as "Bins" in other software.

## Visuals
Power BI allows you to visualize data a ton of ways. All you need to do is add one to the dashboard, then drag variables from the fields area to the appropriate visualizations slot. There you can specify how it's summarized, as well as change how it's labelled by right clicking and pressing "Rename for this visual". 

### Key Influencers
I heavily recommend using the "Key influencers" visual, as you can feed it a ton of variables and tell it to solve for the conditions in which a change in one variable influences another variable. This is amazingly useful for finding hidden patterns in the player behavior from hundreds of different metrics. 

### Decomposition Tree
Decomposition trees aren't as useful as Key Influencers, but they're more visually accessible. A decomposition tree allows you to create an N-Dimensional matrix of categories with the goal of finding which ones score the highest in a given metric. I typically use this to see how different platforms and localizations influence KPIs. 

## Filtering
As I briefly touched on earlier, one of the biggest strengths of Power BI is the ability to dynamically reduce your dataset in meaningful ways, allowing you to engage with specific users and behaviors in isolation. There are various ways to do this.

### Clicking a Visual
Many visuals in Power BI double as input mechanisms. For example, you can select a bar on a bar chart, and it will filter the data to just the events composing that bar of the chart. Since you can measure KPIs for this changing audience, it can be very useful for composing different player groups that exist within your game.

### The Filter Panel
On the right side of the screen next to the visuals and fields panel is a filters panel. Here you can place different variables from the fields area and and decide which values to keep and which to dispose of. There are various domains of filtering, ranging from just the current selected visual, to the entire dashboard. Quite frequently I'll use this to remove outliers, as well as my own data.

You can also insert a visual called a "Slicer" which is a slightly more front-end friendly version of the filter panel, allowing you to change variables with things like a slider. Also pro-tip, if when you place a number variable there it lists every single unique value, rather than as a slider, it's because that number is stored as a string.

# Conclusion
Power BI is an awesome tool for sorting through the hyper-complicated systems that are online games. There is a ton of stuff not covered in this document relating to how you can best work with Power Bi - my main focus has just been to give you as clean a dataset as easily as possible, so that you can spend your time focusing on how to actually make sense of the data. 

Feel free to modify things as you need, none of my work is sacred and I made it with myself in mind first and foremost. My main hope is that this framework provides you a useful starting point for improving your games with complete control over your data.

Best of luck!