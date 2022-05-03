while not _G.ServerWorkspaceEnabled do task.wait() end

local replicatedStorage = game:GetService("ReplicatedStorage")
local packages = require(replicatedStorage:WaitForChild("Packages"))
local import = packages("import")
local analytics = import("shared/Analytics")

local titleId = ""
local devSecretKey = ""

local testingGroups = {"A", "B"}
game:SetAttribute("TestingGroup", testingGroups[math.random(#testingGroups)])

local aConfig = analytics:GetConfig()
aConfig.VIP = aConfig.VIP or {}
aConfig.VIP.Groups = {
	--tracking fans of similar games

	--tracking fans of previous work

	--tracking fans of this game
	DevGroupMember = "", --Group the game was made under

	--tracking devs
	["Roblox DevForum Community"] = "3514227",
	["Roblox Virtual Events"] = "9420522",
	Interns = "2868472",
	Admin = "1200769",
}
aConfig.VIP.Developers = { --checks when user is on list
	CJ_Oyer = "42223924",
}
analytics.init(titleId, devSecretKey)


