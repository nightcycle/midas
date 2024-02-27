--!strict
-- Services
local Players = game:GetService("Players")
local VoiceChatService = game:GetService("VoiceChatService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")

-- Packages
-- Modules
local AnalyticsUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AnalyticsUtil"))

-- Types
type AnalyticsPlatform = AnalyticsUtil.AnalyticsPlatform
-- Constants

local ANALYTICS_PERFORMANCE_TABLE_ITERATION = AnalyticsUtil.Config.Iteration.User.Performance
local ANALYTICS_SESSION_TABLE_ITERATION = AnalyticsUtil.Config.Iteration.User.Session

-- Variables
-- References
local RegisterUser = AnalyticsUtil.Remote.Function.Register
local GetPing = AnalyticsUtil.Remote.Function.GetPing
local UpdateClientPerformance = AnalyticsUtil.Remote.Event.UpdateClientPerformance
local GetLastPosition = AnalyticsUtil.Remote.Function.GetLastPosition


-- Private Functions
function waitForChildOfClass(par: Instance, getIfAlive: () -> boolean, class: string): Instance?
	local out: Instance? = par:FindFirstChildOfClass(class :: any)
	while (not out) and getIfAlive() do
		task.wait(0.2)
		out = par:FindFirstChildOfClass(class :: any)
	end
	return out
end
-- Class
-- Types
type UserSessionRowData = AnalyticsUtil.UserSessionRowData
type UserPerformanceRowData = AnalyticsUtil.UserPerformanceRowData

do
	local player = Players.LocalPlayer
	local start = DateTime.now()
	local sessionId = `{player.UserId}-{start.UnixTimestampMillis}`

	-- register client
	do
		local isVCEnabled: boolean?
		local success, msg = pcall(function()
			isVCEnabled = VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
		end)
		if not success then
			task.spawn(function()
				error(msg)
			end)
		end

		local platformType: AnalyticsPlatform = "Unknown"
		if UserInputService.KeyboardEnabled then
			platformType = "PC"
		elseif UserInputService.TouchEnabled then
			platformType = "Mobile"
		elseif UserInputService.GamepadEnabled then
			platformType = "Console"
		elseif UserInputService.VREnabled then
			platformType = "VR"
		end

		local rowData: UserSessionRowData = {
			event = AnalyticsUtil.Enums.AnalyticsSessionEvent("Join"),
			session_id = sessionId,
			user_id = player.UserId,
			iteration = ANALYTICS_SESSION_TABLE_ITERATION,
			follow_user_id = player.FollowUserId,
			job_id = game.JobId,
			is_voice_chat = isVCEnabled,
			language = player.LocaleId,
			platform = AnalyticsUtil.Enums.AnalyticsPlatform(platformType),
			screen_x = workspace.CurrentCamera.ViewportSize.X,
			screen_y = workspace.CurrentCamera.ViewportSize.Y,
			is_premium = player.MembershipType == Enum.MembershipType.Premium,
			account_age = player.AccountAge,
			timestamp = DateTime.now(),
			duration = 0,
			is_finished_loading = false,
		}

		RegisterUser:InvokeServer(rowData)
	end

	local function initCharacter(character: Model?)
		if not character then
			return
		end
		assert(character)

		local humanoid: Instance? = waitForChildOfClass(character, function()
			return character == player.Character
		end, "Humanoid")
		assert(humanoid and humanoid:IsA("Humanoid"))

		do
			local lastKnownPosition: Vector3?
			RunService.RenderStepped:Connect(function()
				if humanoid.Health > 0 then
					local hrp = character.PrimaryPart
					if hrp then
						lastKnownPosition = hrp.Position
					end
				end
			end)

			GetLastPosition.OnClientInvoke = function(): Vector3?
				return lastKnownPosition
			end
		end
	end
	player.CharacterAdded:Connect(initCharacter)
	initCharacter(player.Character)
	-- update performance
	task.spawn(function()
		local fps = 0
		RunService.RenderStepped:Connect(function()
			fps += 1
			task.delay(1, function()
				fps -= 1
			end)
		end)

		while true do
			task.wait(15)
			local quality = UserSettings().GameSettings.SavedQualityLevel

			local rowData: UserPerformanceRowData = {
				session_id = sessionId,
				timestamp = DateTime.now(),
				fps = fps,
				ping = 0,
				iteration = ANALYTICS_PERFORMANCE_TABLE_ITERATION,
				data_send = Stats.DataSendKbps,
				data_receive = Stats.DataReceiveKbps,
				instance_count = Stats.InstanceCount,
				memory_total = Stats:GetTotalMemoryUsageMb(),
				memory_animation = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Animation),
				memory_graphics = (function(): number
					local out = 0
					for i, v in ipairs(Enum.DeveloperMemoryTag:GetEnumItems()) do
						if v.Name:find("Graphics") then
							out += Stats:GetMemoryUsageMbForTag(v)
						end
					end
					return out
				end)(),
				quality = if quality ~= Enum.SavedQualitySetting.Automatic then quality.Value else nil,
				memory_gui = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui),
				memory_instances = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances),
				memory_lua_heap = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap),
				memory_script = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script),
				memory_signal = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Signals),
				memory_sound = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Sounds),
			}
			UpdateClientPerformance:FireServer(rowData)
		end
	end)

	GetPing.OnClientInvoke = function(): boolean
		return true
	end
end
