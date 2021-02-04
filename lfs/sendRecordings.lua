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


-- TODO: break largest code chunks into files to reduce heap use
-- TODO: UploadConn handlers and registration can be moved to their own file to be registered once
local function getBody()
    -- determine if body is complete
    local _, i = UploadRecvBuffer:find('\r\n\r\n')
    if not i then return nil end

    i = i + 1
    local chunkSize = nil
    local j
    local body = ''
    while chunkSize ~= 0 do
        -- slide i,j to chunk size (chunk size transmitted in hex chars)
        _, j = UploadRecvBuffer:find('\r\n', i)

        -- Haven't received end of chunk size portion to parse
        if not j then return nil end

        chunkSize = tonumber(UploadRecvBuffer:sub(i, j), 16)
        if (chunkSize ~= 0) and ((UploadRecvBuffer:len()) <= (j + chunkSize + 2)) then
            -- The full chunk hasn't been received (chunk > received data)
            return nil
        end

        body = body .. UploadRecvBuffer:sub(j + 1, j + chunkSize - 1)
        i = j + chunkSize + 3
    end
    return body
end


local function handleBody(body)
    -- TODO: parse body
    print(UploadRecvBuffer:gsub('\r\n', '\\r\\n'))
end


local function startPost(sck)
    local msg = 'POST /RemoteDevices/upload-readings HTTP/1.1' ..
                '\r\nHost: ' .. settings.serverDomain ..
                '\r\nContent-Type: application/json' ..
                '\r\nConnection: ' .. UploadConnHeader ..
                '\r\nTransfer-Encoding: chunked' ..
                '\r\n\r\n'
    sck:send(msg)
end


local function closeConn(sck)
    print('close conn')
    UploadCloseTimer:unregister()
    ConnTimeout:unregister()
    sck:close()
end


local function sendNextFile(sck)
    -- Pop name, open filedesc, send file
    -- No files left
    FileNameInFlight = table.remove(QueuedFileNames)
    if not FileNameInFlight then
        closeConn(sck)
        return nil
    end
    -- Request close by server if this is the last file
    if not next(QueuedFileNames) then
        UploadConnHeader = 'close'
    end

    -- File doesn't exist, bail
    FdInFlight= file.open(FileNameInFlight, 'r')
    if not FdInFlight then
        closeConn(sck)
        return nil
    end

    startPost(sck)
end


local function handleReceive(sck, data)
    if data then UploadRecvBuffer = UploadRecvBuffer .. data end
    if not UploadRecvBuffer:match('Transfer%-Encoding: chunked') then
      print('Response must be chunked')
      return
    end

    local body = getBody()
    if body then
      handleBody(body)
      UploadRecvBuffer = ''
      file.remove(FileNameInFlight)

      local _, last = UploadRecvBuffer:find('\r\n\r\n')
      local connClose = UploadRecvBuffer:sub(1, last):match('Connection: close')
      if not connClose then
        sendNextFile(sck)
      end
    end

end


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

    -- Handlers
    UploadConn:on("connection",
        function(sck)
            print('connected')
            sendNextFile(sck)
        end
    )

    UploadConn:on("sent", handleSent)

    UploadConn:on("receive", handleReceive)

    UploadConn:on("reconnection",
        function(sck, c)
            print('reconn', c)
            UploadCloseTimer:unregister()
            ConnTimeout:unregister()
        end
    )
    UploadConn:on("disconnection",
        function(sck)
            UploadCloseTimer:unregister()
            ConnTimeout:unregister()
            print('disconn')
        end
    )

    UploadConn:connect(settings.serverPort, settings.serverDomain)
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
    -- TODO: check if in flight and abort?
    -- TODO: calculate space taken by queued files and stop recording above X KB/MB or remaining flash space
    queueFiles()
    if not next(QueuedFileNames) then return end
    sendFiles()
end


sendRecordings()