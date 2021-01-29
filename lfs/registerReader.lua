local util = require('serverUtil')

local interval, readFunc, dsname, tmrMode = ...

local function initFile(dsname)
    local key = util.loadSetup().key
    if not key then
        error('Device is not setup to report')
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

    --TODO: check/set global HTTP request timer to send data

    return readTmr
end

return registerReader()