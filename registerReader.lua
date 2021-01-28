tslStatus = tsl2561.init(4, 5)
print('status is ok: ', tslStatus == tsl2561.TSL2561_OK)


function initFile(dsname)
    local key = getKey()
    local fd = file.open(dsname, 'w+')
    fd:writeline('{\n    "key": ' .. key .. ',\n    "dataset": ' .. dsname .. ',\n    "readings": [\n')
end


function write(dsname, readFunc)
end


function registerReader(interval, readFunc, dsname,tmrMode)
    tmrMode = tmrMode or tmr.ALARM_AUTO

    if not file.exists(dsname) then
        initFile(dsname)
    end

    write(dsname, readFunc)

    local readTmr = tmr.create()
    readTmr:register(interval, tmrMode, function() write(dsname, readFunc) end)
    return readTmr
end


function read()
    return tsl2561.getlux()
end

lightTmr = registerReader(2000, read(), 'lux')