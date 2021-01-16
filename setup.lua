function loadSetup()
    if file.open('setup', 'r') then
        local setupString = file.readline()
        file.close()
        return util.decodeJson(setupString)
    else
        return nil
    end
end

function handleStatus(statusString)
        print (statusString)
        if statusString == 'success' then
            statusTimer:unregister()
        else
            statusTimer:start()
        end
end

function getStatus()
    local setup = loadSetup()

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

function startStatusChecks()
    statusTimer:register(3500, tmr.ALARM_SEMI, getStatus)
end

function handleSetupCode(setupString)
    local setup = util.decodeJson(setupString)
    setup.complete = false
    setupString = util.encodeJson(setup)

    local fd = file.open('setup', 'w+')
    fd:writeline(setupString)
    fd:close()

    startStatusChecks()
end

function requestSetup()
    http.get(
        "https://192.168.1.7:5001/RemoteDevices/get-setup-code",
        nil,
        function(code, data)
            if (code < 0) then
                -- TODO: set status
                print("Setup request failed")
                requestSetup(handleSetupCode)
            else
                print(code, data)
                handleSetupCode(data)
            end
        end
    )
end

