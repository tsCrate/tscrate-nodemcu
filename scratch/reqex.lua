function request()
print('do it')
    local conn = tls.createConnection(net.TCP, 0)
    
    conn:on("connection", function(sck)
        print('connected')
        msg = 'GET /RemoteDevices/time HTTP/1.1\r\nHost: 192.168.1.7\r\n\r\n'
        sck:send(msg)
    end)

    conn:on("reconnection", function(sck, c)
        -- reconn is fired on disconn instead of the disconn event for some reason
        print('reconn', c)
    end)

    conn:on("disconnection", function(sck, c)
        print('disconn', c)
        startConnection()
    end)

    conn:on("receive",
        function(sck, c)
            print('recv ')
            sck:close()
        end
    )

    conn:on("sent", function()
        print('sent')
    end)
    
    conn:connect(5001, '192.168.1.7')
    print('heap ', node.heap())
end

reqTmr = tmr.create()
reqTmr:register(10000, tmr.ALARM_AUTO, request)
reqTmr:start()