local settings = require('settings')
-- initialize global vars
dofile('global.lua')
local util = require('serverUtil')

-- reset flag filename
-- TODO: move to settings
local resetFlag = 'resetFlag'

local function writeResetFlag()
    file.open(resetFlag, "w+")
    file.close()

    local delFlagTmr = tmr.create()
    delFlagTmr:register(5000, tmr.ALARM_SINGLE,
        function()
            file.remove(resetFlag)
        end
    )
    delFlagTmr:start()
end

-- Restart in 5 minutes unless an AP client connects
local function registerFlagHandler()
    -- register 2 events:
    -- first, a timer to delete flag and restart in 5 mins
    -- second, cancel the timer if a user connects within 3 mins
    local flagDelTmr = tmr.create()
    flagDelTmr:register(3 * 60 * 1000, tmr.ALARM_SINGLE, function()
        file.remove(resetFlag)
        node.restart()
    end)

    flagDelTmr:start()
    wifi.eventmon.register(wifi.eventmon.AP_STACONNECTED, function ()
        flagDelTmr:unregister()
    end)
end


local function startup()
    local externalReset = 6
    local resetRaw, resetExtended = node.bootreason()

    -- resetFlag exists if previous boot didn't last 5 seconds indicating consecutive user restart
    local setupTrigger = resetExtended == externalReset and file.exists(resetFlag)
    if resetExtended == externalReset then
        writeResetFlag()
    else
        file.remove(resetFlag)
    end


    local setup = util.loadSetup()
    -- Limit the number of data files to something processable
    LFS.queueFiles()
    local filesCapped = LFS.queuedFileCount() >= settings.maxFileCount

    local startClient = setup.confirmed and setup.key and not setupTrigger and not filesCapped
    local startRecoveryClient = setup.confirmed and setup.key and not setupTrigger and filesCapped
    local startReconfig = setup.confirmed and setup.key and setupTrigger
    local startSetup = not setup.confirmed or not setup.key

    if startClient then
        print('Client mode. Reporting to the server.')
        LFS.startClient()
    elseif startRecoveryClient then
        print('Data file cap reached. Attempting to upload before recording more.')
        LFS.startRecoveryClient()
    elseif startReconfig then
        print('Reconfigure mode. Restarts in 3 minutes if no user connects to the access point.')
        LFS.startServer()
        registerFlagHandler()
    elseif startSetup then
        print('Setup mode. Connect to the device to configure Wi-Fi and get a setup code.')
        LFS.startServer()
    else
        print('Setup mode. Connect to the device to configure Wi-Fi and get a setup code.')
        LFS.startServer()
    end
end

startup()