--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Packages
local _Package = script.Parent
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)

-- Modules
local Config = require(_Package.Config)
local PlayFab = require(_Package.PlayFab)
local Network = require(_Package.Network)

type Midas = {}

local REGISTRY: {[number]: Profile} = {}

export type TeleportDataEntry = {
	_Prev: {[string]: any},
	_SessionId: string,
	_PlayerId: string,
}

export type Profile = {
	_Maid: _Maid.Maid,
	Player: Player,
	Instance: Instance,
	EventsPerMinute: number,
	TimeDifference: number,
	_IsAlive: boolean,
	_ConstructionTick: number,
	_IsTeleporting: boolean,
	_WasTeleported: boolean,
	_Index: number,
	_Midaii: {[string]: Midas},
	_Prev: {},
	_SessionId: string?,
	_PlayerId: string?,
	Destroy: (self: Profile) -> nil,
	_Fire: (self: Profile, eventFullPath: string, delta: {[string]: any}, tags: {string}, timestamp: number) -> nil,
	_Format: (self: Profile, midas: Midas, eventName: string, delta: {[string]: any}, eventIndex: number, duration: number, timestamp: number) -> ({[string]: any}, string),
	FireSeries: (self: Profile, midas: Midas, eventName: string, timeStamp: string, eventIndex: number, includeEndEvent: boolean) -> _Signal.Signal,
	Fire: (self: Profile, midas: Midas, eventName: string, timestamp: string, eventIndex: number, duration: number?) -> nil, 
	HasPath: (self: Profile, midas: Midas, path: string) -> boolean,
	DestroyPath: (self: Profile, path: string) -> nil,
	DestroyMidas: (self: Profile, path: string) -> nil,
	SetMidas: (self: Profile, midas: Midas) -> nil,
	_Export: (self: Profile) -> TeleportDataEntry,
	Teleport: (self: Profile) -> nil,
	new: (player: Player) -> Profile,
	get:(userId: number) -> Profile?,
	getProfilesFolder: () -> Folder,
	__index: Profile,
}

local Profile: Profile = {} :: any
Profile.__index = Profile

local ProfilesFolder: Folder? = script:FindFirstChild("MidasProfiles") or Instance.new("Folder")
assert(ProfilesFolder ~= nil)
ProfilesFolder.Name = "MidasProfiles"
ProfilesFolder.Parent = script

function writePath(tabl: any, pathWords: string | {string}, val: any)
	if type(pathWords) == "string" then
		pathWords = string.split(pathWords, "/")
	end
	assert(typeof(pathWords) == "table")
	local nextKey = pathWords[1]
	assert(nextKey ~= nil, "Bad key")
	table.remove(pathWords, 1)
	if #pathWords == 0 then
		tabl[nextKey] = val
	elseif tabl[nextKey] then
		writePath(tabl[nextKey], pathWords, val)
	else
		tabl[nextKey] = {}
		writePath(tabl[nextKey], pathWords, val)
	end
end

function readPath(tabl: any, pathWords: string | {string})
	if type(pathWords) == "string" then
		pathWords = string.split(pathWords, "/")
	end
	assert(typeof(pathWords) == "table")
	local nextKey = pathWords[1]

	if tabl[nextKey] == nil then return nil end
	
	if #pathWords == 1 then
		return tabl[nextKey]
	else
		table.remove(pathWords, 1)
		return readPath(tabl[nextKey], pathWords)
	end
end

function writeDelta(path: string, value: any, delta, old)
	local lastValue = readPath(old, path)
	if lastValue ~= value then
		writePath(delta, path, value)
		writePath(old, path, value)
	end
end

function Profile:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false

	REGISTRY[self.Player.UserId] = nil

	self._Maid:Destroy()

	setmetatable(self, nil)
	local tabl: any = self
	for k, v in pairs(tabl) do
		tabl[k] = nil
	end

	return nil
end

function Profile:_Fire(eventFullPath: string, delta: {[string]: any}, tags: {string}, timestamp: number)
	self.EventsPerMinute += 1
	
	task.delay(60, function()
		if self ~= nil and self._ServerPerformanceMidas ~= nil then
			self.EventsPerMinute -= 1
		end
	end)

	self.TimeDifference = tick() - self._ConstructionTick

	while self._IsAlive and self._PlayerId == nil do task.wait(0.1) end

	PlayFab:Fire(self._PlayerId, eventFullPath, delta, tags, timestamp)
	return nil
end

function Profile:_Format(midas: Midas, eventName: string, delta: {[string]: any}, eventIndex: number, duration: number?, timestamp: number): ({[string]: any}, string)
	self._Index += 1

	delta.Index = {
		Total = self._Index,
		Event = eventIndex,
	}

	delta.Duration = duration or 0
	local path = midas:GetPath()
	local eventFullPath = path.."/"..eventName

	if eventName == "Empty" then
		eventFullPath = path
	end
	return delta, "User/"..eventFullPath
end


function Profile:FireSeries(midas: Midas, eventName: string, timestamp: string, eventIndex: number, includeEndEvent: boolean): _Signal.Signal
	local deltaStates = {}
	for p, midas in pairs(self._Midaii) do
		local output = midas:Compile()

		if output then
			for k, v in pairs(output) do
				local fullPath = p.."/"..k
				writeDelta(fullPath, v, deltaStates, self._Prev)
			end
		end
	end

	local eventFullPath
	deltaStates, eventFullPath = self:_Format(midas, eventName, deltaStates, eventIndex, timestamp)

	local maid = _Maid.new()
	self._Maid:GiveTask(maid)

	local trigger = _Signal.new(); maid:GiveTask(trigger)
	local hasFired = false

	maid:GiveTask(trigger:Connect(function(duration)
		if hasFired == true then return end
		deltaStates.Duration = duration
		if includeEndEvent and midas.Living == true then
			self:_Fire(eventFullPath.."Start", deltaStates, midas._Tags, timestamp)
			self:Fire(midas, eventName.."Finish", midas:GetUTC(), eventIndex, duration)
		else
			self:_Fire(eventFullPath, deltaStates, midas._Tags, timestamp)
		end
		hasFired = true
		maid:Destroy()
	end))

	return trigger
end

--shoot it out to server
function Profile:Fire(midas: Midas, eventName: string, timestamp: string, eventIndex: number, duration: number?): nil 

	local deltaStates = {}

	for p, midas in pairs(self._Midaii) do
		local output = midas:Compile()
		if output then
			for k, v in pairs(output) do
				local fullPath = p.."/"..k
				writeDelta(fullPath, v, deltaStates, self._Prev)
			end
		end
	end
	
	deltaStates.Id = deltaStates.Id or {}
	deltaStates.Id.Place = tostring(game.PlaceId)
	deltaStates.Id.Session = tostring(self._SessionId)
	deltaStates.Id.User = tostring(self.Player.UserId)

	local eventFullPath
	deltaStates, eventFullPath = self:_Format(midas, eventName, deltaStates, eventIndex, duration, timeStamp)

	self:_Fire(eventFullPath, deltaStates, midas._Tags, timeStamp)
end

function Profile:HasPath(midas: Midas, path: string): boolean
	local mPath = midas:GetPath()
	local pLen = string.len(path)
	return string.find(mPath, path) and path == string.sub(mPath, 1, pLen)
end

function Profile:DestroyPath(path: string): nil
	local pLen = string.len(path)
	for k, midas in pairs(self._Midaii) do
		if self:HasPath(midas, path) then
			self:DestroyMidas(k)
		end
	end
end

function Profile:DestroyMidas(path: string): nil
	local midas = self._Midaii[path]
	if midas then
		midas:Destroy()
	end
end

function Profile:SetMidas(midas)
	local path = midas:GetPath()
	self._Midaii[path] = midas

	midas.Instance.Parent = self.Instance

	for kPath, vChance in pairs(Config.Chances) do
		if self:HasPath(midas, kPath) then
			midas:SetChance(vChance)
		end
	end

	self._Maid[path] = midas
	self._Maid[path.."_Destroy"] = midas.Destroying:Connect(function()
		self._Midaii[path] = nil
	end)

	return self
end

function Profile.getProfilesFolder(): Folder
	return ProfilesFolder
end

function Profile:_Export()
	return {
		_Prev = self._Prev,
		_SessionId = self._SessionId,
		_PlayerId = self._PlayerId,
	}
end

function Profile:Teleport()
	self._IsTeleporting = true
	local output = self:_Export()
	self._mExit:Fire("Teleport")
	self:Destroy()
	return output
end

function Profile.new(player: Player): Profile
	local inst = Instance.new("Folder")
	inst.Name = tostring(player.UserId)
	inst.Parent = ProfilesFolder

	local self = setmetatable({
		_Maid = _Maid.new(),
		Player = player,
		["Instance"] = inst,
		_IsAlive = true,
		EventsPerMinute = 0,
		TimeDifference = 0,
		_ConstructionTick = tick(),
		_IsTeleporting = false,
		_WasTeleported = false,
		_Index = 0,
		_Midaii = {},
		_Prev = {},
		_SessionId = nil,
		_PlayerId = nil,
	}, Profile)

	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData

	if teleportData == nil or teleportData.MidasAnalyticsData == nil then
		self._Prev = {}
		self._SessionId, self._PlayerId = PlayFab:Register(tostring(self.Player.UserId))
	else
		self._WasTeleported = true
		local midasData = teleportData.MidasAnalyticsData
		self._Prev = midasData._Prev
		self._SessionId = midasData._SessionId
		self._PlayerId = midasData._PlayerId
	end

	local preExistingProfile: Profile? = REGISTRY[self.Player.UserId]
	if preExistingProfile then
		preExistingProfile:Destroy()
		REGISTRY[self.Player.UserId] = nil
	end
	REGISTRY[self.Player.UserId] = self :: any

	return self :: any
end

function Profile.get(userId: number)
	local function getProfile(attempt: number?)
		attempt = attempt or 1
		assert(attempt ~= nil)

		if attempt > 10/0.1 then return end

		local result: Profile? = REGISTRY[userId] :: any

		if result == nil then
			task.wait(0.1)
			return getProfile(attempt + 1)
		else
			return result
		end
	end
	return getProfile(userId)
end

if RunService:IsServer() then

	Players.PlayerAdded:Connect(Profile.new)
	task.spawn(function()
		for i, player in ipairs(Players:GetChildren()) do
			Profile.new(player)
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
end


if RunService:IsServer() then
	local DestroyMidas = Network.getRemoteEvent("DestroyMidas")
	DestroyMidas.OnServerEvent:Connect(function(player: Player, eventKeyPath: string)
		local profile = Profile.get(player.UserId)
		if profile then
			profile:DestroyMidas(eventKeyPath)
		end
	end)
end

return Profile