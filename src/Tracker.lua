--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- References
local Package = script.Parent
local Packages = Package.Parent

-- Packages
local Maid = require(Packages:WaitForChild("Maid"))
local Signal = require(Packages:WaitForChild("Signal"))
local NetworkUtil = require(Packages:WaitForChild("NetworkUtil"))

-- Modules
local Config = require(script.Parent.Config)
local Profile = require(script.Parent.Profile)
local Types = require(script.Parent.Types)

type State = Types.State
type Profile = Types.Profile
export type Tracker = Types.PrivateTracker

-- Constants
local CONSTRUCT_KEY = "ConstructTracker"
local ON_CLIENT_FIRE_KEY = "OnClientFire"
local CLIENT_REGISTER = "ClientRegister"

-- Remote Events
local DestroyTracker = NetworkUtil.getRemoteEvent("DestroyTracker")

function log(message: string, player: Player?, path: string?)
	if Config.PrintLog then
		print("[", player, "]", "[tracker]", "[", path, "]", ":", message)
	end
end

--- @class Tracker
--- The heart of the entire framework, allowing for decentralized recording and organizing of in-game state and events.
local Tracker: Tracker = {} :: any
Tracker.__index = Tracker

--- Allows for the binding of state to the tracker object.
function Tracker:SetState(key: string, state: State)
	local s: any = rawget(self, "_States")
	local states: { [string]: State } = s
	assert(states ~= nil and typeof(states) == "table")

	local function stateToFunction(state: State): any
		if type(state) == "function" then
			return state
		elseif type(state) == "table" then
			local stateObj: any = state
			if stateObj.get then
				return function()
					return stateObj:get()
				end
			elseif stateObj.Get then
				return function()
					return stateObj:Get()
				end
			end
		end
		error("Bad state")
	end

	states[key] = stateToFunction(state)

	local keyCount = Tracker.GetBoundStateCount(self :: any)
	rawset(self, "_KeyCount", keyCount :: any)
	return nil
end

--- Destroys the tracker object
function Tracker:Destroy()
	if not self._IsAlive then
		return
	end
	log("destroy", self.Player, self.Path)
	self._IsAlive = false

	if RunService:IsServer() then
		for k, signal in pairs(self._SeriesSignal) do
			self._SeriesSignal[k] = nil
			signal:Fire()
		end
	else
		DestroyTracker:FireServer(self.Path)
	end
	self._OnDestroy:Fire()

	self._Maid:Destroy()

	setmetatable(self, nil)
	local tabl: any = self
	for k, v in pairs(tabl) do
		tabl[k] = nil
	end

	return nil
end

--- Adds a tag to all future events from the tracker object.
function Tracker:SetTag(key: string): nil
	self._Tags[key] = true
	return nil
end

--- Removes tag from all future events from the tracker object.
function Tracker:RemoveTag(key: string): nil
	self._Tags[key] = nil
	return nil
end

--- Allows for the binding of fire condition blockers. If any return false the tracker will not fire.
function Tracker:SetCondition(key: string, func: () -> boolean): nil
	self._Conditions[key] = func
	return nil
end

--- Sets the rounding precision of all numbers and vectors to 10^exp paramter. If not exponent parameter is provided it defaults to 0.
function Tracker:SetRoundingPrecision(exp: number?): nil
	self._RoundingPrecision = exp or 0
	return nil
end

function Tracker:_HandleCompile(): { [string]: any }?
	log("_compile", self.Player, self.Path)
	if not self._Loaded then
		return
	end
	local roundHistory = {}
	local function round(val: any): any
		if typeof(val) == "Vector3" then
			local x = round(val.X)
			local y = round(val.Y)
			local z = round(val.Z)
			return {
				X = x,
				Y = y,
				Z = z,
			}
		elseif typeof(val) == "Vector2" then
			local x = round(val.X)
			local y = round(val.Y)
			-- print("XY", x, y)
			return {
				X = x,
				Y = y,
			}
		elseif typeof(val) == "CFrame" then
			local p = round(val.Position)
			local xVector = round(val.XVector)
			local yVector = round(val.YVector)
			local zVector = round(val.ZVector)
			return {
				Pos = p,
				XVec = xVector,
				YVec = yVector,
				ZVec = zVector,
			}
		elseif type(val) == "number" then
			local mag = 10 ^ self._RoundingPrecision
			return math.round(val * mag) / mag
		elseif type(val) == "table" then
			if roundHistory[val] == nil then
				roundHistory[val] = true
				for k, v in pairs(val) do
					val[k] = round(v)
				end
			end
		end
		return val
	end

	local output = {}
	for k, v in pairs(self._States) do
		local success, msg = pcall(function()
			if v == nil then
				output[k] = "nil"
			elseif type(v) == "function" then
				local vFun: any = v
				local vOut = vFun()
				output[k] = round(vOut)
			elseif type(v) == "string" then
				output[k] = v
			else
				output[k] = round(v)
			end
		end)
		if not success then
			print(msg)
			warn("Error in solving for", k)
		end
	end
	return output
end

--- Creates a dictionary of values resulting from invoking the bound state functions / objects.
function Tracker:_Compile(): { [string]: any }? --server only
	log("compile", self.Player, self.Path)
	assert(RunService:IsServer() == true, "Compile can only be called on server")
	if self._Chance < math.random() then
		return
	end

	local output
	if self._IsClientManaged then
		if not self.Player:GetAttribute("IsExiting") then
			log("invoking client", self.Player, self.Path)
			assert(self._GetRenderOutput ~= nil)
			output = self._GetRenderOutput:InvokeClient(self.Player)
		else
			log("client not found", self.Player, self.Path)
			return
		end
	else
		output = self:_HandleCompile()
	end

	if output then
		local finalOutput: { [string]: any } = {}
		for k, v in pairs(output) do
			if typeof(v) == "Vector3" then
				finalOutput[k] = {
					X = v.X,
					Y = v.Y,
					Z = v.Z,
				}
			elseif typeof(v) == "Vector2" then
				finalOutput[k] = {
					X = v.X,
					Y = v.Y,
				}
			elseif typeof(v) == "Color3" then
				finalOutput[k] = v:ToHex()
			elseif typeof(v) == "EnumItem" then
				finalOutput[k] = v.Name
			else
				finalOutput[k] = v
			end
		end
		return finalOutput
	end
	return nil
end

--- Returns a UTC format compliant timestamp string from the current tick. An optional offset can be applied to this in seconds.
function Tracker:_GetUTC(offset: number?): string
	offset = offset or 0
	assert(offset ~= nil)
	local unixTime = (DateTime.now().UnixTimestampMillis / 1000) + offset

	local dateTime: DateTime = DateTime.fromUnixTimestamp(unixTime)
	local utc: any = dateTime:ToUniversalTime()

	return utc.Year
		.. "-"
		.. utc.Month
		.. "-"
		.. utc.Day
		.. " "
		.. utc.Hour
		.. ":"
		.. utc.Minute
		.. ":"
		.. utc.Second
		.. "."
		.. math.round((unixTime - math.floor(unixTime)) * 1000) --utc.Millisecond
end

--- Determines if a tracker object meets all the bound conditions.
function Tracker:CanFire(): boolean
	local allTrue = true
	for k, func in pairs(self._Conditions) do
		if func() ~= true then
			allTrue = false
		end
	end
	return allTrue
end

function Tracker:_FireSeries(
	eventName: string,
	data: { [string]: any }?,
	utc: string,
	waitDuration: number,
	includeEndEvent: boolean?
): nil
	log("_fire series", self.Player, eventName)
	assert(RunService:IsServer(), "Bad domain")
	waitDuration = waitDuration or 15
	includeEndEvent = if includeEndEvent == nil then false else includeEndEvent
	assert(includeEndEvent ~= nil)
	local t = tick()
	if self._LastFireTick[eventName] == nil then
		assert(self._Profile ~= nil)
		self._SeriesSignal[eventName] = self._Profile:FireSeries(
			self,
			eventName,
			data,
			utc,
			self._Index[eventName],
			self._Profile:IncrementIndex(),
			includeEndEvent
		)
	end
	self._FirstFireTick[eventName] = self._FirstFireTick[eventName] or t
	self._LastFireTick[eventName] = t
	self._Repetitions[eventName] = (self._Repetitions[eventName] or -1) + 1

	task.spawn(function()
		task.wait(waitDuration)
		local currentTick = tick()

		local signal = self._SeriesSignal[eventName]
		local lastTick = self._LastFireTick[eventName]
		local firstFire = self._FirstFireTick[eventName]

		if firstFire and lastTick and currentTick - lastTick >= waitDuration and signal ~= nil then
			-- local reps = self._Repetitions[eventName]

			signal:Fire(lastTick - firstFire)
			self._FirstFireTick[eventName] = nil
			self._LastFireTick[eventName] = nil
			self._Repetitions[eventName] = nil
		end
	end)
	return nil
end

function Tracker:_FireEvent(eventName: string, data: { [string]: any }?, utc: string): nil
	log("_fire event", self.Player, eventName)
	assert(RunService:IsServer(), "Bad domain")
	self._Index[eventName] = self._Index[eventName] or 0
	self._Index[eventName] += 1
	assert(self._Profile ~= nil)
	self._Profile:Fire(self, eventName, data, utc, self._Index[eventName], self._Profile:IncrementIndex())
	return nil
end

function Tracker:_Fire(
	eventName: string,
	data: { [string]: any }?,
	utc: string,
	seriesDuration: number?,
	includeEndEvent: boolean?
): nil
	log("_fire", self.Player, eventName)
	if RunService:IsServer() then
		if seriesDuration ~= nil then
			self:_FireSeries(eventName, data, utc, seriesDuration, includeEndEvent)
		else
			self:_FireEvent(eventName, data, utc)
		end
	else
		assert(self._OnClientFire ~= nil)
		self._OnClientFire:FireServer(eventName, data, utc, seriesDuration)
	end
	return nil
end

--- Fires an event. If series duration is included it will delay sending the event until that duration has passed. It can also fire an end event in that case.
function Tracker:Fire(
	eventName: string,
	data: { [string]: any }?,
	seriesDuration: number?,
	includeEndEvent: boolean?
): nil
	log("fire", self.Player, eventName)
	task.spawn(function()
		local utc = self:_GetUTC()
		if not self._Loaded then
			log("yielding until load", self.Player, eventName)
			self._OnLoad:Wait()
		end
		if self._Loaded == false then
			task.wait(1)
			log("trying to fire again", self.Player, eventName)
			self:Fire(eventName, data, seriesDuration, includeEndEvent)
		else
			if eventName == nil then
				eventName = "Event"
			end
			if self:CanFire() == false then
				log("can't fire, returning", self.Player, eventName)
				return
			end
			self:_Fire(eventName, data, utc, seriesDuration, includeEndEvent)
		end
	end)
	return nil
end

--- Forces the tracker object to roll the dice before firing future events. Default is 1, which will always fire the event.
function Tracker:SetChance(val: number): nil
	if not self._Loaded then
		self._OnLoad:Wait()
	end
	self._Chance = val
	return nil
end

--- Gets the number of states currently bound to the tracker object.
function Tracker:GetBoundStateCount(): number
	local count = 0
	for k, v in pairs(self._States) do
		count += 1
	end
	return count
end

function Tracker:_Load(player: Player, path: string, profile: Profile?, maid: Maid.Maid, onLoad: Signal.Signal)
	local inst: Folder?
	log("loading", player, path)
	if RunService:IsServer() then -- Server builds instance
		log("building server instances", player, path)	
		inst = Instance.new("Folder")
		assert(inst ~= nil)
		assert(profile ~= nil)
		inst.Name = path
		inst.Parent = profile.Instance
		log("built folder", player, path)
	else -- Client tries to find existing instance
		log("building client instances", player, path)
		-- Get profile folder
		local profFolders = Profile.getProfilesFolder()
		local profFolder = profFolders:WaitForChild(tostring(player.UserId), 5)
		assert(profFolder ~= nil)

		if time() < 15 then --give more slack when everything's loading in
			inst = profFolder:WaitForChild(path, 2) :: any?
		else
			inst = profFolder:WaitForChild(path, 0.1) :: any?
		end

		if inst == nil then -- Couldn't find instance, so one needs to be constructed
			NetworkUtil.invokeServer(CONSTRUCT_KEY, path)

			-- Waiting for server to construct
			local userId = self.Player.UserId
			inst = profFolder:WaitForChild(path, 15) :: any?
			local isPlayerInGameStill = false
			for i, player in ipairs(Players:GetChildren()) do
				if player:IsA("Player") and userId == player.UserId then
					isPlayerInGameStill = true
				end
			end
			if inst == nil then
				if isPlayerInGameStill then
					error("Didn't find " .. tostring(path))
				end
				return
			end
			assert(inst ~= nil)
		end
		log("found folder", player, path)
	end
	assert(inst ~= nil)
	maid:GiveTask(inst)
	rawset(self, "Instance", inst :: any)

	if RunService:IsServer() then
		--tells server Tracker that it should call client Tracker for rendering
		self._ClientRegister = NetworkUtil.getRemoteEvent(CLIENT_REGISTER, inst)
		maid:GiveTask(self._ClientRegister)
		assert(self._ClientRegister ~= nil)
		maid:GiveTask(self._ClientRegister.OnServerEvent:Connect(function(eventPlayer: Player)
			if eventPlayer == player then
				log("register", player, path)
				local onLoad: any = rawget(self, "_OnLoad")
				if not rawget(self, "_Loaded") then
					onLoad:Wait()
				end
				self._IsClientManaged = true
			end
		end))

		--list of client fires
		self._OnClientFire = NetworkUtil.getRemoteEvent(ON_CLIENT_FIRE_KEY, inst)
		maid:GiveTask(self._OnClientFire)
		assert(self._OnClientFire ~= nil)
		maid:GiveTask(
			self._OnClientFire.OnServerEvent:Connect(
				function(eventPlayer: Player, eventName: string, data: { [string]: any }?, utc: string, reps: number)
					if eventPlayer == player then
						log("client fired", player, path)
						if not rawget(self, "_Loaded") then
							onLoad:Wait()
						end
						Tracker._Fire(self :: any, eventName, data, utc, reps)
					end
				end
			)
		)

		--get render output from client
		self._GetRenderOutput = NetworkUtil.getRemoteFunction("GetRenderOutput", inst)
		maid:GiveTask(self._GetRenderOutput)
	else
		--register to server instance
		self._OnClientFire = NetworkUtil.getRemoteEvent(ON_CLIENT_FIRE_KEY, inst)
		self._ClientRegister = NetworkUtil.getRemoteEvent(CLIENT_REGISTER, inst)
		assert(self._ClientRegister ~= nil)
		self._ClientRegister:FireServer()

		--listen for render requests
		self._GetRenderOutput = NetworkUtil.getRemoteFunction("GetRenderOutput", inst)
		assert(self._GetRenderOutput ~= nil)
		self._GetRenderOutput.OnClientInvoke = function()
			log("render invoke", player, path)
			if not rawget(self, "_Loaded") then
				onLoad:Wait()
			end
			return Tracker._HandleCompile(self :: any)
		end
	end
	onLoad:Fire()
	return nil
end

function Tracker._new(player: Player, path: string, profile: Profile?): Tracker
	log("new", player, path)

	-- Construct instance.
	local maid = Maid.new()


	-- Create signals
	local onLoad = Signal.new()
	maid:GiveTask(onLoad)
	local onDestroy = Signal.new()
	maid:GiveTask(onDestroy)
	local onEvent = Signal.new()
	maid:GiveTask(onEvent)

	-- Build self
	local self = {
		["Instance"] = nil,

		_Loaded = false,
		_OnLoad = onLoad,
		_OnDestroy = onDestroy,
		_OnEvent = onEvent,

		_Maid = maid,

		_Profile = profile,
		Path = path,
		Player = player,
		_PlayerName = player.Name,

		_IsAlive = true,
		_RoundingPrecision = 1,
		_Chance = 1,
		_KeyCount = 0,
		_IsClientManaged = RunService:IsClient(),

		_Tags = {},
		_Conditions = {},
		_States = {},
		_FirstFireTick = {},
		_LastFireTick = {},
		_SeriesSignal = {},
		_Index = {},
		_Repetitions = {},
	}

	setmetatable(self, Tracker)

	maid:GiveTask(self._OnLoad:Connect(function()
		log("loaded", player, path)
		rawset(self :: any, "_Loaded", true)
	end))

	task.spawn(function()
		Tracker._Load(self :: any, player, path, profile, maid, onLoad)
	end)

	if RunService:IsServer() then
		assert(profile ~= nil)
		log("sending to profile", player, path)

		if profile._IsAlive then
			profile:SetTracker(self :: any)
		end
	end

	return self :: any
end

return Tracker
