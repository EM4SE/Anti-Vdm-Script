-- server.lua
local QBCore = exports['qb-core']:GetCoreObject()
local vdmWarnings = {}

-- Configuration
local Config = {
    warningTime = 60, -- Time in seconds (2 minutes) before warning expires
    enableLogs = true, -- Enable Discord webhook logs
    webhookURL = "" -- Add your Discord webhook URL here
}

-- Function to send Discord log
local function SendDiscordLog(title, message, color)
    if not Config.enableLogs or Config.webhookURL == "" then return end
    
    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["color"] = color,
            ["footer"] = {
                ["text"] = os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    PerformHttpRequest(Config.webhookURL, function(err, text, headers) end, 'POST', 
        json.encode({username = "VDM System", embeds = embed}), 
        {['Content-Type'] = 'application/json'})
end

-- Function to clean expired warnings
local function CleanExpiredWarnings(src)
    if vdmWarnings[src] then
        local currentTime = os.time()
        if (currentTime - vdmWarnings[src].time) > Config.warningTime then
            vdmWarnings[src] = nil
            print(string.format("^3[VDM System]^7 Cleared expired warning for player %s", src))
        end
    end
end

-- Server-side event handler
RegisterServerEvent('vdm:detectVDM')
AddEventHandler('vdm:detectVDM', function(victimId, speed, vehicleName)
    local src = source
    
    print(string.format("^3[VDM System]^7 VDM detected! Player: %s | Speed: %.1f km/h | Vehicle: %s", src, speed, vehicleName))
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        print(string.format("^1[VDM System]^7 ERROR: Could not get QBCore player for source %s", src))
        return 
    end
    
    local playerName = GetPlayerName(src)
    local identifiers = GetPlayerIdentifiers(src)
    
    -- Clean expired warnings
    CleanExpiredWarnings(src)
    
    -- Check if player already has a warning
    if vdmWarnings[src] then
        print(string.format("^1[VDM System]^7 KICKING player %s for second VDM offense!", playerName))
        
        -- Second offense - Kick player
        local reason = string.format("VDM: Second offense within 2 minutes. Speed: %.1f km/h", speed)
        DropPlayer(src, reason)
        
        -- Send Discord log
        SendDiscordLog(
            "Player Kicked - VDM",
            string.format("**Player:** %s\n**ID:** %s\n**Reason:** %s\n**Vehicle:** %s", 
                playerName, src, reason, vehicleName),
            15158332 -- Red color
        )
        
        -- Notify all players
        TriggerClientEvent('QBCore:Notify', -1, playerName .. " was kicked for VDM (Second offense)", "error")
        
        -- Clear warning
        vdmWarnings[src] = nil
    else
        print(string.format("^3[VDM System]^7 WARNING player %s for first VDM offense!", playerName))
        
        -- First offense - Warn player
        vdmWarnings[src] = {
            time = os.time(),
            count = 1
        }
        
        -- Send warning to player with custom notification
        TriggerClientEvent('vdm:showWarning', src, speed, vehicleName)
        
        -- Also send QBCore notification as backup
        TriggerClientEvent('QBCore:Notify', src, 
            "VDM WARNING! Next offense within 2 minutes = KICK!", 
            "error", 8000)
        
        -- Send Discord log
        SendDiscordLog(
            "Player Warned - VDM",
            string.format("**Player:** %s\n**ID:** %s\n**Speed:** %.1f km/h\n**Vehicle:** %s\n**Warning:** First offense", 
                playerName, src, speed, vehicleName),
            16776960 -- Yellow color
        )
        
        -- Notify admins
        for _, playerId in ipairs(GetPlayers()) do
            local targetPlayer = QBCore.Functions.GetPlayer(tonumber(playerId))
            if targetPlayer and QBCore.Functions.HasPermission(playerId, 'admin') then
                TriggerClientEvent('QBCore:Notify', playerId, 
                    string.format("%s received VDM warning (Speed: %.1f km/h)", playerName, speed), 
                    "error")
            end
        end
    end
end)

-- Clean up warnings when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    if vdmWarnings[src] then
        vdmWarnings[src] = nil
        print(string.format("^3[VDM System]^7 Cleared warning for disconnected player %s", src))
    end
end)

-- print("^2[VDM System]^7 Server-side Anti-VDM script loaded successfully! ^5| Made by Emase")