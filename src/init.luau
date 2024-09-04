--!strict
-- Services
-- Packages
local ServiceProxy = require("@pkg/@nightcycle/service-proxy")
local TableUtil = require("@pkg/@nightcycle/table-util")

-- Modules
local DataSet = require("./DataSet")
local StorageProviders = require("./StorageProviders")
local Util = require("./Util")

-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type OnBatchInsertInvoke = StorageProviders.OnBatchInsertInvoke
type OnBatchSetInvoke = StorageProviders.OnBatchSetInvoke

export type DataTable<RowData> = DataSet.DataTable<RowData>
export type DataSet = DataSet.DataSet
export type DataType = Util.DataType
type StorageProviders = typeof(StorageProviders)

export type Midas = {
	__index: Midas,
	_IsAlive: boolean,
	_OnBatchInsertInvoke: OnBatchInsertInvoke,
	_OnBatchSetInvoke: OnBatchSetInvoke,
	_DataSets: { [string]: DataSet },
	ProjectId: string?,
	Util: typeof(Util),
	StorageProviders: StorageProviders,
	GetRowCount: (self: Midas) -> number,
	CreateDataSet: (self: Midas, name: string, id: string) -> DataSet,
	Post: (
		self: Midas,
		maxEntriesPerTable: number,
		maxSizePerTable: number,
		delayPerTable: number,
		recursive: boolean
	) -> (boolean, boolean, number),
	GetDataSet: (self: Midas, name: string) -> DataSet,
	GetDataSets: (self: Midas) -> { [number]: DataSet },
	SetOnBatchInsertInvoke: (self: Midas, onBatchInsertInvoke: OnBatchInsertInvoke) -> (),
	SetOnBatchSetInvoke: (self: Midas, onBatchSetInvoke: OnBatchSetInvoke) -> (),

	Automate: (
		self: Midas,
		printEnabled: boolean,
		maxEntriesPerTable: number?,
		minDurationPerTable: number?,
		updateDelay: number?,
		averageSizePerRow: number?,
		escalationRate: number?,
		onAttemptInvokeLogger: OnAttemptInvokeLogger?
	) -> (),
	Destroy: (self: Midas) -> (),
	new: () -> Midas,
	init: () -> () -> (),
}

-- Class
local CurrentMidas: Midas = nil :: any

--[=[
	@class Midas

	This is the service itself, the main interface which the dev sets up the various data structures.
]=]
local Midas = {} :: Midas
Midas.__index = Midas

--- @type OnAttemptInvokeLogger (success: boolean, size: number, rowCount: number, currentSizeLimit: number, currentRowLimit: number, rowsRemaining: number, attemptIndex: number, errorMessage: string?) -> ()
--- @within Midas
---
--- I often run a datatable on the performance of posts to tune the parameters / detect issue / estimate data validity. If you wish to do the same you can with this function.
export type OnAttemptInvokeLogger = (
	success: boolean,
	size: number,
	rowCount: number,
	currentSizeLimit: number,
	currentRowLimit: number,
	rowsRemaining: number,
	attemptIndex: number,
	errorMessage: string?
) -> ()

--- @prop ProjectId string?
--- @within Midas
--- The project id passed to the posting function

function Midas:Destroy()
	if not self._IsAlive then
		return
	end
	self._IsAlive = false
	if CurrentMidas == self then
		CurrentMidas = nil :: any
	end
	table.clear(self)
	setmetatable(self, nil)
end

--[=[
	This triggers the process of gathering rows for posting for all datatables. All the parameters are meant to help the dev work within the limits of whatever API they use to store data.

	@param maxEntriesPerTable number -- the max number of entries per table you'll be posting
	@param maxSizePerTable number -- the max amount of data (in characters) that can be sent per table in a single post
	@param delayPerTable number -- the amount it will wait between post requests, skipped if the table is empty
	@param recursive boolean -- whether it sticks on a single table, delaying and posting until it is empty.
	@return totalSuccess boolean -- whether all data tables posted without error
	@return totalEmpty boolean -- whether every datatable is now empty
	@return netData number -- the amount of data (in characters) sent by all tables
]=]
function Midas:Post(
	maxEntriesPerTable: number,
	maxSizePerTable: number,
	delayPerTable: number,
	recursive: boolean
): (boolean, boolean, number)
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
				local success, isEmpty, data =
					dataSets:Post(maxEntriesPerTable, maxSizePerTable, delayPerTable, recursive)
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

--[=[
	Constructs a dataset

	@param name string -- the key your dataset will be organized under
	@param id string -- the id that's passed to the data posting solution

	@return dataset DataSet -- the dataset you just constructed
]=]
function Midas:CreateDataSet(name: string, id: string): DataSet
	assert(self._DataSets[name] == nil, `dataSet of name {name} already exists`)
	local dataSet = DataSet.new(name, id, function()
		return function(
			dataSetId: string,
			dataTableId: string,
			dataList: { [number]: { [string]: unknown } },
			format: { [string]: DataType },
			onPayloadSizeKnownInvoke: (size: number) -> ()
		): boolean
			local projectId = self.ProjectId
			assert(projectId, `projectId hasn't been set yet`)

			local onBatchInsertInvoke = self._OnBatchInsertInvoke
			assert(onBatchInsertInvoke, `onBatchInsertInvoke hasn't been set yet`)

			return onBatchInsertInvoke(projectId, dataSetId, dataTableId, dataList, format, onPayloadSizeKnownInvoke)
		end
	end, function()
		return function(
			dataSetId: string,
			dataTableId: string,
			onKey: string,
			dataList: { [number]: { [string]: unknown } },
			format: { [string]: DataType },
			onPayloadSizeKnownInvoke: (size: number) -> ()
		): boolean
			local projectId = self.ProjectId
			assert(projectId, `projectId hasn't been set yet`)

			local onBatchSetInvoke = self._OnBatchSetInvoke
			assert(onBatchSetInvoke, `onBatchSetInvoke hasn't been set yet`)

			return onBatchSetInvoke(
				projectId,
				dataSetId,
				dataTableId,
				onKey,
				dataList,
				format,
				onPayloadSizeKnownInvoke
			)
		end
	end)
	self._DataSets[name] = dataSet
	return dataSet
end

--[=[
	Sets the posting function

	@param onBatchInsertInvoke OnBatchInsertInvoke -- the function that posts data
]=]
function Midas:SetOnBatchInsertInvoke(onBatchInsertInvoke: OnBatchInsertInvoke)
	self._OnBatchInsertInvoke = onBatchInsertInvoke
end

--[=[
	Sets the posting function

	@param onBatchInsertInvoke OnBatchInsertInvoke -- the function that posts data
]=]
function Midas:SetOnBatchSetInvoke(onBatchSetInvoke: OnBatchSetInvoke)
	self._OnBatchSetInvoke = onBatchSetInvoke
end

--- gets a dataset by name
function Midas:GetDataSet(name: string): DataSet
	local dataSets = self._DataSets[name]
	assert(dataSets, `no dataset at {name}`)
	return dataSets
end

--- gets a list of datasets
function Midas:GetDataSets(): { [number]: DataSet }
	return TableUtil.values(self._DataSets)
end

--- gets the number of rows currently waiting to be processed
function Midas:GetRowCount(): number
	local rows = 0
	for i, dataSet in ipairs(self:GetDataSets()) do
		rows += dataSet:GetRowCount()
	end
	return rows
end

--[=[
	Automates the posting of rows, dynamically adapting to handle errors and rate limits as appropriate.
	@param printEnabled boolean -- whether you want to print the results of each post (useful for debugging).
	@param maxEntriesPerTable number? -- The upper limit for how many entries you allow. Defaults to 200.
	@param minDurationPerTable number? -- The delay after posting a table. Defaults to 1.
	@param updateDelay number? -- How long Midas will wait for rows to accumulate between runs.
	@param averageSizePerRow number? -- Used to estimate how much data will be passed by a table. Defaults to 200
	@param escalationRate number? -- The speed at which it will alter limits to achieve a successful post.
	@param onAttemptInvokeLogger OnAttemptInvokeLogger? --A function that is called after each attempted run, used for debugging / logging performance mostly.

]=]
function Midas:Automate(
	printEnabled: boolean,
	maxEntriesPerTable: number?,
	minDurationPerTable: number?,
	updateDelay: number?,
	averageSizePerRow: number?,
	escalationRate: number?,
	onAttemptInvokeLogger: OnAttemptInvokeLogger?
): ()
	maxEntriesPerTable = maxEntriesPerTable or 200
	assert(maxEntriesPerTable)

	averageSizePerRow = averageSizePerRow or 200
	assert(averageSizePerRow)

	minDurationPerTable = minDurationPerTable or 1
	assert(minDurationPerTable)

	escalationRate = escalationRate or 2
	assert(escalationRate)

	updateDelay = updateDelay or 15
	assert(updateDelay)

	local function log(msg: string)
		if printEnabled then
			print(msg)
		end
	end
	task.spawn(function()
		local postIndex = 0

		while self._IsAlive do
			local success: boolean, isComplete: boolean, size: number
			local entriesPerTable = maxEntriesPerTable
			local duration = minDurationPerTable
			local runIndex = 0
			postIndex += 1
			task.wait(updateDelay)
			repeat
				success, isComplete, size = false, false, 0
				runIndex += 1
				local start = tick()
				local maxSize = maxEntriesPerTable * averageSizePerRow
				local rowCount = self:GetRowCount()

				local tableCount = 0
				for i, dataSet in ipairs(self:GetDataSets()) do
					tableCount += #dataSet:GetDataTables()
				end

				local pSuccess, msg = pcall(function()
					success, isComplete, size = self:Post(entriesPerTable, maxSize, duration, false)
				end)
				log(`post {postIndex}.{runIndex} = [{success}&{pSuccess}]@[#{entriesPerTable}x{duration}s]`)

				if not pSuccess then
					log(msg)
					task.spawn(function()
						error(msg)
					end)
					success = false
				else
					log("post-success")
				end
				if success and pSuccess then
					entriesPerTable *= escalationRate
					entriesPerTable = math.min(entriesPerTable, maxEntriesPerTable)
					entriesPerTable = math.ceil(entriesPerTable)

					duration /= escalationRate
					duration = math.max(duration, minDurationPerTable)
				else
					entriesPerTable /= escalationRate
					entriesPerTable = math.ceil(entriesPerTable)

					duration *= escalationRate
				end

				if onAttemptInvokeLogger then
					onAttemptInvokeLogger(
						(success and pSuccess),
						size,
						rowCount,
						maxSize,
						entriesPerTable * tableCount,
						self:GetRowCount(),
						runIndex,
						msg
					)
				end

				local runDuration = tick() - start

				if runDuration < updateDelay then
					task.wait(updateDelay - runDuration)
				end
			until (success == true and isComplete == true) or not self._IsAlive
		end
	end)
end

function Midas.new(): Midas
	local self: Midas = setmetatable({}, Midas) :: any
	self._IsAlive = true
	self.ProjectId = nil
	self.StorageProviders = StorageProviders
	self.Util = Util
	self._OnBatchInsertInvoke = function(): boolean
		warn(`onBatchInsertInvoke not set`)
		return false
	end
	self._OnBatchSetInvoke = function(): boolean
		warn(`onBatchInsertInvoke not set`)
		return false
	end

	local success, msg = pcall(function()
		game:BindToClose(function()
			self:Post(math.huge, math.huge, 1 / 60, true)
		end)
	end)
	if not success then
		warn(msg)
	end

	self._DataSets = {}
	if CurrentMidas ~= nil then
		CurrentMidas:Destroy()
		CurrentMidas = nil :: any
	end
	CurrentMidas = self

	return self
end

--- initializes the package
function Midas.init(): () -> ()
	print(`booting {script.Name}`)
	local midas = Midas.new()
	return function()
		midas:Destroy()
	end
end

return ServiceProxy(function()
	return CurrentMidas or Midas
end)
