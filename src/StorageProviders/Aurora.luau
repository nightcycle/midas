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
type DataType = Util.DataType
type DatabaseType = "MySQL" --| "PostgreSQL"
export type Aurora = {
	__index: Aurora,
	_IsAlive: boolean,
	_Type: DatabaseType,
	InsertMany: (
		self: Aurora,
		database: string,
		dataList: { [number]: { [string]: any } },
		format: { [string]: DataType },
		onPayloadSizeKnownInvoke: (size: number) -> ()
	) -> boolean,
	Destroy: (self: Aurora) -> (),
	new: (
		username: string,
		password: string,
		host: string,
		databaseType: DatabaseType?
	) -> Aurora,
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


--- sends the data to Aurora
function Aurora:InsertMany(
	database: string,
	dataList: { [number]: { [string]: any } },
	format: { [string]: DataType },
	onPayloadSizeKnownInvoke: (size: number) -> ()
): boolean
	
	return false
end

function Aurora.new(apiKey: string, url: string): Aurora
	local self: Aurora = setmetatable({}, Aurora) :: any
	self._IsAlive = true

	return self
end

return Aurora
