--!strict
-- Services
-- Packages
local Midas = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Midas"))

-- Modules
local AnalyticsUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AnalyticsUtil"))

-- Types
type DataTable<V> = Midas.DataTable<V>
type UserSessionRowData = AnalyticsUtil.UserSessionRowData
type UserPerformanceRowData = AnalyticsUtil.UserPerformanceRowData
type UserSocialRowData = AnalyticsUtil.UserSocialRowData
type UserMonetizationRowData = AnalyticsUtil.UserMonetizationRowData
type UserSettingsRowData = AnalyticsUtil.UserSettingsRowData
type ServerPopulationRowData = AnalyticsUtil.ServerPopulationRowData
type ServerPerformanceRowData = AnalyticsUtil.ServerPerformanceRowData
type ServerMidasRowData = AnalyticsUtil.ServerMidasRowData

export type DataTables = {
	User: {
		Session: DataTable<UserSessionRowData>,
		Performance: DataTable<UserPerformanceRowData>,
		Social: DataTable<UserSocialRowData>,
		Monetization: DataTable<UserMonetizationRowData>,
		Settings: DataTable<UserSettingsRowData>,
	},
	Server: {
		Population: DataTable<ServerPopulationRowData>,
		Performance: DataTable<ServerPerformanceRowData>,
		Midas: DataTable<ServerMidasRowData>,
	},
}
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
return function(): DataTables
	local dataTables: DataTables = {
		User = {},
		Server = {},
	} :: any

	local function addTimestampColumn(dataTable: DataTable<any>)
		dataTable:AddColumn("timestamp", "Date", false)
	end

	local function addIterationColumn(dataTable: DataTable<any>)
		dataTable:AddColumn("iteration", "Int32", false)
	end

	do
		local function addSessionIdColumn(dataTable: DataTable<any>)
			dataTable:AddColumn("session_id", "String", false)
		end

		local userDataSet = Midas:CreateDataSet("User", "user")

		do
			local sessionDataTable = userDataSet:CreateDataTable("Session", "session")
			addSessionIdColumn(sessionDataTable)
			addTimestampColumn(sessionDataTable)
			addIterationColumn(sessionDataTable)
			sessionDataTable:AddColumn("job_id", "String", false)
			sessionDataTable:AddColumn("event", "Int32", false)
			sessionDataTable:AddColumn("follow_user_id", "Int64", true)
			sessionDataTable:AddColumn("is_voice_chat", "Boolean", true)
			sessionDataTable:AddColumn("language", "String", true)
			sessionDataTable:AddColumn("platform", "Int32", true)
			sessionDataTable:AddColumn("os", "Int32", true)
			sessionDataTable:AddColumn("screen_x", "Int32", true)
			sessionDataTable:AddColumn("screen_y", "Int32", true)
			sessionDataTable:AddColumn("user_id", "Int64", false)
			sessionDataTable:AddColumn("duration", "Int32", false)
			sessionDataTable:AddColumn("is_premium", "Boolean", true)
			sessionDataTable:AddColumn("account_age", "Int32", true)
			sessionDataTable:AddColumn("is_verified", "Boolean", true)
			sessionDataTable:AddColumn("is_tester", "Boolean", true)
			sessionDataTable:AddColumn("is_nightcycle", "Boolean", true)
			sessionDataTable:AddColumn("is_finished_loading", "Boolean", false)

			dataTables.User.Session = sessionDataTable
		end

		do
			local performanceDataTable = userDataSet:CreateDataTable("Performance", "performance")
			addSessionIdColumn(performanceDataTable)
			addTimestampColumn(performanceDataTable)
			addIterationColumn(performanceDataTable)
			performanceDataTable:AddColumn("data_receive", "Int32", false)
			performanceDataTable:AddColumn("data_send", "Int32", false)
			performanceDataTable:AddColumn("quality", "Int32", true)
			performanceDataTable:AddColumn("fps", "Int32", false)
			performanceDataTable:AddColumn("instance_count", "Int32", false)
			performanceDataTable:AddColumn("memory_total", "Int32", false)
			performanceDataTable:AddColumn("memory_animation", "Int32", false)
			performanceDataTable:AddColumn("memory_graphics", "Int32", false)
			performanceDataTable:AddColumn("memory_gui", "Int32", false)
			performanceDataTable:AddColumn("memory_instances", "Int32", false)
			performanceDataTable:AddColumn("memory_lua_heap", "Int32", false)
			performanceDataTable:AddColumn("memory_script", "Int32", false)
			performanceDataTable:AddColumn("memory_signal", "Int32", false)
			performanceDataTable:AddColumn("memory_sound", "Int32", false)
			performanceDataTable:AddColumn("ping", "Int32", true)
			dataTables.User.Performance = performanceDataTable
		end

		do
			local socialDataTable = userDataSet:CreateDataTable("Social", "social")
			addSessionIdColumn(socialDataTable)
			addTimestampColumn(socialDataTable)
			addIterationColumn(socialDataTable)
			socialDataTable:AddColumn("message", "Int32", false)
			socialDataTable:AddColumn("pos_x", "Int32", true)
			socialDataTable:AddColumn("pos_y", "Int32", true)
			socialDataTable:AddColumn("pos_z", "Int32", true)
			dataTables.User.Social = socialDataTable
		end

		do
			local monetizationDataTable = userDataSet:CreateDataTable("Monetization", "monetization")
			addSessionIdColumn(monetizationDataTable)
			addTimestampColumn(monetizationDataTable)
			addIterationColumn(monetizationDataTable)
			monetizationDataTable:AddColumn("revenue", "Int32", false)
			monetizationDataTable:AddColumn("product_id", "Int64", false)
			monetizationDataTable:AddColumn("type", "Int32", false)
			dataTables.User.Monetization = monetizationDataTable
		end

		do
			local settingsDataTable = userDataSet:CreateDataTable("Settings", "settings")
			addSessionIdColumn(settingsDataTable)
			addTimestampColumn(settingsDataTable)
			addIterationColumn(settingsDataTable)
			settingsDataTable:AddColumn("dark_mode", "Boolean", true)
			settingsDataTable:AddColumn("large_text", "Boolean", true)
			settingsDataTable:AddColumn("music_enabled", "Boolean", true)
			dataTables.User.Settings = settingsDataTable
		end
	end

	do
		local function addJobIdColumn(dataTable: DataTable<any>)
			dataTable:AddColumn("job_id", "String", false)
		end

		local serverDataSet = Midas:CreateDataSet("Server", "server")

		do
			local populationDataTable = serverDataSet:CreateDataTable("Population", "population")
			addJobIdColumn(populationDataTable)
			addTimestampColumn(populationDataTable)
			addIterationColumn(populationDataTable)
			populationDataTable:AddColumn("event", "Int32", false)
			populationDataTable:AddColumn("users", "String", false)
			populationDataTable:AddColumn("friends", "String", false)
			dataTables.Server.Population = populationDataTable
		end
		do
			local performanceDataTable = serverDataSet:CreateDataTable("Performance", "performance")
			addJobIdColumn(performanceDataTable)
			addTimestampColumn(performanceDataTable)
			addIterationColumn(performanceDataTable)
			performanceDataTable:AddColumn("version", "String", false)
			performanceDataTable:AddColumn("build", "Int32", false)
			performanceDataTable:AddColumn("heartbeat", "Int32", false)
			performanceDataTable:AddColumn("ping", "Int32", false)
			performanceDataTable:AddColumn("instance_count", "Int32", false)
			performanceDataTable:AddColumn("data_send", "Int32", false)
			performanceDataTable:AddColumn("data_receive", "Int32", false)
			performanceDataTable:AddColumn("memory_total", "Int32", false)
			performanceDataTable:AddColumn("memory_http_cache", "Int32", false)
			performanceDataTable:AddColumn("memory_instances", "Int32", false)
			performanceDataTable:AddColumn("memory_lua_heap", "Int32", false)
			performanceDataTable:AddColumn("memory_physics", "Int32", false)
			performanceDataTable:AddColumn("memory_script", "Int32", false)
			performanceDataTable:AddColumn("memory_signal", "Int32", false)
			performanceDataTable:AddColumn("memory_sound", "Int32", false)
			dataTables.Server.Performance = performanceDataTable
		end
		do
			local midasDataTable = serverDataSet:CreateDataTable("Midas", "midas")
			addJobIdColumn(midasDataTable)
			addTimestampColumn(midasDataTable)
			addIterationColumn(midasDataTable)
			midasDataTable:AddColumn("success", "Boolean", false)
			midasDataTable:AddColumn("size", "Int32", false)
			midasDataTable:AddColumn("size_limit", "Int32", false)
			midasDataTable:AddColumn("rows", "Int32", false)
			midasDataTable:AddColumn("row_limit", "Int32", false)
			midasDataTable:AddColumn("rows_remaining", "Int32", false)
			midasDataTable:AddColumn("attempt", "Int32", false)
			midasDataTable:AddColumn("distribution", "String", false)
			midasDataTable:AddColumn("error_message", "String", true)
			dataTables.Server.Midas = midasDataTable
		end
	end

	return dataTables
end
