local httpService = game:GetService("HttpService")
local runService = game:GetService("RunService")

local package = script.Parent
local packages = package.Parent

local fetchu = require(packages:WaitForChild("fetchu"))
local config = require(package:WaitForChild("Config"))


local debugMode = false
local PlayFab = {}

local titleId
local devSecretKey

function getURL(path)
	return "https://"..titleId..".playfabapi.com/"..path
end

function post(url, headers: table, body: table, attempt)
	attempt = attempt or 1
	local response

	local size = string.len(httpService:JSONEncode(body))
	if runService:IsStudio() then
		print("Firing "..body.EventName, "(", size, "):", body)
	end
	local httpService = game:GetService("HttpService")
	local success, msg = pcall(function()
		response = httpService:PostAsync(
			url,
			httpService:JSONEncode(body or {}),
			Enum.HttpContentType.ApplicationJson,
			false,
			headers
		)
	end)
	local responseTabl = httpService:JSONDecode(response or {})
	if success and responseTabl.code == 200 then
		return response
	elseif attempt < 15 then
		task.wait(1)
		return post(url, headers, body, attempt+1)
	else
		print(response, success, responseTabl)
		error("API call failed to "..url)
	end
	-- print("Response", responseTabl, response)
end

function apiFire(url, headers: table, body: table, attempt)
	if not attempt then attempt = 0 end

	local packet = {
		content_type = Enum.HttpContentType.ApplicationJson,
		headers = headers or {},
		body = body or {},
		compress = false,
	}

	if debugMode ~= true then
		local response

		local success, msg = pcall(function()
			response = httpService:JSONDecode(fetchu.post(url,packet))
		end)
		
		if success and response.code == 200 then
			return response
		elseif attempt < 15 then
			task.wait(1)
			return apiFire(url, headers, body, attempt)
		else
			print(response)
			error("API call failed to "..url)
		end
	end
end

function PlayFab:Fire(pId, eventName, data, tags, timeStamp)
	-- logger:Log("Firing to PlayFab: "..tostring(eventName).." for "..tostring(pId))
	while titleId == nil do task.wait() end
	task.spawn(function()
		local url = getURL("Server/WritePlayerEvent")
		local cleanHistory = {}
		local function clean(tabl)
			if cleanHistory[tabl] then return end
			cleanHistory[tabl] = true
			for k, v in pairs(tabl) do
				local finalK
				if type(k) == "string" then
					finalK = string.gsub(k, "/", "")
					tabl[finalK] = v
					tabl[k] = nil
				else
					finalK = k
				end
				if type(v) == "string" then
					tabl[finalK] = string.gsub(v, "/", "")
				elseif type(v) == "table" then
					tabl[finalK] = clean(v)
				end
			end
			return tabl
		end
		-- data = clean(data)
		post(url,
			{
				["X-SecretKey"] = devSecretKey,
			},
			{
				-- EventName = "Test",
				EventName = string.gsub(eventName, "/", ""),
				PlayFabId = pId,
				CustomTags = tags,
				Timestamp = timeStamp,
				Body = {
					Version = config.Version,
					State = data or {},
				}
			}
		)
	end)
end

function PlayFab:Register(userId)
	-- print("A")
	if not runService:IsServer() then return end
	-- print("B")
	while titleId == nil do print("WAITING FOR TITLE") task.wait() end
	-- print("C")
	local url = getURL("Client/LoginWithCustomID")
	local response
	-- print("Registering")
	response = apiFire(url,
		{
			["X-ReportErrorAsSuccess"] = "true",
			["X-PlayFabSDK"] = "RobloxSdk_undefined",
		},
		{
			TitleId = titleId,
			CustomId = tostring(userId),
			CreateAccount = true,
		}
	)
	-- print("Response", response)
	-- if debugMode then
	-- 	response = {
	-- 		data = {
	-- 				SessionTicket = httpService:GenerateGUID(false),
	-- 				PlayFabId = httpService:GenerateGUID(false)
	-- 		},
	-- 	}
	-- end
	local responseData = response.data
	local sessionId = responseData.SessionTicket
	local playerId = responseData.PlayFabId
	-- print("Returning", sessionId, playerId)
	return sessionId, playerId
end

function PlayFab.init(tId, dSK)
	titleId = tId
	devSecretKey = dSK
end

return PlayFab