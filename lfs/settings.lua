local serverDomain = 'tscrate.com'
local serverPort = 443

return {
    serverDomain = serverDomain,
    serverPort = 5001,
    serverAddr = 'https://' .. serverDomain .. ':' .. serverPort,
    ssid = "DA".. tostring(node.chipid()),
    password = 'data app',
    uploadInterval = 60000,
    dataFilePrefix = 'data_',
    queuedFilePrefix = 'queued_',
    maxFileCount = 50,
    sntpInterval = 1800000
}