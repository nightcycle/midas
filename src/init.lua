local runService = game:GetService("RunService")
local players = game:GetService("Players")
local statService = game:GetService("Stats")
local policyService = game:GetService("PolicyService")
local userInputService = game:GetService("UserInputService")
local marketplaceService = game:GetService("MarketplaceService")
local voiceChatService = game:GetService("VoiceChatService")

local package = script
local packages = package.Parent

local fusion = require(packages:WaitForChild("cold-fusion"))
local maidConstructor = require(packages:WaitForChild("maid"))
local signalConstructor = require(packages:WaitForChild("signal"))

local midasConstructor = require(package:WaitForChild("Midas"))
local config = require(package:WaitForChild("Config"))
local profile = require(package:WaitForChild("Profile"))
local playFab = require(package:WaitForChild("PlayFab"))

local Service = {}
Service.__type = "Analytics"
Service.__index = Service

--[=[
	@class Service
	-- the class used to create Midas objects
]=]

--[=[
	This function allows for the rapid construction of Midaii
	@method Midas
	@within Service
	@param ... --all parameters passed to Midas object
	@return Midas -- Returns a midas object
]=]
function Service:Midas(...)
	return midasConstructor.new(...)
end

function Service.State(...)
	return fusion.State(...)
end

function Service.Computed(...)
	return fusion.Computed(...)
end

function clientResponse(remoteEvent, func)
	remoteEvent.OnClientEvent:Connect(function(...)
		local val = func(...):Wait()
		remoteEvent:FireServer(val)
	end)
end

function serverSignal(remoteEvent, ...)
	local params = {...}
	assert(params[1].ClassName == "Player", "Bad player")
	local promptMaid = maidConstructor.new()
	local signal = signalConstructor.new()
	promptMaid:GiveTask(remoteEvent.OnServerEvent:Connect(function(player, ...)
		if player == params[1] then
			signal:Fire(...)
			promptMaid:Destroy()
		end
	end))
	promptMaid:GiveTask(signal)
	remoteEvent:FireClient(...)
	return signal
end

--[=[
	This function returns the configuration table for editing

    @method GetConfig
    @within Service
    @return table -- Returns the configuration table
]=]
function Service:GetConfig()
	return config
end

--[=[
	This begins tracking various useful states for a player
	@method LoadDefault
	@within Service
	@param player Player -- the player to hook-up
]=]
function Service:LoadDefault(player)
	-- logger:Log("Loading default state for "..player.Name)
	local maid = maidConstructor.new()
	if runService:IsClient() then
		local localizationService = game:GetService("LocalizationService")

		local mDemographics = midasConstructor.new(player, "Audience/Demographics")
		mDemographics:SetRoundingPrecision(0)
		mDemographics.AccountAge = player.AccountAge
		mDemographics.RobloxLangugage = localizationService.RobloxLocaleId
		mDemographics.SystemLanguage = localizationService.SystemLocaleId

		mDemographics["Platform/Accelerometer"] = function()
			return userInputService.VREnabled
		end
		mDemographics["Platform/Gamepad"] = function()
			return userInputService.GamepadConnected
		end
		mDemographics["Platform/Gyroscope"] = function()
			return userInputService.GyroscopeEnabled
		end
		mDemographics["Platform/Keyboard"] = function()
			return userInputService.KeyboardEnabled
		end
		mDemographics["Platform/Mouse"] = function()
			return userInputService.MouseEnabled
		end
		mDemographics["Platform/TouchEnabled"] = function()
			return userInputService.TouchEnabled
		end
		-- mDemographics["Platform/VREnabled"] = function()
		-- 	return vrService.VREnabled
		-- end
		-- mDemographics["Platform/VRAvailable"] = function()
		-- 	return vrService.VRDeviceAvailable
		-- end
		mDemographics["Platform/VCEnabled"] = function()
			return voiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
		end
		mDemographics["Platform/ScreenSize"] = function()
			return game.Workspace.CurrentCamera.ViewportSize.Magnitude
		end
		mDemographics["Platform/ScreenRatio"] = function()
			local size = game.Workspace.CurrentCamera.ViewportSize
			local x = size.X
			local y = size.Y
			local ratio = y/x
			if ratio == 16/10 then
				return "16:10"
			elseif ratio == 16/9 then
				return "16:9"
			elseif ratio == 5/4 then
				return "5:4"
			elseif ratio == 5/3 then
				return "5:3"
			elseif ratio == 3/2 then
				return "3:2"
			elseif ratio == 4/3 then
				return "4:3"
			elseif ratio == 9/16 then
				return "9:16"
			end
			return (math.round(100/ratio)/100)..":1"
		end

		local mPolicy = midasConstructor.new(player, "Policy")
		task.spawn(function()
			local policyInfo = policyService:GetPolicyInfoForPlayerAsync(player)
			mPolicy.Lootboxes = policyInfo.ArePaidRandomItemsRestricted
			mPolicy.AllowedLinks = policyInfo.AllowedExternalLinkReferences
			mPolicy.Trading = policyInfo.IsPaidItemTradingAllowed
			mPolicy.China = policyInfo.IsSubjectToChinaPolicies
		end)

		local mClientPerformance = midasConstructor.new(player, "Performance/Client")
		mClientPerformance:SetRoundingPrecision(0)
		mClientPerformance.Ping = function()
			return math.clamp(player:GetNetworkPing(), 0, 10^6)
		end

		local frames = 0
		local duration = 0
		maid:GiveTask(runService.RenderStepped:Connect(function(delta)
			frames += 1
			duration += delta
			task.delay(1, function()
				frames -= 1
				duration -= delta
			end)
		end))
		mClientPerformance.FPS = function()
			return frames/duration
		end
		maid:GiveTask(game.GraphicsQualityChangeRequest:Connect(function(increase)
			if increase then
				mClientPerformance:Fire("Graphics/Increase")
			else
				mClientPerformance:Fire("Graphics/Decrease")
			end
		end))

		local gameSettings = UserSettings():GetService("UserGameSettings")
		local mSettings = midasConstructor.new(player, "Settings")
		mClientPerformance:SetRoundingPrecision(2)
		-- mSettings.CameraMode = function()
		-- 	return gameSettings.CustomCameraMode.Name
		-- end
		mSettings.ComputerMovementMode = function()
			return gameSettings.ComputerMovementMode.Name
		end
		mSettings.ControlMode = function()
			return gameSettings.ControlMode.Name
		end
		mSettings.MasterVolume = function()
			return gameSettings.MasterVolume
		end
		mSettings.MouseSensitivity = function()
			return gameSettings.MouseSensitivity
		end
		mSettings.RotationType = function()
			return gameSettings.RotationType.Name
		end
		mSettings.SavedQualityLevel = function()
			return gameSettings.SavedQualityLevel.Value
		end
		mSettings.TouchCameraMovementMode = function()
			return gameSettings.TouchCameraMovementMode.Value
		end
		mSettings.TouchMovementMode = function()
			return gameSettings.TouchMovementMode.Value
		end
		-- mSettings.VREnabled = function()
		-- 	return gameSettings.VREnabled
		-- end
		-- mSettings.VRRotationIntensity = function()
		-- 	return gameSettings.VRRotationIntensity
		-- end
		mSettings.VignetteEnabled = function()
			return gameSettings.VignetteEnabled
		end
	else
		local startTick = tick()
		local serverProfile = profile.get(player.UserId)

		local mChat = midasConstructor.new(player, "Chat")
		mChat.LastMessage = nil
		
		maid:GiveTask(player.Chatted:Connect(function(msg)
			mChat.LastMessage = string.sub(msg, 140)
			mChat:Fire("Spoke")
		end))

		local mJoin = midasConstructor.new(player, "Join")
		if serverProfile._wasTeleported then
			mJoin:Fire("Teleport")
		else
			mJoin:Fire("Enter")
		end

		-- local mId = midasConstructor.new(player, "Id")
		-- mId.User = player.UserId
		-- mId.Session = serverProfile._sId
		-- mId.Place = game.PlaceId

		local function setCharacter(char)
			if not char then return end
			local mCharacter = midasConstructor.new(player, "Character")
			mCharacter:SetRoundingPrecision(1)
			mCharacter.IsDead = false
			mCharacter.Height = function()
				local humanoid = char:FindFirstChild("Humanoid")
				if humanoid then
					local humDesc = humanoid:GetAppliedDescription()
					if humDesc then
						return humDesc.HeightScale
					end
				end
			end
			mCharacter.Mass = function()
				local primarypart = char.PrimaryPart
				if primarypart then
					return primarypart.AssemblyMass
				end
			end
			mCharacter.WalkSpeed = function()
				local humanoid = char:FindFirstChild("Humanoid")
				if humanoid then
					return humanoid.WalkSpeed
				end
			end
			mCharacter.Position = function()
				local primarypart = char.PrimaryPart
				if primarypart then
					return Vector2.new(primarypart.Position.X, primarypart.Position.Z)
				end
			end
			mCharacter.Altitude = function()
				local primarypart = char.PrimaryPart
				if primarypart then
					return primarypart.Position.Y
				end
			end
			mCharacter.JumpPower = function()
				local humanoid = char:FindFirstChild("Humanoid")
				if humanoid then
					return humanoid.WalkSpeed
				end
			end
			mCharacter.Health = function()
				local humanoid = char:FindFirstChild("Humanoid")
				if humanoid then
					return humanoid.Health
				end
			end
			mCharacter.MaxHealth = function()
				local humanoid = char:FindFirstChild("Humanoid")
				if humanoid then
					return humanoid.MaxHealth
				end
			end
			mCharacter.Deaths = 0
			maid:GiveTask(char:WaitForChild("Humanoid", 15).Died:Connect(function()
				mCharacter.Deaths += 1
				mCharacter:Fire("Died")
				mCharacter.IsDead = true
			end))
		end

		maid:GiveTask(player.CharacterAdded:Connect(function(char)
			setCharacter(char)
		end))
		setCharacter(player.Character)

		local mPopulation = midasConstructor.new(player, "Population")
		mPopulation.Total = function()
			return #game.Players:GetChildren()
		end
		mPopulation.Team = function()
			local teamColor = player.TeamColor
			local count = 0
			for i, plr in ipairs(game.Players:GetChildren()) do
				if plr ~= player and plr.TeamColor == teamColor then
					count += 1
				end
			end
			return count
		end
		local friendPages = players:GetFriendsAsync(player.UserId)
		local friends = {}
		task.spawn(function()
			local function iterPageItems(pages)
				return coroutine.wrap(function()
					local pagenum = 1
					while true do
						for _, item in ipairs(pages:GetCurrentPage()) do
							coroutine.yield(item, pagenum)
						end
						if pages.IsFinished then
							break
						end
						pages:AdvanceToNextPageAsync()
						pagenum = pagenum + 1
					end
				end)
			end
			for item, pageNo in iterPageItems(friendPages) do
				friends[item.Id] = true
			end
		end)

		mPopulation.PeakFriends = 0
		mPopulation.Friends = function()
			local count = 0
			for i, plr in ipairs(game.Players:GetChildren()) do
				if plr ~= player and friends[plr.UserId] == true then
					count += 1
				end
			end
			mPopulation.PeakFriends = math.max(mPopulation.PeakFriends, count)
			return count
		end

		local results = {}
		for k, id in pairs(config.VIP.Developers or {}) do
			if tostring(id) == tostring(player.UserId) then
				mPopulation["VIP/Groups/Developer"] = true
			end
			if friends[tonumber(id)] then
				mPopulation["VIP/Friends/"..k] = true
			else
				mPopulation["VIP/Friends/"..k] = false
			end
		end

		task.spawn(function()
			for k, id in pairs(config.VIP.Groups or {}) do
				if player:IsInGroup(id) then
					mPopulation["VIP/Groups/"..k] = true
				else
					mPopulation["VIP/Groups/"..k] = false
				end
			end
		end)

		-- end
		mPopulation.SpeakingDistance = function()
			local count = 0
			local pChar = player.Character
			if pChar then
				local pPrim = pChar.PrimaryPart
				for i, plr in ipairs(game.Players:GetChildren()) do
					if plr ~= player then
						local char = plr.Char
						if char then
							local prim = char.PrimaryPart
							if prim then
								local dist = (prim.Position - pPrim.Position).Magnitude
								if dist < 40 then
									count += 1
								end
							end
						end
					end
				end
			end
		end

		local mServerPerformance = midasConstructor.new(player, "Performance/Server")
		serverProfile._mServerPerformance = mServerPerformance
		mServerPerformance:SetRoundingPrecision(0)
		mServerPerformance.EventsPerMinute = function()
			if serverProfile.TimeDifference < 60 then
				return 60*serverProfile.EventsPerMinute/serverProfile.TimeDifference
			else
				return serverProfile.EventsPerMinute
			end
	
		end
		mServerPerformance["ServerTime"] = function()
			return math.round(time())
		end
		mServerPerformance["HeartRate"] = function()
			return math.clamp(math.round(1/statService.HeartbeatTimeMs), 6000)
		end
		mServerPerformance["Instances"] = function()
			return math.round(statService.InstanceCount/1000)*1000
		end
		mServerPerformance["MovingParts"] = function()
			return statService.InstanceCount
		end
		mServerPerformance["Network/Data/Send"] = function()
			return statService.DataSendKbps
		end
		mServerPerformance["Network/Data/Receive"] = function()
			return statService.DataReceiveKbps
		end
		mServerPerformance["Network/Physics/Send"] = function()
			return statService.PhysicsSendKbps
		end
		mServerPerformance["Network/Physics/Receive"] = function()
			return statService.PhysicsReceiveKbps
		end
		mServerPerformance["Memory/Internal"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Internal)
		end
		mServerPerformance["Memory/HttpCache"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.HttpCache)
		end
		mServerPerformance["Memory/Instances"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances)
		end
		mServerPerformance["Memory/Signals"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Signals)
		end
		mServerPerformance["Memory/LuaHeap"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap)
		end
		mServerPerformance["Memory/Script"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script)
		end
		mServerPerformance["Memory/PhysicsCollision"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsCollision)
		end
		mServerPerformance["Memory/PhysicsParts"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsParts)
		end
		mServerPerformance["Memory/CSG"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
		end
		mServerPerformance["Memory/Particle"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParticles)
		end
		mServerPerformance["Memory/Part"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParts)
		end
		mServerPerformance["Memory/MeshPart"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
		end
		mServerPerformance["Memory/SpatialHash"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsSpatialHash)
		end
		mServerPerformance["Memory/TerrainGraphics"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.TerrainVoxels)
		end
		mServerPerformance["Memory/Textures"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture)
		end
		mServerPerformance["Memory/CharacterTextures"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTextureCharacter)
		end
		mServerPerformance["Memory/SoundsData"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Sounds)
		end
		mServerPerformance["Memory/SoundsStreaming"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.StreamingSounds)
		end
		mServerPerformance["Memory/TerrainVoxels"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.TerrainVoxels)
		end
		mServerPerformance["Memory/Guis"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)
		end
		mServerPerformance["Memory/Animations"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Animation)
		end
		mServerPerformance["Memory/Pathfinding"] = function()
			return statService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Navigation)
		end
		mServerPerformance["PlayerHTTPLimit"] = function()
			return 500/#players:GetChildren()
		end

		local mMarket = midasConstructor.new(player, "Spending")
		mMarket.Products = 0
		mMarket.Gamepasses = 0
		mMarket.Spending = function()
			return mMarket.Products + mMarket.Gamepasses
		end
		maid:GiveTask(marketplaceService.PromptPurchaseFinished:Connect(function(plr, id, success)
			if plr ~= player and success then
				local itemInfo = marketplaceService:GetProductInfo(id, Enum.InfoType.Product)
				mMarket:Fire("Purchase/Product/"..itemInfo.Name)
				mMarket.Products += itemInfo.PriceInRobux
			end

		end))
		maid:GiveTask(marketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, id, success)
			if plr ~= player and success then
				local itemInfo = marketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
				mMarket:Fire("Purchase/Gamepass/"..itemInfo.Name)
				mMarket.Gamepasses += itemInfo.Gamepasses
			end
		end))

		serverProfile._mExit = midasConstructor.new(player, "Exit")
		maid:GiveTask(game.Players.PlayerRemoving:Connect(function(remPlayer)
			if remPlayer == player and serverProfile._isTeleporting == false then
				serverProfile._mExit:Fire("Quit")
				maid:Destroy()
			end
		end))
		maid:GiveTask(game.Close:Connect(function()
			serverProfile._mExit:Fire("Close")
			serverProfile:Destroy()
			maid:Destroy()
		end))
	end
end

function Service.new()
	local self = setmetatable({}, Service)
	return self
end

if runService:IsClient() then
	return Service.new()
else
	--[=[
	This function returns the configuration table for editing

	@method init
	@within Service
	@server
	@param titleId string -- the playfab TitleId
	@param devSecretKey string --the playfab developer secret key
	]=]
	function Service.init(titleId: string, devSecretKey: string)
		playFab.init(titleId, devSecretKey)
		profile.init(Service)

		return Service
	end

	function Service:GetTeleportDataEntry(player, teleportData)
		teleportData = teleportData or {}
		local current = profile.get()
		if current then
			teleportData.MidasAnalyticsData = current:Teleport(player)
		end
		return teleportData
	end

	return Service.new()
end
