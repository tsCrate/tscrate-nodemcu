local settings = require('settings')


-- Return a name that doesn't appear in any of the provided tables' keys
local function getUniqueName(name, ...)
    local function exists(key)
        local match = nil
        for i,tbl in ipairs(arg) do
            match = match or tbl[key]
        end
        return match ~= nil
    end

    local index = 0
    local newName = name
    while exists(newName) do
        index = index + 1
        newName = name .. index
    end

    return newName
end


local function appendJsonChars(fileName)
    -- Remove trailing comma
    local fdr = file.open(fileName, 'r+')
    fdr:seek('end', -2)
    local isComma = file.read(1) == ','
    if isComma then
        fdr:seek('end', -2)
        fdr:write(' ')
    end
    fdr:close()

    -- Add array and object close
    local fda = file.open(fileName, 'a+')
    fda:writeline(']}')
    fda:close()
end


local function prepDataFiles()
    local dataPrefix = '^' .. settings.dataFilePrefix
    local oldQueuedFiles = file.list('^' .. settings.queuedFilePrefix)
    local newQueuedFiles = {}

    for n,b in pairs(file.list(dataPrefix)) do
        appendJsonChars(n)
        local queuedName = n:gsub(dataPrefix, settings.queuedFilePrefix, 1)
        queuedName = getUniqueName(queuedName, newQueuedFiles, oldQueuedFiles)

        -- Store the new name for the next getUniqueName() and rename the file
        newQueuedFiles[queuedName] = b
        file.rename(n, queuedName)
    end

end


local function queueFiles()
    prepDataFiles()
    QueuedFileNames = {}
    local queuedFiles = file.list('^' .. settings.queuedFilePrefix)

    for n,b in pairs(queuedFiles) do
        table.insert(QueuedFileNames, n)
    end
end

queueFiles()