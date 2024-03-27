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
type MongoInsertOneResponse = {
	insertedId: string,
}
type DataType = Util.DataType
export type MongoDB = {
	__index: MongoDB,
	_IsAlive: boolean,
	_ApiKey: string,
	_Url: string,
	DebugPrintEnabled: boolean,
	Destroy: (self: MongoDB) -> (),
	InsertMany: (
		self: MongoDB,
		dataSource: string,
		databaseName: string,
		collectionName: string,
		dataList: { [number]: { [string]: any } },
		format: { [string]: DataType },
		onPayloadSizeKnownInvoke: (size: number) -> ()
	) -> boolean,
	new: (apiKey: string, url: string) -> MongoDB,
}

-- Constants
local DATA_TYPE_CONVERSION: { [DataType]: (value: any) -> any } = {
	["Int32"] = function(value: any): any
		assert(type(value) == "number")
		return { ["$numberInt"] = tostring(math.round(value)) }
	end,
	["Int64"] = function(value: any): any
		assert(type(value) == "number")
		return { ["$numberLong"] = tostring(math.round(value)) }
	end,
	["Binary"] = function(value: any): any
		assert(type(value) == "string")
		return {
			["$binary"] = {
				["base64"] = HashUtil.base64_encode(value),
				["subType"] = "05",
			},
		}
	end,
	["Date"] = function(value: any): any
		assert(typeof(value) == "DateTime", `bad type for {value}, type is {typeof(value)}, expected DateTime`)
		return { ["$date"] = Util.toTimeString(value) }
	end,
	["Decimal128"] = function(value: any): any
		assert(type(value) == "number")
		return { ["$numberDecimal"] = tostring(value) }
	end,
	["Double"] = function(value: any): any
		assert(type(value) == "number")
		return { ["$numberDouble"] = tostring(value) }
	end,
	["Boolean"] = function(value: any): any
		return value
	end,
	["Array"] = function(value: any): any
		return value
	end,
	["Null"] = function(value: any): any
		return value
	end,
	["Object"] = function(value: any): any
		return value
	end,
	["String"] = function(value: any): any
		return value
	end,
}
-- Variables
-- References
-- Private Functions
--[=[
	@class MongoDB

	This is a simple API provider class, allowing you to make simplified reuqests without needing to think about http stuff.
]=]
local MongoDB = {} :: MongoDB
MongoDB.__index = MongoDB

--- @prop DebugPrintEnabled boolean
--- @within MongoDB
--- Whether it prints the results of posting (good for debugging)

function MongoDB:Destroy()
	if not self._IsAlive then
		return
	end
	self._IsAlive = false
	table.clear(self)
	setmetatable(self, nil)
end

--- sends the data to MongoDB
function MongoDB:InsertMany(
	dataSource: string,
	databaseName: string,
	collectionName: string,
	dataList: { [number]: { [string]: any } },
	format: { [string]: DataType },
	onPayloadSizeInvoke: (size: number) -> ()
): boolean
	local payload = {
		["dataSource"] = dataSource,
		["database"] = databaseName,
		["collection"] = collectionName,
		["documents"] = {},
	}

	for i, data in ipairs(dataList) do
		local document = {}

		for k, v in pairs(data) do
			local f: DataType = format[k]
			local conversion = DATA_TYPE_CONVERSION[f]
			assert(conversion ~= nil, `bad data type {f} for {k}`)
			document[k] = conversion(v)
		end

		payload["documents"][i] = document
	end

	local encodedPayload = HttpService:JSONEncode(payload)
	onPayloadSizeInvoke(encodedPayload:len())
	local response: {
		Body: string?,
		Headers: {
			[string]: string,
		},
		StatusCode: number,
		StatusMessage: string,
		Success: boolean,
	}
	if game.PlaceId ~= 0 then
		response = HttpService:RequestAsync({
			Url = `{self._Url}/endpoint/data/v1/action/insertMany`,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/ejson",
				[`Accept`] = `application/json`,
				["apiKey"] = self._ApiKey,
			},
			Body = encodedPayload,
		})
	else
		response = {
			Body = HttpService:JSONEncode({ {
				insertedId = "abc123",
			} }),
			Headers = {},
			StatusCode = 200,
			StatusMessage = "You're offline anything",
			Success = true,
		}
	end

	if self.DebugPrintEnabled then
		print(`MongoDB:InsertMany({dataSource}/{databaseName}/{collectionName}) -> [{response.StatusCode}]`)
	end
	if not response.Success then
		error(`mongo post fail, code={response.StatusCode}, msg={response.StatusMessage}, body={response.Body}`)
	end

	return response.Success
end

--- initializes the class
function MongoDB.new(apiKey: string, url: string)
	assert(RunService:IsServer(), `bad domain`)

	local self: MongoDB = setmetatable({}, MongoDB) :: any
	self._IsAlive = true
	self._ApiKey = apiKey
	self._Url = url
	self.DebugPrintEnabled = true

	return self
end

return MongoDB
