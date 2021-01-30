local settings = require('settings')

local conn = tls.createConnection(net.TCP, 0)


function handleSent(sck)
    sendFileChunks

    sendJsonClose

    sendZeroChunk
    print('sent')
end


function handleReceive(sck, c)
    print('recv ', c)

    handleHttpResponse

    closeConnection

    streamFile(nextFile)
end


function startPost(sck)
    local msg = 'POST /RemoteDevices/upload-readings HTTP/1.1' ..
                '\r\nHost: ' .. settings.serverDomain ..
                '\r\n Transfer-Encoding: chunked' ..
                '\r\n\r\n'
    sck:send(msg)
end


function sendFile()
    conn:on("connection", startPost)

    conn:on("reconnection", function(sck, c) print('reconn', c) end)

    conn:on("disconnection", function(sck) print('disconn') end)

    conn:on("receive", handleReceive)

    conn:on("sent", handleSent)

    conn:connect(settings.serverPort, settings.serverDomain)
end


-- Return a name that doesn't appear in any of the provided tables' keys
function getUniqueName(name, ...)
    local function exists(key)
        local match = nil
        for i,tbl in ipairs(arg) do
            match = match or tbl[key]
        end
        return match ~= nil
    end

    local index = 0
    local newName = name
    while exists(newName) do
        index = index + 1
        newName = name .. index
    end

    return newName
end


function queueFiles()
    QueuedFileNames = {}
    local dataPrefix = '^' .. settings.dataFilePrefix
    local oldQueuedFiles = file.list('^' .. settings.queuedFilePrefix)
    local newQueuedFiles = {}

    for n,b in pairs(file.list(dataPrefix)) do
        local queuedName = n:gsub(dataPrefix, settings.queuedFilePrefix, 1)
        queuedName = getUniqueName(queuedName, newQueuedFiles, oldQueuedFiles)

        -- Store the new name for the next getUniqueName() and rename the file
        newQueuedFiles[queuedName] = b
        file.rename(n, queuedName)
        table.insert(QueuedFileNames, queuedName)
    end
end


function processQueue()
    FileInFlight = table.remove(QueuedFileNames)
    if FileInFlight then
        sendFile()
    end
end


function sendRecordings()
    queueFiles()
    processQueue()
end


sendRecordings()