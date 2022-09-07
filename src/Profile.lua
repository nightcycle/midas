--!strict
local RunService = game:GetService("RunService")

-- Packages
local _Package = script.Parent
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)

-- Modules
local Config = require(_Package.Config)
local PlayFab = require(_Package.PlayFab)
local Network = require(_Package.Network)
local Types = require(_Package.Types)

type State = Types.State
type Midas = Types.Midas
export type Profile = Types.Profile
export type TeleportDataEntry = Types.TeleportDataEntry

local REGISTRY: {[number]: Profile} = {}

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
	if lastValue ~= value or Config.SendDeltaState == false then
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

function Profile:_Fire(eventFullPath: string, delta: {[string]: any}, tags: {[string]: boolean}, timestamp: string)
	self.EventsPerMinute += 1
	
	task.delay(60, function()
		if self ~= nil and self._IsAlive ~= nil then
			self.EventsPerMinute -= 1
		end
	end)

	self.TimeDifference = tick() - self._ConstructionTick

	while self._IsAlive and self._PlayerId == nil do task.wait(0.1) end

	local pId = self._PlayerId
	assert(pId ~= nil)

	PlayFab:Fire(pId, eventFullPath, delta, tags, timestamp)
	return nil
end

function Profile:_Format(midas: Midas, eventName: string, delta: {[string]: any}, eventIndex: number, duration: number?, timestamp: string): ({[string]: any}, string)
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
				writeDelta(fullPath, v, deltaStates, self._PreviousStates)
			end
		end
	end

	local eventFullPath
	deltaStates, eventFullPath = self:_Format(midas, eventName, deltaStates, eventIndex, nil, timestamp)

	local maid = _Maid.new()
	self._Maid:GiveTask(maid)

	local trigger = _Signal.new(); maid:GiveTask(trigger)
	local hasFired = false

	maid:GiveTask(trigger:Connect(function(duration)
		if hasFired == true then return end
		deltaStates.Duration = duration
		if includeEndEvent and midas._IsAlive == true then
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
				writeDelta(fullPath, v, deltaStates, self._PreviousStates)
			end
		end
	end
	
	deltaStates.Id = deltaStates.Id or {}
	deltaStates.Id.Place = tostring(game.PlaceId)
	deltaStates.Id.Session = tostring(self._SessionId)
	deltaStates.Id.User = tostring(self.Player.UserId)

	local eventFullPath
	deltaStates, eventFullPath = self:_Format(midas, eventName, deltaStates, eventIndex, duration, timestamp)

	self:_Fire(eventFullPath, deltaStates, midas._Tags, timestamp)
	return nil
end

function Profile:HasPath(midas: Midas, path: string): boolean
	local mPath = midas:GetPath()
	local pLen = string.len(path)
	return string.find(mPath, path) and path == string.sub(mPath, 1, pLen)
end

function Profile:DestroyPath(path: string): nil
	for k, midas in pairs(self._Midaii) do
		if self:HasPath(midas, path) then
			self:DestroyMidas(k)
		end
	end
	return nil
end

function Profile:DestroyMidas(path: string): nil
	local midas = self._Midaii[path]
	if midas then
		midas:Destroy()
	end
	return nil
end

function Profile:GetMidas(path: string): Midas?
	return self._Midaii[path]
end

function Profile:SetMidas(midas)
	local path = midas:GetPath()
	self._Midaii[path] = midas

	local mInst = midas.Instance
	assert(mInst ~= nil)
	mInst.Parent = self.Instance

	self._Maid[path] = midas
	self._Maid[path.."_Destroy"] = midas.OnDestroy:Connect(function()
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
	local sId: string, pId: string
	if teleportData == nil or teleportData.MidasAnalyticsData == nil then
		prev = {}
		local userId = player.UserId
		sId, pId = PlayFab:Register(userId)
	else
		wasTeleported = true
		local midasData = teleportData.MidasAnalyticsData
		prev = midasData._PreviousStates
		sId = midasData._SessionId
		pId = midasData._PlayerId
	end

	local self = setmetatable({
		_Maid = _Maid.new(),
		Player = player,
		["Instance"] = inst,
		_IsAlive = true,
		EventsPerMinute = 0,
		TimeDifference = 0,
		_ConstructionTick = tick(),
		_IsTeleporting = false,
		_WasTeleported = wasTeleported,
		_Index = 0,
		_Midaii = {},
		_PreviousStates = prev,
		_SessionId = sId,
		_PlayerId = pId,
	}, Profile)

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
	local DestroyMidas = Network.getRemoteEvent("DestroyMidas")
	DestroyMidas.OnServerEvent:Connect(function(player: Player, eventKeyPath: string)
		local profile = Profile.get(player.UserId)
		if profile then
			profile:DestroyMidas(eventKeyPath)
		end
	end)
end

return Profile