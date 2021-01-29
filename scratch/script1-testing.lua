sntp.sync()
RequestQueue = {}
RequestInFlight = false
recvBuff = ''
testTmr = tmr.create()
conn = tls.createConnection()
currentRequest = nil

sec, microsec = rtctime.get()
lastTime = sec + microsec / math.pow(10, 6)

--[[
bTmr = tmr.create()
bTmr:register(5000, tmr.ALARM_AUTO, function() print('recvBuffer ', recvBuffer) end)
bTmr:start()
]]

-- TODO: set a restart timeout on request because the device just silently drops the TLS connection sometimes
-- TODO: Is thi even possible -> Actually, the above issue may be a conflict with sent/received/registered sends
-- TODO: Maybe it's a parsing problem; observed a "send", which the server saw, but the device didn't appear to handle
-- TODO: keepalive requests every X minutes

function startReporting()
    testTmr:register(10000, tmr.ALARM_AUTO,
        function()
            local sec, microsec = rtctime.get()
            local nowTime = sec + microsec / math.pow(10, 6)
            
            lastTime = nowTime
            print('calling registered')
            request('/RemoteDevices/test', 'GET', nil,
                function(data)
                    if data then
                        --print(data)
                    end
                end)
        end)

    testTmr:start()
end


function processQueue()
    if not currentRequest then
        currentRequest = table.remove(RequestQueue, 1)
        if currentRequest then
            print('sending')
            conn:send(currentRequest.message)
        end
    end
end


function request(url, method, body, callback)
    local msg = ''
    if method == 'GET' then
        msg = 'GET ' .. url .. ' HTTP/1.1\r\nHost: 192.168.1.7\r\nConnection: keep-alive\r\nAccept: application/json\r\n\r\n'
    end
    table.insert(
        RequestQueue,
        {
            message = msg,
            callback = callback
        })
    processQueue()
end


function getBody()
    --print(recvBuff:gsub('\r\n', '\\r\\n'))
    -- determine if body is complete
    local _, i = recvBuff:find('\r\n\r\n')
    --print('i ', i)
    if not i then return nil end

    i = i + 1
    local chunkSize = nil
    local j
    local body = ''
    while chunkSize ~= 0 do
        _, j = recvBuff:find('\r\n', i)
        --print('j ', j)
        if not j then return nil end

        --print(recvBuff:sub(i, j))

        chunkSize = tonumber(recvBuff:sub(i, j), 16)
        if (chunkSize ~= 0) and ((recvBuff:len()) <= (j + chunkSize + 2)) then return nil end

        body = body .. recvBuff:sub(j + 1, j + chunkSize)
        i = j + chunkSize + 3
    end
    
    return body
end


function handleBody(body)
    --print('handle body')
    print(recvBuff:gsub('\r\n', '\\r\\n'))
end


function handleReceive(sck, data)
  --print('received')
    if data then recvBuff = recvBuff .. data end
    --print(recvBuff:find('\r\n\r\n'))
    if not recvBuff:match('Transfer%-Encoding: chunked') then
      print('Response must be chunked')
      return
    end

    local body = getBody()
    if body then
      handleBody(body)
      currentRequest.callback(body)
      recvBuff = ''
      currentRequest = nil
      processQueue()
    end
    --sck:send('GET /RemoteDevices/get-setup-code HTTP/1.1\r\nHost: 192.168.1.7\r\nConnection: keep-alive\r\nAccept: application/json\r\n\r\n')
end


function startClient()
  conn:on("connection", function(sck, c)
    print('connected')
    startReporting()
  end)

  conn:on("reconnection", function(sck, c)
    print('reconn', c)
    --sck:send('GET /RemoteDevices/test HTTP/1.1\r\nHost: 192.168.1.7\r\nConnection: keep-alive\r\nAccept: application/json\r\n\r\n')
  end)

  conn:on("disconnection", function(sck, c) print('disconn') end)
  conn:on("receive", function(sck, c)
    handleReceive(sck, c)
  end)
  conn:on("sent", function(sck, c)
    local sec, microsec = rtctime.get()
    local nowTime = sec + microsec / math.pow(10, 6)
    print('time to send ', nowTime - lastTime)
    --print('sent')
  end)

  conn:connect(5001, '192.168.1.7')
end

startClient()