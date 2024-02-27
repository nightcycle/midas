--!strict
-- Services
local RunService = game:GetService("RunService")
-- Packages
-- Modules
-- Types
type BaseRowData = {
	iteration: number,
	timestamp: DateTime,
}
type UserRowData = BaseRowData & {
	session_id: string,
}
type ServerRowData = BaseRowData & {
	job_id: string,
}

--- DONE!
export type UserSettingsRowData = UserRowData & {
	large_text: boolean?,
	dark_mode: boolean?,
	music_enabled: boolean?,
}

--- DONE!
export type UserSessionRowData = UserRowData & {
	event: number,
	user_id: number,
	duration: number,
	job_id: string,
	language: string?,
	platform: number?,
	is_voice_chat: boolean?,
	screen_x: number?,
	screen_y: number?,
	follow_user_id: number?,
	is_premium: boolean?,
	is_verified: boolean?,
	account_age: number?,
	is_tester: boolean?,
	is_group: boolean?,
	is_finished_loading: boolean,
}

export type UserSocialRowData = UserRowData & {
	message: string,
	pos_x: number?,
	pos_y: number?,
	pos_z: number?,
}

export type UserMonetizationRowData = UserRowData & {
	revenue: number,
	type: number,
	product_id: number,
}

export type ServerPopulationRowData = ServerRowData & {
	event: number,
	users: string,
	friends: string,
}

export type ServerMidasRowData = ServerRowData & {
	success: boolean,
	size: number,
	size_limit: number,
	rows: number,
	row_limit: number,
	rows_remaining: number,
	attempt: number,
	error_message: string?,
	distribution: string,
}

export type ServerPerformanceRowData = ServerRowData & {
	version: string,
	build: number,
	heartbeat: number,
	ping: number?,
	instance_count: number,
	data_send: number,
	data_receive: number,
	memory_total: number,
	memory_http_cache: number,
	memory_instances: number,
	memory_lua_heap: number,
	memory_physics: number,
	memory_script: number,
	memory_signal: number,
	memory_sound: number,
}

export type UserPerformanceRowData = UserRowData & {
	fps: number,
	ping: number,

	data_send: number,
	data_receive: number,

	instance_count: number,

	quality: number?,

	memory_total: number,
	memory_animation: number,
	memory_graphics: number,
	memory_gui: number,
	memory_instances: number,
	memory_lua_heap: number,
	memory_script: number,
	memory_signal: number,
	memory_sound: number,
}


export type AnalyticsPlatform = "PC" | "Mobile" | "Console" | "VR" | "Unknown"
export type AnalyticsSessionEvent = "Join" | "Quit"

-- Constants
local ANALYTICS_PLATFORM_ENUM: {[AnalyticsPlatform]: number} = {
	PC = 1,
	Mobile = 2,
	Console = 3,
	VR = 4,
	Unknown = 5,
}
local ANALYTICS_SESSION_EVENT_ENUM: {[AnalyticsSessionEvent]: number} = {
	Join = 1,
	Quit = 2,
}
-- Variables
-- References
-- Private Functions
local function getOrConstructRemoteEvent(name: string): RemoteEvent
	local out: Instance
	if RunService:IsClient() then
		out = script:WaitForChild(name)
	else
		out = script:FindFirstChild(name) or Instance.new("RemoteEvent")
	end
	assert(out:IsA("RemoteEvent"), `bad inst, expected RemoteEvent, got {out.ClassName}`)
	out.Name = name
	return out
end

local function getOrConstructRemoteFunction(name: string): RemoteFunction
	local out: Instance
	if RunService:IsClient() then
		out = script:WaitForChild(name)
	else
		out = script:FindFirstChild(name) or Instance.new("RemoteFunction")
	end
	assert(out:IsA("RemoteFunction"), `bad inst, expected RemoteFunction, got {out.ClassName}`)
	out.Name = name
	return out
end

-- Class
local AnalyticsUtil = {
	Enums = {
		AnalyticsPlatform = function(val: AnalyticsPlatform): number
			local num = ANALYTICS_PLATFORM_ENUM[val]
			assert(num ~= nil, `bad AnalyticsPlatform enum {val}`)
			return num
		end,
		AnalyticsSessionEvent = function(val: AnalyticsSessionEvent): number
			local num = ANALYTICS_SESSION_EVENT_ENUM[val]
			assert(num ~= nil, `bad AnalyticsSessionEvent enum {val}`)
			return num
		end,
	},
	Remote = {
		Event = {
			UpdateClientPerformance = getOrConstructRemoteEvent("AnalyticsUpdateClientPerformance"),
			OnSettingsUpdate = getOrConstructRemoteEvent("OnSettingsUpdate"),
		},
		Function = {
			Register = getOrConstructRemoteFunction("AnalyticsRegisterUser"),
			GetPing = getOrConstructRemoteFunction("AnalyticsGetPing"),
			GetLastPosition = getOrConstructRemoteFunction("AnalyticsGetLastPosition"),
		},
	},
	Config = {
		Version = "0.1.0",	
		Iteration = {
			User = {
				Session = 7,
				Performance = 2,
				Social = 3,
				Map = 2,
				Settings = 2,
			},
			Server = {
				Population = 2,
				Performance = 3,
				Midas = 4,
			},
		},
	},
}



return AnalyticsUtil
