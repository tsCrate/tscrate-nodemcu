local sntpServers = { 'time1.google.com', 'time2.google.com', 'time3.google.com', 'time4.google.com' }

wifi.setmode(wifi.STATION, true)
wifi.sta.autoconnect(1)


local function sntpComplete()
    print('SNTP complete. Starting main.')
    main()
end


local function sntpStart()
    sntp.sync(sntpServers, sntpComplete,
        function()
            print("SNTP failed. Time not set. Retrying in 10 seconds.")
            local sntpTmr = tmr.create()
            sntpTmr:register(10000, tmr.ALARM_SINGLE, sntpStart)
        end
      )
end


local function startClient()
    sntpStart()
    LFS.prepareUploadConn()
end


if wifi.sta.status() == wifi.STA_GOTIP then
    startClient()
else
    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP,
        function ()
            print('got ip')
            -- TODO: test wifi drop
            wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
            startClient()
        end
    )
end