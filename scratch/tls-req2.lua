sntpServers = { 'time1.google.com', 'time2.google.com', 'time3.google.com', 'time4.google.com' }
conn = tls.createConnection()
currentCallback = function() print('default') end


function handleSent()
    print('sent')
end


function handleReceive(sck, c)
    print('recv ', c)
    conn:close()
end


function request(url, method, body, callback)
    msg = 'GET ' .. url .. ' HTTP/1.0\r\nHost: 192.168.1.7\r\n\r\n'
    currentCallback = callback
    conn:send(msg)
end


function makeRequest()
    request('/RemoteDevices/time', 'GET', nil,
        function(data)
            if data then
                print(data)
            end
        end
    )
end


function startReqs()
    conn:connect(5001, '192.168.1.7')
end


function sendFile()
    conn:on("connection", function(sck)
        print('connected')
        makeRequest()
    end)

    --[[
    conn:on("reconnection", function(sck, c)
        print('reconn', c)
    end)
    ]]

    conn:on("disconnection", function(sck)
        print('disconn')
        startReqs()
    end)

    conn:on("receive", function(sck, c)
        handleReceive(sck, c)
    end)

    conn:on("sent", function(sck)
        handleSent()
    end)
end


function sntpComplete()
    startReqs()
    print('SNTP complete')
end


function sntpFail()
    print("Couldn't get time")
end

sendFile()
sntp.sync(sntpServers, sntpComplete, sntpFail)
