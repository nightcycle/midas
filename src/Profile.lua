--!strict
local RunService = game:GetService("RunService")

-- Packages
local _Package = script.Parent
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)
local Network = require(_Packages.Network)

-- Modules
local Config = require(_Package.Config)
local PlayFab = require(_Package.PlayFab)
local Types = require(_Package.Types)

type State = Types.State
type Midas = Types.PrivateMidas
export type Profile = Types.Profile
export type TeleportDataEntry = Types.TeleportDataEntry

local REGISTRY: { [number]: Profile } = {}

local Profile: Profile = {} :: any
Profile.__index = Profile

local ProfilesFolder: Folder? = script:FindFirstChild("MidasProfiles") or Instance.new("Folder")
assert(ProfilesFolder ~= nil)
ProfilesFolder.Name = "MidasProfiles"
ProfilesFolder.Parent = script

function log(message: string, player: Player?, path: string?)
	if Config.PrintLog then
		print("[", player, "]", "[profile]", "[", path, "]", ":", message)
	end
end

function writePath(tabl: any, pathWords: string | { string }, val: any)
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

function readPath(tabl: any, pathWords: string | { string })
	if type(pathWords) == "string" then
		pathWords = string.split(pathWords, "/")
	end
	assert(typeof(pathWords) == "table")
	local nextKey = pathWords[1]

	if tabl[nextKey] == nil then
		return nil
	end

	if #pathWords == 1 then
		return tabl[nextKey]
	else
		table.remove(pathWords, 1)
		return readPath(tabl[nextKey], pathWords)
	end
end

function writeDelta(path: string, value: any, delta, old)
	local lastValue = readPath(old, path)
	if lastValue ~= value or Config.SendDeltaState == false then
		writePath(delta, path, value)
		writePath(old, path, value)
	end
end

function Profile:Destroy()
	if not self._IsAlive then
		return
	end
	log("destroy", self.Player)
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

function Profile:_Fire(eventFullPath: string, delta: { [string]: any }, tags: { [string]: boolean }, timestamp: string)
	log("_fire", self.Player, eventFullPath)
	self.EventsPerMinute += 1

	task.delay(60, function()
		if self ~= nil and self._IsAlive ~= nil then
			self.EventsPerMinute -= 1
		end
	end)

	self.TimeDifference = tick() - self._ConstructionTick

	task.spawn(function()
		local startTick = tick()
		while self._IsLoaded == false and tick() - startTick > 60 do
			task.wait(0.1)
		end
		assert(self._IsLoaded, "Profile still isn't loaded for "..tostring(eventFullPath))
		local pId = self._PlayerId
		assert(pId ~= nil)
	
		PlayFab:Fire(pId, eventFullPath, delta, tags, timestamp)
	end)

	return nil
end

function Profile:_Format(
	midas: Midas,
	eventName: string,
	delta: { [string]: any },
	eventIndex: number?,
	duration: number?,
	timestamp: string,
	index: number
): ({ [string]: any }, string)
	log("_format", midas._Player, eventName)

	delta.Index = {
		Total = index,
		Event = eventIndex,
	}

	delta.Version = {
		Major = Config.Version.Major,
		Minor = Config.Version.Minor,
		Patch = Config.Version.Patch,
		Tag = Config.Version.Tag,
		TestGroup = Config.Version.TestGroup,
		Build = game.PlaceVersion
	}

	delta.Duration = math.round(1000 * (duration or 0)) / 1000
	delta.IsStudio = RunService:IsStudio()
	local path = midas.Path

	local eventFullPath = path .. "/" .. eventName

	if eventName == "Empty" then
		eventFullPath = path
	end
	return delta, "User/" .. eventFullPath
end

function Profile:IncrementIndex(): number
	self._Index += 1
	return self._Index
end

function Profile:FireSeries(
	midas: Midas,
	eventName: string,
	timestamp: string,
	eventIndex: number,
	index: number,
	includeEndEvent: boolean
): _Signal.Signal
	log("fire series", midas._Player, eventName)
	local deltaStates = {}
	for p, midas in pairs(self._Midaii) do
		local output = midas:_Compile()

		if output then
			for k, v in pairs(output) do
				local fullPath = p .. "/" .. k
				writeDelta(fullPath, v, deltaStates, self._PreviousStates)
			end
		end
	end

	deltaStates.Id = deltaStates.Id or {}
	deltaStates.Id.Place = tostring(game.PlaceId)
	deltaStates.Id.Session = tostring(self._SessionId)
	deltaStates.Id.User = tostring(self.Player.UserId)

	local eventFullPath
	deltaStates, eventFullPath = self:_Format(midas, eventName, deltaStates, eventIndex, nil, timestamp, index)

	local maid = _Maid.new()
	self._Maid:GiveTask(maid)

	local trigger = _Signal.new()
	maid:GiveTask(trigger)
	local hasFired = false

	maid:GiveTask(trigger:Connect(function(duration)
		if hasFired == true then
			return
		end
		deltaStates.Duration = math.round(1000 * duration) / 1000
		if includeEndEvent and midas._IsAlive == true then
			self:_Fire(eventFullPath .. "Start", deltaStates, midas._Tags, timestamp)
			self:Fire(midas, eventName .. "Finish", midas:_GetUTC(), eventIndex, duration)
		else
			self:_Fire(eventFullPath, deltaStates, midas._Tags, timestamp)
		end
		hasFired = true
		maid:Destroy()
	end))

	return trigger
end

--shoot it out to server
function Profile:Fire(midas: Midas, eventName: string, timestamp: string, eventIndex: number, index: number, duration: number?): nil
	log("fire", midas._Player, eventName)
	local deltaStates = {}

	for p, midas in pairs(self._Midaii) do
		log("getting compile for " .. tostring(midas.Path), midas._Player, eventName)
		local output = midas:_Compile()
		if output then
			for k, v in pairs(output) do
				local fullPath = p .. "/" .. k
				writeDelta(fullPath, v, deltaStates, self._PreviousStates)
			end
		end
	end
	log("delta assembled", midas._Player, eventName)
	deltaStates.Id = deltaStates.Id or {}
	deltaStates.Id.Place = tostring(game.PlaceId)
	deltaStates.Id.Session = tostring(self._SessionId)
	deltaStates.Id.User = tostring(self.Player.UserId)

	local eventFullPath
	deltaStates, eventFullPath = self:_Format(midas, eventName, deltaStates, eventIndex, duration, timestamp, index)

	self:_Fire(eventFullPath, deltaStates, midas._Tags, timestamp)
	return nil
end

function Profile:HasPath(midas: Midas, path: string): boolean
	local mPath = midas.Path
	local pLen = string.len(path)
	return string.find(mPath, path) and path == string.sub(mPath, 1, pLen)
end

function Profile:DestroyPath(path: string): nil
	log("destroy path", self.Player, path)
	for k, midas in pairs(self._Midaii) do
		if self:HasPath(midas, path) then
			self:DestroyMidas(k)
		end
	end
	return nil
end

function Profile:DestroyMidas(path: string): nil
	log("destroy", self.Player, path)
	local midas = self._Midaii[path]
	if midas then
		midas:Destroy()
	end
	return nil
end

function Profile:GetMidas(path: string): Midas?
	log("get midas", self.Player, path)
	return self._Midaii[path]
end

function Profile:SetMidas(midas)
	local path = midas.Path
	self._Midaii[path] = midas

	local mInst = midas.Instance
	assert(mInst ~= nil)
	mInst.Parent = self.Instance

	self._Maid[path] = midas
	self._Maid[path .. "_Destroy"] = midas._OnDestroy:Connect(function()
		self._Midaii[path] = nil
	end)

	return nil
end

function Profile.getProfilesFolder(): Folder
	return ProfilesFolder
end

function Profile:_Export(): TeleportDataEntry
	local sId = self._SessionId
	local pId = self._PlayerId
	assert(sId ~= nil and pId ~= nil)

	return {
		_PreviousStates = self._PreviousStates,
		_SessionId = sId,
		_PlayerId = pId,
	}
end

function Profile:Teleport(mExit: Midas?): TeleportDataEntry
	self._IsTeleporting = true
	local output = self:_Export()

	if mExit then
		mExit:Fire("Teleport")
	end

	self:Destroy()

	return output
end

function Profile.new(player: Player): Profile
	local inst = Instance.new("Folder")
	inst.Name = tostring(player.UserId)
	inst.Parent = ProfilesFolder

	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData

	local prev = {}
	local wasTeleported = false


	local self = setmetatable({
		_Maid = _Maid.new(),
		Player = player,
		["Instance"] = inst,
		_IsAlive = true,
		EventsPerMinute = 0,
		TimeDifference = 0,
		_ConstructionTick = tick(),
		_IsTeleporting = false,
		_IsLoaded = false,
		_WasTeleported = wasTeleported,
		_Index = 0,
		_Midaii = {},
		_PreviousStates = prev,
		_SessionId = nil :: string?,
		_PlayerId = nil :: string?,
	}, Profile)

	local function load()
		if teleportData == nil or teleportData.MidasAnalyticsData == nil then
			prev = {}
			local userId = player.UserId
			self._SessionId, self._PlayerId = PlayFab:Register(userId)
		else
			wasTeleported = true
			local midasData = teleportData.MidasAnalyticsData
			prev = midasData._PreviousStates
			self._SessionId = midasData._SessionId
			self._PlayerId = midasData._PlayerId
		end
		self._IsLoaded = true
	end
	task.spawn(load)

	local preExistingProfile: Profile? = REGISTRY[self.Player.UserId]
	if preExistingProfile then
		preExistingProfile:Destroy()
		REGISTRY[self.Player.UserId] = nil
	end
	REGISTRY[self.Player.UserId] = self :: any

	return self :: any
end

function Profile.get(userId: number)
	log("get(" .. tostring(userId) .. ")", nil, nil)
	local function getProfile(attempt: number?)
		attempt = attempt or 1
		assert(attempt ~= nil)

		if attempt > 10 / 0.1 then
			return
		end

		local result: Profile? = REGISTRY[userId] :: any

		if result == nil then
			task.wait(0.2)
			log("retry get " .. tostring(attempt) .. "x (" .. tostring(userId) .. ")", nil, nil)
			return getProfile(attempt + 1)
		else
			if result then
				log("returning profile (" .. tostring(userId) .. ")", nil, nil)
			else
				log("returning nil (" .. tostring(userId) .. ")", nil, nil)
			end

			return result
		end
	end
	return getProfile()
end

if RunService:IsServer() then
	local DestroyMidas = Network.getRemoteEvent("DestroyMidas")
	DestroyMidas.OnServerEvent:Connect(function(player: Player, eventKeyPath: string)
		log("destroy midas event", player, eventKeyPath)
		local profile = Profile.get(player.UserId)
		if profile then
			log("firing profile destroy", player, eventKeyPath)
			profile:DestroyMidas(eventKeyPath)
		end
	end)
end

return Profile
