--!strict
-- Services
-- Packages
-- local HashUtil = require("@pkg/@rbxts/rbxts-hashlib")
-- Modules
local Util = require("../Util")

-- Types
type MongoInsertOneResponse = {
	insertedId: string,
}
type DataType = Util.DataType
export type MongoDB = {
	__index: MongoDB,
	_IsAlive: boolean,
	_ApiKey: string | Secret,
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
	-- ["Binary"] = function(value: any): any
	-- 	assert(type(value) == "string")
	-- 	return {
	-- 		["$binary"] = {
	-- 			["base64"] = HashUtil.base64_encode(value),
	-- 			["subType"] = "05",
	-- 		},
	-- 	}
	-- end,
	["Date"] = function(value: any): any
		assert(
			Util.getIfDateTimeLike(value),
			`bad type for {value}, type is {typeof(value)}, expected DateTime / datetime`
		)
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

	local isLune: boolean?
	do
		local success, _result = pcall(function()
			local req: any = require
			local _ = req("@lune/serde")
		end)
		isLune = success
	end

	local response: {
		Body: string?,
		Headers: {
			[string]: string,
		},
		StatusCode: number,
		StatusMessage: string,
		Success: boolean,
	}

	local url = `{self._Url}/endpoint/data/v1/action/insertMany`
	local headers = {
		["Content-Type"] = "application/ejson",
		[`Accept`] = `application/json`,
		["apiKey"] = self._ApiKey,
	} :: { [string]: Secret | string }
	if isLune then
		local req: any = require
		local serde: any = req("@lune/serde")
		local net: any = req("@lune/net")

		local encodedPayload = serde.encode("json", payload)
		onPayloadSizeInvoke(encodedPayload:len())

		local netResponse = net.request({
			url = url,
			method = "POST",
			headers = headers,
			body = encodedPayload,
		})

		response = {
			Body = netResponse.body,
			Headers = netResponse.headers,
			StatusCode = netResponse.statusCode,
			StatusMessage = netResponse.statusMessage,
			Success = netResponse.success or netResponse.statusCode == 201, -- 201 also means it worked but will return as false
		}
	else
		local encodedPayload = game:GetService("HttpService"):JSONEncode(payload)
		onPayloadSizeInvoke(encodedPayload:len())

		if game.PlaceId ~= 0 then
			response = game:GetService("HttpService"):RequestAsync({
				Url = url,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/ejson",
					[`Accept`] = `application/json`,
					["apiKey"] = self._ApiKey,
				} :: { [string]: Secret | string },
				Body = encodedPayload,
				Compress = Enum.HttpCompression.None,
			})
		else
			response = {
				Body = game:GetService("HttpService"):JSONEncode({ {
					insertedId = "abc123",
				} }),
				Headers = {},
				StatusCode = 200,
				StatusMessage = "You're offline",
				Success = true,
			}
		end
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
	local self: MongoDB = setmetatable({}, MongoDB) :: any
	self._IsAlive = true
	self._ApiKey = apiKey
	self._Url = url
	self.DebugPrintEnabled = true

	return self
end

return MongoDB
