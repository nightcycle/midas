---
sidebar_position: 2
---

# Roblox
Integrating the Midas framework into your game's code is fairly easy, however it requires pre-requisite knowledge being provided to you now.

## Initial Set-Up
These are the things you need to complete for each game.

### Configuring the Framework
In order to best support your workflow you can configure many different aspects of the framework. You can read up further on the properties available to configure under the ConfigurationData type on the Interface API page, however you don't need to write to all of them when configuring. In the below example only about half of the variables are being set. Typically you should at least set the version as you'll want to be able to tell which version of the game data originates from. You must run this script on the server for it to work, otherwise it will error.

```lua
	local WallyPackages = game.ReplicatedStorage.Packages
	local MidasAnalytics = require(WallyPackages.Midas)

	MidasAnalytics:Configure({
		Version = {
			Major = 1,
			Minor = 0,
			Patch = 0,
			Hotfix = 2,
			Tag = "Alpha",
		},
		SendDeltaState = false,
		Templates = {
			Join = true,
			Chat = false,
			Demographics = true,
			Policy = false,
			Settings = false,
		}
	})
```

### Initializing the Framework
Assuming you are using the native PlayFab based data storage solution, you will want to initialize the framework with the [TitleId](https://docs.microsoft.com/en-us/gaming/playfab/personas/developer) and [Dev Secret Key](https://docs.microsoft.com/en-us/gaming/playfab/gamemanager/secret-key-management). As you may have guessed from the name "Dev Secret Key", it's a secret. Since it's a secret please run this in a script stored exclusively under ServerScriptService to avoid exploiters from finding it.

```lua

local TITLE_ID = "ABC123"
local DEV_SECRET_KEY = "A1B2C3D4E5F6G7H8I9"

MidasAnalytics.init(TITLE_ID, DEV_SECRET_KEY)

```

### Connecting Players to Framework
The framework automatically detects new players entering and will bind them to the relevant data templates as dictated in the configuration. Since some templates record client-side information it's important that you require the Midas framework package on both client and server, otherwise you can experience some data loss.

## Using Midaii
At the heart of the Midas framework is a "Midas", plurally known as "Midaii". These are little data collection helpers that do a ton of work behind the scenes to make data collection and event firing as easy as possible. 

### Constructing a Midas
Midaii can be constructed on the server or client. In the below example we'll be creating a Midas for a player's sword. 

```lua
local player = game.Players.LocalPlayer
local path = "Combat/Weapon/Sword"
local swordMidas = MidasAnalytics:GetMidas(player, path)
```
The path variable provides context on where to store the information in the eventual dataset, a functionality we explore further farther down on this page. 

You also don't need to worry about garbage collection, as Midaii delete themselves when a player leaves. If a Midas with the same path already exists it will pass you that Midas rather than creating a new one.

### Binding State to Midas
If there's data you'd like to track, just attach it to a Midas! 

```lua

local swordKills = 0
swordMidas:SetState("Kills", function() return swordKills end)

local damagePerSecond = 0
swordMidas:SetState("DPS", function() return damagePerSecond end)

```

In order to keep things simple, rather than binding the information directly to the Midas you instead provide a function it can call to get the current value. This allows for the easy tracking of local variables without needing to manually update the Midas whenever one of them changes.

### Firing an Event from Midas

It was game designer Sid Meier who once said "A game is a series of interesting choices.", as a game analyst it's your job to track those choices to see if they're interesting. Here's an example of an event you might fire if the sword just got equipped.

```lua

swordMidas:Fire("Equipped")

```

The event itself will fire to framework (even if it's on the client), where it will be formatted and bundled and sent off to PlayFab / your custom data storage solution. The key itself doesn't need to be unique, as it is actually added onto the end of the path variable set when the midas was constructed. For example, "Equipped" is recorded as "Combat/Weapon/Sword/Equipped".

You may notice that there is no place to include extra information with the fired events unlike many other libraries. I've gone back and forth on whether to add support for one-off data binding with events, but for now I feel it is best for you to bind all useful data, no matter how temporary, as a state. 

Should you not want to use PlayFab to store your data, on the server use ``MidasAnalytics:GetEventSignal()`` to have all the compiled event data sent directly to you, allowing you to hook it up and send wherever is needed. This function can also be quite useful for debugging. 

### The Midas Hierarchy

Whenever a Midas is fired, the framework basically takes a photograph of the entire game. Every single Midas registerred to a player is compiled, calling their bound state functions and returning tables with their outputs. Then, using the path variable of each midas, the resulting data is organized into a singular massive data structure.
```json
	{
		Combat: {
			Weapon: {
				Sword: {
					Kills: 0,
					DPS: 0,
				}
			}
		}
	}
```

In the above example, you can see how it separated the path into layers of tables with a single Midas. A more complicated table with multiple Midaii will look something like this:
```json
	{
		FriendsInServer: {
			Old: 2,
			New: 1,
		},
		Combat: {
			Weapon: {
				Sword: {
					Kills: 0,
					DPS: 0,
					Blade: {
						IsPoison: false,
						Sharpness: 0.5,
						Length: 3,
					},
				}
				Gun: {
					Kills: 0
					Range: 50
				},
			},
			Stats: {
				Deaths: 6,
				Kills: 3,
				KDR: 0.5,
			}
			Health: 0
		},
		Map: {
			Lighting: {
				Precipitation: 0,
				Fog: 0.5,
				Brightness: 0.5,
				ClockTime: 15.63,
			},
			Biome: "Forest",
			NearbyPlayers: 2,
		}
	}
```

This mega-table is constructed every single time a Midas is fired. This table is then sent with the event to PlayFab / your data storage solution. If after encoding your table is larger than 500 characters it will error and the event will be lost. There are a few things you can do to avoid this.

#### Cutting Back on Templates
In the initial configuration you can create various template Midaii to track useful data about the player. While all of the data tracked is useful, not all of it is equally useful. For example if your game is relatively small and has no reason to worry about lag, consider cutting the ServerPerformance and ClientPerformance templates. The ServerPerformance template is particularly massive due to it's recording of a ton of peripheral data.

Some other templates you may consider filtering for a reduced size are the Demographics and Settings templates. The Demographics template contains a ton of useful information ranging from account age to platform to language, however if you're fairly confident in who your audience is it may make more sense to create your own custom alternative with less information.

#### Only Recording Changes in State
If the SendDeltaState configuration variable is flipped to true, when compiling the mega-table above it will only include data which has changed since the previous event. This can cut down on the amount of data dramatically, however it brings in two new issues: increased difficulty in unloading data, and increased risk of data loss.

Of the two, the increased difficulty unloading data can be trivial if you know what you're doing. Basically, when you query the data in Power Bi later, you need to sort the events by session id, then sort them by index / order. From there you can use a function called ["Fill Down"](https://docs.microsoft.com/en-us/power-query/fill-values-column) which will take the previous value and insert it below when the cell is empty. It slows down the query a bit, but once the query is set-up you likely won't run it more than a few times an hour.

The real issue of this method is that there's an elevated chance for data corruption.

```lua
-- Character health is tracked by a Midas.
local health = 100
characterMidas:SetState("Health", function() return health end)

--Character is damaged
health = 2
characterMidas:Fire("ReceiveDamage") --ERROR, THIS FAILED!

-- Character runs away
characterMidas:Fire("Flee")

```

In the above scenario, because the delta state failed, when the tables are later filled down the Flee event will be attributed a health of 100 because that was the last health update it received. As you can guess, having a character flee at full health and at almost 0 health are very different experiences - this is why this method is arguably more dangerous.

I've included with each event a baked in roblox-side index so that you can estimate how many events are missing. For example if you receive an event with index 4 and an event with index 6, you know 5 didn't make it through. In my experience, around 1% of events tend to disappear currently. Since with analytics you're dealing with sample sizes in the thousands, usually the error caused by this across such a large group isn't a huge issue as for every player who missed that key moment, there are another 99 who recorded it.

Over time I plan to add more safeguards, such as handling failed events more intelligently, as well as sprinkling in a few unchanged states to ensure a higher change of correcting failures early. That being said, this will always be more of a risk than the method which sends an entire copy of the player's state each time.

## Conclusion
And that's about it! There are a few useful functions and utilities worth learning that will improve your quality of life, but the bare necessities are complete. Now that you've completed sending the data, it's time to catch that data on the storage side.