local HttpService = game:GetService("HttpService")
local packages = script.Parent
local promiseConstructor = require(packages:WaitForChild("Promise"))

local PlayFabSettings = {
    _internalSettings = {
        sdkVersionString = "RobloxSdk_undefined",
        buildIdentifier = "default_manual_build",
        requestGetParams = {["sdk"] = "RobloxSdk_undefined"}
    },
    settings = {
        titleId = nil,
        devSecretKey = nil,
        -- Probably don't need to edit
        productionUrl = ".playfabapi.com",
        verticalName = nil -- The name of a customer vertical. This is only for customers running a private cluster. Generally you shouldn't touch this
    }
}

function makePlayFabApiCall(path, requestBody, authKey, authValue, onSuccess)
	local fullUrl = "https://" .. PlayFabSettings.settings.titleId .. PlayFabSettings.settings.productionUrl .. path
	local getParams = PlayFabSettings._internalSettings.requestGetParams
	local firstParam = true
	for key, value in pairs(getParams) do
		if firstParam then
			fullUrl ..= "?"
			firstParam = false
		else
			fullUrl ..= "&"
		end

		fullUrl ..= key .. "=" .. value
	end

    local encodedBody = HttpService:JSONEncode(requestBody)
    local headers = {
        ["X-ReportErrorAsSuccess"] = "true",
        ["X-PlayFabSDK"] = PlayFabSettings._internalSettings.sdkVersionString,
        ["Content-Type"] = "application/json",
    }

    if authKey and authValue ~= "" and authValue then
        headers[authKey] = authValue
    end

    local success, response = pcall(HttpService.RequestAsync, HttpService, {
        Url = fullUrl,
        Method = "POST",
        Headers = headers,
        Body = encodedBody,
    })

    if success then
        if response.Success then
            local responseBody = HttpService:JSONDecode(response.Body)
            if responseBody and responseBody.code == 200 and responseBody.data then
                onSuccess(responseBody.data)
            end
        end
    else
		if response.Body then
			print(response, HttpService:JSONDecode(response.Body))
		else
			print(response)
		end
    end
end

local PlayFab = {}

function PlayFab:Fire(entityToken, request)
	task.spawn(function()
		local success, msg = function()
			makePlayFabApiCall("/Event/WriteEvents", request or {}, "X-EntityToken", entityToken)
		end
		if success then
			print("Success!")
		else
			warn("Failure: "..tostring(msg))
		end
	end)
end

function PlayFab:Register(player)
	repeat task.wait() until PlayFabSettings.settings.devSecretKey ~= nil
	local loginResult = makePlayFabApiCall("/Client/LoginWithCustomID", {
        CreateAccount = true, -- Create an account if one doesn't already exist
        CustomId = tostring(player.UserId) -- You can use your own CustomId scheme
    })

	local entityToken = loginResult.EntityToken.EntityToken
	local sessionTicket = loginResult.SessionTicket

	return entityToken, sessionTicket
end

function PlayFab.init(titleId, devSecretKey)
	PlayFabSettings.settings.titleId = titleId
	PlayFabSettings.settings.devSecretKey = devSecretKey
end

return PlayFab