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


local function sendNextFile(sck)
    -- Pop name, open filedesc, send file
    -- No files left
    FileNameInFlight = table.remove(QueuedFileNames)
    if not FileNameInFlight then
        return nil
    end

    -- File doesn't exist
    FdInFlight= file.open(FileNameInFlight, 'r')
    if not FdInFlight then
        return nil
    end

    -- Request close by server if this is the last file
    if not next(QueuedFileNames) then
        UploadConnHeader = 'close'
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


local function registerHandlers()
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
end

registerHandlers()