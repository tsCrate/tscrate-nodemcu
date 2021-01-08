-- make globals available to this module
----------------------------------------------------------------------
local M = {}
do
	local globaltbl = _G
	local newenv = setmetatable({}, {
		__index = function (t, k)
			local v = M[k]
			if v == nil then return globaltbl[k] end
			return v
		end,
		__newindex = M,
	})
	if setfenv then
		setfenv(1, newenv) -- for 5.1
	else
		_ENV = newenv -- for 5.2
	end
end


-- import any required modules here
----------------------------------------------------------------------
local ds18b20 = require('ds18b20')


-- io setup
----------------------------------------------------------------------
local sdapin = 2
local sclpin = 3
tsl2561.init(sdapin, sclpin)
local reading = tsl2561.getlux()

local gpio = 1
ds18b20.setup(gpio)


-- functions for reading from sensors
----------------------------------------------------------------------
-- read lux
local function readLux()
    -- get value
    local reading = tsl2561.getlux()

    return reading, 'lux'
end

ds18b20.read(nil, ds18b20.F)
local function readTemp1()
    --get time
    reading = ds18b20.read(nil, ds18b20.F)

    return reading, 'F'
end


-- table of sensor properties
-- add sensors to be read, including
--   name - sensors with the same name will be treated as the same sensor
--   readSensor - function to call which will return a reading and units
--   defaultInterval - read interval (milliseconds)
--   minimumInterval - minimum time between reads (milliseconds)
----------------------------------------------------------------------
sensors = {
    {
        name = 'lux1',
        readSensor = readLux,
        defaultInterval = 2000,
        minInterval = 2000
    },
    {
        name = 'temp1',
        readSensor = readTemp1,
        defaultInterval = 3300,
        minInterval = 3300
    }
}

-- return module
return M
