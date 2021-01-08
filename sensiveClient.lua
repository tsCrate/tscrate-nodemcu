-- Connect to a server and send readings based on the sensorReader module

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

local sensorReader = require('sensorReader')
local cjsonNull = cjson.decode('null');

-- Receive buffer
local serverMsg = ""
-- Store settings read from a file or server
local moduleSettings = {}
-- file to check for settings
local moduleSettingsPath = 'moduleSettings.config'
-- Connection settings to the server
local connectionSettings = {}

-- socket for the server
-- initiate comms with connectToServer()
local sockToServer = nil
local dataQueue = {}

-- last time clock was set
local lastSet = 0

local function sendTableAsJson(table)
    if pcall(function () jsonMsg = cjson.encode(table) .. '\r\n\r\n' end) then
        -- TODO handle socket not connected - remove timer not guaranteed to catch
        if not pcall(function () sockToServer:send(jsonMsg) end) then
            print('Failed Send')
        end
    else
    end
end

local function processQueue()
    if table.getn(dataQueue) > 0 then
        sendTableAsJson(table.remove(dataQueue, 1))
    end
end

-- process messages - either queue or send
local function processMsg(msgTbl)
    sockToServer:on("sent", function (sock, c)
        processQueue()
    end)

    -- Buffer data and implement send event loop- sequential sends (timed) not guaranteed to succeed
    if table.getn(dataQueue) > 0 then
        table.insert(dataQueue, msgTbl)
    else
        sendTableAsJson(msgTbl)
    end
end

-- function called on a timer
local function sendData(sensor)
    --get time
    local sec, us = rtctime.get()
    local reading, unit = sensor.readSensor()

    if reading == nil or reading == '' then
        return
    end

    local msg = {
        msgType = 'data',
        moduleId = moduleSettings['moduleId'],
        passphrase = moduleSettings['passphrase'],
        unixMs = sec * 1000 + us / 1000,
        value = reading,
        sensor = sensor['name'],
        units = unit,
        battery = nil,
        status = 'ok',
        errorMsg = nil
    }

    processMsg(msg)
end

-- stop sending
local function stopSending()
    for i,sensor in ipairs(sensorReader.sensors) do
        -- unregister timer event
        tmr.unregister(i-1)
    end
end

-- server connection established; being sending data per read settings
local function beginSending(sendNow)
    for i,sensor in ipairs(sensorReader.sensors) do
        if sendNow then
            sendData(sensor)
        end
        -- register timer event; sensors are in the same order in moduleSettings and sensorReader
        tmr.register(i-1, moduleSettings.sensors[i].interval, tmr.ALARM_AUTO, function () 
            sendData(sensor)
        end)
        tmr.start(i-1)
    end
end

local function connectedToServer(sock, c)
    print("connected to server")
end

local function reconnectedToServer(sock, c)
    print("reconnected to server")
end

-- check for complete json strings; store incomplete strings
local function parseMsg()
    -- find separator
    local i, j = string.find(serverMsg, "\r\n\r\n")

    -- remove first message from buffer
    local msg = string.sub(serverMsg, 1, i-1)
    serverMsg = string.sub(serverMsg, j+1)

    if pcall(function () jsonMsg = cjson.decode(msg) end) then
        return true, jsonMsg
    -- parse failed, store message and wait for the rest
    else
        print('invalid json')
        return false, {}
    end
end

-- check for settings file and attempt to decode
local function getModuleSettings()
    if file.exists(moduleSettingsPath) then
        file.open(moduleSettingsPath, "r")
        moduleSettingsjSON = file.readline()
        file.close()
        local ok, decodedTable = pcall(cjson.decode, moduleSettingsjSON)
        if ok then
            -- write sensors array if it's not available
            if not decodedTable.sensors then
                -- construct sensor table without read funcs (funcs can't be encoded)
                local sensorsWithoutFunc = {}
                for i,sensor in ipairs(sensorReader.sensors) do
                    sensorsWithoutFunc[i] = {}
                    sensorsWithoutFunc[i].name = sensor.name
                    sensorsWithoutFunc[i].interval = sensor.defaultInterval
                    sensorsWithoutFunc[i].minInterval = sensor.minInterval
                end
                decodedTable.sensors = sensorsWithoutFunc
                encodedTable = cjson.encode(decodedTable)
                local openFile = file.open("moduleSettings.config", "w+")
                openFile:write(encodedTable)
                openFile:close()
            end
                return true, decodedTable
        else
            --file.remove(moduleSettingsPath)
            return false
        end
    else
        return false
    end
end

-- handle serverTime message
local function handleServerTime(msg)
    rtctime.set(msg['unixMs'] / 1000)
    lastSet = rtctime.get()

    -- if good module settings from file, begin transmitting data
    local settingsAvailable, currentSettings = getModuleSettings()
    if settingsAvailable then
        --print('Settings read: ' .. cjson.encode(currentSettings))
        moduleSettings = currentSettings
        beginSending(true)
    else
        node.restart()
    end
end

-- server data ACK; contains any settings updates from user
local function handleDataReply(msg)
    --print('data reply received: ' .. cjson.encode(msg))
    if (msg.unixMs/1000 - lastSet > 300) then
        rtctime.set(msg['unixMs'] / 1000)
        lastSet = rtctime.get()
    end
    if msg.updates ~= cjsonNull and msg.updates ~= nil then
        -- apply updates to sensors by name
        for i,sensor in ipairs(moduleSettings.sensors) do
            for j,update in ipairs(msg.updates) do
                if update.name == sensor.name and (update.intervalMs ~= cjsonNull and update.intervalMs ~= nil) then
                    -- write and apply settings settings
                    moduleSettings.sensors[i].interval = update.intervalMs
                    stopSending()
                    beginSending(false)
                    local settingsFile = file.open("moduleSettings.config", "w+")
                    settingsFile:write(cjson.encode(moduleSettings))
                    settingsFile:close()
                end
            end
        end
    end
    msg.updates = nil
end

-- server stop message; module should no longer connect or send to server
--local function handleStop(msg)
    --print('stop received')
--end

-- settings update from server; modify accordingly
local function handleSettings(msg)
    print('settings received')
end

-- received server ACK of settings update; no need to resend
--local function handleSettingsReply(msg)
    --print('settings reply received')
--end

-- handle parsed messages
local msgHandlers = {
    --initReply = handleInitReply,
    dataReply = handleDataReply,
    --stop = handleStop,
    settings = handleSettings,
    --settingsReply = handleSettingsReply,
    --moduleAssigned = handleModuleAssigned,
    serverTime = handleServerTime
}

-- select appropriate message handler
local function handleMsg(msg)
    msgHandlers[msg['msgType']](msg)
end

-- handle message from server
-- messages are not guaranteed to be complete or separate
local function receive(sock, c)
    --print('received: ' .. c)

    -- append to string buffer
    serverMsg = serverMsg .. c

    -- while \r\n\r\n present, process messages
    while string.find(serverMsg, "\r\n\r\n") ~= nil do
        -- parse
        local ok, msg = parseMsg()
        -- handle if JSON valid
        if ok then
            handleMsg(msg)
        end
    end
end

local function disconnectedFromServer(sock, c)
    serverMsg = ""
    stopSending()
    print("disconnected from server")
    if wifi.sta.getip() then
        sockToServer = net.createConnection(net.TCP, 0)
        sockToServer:on("connection", connectedToServer)
        sockToServer:on("disconnection", disconnectedFromServer)
        sockToServer:on("receive", receive)
        sockToServer:connect(connectionSettings['serverPort'], connectionSettings['serverDomain'])
    end
end

-- connected to WiFi - open socket to server
local function gotIp(prevStat)
    print("STATION_GOT_IP" .. wifi.sta.getip())

    -- open connection to server
    sockToServer = net.createConnection(net.TCP, 0)
    sockToServer:on("connection", connectedToServer)
    sockToServer:on("disconnection", disconnectedFromServer)
    sockToServer:on("receive", receive)
    sockToServer:connect(connectionSettings['serverPort'], connectionSettings['serverDomain'])
end

-- connect to wifi and server, and begin comms loop
function connectToServer(ssid, pwd, domain, port)
    -- store settings
    connectionSettings['wifiSsid'] = ssid
    connectionSettings['wifiPwd'] = pwd
    connectionSettings['serverDomain'] = domain
    connectionSettings['serverPort'] = port
    wifi.sta.config({ssid=connectionSettings['wifiSsid'], pwd=connectionSettings['wifiPwd'], auto=false})

    -- Setup wifi event handling
    wifi.sta.eventMonReg(wifi.STA_IDLE, function() print("STATION_IDLE") end)
    wifi.sta.eventMonReg(wifi.STA_CONNECTING, function() print("STATION_CONNECTING") end)
    wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function() print("STATION_WRONG_PASSWORD") end)
    wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function() print("STATION_NO_AP_FOUND") end)
    wifi.sta.eventMonReg(wifi.STA_FAIL, function()
        print("STATION_CONNECT_FAIL")
        node.restart()
    end)
    wifi.sta.eventMonReg(wifi.STA_GOTIP, function ()
        print("WiFi connected: " .. wifi.sta.getip())
        gotIp()
    end)
    
    -- connect to wifi
    wifi.sta.eventMonStart()
    wifi.setmode(wifi.STATION, true)
    wifi.sta.connect()
end

-- disconnect the global sock var
local function closeConn()
    for i,sensor in ipairs(moduleSettings.sensors) do
        tmr.unregister(i)
    end
    sockToServer:close()
end

-- return module
return M
