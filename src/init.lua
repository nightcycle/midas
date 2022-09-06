--!strict
local RunService = game:GetService("RunService")

-- Packages
local _Package = script
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)

-- Modules
local Config = require(_Package.Config)
local PlayFab = require(_Package.PlayFab)
local Midas = require(_Package.Midas)
local Profile = require(_Package.Profile)
local Templates = require(_Package.Templates)

export type Midas = Midas.Midas
export type TeleportDataEntry = Profile.TeleportDataEntry
type Profile = Profile.Profile

local Service = {}
Service.__type = "Analytics"
Service.__index = Service

function Service:Midas(player: Player, eventKeyPath: string): Midas
	return Midas.new(player, eventKeyPath)
end

function Service:GetConfig()
	return Config
end

function Service:LoadDefault(player: Player)
	local profile = Profile.get(player.UserId)
	assert(profile ~= nil)

	if RunService:IsServer() then
		Templates.join(player, profile._WasTeleported)
		Templates.chat(player)	
		Templates.population(player)
		Templates.serverPerformance(player, function() return profile.TimeDifference end, function() return profile.EventsPerMinute end)
		Templates.market(player)
		Templates.exit(player, function() return profile._IsTeleporting end)

		-- Track character properties
		local function loadCharacter(character: Model)
			profile:SetMidas(Templates.character(character))
		end
		profile._Maid:GiveTask(player.CharacterAdded:Connect(loadCharacter))
		if player.Character then loadCharacter(player.Character) end
	else
		Templates.demographics(player)
		Templates.policy(player)
		Templates.clientPerformance(player)
		Templates.settings(player)
	end
end

function Service:InsertTeleportDataEntry(player: Player, teleportData: {[any]: any}?): {
	MidasAnalyticsData: TeleportDataEntry,
	[any]: any
}
	assert(RunService:IsServer(), "Bad domain")
	teleportData = teleportData or {}
	assert(teleportData ~= nil)

	local profile = Profile.get(player.UserId)
	if profile then
		teleportData.MidasAnalyticsData = profile:Teleport()
	end

	return teleportData
end

function Service.init(titleId: string, devSecretKey: string)
	assert(RunService:IsServer(), "Bad domain")
	PlayFab.init(titleId, devSecretKey)
	return Service
end

return Service