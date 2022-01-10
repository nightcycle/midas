local packages = script.Parent

local maidConstructor = require(packages:WaitForChild("maid"))
local fusion = require(packages:WaitForChild("fusion"))
local comm = require(packages:WaitForChild("comm"))

local runService = game:GetService("RunService")
local players = require(script:WaitForChild("Players"))
local playFab = require(script:WaitForChild("PlayFab"))

local Midas = {}
Midas.ClassName = "Midas"

if runService:IsClient() then

	-- local clientRemote = game:WaitForChild("ReplicatedStorage"):WaitForChild("MidasAnalyticsEvent")
	local clientSignal = comm.Client.GetSignal(script, "MidasAnalyticsEvent")
	function Midas:Fire()
		clientSignal:Fire(self:Serialize())
	end
else
	-- local remoteEvent = Instance.new("RemoteEvent", game:WaitForChild("ReplicatedStorage"))
	-- remoteEvent.Name = "MidasAnalyticsEvent"

	local serverSignal = comm.Server.CreateSignal(script, "MidasAnalyticsEvent")

	serverSignal:Connect(function(player, payload)
		if players[player] then
			playFab:Fire(players[player].PlayerId, payload.Path, payload.Data)
		end
	end)

	function Midas:Fire() --shoot it out to server
		local payload = self:Serialize()
		local player = self:GetPlayer()
		if players[player] then
			playFab:Fire(players[player].PlayerId, payload.Path, payload.Data)
		end
	end
end

function Midas.new(eventName, player)
	local self = {
		_properties = {
			_eventName = eventName,
			_player = player,
		},
		_maid = maidConstructor.new(),
		_metrics = {},
		_delta = {},
	}
	setmetatable(self, Midas)
	self._maid:GiveTask(self)
	return self
end

function Midas.getSessionId(player)
	if runService:IsClient() then return end
	return players[player].SessionId
end

function Midas:GetPlayer()
	return self._properties._player
end

function Midas:Serialize()
	local data = {}

	local _props = self._properties

	local output = {
		Path = _props._eventName,
		Player = self:GetPlayer().UserId,
		Data = self._delta,
	}
	self._delta = {}
	return output
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
		return self._metrics[index]
	end
end

function Midas:__newindex(index, newState)
	if not newState then return end
	if not type(newState) == "table" then return end
	if newState["type"] ~= "State" then return end

	local metrics = self._metrics
	local oldState = metrics[index]

	self._delta[index] = newState:get()
	self._maid:GiveTask(fusion.Compat(newState):onChange(function()
		self._delta[index] = newState:get()
	end))

	if oldState == newState then return end

	metrics[index] = newState
end

function Midas:Destroy()
	self._properties:destruct()
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
