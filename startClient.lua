local settings = require('settings')

wifi.setmode(wifi.STATION, true)
wifi.sta.autoconnect(1)

local function startClient()

  local conn = tls.createConnection()
  conn:on("connection", function(sck, c)
    print('connected')
    sck:send('GET /RemoteDevices/get-setup-code HTTP/1.1\r\nHost: 192.168.1.7\r\nConnection: keep-alive\r\n\r\n')
  end)

  conn:on("reconnection", function(sck, c) print('reconn') end)
  conn:on("disconnection", function(sck, c) print('disconn') end)
  conn:on("receive", function(sck, c) print(c) end)
  conn:on("sent", function(sck, c) print('sent') end)

  conn:connect(5001, '192.168.1.7')
end


if wifi.sta.status() == wifi.STA_GOTIP then
  startClient()
else
  wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function ()
    startClient()
  end)
end