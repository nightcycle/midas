--!strict
local _Package = script.Parent.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local Queue = require(_Packages:WaitForChild("Queue"))

-- Modules
local Util = require(_Package:WaitForChild("Util"))

-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type Queue<T> = Queue.Queue<T>
type DataType = Util.DataType

type ColumnData = {
	Key: string,
	Format: DataType,
	IsNullable: boolean
}

type OnBatchSaveInvoke = (dataTableId: string, dataList: {[number]: {[string]: unknown}}, format: {[string]: DataType}, onPayloadSizeKnownInvoke: (size: number) -> ()) -> boolean
export type DataTable<RowData> = {
	__index: DataTable<RowData>,
	_Id: string,
	_Columns: {[number]: ColumnData},
	_GetOnBatchSaveInvoke: () -> OnBatchSaveInvoke,
	_BatchQueue: Queue<RowData>,
	_TotalRowsPosted: number,
	_TotalDataPosted: number,
	Name: string,
	AddRow: (self: DataTable<RowData>, data: RowData) -> (),
	AddColumn: (self: DataTable<RowData>, key: string, dataType: DataType, isNullable: boolean) -> (),
	GetRowCount: (self: DataTable<RowData>) -> number,
	Post: (self: DataTable<RowData>, maxEntries: number, maxSize: number) -> (boolean, boolean, number),
	new: (name: string, id: string, getOnBatchSaveInvoke: () -> OnBatchSaveInvoke) -> DataTable<RowData>,
}

-- Class

--[=[
	@class DataTable

	This is the base table class that rows are added for processing.
]=]
local DataTable = {} :: DataTable<{[string]: unknown}>
DataTable.__index = DataTable

--- adds a row of data
function DataTable:AddRow(param: {[string]: unknown})
	assert(type(param) == "table", `bad data "{param}" for dataTable {self.Name}`)
	local data: {[any]: any} = param :: any
	for i, columnData in ipairs(self._Columns) do
		local v = data[columnData.Key]
		if v == nil then
			if columnData.IsNullable == false then 
				error(`missing data at key "{columnData.Key}" of dataTable {self.Name}`)
			end
		else
			if columnData.Format == "Binary" then
				assert(type(v) == "string", `bad value {v} at key "{columnData.Key}", expected string, received {type(v)}`)
				assert(type(v) == "number", `bad value {v} at key "{columnData.Key}", expected number, received {type(v)}`)
			elseif columnData.Format == "String" then
				assert(type(v) == "string", `bad value {v} at key "{columnData.Key}", expected string, received {type(v)}`)
			elseif columnData.Format == "Boolean" then
			assert(type(v) == "boolean", `bad value {v} at key "{columnData.Key}", expected boolean, received {type(v)}`)
			elseif columnData.Format == "Array" then
				assert(type(v) == "table", `bad value {v} at key "{columnData.Key}", expected table, received {type(v)}`)
			elseif columnData.Format == "Object" then
				assert(type(v) == "table", `bad value {v} at key "{columnData.Key}", expected table, received {type(v)}`)
			elseif columnData.Format == "Date" then
				assert(typeof(v) == "DateTime", `bad value {v} at key "{columnData.Key}", expected DateTime, received {typeof(v)}`)
			end
			
			if type(v) == "number" and v ~= v then
				error(`NAN data at key "{columnData.Key}" of dataTable {self.Name}`)
			end
			
			if columnData.Format == "Decimal128" then
				assert(type(v) == "number", `bad value {v} at key "{columnData.Key}", expected number, received {type(v)}`)
			elseif columnData.Format == "Double" then
				assert(type(v) == "number", `bad value {v} at key "{columnData.Key}", expected number, received {type(v)}`)
			elseif columnData.Format == "Int32" then
				assert(type(v) == "number", `bad value {v} at key "{columnData.Key}", expected number, received {type(v)}`)
				assert(math.abs(v) < 2147483647, `integer is larger than 32 bits at key "{columnData.Key}" - consider changing to Int64`)
			elseif columnData.Format == "Int64" then
				assert(type(v) == "number", `bad value {v} at key "{columnData.Key}", expected number, received {type(v)}`)
				assert(math.abs(v) < 9223372036854775807, `integer is larger than 64 bits at key "{columnData.Key}"`)
			end
		end
	end

	for k, v in pairs(data) do
		local found = false
		for i, columnData in ipairs(self._Columns) do
			if columnData.Key == k then
				found = true
			end
		end
		if not found then
			error(`unexpected key "{k}" in entry for of dataTable {self.Name}, did you remember to add this column?`)
		end
	end
	
	self._BatchQueue:Add(data, -tick())
end

--- gets the number of rows that need to be processed
function DataTable:GetRowCount(): number
	return self._BatchQueue:GetLength()
end

--- processes the current rows
function DataTable:Post(maxEntries: number, maxSize: number): (boolean, boolean, number)
	if self:GetRowCount() == 0 then
		return true, true, 0
	end
	local format: {[string]: DataType} = {}
	for i, columnData in ipairs(self._Columns) do
		format[columnData.Key] = columnData.Format
	end
	local dataList: {[number]: {[string]: unknown}} = {}

	local entryCount = 0
	local netSize = 0

	local averageSize: number
	if self._TotalRowsPosted > 0 then
		averageSize = self._TotalDataPosted/self._TotalRowsPosted
	else
		averageSize = 100
	end

	repeat
		local nextEntry: {[string]: unknown}? = self._BatchQueue:Peek()
		if nextEntry then
			entryCount += 1
			netSize += averageSize
			if entryCount < maxEntries and netSize < maxSize then
				local entry = self._BatchQueue:Get()
				if entry then
					table.insert(dataList, entry)
				end
			end
		end
	until self._BatchQueue:IsEmpty() or entryCount >= maxEntries or netSize >= maxSize

	local onBatchInvoke = self._GetOnBatchSaveInvoke()
	local attemptSize = 0
	local success = onBatchInvoke(
		self._Id, 
		dataList, 
		format, 
		function(size: number)  
			attemptSize += size
			self._TotalDataPosted += size
			self._TotalRowsPosted += #dataList
		end	
	)
	if not success then
		for i, v in ipairs(dataList) do
			self._BatchQueue:Add(v, 0)
		end
	end

	return success, self._BatchQueue:IsEmpty(), if success then netSize else 0
end

--- adds a column, only to be used when initially constructing the table
function DataTable:AddColumn(key: string, format: DataType, isNullable: boolean)
	for i, columnData in ipairs(self._Columns) do
		if columnData.Key == key then
			error(`column with key {key} has already been registered for DataTable {self.Name}`)
		end
	end
	local columnData: ColumnData = {
		Key = key,
		Format = format,
		IsNullable = isNullable
	}
	table.insert(self._Columns, columnData)
end

function DataTable.new(name: string, id: string, getOnBatchSaveInvoke: () -> OnBatchSaveInvoke): DataTable<{[string]: unknown}>

	local self: DataTable<{[string]: unknown}> = setmetatable({}, DataTable) :: any
	self._Id = id
	self.Name = name
	self._TotalRowsPosted = 0
	self._TotalDataPosted = 0
	self._GetOnBatchSaveInvoke = getOnBatchSaveInvoke
	self._BatchQueue = Queue.new()
	self._BatchQueue.IsSorted = true
	self._Columns = {}

	-- table.freeze(self)

	return self
end

return DataTable