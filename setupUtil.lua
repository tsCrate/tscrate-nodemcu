local util = require("serverUtil")
local settings = require("settings")

Queue = {}
RequestInFlight = false
StatusTimer = tmr.create()


local function writeSetup(setup)
    local fd = file.open('setup', 'w+')
    fd:writeline(util.encodeJson(setup))
    fd:close()
end


local function processQueue()
    if not RequestInFlight then
        local callback = table.remove(Queue, 1)
        if callback then callback() end
    end
end

local function request(url, method, headers, body, callback)
    table.insert(
        Queue,
        function()
            http.request(
                "GET /RemoteDevices/test HTTP/1.1\r\nHost: 192.168.1.7\r\nConnection: keep-alive\r\nAccept: application/json\r\n\r\n" ,
                method,
                headers,
                body,
                function(code, data)
                    callback(code, data)
                    RequestInFlight = false
                    processQueue()
                end
            )
            RequestInFlight = true
        end
    )
    processQueue()
end

local function post(url, headers, body, callback)
    request(url, "POST", headers, body, callback)
end

local function get(url, headers, callback)
    request(url, "GET", headers, nil, callback)
end

local function setupLinked (status)
    writeSetup(status)

    post(
        settings.serverAddr .. '/RemoteDevices/finish-setup',
        'Content-Type: application/json\r\n',
        util.encodeJson({ setupCode = status.setupCode }),
        function () node.restart() end
    )
end


local function handleStatus(code, data)
    print (code, data)

    if (code < 0) then
        -- TODO add status request failed to device statuses
        print("Status request failed")
        StatusTimer:start()

    elseif code >= 400 and code < 500 then
        if code == 410 then
            SetupCodeExpired = true
        else
            print("Bad status request")
        end

    elseif code >= 200 and code < 300 then
        local status = util.decodeJson(data)
        if status and status.confirmed == true then
            StatusTimer:unregister()
            setupLinked(status)
        else
            StatusTimer:start()
        end

    else
        print("Status request error")
    end

end


local function getStatus()
    print('in get status')
    local setup = util.loadSetup()
    if not setup.setupCode then return end

    -- don't request status if there's no wifi
    if wifi.sta.status() ~= wifi.STA_GOTIP then
        StatusTimer:start()
        return
    end

    post(
        settings.serverAddr .. '/RemoteDevices/setup-status',
        'Content-Type: application/json\r\n',
        util.encodeJson({ setupCode = setup.setupCode }),
        handleStatus
    )
end


local function startStatusChecks()
    StatusTimer:unregister()
    StatusTimer:register(3500, tmr.ALARM_SEMI, getStatus)
    StatusTimer:start()
end


local function handleSetupCode(setupString)
    print('in handle setup')
    print('setup string: ' .. setupString)
    SetupCodeExpired = false
    SetupCodeRequested = false

    local setup = util.decodeJson(setupString)
    setup.confirmed = false
    writeSetup(setup)
    startStatusChecks()
end


local function requestSetup(handler)
    print ('in get req setup')
    StatusTimer:unregister()
    file.remove('setup')
    SetupCodeRequested = true

    get(
        settings.serverAddr .. "/RemoteDevices/get-setup-code",
        nil,
        function(code, data)
            if (code < 0) then
                handler(code, data)
            else
                print(code, data)
                handleSetupCode(data)
                handler(code, data)
            end
        end
    )
end


return {
    requestSetup = requestSetup,
    startStatusChecks = startStatusChecks
}