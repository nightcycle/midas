--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
-- Packages
local ServiceProxy = require(_Packages:WaitForChild("ServiceProxy"))
local Maid = require(_Packages:WaitForChild("Maid"))
-- Modules
local DataSet = require(_Package:WaitForChild("DataSet"))
local StorageProviders = require(_Package:WaitForChild("StorageProviders"))
local Util = require(_Package:WaitForChild("Util"))
-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type Maid = Maid.Maid
type OnSaveInvoke = StorageProviders.OnSaveInvoke
export type DataTable<RowData> = DataSet.DataTable<RowData>
export type DataSet = DataSet.DataSet
export type DataType = Util.DataType
type StorageProviders = typeof(StorageProviders)
export type Midas = {
	__index: Midas,
	_Maid: Maid,
	_IsAlive: boolean,
	_OnSaveInvoke: OnSaveInvoke,
	_DataSets: {[string]: DataSet},
	ProjectId: string?,
	Util: typeof(Util),
	StorageProviders: StorageProviders,
	CreateDataSet: (self: Midas, name: string, id: string) -> DataSet,
	GetDataSet: (self: Midas, name: string) -> DataSet,
	SetOnSaveInvoke: (self: Midas, onSaveInvoke: OnSaveInvoke) -> (),
	Destroy: (self: Midas) -> (),
	new: () -> Midas,
	init: (maid: Maid) -> nil
}

-- Class
local CurrentMidas: Midas = nil :: any
local Midas = {} :: Midas
Midas.__index = Midas

function Midas:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	if CurrentMidas == self then
		CurrentMidas = nil :: any
	end
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function Midas:CreateDataSet(name: string, id: string): DataSet
	assert(self._DataSets[name] == nil, `dataSet of name {name} already exists`)
	local dataSet = self._Maid:GiveTask(DataSet.new(name, id, function()

		return function(dataSetId: string, dataTableId: string, data: {[string]: unknown}, formats: {[string]: DataType}): boolean
			local projectId = self.ProjectId
			assert(projectId, `projectId hasn't been set yet`)
	
			local onSaveInvoke =  self._OnSaveInvoke
			assert(onSaveInvoke, `onSaveInvoke hasn't been set yet`)

			return onSaveInvoke(projectId, dataSetId, dataTableId, data, formats)
		end
	end))
	self._DataSets[name] = dataSet
	return dataSet
end

function Midas:GetDataSet(name: string): DataSet
	local dataSets = self._DataSets[name]
	assert(dataSets, `no dataset at {name}`)
	return dataSets
end
function Midas:SetOnSaveInvoke(onSaveInvoke: OnSaveInvoke)
	self._OnSaveInvoke = onSaveInvoke
end

function Midas.new()

	local self: Midas = setmetatable({}, Midas) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self.ProjectId = nil
	self.StorageProviders = StorageProviders
	self.Util = Util
	self._OnSaveInvoke = function()
		return false
	end
	self._DataSets = {}
	if CurrentMidas ~= nil then
		 CurrentMidas:Destroy()
		 CurrentMidas = nil :: any
	end
	CurrentMidas = self

	return self
end

function Midas.init(maid: Maid)
	print(`booting {script.Name}`)
	maid:GiveTask(Midas.new())
	return nil
end

return ServiceProxy(function()
	return CurrentMidas or Midas
end)