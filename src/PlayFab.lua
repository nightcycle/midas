local httpService = game:GetService("HttpService")
local runService = game:GetService("RunService")
local packages = script.Parent.Parent
local fetchu = require(packages:WaitForChild("fetchu"))

local PlayFab = {}

local titleId
local devSecretKey

function PlayFab:Fire(playerId, eventName, body)
    local function httpEvent(attempt)
        if not attempt then attempt = 0 end
        local url = "https://"..titleId..".playfabapi.com/Server/WritePlayerEvent"

        local response
        print(playerId, eventName, body)
        local success, msg = pcall(function()
            response = fetchu.post(url,
            {
                content_type = Enum.HttpContentType.ApplicationJson,
                headers = {
                    ["X-SecretKey"] = devSecretKey,
                },
                body = {
                    EventName = eventName,
                    PlayFabId = playerId,
                    Body = body,
                },
                compress = false,
            })
        end)
        response = httpService:JSONDecode(response)
        if success and response.code == 200 then
            return response.data.EventId
        elseif attempt < 10 then
            task.wait(1)
            return httpEvent(attempt + 1)
        else
            print(response)
            error("Couldn't send event")
        end
    end
	task.spawn(httpEvent)
end

function PlayFab:Register(id)
    if runService:IsClient() then return end
    while titleId == nil do task.wait() end

    local function httpRegister(attempt)
        if not attempt then attempt = 0 end
        local url = "https://"..titleId..".playfabapi.com/Client/LoginWithCustomID"

        local response
        local success, msg = pcall(function()
            response = fetchu.post(url,
            {
                content_type = Enum.HttpContentType.ApplicationJson,
                headers = {
                    ["X-ReportErrorAsSuccess"] = "true",
                    ["X-PlayFabSDK"] = "RobloxSdk_undefined",
                },
                body = {
                    TitleId = titleId,
                    CustomId = tostring(id),
                    CreateAccount = true,
                },
                compress = false,
            })
        end)
        response = httpService:JSONDecode(response)
        if success and response.code == 200 then
            local data = response.data
            local sID = data.SessionTicket
            local pID = data.PlayFabId
            return sID, pID
        elseif attempt < 10 then
            task.wait(1)
            return httpRegister(attempt + 1)
        else
            error("Couldn't retrieve entity token for "..tostring(id))
        end
    end

    local sessionId, playerId = httpRegister()
    return sessionId, playerId
end

function PlayFab.init(tId, dSK)
	titleId = tId
	devSecretKey = dSK
end

return PlayFab