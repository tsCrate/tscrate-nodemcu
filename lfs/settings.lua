local serverDomain = '192.168.1.7'
local serverPort = 5001

return {
    serverDomain = serverDomain,
    serverPort = 5001,
    serverAddr = 'https://' .. serverDomain .. ':' .. serverPort,
    httpTimerInterval = 10000,
    dataFilePrefix = 'data_',
    queuedFilePrefix = 'queued_'
}