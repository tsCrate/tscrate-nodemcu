-- Sensor-specific read function
local function read()
    local val, err = tsl2561.getlux()

    local errMsg = nil
    if err ~= tsl2561.TSL2561_OK then
        errMsg = err
    end

    return val, 'lux', errMsg
end

-- Sensor-specific initialization
local tslOk = tsl2561.init(4, 5) == tsl2561.TSL2561_OK

print('tls2561 status is ok: ', tslOk)

-- Register the read function. We'll take it from here.
node.LFS.registerReader(2000, read, 'tslData')