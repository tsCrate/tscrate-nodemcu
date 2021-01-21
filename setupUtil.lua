local util = require("serverUtil")

StatusTimer = tmr.create()


local function setupConfirmed ()
    print('setup confirmed')
    node.restart()
end


local function handleStatus(data)
    print (data)
    local status = util.decodeJson(data)
    if status and status.confirmed == true then
        -- TODO: write key for recording data and ACK receipt
        StatusTimer:unregister()
        setupConfirmed()
    else
        StatusTimer:start()
    end
end


local function writeSetup(setup)
    local fd = file.open('setup', 'w+')
    fd:writeline(util.encodeJson(setup))
    fd:close()
end


local function getStatus()
    print('in get status')
    local setup = util.loadSetup()
    if not setup.setupCode then return end

    http.post(
        'https://192.168.1.7:5001/RemoteDevices/setup-status',
        'Content-Type: text/plain\r\n',
        setup.setupCode,
        function(code, data)
            print (code, data)
            if (code < 0) then
                print("Status request failed")
                StatusTimer:start()
            elseif code > 400 and code < 500 then
                print("Bad status request, possibly expired code")
                writeSetup({ setupCode = nil, aesKey = nil, confirmed = false })
            elseif code > 200 and code < 300 then
                handleStatus(data)
            else
                print("Status request error")
            end
        end
    )
end


local function startStatusChecks()
    print('starting status checks')

    StatusTimer:unregister()
    StatusTimer:register(3500, tmr.ALARM_SEMI, function () print('firing') getStatus() end)
    StatusTimer:start()
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