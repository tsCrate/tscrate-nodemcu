--file.open('heaps', "a")
reqTmr = tmr.create()
reqTmr:register(200, tmr.ALARM_AUTO,
    function()
        --print(node.heap())
        --file.writeline(node.heap())
    end
)

reqTmr:start()
function makeReq()
    http.request(
        "https://192.168.1.7:5001/RemoteDevices/time",
        "GET",
        nil,
        nil,
        function(code, data)
            print(data)
            makeReq()
        end
    )
end

makeReq()