--!strict
-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

-- Packages
local Midas = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Midas"))

-- Modules
local AnalyticsUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AnalyticsUtil"))
local AnalyticsConstruction = require(script:WaitForChild("Construction"))

-- Types
type DataTable<V> = Midas.DataTable<V>
export type UserSessionRowData = AnalyticsUtil.UserSessionRowData
export type UserPerformanceRowData = AnalyticsUtil.UserPerformanceRowData
export type UserMonetizationRowData = AnalyticsUtil.UserMonetizationRowData
export type UserSettingsRowData = AnalyticsUtil.UserSettingsRowData
export type ServerPopulationRowData = AnalyticsUtil.ServerPopulationRowData
export type ServerPerformanceRowData = AnalyticsUtil.ServerPerformanceRowData
export type ServerMidasRowData = AnalyticsUtil.ServerMidasRowData

export type DataType = Midas.DataType

export type Analytics = {
	__index: Analytics,
	SessionIds: {[number]: string},
	DataTables: AnalyticsConstruction.DataTables,
	new: () -> Analytics,
}
-- Constants
local MONGO_API_KEY = "abc1235230sawhateveryourapikeyis" -- DEFINITELY DO NOT PUT THIS IN SHARED OR CLIENT
local MONGO_URL_ENDPOINT = "https://us-east-2.aws.data.mongodb-api.com/app/data-abc123"
local PROJECT_ID = "project-id"
local VERSION = AnalyticsUtil.Config.Version
local MAX_ENTRIES_PER_TABLE = 200 --how many entries / rows trigger a table post
local AVG_SIZE_PER_ROW = 200 --the avg number of characters per row, used to est char limit trigger of table post
local MIN_DURATION_PER_TABLE = 1 --the minimum amount of time posts are separated by
local ESCALATION_RATE = 2 --how much it slows / speeds up based on a failed / successful post
local GROUP_ID = 123456
local GROUP_TESTER_RANK_ID = 7891011
local UPDATE_DELAY = 15
local TESTER_RANK = 10
local ANALYTICS_SOCIAL_TABLE_ITERATION = AnalyticsUtil.Config.Iteration.User.Social
local ANALYTICS_SESSION_TABLE_ITERATION = AnalyticsUtil.Config.Iteration.User.Session
local ANALYTICS_SETTINGS_TABLE_ITERATION = AnalyticsUtil.Config.Iteration.User.Settings
local ANALYTICS_MIDAS_TABLE_ITERATION = AnalyticsUtil.Config.Iteration.Server.Midas
local ANALYTICS_PERFORMANCE_TABLE_ITERATION = AnalyticsUtil.Config.Iteration.Server.Performance
local ANALYTICS_POPULATION_TABLE_ITERATION = AnalyticsUtil.Config.Iteration.Server.Population

local ON_LOADING_SEQUENCE_COMPLETE = "OnLoadingSequenceComplete"
-- Variables
-- References
local RegisterUser = AnalyticsUtil.Remote.Function.Register
local GetPing = AnalyticsUtil.Remote.Function.GetPing
local UpdatePerformance = AnalyticsUtil.Remote.Event.UpdateClientPerformance
local OnSettingsUpdate = AnalyticsUtil.Remote.Event.OnSettingsUpdate
local GetLastPosition = AnalyticsUtil.Remote.Function.GetLastPosition
-- Private Functions

-- Class
local Analytics = {} :: Analytics
Analytics.__index = Analytics

function Analytics.new(): Analytics

	do
		Midas.init()
		Midas.ProjectId = PROJECT_ID
	
		local mongoDB = Midas.StorageProviders.MongoDB.new(MONGO_API_KEY, MONGO_URL_ENDPOINT)
		mongoDB.DebugPrintEnabled = false -- RunService:IsStudio()
	
		Midas:SetOnBatchSaveInvoke(
			function(
				projectId: string,
				dataSetId: string,
				dataTableId: string,
				dataList: { [number]: { [string]: unknown } },
				format: { [string]: DataType },
				onPayloadSizeKnownInvoke:(number) -> ()
			): boolean
				return mongoDB:InsertMany(projectId, dataSetId, dataTableId, dataList, format, onPayloadSizeKnownInvoke)
			end
		)	
	end


	local self: Analytics = setmetatable({}, Analytics) :: any
	self.SessionIds = {}
	self.DataTables = AnalyticsConstruction()

	task.spawn(function()
		local heartbeat = 0
		RunService.Heartbeat:Connect(function()
			heartbeat += 1
			task.delay(1, function()
				heartbeat -= 1
			end)
		end)
		task.wait(1)

		while true do
			local success, msg = pcall(function()

				local netPing = 0
				local count = 0
				for i, player in ipairs(Players:GetPlayers()) do
					local start = tick()
					GetPing:InvokeClient(player)
					local finish = tick()
					count += 1
					netPing += (finish - start)*1000
				end

				self.DataTables.Server.Performance:AddRow({
					job_id = game.JobId,
					build = game.PlaceVersion,
					timestamp = DateTime.now(),
					iteration = ANALYTICS_PERFORMANCE_TABLE_ITERATION,
					data_receive = Stats.DataReceiveKbps,
					data_send = Stats.DataSendKbps,
					heartbeat = heartbeat,
					instance_count = Stats.InstanceCount,
					memory_http_cache = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.HttpCache),
					memory_instances = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances),
					memory_lua_heap = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap),
					memory_physics = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsCollision) + Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.PhysicsParts),
					memory_script = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script),
					memory_signal = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Signals),
					memory_sound = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Sounds),
					memory_total = Stats:GetTotalMemoryUsageMb(),
					ping = if count > 0 then math.round(netPing/count) else nil,
					version = VERSION
				})
			end)
			if not success then
				print(msg)
			end
			task.wait(15)
		end
	end)

	local loadRegistry: {[number]: boolean} = {}

	local onLoadingComplete = Instance.new("RemoteEvent")
	onLoadingComplete.Name = ON_LOADING_SEQUENCE_COMPLETE
	onLoadingComplete.OnServerEvent:Connect(function(player: Player)
		loadRegistry[player.UserId] = true
	end)
	onLoadingComplete.Parent = StarterGui

	RegisterUser.OnServerInvoke = function(player: Player, joinRowData: UserSessionRowData): nil
		if self.SessionIds[player.UserId] then return nil end
		
		local start = joinRowData.timestamp
		local sessionId = joinRowData.session_id
		self.SessionIds[player.UserId] = sessionId
		
		local onChatted: RBXScriptConnection
		local onPlayerRemoving: RBXScriptConnection

		onChatted = player.Chatted:Connect(function(message: string, otherPlayer: Player?)
			local lastPosition = GetLastPosition:InvokeClient(player)
			assert(lastPosition == nil or typeof(lastPosition) == "Vector3", `bad position: {typeof(lastPosition)}`)
			self.DataTables.User.Social:AddRow({
				message = message,
				pos_x = if lastPosition then lastPosition.X else nil,
				pos_y = if lastPosition then lastPosition.Y else nil,
				pos_z = if lastPosition then lastPosition.Z else nil,
				iteration = ANALYTICS_SOCIAL_TABLE_ITERATION,
				session_id = sessionId,
				timestamp = DateTime.now(),
			})
		end)

		onPlayerRemoving = Players.PlayerRemoving:Connect(function(remPlayer: Player)
			if remPlayer.UserId == player.UserId then
				local didLoad = false
				-- print(loadRegistry)
				if loadRegistry[player.UserId] ~= nil then
					didLoad = loadRegistry[player.UserId]
					loadRegistry[player.UserId] = nil
				end
				-- print("didLoad", didLoad)
				local finish = DateTime.now()
				self.DataTables.User.Session:AddRow({
					event = AnalyticsUtil.Enums.AnalyticsSessionEvent("Quit"),
					session_id = sessionId,
					iteration = ANALYTICS_SESSION_TABLE_ITERATION,
					job_id = game.JobId,
					user_id = player.UserId,
					duration = (finish.UnixTimestampMillis - start.UnixTimestampMillis)/1000,
					timestamp = DateTime.now(),
					is_finished_loading = didLoad,
				})
				self.SessionIds[player.UserId] = nil
				onChatted:Disconnect()
				onPlayerRemoving:Disconnect()
				if #Players:GetPlayers() == 0 then
					Midas:Post(
						1000000000, 
						1000000000, 
						0, 
						true
					)
				end
			end
		end)


		task.spawn(function()
			local success, msg = pcall(function()
				joinRowData.is_group = player:IsInGroup(GROUP_ID)
				joinRowData.is_tester = player:GetRankInGroup(GROUP_TESTER_RANK_ID) == TESTER_RANK
			end)
			if not success then
				task.spawn(function()
					error(msg)
				end)
			end
			self.DataTables.User.Session:AddRow(joinRowData)
		end)

		return nil
	end

	Midas:Automate(
		true,
		MAX_ENTRIES_PER_TABLE,
		MIN_DURATION_PER_TABLE,
		UPDATE_DELAY,
		AVG_SIZE_PER_ROW,
		ESCALATION_RATE,
		function()

		end
	)

	function Midas:Automate(
		printEnabled: boolean,
		maxEntriesPerTable: number?,
		minDurationPerTable: number?,
		updateDelay: number?,
		averageSizePerRow: number?,
		escalationRate: number?,
		onAttemptInvokeLogger: Midas.OnAttemptInvokeLogger?
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
					local maxSize = maxEntriesPerTable*averageSizePerRow
					local rowCount = self:GetRowCount()
			
					local tableCount = 0
					for i, dataSet in ipairs(self:GetDataSets()) do
						tableCount += #dataSet:GetDataTables()
					end
		
					local pSuccess, msg = pcall(function()
						success, isComplete, size = self:Post(
							entriesPerTable,
							maxSize,
							duration,
							false
						)
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
						task.wait(updateDelay-runDuration)
					end
				until (success == true and isComplete == true) or not self._IsAlive
			end
		end)
	end

	task.spawn(function()
		local postIndex = 0

		while true do
			local success: boolean, isComplete: boolean, size: number
			local entriesPerTable = MAX_ENTRIES_PER_TABLE
			local duration = MIN_DURATION_PER_TABLE
			local runIndex = 0
			postIndex += 1
			task.wait(UPDATE_DELAY)
			repeat
				success, isComplete, size = false, false, 0
				runIndex += 1
				local start = tick()
				local maxSize = MAX_ENTRIES_PER_TABLE*AVG_SIZE_PER_ROW
				local rowCount = Midas:GetRowCount()

				local distribution: {[string]: {[string]: number}} = {}

				local tableCount = 0
				for cat, dTRegistry in pairs(self.DataTables) do
					distribution[cat] = {}
					for k, dataTable in pairs(dTRegistry :: {[string]: DataTable<any>}) do
						distribution[cat][k] = dataTable:GetRowCount()
						tableCount += 1
					end
				end

				local pSuccess, msg = pcall(function()
					success, isComplete, size = Midas:Post(
						entriesPerTable,
						maxSize,
						duration,
						false
					)
				end)
				print(`post {postIndex}.{runIndex} = [{success}&{pSuccess}]@[#{entriesPerTable}x{duration}s]`)
			
				if not pSuccess then
					print(msg)
					task.spawn(function()
						error(msg)
					end)
					success = false
				else
					print("post-success")
				end
				if success and pSuccess then
					entriesPerTable *= ESCALATION_RATE
					entriesPerTable = math.min(entriesPerTable, MAX_ENTRIES_PER_TABLE)
					entriesPerTable = math.ceil(entriesPerTable)

					duration /= ESCALATION_RATE
					duration = math.max(duration, MIN_DURATION_PER_TABLE)

				else
					entriesPerTable /= ESCALATION_RATE
					entriesPerTable = math.ceil(entriesPerTable)

					duration *= ESCALATION_RATE
				end

				self.DataTables.Server.Midas:AddRow({
					success = (success and pSuccess),
					size = size,
					iteration = ANALYTICS_MIDAS_TABLE_ITERATION,
					size_limit = maxSize,
					rows = rowCount,
					row_limit = entriesPerTable * tableCount,
					rows_remaining = Midas:GetRowCount(),
					attempt = runIndex,
					error_message = msg,
					job_id = game.JobId,
					timestamp = DateTime.now(),
					distribution = HttpService:JSONEncode(distribution)
				})

				if not (success and pSuccess) then
					self.DataTables.Server.Midas:Post(
						math.huge,
						math.huge
					)
				end

				local runDuration = tick() - start
				
				if runDuration < UPDATE_DELAY then
					task.wait(UPDATE_DELAY-runDuration)
				end
			until (success == true and isComplete == true)
		end
	end)


	do
		OnSettingsUpdate.OnServerEvent:Connect(function(player: Player, isDark: boolean?, isLarge: boolean?, isMusicEnabled: boolean?)
			local sessionId = self.SessionIds[player.UserId]
			assert(sessionId ~= nil)
			self.DataTables.User.Settings:AddRow({
				session_id = sessionId,
				iteration = ANALYTICS_SETTINGS_TABLE_ITERATION,
				timestamp = DateTime.now(),
				dark_mode = isDark,
				large_text = isLarge,
				music_enabled = isMusicEnabled,
			})
		end)
	end

	do
		local friends: {[string]: {[number]: string}} = {}
		local users: {[number]: number} = {}
		local function update(event: AnalyticsUtil.AnalyticsSessionEvent)
			self.DataTables.Server.Population:AddRow({
				job_id = game.JobId,
				iteration = ANALYTICS_POPULATION_TABLE_ITERATION,
				friends = HttpService:JSONEncode(friends),
				users = HttpService:JSONEncode(users),
				event = AnalyticsUtil.Enums.AnalyticsSessionEvent(event),
				timestamp = DateTime.now(),
			} :: ServerPopulationRowData)
		end

		Players.PlayerAdded:Connect(function(player: Player)
			table.insert(users, player.UserId)
			local function addFriend(host: number, friend: number)
				if not friends[tostring(host)] then
					friends[tostring(host)] = {}
				end
				if not table.find(friends[tostring(host)], tostring(friend)) then
					table.insert(friends[tostring(host)], tostring(friend))
				end
			end
			for i, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer.UserId ~= player.UserId then
					if otherPlayer:IsFriendsWith(player.UserId) then
						addFriend(otherPlayer.UserId, player.UserId)
						addFriend(player.UserId, otherPlayer.UserId)
					end
				end
			end
			update("Join")
		end)

		Players.PlayerRemoving:Connect(function(player: Player)
			local i = table.find(users, player.UserId)
			if i then
				table.remove(users, i)
			end
			for k, friendList in pairs(friends) do
				if k == tostring(player.UserId) then
					friends[k] = nil
				else
					local fI = table.find(friendList, tostring(player.UserId))
					if fI then
						table.remove(friendList, fI)
					end
					if #friendList <= 0 then
						friends[k] = nil
					end
				end
			end
			update("Quit")
		end)
	end


	do	
		UpdatePerformance.OnServerEvent:Connect(function(player: Player, data: UserPerformanceRowData)

			local start = tick()
			GetPing:InvokeClient(player)
			local finish = tick()
			data.ping = math.round(1000*(finish-start))

			self.DataTables.User.Performance:AddRow(data)
		end)

	end

	return self
end

return Analytics.new()