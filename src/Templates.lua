--!strict
local StatService = game:GetService("Stats")
local PolicyService = game:GetService("PolicyService")
local MarketplaceService = game:GetService("MarketplaceService")
local VoiceChatService = game:GetService("VoiceChatService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")

-- Packages
local _Package = script.Parent
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)
local _Network = require(_Packages.Network)

-- Modules
local Config = require(_Package.Config)
local Midas = require(_Package.Midas)
local Types = require(_Package.Types)

type Midas = Types.PrivateMidas

function log(message: string, player: Player?, path: string?)
	if Config.PrintLog then
		print("[", player, "]", "[templates]", "[", path, "]", ":", message)
	end
end

--Class definition
local Templates = {}
Templates.__index = {}

function Templates.join(player: Player, wasTeleportedIn: boolean): Midas?
	if not Config.Templates.Join then
		return
	end

	assert(RunService:IsServer(), "Bad domain")
	local mJoin = Midas._new(player, "Join")
	log("loaded", player, mJoin.Path)
	if wasTeleportedIn then
		log("firing teleport", player, mJoin.Path)
		mJoin:Fire("Teleport")
	else
		log("firing enter", player, mJoin.Path)
		mJoin:Fire("Enter")
	end
	return mJoin :: any
end

function Templates.chat(player: Player): Midas?
	if not Config.Templates.Chat then
		return
	end
	assert(RunService:IsServer(), "Bad domain")

	local mChat = Midas._new(player, "Chat")
	log("loaded", player, mChat.Path)


	task.spawn(function()
		
		local lastMessage: string?

		mChat:SetState("LastMessage", function()
			return lastMessage
		end)

		mChat._Maid:GiveTask(player.Chatted:Connect(function(msg)
			lastMessage = string.sub(msg, 1, 140)
			mChat:Fire("Spoke")
		end))
	end)

	return mChat :: any
end

function Templates.character(character: Model): Midas?
	if not Config.Templates.Character then
		return
	end
	assert(RunService:IsServer(), "Bad domain")
	local player = Players:GetPlayerFromCharacter(character)
	assert(player ~= nil)

	local maid = _Maid.new()


	local mCharacter = Midas._new(player, "Character")
	mCharacter:SetRoundingPrecision(1)

	maid:GiveTask(character.Destroying:Connect(function()
		log("character destroying", player, mCharacter.Path)
		maid:Destroy()
	end))


	local isDead = false
	task.spawn(function()
		mCharacter:SetState("IsDead", function()
			return isDead
		end)
		mCharacter:SetState("Height", function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			assert(humanoid ~= nil)
			local humDesc = humanoid:GetAppliedDescription()
			assert(humDesc ~= nil)
			return humDesc.HeightScale
		end)

		mCharacter:SetState("Mass", function()
			local primaryPart = character.PrimaryPart
			assert(primaryPart ~= nil)
			return primaryPart.AssemblyMass
		end)

		mCharacter:SetState("State", function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			assert(humanoid ~= nil)
			return humanoid:GetState().Name
		end)

		mCharacter:SetState("WalkSpeed", function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			assert(humanoid ~= nil)
			return humanoid.WalkSpeed
		end)

		mCharacter:SetState("Position", function()
			local primaryPart = character.PrimaryPart
			assert(primaryPart ~= nil)
			return Vector2.new(primaryPart.Position.X, primaryPart.Position.Z)
		end)

		mCharacter:SetState("Altitude", function()
			local primaryPart = character.PrimaryPart
			assert(primaryPart ~= nil)
			return primaryPart.Position.Y
		end)

		mCharacter:SetState("JumpPower", function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			assert(humanoid ~= nil)
			return humanoid.WalkSpeed
		end)

		mCharacter:SetState("Health", function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			assert(humanoid ~= nil)
			return humanoid.Health
		end)

		mCharacter:SetState("MaxHealth", function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			assert(humanoid ~= nil)
			return humanoid.MaxHealth
		end)

		local deaths = 0

		mCharacter:SetState("Deaths", function()
			return deaths
		end)
		local humanoid = character:WaitForChild("Humanoid", 15)
		assert(humanoid ~= nil and humanoid:IsA("Humanoid"), "Bad humanoid")

		maid:GiveTask(humanoid.Died:Connect(function()
			deaths += 1
			mCharacter:Fire("Died")
			isDead = true
		end))
	end)

	return mCharacter :: any
end

function Templates.population(player: Player): Midas?
	if not Config.Templates.Population then
		return
	end
	assert(RunService:IsServer(), "Bad domain")
	local mPopulation = Midas._new(player, "Population")

	task.spawn(function()
		mPopulation:SetState("Total", function()
			return #game.Players:GetChildren()
		end)
		mPopulation:SetState("Team", function()
			local teamColor = player.TeamColor
			local count = 0
			for i, plr in ipairs(game.Players:GetChildren()) do
				if plr ~= player and plr.TeamColor == teamColor then
					count += 1
				end
			end
			return count
		end)

		local friends = {}
		task.spawn(function()
			local friendPages = Players:GetFriendsAsync(player.UserId)
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

		local peakFriends = 0
		mPopulation:SetState("PeakFriends", function()
			return peakFriends
		end)
		mPopulation:SetState("Friends", function()
			local count = 0
			for i, plr in ipairs(game.Players:GetChildren()) do
				if plr ~= player and friends[plr.UserId] == true then
					count += 1
				end
			end
			peakFriends = math.max(peakFriends, count)
			return count
		end)

		-- end
		mPopulation:SetState("SpeakingDistance", function()
			local count = 0
			local pChar: Model? = player.Character :: any
			assert(pChar ~= nil)
			local pPrim = pChar.PrimaryPart
			assert(pPrim ~= nil)
			for i, plr in ipairs(game.Players:GetChildren()) do
				if plr ~= player then
					local char = plr.Character
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
			return count
		end)
	end)

	return mPopulation :: any
end

function Templates.serverPerformance(
	player: Player,
	getTimeDifference: () -> number,
	getEventsPerMinute: () -> number
): Midas?
	if not Config.Templates.ServerPerformance then
		return
	end
	assert(RunService:IsServer(), "Bad domain")
	local mServerPerformance = Midas._new(player, "Performance/Server")
	mServerPerformance:SetRoundingPrecision(0)
	task.spawn(function()
		mServerPerformance:SetState("EventsPerMinute", function()
			local timeDifference = getTimeDifference()
			local eventsPerMinute = getEventsPerMinute()
			if timeDifference < 60 then
				return 60 * eventsPerMinute / timeDifference
			else
				return eventsPerMinute
			end
		end)
		mServerPerformance:SetState("Ping", function()
			return math.clamp(player:GetNetworkPing(), 0, 10 ^ 6)
		end)
		mServerPerformance:SetState("ServerTime", function()
			return math.round(time())
		end)
		mServerPerformance:SetState("HeartRate", function()
			return math.clamp(math.round(1 / StatService.HeartbeatTimeMs), 0, 6000)
		end)
		mServerPerformance:SetState("Instances", function()
			return math.round(StatService.InstanceCount / 1000) * 1000
		end)
		mServerPerformance:SetState("MovingParts", function()
			return StatService.InstanceCount
		end)
		mServerPerformance:SetState("Network/Data/Send", function()
			return StatService.DataSendKbps
		end)
		mServerPerformance:SetState("Network/Data/Receive", function()
			return StatService.DataReceiveKbps
		end)
		mServerPerformance:SetState("Network/Physics/Send", function()
			return StatService.PhysicsSendKbps
		end)
		mServerPerformance:SetState("Network/Physics/Receive", function()
			return StatService.PhysicsReceiveKbps
		end)
		mServerPerformance:SetState("Memory/Internal", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Internal)
		end)
		mServerPerformance:SetState("Memory/HttpCache", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.HttpCache)
		end)
		mServerPerformance:SetState("Memory/Instances", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances)
		end)
		mServerPerformance:SetState("Memory/Signals", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Signals)
		end)
		mServerPerformance:SetState("Memory/LuaHeap", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap)
		end)
		mServerPerformance:SetState("Memory/Script", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script)
		end)
		mServerPerformance:SetState("Memory/PhysicsCollision", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsCollision)
		end)
		mServerPerformance:SetState("Memory/PhysicsParts", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsParts)
		end)
		mServerPerformance:SetState("Memory/CSG", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
		end)
		mServerPerformance:SetState("Memory/Particle", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParticles)
		end)
		mServerPerformance:SetState("Memory/Part", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParts)
		end)
		mServerPerformance:SetState("Memory/MeshPart", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
		end)
		mServerPerformance:SetState("Memory/SpatialHash", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsSpatialHash)
		end)
		mServerPerformance:SetState("Memory/TerrainGraphics", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.TerrainVoxels)
		end)
		mServerPerformance:SetState("Memory/Textures", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture)
		end)
		mServerPerformance:SetState("Memory/CharacterTextures", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTextureCharacter)
		end)
		mServerPerformance:SetState("Memory/SoundsData", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Sounds)
		end)
		mServerPerformance:SetState("Memory/SoundsStreaming", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.StreamingSounds)
		end)
		mServerPerformance:SetState("Memory/TerrainVoxels", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.TerrainVoxels)
		end)
		mServerPerformance:SetState("Memory/Guis", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)
		end)
		mServerPerformance:SetState("Memory/Animations", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Animation)
		end)
		mServerPerformance:SetState("Memory/Pathfinding", function()
			return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Navigation)
		end)
		mServerPerformance:SetState("PlayerHTTPLimit", function()
			return 500 / #Players:GetChildren()
		end)
	end)
	return mServerPerformance :: any
end

function Templates.market(player: Player): Midas?
	if not Config.Templates.Market then
		return
	end
	assert(RunService:IsServer(), "Bad domain")

	local mMarket = Midas._new(player, "Spending")

	local products = 0
	local gamepasses = 0

	task.spawn(function()
		mMarket:SetState("Products", function()
			return products
		end)
		mMarket:SetState("Gamepasses", function()
			return gamepasses
		end)
		mMarket:SetState("Spending", function()
			return products + gamepasses
		end)

		mMarket._Maid:GiveTask(
			MarketplaceService.PromptPurchaseFinished:Connect(function(plr: Player, id: number, success: boolean)
				if plr ~= player and success then
					local itemInfo = MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
					mMarket:Fire("Purchase/Product/" .. itemInfo.Name)
					products += itemInfo.PriceInRobux
				end
			end)
		)
		mMarket._Maid:GiveTask(
			MarketplaceService.PromptGamePassPurchaseFinished:Connect(
				function(plr: Player, id: number, success: boolean)
					if plr ~= player and success then
						local itemInfo = MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
						mMarket:Fire("Purchase/Gamepass/" .. itemInfo.Name)
						gamepasses += itemInfo.Gamepasses
					end
				end
			)
		)
	end)

	return mMarket :: any
end

function Templates.exit(player: Player, getIfTeleporting: () -> boolean): Midas?
	if not Config.Templates.Exit then
		return
	end
	assert(RunService:IsServer(), "Bad domain")

	local mExit = Midas._new(player, "Exit")
	task.spawn(function()
		mExit._Maid:GiveTask(game.Players.PlayerRemoving:Connect(function(remPlayer: Player)
			local isTeleporting = getIfTeleporting()
			if remPlayer == player and isTeleporting == false then
				remPlayer:SetAttribute("IsExiting", true)
				mExit:Fire("Quit")
				mExit._Maid:Destroy()
			end
		end))
		mExit._Maid:GiveTask(game.Close:Connect(function()
			mExit:Fire("Close")
		end))
	end)

	return mExit :: any
end

function Templates.serverIssues(player: Player): Midas?
	if not Config.Templates.ServerIssues then
		return
	end

	assert(RunService:IsServer(), "Bad domain")

	local mIssues = Midas._new(player, "Issues/Server")

	local prevErrorMsg = ""
	mIssues:SetState("Error/Message", function()
		return prevErrorMsg
	end)

	mIssues._Maid:GiveTask(LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
		if string.find(message, player.Name) then
			if (messageType == Enum.MessageType.MessageError) then
				message = string.gsub(message, player.Name, "{PLAYER}")
				for i, plr in ipairs(game.Players:GetChildren()) do
					if plr:IsA("Player") then
						message = string.gsub(message, plr.Name, "{OTHER_PLAYER}")
					end
				end

				prevErrorMsg = message
				mIssues:Fire("Error")
			end
		end
	end))

	return mIssues :: any
end


function Templates.clientIssues(player: Player): Midas?
	if not Config.Templates.ClientIssues then
		return
	end

	assert(RunService:IsClient(), "Bad domain")

	local mIssues = Midas._new(player, "Issues/Client")

	local prevErrorMsg = ""
	mIssues:SetState("Error/Message", function()
		return prevErrorMsg
	end)

	mIssues._Maid:GiveTask(LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
		-- if string.find(message, player.Name) then
		if (messageType == Enum.MessageType.MessageError) then
			message = string.gsub(message, player.Name, "{PLAYER}")
			for i, plr in ipairs(game.Players:GetChildren()) do
				if plr:IsA("Player") then
					message = string.gsub(message, plr.Name, "{OTHER_PLAYER}")
				end
			end

			prevErrorMsg = message
			mIssues:Fire("Error")
		end
		-- end
	end))

	return mIssues :: any
end

function Templates.groups(player: Player): Midas?
	if not Config.Templates.Group then
		return
	end

	local mGroups = Midas._new(player, "Groups")
	mGroups:SetRoundingPrecision(0)

	task.spawn(function()
		local groupConfig = Config.Templates.Group
		assert(groupConfig ~= nil)
		for groupName, groupId in pairs(groupConfig) do
			local isInGroup = player:IsInGroup(groupId)
			local role = if isInGroup then player:GetRoleInGroup(groupId) else "none"
			mGroups:SetState(string.gsub(groupName, "%s", "_"), function()
				return role
			end)
		end
	end)

	return mGroups :: any
end

function Templates.demographics(player: Player): Midas?
	if not Config.Templates.Demographics then
		return
	end
	assert(RunService:IsClient(), "Bad domain")
	local localizationService = game:GetService("LocalizationService")

	local mDemographics = Midas._new(player, "Demographics")
	mDemographics:SetRoundingPrecision(0)

	task.spawn(function()
		mDemographics:SetState("AccountAge", function()
			return player.AccountAge
		end)
		mDemographics:SetState("RobloxLangugage", function()
			return localizationService.RobloxLocaleId
		end)
		mDemographics:SetState("SystemLanguage", function()
			return localizationService.SystemLocaleId
		end)
		mDemographics:SetState("Platform/Accelerometer", function()
			return UserInputService.VREnabled
		end)
		mDemographics:SetState("Platform/Gamepad", function()
			return UserInputService.GamepadConnected
		end)
		mDemographics:SetState("Platform/Gyroscope", function()
			return UserInputService.GyroscopeEnabled
		end)
		mDemographics:SetState("Platform/Keyboard", function()
			return UserInputService.KeyboardEnabled
		end)
		mDemographics:SetState("Platform/Mouse", function()
			return UserInputService.MouseEnabled
		end)
		mDemographics:SetState("Platform/TouchEnabled", function()
			return UserInputService.TouchEnabled
		end)
		mDemographics:SetState("Platform/VCEnabled", function()
			return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
		end)
		mDemographics:SetState("Platform/ScreenSize", function()
			return game.Workspace.CurrentCamera.ViewportSize.Magnitude
		end)
		mDemographics:SetState("Platform/ScreenRatio", function()
			local size = game.Workspace.CurrentCamera.ViewportSize
			local x = size.X
			local y = size.Y
			local ratio = y / x
			if ratio == 16 / 10 then
				return "16:10"
			elseif ratio == 16 / 9 then
				return "16:9"
			elseif ratio == 5 / 4 then
				return "5:4"
			elseif ratio == 5 / 3 then
				return "5:3"
			elseif ratio == 3 / 2 then
				return "3:2"
			elseif ratio == 4 / 3 then
				return "4:3"
			elseif ratio == 9 / 16 then
				return "9:16"
			end
			return (math.round(100 / ratio) / 100) .. ":1"
		end)
	end)

	return mDemographics :: any
end

function Templates.policy(player: Player): Midas?
	if not Config.Templates.Policy then
		return
	end
	local mPolicy = Midas._new(player, "Policy")
	log("created policy midas", player, mPolicy.Path)
	task.spawn(function()
		log("getting policy info", player, mPolicy.Path)
		local policyInfo = PolicyService:GetPolicyInfoForPlayerAsync(player)
		log("got policy info", player, mPolicy.Path)
		mPolicy:SetState("Lootboxes", function()
			return policyInfo.ArePaidRandomItemsRestricted
		end)
		mPolicy:SetState("AllowedLinks", function()
			return policyInfo.AllowedExternalLinkReferences
		end)
		mPolicy:SetState("Trading", function()
			return policyInfo.IsPaidItemTradingAllowed
		end)
		mPolicy:SetState("China", function()
			return policyInfo.IsSubjectToChinaPolicies
		end)
	end)
	return mPolicy :: any
end

function Templates.clientPerformance(player: Player): Midas?
	if not Config.Templates.ClientPerformance then
		return
	end
	local mClientPerformance = Midas._new(player, "Performance/Client")
	mClientPerformance:SetRoundingPrecision(0)

	task.spawn(function()
		mClientPerformance:SetState("Ping", function()
			return math.clamp(player:GetNetworkPing(), 0, 10 ^ 6)
		end)

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
		mClientPerformance:SetState("FPS", function()
			return frames / duration
		end)

		mClientPerformance._Maid:GiveTask(game.GraphicsQualityChangeRequest:Connect(function(increase)
			if increase then
				mClientPerformance:Fire("Graphics/Increase")
			else
				mClientPerformance:Fire("Graphics/Decrease")
			end
		end))
	end)

	return mClientPerformance :: any
end

function Templates.settings(player: Player): Midas?
	if not Config.Templates.Settings then
		return
	end
	local gameSettings = UserSettings():GetService("UserGameSettings")

	local mSettings = Midas._new(player, "Settings")

	task.spawn(function()
		mSettings:SetState("ComputerMovementMode", function()
			return gameSettings.ComputerMovementMode.Name
		end)
		mSettings:SetState("ControlMode", function()
			return gameSettings.ControlMode.Name
		end)
		mSettings:SetState("MouseSensitivity", function()
			return gameSettings.MouseSensitivity
		end)
		mSettings:SetState("RotationType", function()
			return gameSettings.RotationType.Name
		end)
		mSettings:SetState("SavedQualityLevel", function()
			return gameSettings.SavedQualityLevel.Value
		end)
		mSettings:SetState("TouchCameraMovementMode", function()
			return gameSettings.TouchCameraMovementMode.Value
		end)
		mSettings:SetState("TouchMovementMode", function()
			return gameSettings.TouchMovementMode.Value
		end)
		mSettings:SetState("VignetteEnabled", function()
			return gameSettings.VignetteEnabled
		end)
	end)

	return mSettings :: any
end

return Templates
