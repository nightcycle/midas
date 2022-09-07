--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
local Types = require(_Package.Types)

local Config: Types.ConfigData = {
	Version = 13, --Internal versioning for midas framework
	SendDeltaState = true, --Send just the changes of state, not the entirety
}

return Config
