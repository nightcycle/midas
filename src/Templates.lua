--!strict
local StatService = game:GetService("Stats")
local PolicyService = game:GetService("PolicyService")
local MarketplaceService = game:GetService("MarketplaceService")
local VoiceChatService = game:GetService("VoiceChatService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Packages
local _Package = script.Parent
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)

-- Modules
local Config = require(_Package.Config)
local Midas = require(_Package.Midas)

export type Midas = Midas.Midas

local Templates = {}
Templates.__index = {}

function Templates.join(player: Player, wasTeleportedIn: boolean): Midas
	assert(RunService:IsServer(), "Bad domain")
	local mJoin = Midas.new(player, "Join")
	if wasTeleportedIn then
		mJoin:Fire("Teleport")
	else
		mJoin:Fire("Enter")
	end
	return mJoin
end

function Templates.chat(player: Player): Midas
	assert(RunService:IsServer(), "Bad domain")
	local mChat = Midas.new(player, "Chat")
	mChat.LastMessage = nil
	mChat._Maid:GiveTask(player.Chatted:Connect(function(msg)
		mChat.LastMessage = string.sub(msg, 140)
		mChat:Fire("Spoke")
	end))
	return mChat
end

function Templates.character(character: Model): Midas
	assert(RunService:IsServer(), "Bad domain")
	local player = Players:GetPlayerFromCharacter(character)
	assert(player ~= nil)

	local maid = _Maid.new()

	maid:GiveTask(character.Destroying:Connect(function()
		maid:Destroy()
	end))

	local mCharacter = Midas.new(player, "Character")
	mCharacter:SetRoundingPrecision(1)
	mCharacter.IsDead = false
	mCharacter.Height = function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local humDesc = humanoid:GetAppliedDescription()
			if humDesc then
				return humDesc.HeightScale
			end
		end
	end

	mCharacter.Mass = function()
		local primarypart = character.PrimaryPart
		if primarypart then
			return primarypart.AssemblyMass
		end
	end

	mCharacter.WalkSpeed = function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid.WalkSpeed
		end
	end

	mCharacter.Position = function()
		local primarypart = character.PrimaryPart
		if primarypart then
			return Vector2.new(primarypart.Position.X, primarypart.Position.Z)
		end
	end

	mCharacter.Altitude = function()
		local primarypart = character.PrimaryPart
		if primarypart then
			return primarypart.Position.Y
		end
	end

	mCharacter.JumpPower = function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid.WalkSpeed
		end
	end

	mCharacter.Health = function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid.Health
		end
	end

	mCharacter.MaxHealth = function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid.MaxHealth
		end
	end

	mCharacter.Deaths = 0
	local humanoid = character:WaitForChild("Humanoid", 15)
	assert(humanoid ~= nil and humanoid:IsA("Humanoid"), "Bad humanoid")

	maid:GiveTask(humanoid.Died:Connect(function()
		mCharacter.Deaths += 1
		mCharacter:Fire("Died")
		mCharacter.IsDead = true
	end))
	return mCharacter
end

function Templates.population(player: Player): Midas
	assert(RunService:IsServer(), "Bad domain")
	local mPopulation = Midas.new(player, "Population")
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
	
	local friendPages = Players:GetFriendsAsync(player.UserId)
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
	for k, id in pairs(Config.VIP.Developers or {}) do
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
		for k, id in pairs(Config.VIP.Groups or {}) do
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
	return mPopulation
end

function Templates.serverPerformance(player: Player, getTimeDifference: () -> number, getEventsPerMinute: () -> number): Midas
	assert(RunService:IsServer(), "Bad domain")
	local mServerPerformance = Midas.new(player, "Performance/Server")
	mServerPerformance:SetRoundingPrecision(0)
	mServerPerformance.EventsPerMinute = function()
		local timeDifference = getTimeDifference()
		local eventsPerMinute = getEventsPerMinute()
		if timeDifference < 60 then
			return 60*eventsPerMinute/timeDifference
		else
			return eventsPerMinute
		end
	end
	mServerPerformance["ServerTime"] = function()
		return math.round(time())
	end
	mServerPerformance["HeartRate"] = function()
		return math.clamp(math.round(1/StatService.HeartbeatTimeMs), 6000)
	end
	mServerPerformance["Instances"] = function()
		return math.round(StatService.InstanceCount/1000)*1000
	end
	mServerPerformance["MovingParts"] = function()
		return StatService.InstanceCount
	end
	mServerPerformance["Network/Data/Send"] = function()
		return StatService.DataSendKbps
	end
	mServerPerformance["Network/Data/Receive"] = function()
		return StatService.DataReceiveKbps
	end
	mServerPerformance["Network/Physics/Send"] = function()
		return StatService.PhysicsSendKbps
	end
	mServerPerformance["Network/Physics/Receive"] = function()
		return StatService.PhysicsReceiveKbps
	end
	mServerPerformance["Memory/Internal"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Internal)
	end
	mServerPerformance["Memory/HttpCache"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.HttpCache)
	end
	mServerPerformance["Memory/Instances"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances)
	end
	mServerPerformance["Memory/Signals"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Signals)
	end
	mServerPerformance["Memory/LuaHeap"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap)
	end
	mServerPerformance["Memory/Script"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script)
	end
	mServerPerformance["Memory/PhysicsCollision"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsCollision)
	end
	mServerPerformance["Memory/PhysicsParts"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsParts)
	end
	mServerPerformance["Memory/CSG"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
	end
	mServerPerformance["Memory/Particle"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParticles)
	end
	mServerPerformance["Memory/Part"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParts)
	end
	mServerPerformance["Memory/MeshPart"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
	end
	mServerPerformance["Memory/SpatialHash"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsSpatialHash)
	end
	mServerPerformance["Memory/TerrainGraphics"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.TerrainVoxels)
	end
	mServerPerformance["Memory/Textures"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture)
	end
	mServerPerformance["Memory/CharacterTextures"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTextureCharacter)
	end
	mServerPerformance["Memory/SoundsData"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Sounds)
	end
	mServerPerformance["Memory/SoundsStreaming"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.StreamingSounds)
	end
	mServerPerformance["Memory/TerrainVoxels"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.TerrainVoxels)
	end
	mServerPerformance["Memory/Guis"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)
	end
	mServerPerformance["Memory/Animations"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Animation)
	end
	mServerPerformance["Memory/Pathfinding"] = function()
		return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Navigation)
	end
	mServerPerformance["PlayerHTTPLimit"] = function()
		return 500/#Players:GetChildren()
	end
	return mServerPerformance
end

function Templates.market(player: Player)
	assert(RunService:IsServer(), "Bad domain")

	local mMarket = Midas.new(player, "Spending")
	mMarket.Products = 0
	mMarket.Gamepasses = 0
	mMarket.Spending = function()
		return mMarket.Products + mMarket.Gamepasses
	end

	mMarket._Maid:GiveTask(MarketplaceService.PromptPurchaseFinished:Connect(function(plr: Player, id: number, success: boolean)
		if plr ~= player and success then
			local itemInfo = MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			mMarket:Fire("Purchase/Product/"..itemInfo.Name)
			mMarket.Products += itemInfo.PriceInRobux
		end

	end))
	mMarket._Maid:GiveTask(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, id: number, success: boolean)
		if plr ~= player and success then
			local itemInfo = MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
			mMarket:Fire("Purchase/Gamepass/"..itemInfo.Name)
			mMarket.Gamepasses += itemInfo.Gamepasses
		end
	end))
	return mMarket
end

function Templates.exit(player: Player, getIfTeleporting: () -> boolean): Midas
	assert(RunService:IsServer(), "Bad domain")

	local mExit = Midas.new(player, "Exit")
	mExit._Maid:GiveTask(game.Players.PlayerRemoving:Connect(function(remPlayer: Player)
		if remPlayer == player and getIfTeleporting() == false then
			mExit:Fire("Quit")
			mExit._Maid:Destroy()
		end
	end))
	mExit._Maid:GiveTask(game.Close:Connect(function()
		mExit:Fire("Close")
	end))
	return mExit
end

function Templates.demographics(player: Player): Midas
	assert(RunService:IsClient(), "Bad domain")
	local localizationService = game:GetService("LocalizationService")

	local mDemographics = Midas.new(player, "Audience/Demographics")
	mDemographics:SetRoundingPrecision(0)
	mDemographics.AccountAge = player.AccountAge
	mDemographics.RobloxLangugage = localizationService.RobloxLocaleId
	mDemographics.SystemLanguage = localizationService.SystemLocaleId

	mDemographics["Platform/Accelerometer"] = function()
		return UserInputService.VREnabled
	end
	mDemographics["Platform/Gamepad"] = function()
		return UserInputService.GamepadConnected
	end
	mDemographics["Platform/Gyroscope"] = function()
		return UserInputService.GyroscopeEnabled
	end
	mDemographics["Platform/Keyboard"] = function()
		return UserInputService.KeyboardEnabled
	end
	mDemographics["Platform/Mouse"] = function()
		return UserInputService.MouseEnabled
	end
	mDemographics["Platform/TouchEnabled"] = function()
		return UserInputService.TouchEnabled
	end
	mDemographics["Platform/VCEnabled"] = function()
		return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
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
	return mDemographics
end

function Templates.policy(player: Player): Midas
	local mPolicy = Midas.new(player, "Policy")
	task.spawn(function()
		local policyInfo = PolicyService:GetPolicyInfoForPlayerAsync(player)
		mPolicy.Lootboxes = policyInfo.ArePaidRandomItemsRestricted
		mPolicy.AllowedLinks = policyInfo.AllowedExternalLinkReferences
		mPolicy.Trading = policyInfo.IsPaidItemTradingAllowed
		mPolicy.China = policyInfo.IsSubjectToChinaPolicies
	end)
	return mPolicy
end

function Templates.clientPerformance(player: Player): Midas
	local mClientPerformance = Midas.new(player, "Performance/Client")
	mClientPerformance:SetRoundingPrecision(0)
	mClientPerformance.Ping = function()
		return math.clamp(player:GetNetworkPing(), 0, 10^6)
	end

	local frames = 0
	local duration = 0
	mClientPerformance._Maid:GiveTask(RunService.RenderStepped:Connect(function(delta)
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
	mClientPerformance._Maid:GiveTask(game.GraphicsQualityChangeRequest:Connect(function(increase)
		if increase then
			mClientPerformance:Fire("Graphics/Increase")
		else
			mClientPerformance:Fire("Graphics/Decrease")
		end
	end))

	mClientPerformance:SetRoundingPrecision(2)

	return mClientPerformance
end

function Templates.settings(player: Player): Midas
	local gameSettings = UserSettings():GetService("UserGameSettings")
	local mSettings = Midas.new(player, "Settings")
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
	mSettings.VignetteEnabled = function()
		return gameSettings.VignetteEnabled
	end
	return mSettings
end

return Templates

