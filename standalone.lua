-- Record data offline directly to a modules local storage
-- Copywright Sensive

-- make globals available to this module
----------------------------------------------------------------------

-- get read settings
local sensorReader = require('sensorReader')
local clients = {}

local moduleSettingsPath = 'moduleSettings.config'
local overwriteCounter = 0;

    --getContentType["offlineRecordings.csv"] = "application/csv"

-- decode stringified JSON
local function decodeJson(encodedJson)
    local ok, decodedJson = pcall(cjson.decode, encodedJson)
    if ok then
        return (decodedJson)
    else
        print("Decoding failed: " .. encodedJson)
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
            return true, decodedTable
        else
            file.remove(moduleSettingsPath)
            return false
        end
    else
        return false
    end
end

-- parse page requested
local function parseResource(data)
    local i, j = string.find(data, "GET /")
    if not i then
        i, j = string.find(data, "POST /")
    elseif not i then
        -- not post or get
        return nil
    end
    local k, l = string.find(data, " HTTP")
    return string.sub(data, j+1, k-1)
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- extract json from a client's receive buffer
function extractTable(sock)
    -- check for delimiters
    local k, l = string.find(clients[sock].rcvBuf, "}\r\n\r\n")
    if k then
        local i, j = string.find(clients[sock].rcvBuf, "\r\n\r\n")
        local encJson = string.sub(clients[sock].rcvBuf, j+1, k)
        clients[sock].rcvBuf = ""
        --print("heap: "..node.heap()/1000)
        --print("gc: "..collectgarbage("count"))
        --print("clients: "..tablelength(clients))
        return decodeJson(encJson)
    end
    -- else return nil
    return nil
end

local function closeClient(sock)
    sock:on("disconnection", function() end)
    sock:on("receive", function() end)
    sock:on("sent", function() end)
    clients[sock].rcvBuf = nil
    clients[sock].requestFile = nil
    clients[sock].readStarted = nil

    if clients[sock].file then
        clients[sock].file:close()
        clients[sock].file = nil
    end
    pcall(function() sock:close() end)
    clients[sock] = nil
end

function handleAjax(sock)
    -- extract and remove msg from client buffer
    local msgTable = extractTable(sock)
    if msgTable then
        if msgTable.msgType == 'reset' then
            file.remove("offlineSettings.config")
            sock:send("HTTP/1.0 200 OK\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\nModule reset")
            sock:on("sent", function(s) closeClient(s) end)

        end

    -- else wait for more data
    else
        return
    end
end

local function sendFile(sock)
-- continue sending requested resource or close conn
    if clients[sock].file then
        local chunk = clients[sock].file:read(512)
        if chunk then
            sock:send(chunk)
        else
            closeClient(sock)
        end
    end
end

-- handle data receive from server
local function handleReceive(sock, data)
    -- buffer request
    clients[sock].rcvBuf = clients[sock].rcvBuf .. data
    -- check for at least one \r\n\r\n
    local k, l = string.find(clients[sock].rcvBuf, "\r\n\r\n")

    if k then
        -- parse resource
        local resource = parseResource(clients[sock].rcvBuf)

        if not resource then
            sock:on("sent", function(s) closeClient(s) end)
            sock:send("HTTP/1.0 404 Not Found\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\n<a href='"..wifi.ap.getip().."'>")
        
		end
				
        if resource == "" then resource = "offlineIndex.htm" end
		
        -- begin sending resource if available
        if resource == "ajaxReq" then
            handleAjax(sock)
        else
            clients[sock].file = file.open(resource)
            if not clients[sock].file then
                sock:on("sent", function(s) closeClient(s) end)
                sock:send("HTTP/1.0 404 Not Found\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\n<a href='"..wifi.ap.getip().."'>")
                return
            end
			
			if resource == "offlineRecordings.csv" then
			    clients[sock].readStarted = false
				sock:on("sent", function(s) sendFile(s) end)
				sock:send("HTTP/1.0 200 OK\r\nCache-Control: no-store\r\nContent-Type: csv/text\r\nContent-Disposition: attachment\r\n\r\n")
			end
			
			
            clients[sock].readStarted = false
            sock:on("sent", function(s) sendFile(s) end)
            sock:send("HTTP/1.0 200 OK\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\n")
        end
    end
end

local function handleSent(sock)
    -- if reading file, start/continue
    if clients[sock].requestFile == true then
        sendFile(sock)
    -- else not reading file - ajax call
    else
        -- TODO determine why additional clients causes memory leak
        --closeClient(sock)
    end
end


-- handle new client connection
local function handleConn(newSock)

    clients[newSock] = {}
    clients[newSock].rcvBuf= ""
    newSock:on("disconnection", function(sock, err)

        print('client disconn')
        closeClient(sock)
    end)
    newSock:on("receive", handleReceive)
end

-- setup server and enter AP mode
function createSetupServer()
    local srv=net.createServer(net.TCP)
    srv:listen(80, handleConn)

    -- configure wifi
    wifi.eventmon.register(wifi.eventmon.AP_STADISCONNECTED, function() print("Dropped AP client") end)
    wifi.setmode(wifi.STATIONAP, false);
    wifi.ap.config({ssid="Sensive".. tostring(node.chipid()), pwd="12345678", auth=wifi.WPA2_PSK, save=false, beacon=100})
    return srv
end


-- check for settings file and attempt to decode
local function getModuleSettings()
    if file.exists(moduleSettingsPath) then
        file.open(moduleSettingsPath, "r")
        moduleSettingsjSON = file.readline()
        file.close()
        local ok, decodedTable = pcall(cjson.decode, moduleSettingsjSON)
        if ok then
            return true, decodedTable
        else
            file.remove(moduleSettingsPath)
            return false
        end
    else
        return false
    end
end

-- Store settings read from a file or server
local moduleSettings = {}
-- file to check for settings

-- function called on a timer
local function writeData(i, sensor, memory)

    --get time
    local sec, us = rtctime.get()
    local reading, unit = sensor.readSensor()

    if reading == nil then
        return
    end

    local msg = {
        msgType = 'data',
        utcOffset = utcOffset,
        unixMs = sec * 1000 + us / 1000,
        value = reading,
        sensor = sensor['name'],
        units = unit,
        battery = nil,
        status = 'ok',
        errorMsg = nil
    }

    -- if file exists, header is there, just write line
    if (file.open("offlineRecordings.csv")) then
        for k,v in pairs(file.list()) do 
            l = string.format("%-15s",k)  
            if l == "offlineRecordings.csv" and v >= 2048000 then
                print(l.."   "..v.." bytes")
                print("overwriting line")
                -- Module is near full, stop recording
                if memory == "overwrite" then
                    file.open("offlineRecordings.csv", "w")
                    counter = 0
                    while true do
                        line = file.readline
                        if counter == overwriteCounter then
                            print("Writing: " .. i..","..msg.unixMs..","..msg.value..","..msg.units)
                            file.writeline(i..","..msg.unixMs..","..msg.value..","..msg.units, "\n")
                            file.close()
                        end
                        counter = counter + 1
                    end
                    overwriteCounter = overwriteCounter + 1
                    return
                elseif memory == "stop" then
                    return
                end
            end
        end

        file.open("offlineRecordings.csv", "a")
        print("Writing: " .. i..","..msg.unixMs..","..msg.value..","..msg.units)
        file.writeline(i..","..msg.unixMs..","..msg.value..","..msg.units, "\n")
        file.close()

    -- write header
    else
        file.open("offlineRecordings.csv", "a")
        --print("Creating offlineRecordings.csv")
        moduleSettings = getModuleSettings

        if(moduleSettings == {}) then
            file.writeline(moduleSettings[moduleId].."=="..moduleSettings[passphrase], "\n")
        else
            file.writeline("==", "\n")
        end

        file.close()
    end

end

local function beginWriting(recordingInterval, batteryMode, memory)
    for i,sensor in ipairs(sensorReader.sensors) do
        --print(sensor.name)

        -- register timer event
        tmr.register(i-1, recordingInterval*60000, tmr.ALARM_AUTO, function () 
            writeData(i, sensor, memory)

            if(batteryMode == "sleep") then
                -- Go into deep sleep
                rtctime.dsleep(60*1000000*recordingInterval)
            end

        end)

        tmr.start(0)
    end
end

function recordData(recordingInterval, batteryMode, memory)

    createSetupServer()

    -- start writing in a loop.  It needs all 3 variables.
    beginWriting(recordingInterval, batteryMode, memory)

end

file.open("offlineSettings.config")
local settingsEncodedJson = file.readline()
file.close()
local decodedJson = decodeJson(settingsEncodedJson)
rtctime.set(decodedJson["time"]/1000, 0)

recordData(decodedJson["interval"], decodedJson["power"], decodedJson["memory"])
