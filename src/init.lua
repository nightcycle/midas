--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- References
local Package = script
local Packages = Package.Parent

-- Packages
local Signal = require(Packages:WaitForChild("Signal"))
local NetworkUtil = require(Packages:WaitForChild("NetworkUtil"))
local ServiceProxy = require(Packages:WaitForChild("ServiceProxy"))
local Maid = require(Packages:WaitForChild("Maid"))

-- Modules
local Config = require(script.Config)
local PlayFab = require(script.PlayFab)
local Tracker = require(script.Tracker)
local Profile = require(script.Profile)
local Templates = require(script.Templates)
local Types = require(script.Types)

-- Remote Events
local GetInitialConfig = NetworkUtil.getRemoteFunction("GetInitialMidasConfig")

export type Tracker = Types.PublicTracker
export type PrivateTracker = Types.PrivateTracker
export type TeleportDataEntry = Types.TeleportDataEntry
type Profile = Types.Profile
export type ConfigurationData = Types.ConfigurationData
type Maid = Maid.Maid
export type Interface = {
	__index: Interface,
	_TitleId: string?, 
	_SecretKey: string?,
	_Maid: Maid,
	_IsAlive: boolean,
	_ProfileRegistry: {[number]: Profile},
	_GetProfile: (self: Interface, userId: number) -> Profile?,
	GetTracker: (self: Interface, player: Player, path: string) -> Tracker,
	_Connect: (self: Interface, player: Player) -> nil,
	InsertTeleportDataEntry: (
		self: Interface,
		player: Player,
		teleportData: { [any]: any }?
	) -> {
		MidasAnalyticsData: TeleportDataEntry,
		[any]: any,
	},
	GetEventSignal: (self: Interface) -> Signal.Signal,
	Destroy: (self: Interface) -> nil,
	Configure: (self: Interface, config: ConfigurationData) -> nil,
	new: () -> Interface,
	init: (titleId: string, devSecretKey: string, maid: Maid?) -> nil,
}

function log(message: string, player: Player?)
	if Config.PrintLog then
		print("[", player, "]", "[interface]", ":", message)
	end
end

local CONSTRUCT_KEY = "ConstructTracker"

--- @class Interface
--- The front-facing module used to integrate a game with the Tracker library.
local Interface: Interface = {} :: any
Interface.__index = Interface

function Interface:Destroy()
	if not self._IsAlive then
		return
	end
	self._IsAlive = false

	self._Maid:Destroy()

	setmetatable(self, nil)
	local tabl: any = self
	for k, v in pairs(tabl) do
		tabl[k] = nil
	end

	return nil
end

function Interface:_GetProfile(userId: number)
	log("get profile for "..tostring(userId))
	local function getProfile(attempt: number?)
		attempt = attempt or 1
		assert(attempt ~= nil)

		if attempt > 10 / 0.1 then
			log("profile failed "..tostring(userId))
			return
		end

		local result: Profile? = self._ProfileRegistry[userId] :: any

		if result == nil then
			task.wait(1)
			log("did not find profile "..tostring(userId))
			return getProfile(attempt + 1)
		else
			log("found profile "..tostring(userId))
			return result
		end
	end
	return getProfile()
end

--- Returns a tracker configured for that path. If one already exists for that path it will provide that one.
function Interface:GetTracker(player: Player, path: string): Tracker
	log("get tracker", player)
	local profile = if RunService:IsServer() then self:_GetProfile(player.UserId) else nil
	if profile then
		local existingMidas = profile:GetTracker(path)
		if existingMidas then
			return existingMidas :: any
		end
	end
	if RunService:IsServer() then
		log("constructing new server tracker", player)	
		return Tracker._new(player, path, profile) :: any
	else
		log("constructing new client tracker", player)	
		return Tracker._new(player, path, nil) :: any
	end
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

	return nil
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

	local profile = self:_GetProfile(player.UserId)
	if profile then
		teleportData.MidasAnalyticsData = profile:Teleport()
	end

	return teleportData
end

--- Provides a pseudo-RBXScriptSignal which will fire whenever an event is sent via HttpService.
--- When the Signal is fired it will provide the playerId, path, data, tags, and timestamp in that order.
--- @server
function Interface:GetEventSignal(): Signal.Signal
	assert(RunService:IsServer(), "Bad domain")
	return PlayFab.OnFire
end



local currentInterface: Interface


-- Make sure client always has the most up-to-date config
if RunService:IsServer() then


	function Interface.new()
		log("new interface")
		local self: Interface = setmetatable({}, Interface) :: any
		self._TitleId = nil
		self._SecretKey = nil
		self._Maid = Maid.new()
		self._ProfileRegistry = {}
		self._IsAlive = true
	
		-- Connect players to framework when they enter
		local function initPlayer(player: Player)
			assert(player, "bad player")

			log("init player", player)
			local profile = self._Maid:GiveTask(Profile.new(player))
			
			log("registering profile", player)
			local preExistingProfile: Profile = self._ProfileRegistry[player.UserId]
			if preExistingProfile then
				preExistingProfile:Destroy()
				self._ProfileRegistry[player.UserId] = nil
			end
			self._ProfileRegistry[player.UserId] = profile
			
			log("registering templates", player)
			assert(profile ~= nil)
			Templates.join(player, profile, profile._WasTeleported)
			Templates.chat(player, profile)
			Templates.groups(player, profile)
			Templates.population(player, profile)
			Templates.serverPerformance(player, profile, function()
				return profile.TimeDifference
			end, function()
				return profile.EventsPerMinute
			end)
			Templates.market(player, profile)
			Templates.exit(player, profile, function()
				return profile._IsTeleporting
			end)
			-- Track character properties
			local function loadCharacter(character: Model)
				log("load character", player)
				local mCharacter = Templates.character(character, profile)
				if mCharacter then
					profile:SetTracker(mCharacter :: any)
				end
			end
			profile._Maid:GiveTask(player.CharacterAdded:Connect(loadCharacter))
			if player.Character then
				loadCharacter(player.Character)
			end

			return nil
		end

		local DestroyTracker = self._Maid:GiveTask(NetworkUtil.getRemoteEvent("DestroyTracker"))
		self._Maid:GiveTask(DestroyTracker.OnServerEvent:Connect(function(player: Player, eventKeyPath: string)
			local profile = self:_GetProfile(player.UserId)
			log("destroying tracker", player)
			if profile then
				profile:DestroyTracker(eventKeyPath)
			end
		end))
		
		self._Maid:GiveTask(Players.PlayerAdded:Connect(initPlayer))

		task.spawn(function()
			for i, player in ipairs(Players:GetChildren()) do
				assert(player:IsA("Player"))
				initPlayer(player)
			end
		end)

		self._Maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
			log("player removing", player)
			local profile = self:_GetProfile(player.UserId)
			if profile then
				log("found profile of removed player", player)
				task.delay(15, function()
					if profile._IsAlive then
						profile:Destroy()
					end
				end)
			end
		end))

		NetworkUtil.onServerInvoke(CONSTRUCT_KEY, function(player: Player, eventKeyPath: string)
			log("constructing tracker at "..tostring(eventKeyPath), player)
			Tracker._new(player, eventKeyPath, self:_GetProfile(player.UserId))
			return true
		end)
		if currentInterface ~= nil then
			currentInterface:Destroy()
		end
		currentInterface = self
	
		return self
	end


	--- Call this on the server to connect PlayFab prior to firing any events.
	--- @server
	function Interface.init(titleId: string, devSecretKey: string, maid: Maid?): nil

		maid = maid or Maid.new()
		assert(maid)

		local interface = maid:GiveTask(Interface.new())
		interface._TitleId = titleId
		interface._SecretKey = devSecretKey

		PlayFab.init(titleId, devSecretKey)
		GetInitialConfig.OnServerInvoke = function(player: Player)
			return Config
		end

		return nil
	end

else

	GetInitialConfig:InvokeServer()

	Templates.demographics(Players.LocalPlayer)
	Templates.clientPerformance(Players.LocalPlayer)

end

return ServiceProxy(function()
	return currentInterface or Interface
end)
