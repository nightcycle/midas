--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local TableUtil = require(_Packages:WaitForChild("TableUtil"))

-- Modules
local DataTable = require(script:WaitForChild("DataTable"))
local Util = require(_Package:WaitForChild("Util"))

-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type DataType = Util.DataType
export type DataTable<RowData> = DataTable.DataTable<RowData>
type OnBatchInsertInvoke = (
	dataSetId: string,
	dataTableId: string,
	dataList: { [number]: { [string]: unknown } },
	format: { [string]: DataType },
	onPayloadSizeKnownInvoke: (size: number) -> ()
) -> boolean
type OnBatchSetInvoke = (
	dataSetId: string,
	dataTableId: string,
	onKey: string,
	dataList: { [number]: { [string]: unknown } },
	format: { [string]: DataType },
	onPayloadSizeKnownInvoke: (size: number) -> ()
) -> boolean
export type DataSet = {
	__index: DataSet,
	_Id: string,
	_DataTables: { [string]: DataTable<any> },
	_GetOnBatchInsertInvoke: () -> OnBatchInsertInvoke,
	_GetOnBatchSetInvoke: () -> OnBatchSetInvoke,
	Name: string,
	Post: (
		self: DataSet,
		maxEntriesPerTable: number,
		maxSizePerTable: number,
		delayPerTable: number,
		recursive: boolean
	) -> (boolean, boolean, number),
	CreateDataTable: <RowData>(self: DataSet, name: string, id: string) -> DataTable<RowData>,
	GetRowCount: (self: DataSet) -> number,
	GetDataTable: <RowData>(self: DataSet, name: string) -> DataTable<RowData>,
	GetDataTables: (self: DataSet) -> { [number]: DataTable<{ [string]: unknown }> },
	new: (
		name: string,
		id: string,
		getOnBatchInsertInvoke: () -> OnBatchInsertInvoke,
		getOnBatchSetInvoke: () -> OnBatchSetInvoke
	) -> DataSet,
}

-- Class

--[=[
	@class DataSet

	This allows for the organization of datatables into smaller buckets.
]=]
--
local DataSet = {} :: DataSet
DataSet.__index = DataSet

--- creates a new datatable
function DataSet:CreateDataTable<RowData>(name: string, id: string): DataTable<RowData>
	assert(self._DataTables[name] == nil, `dataTable of name {name} already exists in dataset {self.Name}`)

	local dataTable: DataTable<any> = DataTable.new(name, id, function()
		return function(
			dataTableId: string,
			dataList: { [number]: { [string]: unknown } },
			format: { [string]: DataType },
			onPayloadSizeKnownInvoke: (size: number) -> ()
		): boolean
			local dataSetId = self._Id
			local onBatchInsertInvoke = self._GetOnBatchInsertInvoke()
			return onBatchInsertInvoke(dataSetId, dataTableId, dataList, format, onPayloadSizeKnownInvoke)
		end
	end, function()
		return function(
			dataTableId: string,
			dataList: { [number]: { [string]: unknown } },
			onKey: string,
			format: { [string]: DataType },
			onPayloadSizeKnownInvoke: (size: number) -> ()
		): boolean
			local dataSetId = self._Id
			local onBatchSetInvoke = self._GetOnBatchSetInvoke()
			return onBatchSetInvoke(dataSetId, dataTableId, onKey, dataList, format, onPayloadSizeKnownInvoke)
		end
	end)

	self._DataTables[name] = dataTable
	return dataTable
end

--- gets a datatable by name
function DataSet:GetDataTable<RowData>(name: string): DataTable<RowData>
	local dataTable = self._DataTables[name]
	assert(dataTable, `no datatable at {name} in dataset {self.Name}`)
	return dataTable
end

--- posts the current entries from all underlying datatables
function DataSet:Post(
	maxEntriesPerTable: number,
	maxSizePerTable: number,
	delayPerTable: number,
	recursive: boolean
): (boolean, boolean, number)
	local netData = 0
	local totalSuccess = true
	local totalEmpty = true
	for i, dataTable in ipairs(self:GetDataTables()) do
		if dataTable:GetRowCount() > 0 then
			task.wait(delayPerTable)
			local success, isEmpty, data = dataTable:Post(maxEntriesPerTable, maxSizePerTable)
			totalEmpty = totalEmpty and isEmpty
			totalSuccess = success and totalSuccess
			netData += data
		end
	end
	if not totalSuccess and recursive then
		task.wait(delayPerTable)
		local success, isEmpty, data = self:Post(maxEntriesPerTable, maxSizePerTable, delayPerTable, recursive)
		netData += data
		return success, isEmpty, netData
	end
	return totalSuccess, totalEmpty, netData
end

--- gets number of rows waiting to be processed
function DataSet:GetRowCount(): number
	local rows = 0
	for i, dataTable in ipairs(self:GetDataTables()) do
		rows += dataTable:GetRowCount()
	end
	return rows
end

--- gets all tables currently stored under the dataset
function DataSet:GetDataTables(): { [number]: DataTable<{ [string]: unknown }> }
	return TableUtil.values(self._DataTables)
end

function DataSet.new(
	name: string,
	id: string,
	getOnBatchInsertInvoke: () -> OnBatchInsertInvoke,
	getOnBatchSetInvoke: () -> OnBatchSetInvoke
): DataSet
	local self: DataSet = setmetatable({}, DataSet) :: any
	self._Id = id
	self.Name = name
	self._GetOnBatchInsertInvoke = getOnBatchInsertInvoke
	self._GetOnBatchSetInvoke = getOnBatchSetInvoke
	self._DataTables = {}

	table.freeze(self)

	return self
end

return DataSet
