local titleId = "82C4C"
local devSecretKey = "CB6D9C684247986C"
local midas = game.ServerStorage:WaitForChild("midas")
midas.Parent = game.ReplicatedStorage:WaitForChild("Packages")
local midasAnalytics = require(midas)
midasAnalytics = midasAnalytics(titleId, devSecretKey)
