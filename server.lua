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
local serverConnStatus = "No connection"

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


local function getStatus(sock)
    sock:on("sent", function(s) closeClient(s) end)
    sock:send("HTTP/1.0 200 OK\r\n\r\n status sample" .. math.random(1, 100))
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


-- request controllers
local controllers = {
  ['check-status'] = getStatus,
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

        -- NEW CODE
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
    wifi.ap.config({ssid="Sensive".. tostring(node.chipid()), pwd="12345678", auth=wifi.WPA2_PSK, save=false, beacon=100})
    wifi.ap.dhcp.start()
    return srv
end


return M
