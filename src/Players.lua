local packages = script.Parent.Parent
local rodux = require(packages:WaitForChild("rodux"))

local playFab = require(script.Parent:WaitForChild("PlayFab"))

local players = {}

local function setUpPlayer(player)
	local entityToken, sessionTicket = playFab:Register(player)

	players[player] = rodux.combineReducers({
		PlayFab = rodux.createReducer(function()
			return {
				EntityToken = entityToken,
				SessionTicket = sessionTicket,
			}
		end),
		State = rodux.createReducer(function(state, action)
			return {

			}
		end),
		Session = rodux.createReducer(function(state, action)
			return {

			}
		end),
	})

	player.CharacterAdded:Connect(function()

	end)
	player.Chatted:Connect(function(msg)

	end)
	player.CharacterRemoving:Connect(function()

	end)
end

game.Players.PlayerAdded:Connect(setUpPlayer)

game.Players.PlayerRemoving:Connect(function(player)
	playFab:Deregister(player)
end)

game.Close:Connect(function()

end)

return players