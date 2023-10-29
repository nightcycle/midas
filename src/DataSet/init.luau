--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
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
type Maid = Maid.Maid
type DataType = Util.DataType
export type DataTable<RowData> = DataTable.DataTable<RowData>
type OnSaveInvoke = (dataSetId: string, dataTableId: string, data: {[string]: unknown}, formats: {[string]: DataType}) -> boolean
export type DataSet = {
	__index: DataSet,
	_Maid: Maid,
	_IsAlive: boolean,
	_Id: string,
	_DataTables: {[string]: DataTable<unknown>},
	_GetOnSaveInvoke: () -> OnSaveInvoke,
	Name: string,
	CreateDataTable: <RowData>(self: DataSet, name: string, id: string) -> DataTable<RowData>,
	GetDataTable: <RowData>(self: DataSet, name: string) -> DataTable<RowData>,
	Destroy: (self: DataSet) -> (),
	new: (name: string, id: string, getOnSaveInvoke: () -> OnSaveInvoke) -> DataSet,
	init: (maid: Maid) -> nil
}

-- Class
local DataSet = {} :: DataSet
DataSet.__index = DataSet

function DataSet:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function DataSet:CreateDataTable<RowData>(name: string, id: string): DataTable<RowData>
	assert(self._DataTables[name] == nil, `dataTable of name {name} already exists in dataset {self.Name}`)
	local dataTable = self._Maid:GiveTask(DataTable.new(name, id, function()
		return function(dataTableId: string, data: {[string]: unknown}, formats: {[string]: DataType}): boolean
			local dataSetId = self._Id
			local onSaveInvoke =  self._GetOnSaveInvoke()
			return onSaveInvoke(dataSetId, dataTableId, data, formats)
		end
	end))

	self._DataTables[name] = dataTable
	return dataTable
end

function DataSet:GetDataTable<RowData>(name: string): DataTable<RowData>
	local dataTable = self._DataTables[name]
	assert(dataTable, `no datatable at {name} in dataset {self.Name}`)
	return dataTable
end

function DataSet.new(name: string, id: string, getOnSaveInvoke: () -> OnSaveInvoke)

	local self: DataSet = setmetatable({}, DataSet) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self._Id = id
	self.Name = name
	self._GetOnSaveInvoke = getOnSaveInvoke
	self._DataTables = {}

	return self
end

function DataSet.init(maid: Maid)
	print(`booting {script.Name}`)
	return nil
end

return DataSet