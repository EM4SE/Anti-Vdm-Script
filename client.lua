-- client.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Configuration
local Config = {
    minSpeed = 30.0, -- Minimum speed (km/h) to be considered VDM (lowered for better detection)
    damageThreshold = 20.0, -- Minimum damage to trigger VDM detection (lowered for better detection)
    checkInterval = 100 -- Check interval in milliseconds
}

-- Custom VDM Warning Notification
RegisterNetEvent('vdm:showWarning')
AddEventHandler('vdm:showWarning', function(speed, vehicleName)
    print(string.format("^3[VDM System]^7 Showing warning popup - Speed: %.1f km/h | Vehicle: %s", speed, vehicleName))
    
    -- Send NUI message to show custom alert
    SendNUIMessage({
        type = 'showVDMWarning',
        speed = string.format("%.1f", speed),
        vehicle = vehicleName
    })
    
    -- Play warning sound
    PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 1)
end)

-- Detect vehicle collision with players using entity damage event
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local weaponHash = args[5]
        local damage = args[4]
        
        local playerPed = PlayerPedId()
        
        -- Check if victim is a player and not the local player
        if IsPedAPlayer(victim) and victim ~= playerPed then
            -- Check if local player is the attacker and is in a vehicle
            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                local driver = GetPedInVehicleSeat(vehicle, -1)
                
                -- Check if local player is the driver
                if driver == playerPed then
                    -- Check if the vehicle caused the damage
                    if attacker == vehicle or attacker == playerPed then
                        local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert m/s to km/h
                        
                        print(string.format("^3[VDM System]^7 Collision detected! Speed: %.1f km/h | Damage: %.1f", speed, damage))
                        
                        -- Check if speed meets threshold
                        if speed >= Config.minSpeed then
                            local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
                            local victimServerId = GetPlayerServerId(victimPlayer)
                            local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
                            
                            print(string.format("^1[VDM System]^7 VDM DETECTED! Triggering server event..."))
                            
                            -- Trigger server event to log VDM
                            TriggerServerEvent('vdm:detectVDM', victimServerId, speed, vehicleName)
                        end
                    end
                end
            end
        end
    end
end)

-- Test command to check if NUI is working
RegisterCommand('testvdm', function()
    print("^2[VDM System]^7 Testing VDM warning popup...")
    TriggerEvent('vdm:showWarning', 85.5, "Adder")
end, false)

-- print("^2[VDM System]^7 Client-side Anti-VDM script loaded successfully! ^5| Made by Emase")
-- print("^3[VDM System]^7 Type /testvdm to test the warning popup")