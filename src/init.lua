--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Packages
local _Package = script
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)
local Network = require(_Packages.Network)

-- Modules
local Config = require(_Package.Config)
local PlayFab = require(_Package.PlayFab)
local Midas = require(_Package.Midas)
local Profile = require(_Package.Profile)
local Templates = require(_Package.Templates)
local Types = require(_Package.Types)

-- Remote Events
local GetInitialConfig = Network.getRemoteFunction("GetInitialMidasConfig")
local UpdateConfig = Network.getRemoteEvent("UpdateMidasConfig")

export type Midas = Types.PublicMidas
export type PrivateMidas = Types.PrivateMidas
export type TeleportDataEntry = Types.TeleportDataEntry
type Profile = Types.Profile
type ConfigurationData = Types.ConfigurationData
type Interface = {
	__index: Interface,
	GetMidas: (self: Interface, player: Player, path: string) -> Midas,
	_Connect: (self: Interface, player: Player) -> nil,
	InsertTeleportDataEntry: (
		self: Interface,
		player: Player,
		teleportData: { [any]: any }?
	) -> {
		MidasAnalyticsData: TeleportDataEntry,
		[any]: any,
	},
	GetEventSignal: (self: Interface) -> _Signal.Signal,
	Configure: (self: Interface, config: ConfigurationData) -> nil,
	init: (titleId: string, devSecretKey: string) -> nil,
}

--- @class Interface
--- The front-facing module used to integrate a game with the Midas library.
local Interface: Interface = {} :: any
Interface.__index = Interface

--- Returns a midas configured for that path. If one already exists for that path it will provide that one.
function Interface:GetMidas(player: Player, path: string): Midas
	local profile = if RunService:IsServer() then Profile.get(player.UserId) else nil
	if profile then
		local existingMidas = profile:GetMidas(path)
		if existingMidas then
			return existingMidas :: any
		end
	end
	return Midas._new(player, path) :: any
end

--- Allows for the replacement of the default config table, changing the behavior of the framework.
--- @server
function Interface:Configure(deltaConfig: ConfigurationData): nil
	assert(RunService:IsServer(), "Bad domain")
	-- Overwrites the shared keys with new data.
	local function writeDelta(target: { [string]: any }, change: { [string]: any })
		for k, v in pairs(change) do
			if typeof(v) == "table" then
				if target[k] == nil then
					target[k] = {}
				end
				writeDelta(target[k], v)
			else
				target[k] = v
			end
		end
	end
	writeDelta(Config, deltaConfig)

	UpdateConfig:FireAllClients(Config)

	return nil
end

-- Make sure client always has the most up-to-date config
if not RunService:IsServer() then
	local function rewriteConfig(newConfig: { [string]: any })
		for k, v in pairs(newConfig) do
			Config[k] = v
		end
	end
	UpdateConfig.OnClientEvent:Connect(rewriteConfig)
	rewriteConfig(GetInitialConfig:InvokeServer())
else
	GetInitialConfig.OnServerInvoke = function(player: Player)
		return Config
	end
end

--- When a player is being teleported, pass the teleport data prior to teleporting them through this API. This will ensure the session is tracked as continuing.
--- @server
function Interface:InsertTeleportDataEntry(
	player: Player,
	teleportData: { [any]: any }?
): {
	MidasAnalyticsData: TeleportDataEntry,
	[any]: any,
}
	assert(RunService:IsServer(), "Bad domain")
	teleportData = teleportData or {}
	assert(teleportData ~= nil)

	local profile = Profile.get(player.UserId)
	if profile then
		teleportData.MidasAnalyticsData = profile:Teleport()
	end

	return teleportData
end

--- Provides a pseudo-RBXScriptSignal which will fire whenever an event is sent via HttpService.
--- When the Signal is fired it will provide the playerId, path, data, tags, and timestamp in that order.
--- @server
function Interface:GetEventSignal(): _Signal.Signal
	assert(RunService:IsServer(), "Bad domain")
	return PlayFab.OnFire
end

--- Call this on the server to connect PlayFab prior to firing any events.
--- @server
function Interface.init(titleId: string, devSecretKey: string): nil
	assert(RunService:IsServer(), "Bad domain")
	PlayFab.init(titleId, devSecretKey)
	return nil
end

-- Connect players to framework when they enter
function initPlayer(player: Player)
	if RunService:IsServer() then
		local profile = Profile.new(player)
		assert(profile ~= nil)
		Templates.join(player, profile._WasTeleported)
		Templates.chat(player)
		Templates.groups(player)
		Templates.population(player)
		Templates.serverPerformance(player, function()
			return profile.TimeDifference
		end, function()
			return profile.EventsPerMinute
		end)
		Templates.market(player)
		Templates.exit(player, function()
			return profile._IsTeleporting
		end)
		Templates.serverIssues(player)
		-- Track character properties
		local function loadCharacter(character: Model)
			local mCharacter = Templates.character(character)
			if mCharacter then
				profile:SetMidas(mCharacter :: any)
			end
		end
		profile._Maid:GiveTask(player.CharacterAdded:Connect(loadCharacter))
		if player.Character then
			loadCharacter(player.Character)
		end
	else
		Templates.demographics(player)
		Templates.policy(player)
		Templates.clientPerformance(player)
		Templates.settings(player)
		Templates.clientIssues(player)
	end

	return nil
end

if RunService:IsServer() then
	Players.PlayerAdded:Connect(initPlayer)
	task.spawn(function()
		for i, player in ipairs(Players:GetChildren()) do
			initPlayer(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = Profile.get(player.UserId)
		if profile then
			task.delay(15, function()
				profile:Destroy()
			end)
		end
	end)
else
	initPlayer(game.Players.LocalPlayer)
end

return Interface
