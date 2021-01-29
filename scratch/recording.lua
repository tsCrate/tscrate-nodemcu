sntpServers = { 'time1.google.com', 'time2.google.com', 'time3.google.com', 'time4.google.com' }


function writes()
    sec, microsec = rtctime.get()
    nowTime = sec + microsec / math.pow(10, 3)
    
    file.open('tester', "a+")
    file.writeline(nowTime)
    file.close()
end

function sntpComplete()
    print('SNTP complete')
    
    sec, microsec = rtctime.get()
    local startTime = sec + microsec / math.pow(10, 6)
    print('start ', nowTime)
    
    for i = 1, 100 do
        writes()
    end

    sec, microsec = rtctime.get()
    local endTime = sec + microsec / math.pow(10, 6)
    print('Elapsed ', startTime - endTime)
end

function sntpFail()
    print("Couldn't get time")
end

sntp.sync(sntpServers, sntpComplete, sntpFail)