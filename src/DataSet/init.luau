--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
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
type OnSaveInvoke = (dataSetId: string, dataTableId: string, data: {[string]: unknown}, formats: {[string]: DataType}) -> boolean
type OnMultiSaveInvoke = (dataSetId: string, dataTableId: string, dataList: {[number]: {[string]: unknown}}, formatList: {[number]: {[string]: DataType}}) -> boolean

export type DataSet = {
	__index: DataSet,
	_Id: string,
	_DataTables: {[string]: DataTable<unknown>},
	_GetOnSaveInvoke: () -> OnSaveInvoke,
	_GetOnMultiSaveInvoke: () -> OnMultiSaveInvoke,
	Name: string,
	CreateDataTable: <RowData>(self: DataSet, name: string, id: string) -> DataTable<RowData>,
	GetDataTable: <RowData>(self: DataSet, name: string) -> DataTable<RowData>,
	new: (name: string, id: string, getOnSaveInvoke: () -> OnSaveInvoke, getOnMultiSaveInvoke: () -> OnMultiSaveInvoke) -> DataSet,
}

-- Class
local DataSet = {} :: DataSet
DataSet.__index = DataSet

function DataSet:CreateDataTable<RowData>(name: string, id: string): DataTable<RowData>
	assert(self._DataTables[name] == nil, `dataTable of name {name} already exists in dataset {self.Name}`)
	
	local dataTable = DataTable.new(
		name, 
		id, 
		function()
			return function(dataTableId: string, data: {[string]: unknown}, formats: {[string]: DataType}): boolean
				local dataSetId = self._Id
				local onSaveInvoke =  self._GetOnSaveInvoke()
				return onSaveInvoke(dataSetId, dataTableId, data, formats)
			end
		end,
		function()
			return function(dataTableId: string, dataList: {[number]: {[string]: unknown}}, formatList: {[number]: {[string]: DataType}}): boolean
				local dataSetId = self._Id
				local onMultiSaveInvoke =  self._GetOnMultiSaveInvoke()
				return onMultiSaveInvoke(dataSetId, dataTableId, dataList, formatList)
			end
		end
	)

	self._DataTables[name] = dataTable
	return dataTable
end

function DataSet:GetDataTable<RowData>(name: string): DataTable<RowData>
	local dataTable = self._DataTables[name]
	assert(dataTable, `no datatable at {name} in dataset {self.Name}`)
	return dataTable
end

function DataSet.new(name: string, id: string, getOnSaveInvoke: () -> OnSaveInvoke, getOnMultiSaveInvoke: () -> OnMultiSaveInvoke): DataSet

	local self: DataSet = setmetatable({}, DataSet) :: any
	self._Id = id
	self.Name = name
	self._GetOnSaveInvoke = getOnSaveInvoke
	self._GetOnMultiSaveInvoke = getOnMultiSaveInvoke
	self._DataTables = {}

	table.freeze(self)

	return self
end

return DataSet