local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
if not runService:IsServer() then return {} end

local package = script.Parent
local packages = package.Parent

local maidConstructor = require(packages:WaitForChild("maid"))
local signalConstructor = require(packages:WaitForChild("signal"))
local playFab = require(package:WaitForChild("PlayFab"))
local config = require(package:WaitForChild("Config"))

local analytics --set in init
local registry = {}
local profilesFolder = replicatedStorage:FindFirstChild("MidasProfiles") or Instance.new("Folder", replicatedStorage)
profilesFolder.Name = "MidasProfiles"

function writePath(tabl, pathWords, val)
	-- print("Tabl", tabl, "Path", pathWords, "V", val)
	if type(pathWords) == "string" then
		pathWords = string.split(pathWords, "/")
	end
	-- print("Post tabl", pathWords)
	local nextKey = pathWords[1]
	-- assert(tabl == nil, "Bad table")
	assert(nextKey ~= nil, "Bad key")
	table.remove(pathWords, 1)
	if #pathWords == 0 then
		tabl[nextKey] = val
	elseif tabl[nextKey] then
		-- table.remove(pathWords, 1)
		writePath(tabl[nextKey], pathWords, val)
	else
		tabl[nextKey] = {}
		writePath(tabl[nextKey], pathWords, val)
	end
end

function readPath(tabl, pathWords)
	-- print("Tabl", tabl, "Words", pathWords)
	if type(pathWords) == "string" then
		pathWords = string.split(pathWords, "/")
	end
	local nextKey = pathWords[1]

	if tabl[nextKey] == nil then return nil end
	
	if #pathWords == 1 then
		return tabl[nextKey]
	else
		table.remove(pathWords, 1)
		return readPath(tabl[nextKey], pathWords)
	end
end

function writeDelta(path, value, delta, old)
	local lastValue = readPath(old, path)
	if lastValue ~= value then
		writePath(delta, path, value)
		writePath(old, path, value)
	end
end

function readDelta(path, value, delta, old)
	local lastValue = readPath(old, path)
	if lastValue ~= value then
		writePath(delta, path, value)
	end
end


local Profile = {}
Profile.__type = "Profile"
Profile.__index = Profile

function Profile:Destroy()
	registry[self._player] = nil
	self._maid:Destroy()
end

function Profile:_Fire(eventFullPath, delta, tags, timeStamp)

	-- logger:Log("_Fire: "..tostring(eventFullPath).." for "..tostring(self._player.Name))
	-- eventFullPath = string.upper(eventFullPath)

	-- print("Previous", self._prev)
	self.EventsPerMinute += 1
	task.delay(60, function()
		if self ~= nil and self._mServerPerformance ~= nil then
			self.EventsPerMinute -= 1
		end
	end)
	self.TimeDifference = tick() - self._constructionTick


	local history = {}
	local function toUpper(val)
		return val
		-- if type(val) == "table" and history[val] == nil then
		-- 	history[val] = true
		-- 	local newTabl = {}
		-- 	for k, v in pairs(val) do
		-- 		newTabl[toUpper(k)] = toUpper(v)
		-- 	end
		-- 	return newTabl
		-- elseif type(val) ~= "table" then
		-- 	return string.upper(tostring(val))
		-- end
	end
	-- logger:Log("Waiting for instance: "..tostring(eventFullPath).." for "..tostring(self._player.Name))
	while self.Instance ~= nil and self._pId == nil do task.wait(0.1) end
	-- logger:Log("Firing to PlayFab: "..tostring(eventFullPath).." for "..tostring(self._player.Name))
	playFab:Fire(self._pId, toUpper(eventFullPath), toUpper(delta), toUpper(tags), toUpper(timeStamp))
end

function Profile:_Format(midas, eventName, delta, eventIndex, duration, ts)
	self._index += 1
	delta.Index = {
		Total = self._index,
		Event = eventIndex,
	}
	-- delta.UTC = ts
	delta.Duration = duration or 0
	local path = midas:GetPath()
	local eventFullPath = path.."/"..eventName
	if eventName == "Empty" then
		eventFullPath = path
	end
	return delta, "User/"..eventFullPath
end


function Profile:FireSeries(midas, eventName: string, timeStamp: string, eventIndex: string, includeEndEvent: boolean)
	-- logger:Log("_FireSeries: "..tostring(eventName).." for "..tostring(self._player.Name))
	local deltaStates = {}
	for p, midas in pairs(self._midaii) do
		local output = midas:Render()

		if output then
			for k, v in pairs(output) do
				local fullPath = p.."/"..k
				writeDelta(fullPath, v, deltaStates, self._prev)
			end
		end
	end

	local eventFullPath
	deltaStates, eventFullPath = self:_Format(midas, eventName, deltaStates, eventIndex, timeStamp)

	local maid = maidConstructor.new()
	self._maid:GiveTask(maid)
	local trigger = signalConstructor.new()
	local hasFired = false
	maid:GiveTask(trigger:Connect(function(duration)
		if hasFired == true then return end
		deltaStates.Duration = duration
		if includeEndEvent and midas.Living == true then
			self:_Fire(eventFullPath.."Start", deltaStates, midas._tags, timeStamp)
			self:Fire(midas, eventName.."Finish", midas:GetUTC(), eventIndex, duration)
		else
			self:_Fire(eventFullPath, deltaStates, midas._tags, timeStamp)
		end
		hasFired = true
		maid:Destroy()
	end))
	return trigger
end

function Profile:Fire(midas, eventName, timeStamp, eventIndex, duration) --shoot it out to server
	-- logger:Log("Fire called: "..tostring(eventName).." for "..tostring(self._player.Name))
	local deltaStates = {}

	-- print("Midaii", self._midaii)
	for p, midas in pairs(self._midaii) do
		local output = midas:Render()
		-- print(p, output)
		if output then
			for k, v in pairs(output) do
				local fullPath = p.."/"..k
				writeDelta(fullPath, v, deltaStates, self._prev)
			end
		end
	end
	
	deltaStates.Id = deltaStates.Id or {}
	deltaStates.Id.Place = tostring(game.PlaceId)
	deltaStates.Id.Session = tostring(self._sId)
	deltaStates.Id.User = tostring(self._player.UserId)


	local eventFullPath
	deltaStates, eventFullPath = self:_Format(midas, eventName, deltaStates, eventIndex, duration, timeStamp)

	self:_Fire(eventFullPath, deltaStates, midas._tags, timeStamp)
end

function Profile:HasPath(midas, path)
	local mPath = midas:GetPath()
	local pLen = string.len(path)
	return string.find(mPath, path) and path == string.sub(mPath, 1, pLen)
end

function Profile:DestroyPath(path)
	local pLen = string.len(path)
	for k, midas in pairs(self._midaii) do
		if self:HasPath(midas, path) then
			self:DestroyMidas(k)
		end
	end
end

function Profile:DestroyMidas(path)
	local midas = self._midaii[path]
	if midas then
		midas:Destroy()
	end
end

function Profile:SetMidas(midas)
	local path = midas:GetPath()
	-- print("Set Midas", path, midas)
	self._midaii[path] = midas

	midas.Instance.Parent = self.Instance

	for kPath, vChance in pairs(config.Chances) do
		if self:HasPath(midas, kPath) then
			midas:SetChance(vChance)
		end
	end

	self._maid[path] = midas
	self._maid[path.."_Destroy"] = midas.Destroying:Connect(function()
		self._midaii[path] = nil
	end)

	return self
end

function Profile:_Export()
	return {
		_prev = self._prev,
		_sId = self._sId,
		_pId = self._pId,
	}
end

function Profile:Teleport()
	self._isTeleporting = true
	local output = self._Export
	self._mExit:Fire("Teleport")
	self:Destroy()
	return output
end

function Profile.new(player)
	local self = setmetatable({}, Profile)
	
	self._maid = maidConstructor.new()
	self._maid:GiveTask(self)

	self._player = player
	self.Instance = Instance.new("Folder", profilesFolder)
	self.Instance.Name = tostring(player.UserId)
	self.EventsPerMinute = 0

	self._constructionTick = tick()
	self._isTeleporting = false
	self._wasTeleported = false
	self._index = 0
	self._midaii = {}

	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	-- print("Profile created")
	if teleportData == nil or teleportData.MidasAnalyticsData == nil then
		-- print("Not teleported")
		self._prev = {}
		self._sId, self._pId = playFab:Register(tostring(self._player.UserId))
		-- print("Result", self._sId, self._pId)
	else
		-- print("Teleported")
		self._wasTeleported = true
		local midasData = teleportData.MidasAnalyticsData
		self._prev = midasData._prev
		self._sId = midasData._sId
		self._pId = midasData._pId
	end

	registry[tostring(self._player.UserId)] = self

	return self
end

function Profile.get(playerOrUserId, attempt)
	attempt = attempt or 1
	if attempt > 10/0.1 then return end
	local result
	if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
		result = registry[tostring(playerOrUserId.UserId)]
	else
		result = registry[tostring(playerOrUserId)]
	end
	if result == nil then
		task.wait(0.1)
		return Profile.get(playerOrUserId, attempt + 1)
	else
		return result
	end
end

function Profile.init(a)
	analytics = a
end

function newPlayer(player)
	if registry[player] then
		registry[player]:Destroy()
		registry[player] = nil
	end
	local profile = Profile.new(player)
	if profile then
		analytics:LoadDefault(player)
	end
end

players.PlayerAdded:Connect(newPlayer)
task.spawn(function()
	for i, player in ipairs(game.Players:GetChildren()) do
		newPlayer(player)
	end
end)

game.Players.PlayerRemoving:Connect(function(player)
	local profile = Profile.get(player.UserId)
	if profile then
		task.delay(15, function()
			profile:Destroy()
		end)
	end
end)

return Profile