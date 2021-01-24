local util = require("serverUtil")

StatusTimer = tmr.create()


local function setupConfirmed ()
    print('setup confirmed')
    node.restart()
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
            -- TODO: write key for recording data and ACK receipt
            StatusTimer:unregister()
            setupConfirmed()
        else
            StatusTimer:start()
        end

    else
        print("Status request error")
    end

end


local function writeSetup(setup)
    local fd = file.open('setup', 'w+')
    fd:writeline(util.encodeJson(setup))
    fd:close()
end


local function getStatus()
    local setup = util.loadSetup()
    if not setup.setupCode then return end

    -- don't request status if there's no wifi
    if wifi.sta.status() ~= wifi.STA_GOTIP then
        StatusTimer:start()
        return
    end

    http.post(
        'https://192.168.1.7:5001/RemoteDevices/setup-status',
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
    SetupCodeExpired = false
    local setup = util.decodeJson(setupString)
    setup.confirmed = false
    writeSetup(setup)
    startStatusChecks()
end


local function requestSetup(handler)
    --TODO: set NewCodeRequested for status
    --TODO: remove existing code, stop status checks if they'd continue on their own
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