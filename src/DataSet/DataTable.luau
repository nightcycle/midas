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
	ExternalKey: string,
	Key: string,
	Format: DataType,
	IsNullable: boolean,
}

type OnBatchInsertInvoke = (
	dataTableId: string,
	dataList: { [number]: { [string]: unknown } },
	format: { [string]: DataType },
	onPayloadSizeKnownInvoke: (size: number) -> ()
) -> boolean
type OnBatchSetInvoke = (
	dataTableId: string,
	dataList: { [number]: { [string]: unknown } },
	onKey: string,
	format: { [string]: DataType },
	onPayloadSizeKnownInvoke: (size: number) -> ()
) -> boolean

export type DataTable<RowData> = {
	__index: DataTable<RowData>,
	_Id: string,
	_Key: string?,
	_Columns: { [number]: ColumnData },
	_GetOnBatchInsertInvoke: () -> OnBatchInsertInvoke,
	_GetOnBatchSetInvoke: () -> OnBatchSetInvoke,
	_BatchQueue: Queue<RowData>,
	_TotalRowsPosted: number,
	_TotalDataPosted: number,
	Name: string,
	AddRow: (self: DataTable<RowData>, data: RowData) -> (),
	AddColumn: (
		self: DataTable<RowData>,
		key: string,
		dataType: DataType,
		isNullable: boolean,
		keySymbol: string?
	) -> (),
	SetKeyColumn: (
		self: DataTable<RowData>,
		key: string
	) -> (),
	GetRowCount: (self: DataTable<RowData>) -> number,
	Post: (self: DataTable<RowData>, maxEntries: number, maxSize: number) -> (boolean, boolean, number),
	new: (
		name: string,
		id: string,
		getOnBatchInsertInvoke: () -> OnBatchInsertInvoke,
		getOnBatchSetInvoke: () -> OnBatchSetInvoke
	) -> DataTable<RowData>,
}

-- Class

--[=[
	@class DataTable

	This is the base table class that rows are added for processing.
]=]
local DataTable = {} :: DataTable<{ [string]: unknown }>
DataTable.__index = DataTable

--- adds a row of data
function DataTable:AddRow(param: { [string]: unknown })
	assert(type(param) == "table", `bad data "{param}" for dataTable {self.Name}`)
	local data: { [any]: any } = param :: any

	for i, columnData in ipairs(self._Columns) do
		local v = data[columnData.ExternalKey]
		if v == nil then
			if columnData.IsNullable == false then
				error(`missing data at key "{columnData.ExternalKey}" of dataTable {self.Name}`)
			end
		else
			if columnData.Format == "Binary" then
				assert(
					type(v) == "string",
					`bad value {v} at key "{columnData.ExternalKey}", expected string, received {type(v)}`
				)
				assert(
					type(v) == "number",
					`bad value {v} at key "{columnData.ExternalKey}", expected number, received {type(v)}`
				)
			elseif columnData.Format == "String" then
				assert(
					type(v) == "string",
					`bad value {v} at key "{columnData.ExternalKey}", expected string, received {type(v)}`
				)
			elseif columnData.Format == "Boolean" then
				assert(
					type(v) == "boolean",
					`bad value {v} at key "{columnData.ExternalKey}", expected boolean, received {type(v)}`
				)
			elseif columnData.Format == "Array" then
				assert(
					type(v) == "table",
					`bad value {v} at key "{columnData.ExternalKey}", expected table, received {type(v)}`
				)
			elseif columnData.Format == "Object" then
				assert(
					type(v) == "table",
					`bad value {v} at key "{columnData.ExternalKey}", expected table, received {type(v)}`
				)
			elseif columnData.Format == "Date" then
				assert(
					typeof(v) == "DateTime",
					`bad value {v} at key "{columnData.ExternalKey}", expected DateTime, received {typeof(v)}`
				)
			end

			if type(v) == "number" and v ~= v then
				error(`NAN data at key "{columnData.ExternalKey}" of dataTable {self.Name}`)
			end

			if columnData.Format == "Decimal128" then
				assert(
					type(v) == "number",
					`bad value {v} at key "{columnData.ExternalKey}", expected number, received {type(v)}`
				)
			elseif columnData.Format == "Double" then
				assert(
					type(v) == "number",
					`bad value {v} at key "{columnData.ExternalKey}", expected number, received {type(v)}`
				)
			elseif columnData.Format == "Int32" then
				assert(
					type(v) == "number",
					`bad value {v} at key "{columnData.ExternalKey}", expected number, received {type(v)}`
				)
				assert(
					math.abs(v) < 2147483647,
					`integer is larger than 32 bits at key "{columnData.Key}" - consider changing to Int64`
				)
			elseif columnData.Format == "Int64" then
				assert(
					type(v) == "number",
					`bad value {v} at key "{columnData.ExternalKey}", expected number, received {type(v)}`
				)
				assert(
					math.abs(v) < 9223372036854775807,
					`integer is larger than 64 bits at key "{columnData.ExternalKey}"`
				)
			end
		end
	end

	local compressedData: { [string]: unknown } = {}
	for k, v in pairs(data) do
		local found = false
		for i, columnData in ipairs(self._Columns) do
			if columnData.ExternalKey == k then
				found = true
				compressedData[columnData.Key] = v
			end
		end
		if not found then
			error(`unexpected key "{k}" in entry for of dataTable {self.Name}, did you remember to add this column?`)
		end
	end

	self._BatchQueue:Add(compressedData, -tick())
end

function DataTable:SetKeyColumn(key: string)
	local isFound = false
	for i, column in ipairs(self._Columns) do
		if column.Key == key or column.ExternalKey == key then
			isFound = true
			key = column.Key
			break
		end
	end
	assert(isFound, `no column exists with key {key} in datatable {self.Name}`)
	self._Key = key
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
	local format: { [string]: DataType } = {}
	for i, columnData in ipairs(self._Columns) do
		format[columnData.Key] = columnData.Format
	end
	local dataList: { [number]: { [string]: unknown } } = {}

	local entryCount = 0
	local netSize = 0

	local averageSize: number
	if self._TotalRowsPosted > 0 then
		averageSize = self._TotalDataPosted / self._TotalRowsPosted
	else
		averageSize = 100
	end

	repeat
		local nextEntry: { [string]: unknown }? = self._BatchQueue:Peek()
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

	local attemptSize = 0
	local success: boolean

	if self._Key then
		local onBatchInvoke = self._GetOnBatchSetInvoke()
		local key = self._Key
		assert(key)
		success = onBatchInvoke(self._Id, dataList, key, format, function(size: number)
			attemptSize += size
			self._TotalDataPosted += size
			self._TotalRowsPosted += #dataList
		end)
	
	else
		local onBatchInvoke = self._GetOnBatchInsertInvoke()
		success = onBatchInvoke(self._Id, dataList, format, function(size: number)
			attemptSize += size
			self._TotalDataPosted += size
			self._TotalRowsPosted += #dataList
		end)
	
	end


	if not success then
		for i, v in ipairs(dataList) do
			self._BatchQueue:Add(v, 0)
		end
	end

	return success, self._BatchQueue:IsEmpty(), if success then netSize else 0
end

--- adds a column, only to be used when initially constructing the table. Optional keySymbol parameter will swap out key at last second to reduce storage size
function DataTable:AddColumn(key: string, format: DataType, isNullable: boolean, keySymbol: string?)
	for i, columnData in ipairs(self._Columns) do
		if columnData.ExternalKey == key then
			error(`column with key {key} has already been registered for DataTable {self.Name}`)
		elseif columnData.Key == keySymbol then
			error(`column with key symbol {keySymbol} has already been registered for DataTable {self.Name}`)
		end
	end
	local columnData: ColumnData = {
		ExternalKey = key,
		Key = keySymbol or key,
		Format = format,
		IsNullable = isNullable,
	}
	table.insert(self._Columns, columnData)
end

function DataTable.new(
	name: string,
	id: string,
	getOnBatchInsertInvoke: () -> OnBatchInsertInvoke,
	getOnBatchSetInvoke: () -> OnBatchSetInvoke
): DataTable<{ [string]: unknown }>
	local self: DataTable<{ [string]: unknown }> = setmetatable({}, DataTable) :: any
	self._Id = id
	self.Name = name
	self._Key = nil
	self._TotalRowsPosted = 0
	self._TotalDataPosted = 0
	self._GetOnBatchInsertInvoke = getOnBatchInsertInvoke
	self._GetOnBatchSetInvoke = getOnBatchSetInvoke
	self._BatchQueue = Queue.new()
	self._BatchQueue.IsSorted = true
	self._Columns = {}

	-- table.freeze(self)

	return self
end

return DataTable
