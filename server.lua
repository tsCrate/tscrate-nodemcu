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
    return wifiStates[wifiCode] .. (wifiCode ~= wifi.STA_IDLE and ssid or '')
end


local function getStatus(sock)
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
    sock:send("HTTP/1.0 200 OK\r\n\r\n")
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
    -- else wait for the rest of the body
    else
    end
end


-- request controllers
local controllers = {
  ['check-status'] = getStatus,
  ['wifi-connect'] = postWifiConnect,
  [''] = function (sock) serveFile(sock, 'index.html') end
}


-- handle data received from AP client
local function handleReceive(sock, data)
    -- buffer request
    clients[sock].rcvBuf = clients[sock].rcvBuf .. data
    -- check for at least one \r\n\r\n
    local k, l = string.find(clients[sock].rcvBuf, "\r\n\r\n")

    if k then
        -- parse endpoint
        local endpoint = util.parseResource(clients[sock].rcvBuf)
        print('endpoint: ' .. endpoint)

        if file.exists(endpoint) then
            serveFile(sock, endpoint)
        elseif controllers[endpoint] ~= nil then
            controllers[endpoint](sock)
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
function createSetupServer()
    local srv=net.createServer(net.TCP)
    srv:listen(80, handleConn)

    -- configure wifi
    wifi.eventmon.register(wifi.eventmon.AP_STADISCONNECTED, function() print("Dropped AP client") end)
    wifi.setmode(wifi.STATIONAP, false);
    wifi.ap.config({ssid="DA".. tostring(node.chipid()), pwd="data app", auth=wifi.WPA2_PSK, save=false, beacon=100})
    wifi.ap.dhcp.start()
    return srv
end


return M
