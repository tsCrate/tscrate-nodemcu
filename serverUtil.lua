-- decode stringified JSON
local function decodeJson(encodedJson)
    local ok, decodedJson = pcall(sjson.decode, encodedJson)
    if ok then
        return (decodedJson)
    else
        print("Decoding failed: " .. encodedJson)
    end
end

-- stringify JSON
local function encodeJson(tableToEncode)
    local ok, encodedJson = pcall(sjson.encode, tableToEncode)
    if ok then
        return(encodedJson)
    else
        print("Encoding failed")
    end
end

-- parse page requested
local function parseResource(data)
    local i, j = string.find(data, "GET /")
    if not i then
        i, j = string.find(data, "POST /")
    elseif not i then
        -- not post or get
        return nil
    end
    local k, l = string.find(data, " HTTP")
    return string.sub(data, j+1, k-1)
end

-- Message from server - check for complete json strings; store incomplete strings
local function parseServerMsg(serverMsg)
    -- find separator
    local i, j = string.find(serverMsg, "\r\n\r\n")

    -- remove first message from buffer
    local msg = string.sub(serverMsg, 1, i-1)
    serverMsg = string.sub(serverMsg, j+1)

    return serverMsg, decodeJson(msg)
end

-- Get body from an HTTP message
local function getBody(req)
    local i, j = string.find(req, '\r\n\r\n')

    if i then
        local body = req:sub(j+1)
        local _, _, contLen = req:find('Content%-Length:(.-)\r\n')
        if body:len() >= tonumber(contLen) then
            return body
        else
            return nil
        end
    else
        return nil
    end
end

-- extract json from a client's receive buffer
local function extractTable(clients, sock)
    -- check for delimiters
    local k, l = string.find(clients[sock].rcvBuf, "}\r\n\r\n")
    if k then
        local i, j = string.find(clients[sock].rcvBuf, "\r\n\r\n")
        local encJson = string.sub(clients[sock].rcvBuf, j+1, k)
        clients[sock].rcvBuf = ""
        --print("heap: "..node.heap()/1000)
        --print("gc: "..collectgarbage("count"))
        --print("clients: "..tablelength(clients))
        return decodeJson(encJson)
    end
    -- else return nil
    return nil
end

return {
    parseResource = parseResource,
    extractTable = extractTable,
    getBody = getBody,
    parseServerMsg = parseServerMsg,
    encodeJson = encodeJson,
    decodeJson = decodeJson
}
