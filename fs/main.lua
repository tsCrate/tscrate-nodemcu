-- Example main.lua file for tsCrate

-- Values will be recorded to a dataset with this name on tsCrate.com.
-- If the dataset doesn't exist, it will be created.
local datasetName = 'Light'

-- Sensor-specific read functions are registered with the tsCrate LFS
-- registerReader function. These functions should return a numeric
-- value, a unit string, and nil or and error string if an error occurred.
local function readFunc()
    local val, err = tsl2561.getlux()

    local errMsg = nil
    if err ~= tsl2561.TSL2561_OK then
        errMsg = 'TSL error: ' .. err
    end

    return val, 'lux', errMsg
end

-- Sensor-specific initialization
local tslOk = tsl2561.init(4, 5) == tsl2561.TSL2561_OK
print('tsl2561 status is ok: ', tslOk)

-- Read interval in milliseconds
local interval = 30000

-- Register the read function. We'll take it from here.
LFS.registerReader(interval, readFunc, datasetName)