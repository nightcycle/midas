local runService = game:GetService("RunService")

local Midas = require(script:WaitForChild("Constructor"))
local PlayFab = require(script:WaitForChild("PlayFab"))

local Interface = {}

local initialized = false

function Interface.new(...)
	assert(initialized == true, "Not initialized")
	return Midas.new(...)
end

if runService:IsClient() or initialized == true then
	return Interface
else
	function Interface.init(titleId, devSecretKey)
		PlayFab.init(titleId, devSecretKey)
		return Interface
	end

	return Interface
end
