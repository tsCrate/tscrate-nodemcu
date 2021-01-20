SetupRequestFailed = false
local setupUtil = require('setupUtil')

-- web clients connected to the AP
local clients = {}
-- moduleId, passphrase, etc.
local moduleSettings = {}
-- status of server connection
local status = "Idle"

local util = require("serverUtil")


-- remove client data to be garbage collected
local function closeClient(sock)
    sock:on("disconnection", function() end)
    sock:on("receive", function() end)
    sock:on("sent", function() end)
    clients[sock].rcvBuf = nil

    if clients[sock].file then
        clients[sock].file:close()
        clients[sock].file = nil
    end
    pcall(function() sock:close() end)
    clients[sock] = nil
end


-- continue sending requested resource or close conn
local function sendFile(sock)
    if clients[sock].file then
        local chunk = clients[sock].file:read()
        if chunk then
            sock:send(chunk)
        else
            closeClient(sock)
        end
    end
end


local function get404(sock)
    sock:on("sent", function(s) closeClient(s) end)
    sock:send("HTTP/1.0 404 Not Found\r\nCache-Control: no-store\r\nContent-Type: text/html\r\n\r\n<a href='"..wifi.ap.getip().."'>")
end


local function get200(sock, msg)
    msg = msg or ''
    sock:on("sent", function(s) closeClient(s) end)
    sock:send("HTTP/1.0 200 OK Found\r\n\r\n" .. msg)
end


local wifiStates = {
    [wifi.STA_IDLE] = 'WiFi Idle',
    [wifi.STA_CONNECTING] = "Connecting to WiFi: ",
    [wifi.STA_WRONGPWD] = "Wrong WiFi Password for: ",
    [wifi.STA_APNOTFOUND] = "Didn't find WiFi: ",
    [wifi.STA_FAIL] = "WiFi failed: ",
    [wifi.STA_GOTIP] = "WiFi connected: "
}

local function getStatusMsg ()
    local wifiCode = wifi.sta.status()
    local ssid = wifi.sta.getconfig()
    local wifiMsg = wifiStates[wifiCode] .. ((wifiCode ~= wifi.STA_IDLE and ssid) or '')

    local setup = util.loadSetup()
    local setupMsg = ''

    if setup.code and (not setup.confirmed) then
        setupMsg = setupMsg .. '\r\nCode to enter at DataApp.com: ' .. setup.code
    elseif setup.confirmed then
        setupMsg = setupMsg .. '\r\nDevice linked to an account at DataApp.com'
    end

    if SetupRequestFailed then
        setupMsg = setupMsg .. '\r\nSetup request failed'
    end

    return wifiMsg .. '\r\n' .. setupMsg
end


local function getDeviceStatus(sock)
    sock:on("sent", function(s) closeClient(s) end)
    sock:send("HTTP/1.0 200 OK\r\n\r\n" .. getStatusMsg())
end


local function serveFile(sock, resource)
    clients[sock].file = file.open(resource)
    if not clients[sock].file then
        get404(sock)
        return
    end
    sock:on("sent", function(s) sendFile(s) end)

    local contEnc = ''
    local fileExt = util.getFileExt(resource)
    if fileExt == '.gz' then contEnc = '\r\nContent-Encoding: gzip' end
    local contType = ''
    if fileExt == '.css' then contType = '\r\nContent-Type: text/css' end
    sock:send('HTTP/1.0 200 OK' .. contType .. contEnc .. '\r\n\r\n')
end


local function postWifiConnect(sock)
    local reqBody = util.getBody(clients[sock].rcvBuf)
    -- if body not nil, handle and cleanup
    if reqBody then
        local reqVals = util.decodeJson(reqBody)
        local station_cfg = {}
        station_cfg.ssid = reqVals.ssid
        station_cfg.pwd = reqVals.pwd
        -- TODO: save config to flash
        station_cfg.save = false
        wifi.sta.config(station_cfg)

        get200(sock)
    -- else wait for the rest of the body
    else
    end
end


local function getSetupCode(sock)
    setupUtil.requestSetup(function (code, data)
        print(code, data)
        get200(sock)
        if (code < 0) then
            SetupRequestFailed = true
        else
            SetupRequestFailed = false
        end
    end)
end


-- request controllers
local controllers = {
  ['check-status'] = getDeviceStatus,
  ['wifi-connect'] = postWifiConnect,
  ['get-setup-code'] = getSetupCode,
  [''] = function (sock) serveFile(sock, 'index.html') end
}


-- handle data received from AP client
local function handleReceive(sock, data)
    if not clients[sock] then
        return nil
    end

    -- buffer request
    clients[sock].rcvBuf = clients[sock].rcvBuf .. data
    -- check for at least one \r\n\r\n
    local k, l = string.find(clients[sock].rcvBuf, "\r\n\r\n")

    if k then
        -- parse endpoint
        local endpoint = util.parseResource(clients[sock].rcvBuf)
        local fileName = util.getFileName(endpoint)

        if controllers[endpoint] ~= nil then
            controllers[endpoint](sock)
        elseif fileName then
            serveFile(sock, fileName)
        else
            get404(sock)
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
local function startServer()
    local setup = util.loadSetup()
    -- code, no confirm; status checks
    if setup.code and setup.confirmed == false then
        setupUtil.startStatusChecks()
    end

    local srv = net.createServer(net.TCP)
    srv:listen(80, handleConn)

    -- configure wifi
    wifi.setmode(wifi.STATIONAP, false);
    wifi.ap.config({ssid="DA".. tostring(node.chipid()), pwd="data app", auth=wifi.WPA2_PSK, save=false})
    wifi.ap.dhcp.start()
    return srv
end

startServer()