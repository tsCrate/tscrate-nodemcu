if node.LFS.list() == nil and file.exists('lfs.img') then
    node.LFS.reload('lfs.img')
end

--[[
initTimer = tmr.create()
initTimer:register(1000, tmr.ALARM_SINGLE,
    function()
        local fi=node.LFS.get('_init');
        pcall(fi and fi'_init')
    end)
initTimer:start()
]]

node.LFS.get('_init')()

local server = require('server')
server.createSetupServer()
