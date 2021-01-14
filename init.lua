if node.LFS.list() == nil and file.exists('lfs.img') then
    node.LFS.reload('lfs.img')
end

--[[
initTimer = tmr.create()
initTimer:register(1000, tmr.ALARM_SINGLE,
    function()
        local fi=node.LFS.get('_init');
        pcall(fi and fi'_init')
    end)
initTimer:start()
]]

node.LFS.get('_init')()

local server = require('server')
local util = require("serverUtil")
local statusTimer = tmr.create()

local function loadSetup()
    if file.open('setup', 'r') then
        local setupString = fd:readline()
        local setup = util.decodeJson(setupString)
        local setupCode = setup.code
        local aesKey = setup.aesKey
    end
end

local function handleStatus(statusString)
        print (statusString)
        if statusString == 'success' then
            statusTimer:unregister()
        else
            statusTimer:start()
        end
end

local function getStatus()
    http.get(
        "https://192.168.1.9:5001/RemoteDevices/get-status",
        'TODO: USE SETUP CODE',
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
    statusTimer.register( 3500, tmr.ALARM_SEMI, getStatus())
end

local function handleSetupCode(setupString)
    local fd = file.open('setup', 'w+')
    fd:writeline(setupString)
    fd:close()
    startStatusChecks()
end

local function requestSetup()
    http.get(
        "https://192.168.1.9:5001/RemoteDevices/get-setup-code",
        nil,
        function(code, data)
            if (code < 0) then
                print("Setup request failed")
                requestSetup(handleSetupCode)
            else
                print(code, data)
                handleSetupCode(data)
            end
        end
    )
end

local function startSetup()
    requestSetup()
end

wifi.sta.eventMonReg(wifi.STA_GOTIP, function ()
    -- TODO: if not setup, request setup, else start recording
    local setup = false
    if setup then
        -- TODO: start recording
    else
        startSetup()
    end
end)

server.createSetupServer()
