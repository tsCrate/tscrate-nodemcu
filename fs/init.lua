-- set to station until correct mode is determined
wifi.setmode(wifi.STATION, true)

if node.LFS.list() == nil and file.exists('lfs.img') then
    node.LFS.reload('lfs.img')
end

-- make LFS easier to access
node.LFS.get('_init')()
node.LFS.startup()

main = function() dofile('main.lua') end