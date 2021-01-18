local util = require('serverUtil')

local function writeResetFlag()
    file.open(resetFlag, "w+")
    file.close()
    
    local delFlagTmr = tmr.create()
    delFlagTmr:register(5000, tmr.ALARM_SINGLE, function()
        print("deleting setup trigger")
        file.remove("setupTrigger")
    end)
    delFlagTmr:start()
end

-- Restart in 5 minutes unless an AP client connects
local function registerFlagHandler()
        -- register 2 events:
        -- first, a timer to delete flag and restart in 5 mins
        local flagDelTmr = tmr.create()
        flagDelTmr.register(3 * 60 * 1000, tmr.ALARM_SINGLE, function()
            file.remove(resetFlag)
            node.restart()
        end)
        flagDelTmr.start()
        -- second, to cancel the timer if a user connects within 3 mins
        wifi.eventmon.register(wifi.eventmon.AP_STACONNECTED, function ()
            print('AP client connected')
            flagDelTmr:unregister()
        end)
end

-- reset flag filename
local resetFlag = 'resetFlag'

local externalReset = 6
local resetRaw, resetExtended = node.bootreason()
-- resetFlag exists if previous boot didn't last 5 seconds
-- indicating consecutive user restart
local setupTrigger = resetExtended == externalReset and file.exists(resetFlag)

if resetExtended == externalReset then
    writeResetFlag()
end

local setup = util.loadSetup()
if setup.confirmed then
    if not setupTrigger then
        -- TODO: start client
        print('start client')
    else
        LFS.server()
        registerFlagHandler()
    end
else
    LFS.server()
end