local util = require('serverUtil')

-- reset flag filename
-- TODO: move to settings
local resetFlag = 'resetFlag'

local function writeResetFlag()
    file.open(resetFlag, "w+")
    file.close()

    local delFlagTmr = tmr.create()
    delFlagTmr:register(5000, tmr.ALARM_SINGLE, function()
        file.remove(resetFlag)
    end)
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
    if setup.confirmed and setup.key then
        if not setupTrigger then
            print('Client mode. Reporting to the server.')
            LFS.startClient()
        else
            print('Reconfigure mode. Restarts in 3 minutes if no user connects to the access point.')
            LFS.startServer()
            registerFlagHandler()
        end
    else
        print('Setup mode. Connect to the device to configure Wi-Fi and get a setup code.')
        LFS.startServer()
    end
end

startup()