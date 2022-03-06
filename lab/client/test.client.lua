local packages = game.ReplicatedStorage:WaitForChild("Packages")
local fusion = require(packages:WaitForChild("fusion"))
local player = game.Players.LocalPlayer

-- player.CharacterAdded:Connect(function()
local midasAnalytics = require(packages:WaitForChild("midas"))
local chatMaid = midasAnalytics.new("CHAT", player)

local fill = fusion.Value(2)

chatMaid:Connect(player.Chatted)
chatMaid.FILL = fill


