local RunService = game:GetService("RunService")
if RunService:IsClient() then return {} end

local packages = script.Parent.Parent
local playFab = require(script.Parent:WaitForChild("PlayFab"))
local players = {}

local function setUpPlayer(player)
	local sessionId, playerId = playFab:Register(tostring(player.UserId))
	players[player] = {
		PlayerId = playerId,
		SID = sessionId,
	}
end



game.Players.PlayerAdded:Connect(setUpPlayer)
task.spawn(function()
	for i, player in ipairs(game.Players:GetChildren()) do
		setUpPlayer(player)
	end
end)

game.Players.PlayerRemoving:Connect(function(player)
	players[player] = nil
end)

return players