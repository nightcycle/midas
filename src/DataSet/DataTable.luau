--!strict
local _Package = script.Parent.Parent
local _Packages = _Package.Parent
-- Services
-- Packages

-- Modules
local Util = require(_Package:WaitForChild("Util"))

-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type DataType = Util.DataType

type ColumnData = {
	Key: string,
	Format: DataType,
	IsNullable: boolean,
}

type OnSaveInvoke = (dataTableId: string, data: {[string]: unknown}, formats: {[string]: DataType}) -> boolean
type OnMultiSaveInvoke = (dataTableId: string, dataList: {[number]: {[string]: unknown}}, formatList: {[number]: {[string]: DataType}}) -> boolean
export type DataTable<RowData> = {
	__index: DataTable<RowData>,
	_Id: string,
	_Columns: {[number]: ColumnData},
	_GetOnSaveInvoke: () -> OnSaveInvoke,
	_GetOnMultiSaveInvoke: () -> OnMultiSaveInvoke,

	Name: string,
	AddRow: (self: DataTable<RowData>, data: RowData) -> boolean,
	AddColumn: (self: DataTable<RowData>, key: string, dataType: DataType, isNullable: boolean) -> (),
	new: (name: string, id: string, getOnSaveInvoke: () -> OnSaveInvoke, getOnMultiSaveInvoke: () -> OnMultiSaveInvoke) -> DataTable<RowData>,
}

-- Class
local DataTable = {} :: DataTable<unknown>
DataTable.__index = DataTable

function DataTable:AddRow(param: unknown): boolean
	assert(type(param) == "table", `bad data "{param}" for dataTable {self.Name}`)
	local data: {[any]: any} = param :: any
	local formats: {[string]: DataType} = {}
	for i, columnData in ipairs(self._Columns) do
		if ((not columnData.IsNullable) or data[columnData.Key] ~= nil) then
			formats[columnData.Key] = columnData.Format
		else
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
	
	local onInvoke = self._GetOnSaveInvoke()

	return onInvoke(self._Id, data, formats)
end

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

function DataTable.new(name: string, id: string, getOnSaveInvoke: () -> OnSaveInvoke, getOnMultiSaveInvoke: () -> OnMultiSaveInvoke): DataTable<unknown>

	local self: DataTable<unknown> = setmetatable({}, DataTable) :: any
	self._Id = id
	self.Name = name
	self._GetOnSaveInvoke = getOnSaveInvoke
	self._GetOnMultiSaveInvoke = getOnMultiSaveInvoke

	self._Columns = {}

	table.freeze(self)

	return self
end

return DataTable