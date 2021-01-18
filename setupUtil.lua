local util = require("serverUtil")

local STATE = {
    NO_CODE = 0,
    UNCONFIRMED_CODE = 1,
    CONFIRMED_CODE = 2
}

local statusTimer = tmr.create()

local function setupConfirmed ()
end

local function handleStatus(data)
        print (data)
        local status = util.decodeJson(data)
        if status.complete == true then
            setupConfirmed()
            statusTimer:unregister()
        else
            statusTimer:start()
        end
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
    local setup = util.decodeJson(setupString)
    setupString = util.encodeJson(setup)

    local fd = file.open('setup', 'w+')
    fd:writeline(setupString)
    fd:close()

    SetupState = STATE.UNCONFIRMED_CODE
    startStatusChecks()
end

local function requestSetup()
    http.get(
        "https://192.168.1.7:5001/RemoteDevices/get-setup-code",
        nil,
        function(code, data)
            if (code < 0) then
                -- TODO: notify client of failed request
                print("Setup request failed")
            else
                print(code, data)
                handleSetupCode(data)
            end
        end
    )
end

return {
    requestSetup = requestSetup,
    startStatusChecks = startStatusChecks
}