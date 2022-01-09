local packages = script.Parent
local maidConstructor = require(packages:WaitForChild("maid"))
local rodux = require(packages:WaitForChild("rodux"))
local remoteConstructor = require(packages:WaitForChild("remote"))

local runService = game:GetService("RunService")
local players = require(script:WaitForChild("Players"))
local playFab = require(script:WaitForChild("PlayFab"))

local Midas = {}
Midas.ClassName = "Midas"

function Midas.new(class, parentClass, player: Player)
	local self = {
		_class = class,
		_parent = parentClass,
		_player = player,
		_states = {},
		_maid = maidConstructor.new(),
	}
	self._maid:GiveTask(self)
	return setmetatable(self, Midas)
end

if runService:IsClient() then
	local clientRemote = remoteConstructor.new()
	clientRemote:BindToServer(game:WaitForChild("ReplicatedStorage"):WaitForChild("MidasAnalyticsEvent"))

	function Midas:Fire()

	end
else
	local remoteEvent = Instance.new("RemoteEvent", game:WaitForChild("ReplicatedStorage"))
	remoteEvent.Name = "MidasAnalyticsEvent"

	function Midas:Fire() --shoot it out to server
		local playerInfo = players[self._player]
		local playFabApi = playerInfo.PlayFab:getState()
		local context = self:Serialize()
		playFab:Fire(playFabApi.EntityToken,{
			Payload = {

			},
			Eneity = playFabApi.EntityToken,

		})
	end
end

function Midas:Serialize()
	local function serialize(states)
		local newTabl = {}
		for k, v in pairs(states) do
			if type(v) == "table" then
				newTabl[k] = serialize(v)
			elseif type(v) == "function" then
				newTabl[k] = v()
			else
				newTabl[k] = v
			end
		end
		return newTabl
	end
	return serialize(self._states)
end

function Midas:Connect(signal)
	self._maid:GiveTask(signal:Connect(function()
		self:Fire()
	end))
end

function Midas:__index(index)
	if Midas[index] then
		return Midas[index]
	else
		return self._tasks[index]
	end
end

function Midas:__newindex(index, newState)
	if Midas[index] ~= nil then
		error(("'%s' is reserved"):format(tostring(index)), 2)
	end

	local states = self._states
	local oldState = states[index]

	if oldState == newState then
		return
	end

	states[index] = newState
end

function Midas:Destroy()
	self._maid:Destroy()
end

local initialized = false
if runService:IsClient() or initialized == true then
	return Midas
else
	return function(titleId, devSecretKey) --gotta init first
		playFab.init(titleId, devSecretKey)
		return Midas
	end
end
