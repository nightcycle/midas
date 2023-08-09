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
	if Config.Template.Event.Join.Enter or Config.Template.Event.Join.Teleport then
		assert(RunService:IsServer(), "Bad domain")
		local mJoin = Tracker._new(player, "Join", profile)
		log("loaded", player, mJoin.Path)
		if wasTeleportedIn and Config.Template.Event.Join.Teleport then
			log("firing teleport", player, mJoin.Path)
			mJoin:Fire("Teleport")
		else
			if Config.Template.Event.Join.Enter then
				log("firing enter", player, mJoin.Path)
				mJoin:Fire("Enter")
			end
		end
		return mJoin :: any
	else
		return nil
	end
end

function Templates.chat(player: Player, profile: Profile): Tracker?
	assert(RunService:IsServer(), "Bad domain")

	if Config.Template.State.Chat.Count or Config.Template.State.Chat.LastMessage or Config.Template.Event.Chat.Spoke then
		local mChat = Tracker._new(player, "Chat", profile)
		log("loaded", player, mChat.Path)

		task.spawn(function()
			local lastMessage: string?
			local chatCount = 0

			if Config.Template.State.Chat.Count then
				mChat:SetState("LastMessage", function()
					return lastMessage
				end)
			end

			if Config.Template.State.Chat.Count then
				mChat:SetState("Count", function()
					return chatCount
				end)
			end

			mChat._Maid:GiveTask(player.Chatted:Connect(function(msg)
				lastMessage = string.sub(msg, 1, 140)
				if Config.Template.Event.Chat.Spoke then
					mChat:Fire("Spoke")
				end
				chatCount += 1
			end))
		end)

		return mChat :: any
	else
		return nil
	end
end

function Templates.character(character: Model, profile: Profile): Tracker?
	assert(RunService:IsServer(), "Bad domain")
	local player = Players:GetPlayerFromCharacter(character)
	assert(player ~= nil)

	local maid = Maid.new()

	local isUsed = false
	for k, v in pairs(Config.Template.State.Character) do
		if v then
			isUsed = true
		end
	end
	isUsed = isUsed or Config.Template.Event.Character.Died

	if isUsed then
		local mCharacter = Tracker._new(player, "Character", profile)
		mCharacter:SetRoundingPrecision(1)

		maid:GiveTask(character.Destroying:Connect(function()
			log("character destroying", player, mCharacter.Path)
			maid:Destroy()
		end))

		local isDead = false
		task.spawn(function()
			if Config.Template.State.Character.IsDead then
				mCharacter:SetState("IsDead", function()
					return isDead
				end)
			end
			if Config.Template.State.Character.Height then
				mCharacter:SetState("Height", function()
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					assert(humanoid ~= nil)
					local humDesc = humanoid:GetAppliedDescription()
					return humDesc.HeightScale
				end)
			end
			if Config.Template.State.Character.Mass then
				mCharacter:SetState("Mass", function()
					local primaryPart = character.PrimaryPart
					assert(primaryPart ~= nil)
					return primaryPart.AssemblyMass
				end)
			end
			if Config.Template.State.Character.State then
				mCharacter:SetState("State", function()
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					assert(humanoid ~= nil)
					return humanoid:GetState().Name
				end)
			end
			if Config.Template.State.Character.WalkSpeed then
				mCharacter:SetState("WalkSpeed", function()
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					assert(humanoid ~= nil)
					return humanoid.WalkSpeed
				end)
			end
			if Config.Template.State.Character.Position then
				mCharacter:SetState("Position", function()
					local primaryPart = character.PrimaryPart
					assert(primaryPart ~= nil)
					return Vector2.new(primaryPart.Position.X, primaryPart.Position.Z)
				end)
			end
			if Config.Template.State.Character.Altitude then
				mCharacter:SetState("Altitude", function()
					local primaryPart = character.PrimaryPart
					if primaryPart then
						return primaryPart.Position.Y
					end
					return nil
				end)
			end
			if Config.Template.State.Character.JumpPower then
				mCharacter:SetState("JumpPower", function()
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					assert(humanoid ~= nil)
					return humanoid.JumpPower
				end)
			end
			if Config.Template.State.Character.Health then
				mCharacter:SetState("Health", function()
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					assert(humanoid ~= nil)
					return humanoid.Health
				end)
			end
			if Config.Template.State.Character.MaxHealth then
				mCharacter:SetState("MaxHealth", function()
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					assert(humanoid ~= nil)
					return humanoid.MaxHealth
				end)
			end

			local deaths = 0
			if Config.Template.State.Character.Deaths then
				mCharacter:SetState("Deaths", function()
					return deaths
				end)
			end

			local humanoid = character:WaitForChild("Humanoid", 15)
			assert(humanoid ~= nil and humanoid:IsA("Humanoid"), "Bad humanoid")

			maid:GiveTask(humanoid.Died:Connect(function()
				deaths += 1
				if Config.Template.Event.Character.Died then
					mCharacter:Fire("Died")
				end
				isDead = true
			end))
		end)

		return mCharacter :: any
	else
		return nil
	end
end

function Templates.population(player: Player, profile: Profile): Tracker?
	if
		Config.Template.State.Population.Total
		or Config.Template.State.Population.Team
		or Config.Template.State.Population.PeakFriends
		or Config.Template.State.Population.Friends
		or Config.Template.State.Population.SpeakingDistance
	then
		assert(RunService:IsServer(), "Bad domain")
		local mPopulation = Tracker._new(player, "Population", profile)

		task.spawn(function()
			if Config.Template.State.Population.Total then
				mPopulation:SetState("Total", function()
					return #Players:GetChildren()
				end)
			end
			if Config.Template.State.Population.Team then
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
			end

			if Config.Template.State.Population.PeakFriends or Config.Template.State.Population.Friends then
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
				if Config.Template.State.Population.PeakFriends then
					mPopulation:SetState("PeakFriends", function()
						return peakFriends
					end)
				end
				if Config.Template.State.Population.Friends then
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
				end
			end
			-- end
			if Config.Template.State.Population.SpeakingDistance then
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
			end
		end)

		return mPopulation :: any
	else
		return nil
	end
end

function Templates.serverPerformance(player: Player, profile: Profile, getTimeDifference: () -> number, getEventsPerMinute: () -> number): Tracker?
	local isUsed = false
	local function getUsage(tabl: { [string]: any }): boolean
		local altUsage = false
		for k, v in pairs(tabl) do
			if v == true then
				isUsed = true
				altUsage = true
			end
		end
		return altUsage
	end
	getUsage(Config.Template.State.Performance.Server)
	getUsage(Config.Template.State.Performance.Server.Network)
	local networkDataUsage = getUsage(Config.Template.State.Performance.Server.Network.Data)
	local networkPhysicsUsage = getUsage(Config.Template.State.Performance.Server.Network.Physics)
	local memoryUsage = getUsage(Config.Template.State.Performance.Server.Memory)

	if isUsed then
		assert(RunService:IsServer(), "Bad domain")
		local mServerPerformance = Tracker._new(player, "Performance/Server", profile)
		mServerPerformance:SetRoundingPrecision(0)
		task.spawn(function()
			if Config.Template.State.Performance.Server.EventsPerMinute then
				mServerPerformance:SetState("EventsPerMinute", function()
					local timeDifference = getTimeDifference()
					local eventsPerMinute = getEventsPerMinute()
					if timeDifference < 60 then
						return 60 * eventsPerMinute / timeDifference
					else
						return eventsPerMinute
					end
				end)
			end
			if Config.Template.State.Performance.Server.Ping then
				mServerPerformance:SetState("Ping", function()
					return math.clamp(player:GetNetworkPing(), 0, 10 ^ 6)
				end)
			end
			if Config.Template.State.Performance.Server.ServerTime then
				mServerPerformance:SetState("ServerTime", function()
					return math.round(time())
				end)
			end
			if Config.Template.State.Performance.Server.HeartRate then
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
			end
			if Config.Template.State.Performance.Server.Instances then
				mServerPerformance:SetState("Instances", function()
					return math.round(StatService.InstanceCount / 1000) * 1000
				end)
			end
			if Config.Template.State.Performance.Server.MovingParts then
				mServerPerformance:SetState("MovingParts", function()
					return StatService.InstanceCount
				end)
			end

			if networkDataUsage then
				if Config.Template.State.Performance.Server.Network.Data.Send then
					mServerPerformance:SetState("Network/Data/Send", function()
						return StatService.DataSendKbps
					end)
				end
				if Config.Template.State.Performance.Server.Network.Data.Receive then
					mServerPerformance:SetState("Network/Data/Receive", function()
						return StatService.DataReceiveKbps
					end)
				end
			end

			if networkPhysicsUsage then
				if Config.Template.State.Performance.Server.Network.Physics.Send then
					mServerPerformance:SetState("Network/Physics/Send", function()
						return StatService.PhysicsSendKbps
					end)
				end
				if Config.Template.State.Performance.Server.Network.Physics.Receive then
					mServerPerformance:SetState("Network/Physics/Receive", function()
						return StatService.PhysicsReceiveKbps
					end)
				end
			end

			if memoryUsage then
				if Config.Template.State.Performance.Server.Memory.Internal then
					mServerPerformance:SetState("Memory/Internal", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Internal)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.HttpCache then
					mServerPerformance:SetState("Memory/HttpCache", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.HttpCache)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Instances then
					mServerPerformance:SetState("Memory/Instances", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Signals then
					mServerPerformance:SetState("Memory/Signals", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Signals)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.LuaHeap then
					mServerPerformance:SetState("Memory/LuaHeap", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Script then
					mServerPerformance:SetState("Memory/Script", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.PhysicsCollision then
					mServerPerformance:SetState("Memory/PhysicsCollision", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsCollision)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.PhysicsParts then
					mServerPerformance:SetState("Memory/PhysicsParts", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsParts)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.CSG then
					mServerPerformance:SetState("Memory/CSG", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Particle then
					mServerPerformance:SetState("Memory/Particle", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParticles)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Part then
					mServerPerformance:SetState("Memory/Part", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParts)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.MeshPart then
					mServerPerformance:SetState("Memory/MeshPart", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.SpatialHash then
					mServerPerformance:SetState("Memory/SpatialHash", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsSpatialHash)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.TerrainGraphics then
					mServerPerformance:SetState("Memory/TerrainGraphics", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.TerrainVoxels)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Textures then
					mServerPerformance:SetState("Memory/Textures", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.CharacterTextures then
					mServerPerformance:SetState("Memory/CharacterTextures", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTextureCharacter)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.SoundsData then
					mServerPerformance:SetState("Memory/SoundsData", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Sounds)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.SoundsStreaming then
					mServerPerformance:SetState("Memory/SoundsStreaming", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.StreamingSounds)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.TerrainVoxels then
					mServerPerformance:SetState("Memory/TerrainVoxels", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.TerrainVoxels)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Guis then
					mServerPerformance:SetState("Memory/Guis", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Animations then
					mServerPerformance:SetState("Memory/Animations", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Animation)
					end)
				end
				if Config.Template.State.Performance.Server.Memory.Pathfinding then
					mServerPerformance:SetState("Memory/Pathfinding", function()
						return StatService:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Navigation)
					end)
				end
			end
		end)
		return mServerPerformance :: any
	else
		return nil
	end
end

function Templates.market(player: Player, profile: Profile): Tracker?
	assert(RunService:IsServer(), "Bad domain")

	if
		Config.Template.State.Spending.Product
		or Config.Template.State.Spending.Gamepass
		or Config.Template.State.Spending.Total
		or Config.Template.Event.Spending.Purchase.Product
		or Config.Template.Event.Spending.Purchase.Gamepass
	then
		local mMarket = Tracker._new(player, "Spending", profile)

		local products = 0
		local gamepasses = 0

		task.spawn(function()
			if Config.Template.State.Spending.Product or Config.Template.Event.Spending.Purchase.Product or Config.Template.State.Spending.Total then
				if Config.Template.State.Spending.Product then
					mMarket:SetState("Spending/Product", function()
						return products
					end)
				end

				mMarket._Maid:GiveTask(MarketplaceService.PromptPurchaseFinished:Connect(function(plr: Player, id: number, success: boolean)
					if plr ~= player and success then
						local itemInfo = MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
						if Config.Template.Event.Spending.Purchase.Product then
							mMarket:Fire("Purchase/Product", {
								Name = itemInfo.Name,
								Price = itemInfo.PriceInRobux,
							})
						end
						products += itemInfo.PriceInRobux
					end
				end))
			end

			if Config.Template.State.Spending.Gamepass or Config.Template.Event.Spending.Purchase.Gamepass or Config.Template.State.Spending.Total then
				if Config.Template.State.Spending.Gamepass then
					mMarket:SetState("Spending/Gamepass", function()
						return gamepasses
					end)
				end

				mMarket._Maid:GiveTask(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, id: number, success: boolean)
					if plr ~= player and success then
						local itemInfo = MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
						if Config.Template.Event.Spending.Purchase.Gamepass then
							mMarket:Fire("Purchase/Gamepass", {
								Name = itemInfo.Name,
								Price = itemInfo.PriceInRobux,
							})
						end
						gamepasses += itemInfo.PriceInRobux
					end
				end))
			end
			if Config.Template.State.Spending.Total then
				mMarket:SetState("Spending/Total", function()
					return products + gamepasses
				end)
			end
		end)

		return mMarket :: any
	else
		return nil
	end
end

function Templates.exit(player: Player, profile: Profile, getIfTeleporting: () -> boolean): Tracker?
	assert(RunService:IsServer(), "Bad domain")

	if Config.Template.Event.Exit.Close or Config.Template.Event.Exit.Quit or Config.Template.Event.Exit.Disconnect then
		local mExit = Tracker._new(player, "Exit", profile)
		task.spawn(function()
			if Config.Template.Event.Exit.Quit then
				mExit._Maid:GiveTask(Players.PlayerRemoving:Connect(function(remPlayer: Player)
					local isTeleporting = getIfTeleporting()
					if remPlayer == player and isTeleporting == false then
						mExit:Fire("Quit")
					end
				end))
			end
			if Config.Template.Event.Exit.Disconnect then
				mExit._Maid:GiveTask(Players.PlayerDisconnecting:Connect(function(remPlayer: Player)
					if remPlayer == player then
						mExit:Fire("Disconnect")
					end
				end))
			end
			if Config.Template.Event.Exit.Close then
				mExit._Maid:GiveTask(game.Close:Connect(function()
					mExit:Fire("Close")
				end))
			end
		end)

		return mExit :: any
	else
		return nil
	end
end

function Templates.groups(player: Player): Tracker?
	assert(RunService:IsClient())

	local groupCount = 0
	for k, v in pairs(Config.Template.State.Groups) do
		groupCount += 1
	end
	if groupCount > 0 then
		local mGroups = Tracker._new(player, "Groups")
		mGroups:SetRoundingPrecision(0)

		task.spawn(function()
			local groupConfig = Config.Template.State.Groups
			assert(groupConfig ~= nil)

			local callsPerMinute = math.floor(15 / groupCount) - 1

			for groupName, groupId in pairs(groupConfig) do
				local rank = player:GetRankInGroup(groupId)

				if callsPerMinute >= 1 then
					local lastUpdate = tick()
					mGroups._Maid:GiveTask(RunService.Heartbeat:Connect(function()
						if tick() - lastUpdate > 60 / callsPerMinute then
							lastUpdate = tick()
							rank = player:GetRankInGroup(groupId)
						end
					end))
				end

				mGroups:SetState(string.gsub(groupName, "%s", "_"), function()
					return rank
				end)
			end
		end)

		return mGroups :: any
	else
		return nil
	end
end

function Templates.badges(player: Player, profile: Profile): Tracker?
	assert(RunService:IsServer())

	local badgeCount = 0
	for k, v in pairs(Config.Template.State.Badges) do
		badgeCount += 1
	end
	if badgeCount > 0 then
		local BadgeService = game:GetService("BadgeService")

		local mBadges = Tracker._new(player, "Badges", profile)
		mBadges:SetRoundingPrecision(0)

		task.spawn(function()
			local badgesConfig = Config.Template.State.Badges
			assert(badgesConfig ~= nil)

			local callsPerMinute = math.floor(35 / badgeCount) - 1

			for badgeName, badgeId in pairs(badgesConfig) do
				local isBadgeOwned = BadgeService:UserHasBadgeAsync(player.UserId, badgeId)

				if not isBadgeOwned and callsPerMinute >= 1 then
					local lastUpdate = tick()
					mBadges._Maid:GiveTask(RunService.Heartbeat:Connect(function()
						if tick() - lastUpdate > 60 / callsPerMinute and not isBadgeOwned then
							lastUpdate = tick()
							isBadgeOwned = BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
						end
					end))
				end

				-- local role = if isInGroup then player:GetRoleInGroup(groupId) else "none"
				mBadges:SetState(string.gsub(badgeName, "%s", "_"), function()
					return isBadgeOwned
				end)
			end
		end)

		return mBadges :: any
	else
		return nil
	end
end

function Templates.demographics(player: Player): Tracker?
	assert(RunService:IsClient(), "Bad domain")

	local isUsed = false
	for k, v in pairs(Config.Template.State.Demographics) do
		if v == true then
			isUsed = true
		end
	end
	local isPlatformUsed = false
	for k, v in pairs(Config.Template.State.Demographics.Platform) do
		if v == true then
			isPlatformUsed = true
		end
	end
	local isUserSettingsUsed = false
	for k, v in pairs(Config.Template.State.Demographics.UserSettings) do
		if v == true then
			isUserSettingsUsed = true
		end
	end
	if isUsed or isPlatformUsed or isUserSettingsUsed then
		local localizationService = game:GetService("LocalizationService")

		local mDemographics = Tracker._new(player, "Demographics")
		mDemographics:SetRoundingPrecision(3)

		task.spawn(function()
			if isUsed then
				if Config.Template.State.Demographics.AccountAge then
					mDemographics:SetState("AccountAge", function()
						return player.AccountAge
					end)
				end
				if Config.Template.State.Demographics.RobloxLanguage then
					mDemographics:SetState("RobloxLanguage", function()
						return localizationService.RobloxLocaleId
					end)
				end
				if Config.Template.State.Demographics.SystemLanguage then
					mDemographics:SetState("SystemLanguage", function()
						return localizationService.SystemLocaleId
					end)
				end
			end
			if isUserSettingsUsed then
				local userSettings = UserSettings()
				local gameSettings = userSettings:GetService("UserGameSettings")
				if Config.Template.State.Demographics.UserSettings.GamepadCameraSensitivity then
					mDemographics:SetState("UserSettings/GamepadCameraSensitivity", function()
						return gameSettings.GamepadCameraSensitivity
					end)
				end
				if Config.Template.State.Demographics.UserSettings.MouseSensitivity then
					mDemographics:SetState("UserSettings/MouseSensitivity", function()
						return gameSettings.MouseSensitivity
					end)
				end
				if Config.Template.State.Demographics.UserSettings.SavedQualityLevel then
					mDemographics:SetState("UserSettings/SavedQualityLevel", function()
						return gameSettings.SavedQualityLevel.Value
					end)
				end
			end
			if isPlatformUsed then
				if Config.Template.State.Demographics.Platform.Accelerometer then
					mDemographics:SetState("Platform/Accelerometer", function()
						return UserInputService.AccelerometerEnabled
					end)
				end
				if Config.Template.State.Demographics.Platform.Gamepad then
					mDemographics:SetState("Platform/Gamepad", function()
						return UserInputService.GamepadEnabled
					end)
				end
				if Config.Template.State.Demographics.Platform.Gyroscope then
					mDemographics:SetState("Platform/Gyroscope", function()
						return UserInputService.GyroscopeEnabled
					end)
				end
				if Config.Template.State.Demographics.Platform.Keyboard then
					mDemographics:SetState("Platform/Keyboard", function()
						return UserInputService.KeyboardEnabled
					end)
				end
				if Config.Template.State.Demographics.Platform.Mouse then
					mDemographics:SetState("Platform/Mouse", function()
						return UserInputService.MouseEnabled
					end)
				end
				if Config.Template.State.Demographics.Platform.Touch then
					mDemographics:SetState("Platform/Touch", function()
						return UserInputService.TouchEnabled
					end)
				end
				if Config.Template.State.Demographics.Platform.VR then
					mDemographics:SetState("Platform/VR", function()
						return UserInputService.VREnabled
					end)
				end
				if Config.Template.State.Demographics.Platform.ScreenSize then
					mDemographics:SetState("Platform/ScreenSize", function()
						return game.Workspace.CurrentCamera.ViewportSize.Magnitude
					end)
				end
				if Config.Template.State.Demographics.Platform.ScreenRatio then
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
				end
			end
		end)

		return mDemographics :: any
	else
		return nil
	end
end

function Templates.clientPerformance(player: Player): Tracker?
	assert(RunService:IsClient())

	if Config.Template.State.Performance.Client.FPS or Config.Template.State.Performance.Client.Ping then
		local mClientPerformance = Tracker._new(player, "Performance/Client")
		mClientPerformance:SetRoundingPrecision(0)

		task.spawn(function()
			if Config.Template.State.Performance.Client.Ping then
				mClientPerformance:SetState("Ping", function()
					return math.round(math.clamp(player:GetNetworkPing() * 1000, 0, 10 ^ 6))
				end)
			end

			if Config.Template.State.Performance.Client.FPS then
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
			end
		end)

		return mClientPerformance :: any
	else
		return nil
	end
end

return Templates
