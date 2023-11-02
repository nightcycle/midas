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
	IsNullable: boolean,
	getSize: (value: unknown) -> number,
}

type OnBatchSaveInvoke = (dataTableId: string, dataList: {[number]: {[string]: unknown}}, format: {[string]: DataType}) -> boolean
export type DataTable<RowData> = {
	__index: DataTable<RowData>,
	_Id: string,
	_Columns: {[number]: ColumnData},
	_GetOnBatchSaveInvoke: () -> OnBatchSaveInvoke,
	_BatchQueue: Queue<RowData>,
	Name: string,
	AddRow: (self: DataTable<RowData>, data: RowData) -> (),
	AddColumn: (self: DataTable<RowData>, key: string, dataType: DataType, isNullable: boolean, getSize: (value: unknown) -> number) -> (),
	GetRowCount: (self: DataTable<RowData>) -> number,
	Post: (self: DataTable<RowData>, maxEntries: number, maxSize: number) -> (boolean, boolean, number),
	new: (name: string, id: string, getOnBatchSaveInvoke: () -> OnBatchSaveInvoke) -> DataTable<RowData>,
}

-- Class
local DataTable = {} :: DataTable<{[string]: unknown}>
DataTable.__index = DataTable

function DataTable:AddRow(param: unknown)
	assert(type(param) == "table", `bad data "{param}" for dataTable {self.Name}`)
	local data: {[any]: any} = param :: any
	for i, columnData in ipairs(self._Columns) do
		if columnData.IsNullable == false and data[columnData.Key] == nil then
			error(`missing data at key "{columnData.Key}" of dataTable {self.Name}`)
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
			error(`unexpected key "{k}" in entry for of dataTable {self.Name}`)
		end
	end
	
	self._BatchQueue:Add(data, -tick())
end

function DataTable:GetRowCount(): number
	return self._BatchQueue:GetLength()
end

function DataTable:Post(maxEntries: number, maxSize: number): (boolean, boolean, number)
	
	local format: {[string]: DataType} = {}
	local sizeSolvers: {[string]: (value: unknown) -> number} = {}
	for i, columnData in ipairs(self._Columns) do
		format[columnData.Key] = columnData.Format
		sizeSolvers[columnData.Key] = columnData.getSize
	end
	local dataList: {[number]: {[string]: unknown}} = {}

	local entryCount = 0
	local netSize = 0
	repeat
		local nextEntry: {[string]: unknown}? = self._BatchQueue:Peek()
		if nextEntry then
			local size = 0
			size += 1 --the brackets
			for k, v in pairs(nextEntry) do
				local solver = sizeSolvers[k]
				assert(solver, `missing size solver for {k} in post of {self.Name}`)
				size += solver(v)
				size += k:len()
				size += 2--the quotes around the key
				size += 1--the colon between key and value
				size += 1-- the comma at the end
			end
			entryCount += 1
			netSize += size
			if entryCount < maxEntries and netSize < maxSize then
				local entry = self._BatchQueue:Get()
				if entry then
					table.insert(dataList, entry)
				end
			end
		end
	until self._BatchQueue:IsEmpty() or entryCount >= maxEntries or netSize >= maxSize

	local onBatchInvoke = self._GetOnBatchSaveInvoke()
	local success = onBatchInvoke(self._Id, dataList, format)
	if not success then
		for i, v in ipairs(dataList) do
			self._BatchQueue:Add(v, 0)
		end
	end

	return success, self._BatchQueue:IsEmpty(), if success then netSize else 0
end

function DataTable:AddColumn(key: string, format: DataType, isNullable: boolean, getSize: (value: unknown) -> number)
	for i, columnData in ipairs(self._Columns) do
		if columnData.Key == key then
			error(`column with key {key} has already been registered for DataTable {self.Name}`)
		end
	end
	local columnData: ColumnData = {
		Key = key,
		Format = format,
		IsNullable = isNullable,
		getSize = getSize
	}
	table.insert(self._Columns, columnData)
end

function DataTable.new(name: string, id: string, getOnBatchSaveInvoke: () -> OnBatchSaveInvoke): DataTable<{[string]: unknown}>

	local self: DataTable<{[string]: unknown}> = setmetatable({}, DataTable) :: any
	self._Id = id
	self.Name = name
	self._GetOnBatchSaveInvoke = getOnBatchSaveInvoke
	self._BatchQueue = Queue.new()
	self._BatchQueue.IsSorted = true
	self._Columns = {}

	table.freeze(self)

	return self
end

return DataTable