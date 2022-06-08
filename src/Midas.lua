local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local package = script.Parent
local packages = package.Parent

local maidConstructor = require(packages:WaitForChild("maid"))
local signalConstructor = require(packages:WaitForChild("signal"))
local profile = require(package:WaitForChild("Profile"))

--[=[
	@class Midas
	-- a data collection object used to easily store and organize data across the client and server
]=]
local Midas = {}
Midas.__index = Midas
Midas.__type = "Midas"
Midas.ClassName = "Midas"

local constructMidas
local destroyMidas
if runService:IsServer() then
	constructMidas = replicatedStorage:FindFirstChild("ConstructMidas") or Instance.new("RemoteEvent", replicatedStorage)
	constructMidas.Name = "ConstructMidas"
	constructMidas.OnServerEvent:Connect(function(player, eventKeyPath)
		Midas.new(player, eventKeyPath)
	end)

	destroyMidas = replicatedStorage:FindFirstChild("DestroyMidas") or Instance.new("RemoteEvent", replicatedStorage)
	destroyMidas.Name = "DestroyMidas"
	destroyMidas.OnServerEvent:Connect(function(player, eventKeyPath)
		local profile = profile.get(player)
		if profile then
			profile:DestroyMidas(eventKeyPath)
		end
	end)
else
	constructMidas = replicatedStorage:WaitForChild("ConstructMidas")
	destroyMidas = replicatedStorage:WaitForChild("DestroyMidas")
end

function stateToFunction(state)
	if type(state) == "function" then
		return state
	elseif type(state) == "table" then
		if state.get then
			return function()
				return state:get()
			end
		elseif state.Get then
			return function()
				return state:Get()
			end
		end
	end
end

function Midas:__index(index)
	local current = rawget(self,index)
	if rawget(self,index) ~= nil then return rawget(self,index) end
	if rawget(Midas,index) ~= nil then return rawget(Midas,index) end
	return rawget(self,"_states")[index]
end

function Midas:__newindex(index, newState)
	if rawget(self, index) ~= nil then rawset(self, index, newState) return end
	local func = stateToFunction(newState)
	if func then
		rawget(self, "_states")[index] = func
	else
		rawget(self, "_states")[index] = tostring(newState)
	end
	rawset(self, "_keyCount", rawget(Midas,"GetKeyCount")(self))
end

function Midas:Destroy()
	if runService:IsServer() then
		for k, signal in ipairs(self._seriesSignal) do
			self._seriesSignal[k] = nil
			signal:Fire()
		end
	else
		destroyMidas:FireServer(self._path)
	end
	self.Destroying:Fire()
	self.profile = nil
	self._maid:Destroy()
end

function Midas:SetTag(key)
	self._tags[key] = true
end

function Midas:RemoveTag(key)
	self._tags[key] = nil
end

function Midas:SetCondition(key, func)

	self._conditions[key] = func
end

function Midas:GetPath()
	return self._path
end

function Midas:SetRoundingPrecision(exp)
	self._roundingPrecision = exp or 1
end

function Midas:_Render()
	if not self.Loaded then return end
	local roundHistory = {}
	local function round(val)
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
			local mag = 10^self._roundingPrecision
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
	for k, v in pairs(self._states) do
		local success, msg = pcall(function()
			if v == nil then
				output[k] = "nil"
			elseif type(v) == "function" then
				output[k] = round(v())
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

function Midas:Render() --server only
	assert(runService:IsServer() == true, "Render can only be called on server")
	if self._chance < math.random() then return end
	local output
	if self._isClientManaged then
		output = self._GetRenderOutput:InvokeClient(self._player)
	else
		output = self:_Render()
	end
	if output then
		local finalOutput = {}
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
end

function Midas:GetUTC(offset)
	offset = offset or 0
	local unixTime = (DateTime.now().UnixTimestampMillis/1000) + offset
	local dateTime: DateTime = DateTime.fromUnixTimestamp(unixTime)
	local utc: table = dateTime:ToUniversalTime()
	return utc.Year.."-"..utc.Month.."-"..utc.Day.." "..utc.Hour..":"..utc.Minute..":"..utc.Second.."."..utc.Millisecond
end

function Midas:CanFire()
	local allTrue = true
	for k, func in pairs(self._conditions) do
		if func() ~= true then
			allTrue = false
		end
	end
	return allTrue
end

if runService:IsServer() then
	function Midas:_FireSeries(eventName: string, utc: string, waitDuration: number, includeEndEvent: boolean | nil)
		-- logger:Log("_Firing series: "..tostring(eventName).." for "..tostring(self._player.Name))
		waitDuration = waitDuration or 15
		local t = tick()
		-- logger:Log("Starting tick "..tostring(t)..": "..tostring(eventName).." for "..tostring(self._player.Name))
		if self._lastFireTick[eventName] == nil then
			self._seriesSignal[eventName] = self._profile:FireSeries(self, eventName, utc, self._index[eventName], includeEndEvent)
		end
		self._firstFireTick[eventName] = self._firstFireTick[eventName] or t
		self._lastFireTick[eventName] = t
		self._repetitions[eventName] = (self._repetitions[eventName] or -1) + 1

		task.spawn(function()

			task.wait(waitDuration)
			local currentTick = tick()
			local signal = self._seriesSignal[eventName]
			local lastTick = self._lastFireTick[eventName]
			local firstFire = self._firstFireTick[eventName]
			-- logger:Log("Time diff: "..tostring(currentTick).." vs and orig "..tostring(lastTick)..": "..tostring(eventName).." for "..tostring(self._player.Name))
			if firstFire and lastTick and currentTick - lastTick >= waitDuration and signal ~= nil then
				local reps = self._repetitions[eventName]
	
				-- logger:Log("Firing signal: "..tostring(eventName).." for "..tostring(self._player.Name))
				signal:Fire(lastTick - firstFire)
				self._firstFireTick[eventName] = nil
				self._lastFireTick[eventName] = nil
				self._repetitions[eventName] = nil
			-- else
				-- logger:Log("Difference: "..tostring(currentTick-(lastTick or 0)).." vs "..tostring(waitDuration)..": "..tostring(eventName).." for "..tostring(self._player.Name))
			end
		end)
	end


	function Midas:_FireEvent(eventName, utc)
		-- logger:Log("_Firing event: "..tostring(eventName).." for "..tostring(self._player.Name))
		self._index[eventName] = self._index[eventName] or 0
		self._index[eventName] += 1
		self._profile:Fire(self, eventName, utc, self._index[eventName])

	end

end

function Midas:_Fire(eventName: string, utc, seriesDuration: number | nil, includeEndEvent: boolean | nil)
	if runService:IsServer() then
		if seriesDuration ~= nil then
			self:_FireSeries(eventName, utc, seriesDuration, includeEndEvent)
		else
			self:_FireEvent(eventName, utc)
		end
	else
		self._OnClientFire:FireServer(eventName, utc, seriesDuration)
	end
end

--[=[
	This function allows for the rapid construction of Midaii
	@method Fire
	@within Midas
	@param eventName string --a final string added to end of event path, creating a unique event type
	@param seriesDuration number | nil --makes it a series event, with this parameter inputting how long without a repeat event is needed to end the series
	@param includeEndEvent boolean | nil --whether a series end event is fired, or if all the info is bundled into a single start event.
	@return Midas
]=]
function Midas:Fire(eventName: string, seriesDuration: number | nil, includeEndEvent: boolean | nil)
	task.spawn(function()
		local utc = self:GetUTC()
		if not self.Loaded then self.LoadSignal:Wait() end
		if self.Loaded == false then
			task.wait(1)
			self:Fire(eventName, seriesDuration, includeEndEvent)
		else
			if eventName == nil then eventName = "Event" end
			if self:CanFire() == false then return end
			self:_Fire(eventName, utc, seriesDuration, includeEndEvent)
		end
	end)
end

function Midas:SetChance(val)
	if not self.Loaded then self.LoadSignal:Wait() end
	self._chance = val
end

function Midas:GetKeyCount()
	-- if not self.Loaded then self.LoadSignal:Wait() end
	local count = 0
	for k, v in pairs(self._states) do
		count += 1
	end
	return count
end

--[=[
	This function allows for the rapid construction of Midaii
	@method new
	@within Midas
	@param player Player --the player the data will be bound to
	@param eventKeyPath string -- an event name similar to a filepath, for example 'Network/Physics/Send'
	@return Midas
]=]
function Midas.new(player: Player, eventKeyPath: string)
	-- logger:Log("New Midas: "..tostring(eventKeyPath).." for "..tostring(player.Name))
	local self = {
		_maid = maidConstructor.new(),
		_profile = if runService:IsServer() then profile.get(player) else nil,

		_path = eventKeyPath,
		_player = player,
		_roundingPrecision = 1,

		_chance = 1,
		_tags = {},
		_conditions = {},
		_states = {},

		_firstFireTick = {},
		_lastFireTick = {},
		_seriesSignal = {},
		_index = {},
		_repetitions = {},
		_initComplete = false,
		Loaded = false,
		LoadSignal = signalConstructor.new(),
		Living = true,
		Destroying = signalConstructor.new(),
		Event = signalConstructor.new(),
	}
	setmetatable(self, Midas)
	task.spawn(function()
		if runService:IsServer() then
			local maid = rawget(self, "_maid")
			-- logger:Log("Creating server midas: "..tostring(eventKeyPath).." for "..tostring(player.Name))
			local pro = rawget(self, "_profile")
			local inst = Instance.new("Folder", pro.Instance)
			inst.Name = rawget(self, "_path")
			maid:GiveTask(inst)
			rawset(self, "Instance", inst)
			--tells server Midas that it should call client Midas for rendering
			local clientRegister = Instance.new("RemoteEvent", inst)
			clientRegister.Name = "ClientRegister"
			maid:GiveTask(clientRegister)
			maid:GiveTask(clientRegister.OnServerEvent:Connect(function(eventPlayer)
				if eventPlayer == rawget(self, "_player") then
					if not rawget(self, "Loaded") then rawget(self, "LoadSignal"):Wait() end
					-- logger:Log("Is client managed: "..tostring(eventKeyPath).." for "..tostring(player.Name))
					self._isClientManaged = true
				end
			end))
			rawset(self, "_ClientRegister", clientRegister)

			--list of client fires
			local onClientFire = Instance.new("RemoteEvent", inst)
			onClientFire.Name = "OnClientFire"
			maid:GiveTask(onClientFire)
			maid:GiveTask(onClientFire.OnServerEvent:Connect(function(eventPlayer, eventName, utc, reps)
				if eventPlayer == player then
					if not rawget(self, "Loaded") then rawget(self, "LoadSignal"):Wait() end
					-- logger:Log("Client fired to server: "..tostring(eventKeyPath).." for "..tostring(player.Name))
					self:_Fire(eventName, utc, reps)
				end
			end))
			rawset(self, "_OnClientFire", onClientFire)

			--get render output from client
			local getRenderOuput = Instance.new("RemoteFunction", inst)
			getRenderOuput.Name = "GetRenderOutput"
			maid:GiveTask(getRenderOuput)
			rawset(self, "_GetRenderOutput", getRenderOuput)

		else
			-- logger:Log("Creating client midas: "..tostring(eventKeyPath).." for "..tostring(player.Name))
			--get server instance
			local profFolder = replicatedStorage:WaitForChild("Profiles"):WaitForChild(tostring(player.UserId))
			local maid = rawget(self, "_maid")
			local inst
			local path = rawget(self, "_path")
			if time() < 15 then
				inst = profFolder:WaitForChild(path, 2)
			else
				inst = profFolder:WaitForChild(path, 0.1)
			end
			if inst == nil then

				constructMidas:FireServer(eventKeyPath)
				-- logger:Log("Registering to server: "..tostring(eventKeyPath).." for "..tostring(player.Name))
				-- print("Waiting indefinitely for", self._path)
				inst = profFolder:WaitForChild(path,15)
				assert(inst ~= nil, "Didn't find "..tostring(eventKeyPath))
			end
			rawset(self, "Instance", inst)
			--register to server instance
			local clientRegister
			clientRegister = inst:WaitForChild("ClientRegister")
			rawset(self, "_ClientRegister", clientRegister)
			rawset(self, "_OnClientFire", inst:WaitForChild("OnClientFire"))
			clientRegister:FireServer()

			--listen for render requests
			local getRenderOutput = inst:WaitForChild("GetRenderOutput")
			getRenderOutput.OnClientInvoke = function()
				if not rawget(self, "Loaded") then rawget(self, "LoadSignal"):Wait() end
				-- logger:Log("Render signal received: "..tostring(eventKeyPath).." for "..tostring(player.Name))
				return self:_Render()
			end
		end

		rawget(self, "_maid"):GiveTask(rawget(self, "Instance").Destroying:Connect(function()
			-- logger:Log("Destroying: "..tostring(eventKeyPath).." for "..tostring(player.Name))
			rawset(self, "Living", false)
			rawget(self, "Destroy")(self)
		end))
		setmetatable(self, Midas)
		rawget(self, "_maid"):GiveTask(self)
		if runService:IsServer() then
			-- logger:Log("Sent midas to profile: "..tostring(eventKeyPath).." for "..tostring(player.Name))
			rawget(self, "_profile"):SetMidas(self)
		end
		rawset(self, "Loaded", true)
		rawget(self, "LoadSignal"):Fire()
	end)
	return self
end


return Midas