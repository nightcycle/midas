local packages = script.Parent
local maidConstructor = require(packages:WaitForChild("maid"))
local rodux = require(packages:WaitForChild("rodux"))
local remoteConstructor = require(packages:WaitForChild("remote"))

local runService = game:GetService("RunService")
local players = require(script:WaitForChild("Players"))
local playFab = require(script:WaitForChild("PlayFab"))

local Midas = {}
Midas.ClassName = "Midas"

function Midas.new(class, parentClass, player)
	local self = {
		_class = class,
		_parent = parentClass,
		_player = player,
		_metrics = {},
		_maid = maidConstructor.new(),
	}
	setmetatable(self, Midas)
	self._maid:GiveTask(self)
	return self
end

if runService:IsClient() then
	local clientRemote = game:WaitForChild("ReplicatedStorage"):WaitForChild("MidasAnalyticsEvent")

	function Midas:Fire()
		clientRemote:FireServer(self:Serialize())
	end
else
	local remoteEvent = Instance.new("RemoteEvent", game:WaitForChild("ReplicatedStorage"))
	remoteEvent.Name = "MidasAnalyticsEvent"

	local function sendEvent(player, payload)
		local playerInfo = players[player]
		print("Player", players)
		if playerInfo then
			print("Dababy lessgo")
			local playFabApi = playerInfo.PlayFab:getState()
			local token = playFabApi.EntityToken
			playFab:Fire(token,{
				Payload = payload,
			})
		end
	end

	remoteEvent.OnServerEvent:Connect(function(player, payload)
		print("A: ", player, payload)
		sendEvent(player, payload)
	end)

	function Midas:Fire() --shoot it out to server
		local payload = self:Serialize()
		sendEvent(self._player, payload)
	end
end

function Midas:Serialize()
	local function serialize(metrics)
		local newTabl = {}
		for k, v in pairs(metrics) do
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
	print(self)
	local output = {
		CLASS = self._class,
		PARENT = self._parent,
		PLAYER = self._player.UserId,
		METRICS = serialize(self._metrics),
	}
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
	local metrics = self._metrics
	local oldState = metrics[index]

	if oldState == newState then
		return
	end

	metrics[index] = newState
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
