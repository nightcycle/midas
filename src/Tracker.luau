--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))
-- Modules
-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
-- Types
-- Types
type Maid = Maid.Maid
export type Tracker<V> = {
	__index: Tracker<V>,
	_Maid: Maid,
	_IsAlive: boolean,
	_OnDeltaOnly: boolean,
	_FireOnSet: boolean,
	_Interval: number?,
	_Recharge: number?,
	_LastFire: number,
	_HasChangedSinceFire: boolean,
	_GetIfEqual: (a: V?, b: V?) -> boolean,
	_OnFireInvoke: (value: V?) -> (),
	_Value: V?,
	Destroy: (self: Tracker<V>) -> (),
	Set: (self: Tracker<V>, value: V?) -> (),
	Get: (self: Tracker<V>) -> V?,
	Fire: (self: Tracker<V>) -> (),
	new: (
		onDeltaOnly: boolean, 
		fireOnSet: boolean, 
		getIfEqual: (a: V?, b: V?) -> boolean, 
		onFireInvoke: (value: V?) -> (), 
		interval: number?, 
		recharge: number?
	) -> Tracker<V>,
	init: (maid: Maid) -> nil
}

-- Class
local Tracker = {} :: Tracker<{[string]: unknown}>
Tracker.__index = Tracker

function Tracker:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function Tracker:Set(v: {[string]: unknown}?)
	local isDelta = not self._GetIfEqual(self._Value, v)
	if isDelta then
		self._Value = if v then TableUtil.deepCopy(v) else nil
	end
	self._HasChangedSinceFire = self._HasChangedSinceFire or isDelta
	if self._FireOnSet then
		if (not self._OnDeltaOnly) or isDelta then
			self:Fire()
		end
	end
end

function Tracker:Get(): {[string]: unknown}?
	return if self._Value then TableUtil.deepCopy(self._Value) else nil
end

function Tracker:Fire()
	if self._Recharge and tick() - self._LastFire < self._Recharge then return end
	if self._OnDeltaOnly and not self._HasChangedSinceFire then return end
	self._HasChangedSinceFire = false
	self._LastFire = tick()
	self._OnFireInvoke(self:Get())
end

function Tracker.new(
	onDeltaOnly: boolean, 
	fireOnSet: boolean,
	getIfEqual: (a: {[string]: unknown}?, b: {[string]: unknown}?) -> boolean, 
	onFireInvoke: (value: {[string]: unknown}?) -> (), 
	interval: number?, 
	recharge: number?
): Tracker<{[string]: unknown}>

	local self: Tracker<{[string]: unknown}> = setmetatable({}, Tracker) :: any
	self._OnDeltaOnly = onDeltaOnly
	self._Interval = interval
	self._Recharge = recharge
	self._FireOnSet = fireOnSet
	self._IsAlive = true
	self._Maid = Maid.new()
	self._Value = nil
	self._LastFire = 0
	self._HasChangedSinceFire = true
	self._GetIfEqual = getIfEqual
	self._OnFireInvoke = onFireInvoke

	if interval then
		task.spawn(function()
			while self._IsAlive do
				self:Fire()
				task.wait(interval)
			end
		end)
	end

	return self
end

return Tracker