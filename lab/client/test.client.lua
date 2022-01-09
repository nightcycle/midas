local player = game.Players.LocalPlayer

-- player.CharacterAdded:Connect(function()
local midasAnalytics = require(game.ReplicatedStorage:WaitForChild("Packages"):WaitForChild("midas"))
local chatMaid = midasAnalytics.new("CHAT", "CHARACTER", player)
chatMaid:Connect(player.Chatted)
chatMaid.FILL = #game.Players:GetChildren()
-- end)

