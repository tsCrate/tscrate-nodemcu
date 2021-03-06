local util = require("serverUtil")
local setupUtil = require('setupUtil')
local settings = require('settings')

-- web clients connected to the AP
local clients = {}


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
    local ssids = {}
    if file.open(settings.wifiApFileName, 'r') then
        ssids = util.decodeJson(file.readline())
        file.close()
    end

    local wifiCode = wifi.sta.status()
    local ssid = wifi.sta.getconfig()
    local wifiMsg = wifiStates[wifiCode] .. ((wifiCode ~= wifi.STA_IDLE and ssid) or '')

    local setup = util.loadSetup()
    local setupMsg = ''

    if setup.setupCode and (not setup.confirmed) then
        if SetupCodeExpired then
            setupMsg = setupMsg .. 'Code expired. A new code can be requested.'
        else
            setupMsg = setupMsg .. 'Code to enter at tsCrate.com: ' .. setup.setupCode:sub(1, 3) .. ' ' .. setup.setupCode:sub(4)
        end
    elseif setup.confirmed then
        setupMsg = setupMsg .. 'Device linked to an account at tsCrate.com'
    elseif SetupCodeRequested then
        setupMsg = setupMsg .. 'Requesting setup code...'
    end

    if SetupReqFailed then
        setupMsg = setupMsg .. '\r\nSetup request failed'
    end

    return util.encodeJson({
        hasIp = wifiCode == wifi.STA_GOTIP,
        wifiStatus = wifiMsg,
        setupStatus = setupMsg,
        ssids = ssids
    })
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
    -- After headers sent, send client's file
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
    -- if body not nil, handle and cleanup; else wait for the body
    if reqBody then
        local reqVals = util.decodeJson(reqBody)
        local station_cfg = {}
        station_cfg.ssid = reqVals.ssid
        station_cfg.pwd = reqVals.pwd
        station_cfg.save = true
        wifi.sta.config(station_cfg)

        get200(sock)
    end
end


local function getSetupCode(sock)
    setupUtil.requestSetup(function (code, data)
        get200(sock)
        if (code < 0) then
            SetupReqFailed = true
        else
            SetupReqFailed = false
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
    newSock:on("disconnection",
        function(sock, err)
            print('User disconnected')
            closeClient(sock)
        end
    )
    newSock:on("receive", handleReceive)
end


-- Write wifi access points to a file in JSON
local function writeAps(apTable)
    local apNames = {}
    for k in pairs(apTable) do
        table.insert(apNames, k)
    end
    file.open(settings.wifiApFileName, 'w+')
    file.writeline(util.encodeJson(apNames))
    file.close()
end


-- Get wifi APs if in stationAP mode
local function getWifiAps()
    if wifi.getmode() == wifi.STATIONAP then
        wifi.sta.getap(writeAps)
    end
end


-- Populate available wifi access points
local function populateWifiAps()
    getWifiAps();
    WifiApsTimer:unregister()
    WifiApsTimer:register(15000, tmr.ALARM_AUTO, getWifiAps)
    WifiApsTimer:unregister()
end


-- setup server and enter AP mode
local function startServer()
    local setup = util.loadSetup()
    -- setupCode, no confirm; status checks
    if setup.setupCode and setup.confirmed == false then
        setupUtil.startStatusChecks()
    end

    local srv = net.createServer(net.TCP)
    srv:listen(80, handleConn)

    -- configure wifi
    wifi.setmode(wifi.STATIONAP, false);
    wifi.ap.config({
        ssid=settings.ssid,
        pwd=settings.password
    })
    wifi.ap.dhcp.start()

    populateWifiAps()

    return srv
end

startServer()