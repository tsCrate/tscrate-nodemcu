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

-- web clients connected to the AP
local clients = {}
-- moduleId, passphrase, etc.
local moduleSettings = {}
-- wifi and server info
local networkSettings = {}
-- offline mode settings
local offlineSettings = {}
-- buffer for messages from the Sensive server
local serverMsg = ""
-- AJAX status for saved settings
local saved = ""
-- status of server connection
local serverConnStatus = "No connection"

local util = require("serverUtil")

-- begin connecting to wifi
local function startStationWifi(msgTable)
    -- set wifi ssid and pwd on successful connection
    wifi.sta.eventMonReg(wifi.STA_IDLE, function() end)
    wifi.sta.eventMonReg(wifi.STA_CONNECTING, function() end)
    wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function()
    end)
    wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function()
    end)
    wifi.sta.eventMonReg(wifi.STA_FAIL, function()
    end)
    wifi.sta.eventMonReg(wifi.STA_GOTIP, function ()
        networkSettings.ssid = msgTable.ssid
        networkSettings.pwd = msgTable.pwd
    end)
    wifi.sta.eventMonStart()

    wifi.sta.config({ssid=msgTable.ssid, pwd=msgTable.pwd, auto=false, save=false})
    wifi.sta.connect()
end

local function saveOfflineSettings(msgTable)

    --interval is recorded as just the minute amount.  Conversions MUST be done --
    --properly for sleeping -- 
    offlineSettings['interval'] = msgTable['interval']
    offlineSettings['memory'] = msgTable['memory']
    offlineSettings['power'] = msgTable['power']
    offlineSettings['mode'] = "standalone"
    offlineSettings['time'] = msgTable['time']

    local encodedTable = util.encodeJson(offlineSettings)
    file.open("offlineSettings.config", "w+")
    file.write(encodedTable)
    file.close()

    file.open("mode", "w+")
    file.write("standalone")
    file.close()

    saved="Settings Saved"
end


-- handle server message
local function handleServerMsg(sock, msg)
    if msg.msgType == 'initReply' then
        -- set module settings
        moduleSettings['moduleId'] = msg['moduleId']
        moduleSettings['passphrase'] = msg['passphrase']
    elseif msg.msgType == 'moduleAssigned' then
        -- write module settings
        local encodedTable = util.encodeJson(moduleSettings)
        -- module settings
        local openFile = file.open("moduleSettings.config", "w+")
        openFile:write(encodedTable)
        openFile:close()
        -- network settings
        local encodedTable = util.encodeJson(networkSettings)
        file.open("networkSettings.config", "w+")
        file.write(encodedTable)
        file.close()
        -- mode setting
        file.open("mode", "w+")
        file.write("web")
        file.close()
        node.restart()
    elseif msg.msgType == 'serverTime' then
        -- construct sensor table without read funcs (funcs can't be encoded)
        local sensorReader = require('sensorReader')
        local sensorsWithoutFunc = {}
        for i,sensor in ipairs(sensorReader.sensors) do
            sensorsWithoutFunc[i] = {}
            sensorsWithoutFunc[i].name = sensor.name
            sensorsWithoutFunc[i].minInterval = sensor.minInterval
            sensorsWithoutFunc[i].defaultInterval = sensor.defaultInterval
        end
        sock:send(util.encodeJson({msgType = 'initRequest', sensors = sensorsWithoutFunc}).."\r\n\r\n")
    end
end


-- handle message from server
-- messages are not guaranteed to be complete or separate
local function receiveServerData(sock, data)
    -- append to string buffer
    serverMsg = serverMsg .. data

    -- while \r\n\r\n present, process messages
    while string.find(serverMsg, "\r\n\r\n") ~= nil do
        -- parse
        local modServerMsg, msg = util.parseServerMsg(serverMsg)
        serverMsg = modServerMsg
        -- handle if JSON valid
        if msg then
            handleServerMsg(sock, msg)
        end
    end
end


-- request initialization data from server
local function requestInit(msgTable)
    networkSettings.serverAddr = msgTable.serverAddr
    networkSettings.serverPort = msgTable.serverPort
    networkSettings.mode = 'web'

    sockToServer = net.createConnection(net.TCP, 0)
    sockToServer:on("connection", function(sock)
        -- Write settings to settings.config --
        serverConnStatus = "Connected"
    end)

    sockToServer:on("disconnection", function()
        serverConnStatus = "Disconnected"
    end)
    sockToServer:on("receive", receiveServerData)
    sockToServer:connect( tonumber(networkSettings['serverPort']), networkSettings['serverAddr'] )
end


-- remove client data to be garbage collected
local function closeClient(sock)

    sock:on("disconnection", function() end)
    sock:on("receive", function() end)
    sock:on("sent", function() end)
    clients[sock].rcvBuf = nil
    clients[sock].readStarted = nil

    if clients[sock].file then
        clients[sock].file:close()
        clients[sock].file = nil
    end
    pcall(function() sock:close() end)
    clients[sock] = nil
end


-- give browser an update on wifi / server conns
local function updateStatus(sock)
    local passphrase = moduleSettings['passphrase']
    if not passphrase then
        passphrase = "Unavailable - " .. serverConnStatus
    end
    local jsonStr = util.encodeJson({wifiStatusCode=wifi.sta.status(), passphraseStatus=passphrase, saveStatus=saved})
    -- send http ok with content-length because socket won't be closed
    sock:send("HTTP/1.1 200 OK\r\nCache-Control: no-store\r\nContent-Type: text/html\r\nContent-Length: "..#jsonStr.."\r\n\r\n"..jsonStr)
end


-- handle ajax requests from clients
local function handleAjax(sock)
    -- extract and remove msg from client buffer
    local msgTable = util.extractTable(clients, sock)
    -- connect to wifi, set server details, or provide WiFi status updates
    if msgTable then
        if msgTable.msgType == 'wifi' then
            startStationWifi(msgTable)
            sock:on("sent", function(s) closeClient(s) end)
            sock:send("HTTP/1.0 200 OK\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\nConnecting to WiFi")
        elseif msgTable.msgType == 'server' then
            sock:on("sent", function(s) closeClient(s) end)
            sock:send("HTTP/1.0 200 OK\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\nConnecting to server")
            requestInit(msgTable)
        elseif msgTable.msgType == 'offline' then
            saveOfflineSettings(msgTable)
            sock:on("sent", function(s) closeClient(s) end)
            sock:send("HTTP/1.0 200 OK\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\nSettings Saved")
            -- Restart module now 
			node.restart()
        elseif msgTable.msgType == 'statusRequest' then
            updateStatus(sock)
        elseif msgTable.msgType == 'exitSetup' then
            file.rename("backupMode", "mode")
            node.restart()
        end
    end
    -- wait for more data if table not present
end


-- continue sending requested resource or close conn
local function sendFile(sock)
    if clients[sock].file then
        local chunk = clients[sock].file:read(512)
        if chunk then
            sock:send(chunk)
        else
            closeClient(sock)
        end
    end
end


-- handle data receive from AP client
local function handleReceive(sock, data)
    -- buffer request
    clients[sock].rcvBuf = clients[sock].rcvBuf .. data
    -- check for at least one \r\n\r\n
    local k, l = string.find(clients[sock].rcvBuf, "\r\n\r\n")

    if k then
        -- parse resource
        local resource = util.parseResource(clients[sock].rcvBuf)

        if not resource then
            sock:on("sent", function(s) closeClient(s) end)
            sock:send("HTTP/1.0 404 Not Found\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\n<a href='"..wifi.ap.getip().."'>")
        end
        if resource == "" then resource = "index.htm" end

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
            clients[sock].readStarted = false
            sock:on("sent", function(s) sendFile(s) end)
            sock:send("HTTP/1.0 200 OK\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\n")
        end
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
    wifi.ap.dhcp.start()
    return srv
end

return M
