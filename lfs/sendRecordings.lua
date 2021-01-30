local settings = require('settings')


local function sendChunk(sck, chunk)
    local chunkSize = string.format('%x', chunk:len())
    sck:send(chunkSize .. '\r\n' .. chunk .. '\r\n')
end


local function handleSent(sck)
    if FdInFlight == nil then return end

    local bytes = FdInFlight:read()
    if bytes then
        sendChunk(sck, bytes)
    else
        FdInFlight:close()
        FdInFlight = nil
        -- send zero chunk
        sendChunk(sck, '')
    end
end


local function handleReceive(sck, c)
    print('recv ', c)
    local term = c:match('0\r\n\r\n')
    if term then
        --TODO: handle response, delete file
        print('terminated')
        sck:close()
    end

    --[[
    bufferHttpResponse
    parseHttpResponse
    handleHttpResponse
        deletefile


    setInFlightFile
    startPost(nextFile)

    closeConnection
    ]]
end


local function startPost(sck)
    local msg = 'POST /RemoteDevices/upload-readings HTTP/1.1' ..
                '\r\nHost: ' .. settings.serverDomain ..
                '\r\nContent-Type: application/json' ..
                '\r\nTransfer-Encoding: chunked' ..
                '\r\n\r\n'
    sck:send(msg)
end


local function sendFiles()
    --pop name, open filedesc, send file
    FileNameInFlight = table.remove(QueuedFileNames)
    if not FileNameInFlight then return end

    FdInFlight= file.open(FileNameInFlight, 'r')
    if not FdInFlight then return end

    local conn = tls.createConnection(net.TCP, 0)

    conn:on("connection", startPost)

    conn:on("sent", handleSent)

    conn:on("receive", handleReceive)

    conn:on("reconnection", function(sck, c) print('reconn', c) end)
    conn:on("disconnection", function(sck) print('disconn') end)

    conn:connect(settings.serverPort, settings.serverDomain)
end


-- Return a name that doesn't appear in any of the provided tables' keys
local function getUniqueName(name, ...)
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


local function appendJsonChars(fileName)
    -- Remove trailing comma
    local fdr = file.open(fileName, 'r+')
    fdr:seek('end', -3)
    local isComma = file.read(1) == ','
    if isComma then
        fdr:seek('end', -3)
        fdr:write(' ')
    end
    fdr:close()

    -- Add array and object close
    local fda = file.open(fileName, 'a+')
    fda:writeline(']}')
    fda:close()
end


local function prepDataFiles()
    local dataPrefix = '^' .. settings.dataFilePrefix
    local oldQueuedFiles = file.list('^' .. settings.queuedFilePrefix)
    local newQueuedFiles = {}

    for n,b in pairs(file.list(dataPrefix)) do
        appendJsonChars(n)
        local queuedName = n:gsub(dataPrefix, settings.queuedFilePrefix, 1)
        queuedName = getUniqueName(queuedName, newQueuedFiles, oldQueuedFiles)

        -- Store the new name for the next getUniqueName() and rename the file
        newQueuedFiles[queuedName] = b
        file.rename(n, queuedName)
    end

end


local function queueFiles()
    prepDataFiles()
    QueuedFileNames = {}
    local queuedFiles = file.list('^' .. settings.queuedFilePrefix)

    for n,b in pairs(queuedFiles) do
        table.insert(QueuedFileNames, n)
    end
end


local function sendRecordings()
    queueFiles()
    sendFiles()
end


sendRecordings()