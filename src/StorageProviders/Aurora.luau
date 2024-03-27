--!strict
local _Package = script.Parent.Parent
local _Packages = _Package.Parent
-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Packages
local HashUtil = require(_Packages:WaitForChild("HashUtil"))

-- Modules
local Util = require(_Package:WaitForChild("Util"))

-- Types
export type Aurora = {
	__index: Aurora,
	_IsAlive: boolean,
	Destroy: (self: Aurora) -> (),
	new: () -> Aurora,
}

-- Class
local Aurora = {} :: Aurora
Aurora.__index = Aurora

function Aurora:Destroy()
	if not self._IsAlive then
		return
	end
	self._IsAlive = false
	table.clear(self)
	setmetatable(self, nil)
end

function Aurora.new()
	local self: Aurora = setmetatable({}, Aurora) :: any
	self._IsAlive = true

	return self
end

return Aurora
