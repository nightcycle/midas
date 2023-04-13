--!strict
local Package = script.Parent
local Types = require(Package.Types)

local Config: Types.ConfigurationData = {
	Version = {
		Major = 0,
		Minor = 0,
		Patch = 0,
	},
	BytesPerMinutePerPlayer = 2000*15,
	SendDeltaState = false, --Send just the changes of state, not the entirety
	SendDataToPlayFab = true,
	PrintEventsInStudio = true,
	PrintLog = false,
	Keys = {},
	Encoding = {
		Marker = "~",
		Dictionary = {
			Properties = {},
			Values = {},
		},
		Arrays = {},
	},
	Templates = {
		Join = true,
		Chat = true,
		Population = true,
		ServerPerformance = true,
		Market = true,
		Exit = true,
		Character = true,
		Player = true,
		Demographics = true,
		ClientPerformance = true,
		Group = {
		},
	},
}

return Config
