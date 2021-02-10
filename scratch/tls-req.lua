sntpServers = { 'time1.google.com', 'time2.google.com', 'time3.google.com', 'time4.google.com' }
conn = tls.createConnection(net.TCP, 0)
currentCallback = function() print('default') end


function handleSent()
    print('sent')
end


function handleReceive(sck, c)
    print('recv ', c)
    conn:close()
end


function request(url, method, body, callback)
    msg = 'GET ' .. url .. ' HTTP/1.1\r\nHost: 192.168.1.7\r\n\r\n'
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


function sendFiles()
    conn:on("connection", function()
        print('connected')
        makeRequest()
    end)

--[[
    conn:on("reconnection", function(sck, c)
        -- reconn is fired on disconn instead of the disconn event for some reason
        print('reconn', c)

    end)
]]

    conn:on("disconnection", function(sck, c)
        print('disconn', c)
                --startReqs()
    end)

    conn:on("receive", function(sck, c)
        handleReceive(nil, c)
    end)

    conn:on("sent", function()
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

sendFiles()
sntp.sync(sntpServers, sntpComplete, sntpFail)
