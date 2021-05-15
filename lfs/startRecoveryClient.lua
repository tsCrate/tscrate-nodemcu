-- This is a recovery client that will only attempt to upload files, not record new values
local settings = require('settings')

wifi.setmode(wifi.STATION, true)
wifi.sta.autoconnect(1)


local function sendFiles()
    UploadConnHeader = 'keep-alive'

    -- Restart if conn fails
    UploadConn:on("reconnection",
        function(sck, c)
            print('Reconnection event', c)
            node.restart()
        end
    )

    -- Connection will be closed by prepareUploadConn after all files are sent
    -- Restart after files have been sent
    UploadConn:on("disconnection",
        function(sck)
            print('Disconnection event')
            node.restart()
        end
    )

    -- TODO: set restart timeout to handle a server not replying (120s)
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