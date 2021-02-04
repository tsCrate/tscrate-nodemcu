local function queuedFileCount()
    local count = 0
    for k in pairs(QueuedFileNames) do
        count = count + 1
    end
    return count
end

return queuedFileCount()