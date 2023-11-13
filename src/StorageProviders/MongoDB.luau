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
	insertedId: string
}
type DataType = Util.DataType
export type MongoDB = {
	__index: MongoDB,
	_IsAlive: boolean,
	_ApiKey: string,
	_Url: string,
	DebugPrintEnabled: boolean,
	Destroy: (self: MongoDB) -> (),
	InsertOne: (
		self: MongoDB, 
		dataSource: string, 
		databaseName: string, 
		collectionName: string, 
		data: {[string]: any}, 
		format: {[string]: DataType}
	) -> (boolean, number?),
	InsertMany: (self: MongoDB,
		dataSource: string, 
		databaseName: string, 
		collectionName: string, 
		dataList: {[number]: {[string]: any}},
		format: {[string]: DataType}
	) -> (boolean, number?),
	new: (apiKey: string, url: string) -> MongoDB,
}

-- Constants
local DATA_TYPE_CONVERSION: {[DataType]: (value: any) -> any} = {
	["Int32"]=function(value: any): any
		assert(type(value) == "number")
		return { ["$numberInt"]= tostring(math.round(value)) }
	end,
	["Int64"]=function(value: any): any
		assert(type(value) == "number")
		return { ["$numberLong"]= tostring(math.round(value)) }
	end,
	["Binary"] = function(value: any): any
		assert(type(value) == "string")
		return {
			["$binary"] = {
				["base64"] = HashUtil.base64_encode(value),
				["subType"] = "05"
			}
		}
	end,
	["Date"]=function(value: any): any
		if type(value) == "number" then
			return {["$date"]= {["$numberLong"]= tostring(value)}}
		elseif type(value) == "string" then
			return { ["$date"]= value }
		elseif typeof(value) == "DateTime" then
			return { ["$date"]= Util.toTimeString(value)}
		end
		error(`bad type for {value}, type is {type(value)}`)
	end,
	["Decimal128"]=function(value: any): any
		assert(type(value) == "number")
		return { ["$numberDecimal"]= tostring(value) }
	end,
	["Double"]=function(value: any): any
		assert(type(value) == "number")
		return { ["$numberDouble"]= tostring(value) }
	end,
	["Boolean"]=function(value: any): any
		return value
	end,
	["Array"]=function(value: any): any
		return value
	end,
	["Null"]=function(value: any): any
		return value
	end,
	["Object"]=function(value: any): any
		return value
	end,
	["String"]=function(value: any): any
		return value
	end,
}
-- Variables
-- References
-- Private Functions
-- Class
local MongoDB = {} :: MongoDB
MongoDB.__index = MongoDB

function MongoDB:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function MongoDB:InsertOne(
	dataSource: string, 
	databaseName: string, 
	collectionName: string, 
	data: {[string]: any},
	format: {[string]: DataType}
): boolean

	local payload = {
		["dataSource"] = dataSource,
		["database"] = databaseName,
		["collection"] = collectionName,
		["document"] = {}
	}

	for k, v in pairs(data) do
		local f: DataType = format[k]
		local conversion = DATA_TYPE_CONVERSION[f]
		assert(conversion ~= nil, `bad data type {f} for {k}`)
		payload["document"][k] = conversion(v)
	end

	local encodedPayload = HttpService:JSONEncode(payload)

	local response: {
		Body: string?,
		Headers: {
			[string]: string
		},
		StatusCode: number,
		StatusMessage: string,
		Success: boolean
	}
	if game.PlaceId ~= 0 then
		response = HttpService:RequestAsync({
			Url = `{self._Url}/endpoint/data/v1/action/insertOne`,
			Method = "POST",
			Headers = {
				['Content-Type'] = 'application/ejson',
				[`Accept`] = `application/json`,
				['apiKey'] = self._ApiKey,
			},
			Body = encodedPayload
		})
	else
		response = {
			Body = HttpService:JSONEncode({
				insertedId = "abc123"
			}),
			Headers = {},
			StatusCode = 200,
			StatusMessage = "You're offline anything",
			Success = true
		}
	end

	if self.DebugPrintEnabled then
		print(`MongoDB:InsertOne({dataSource}/{databaseName}/{collectionName}) -> [{response.StatusCode}]`)
	end
	if not response.Success then
		warn(response.StatusMessage)
		if response.StatusCode == 429 then -- too many requests
			error(`too many requests`)
		elseif response.StatusCode == 413 then -- payload too large
			error(`payload too large`)
		elseif response.StatusCode == 401 then -- unauthorized
			error(`unauthorized`)
		end
	end

	return response.Success
end

function MongoDB:InsertMany(
	dataSource: string, 
	databaseName: string, 
	collectionName: string, 
	dataList: {[number]: {[string]: any}},
	format: {[string]: DataType}
): boolean

	local payload = {
		["dataSource"] = dataSource,
		["database"] = databaseName,
		["collection"] = collectionName,
		["documents"] = {}
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
	local response: {
		Body: string?,
		Headers: {
			[string]: string
		},
		StatusCode: number,
		StatusMessage: string,
		Success: boolean
	}
	if game.PlaceId ~= 0 then
		response = HttpService:RequestAsync({
			Url = `{self._Url}/endpoint/data/v1/action/insertMany`,
			Method = "POST",
			Headers = {
				['Content-Type'] = 'application/ejson',
				[`Accept`] = `application/json`,
				['apiKey'] = self._ApiKey,
			},
			Body = encodedPayload
		})
	else
		response = {
			Body = HttpService:JSONEncode({{
				insertedId = "abc123"
			}}),
			Headers = {},
			StatusCode = 200,
			StatusMessage = "You're offline anything",
			Success = true
		}
	end
	
	if self.DebugPrintEnabled then
		print(`MongoDB:InsertMany({dataSource}/{databaseName}/{collectionName}) -> [{response.StatusCode}]`)
	end
	if not response.Success then
	
		error(`mongo post fail, code={response.StatusCode}, msg={response.StatusMessage}`)
		-- if response.StatusCode == 429 then -- too many requests
		-- 	error(`too many requests`)
		-- elseif response.StatusCode == 413 then -- payload too large
		-- 	error(`payload too large`)
		-- elseif response.StatusCode == 401 then -- unauthorized
		-- 	error(`unauthorized`)
		-- else
		-- 	error(`error [{response.StatusCode}] {response.StatusMessage}`)
		-- end
	end



	return response.Success
end
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