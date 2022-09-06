--!strict
local _RunService = game:GetService("RunService")
local _Math = require(game.ReplicatedStorage.Packages.Math)
local _Maid = require(game.ReplicatedStorage.Packages.Maid)
local _Signal = require(game.ReplicatedStorage.Packages.Signal)

local NetworkUtil = {}
NetworkUtil.__index = NetworkUtil

local function getInstance(key: string, className: string, parent: Instance?): any
	parent = parent or script
	assert(parent ~= nil)
	local cur = parent:FindFirstChild(key)
	if cur then
		if cur:IsA(className) then
			return cur
		else
			error(cur.ClassName .. " key [" .. key .. "] can't be reused as a " .. tostring(className))
		end
	else
		local newInst = Instance.new(className :: any)
		newInst.Name = key
		newInst.Parent = parent
		return newInst
	end
end

function NetworkUtil.getRemoteEvent(key: string, parent: Instance?): RemoteEvent
	if _RunService:IsServer() then
		return getInstance(key, "RemoteEvent", parent)
	else
		return script:WaitForChild(key)
	end
end

function NetworkUtil.getRemoteFunction(key: string, parent: Instance?): RemoteFunction
	if _RunService:IsServer() then
		return getInstance(key, "RemoteFunction", parent)
	else
		return script:WaitForChild(key)
	end
end

return NetworkUtil
