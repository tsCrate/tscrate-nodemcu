local settings = require('settings')

wifi.setmode(wifi.STATION, true)
wifi.sta.autoconnect(1)


local function sendFiles()
    UploadConnHeader = 'keep-alive'

    UploadConn:on("reconnection",
        function(sck, c)
            print('Reconnection event', c)
            node.restart()
        end
    )

    UploadConn:on("disconnection",
        function(sck)
            print('Disconnection event')
            node.restart()
        end
    )

    UploadConn:connect(settings.serverPort, settings.serverDomain)
end


local function startRecoveryClient()
  LFS.prepareUploadConn()

  LFS.queueFiles()
  if not next(QueuedFileNames) then node.restart() end

  sendFiles()
end


if wifi.sta.status() == wifi.STA_GOTIP then
    startRecoveryClient()
else
    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP,
        function ()
            print('got ip')
            wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
            startRecoveryClient()
        end
    )
end