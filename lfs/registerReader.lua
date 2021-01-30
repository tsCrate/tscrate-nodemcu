local util = require('serverUtil')
local settings = require('settings')

local interval, readFunc, dsname, tmrMode = ...

local function initFile(dsname)
    -- TODO: prepend 'dataset_' to the filename
    local key = util.loadSetup().key
    if not key then
        error('Device is not setup')
    end

    local fd = file.open(dsname, 'w+')
    fd:writeline('{\n    "key": ' .. key .. ',\n    "dataset": ' .. dsname .. ',\n    "readings": [\n')
    fd:close()
end


local function record(dsname, readFunc)
    if not file.exists(dsname) then
        initFile(dsname)
    end

    local val, unit, error = readFunc()

    if not ((unit == nil) or (type(unit) == 'string')) then
        error('Unit must be nil or string')
    end

    local ts = rtctime.get()

    local fd = file.open(dsname, 'a+')
    fd:writeline(sjson.encode({ts = ts, u = unit, val = val}) .. ',')
    fd:close()
end


local function registerDataSet(dsname)
    --[[
    if HttpTimer then return end;

    HttpTimer = tmr.create()
    HttpTimer:register(settings.httpTimerInterval, tmr.ALARM_AUTO,
        function()
            node.LFS.sendRecordings(dsname)
        end
    )
    HttpTimer:start()
    ]]
end


local function registerReader()
    tmrMode = tmrMode or tmr.ALARM_AUTO

    if type(readFunc) ~= 'function' then
        error('Parameter must be a function')
    end

    if not file.exists(dsname) then
        initFile(dsname)
    end

    -- record now, and register to record later
    record(dsname, readFunc)

    local readTmr = tmr.create()
    readTmr:register(interval, tmrMode, function() record(dsname, readFunc) end)
    readTmr:start()

    registerDataSet(dsname)
    return readTmr
end

return registerReader()