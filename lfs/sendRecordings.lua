local settings = require('settings')


local function sendFiles()
    print(node.heap())

    -- TODO: set procedure for restarting the module if call to conn:connect fails, as the TLS/net module may have failed
    UploadConnHeader = 'keep-alive'

    -- Timer to request connection close before the next upload event, if files are still being sent
    UploadCloseTimer:register(0.70 * settings.uploadInterval, tmr.ALARM_SINGLE,
        function()
            UploadConnHeader = 'close'
        end
    )
    UploadCloseTimer:start()

    -- Timer to force close connection before next upload event
    ConnTimeout:register(0.95 * settings.uploadInterval, tmr.ALARM_SINGLE,
        function()
            UploadConn:close()
        end
    )
    ConnTimeout:start()

    UploadConn:connect(settings.serverPort, settings.serverDomain)
end


local function sendRecordings()
    -- TODO: check if in flight and abort?
    -- TODO: calculate space taken by queued files and stop recording above X KB/MB or remaining flash space
    LFS.queueFiles()

    if not next(QueuedFileNames) then return end

    if LFS.queuedFileCount() >= settings.maxFileCount then
        node.restart()
    end

    sendFiles()
end


sendRecordings()