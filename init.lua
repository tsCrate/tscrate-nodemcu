if node.LFS.list() == nil and file.exists('lfs.img') then
    node.LFS.reload('lfs.img')
end

node.LFS.get('_init')()

--server = require('server')
--util = require("serverUtil")
--statusTimer = tmr.create()

-- TODO: check state (factory default, wifi set, code set, code confirmed; w/ or w/o restart-setup flag)


-- server.createSetupServer()

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