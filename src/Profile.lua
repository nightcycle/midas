--!strict
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- References
local Package = script.Parent
local Packages = Package.Parent

-- Packages
local Maid = require(Packages:WaitForChild("Maid"))
local Signal = require(Packages:WaitForChild("Signal"))

-- Modules
local Config = require(script.Parent.Config)
local PlayFab = require(script.Parent.PlayFab)
local Types = require(script.Parent.Types)

type State = Types.State
type Tracker = Types.PrivateTracker
export type Profile = Types.Profile
export type TeleportDataEntry = Types.TeleportDataEntry

local REGISTRY: { [number]: Profile } = {}

local Profile: Profile = {} :: any
Profile.__index = Profile

local ProfilesFolder = assert(script:WaitForChild("MidasProfiles", 10) or Instance.new("Folder")) :: Folder
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
	
	local charCount = string.len(HttpService:JSONEncode(delta))
	self._BytesRemaining -= charCount

	task.delay(60, function()
		if self ~= nil and self._IsAlive ~= nil then
			self.EventsPerMinute -= 1
			self._BytesRemaining += charCount
		end
	end)

	self.TimeDifference = tick() - self._ConstructionTick

	task.spawn(function()
		local startTick = tick()
		while self._IsLoaded == false and tick() - startTick < 60 do
			task.wait(0.1)
		end
		assert(self._IsLoaded, "Profile still isn't loaded for " .. tostring(eventFullPath))
		local pId = self._PlayerId
		assert(pId ~= nil)

		PlayFab:Fire(pId, eventFullPath, delta, tags, timestamp)
	end)

	return nil
end

function Profile:_Format(
	tracker: Tracker,
	eventName: string,
	data: { [string]: any }?,
	delta: { [string]: any },
	eventIndex: number?,
	duration: number?,
	timestamp: string,
	index: number
): ({ [string]: any }, string)
	log("_format", tracker._Player, eventName)

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
		Build = game.PlaceVersion,
	}


	delta.Duration = math.round(1000 * (duration or 0)) / 1000
	delta.IsStudio = RunService:IsStudio()
	local path = tracker.Path

	local eventFullPath = path .. "/" .. eventName

	if eventName == "Empty" then
		eventFullPath = path
	end

	if data then
		local currentAccessPoint: {[string]: any} = delta
		local keys = string.split(eventFullPath, "/")
		for i, k in ipairs(keys) do
			if i < #keys then
				if not currentAccessPoint[k] then
					currentAccessPoint[k] = {}
				elseif typeof(currentAccessPoint[k]) ~= "table" then
					currentAccessPoint["_"..k] = currentAccessPoint[k]
					currentAccessPoint[k] = {}
				end
				currentAccessPoint = currentAccessPoint[k]
			end
		end
		currentAccessPoint[keys[#keys]] = data
	end

	return delta, "User/" .. eventFullPath
end

function Profile:IncrementIndex(): number
	log("increment index", self.Player)
	self._Index += 1
	return self._Index
end

function Profile:FireSeries(
	tracker: Tracker,
	eventName: string,
	data: { [string]: any }?,
	timestamp: string,
	eventIndex: number,
	index: number,
	includeEndEvent: boolean
): Signal.Signal
	log("fire series", tracker._Player, eventName)
	local deltaStates = {}
	if self._BytesRemaining > 0 then
		for p, tracker in pairs(self._Midaii) do
			local output = tracker:_Compile()

			if output then
				for k, v in pairs(output) do
					local fullPath = p .. "/" .. k
					writeDelta(fullPath, v, deltaStates, self._PreviousStates)
				end
			end
		end
	end
	deltaStates.Id = deltaStates.Id or {}
	deltaStates.Id.Place = tostring(game.PlaceId)
	deltaStates.Id.Session = tostring(self._SessionId)
	deltaStates.Id.User = tostring(self.Player.UserId)

	local eventFullPath
	deltaStates, eventFullPath = self:_Format(tracker, eventName, data, deltaStates, eventIndex, nil, timestamp, index)

	local maid = Maid.new()
	self._Maid:GiveTask(maid)

	local trigger = Signal.new()
	maid:GiveTask(trigger)
	local hasFired = false

	maid:GiveTask(trigger:Connect(function(duration)
		if hasFired == true then
			return
		end
		deltaStates.Duration = math.round(1000 * duration) / 1000
		if includeEndEvent and tracker._IsAlive == true then
			self:_Fire(eventFullPath .. "Start", deltaStates, tracker._Tags, timestamp)
			self:Fire(tracker, eventName .. "Finish", data, tracker:_GetUTC(), eventIndex, duration)
		else
			self:_Fire(eventFullPath, deltaStates, tracker._Tags, timestamp)
		end
		hasFired = true
		maid:Destroy()
	end))

	return trigger
end

--shoot it out to server
function Profile:Fire(
	tracker: Tracker,
	eventName: string,
	data: { [string]: any }?,
	timestamp: string,
	eventIndex: number,
	index: number,
	duration: number?
): nil
	log("fire", tracker._Player, eventName)
	local deltaStates = {}

	if self._BytesRemaining > 0 then

		for p, tracker in pairs(self._Midaii) do
			log("getting compile for " .. tostring(tracker.Path), tracker._Player, eventName)
			local output = tracker:_Compile()
			if output then
				for k, v in pairs(output) do
					local fullPath = p .. "/" .. k
					writeDelta(fullPath, v, deltaStates, self._PreviousStates)
				end
			end
		end
		
	end

	log("delta assembled", tracker._Player, eventName)
	deltaStates.Id = deltaStates.Id or {}
	deltaStates.Id.Place = tostring(game.PlaceId)
	deltaStates.Id.Session = tostring(self._SessionId)
	deltaStates.Id.User = tostring(self.Player.UserId)

	local eventFullPath
	deltaStates, eventFullPath =
		self:_Format(tracker, eventName, data, deltaStates, eventIndex, duration, timestamp, index)

	self:_Fire(eventFullPath, deltaStates, tracker._Tags, timestamp)
	return nil
end

function Profile:HasPath(tracker: Tracker, path: string): boolean
	log("has path", self.Player, path)
	local mPath = tracker.Path
	local pLen = string.len(path)
	local f1 = string.find(mPath, path) ~= nil
	local f2 = path == string.sub(mPath, 1, pLen)
	return f1 and f2
end

function Profile:DestroyPath(path: string): nil
	log("destroy path", self.Player, path)
	for k, tracker in pairs(self._Midaii) do
		if self:HasPath(tracker, path) then
			self:DestroyTracker(k)
		end
	end
	return nil
end

function Profile:DestroyTracker(path: string): nil
	log("destroy tracker", self.Player, path)
	local tracker = self._Midaii[path]
	if tracker then
		tracker:Destroy()
	end
	return nil
end

function Profile:GetTracker(path: string): Tracker?
	log("get tracker", self.Player, path)
	return self._Midaii[path]
end

function Profile:SetTracker(tracker)
	log("set tracker", self.Player)
	local path = tracker.Path
	self._Midaii[path] = tracker

	local mInst = tracker.Instance
	assert(mInst ~= nil)
	mInst.Parent = self.Instance

	self._Maid[path] = tracker
	self._Maid[path .. "_Destroy"] = tracker._OnDestroy:Connect(function()
		self._Midaii[path] = nil
	end)

	return nil
end

function Profile.getProfilesFolder(): Folder
	log("get profiles folder")
	return ProfilesFolder
end

function Profile:_Export(): TeleportDataEntry
	log("_export", self.Player)
	local sId = self._SessionId
	local pId = self._PlayerId
	assert(sId ~= nil and pId ~= nil)

	return {
		_PreviousStates = self._PreviousStates,
		_SessionId = sId,
		_PlayerId = pId,
	}
end

function Profile:Teleport(mExit: Tracker?): TeleportDataEntry
	log("teleport", self.Player)
	self._IsTeleporting = true
	local output = self:_Export()

	if mExit then
		mExit:Fire("Teleport")
	end

	self:Destroy()

	return output
end

function Profile.new(player: Player): Profile
	log("new profile", player)
	local inst = Instance.new("Folder")
	inst.Name = tostring(player.UserId)
	inst.Parent = ProfilesFolder

	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData

	local prev = {}
	local wasTeleported = false

	local self = setmetatable({
		_Maid = Maid.new(),
		Player = player,
		["Instance"] = inst,
		_IsAlive = true,
		EventsPerMinute = 0,
		TimeDifference = 0,
		_BytesRemaining = Config.BytesPerMinutePerPlayer,
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
		log("loading profile", player)
		if teleportData == nil or teleportData.MidasAnalyticsData == nil then
			prev = {}
			local userId = player.UserId
			log("registering with playfab", player)
			self._SessionId, self._PlayerId = PlayFab:Register(userId)
		else
			log("retrieving teleport data", player)
			wasTeleported = true
			local midasData = teleportData.MidasAnalyticsData
			prev = midasData._PreviousStates
			self._SessionId = midasData._SessionId
			self._PlayerId = midasData._PlayerId
		end
		log("load complete", player)
		self._IsLoaded = true
	end
	task.spawn(load)

	return self :: any
end


return Profile
