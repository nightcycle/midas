--!strict
local StatService = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- References
local Package = script.Parent
local Packages = Package.Parent

-- Packages
local Maid = require(Packages:WaitForChild("Maid"))

-- Modules
local Config = require(script.Parent.Config)
local Tracker = require(script.Parent.Tracker)
local Types = require(script.Parent.Types)

type Tracker = Types.PrivateTracker
type Profile = Types.Profile

function log(message: string, player: Player, path: string?)
	if Config.PrintLog then
		print("[", player, "]", "[templates]", "[", path, "]", ":", message)
	end
end

--Class definition
local Templates = {}
Templates.__index = {}

function Templates.join(player: Player, profile: Profile, wasTeleportedIn: boolean): Tracker?
	if not Config.Templates.Join then
		return
	end

	assert(RunService:IsServer(), "Bad domain")
	local mJoin = Tracker._new(player, "Join", profile)
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

function Templates.chat(player: Player, profile: Profile): Tracker?
	if not Config.Templates.Chat then
		return
	end
	assert(RunService:IsServer(), "Bad domain")

	local mChat = Tracker._new(player, "Chat", profile)
	log("loaded", player, mChat.Path)

	task.spawn(function()
		local lastMessage: string?
		local chatCount = 0
		mChat:SetState("LastMessage", function()
			return lastMessage
		end)

		mChat:SetState("Count", function()
			return chatCount
		end)

		mChat._Maid:GiveTask(player.Chatted:Connect(function(msg)
			lastMessage = string.sub(msg, 1, 140)
			mChat:Fire("Spoke")
			chatCount += 1
		end))
	end)

	return mChat :: any
end

function Templates.character(character: Model, profile: Profile): Tracker?
	if not Config.Templates.Character then
		return
	end
	assert(RunService:IsServer(), "Bad domain")
	local player = Players:GetPlayerFromCharacter(character)
	assert(player ~= nil)

	local maid = Maid.new()

	local mCharacter = Tracker._new(player, "Character", profile)
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
			if primaryPart then
				return primaryPart.Position.Y
			end
			return nil
		end)

		mCharacter:SetState("JumpPower", function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			assert(humanoid ~= nil)
			return humanoid.JumpPower
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

function Templates.population(player: Player, profile: Profile): Tracker?
	if not Config.Templates.Population then
		return
	end
	assert(RunService:IsServer(), "Bad domain")
	local mPopulation = Tracker._new(player, "Population", profile)

	task.spawn(function()
		mPopulation:SetState("Total", function()
			return #Players:GetChildren()
		end)
		mPopulation:SetState("Team", function()
			local teamColor = player.TeamColor
			local count = 0
			for i, plr in ipairs(Players:GetChildren()) do
				assert(plr:IsA("Player"))
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
			for i, plr in ipairs(Players:GetChildren()) do
				assert(plr:IsA("Player"))
				if plr ~= player and friends[plr.UserId] == true then
					count += 1
				end
			end
			peakFriends = math.max(peakFriends, count)
			return count
		end)

		-- end
		mPopulation:SetState("SpeakingDistance", function()
			local pChar: Model? = player.Character :: any
			if pChar then
				local pPrim = pChar.PrimaryPart
				if pPrim then
					local count = 0
					for i, plr in ipairs(Players:GetChildren()) do
						assert(plr:IsA("Player"))
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
				else
					return nil
				end
			else
				return nil
			end
		end)
	end)

	return mPopulation :: any
end

function Templates.serverPerformance(
	player: Player, profile: Profile,
	getTimeDifference: () -> number,
	getEventsPerMinute: () -> number
): Tracker?
	if not Config.Templates.ServerPerformance then
		return
	end
	assert(RunService:IsServer(), "Bad domain")
	local mServerPerformance = Tracker._new(player, "Performance/Server", profile)
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
		local frames = 0
		mServerPerformance._Maid:GiveTask(RunService.Heartbeat:Connect(function()
			frames += 1
			delay(1, function()
				frames -= 1
			end)
		end))
		mServerPerformance:SetState("HeartRate", function()
			return frames
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
	end)
	return mServerPerformance :: any
end

function Templates.market(player: Player, profile: Profile): Tracker?
	if not Config.Templates.Market then
		return
	end
	assert(RunService:IsServer(), "Bad domain")

	local mMarket = Tracker._new(player, "Spending", profile)

	local products = 0
	local gamepasses = 0

	task.spawn(function()
		mMarket:SetState("Spending/Product", function()
			return products
		end)
		mMarket:SetState("Spending/Gamepass", function()
			return gamepasses
		end)
		mMarket:SetState("Spending/Total", function()
			return products + gamepasses
		end)

		mMarket._Maid:GiveTask(
			MarketplaceService.PromptPurchaseFinished:Connect(function(plr: Player, id: number, success: boolean)
				if plr ~= player and success then
					local itemInfo = MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
					mMarket:Fire("Purchase/Product", {
						Name = itemInfo.Name,
						Price = itemInfo.PriceInRobux
					})
					products += itemInfo.PriceInRobux
				end
			end)
		)
		mMarket._Maid:GiveTask(
			MarketplaceService.PromptGamePassPurchaseFinished:Connect(
				function(plr: Player, id: number, success: boolean)
					if plr ~= player and success then
						local itemInfo = MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
						mMarket:Fire("Purchase/Gamepass", {
							Name = itemInfo.Name,
							Price = itemInfo.PriceInRobux
						})
						gamepasses += itemInfo.PriceInRobux
					end
				end
			)
		)
	end)

	return mMarket :: any
end

function Templates.exit(player: Player, profile: Profile, getIfTeleporting: () -> boolean): Tracker?
	if not Config.Templates.Exit then
		return
	end
	assert(RunService:IsServer(), "Bad domain")

	local mExit = Tracker._new(player, "Exit", profile)
	task.spawn(function()
		mExit._Maid:GiveTask(Players.PlayerRemoving:Connect(function(remPlayer: Player)
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

function Templates.groups(player: Player, profile: Profile): Tracker?
	if not Config.Templates.Group then
		return
	end

	local mGroups = Tracker._new(player, "Groups", profile)
	mGroups:SetRoundingPrecision(0)

	task.spawn(function()
		local groupConfig = Config.Templates.Group
		assert(groupConfig ~= nil)
		for groupName, groupId in pairs(groupConfig) do
			local isInGroup = player:IsInGroup(groupId)
			-- local role = if isInGroup then player:GetRoleInGroup(groupId) else "none"
			mGroups:SetState(string.gsub(groupName, "%s", "_"), function()
				return isInGroup
			end)
		end
	end)

	return mGroups :: any
end

function Templates.demographics(player: Player): Tracker?
	
	if not Config.Templates.Demographics then
		return
	end
	assert(RunService:IsClient(), "Bad domain")
	local localizationService = game:GetService("LocalizationService")

	local mDemographics = Tracker._new(player, "Demographics")
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
			return UserInputService.AccelerometerEnabled
		end)
		mDemographics:SetState("Platform/Gamepad", function()
			return UserInputService.GamepadEnabled
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
		mDemographics:SetState("Platform/Touch", function()
			return UserInputService.TouchEnabled
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
			return "uncommon"
		end)
	end)

	return mDemographics :: any
end

function Templates.clientPerformance(player: Player): Tracker?
	assert(RunService:IsClient())
	if not Config.Templates.ClientPerformance then
		return
	end
	local mClientPerformance = Tracker._new(player, "Performance/Client")
	mClientPerformance:SetRoundingPrecision(0)

	task.spawn(function()
		mClientPerformance:SetState("Ping", function()
			return math.clamp(player:GetNetworkPing(), 0, 10 ^ 6)
		end)

		local frames = 0
		mClientPerformance._Maid:GiveTask(RunService.RenderStepped:Connect(function()
			frames += 1
			delay(1, function()
				frames -= 1
			end)
		end))
		mClientPerformance:SetState("FPS", function()
			return frames
		end)

		-- mClientPerformance._Maid:GiveTask(game.GraphicsQualityChangeRequest:Connect(function(increase)
		-- 	if increase then
		-- 		mClientPerformance:Fire("Graphics/Increase")
		-- 	else
		-- 		mClientPerformance:Fire("Graphics/Decrease")
		-- 	end
		-- end))
	end)

	return mClientPerformance :: any
end

return Templates
