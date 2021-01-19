local util = require("serverUtil")

local statusTimer = tmr.create()

local function setupConfirmed ()
    print('setup confirmed')
    node.restart()
end


local function handleStatus(data)
    print (data)
    local setup = util.decodeJson(data)
    if setup.confirmed == true then
        setupConfirmed()
        -- TODO: write key for recording data
        statusTimer:unregister()
    else
        statusTimer:start()
    end
end


local function writeSetup(setup)
    local fd = file.open('setup', 'w+')
    fd:writeline(util.encodeJson(setup))
    fd:close()
end


local function getStatus()
    local setup = util.loadSetup()
    if not setup.code then return end

    http.get(
        "https://192.168.1.7:5001/RemoteDevices/get-status",
        setup.code,
        function(code, data)
            if (code < 0) then
                print("Status request failed")
                statusTimer:start()
            elseif code == 404 then
                writeSetup({ code = nil, aesKey = nil, confirmed = false })
            else
                print(code, data)
                handleStatus(data)
            end
        end
    )
end


local function startStatusChecks()
    statusTimer:unregister()
    statusTimer:register(3500, tmr.ALARM_SEMI, getStatus)
end


local function handleSetupCode(setupString)
    writeSetup(util.decodeJson(setupString))
    startStatusChecks()
end


local function requestSetup(handler)
    http.get(
        "https://192.168.1.7:5001/RemoteDevices/get-setup-code",
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