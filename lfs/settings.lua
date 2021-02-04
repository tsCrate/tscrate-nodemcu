local serverDomain = '192.168.1.8'
local serverPort = 5001

return {
    serverDomain = serverDomain,
    serverPort = 5001,
    serverAddr = 'https://' .. serverDomain .. ':' .. serverPort,
    uploadInterval = 60000,
    dataFilePrefix = 'data_',
    queuedFilePrefix = 'queued_',
    maxFileCount = 50
}