local packages = game.ReplicatedStorage:WaitForChild("Packages")

local titleId = "82C4C"
local devSecretKey = "PK9MCKRMBC9BD7J5TMQX9R6SPKD6DC7K41YHPIXKFUTK7KBZ1N"

local midas = game.ServerStorage:WaitForChild("midas")
midas.Parent = packages
local analytics = require(packages:WaitForChild("midas"))(titleId, devSecretKey)
