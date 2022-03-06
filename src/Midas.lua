local runService = game:GetService("RunService")

local packages = script.Parent.Parent
local src = script.Parent

local maidConstructor = require(packages:WaitForChild("maid"))
local fusion = require(packages:WaitForChild("fusion"))
local comm = require(packages:WaitForChild("comm"))

local players = require(src:WaitForChild("Players"))
local playFab = require(src:WaitForChild("PlayFab"))
local encrypter = require(src:WaitForChild("Encrypter"))

local Midas = {}
Midas.__type = "Midas"
Midas.ClassName = "Midas"

if runService:IsClient() then
	local fireClientEvent = comm.Client.GetSignal(script, "MidasAnalyticsEvent")

	function Midas:Fire()
		fireClientEvent:Fire(self:Serialize())
	end

else
	local onClientEvent = comm.Server.CreateSignal(script, "MidasAnalyticsEvent")

	onClientEvent:Connect(function(player, encodedPayload)
		if players[player] then
			local payload = encrypter.get(encodedPayload)
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

function Midas.new(player: Player, eventKeyPath: string)
	local self = {
		_config = {
			_eventPath = eventKeyPath,
			_player = player,
		},
		_maid = maidConstructor.new(),
		_tags = {},
		_states = {},
		_delta = {},
		_conditions = {},
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
	return self._config._player
end

function Midas:Serialize()
	local data = {}

	local _config = self._config

	local output = {
		Path = _config._eventPath,
		Player = self:GetPlayer().UserId,
		Data = self._delta,
	}
	self._delta = {}
	return encrypter.set(output)
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

	self._delta[index] = newState:Get()
	self._maid:GiveTask(fusion.Observe(newState):Connect(function()
		self._delta[index] = newState:Get()
	end))

	if oldState == newState then return end

	metrics[index] = newState
end

function Midas:Destroy()
	self._properties:destruct()
	self._maid:Destroy()
end
