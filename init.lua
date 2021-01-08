-- decode JSON string
local function jsonDecoder(encodedJson)
	local ok, decodedJson = pcall(cjson.decode, encodedJson)
	if ok then
		return (decodedJson)
	else
	end
end

-- Disable AP until required
wifi.setmode(wifi.STATION, true)

-- enter setup, online, or offline mode
function main()
    -- Check mode and begin execution
    if file.open("mode") then
        local mode = file.readline()
        file.close()

        -- if reset button is cause within 5 seconds of another button reset, trigger setup mode
        local rstRaw, rstExt = node.bootreason()
        if rstRaw == 2 and rstExt == 6 then
            if file.exists("setupTrigger") then
                if file.exists("backupMode") and file.exists("mode") then
                    file.remove("backupMode")
                end
                file.rename("mode", "backupMode")
                file.remove("setupTrigger")
                mode = "setup"
            else
                -- create setup trigger file and delete in 5 seconds
                file.open("setupTrigger", "w+")
                file.close()
                tmr.register(6, 5000, tmr.ALARM_SINGLE, function()
                    print("deleting setup trigger")
                    file.remove("setupTrigger")
                end)
                tmr.start(6)
            end
        else
            file.remove("setupTrigger")
        end

        -- Enter correct mode
        -- Standalone - begin recording
        if mode == "standalone" and file.open("offlineSettings.config", "r") then
            print("offlineSettings")
            local settingsEncodedJson = file.readline()
            file.close()
            local decodedJson = jsonDecoder(settingsEncodedJson)
            local standalone = require('standalone')
        -- Web mode - start client
        elseif mode == "web" and file.open("networkSettings.config", "r") then
            print("networkSettings")
            local settingsEncodedJson = file.readline()
            file.close()
            local decodedJson = jsonDecoder(settingsEncodedJson)
            local sensiveClient = require('sensiveClient')
            sensiveClient.connectToServer(decodedJson["ssid"], decodedJson["pwd"], decodedJson["serverAddr"], decodedJson["serverPort"])
        -- Invalid mode, enter setup mode
        else
            print("No mode, setup")
            local server = require("server")
            server.createSetupServer()
        end
    -- If no mode file, begin setup mode
    else
        print("No mode, setup")
        -- cleanup setupTrigger if it existed from a previous trigger
        file.remove("setupTrigger")
        -- Start AP, allow user to provide settings --
        local server = require("server")
        server.createSetupServer()
    end
end

main()
