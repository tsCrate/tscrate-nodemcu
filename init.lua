-- set to station until correct mode is determined
wifi.setmode(wifi.STATION, true)

if node.LFS.list() == nil and file.exists('lfs.img') then
    node.LFS.reload('lfs.img')
end

-- make LFS easier to access
node.LFS.get('_init')()
node.LFS.startServer()


--local resetRaw, resetExtended = node.bootreason()
-- no code; setup start
-- local server = require('server')
-- server.startServer()
-- code, reset flag; start stationap, restart after 5mins
-- code, no confirm; status checks
-- code confirmed; record mode


-- TODO: check state (factory default, wifi set, code set, code confirmed; w/ or w/o restart-setup flag)


--[[
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function ()
    print('STA GOT IP')
    -- TODO: if setup not completed, request setup code or status, else start recording
    local setup = loadSetup()
    if setup.complete then
        -- TODO: start recording
    else
        requestSetup()
    end
end)
]]