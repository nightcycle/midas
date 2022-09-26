--!strict
local RunService = game:GetService("RunService")

-- Packages
local _Package = script.Parent
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)
local _Math = require(_Packages.Math)
local Network = require(_Packages.Network)

-- Modules
local Profile = require(_Package.Profile)
local Types = require(_Package.Types)

type State = Types.State
type Profile = Types.Profile
export type Midas = Types.Midas

-- Remote Events
local ConstructMidas = Network.getRemoteEvent("ConstructMidas")
local DestroyMidas = Network.getRemoteEvent("DestroyMidas")

--- @class Midas
--- The heart of the entire framework, allowing for decentralized recording and organizing of in-game state and events.
local Midas: Midas = {} :: any
Midas.__index = Midas

--- Allows for the binding of state to the midas object.
function Midas:SetState(key: string, state: State)
	local s: any = rawget(self, "_States"); local states: {[string]: State} = s
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
	
	local keyCount = Midas.GetBoundStateCount(self :: any)
	rawset(self, "_KeyCount", keyCount :: any)
	return nil
end

--- Destroys the midas object
function Midas:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false

	if RunService:IsServer() then
		for k, signal in pairs(self._SeriesSignal) do
			self._SeriesSignal[k] = nil
			signal:Fire()
		end
	else
		DestroyMidas:FireServer(self._Path)
	end
	self.OnDestroy:Fire()

	self._Maid:Destroy()

	setmetatable(self, nil)
	local tabl: any = self
	for k, v in pairs(tabl) do
		tabl[k] = nil
	end

	return nil
end

--- Adds a tag to all future events from the midas object.
function Midas:SetTag(key: string): nil
	self._Tags[key] = true
	return nil
end

--- Removes tag from all future events from the midas object.
function Midas:RemoveTag(key: string): nil
	self._Tags[key] = nil
	return nil
end

--- Allows for the binding of fire condition blockers. If any return false the midas will not fire.
function Midas:SetCondition(key: string, func: () -> boolean): nil
	self._Conditions[key] = func
	return nil
end

--- Returns the hierarchy path the midas object was created under.
function Midas:GetPath(): string
	return self._Path
end

--- Sets the rounding precision of all numbers and vectors to 10^exp paramter. If not exponent parameter is provided it defaults to 0.
function Midas:SetRoundingPrecision(exp: number?): nil
	self._RoundingPrecision = exp or 0
	return nil
end

function Midas:_Compile(): {[string]: any}?
	if not self.Loaded then return end
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
				Y = y
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
				ZVec = zVector
			}
		elseif type(val) == "number" then
			local mag = 10^self._RoundingPrecision
			return math.round(val*mag)/mag
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
function Midas:Compile(): {[string]: any}? --server only

	assert(RunService:IsServer() == true, "Compile can only be called on server")
	if self._Chance < math.random() then return end

	local output
	if self._IsClientManaged then
		assert(self._GetRenderOutput ~= nil)
		output = self._GetRenderOutput:InvokeClient(self._Player)
	else
		output = self:_Compile()
	end

	if output then
		local finalOutput: {[string]: any} = {}
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
function Midas:GetUTC(offset: number?): string
	offset = offset or 0
	assert(offset ~= nil)
	local unixTime = (DateTime.now().UnixTimestampMillis/1000) + offset
	local dateTime: DateTime = DateTime.fromUnixTimestamp(unixTime)
	local utc: any = dateTime:ToUniversalTime()
	return utc.Year.."-"..utc.Month.."-"..utc.Day.." "..utc.Hour..":"..utc.Minute..":"..utc.Second.."."..utc.Millisecond
end

--- Determines if a midas object meets all the bound conditions.
function Midas:CanFire(): boolean
	local allTrue = true
	for k, func in pairs(self._Conditions) do
		if func() ~= true then
			allTrue = false
		end
	end
	return allTrue
end

function Midas:_FireSeries(eventName: string, utc: string, waitDuration: number, includeEndEvent: boolean?): nil
	assert(RunService:IsServer(), "Bad domain")
	waitDuration = waitDuration or 15
	includeEndEvent = if includeEndEvent == nil then false else includeEndEvent
	assert(includeEndEvent ~= nil)
	local t = tick()
	if self._LastFireTick[eventName] == nil then
		assert(self._Profile ~= nil)
		self._SeriesSignal[eventName] = self._Profile:FireSeries(self, eventName, utc, self._Index[eventName], includeEndEvent)
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

function Midas:_FireEvent(eventName: string, utc: string): nil
	assert(RunService:IsServer(), "Bad domain")
	self._Index[eventName] = self._Index[eventName] or 0
	self._Index[eventName] += 1
	assert(self._Profile ~= nil)
	self._Profile:Fire(self, eventName, utc, self._Index[eventName])
	return nil
end

function Midas:_Fire(eventName: string, utc: string, seriesDuration: number?, includeEndEvent: boolean?): nil
	if RunService:IsServer() then
		if seriesDuration ~= nil then
			self:_FireSeries(eventName, utc, seriesDuration, includeEndEvent)
		else
			self:_FireEvent(eventName, utc)
		end
	else
		assert(self._OnClientFire ~= nil)
		self._OnClientFire:FireServer(eventName, utc, seriesDuration)
	end
	return nil
end

--- Fires an event. If series duration is included it will delay sending the event until that duration has passed. It can also fire an end event in that case.
function Midas:Fire(eventName: string, seriesDuration: number?, includeEndEvent: boolean?): nil
	task.spawn(function()
		local utc = self:GetUTC()
		if not self.Loaded then self.OnLoad:Wait() end
		if self.Loaded == false then
			task.wait(1)
			self:Fire(eventName, seriesDuration, includeEndEvent)
		else
			if eventName == nil then eventName = "Event" end
			if self:CanFire() == false then return end
			self:_Fire(eventName, utc, seriesDuration, includeEndEvent)
		end
	end)
	return nil
end

--- Forces the midas object to roll the dice before firing future events. Default is 1, which will always fire the event.
function Midas:SetChance(val: number): nil
	if not self.Loaded then self.OnLoad:Wait() end
	self._Chance = val
	return nil
end

--- Gets the number of states currently bound to the midas object.
function Midas:GetBoundStateCount(): number
	local count = 0
	for k, v in pairs(self._States) do
		count += 1
	end
	return count
end

function Midas:_Load(player: Player, path: string, profile: Profile?, maid: _Maid.Maid, onLoad: _Signal.Signal)
	local inst: Folder?

	if RunService:IsServer() then 	-- Server builds instance
		
		inst = Instance.new("Folder")
		assert(inst ~= nil)
		assert(profile ~= nil)
		inst.Name = path
		inst.Parent = profile.Instance
		
	else -- Client tries to find existing instance
	
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

			ConstructMidas:FireServer(path)

			 -- Waiting for server to construct
			inst = profFolder:WaitForChild(path,15) :: any?

			assert(inst ~= nil, "Didn't find "..tostring(path))
		end
	end
	assert(inst ~= nil)
	maid:GiveTask(inst)
	rawset(self, "Instance", inst :: any)
	
	if RunService:IsServer() then

		--tells server Midas that it should call client Midas for rendering
		self._ClientRegister = Network.getRemoteEvent("ClientRegister", inst)
		maid:GiveTask(self._ClientRegister)
		assert(self._ClientRegister ~= nil)
		maid:GiveTask(self._ClientRegister.OnServerEvent:Connect(function(eventPlayer: Player)

			if eventPlayer == player then
				local onLoad: any = rawget(self, "OnLoad")
				if not rawget(self, "Loaded") then onLoad:Wait() end
				self._IsClientManaged = true
			end
		end))

		--list of client fires
		self._OnClientFire = Network.getRemoteEvent("OnClientFire", inst)
		maid:GiveTask(self._OnClientFire)
		assert(self._OnClientFire ~= nil)
		maid:GiveTask(self._OnClientFire.OnServerEvent:Connect(function(eventPlayer: Player, eventName: string, utc: string, reps: number)
			
			if eventPlayer == player then

				if not rawget(self, "Loaded") then 
					
					onLoad:Wait() 
				end
				Midas._Fire(self :: any, eventName, utc, reps)
			end
		end))

		--get render output from client
		self._GetRenderOutput = Network.getRemoteFunction("GetRenderOutput", inst)
		maid:GiveTask(self._GetRenderOutput)

	else
		--register to server instance
		self._OnClientFire = Network.getRemoteEvent("OnClientFire", inst)
		self._ClientRegister = Network.getRemoteEvent("ClientRegister", inst)
		assert(self._ClientRegister ~= nil)
		self._ClientRegister:FireServer()

		--listen for render requests
		self._GetRenderOutput = Network.getRemoteFunction("GetRenderOutput", inst)
		assert(self._GetRenderOutput ~= nil)
		self._GetRenderOutput.OnClientInvoke = function()
			if not rawget(self, "Loaded") then 
				onLoad:Wait() 
			end
			return Midas._Compile(self :: any)
		end

	end
	onLoad:Fire()
	return nil
end

function Midas.new(player: Player, path: string): Midas
	local profile = if RunService:IsServer() then Profile.get(player.UserId) else nil

	-- Construct instance.
	local maid =  _Maid.new()
	
	-- Create signals
	local onLoad = _Signal.new(); maid:GiveTask(onLoad)
	local onDestroy = _Signal.new(); maid:GiveTask(onDestroy)
	local onEvent = _Signal.new(); maid:GiveTask(onEvent)

	-- Build self
	local self = {
		["Instance"] = nil,

		Loaded = false,
		OnLoad = onLoad,
		OnDestroy = onDestroy,
		OnEvent = onEvent,

		_Maid = maid,

		_Profile = profile,
		_Path = path,
		_Player = player,

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

	setmetatable(self, Midas)

	maid:GiveTask(self.OnLoad:Connect(function()
		rawset(self :: any, "Loaded", true)
	end))

	task.spawn(function()
		Midas._Load(self::any, player, path, profile, maid, onLoad)
	end)

	if RunService:IsServer() then
		assert(profile ~= nil)
		profile:SetMidas(self :: any)
	end

	return self :: any
end

-- Handle construction requests from client
if RunService:IsServer() then
	ConstructMidas.OnServerEvent:Connect(function(player, eventKeyPath)
		Midas.new(player, eventKeyPath)
	end)
end

return Midas