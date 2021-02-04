local util = require('serverUtil')
local settings = require('settings')

local interval, readFunc, dsname, tmrMode = ...

local function initFile(dsfilename)
    local key = util.loadSetup().key
    if not key then
        error('Device is not setup')
    end

    local fd = file.open(dsfilename, 'w+')
    fd:writeline('{\n    "key": "' .. key .. '",\n    "dataset": "' .. dsname .. '",\n    "readings": [\n')
    fd:close()
end


local function record(dsfilename, readFunc)
    if not file.exists(dsfilename) then
        initFile(dsfilename)
    end

    print('calling readfunc')
    local val, unit, error = readFunc()

    if not ((unit == nil) or (type(unit) == 'string')) then
        error('Unit must be nil or string')
    end

    local ts = rtctime.get()

    local fd = file.open(dsfilename, 'a+')
    fd:writeline(sjson.encode({ts = ts, u = unit, val = val}) .. ',')
    fd:close()
end


local function startUploadTimer()
    -- Only start the timer once
    if UploadTimer then return end;

    -- Send files that were here on startup
    node.LFS.sendRecordings()

    UploadTimer = tmr.create()
    UploadTimer:register(settings.uploadInterval, tmr.ALARM_AUTO,
        function()
            node.LFS.sendRecordings()
        end
    )
    UploadTimer:start()
end


local function registerReader()
    tmrMode = tmrMode or tmr.ALARM_AUTO
    local dsfilename = settings.dataFilePrefix .. dsname

    if type(readFunc) ~= 'function' then
        error('Parameter must be a function')
    end

    if not file.exists(dsfilename) then
        initFile(dsfilename)
    end

    --[[ startup upload timer before creating any new files
    (flush any existing files) ]]
    startUploadTimer()

    -- record now, and register to record later
    record(dsfilename, readFunc)

    local readTmr = tmr.create()
    readTmr:register(interval, tmrMode, function() record(dsfilename, readFunc) end)
    readTmr:start()

    return readTmr
end

return registerReader()