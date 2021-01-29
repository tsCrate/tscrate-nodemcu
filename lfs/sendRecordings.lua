local dsname = ...

local function sendRecordings(dsname)
    if not file.exists(dsname) then return end
end

sendRecordings(dsname)