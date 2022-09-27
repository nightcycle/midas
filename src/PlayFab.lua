--!strict
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Packages
local _Package = script.Parent
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)

-- Modules
local Config = require(_Package.Config)

-- Constants
local TITLE_ID: string?
local DEV_SECRET_KEY: string?

-- Class
export type PlayFab = {
	OnFire: _Signal.Signal,
	Register: (self: PlayFab, userId: number) -> (string, string),
	Fire: (
		self: PlayFab,
		pId: string,
		eventName: string,
		data: { [string]: any },
		tags: { [string]: boolean },
		timeStamp: string
	) -> nil,
	init: (titleId: string, devSecretKey: string) -> nil,
}

local PlayFab: PlayFab = {} :: any

type HttpResponse = {
	code: number,
	data: { [string]: any },
}

PlayFab.OnFire = _Signal.new()

function getURL(path: string): string
	assert(TITLE_ID ~= nil, "Bad Title Id")
	return "https://" .. TITLE_ID .. ".playfabapi.com/" .. path
end

function post(url: string, headers: { [string]: any }, body: { [string]: any }, attempt: number?): HttpResponse?
	attempt = attempt or 1
	assert(attempt ~= nil)

	local rawResponse: string?

	local size = string.len(HttpService:JSONEncode(body))
	if RunService:IsStudio() and Config.PrintEventsInStudio then
		local index = 0
		if body.Body and body.Body.State and body.Body.State.Index and body.Body.State.Index.Total then
			index = body.Body.State.Index.Total
		end
		print("Firing " .. tostring(body.EventName), "[", index, "]", "(", size, "):", body)
	end

	local success, _msg = pcall(function()
		rawResponse = HttpService:PostAsync(
			url,
			HttpService:JSONEncode(body or {}),
			Enum.HttpContentType.ApplicationJson,
			false,
			headers
		)
	end)
	local response: HttpResponse
	local dSuccess, dMsg = pcall(function()
		response = HttpService:JSONDecode(rawResponse or "") :: any
	end)
	if not dSuccess then
		print(rawResponse)
		error(dMsg)
	end

	if success and response.code == 200 then
		return response
	elseif attempt < 15 then
		task.wait(1)
		return post(url, headers, body, attempt + 1)
	else
		print(response, success, response)
		error("API call failed to " .. url)
	end
end

function PlayFab:Fire(
	pId: string,
	eventName: string,
	data: { [string]: any },
	tags: { [string]: boolean },
	timeStamp: string
): nil
	assert(RunService:IsServer(), "PlayFab API can only be called on server")

	PlayFab.OnFire:Fire(pId, eventName, data, tags, timeStamp)

	if Config.SendDataToPlayFab == true then
		-- Yield until TITLE_ID has been set
		while TITLE_ID == nil do
			task.wait()
		end

		-- Fire event
		task.spawn(function()
			local url: string = getURL("Server/WritePlayerEvent")

			local headers = {
				["X-SecretKey"] = DEV_SECRET_KEY,
			}

			local body = {
				EventName = string.gsub(eventName, "/", ""),
				PlayFabId = pId,
				CustomTags = tags,
				Timestamp = timeStamp,
				Body = {
					Version = Config.Version,
					State = data or {},
				},
			}

			post(url, headers, body)
		end)
	end

	return nil
end

function PlayFab:Register(userId: number): (string, string)
	assert(RunService:IsServer(), "PlayFab API can only be called on server")
	if Config.SendDataToPlayFab == false then
		return HttpService:GenerateGUID(false), tostring(userId)
	end
	while TITLE_ID == nil do
		print("WAITING FOR TITLE")
		task.wait()
	end
	local url = getURL("Client/LoginWithCustomID")

	local headers = {
		["X-ReportErrorAsSuccess"] = "true",
		["X-PlayFabSDK"] = "RobloxSdk_undefined",
	}

	local body = {
		TitleId = TITLE_ID,
		CustomId = tostring(userId),
		CreateAccount = true,
	}

	local response: HttpResponse? = post(url, headers, body)
	assert(response ~= nil, "Bad response")

	local responseData: { [string]: any } = response.data
	local sessionId: string = responseData.SessionTicket
	local playerId: string = responseData.PlayFabId

	return sessionId, playerId
end

function PlayFab.init(titleId: string, devSecretKey: string)
	assert(RunService:IsServer(), "PlayFab API can only be called on server")
	TITLE_ID = titleId
	DEV_SECRET_KEY = devSecretKey
	return nil
end

return PlayFab
