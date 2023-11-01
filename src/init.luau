--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
-- Packages
local ServiceProxy = require(_Packages:WaitForChild("ServiceProxy"))
local Maid = require(_Packages:WaitForChild("Maid"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))

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
type OnBatchSaveInvoke = StorageProviders.OnBatchSaveInvoke
export type DataTable<RowData> = DataSet.DataTable<RowData>
export type DataSet = DataSet.DataSet
export type DataType = Util.DataType
type StorageProviders = typeof(StorageProviders)
export type Midas = {
	__index: Midas,
	_Maid: Maid,
	_IsAlive: boolean,
	_OnBatchSaveInvoke: OnBatchSaveInvoke,
	_DataSets: {[string]: DataSet},
	ProjectId: string?,
	Util: typeof(Util),
	StorageProviders: StorageProviders,
	GetRowCount: (self: Midas) -> number,
	CreateDataSet: (self: Midas, name: string, id: string) -> DataSet,
	Post: (self: Midas, maxEntriesPerTable: number, maxSizePerTable: number, delayPerTable: number, recursive: boolean) -> (boolean, boolean, number),
	GetDataSet: (self: Midas, name: string) -> DataSet,
	GetDataSets: (self: Midas) -> {[number]: DataSet},
	SetOnBatchSaveInvoke: (self: Midas, onBatchSaveInvoke: OnBatchSaveInvoke) -> (),
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

function Midas:Post(maxEntriesPerTable: number, maxSizePerTable: number, delayPerTable: number, recursive: boolean): (boolean, boolean, number)
	local netData = 0
	local totalSuccess = true
	local totalEmpty = true
	local postCount = 0
	local postCompletion = 0
	for i, dataSets in ipairs(self:GetDataSets()) do
		if dataSets:GetRowCount() > 0 then
			task.wait(delayPerTable)
			postCount += 1
			local function post()
				local success, isEmpty, data = dataSets:Post(maxEntriesPerTable, maxSizePerTable, delayPerTable, recursive)
				totalSuccess = success and totalSuccess
				totalEmpty = isEmpty and totalEmpty
				netData += data
				postCompletion += 1
			end
			if recursive then
				task.spawn(post)
			else
				post()
			end
		end
	end
	if recursive then
		while postCount > postCompletion do
			task.wait(delayPerTable)
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

function Midas:CreateDataSet(name: string, id: string): DataSet
	assert(RunService:IsServer(), `bad domain`)
	assert(self._DataSets[name] == nil, `dataSet of name {name} already exists`)
	local dataSet = DataSet.new(
		name, 
		id, 
		function()
			return function(dataSetId: string, dataTableId: string, dataList: {[number]: {[string]: unknown}}, format: {[string]: DataType}): boolean
				local projectId = self.ProjectId
				assert(projectId, `projectId hasn't been set yet`)
		
				local onBatchSaveInvoke =  self._OnBatchSaveInvoke
				assert(onBatchSaveInvoke, `onBatchSaveInvoke hasn't been set yet`)

				return onBatchSaveInvoke(projectId, dataSetId, dataTableId, dataList, format)
			end
		end
	)
	self._DataSets[name] = dataSet
	return dataSet
end

function Midas:SetOnBatchSaveInvoke(onBatchSaveInvoke: OnBatchSaveInvoke)
	self._OnBatchSaveInvoke = onBatchSaveInvoke
end

function Midas:GetDataSet(name: string): DataSet
	assert(RunService:IsServer(), `bad domain`)
	local dataSets = self._DataSets[name]
	assert(dataSets, `no dataset at {name}`)
	return dataSets
end

function Midas:GetDataSets(): {[number]: DataSet}
	return TableUtil.values(self._DataSets)
end

function Midas:GetRowCount(): number
	local rows = 0
	for i, dataSet in ipairs(self:GetDataSets()) do
		rows += dataSet:GetRowCount()
	end
	return rows
end

function Midas.new()

	local self: Midas = setmetatable({}, Midas) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self.ProjectId = nil
	self.StorageProviders = StorageProviders
	self.Util = Util
	self._OnBatchSaveInvoke = function()
		warn(`onBatchSaveInvoke not set`)
		return false
	end

	self._Maid:GiveTask(game.Close:Connect(function()
		self:Post(math.huge, math.huge, 1/60, true)
	end))

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