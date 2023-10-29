--!strict
local _Package = script.Parent.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))

-- Modules
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

type ColumnData = {
	Key: string,
	Format: DataType,
	IsNullable: boolean,
}

type OnSaveInvoke = (dataTableId: string, data: {[string]: unknown}, formats: {[string]: DataType}) -> boolean
export type DataTable<RowData> = {
	__index: DataTable<RowData>,
	_Maid: Maid,
	_IsAlive: boolean,
	_Id: string,
	_Columns: {[number]: ColumnData},
	_GetOnSaveInvoke: () -> OnSaveInvoke,
	Name: string,
	AddRow: (self: DataTable<RowData>, data: RowData) -> boolean,
	AddColumn: (self: DataTable<RowData>, key: string, dataType: DataType, isNullable: boolean) -> (),
	Destroy: (self: DataTable<RowData>) -> (),
	new: (name: string, id: string, getOnSaveInvoke: () -> OnSaveInvoke) -> DataTable<RowData>,
	init: (maid: Maid) -> nil
}

-- Class
local DataTable = {} :: DataTable<unknown>
DataTable.__index = DataTable

function DataTable:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

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

function DataTable.new(name: string, id: string, getOnSaveInvoke: () -> OnSaveInvoke): DataTable<unknown>

	local self: DataTable<unknown> = setmetatable({}, DataTable) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self._Id = id
	self.Name = name
	self._GetOnSaveInvoke = getOnSaveInvoke

	self._Columns = {}

	return self
end

function DataTable.init(maid: Maid)
	print(`booting {script.Name}`)
	return nil
end

return DataTable