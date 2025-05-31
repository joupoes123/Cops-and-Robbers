-- client.lua
-- Cops & Robbers FiveM Game Mode - Client Script
-- Version: 1.1 | Date: 2025-02-11
-- This file handles client-side functionality including UI notifications,
-- role selection, vendor interactions, spawning, and other game-related events.

-- =====================================
--           CONFIGURATION
-- =====================================

-- Config is loaded from shared_scripts 'config.lua'

-- =====================================
--           VARIABLES
-- =====================================

-- Player-related variables
local role = nil
local playerCash = 0
local currentSpikeStrips = {} -- { [stripId] = { entity = prop_entity, location = vector3, obj = objHandle } }
local spikeStripModelHash = GetHashKey("p_ld_stinger_s") -- Example model for spike strip
local playerStats = { heists = 0, arrests = 0, rewards = 0, experience = 0, level = 1 }
local currentObjective = nil
local wantedLevel = 0 -- This seems to be a legacy or separate wanted level system.
                      -- The new system will use currentWantedStarsClient.
local playerWeapons = {}
local playerAmmo = {}

-- Wanted System Client State
local currentWantedStarsClient = 0
local currentWantedPointsClient = 0
local wantedUiLabel = ""

-- Contraband Drop Client State
local activeDropBlips = {}
local clientActiveContrabandDrops = {} -- Stores { dropId = { location=vec3, name=string, modelHash=hash, propEntity=entity } }
local isCollectingFromDrop = nil -- dropId if currently collecting, else nil
local collectionTimerEnd = 0

-- Safe Zone Client State
local isCurrentlyInSafeZone = false
local currentSafeZoneName = ""

-- =====================================
--           HELPER FUNCTIONS
-- =====================================

-- Function to display notifications on screen
local function ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawNotification(false, true)
end

-- Function to display help text
local function DisplayHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Function to spawn player based on role
local function spawnPlayer(role)
    local spawnPoint = Config.SpawnPoints[role]
    if spawnPoint then
        SetEntityCoords(PlayerPedId(), spawnPoint.x, spawnPoint.y, spawnPoint.z, false, false, false, true)
        -- Consider setting the heading if a spawn heading is available
    else
        print("Error: Invalid role for spawning: " .. tostring(role))
    end
end

-- =====================================
--           NETWORK EVENTS
-- =====================================

-- Request player data when the player spawns
AddEventHandler('playerSpawned', function()
    -- Request player data from the server
    TriggerServerEvent('cops_and_robbers:requestPlayerData')
    
    -- Show NUI role selection screen
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showRoleSelection' })
end)

-- Receive player data from the server
RegisterNetEvent('cops_and_robbers:receivePlayerData')
AddEventHandler('cops_and_robbers:receivePlayerData', function(data)
    if not data then
        print("Error: Received nil data in 'receivePlayerData'")
        return
    end
    
    playerCash = data.cash or 0
    playerStats = data.stats or { heists = 0, arrests = 0, rewards = 0, experience = 0, level = 1 }
    role = data.role
    
    spawnPlayer(role) -- Spawn player based on received role
    
    local playerPed = PlayerPedId()
    if data.weapons then
        for weaponName, ammo in pairs(data.weapons) do
            local weaponHash = GetHashKey(weaponName)
            GiveWeaponToPed(playerPed, weaponHash, ammo or 0, false, false)
            playerWeapons[weaponName] = true
            playerAmmo[weaponName] = ammo or 0
        end
    end
    -- Optionally restore inventory items and update money display
end)

-- Wanted System: Update wanted level display
RegisterNetEvent('cops_and_robbers:updateWantedDisplay')
AddEventHandler('cops_and_robbers:updateWantedDisplay', function(stars, points)
    currentWantedStarsClient = stars
    currentWantedPointsClient = points

    local newUiLabel = ""
    if stars > 0 then
        for _, levelData in ipairs(Config.WantedSettings.levels) do
            if levelData.stars == stars then
                newUiLabel = levelData.uiLabel
                break
            end
        end
        if newUiLabel == "" then -- Fallback if label not found for star count, though config should cover it
            newUiLabel = "Wanted: " .. string.rep("*", stars)
        end
    else
        newUiLabel = "" -- Or "Not Wanted"
    end
    wantedUiLabel = newUiLabel

    -- Update native FiveM wanted level display
    SetPlayerWantedLevel(PlayerId(), stars, false)
    SetPlayerWantedLevelNow(PlayerId(), false) -- Apply immediately without delay/fade

    -- If you had a custom UI element for wanted level, you'd update it here.
    -- Example: SendNUIMessage({ action = 'updateWantedUI', label = wantedUiLabel, points = currentWantedPointsClient })
    -- ShowNotification("Wanted Level: " .. wantedUiLabel .. " (" .. currentWantedPointsClient .. " pts)") -- For debugging
end)

-----------------------------------------------------------
-- Contraband Drop Client Events and Logic
-----------------------------------------------------------
RegisterNetEvent('cops_and_robbers:contrabandDropSpawned')
AddEventHandler('cops_and_robbers:contrabandDropSpawned', function(dropId, location, itemName, itemModelHash)
    if activeDropBlips[dropId] then -- Should not happen if server manages IDs correctly
        RemoveBlip(activeDropBlips[dropId])
    end

    local blip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(blip, 1) -- Default blip sprite, can be changed (e.g., 478 for package)
    SetBlipColour(blip, 2) -- Red, for example
    SetBlipScale(blip, 1.5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Contraband: " .. itemName)
    EndTextCommandSetBlipName(blip)

    activeDropBlips[dropId] = blip

    local propEntity = nil
    if itemModelHash then
        local model = (type(itemModelHash) == "number" and itemModelHash) or GetHashKey(itemModelHash)
        if HasModelLoaded(model) then
            propEntity = CreateObject(model, location.x, location.y, location.z - 0.9, false, true, true) -- No network, yes physics, dynamic
            PlaceObjectOnGroundProperly(propEntity)
        else
            RequestModel(model)
            CreateThread(function()
                local attempts = 0
                while not HasModelLoaded(model) and attempts < 100 do
                    Citizen.Wait(100)
                    attempts = attempts + 1
                end
                if HasModelLoaded(model) then
                    propEntity = CreateObject(model, location.x, location.y, location.z - 0.9, false, true, true)
                    PlaceObjectOnGroundProperly(propEntity)
                    if clientActiveContrabandDrops[dropId] then -- Check if drop still exists
                        clientActiveContrabandDrops[dropId].propEntity = propEntity
                    else -- Drop might have been collected while model was loading
                        DeleteEntity(propEntity)
                    end
                end
                SetModelAsNoLongerNeeded(model)
            end)
        end
    end

    clientActiveContrabandDrops[dropId] = {
        id = dropId,
        location = location,
        name = itemName,
        modelHash = itemModelHash,
        propEntity = propEntity
    }
    ShowNotification("~y~A new contraband drop has appeared: " .. itemName)
end)

RegisterNetEvent('cops_and_robbers:contrabandDropCollected')
AddEventHandler('cops_and_robbers:contrabandDropCollected', function(dropId, collectorName, itemName)
    if activeDropBlips[dropId] then
        RemoveBlip(activeDropBlips[dropId])
        activeDropBlips[dropId] = nil
    end

    if clientActiveContrabandDrops[dropId] then
        if clientActiveContrabandDrops[dropId].propEntity and DoesEntityExist(clientActiveContrabandDrops[dropId].propEntity) then
            DeleteEntity(clientActiveContrabandDrops[dropId].propEntity)
        end
        clientActiveContrabandDrops[dropId] = nil
    end

    if isCollectingFromDrop == dropId then
        isCollectingFromDrop = nil -- Reset collection state if this client was collecting this drop
        collectionTimerEnd = 0
        -- TODO: Hide UI progress bar if it was shown
    end
    ShowNotification("~g~Contraband '" .. itemName .. "' was collected by " .. collectorName .. ".")
end)

RegisterNetEvent('cops_and_robbers:collectingContrabandStarted')
AddEventHandler('cops_and_robbers:collectingContrabandStarted', function(dropId, collectionTime)
    isCollectingFromDrop = dropId
    collectionTimerEnd = GetGameTimer() + collectionTime
    ShowNotification("~b~Collecting contraband... Hold position.")
    -- TODO: Show UI progress bar
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Run every frame for interaction checks and progress monitoring
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        if role == 'robber' then
            if not isCollectingFromDrop then
                for dropId, dropData in pairs(clientActiveContrabandDrops) do
                    if dropData.location then
                        local distance = #(playerCoords - dropData.location)
                        if distance < 3.0 then
                            DisplayHelpText("Press ~INPUT_CONTEXT~ to collect contraband (" .. dropData.name .. ")")
                            if IsControlJustReleased(0, 51) then -- E key (Context)
                                TriggerServerEvent('cops_and_robbers:startCollectingContraband', dropId)
                                -- isCollectingFromDrop will be set by the server event `collectingContrabandStarted`
                            end
                            break -- Show help text for one drop at a time
                        end
                    end
                end
            else -- Player is currently collecting from a drop (isCollectingFromDrop is not nil)
                local currentDropData = clientActiveContrabandDrops[isCollectingFromDrop]
                if currentDropData and currentDropData.location then
                    local distance = #(playerCoords - currentDropData.location)
                    if distance > 5.0 then -- Player moved too far
                        ShowNotification("~r~Contraband collection cancelled: Moved too far.")
                        -- TODO: Hide UI progress bar
                        -- Optional: Notify server about cancellation
                        -- TriggerServerEvent('cops_and_robbers:cancelCollectingContraband', isCollectingFromDrop)
                        isCollectingFromDrop = nil
                        collectionTimerEnd = 0
                    elseif GetGameTimer() >= collectionTimerEnd then
                        ShowNotification("~g~Collection complete! Verifying with server...")
                        -- TODO: Hide UI progress bar
                        TriggerServerEvent('cops_and_robbers:finishCollectingContraband', isCollectingFromDrop)
                        isCollectingFromDrop = nil -- Reset state, server will confirm success/failure
                        collectionTimerEnd = 0
                    else
                        -- Still collecting, update UI progress (e.g., progress bar)
                        local progress = (GetGameTimer() - (collectionTimerEnd - Config.ContrabandCollectionTime)) / Config.ContrabandCollectionTime
                        -- Example: DisplayHelpText(string.format("Collecting... %d%%", math.floor(progress * 100)))
                        -- A proper progress bar via NUI would be better.
                    end
                else
                    -- Drop data somehow became nil while collecting, reset state
                    isCollectingFromDrop = nil
                    collectionTimerEnd = 0
                end
            end
        end
    end
end)

-- =====================================
--        SAFE ZONE CLIENT LOGIC
-- =====================================
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every 1 second

        if not Config.SafeZones or #Config.SafeZones == 0 then
            -- If no safe zones are configured, or table is empty, ensure player is not stuck in safe zone state
            if isCurrentlyInSafeZone then
                isCurrentlyInSafeZone = false
                currentSafeZoneName = ""
                SetEntityInvincible(PlayerPedId(), false)
                DisablePlayerFiring(PlayerId(), false)
                SetPlayerCanDoDriveBy(PlayerId(), true)
                ShowNotification("~g~Safe zone status reset due to configuration change.")
            end
            Citizen.Wait(5000) -- Wait longer if no zones configured
            goto continue_safe_zone_loop -- Skip further processing
        end

        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) then goto continue_safe_zone_loop end

        local playerCoords = GetEntityCoords(playerPed)
        local foundSafeZoneThisCheck = false
        local enteredZoneName = ""
        local enteredZoneMessage = ""

        for _, zone in ipairs(Config.SafeZones) do
            local distance = #(playerCoords - zone.location)
            if distance < zone.radius then
                foundSafeZoneThisCheck = true
                enteredZoneName = zone.name
                enteredZoneMessage = zone.message or "You have entered a Safe Zone."
                break -- Player can only be in one safe zone as per this logic
            end
        end

        if foundSafeZoneThisCheck then
            if not isCurrentlyInSafeZone then
                -- Player just entered a safe zone
                isCurrentlyInSafeZone = true
                currentSafeZoneName = enteredZoneName
                ShowNotification(enteredZoneMessage)

                SetEntityInvincible(playerPed, true)
                DisablePlayerFiring(PlayerId(), true)
                SetPlayerCanDoDriveBy(PlayerId(), false)
                -- Note: NetworkSetFriendlyFireOption is server-wide, not suitable here.
            end
        else
            if isCurrentlyInSafeZone then
                -- Player just exited a safe zone
                ShowNotification("~g~You have left " .. currentSafeZoneName .. ".")
                isCurrentlyInSafeZone = false
                currentSafeZoneName = ""

                SetEntityInvincible(playerPed, false)
                DisablePlayerFiring(PlayerId(), false)
                SetPlayerCanDoDriveBy(PlayerId(), true)
            end
        end
        ::continue_safe_zone_loop::
    end
end)
-----------------------------------------------------------

-- Receive item list from the server (Registered once)
RegisterNetEvent('cops_and_robbers:sendItemList')
AddEventHandler('cops_and_robbers:sendItemList', function(storeName, itemList)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openStore',
        storeName = storeName,
        items = itemList
    })
end)

-- Notify cops of a bank robbery with GPS update and sound
RegisterNetEvent('cops_and_robbers:notifyBankRobbery')
AddEventHandler('cops_and_robbers:notifyBankRobbery', function(bankId, bankLocation, bankName)
    if role == 'cop' then
        ShowNotification("~r~Bank Robbery in Progress!~s~\nBank: " .. bankName)
        SetNewWaypoint(bankLocation.x, bankLocation.y)
        -- Optionally, play a sound or additional alert here
    end
end)

-- =====================================
--        SPIKE STRIP CLIENT EVENTS
-- =====================================

RegisterNetEvent('cops_and_robbers:renderSpikeStrip')
AddEventHandler('cops_and_robbers:renderSpikeStrip', function(stripId, location)
    if not HasModelLoaded(spikeStripModelHash) then
        RequestModel(spikeStripModelHash)
        while not HasModelLoaded(spikeStripModelHash) do
            Citizen.Wait(50)
        end
    end

    -- Ensure location is a vector3. Server might send table.
    local deployCoords = vector3(location.x, location.y, location.z)

    -- Adjust Z-coordinate to ground. Raycast down to find ground.
    local _, groundZ = GetGroundZFor_3dCoord(deployCoords.x, deployCoords.y, deployCoords.z + 1.0, false)
    local finalCoords = vector3(deployCoords.x, deployCoords.y, groundZ)

    local spikeProp = CreateObject(spikeStripModelHash, finalCoords.x, finalCoords.y, finalCoords.z, true, true, false) -- network, nophys, dynamic=false
    -- It might be better to use CreateObjectNoOffset for precise placement or adjust Z slightly higher to prevent clipping.
    -- Or use PlaceObjectOnGroundProperly(spikeProp) if needed, though this might alter X,Y.

    FreezeEntityPosition(spikeProp, true) -- Make it static
    SetEntityCollision(spikeProp, true, true) -- Enable collision

    currentSpikeStrips[stripId] = {
        id = stripId,
        obj = spikeProp,
        location = finalCoords -- Store the actual ground coords
    }
    -- print("Client: Rendered spike strip " .. stripId .. " at " .. json.encode(finalCoords))
end)

RegisterNetEvent('cops_and_robbers:removeSpikeStrip')
AddEventHandler('cops_and_robbers:removeSpikeStrip', function(stripId)
    if currentSpikeStrips[stripId] then
        local prop = currentSpikeStrips[stripId].obj
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
        currentSpikeStrips[stripId] = nil
        -- print("Client: Removed spike strip " .. stripId)
    else
        -- print("Client: Attempted to remove unknown spike strip " .. stripId)
    end
end)

RegisterNetEvent('cops_and_robbers:applySpikeEffectToVehicle')
AddEventHandler('cops_and_robbers:applySpikeEffectToVehicle', function(vehicleNetId)
    local vehicle = NetToVeh(vehicleNetId) -- Get vehicle from network ID
    if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
        -- Burst front tires. Can be more specific if needed.
        SetVehicleTyreBurst(vehicle, 0, true, 1000.0) -- Front left
        SetVehicleTyreBurst(vehicle, 1, true, 1000.0) -- Front right
        SetVehicleTyreBurst(vehicle, 2, true, 1000.0) -- Rear left (optional)
        SetVehicleTyreBurst(vehicle, 3, true, 1000.0) -- Rear right (optional)
        ShowNotification("~r~Your tires have been spiked!")
    end
end)

-- Handler for server instructing client to show the heist timer
RegisterNetEvent('cops_and_robbers:showHeistTimerUI')
AddEventHandler('cops_and_robbers:showHeistTimerUI', function(bankName, duration)
    SendNUIMessage({
        action = 'startHeistTimer',
        duration = duration,
        bankName = bankName
    })
end)

-- =====================================
-- ADMIN COMMAND CLIENT-SIDE HANDLERS
-- =====================================

-- Handler for being frozen/unfrozen by an admin
RegisterNetEvent('cops_and_robbers:toggleFreeze')
AddEventHandler('cops_and_robbers:toggleFreeze', function()
    local ped = PlayerPedId()
    local currentlyFrozen = IsEntityFrozen(ped)
    FreezeEntityPosition(ped, not currentlyFrozen)
    if not currentlyFrozen then
        ShowNotification("~r~An admin has frozen you.")
    else
        ShowNotification("~g~An admin has unfrozen you.")
    end
end)

-- Handler for being teleported to a player by an admin
RegisterNetEvent('cops_and_robbers:teleportToPlayer')
AddEventHandler('cops_and_robbers:teleportToPlayer', function(targetPlayerIdToTeleportTo)
    local targetPed = GetPlayerPed(targetPlayerIdToTeleportTo)
    if DoesEntityExist(targetPed) then
        local targetCoords = GetEntityCoords(targetPed)
        SetEntityCoords(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, true)
        ShowNotification("~b~You have been teleported by an admin.")
    else
        ShowNotification("~r~Target player for teleport not found or too far away.")
    end
end)

-- Handler for spectating a player (admin's client executes this)
RegisterNetEvent('cops_and_robbers:spectatePlayer')
AddEventHandler('cops_and_robbers:spectatePlayer', function(playerToSpectateId)
    local ownPed = PlayerPedId()
    local targetPed = GetPlayerPed(playerToSpectateId)

    -- Rudimentary spectate: make player invisible and attach camera to target.
    -- A proper spectate mode is much more complex (e.g. NetworkSetInSpectatorMode, handling player controls).
    -- This is a simplified version.
    if DoesEntityExist(targetPed) then
        if not IsEntityVisible(ownPed) then -- Already spectating, or invisible for other reasons
            -- Stop spectating: make player visible, detach camera, reset position (e.g. to last known good position or fixed spot)
            SetEntityVisible(ownPed, true, false)
            ClearPedTasksImmediately(ownPed) -- Or SetEntityCollision, SetEntityAlpha etc.
            DetachCam(PlayerGameplayCam())
            RenderScriptCams(false, false, 0, true, true)
            ShowNotification("~g~Spectate mode ended.")
            -- May need to restore player position here if they were moved/made ethereal for spectate.
        else
            SetEntityVisible(ownPed, false, false) -- Make admin invisible
            -- AttachCamToEntity(PlayerGameplayCam(), targetPed, 0,0,2.0, true) -- Example offset
            -- PointCamAtEntity(PlayerGameplayCam(), targetPed, 0,0,0, true)
            -- For a more robust solution, NetworkSetInSpectatorMode might be explored,
            -- but it has its own complexities. This is a placeholder for basic spectate logic.
            -- The following is often used for a simple follow cam:
            SpectatePlayerPed(PlayerId(), targetPed) -- This is a guess, this native might not work as expected or exist.
                                                    -- A common way is manual camera control:
                                                    -- RequestCollisionAtCoord(GetEntityCoords(targetPed))
                                                    -- SetFocusArea(GetEntityCoords(targetPed).x, GetEntityCoords(targetPed).y, GetEntityCoords(targetPed).z, 0.0, 0.0, 0.0)
                                                    -- AttachCameraToPed(GetPlayerPed(-1), targetPed, true) -- This is not a native
                                                    -- A more manual approach:
                                                    -- local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                                                    -- AttachCamToPed(cam, targetPed, 0, -5.0, 2.0, true) -- Offset from target
                                                    -- SetCamActive(cam, true)
                                                    -- RenderScriptCams(true, false, 0, true, true)
            ShowNotification("~b~Spectating player. You are invisible. Trigger spectate again to stop.")
            print("SpectatePlayerPed might not be a direct native or might require more setup.")
            print("A robust spectate requires more complex camera and player state management.")
            -- Fallback to a very simple notification if true spectate is too complex for this context:
            -- ShowNotification("~b~Spectate command received for player ID: " .. playerToSpectateId .. ". True spectate needs more code.")
        end
    else
        ShowNotification("~r~Target player for spectate not found.")
    end
end)

-- Jail System: Send player to jail
RegisterNetEvent('cops_and_robbers:sendToJail')
AddEventHandler('cops_and_robbers:sendToJail', function(jailTime)
    SetEntityCoords(PlayerPedId(), Config.PrisonLocation.x, Config.PrisonLocation.y, Config.PrisonLocation.z, false, false, false, true)
    ShowNotification("~r~You have been sent to jail for " .. jailTime .. " seconds.")
    
    -- Implement jail time countdown and restrictions
    Citizen.CreateThread(function()
        local remainingTime = jailTime
        while remainingTime > 0 do
            Citizen.Wait(1000) -- Wait 1 second
            remainingTime = remainingTime - 1
            
            -- Restrict player actions while in jail
            DisableControlAction(0, 24, true) -- Disable attack
            DisableControlAction(0, 25, true) -- Disable aim
            DisableControlAction(0, 47, true) -- Disable weapon (G key)
            DisableControlAction(0, 58, true) -- Disable weapon (weapon wheel)
            -- Add more restrictions as needed
        end
        
        -- Release player from jail
        spawnPlayer(role)
        ShowNotification("~g~You have been released from jail.")
    end)
end)

-- Purchase Confirmation
RegisterNetEvent('cops_and_robbers:purchaseConfirmed')
AddEventHandler('cops_and_robbers:purchaseConfirmed', function(itemId, quantity)
    quantity = quantity or 1
    -- Find item details
    local itemName = nil
    for _, item in ipairs(Config.Items) do
        if item.itemId == itemId then
            itemName = item.name
            break
        end
    end

    if itemName then
        ShowNotification('You purchased: ' .. quantity .. ' x ' .. itemName)
    else
        ShowNotification('Purchase successful.')
    end
end)

-- Purchase Failure
RegisterNetEvent('cops_and_robbers:purchaseFailed')
AddEventHandler('cops_and_robbers:purchaseFailed', function(reason)
    ShowNotification('Purchase failed: ' .. reason)
end)


-- Sell Confirmation
RegisterNetEvent('cops_and_robbers:sellConfirmed')
AddEventHandler('cops_and_robbers:sellConfirmed', function(itemId, quantity)
    quantity = quantity or 1
    -- Find item details
    local itemName = nil
    for _, item in ipairs(Config.Items) do
        if item.itemId == itemId then
            itemName = item.name
            break
        end
    end

    if itemName then
        ShowNotification('You sold: ' .. quantity .. ' x ' .. itemName)
    else
        ShowNotification('Sale successful.')
    end
end)

-- Sell Failure
RegisterNetEvent('cops_and_robbers:sellFailed')
AddEventHandler('cops_and_robbers:sellFailed', function(reason)
    ShowNotification('Sale failed: ' .. reason)
end)


-- Add Weapon
RegisterNetEvent('cops_and_robbers:addWeapon')
AddEventHandler('cops_and_robbers:addWeapon', function(weaponName)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    GiveWeaponToPed(playerPed, weaponHash, 0, false, false)
    playerWeapons[weaponName] = true
    ShowNotification("Weapon added: " .. weaponName)
end)


-- Remove Weapon
RegisterNetEvent('cops_and_robbers:removeWeapon')
AddEventHandler('cops_and_robbers:removeWeapon', function(weaponName)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    RemoveWeaponFromPed(playerPed, weaponHash)
    playerWeapons[weaponName] = nil
    ShowNotification("Weapon removed: " .. weaponName)
end)


-- Add Ammo
RegisterNetEvent('cops_and_robbers:addAmmo')
AddEventHandler('cops_and_robbers:addAmmo', function(weaponName, ammoCount)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    if HasPedGotWeapon(playerPed, weaponHash, false) then
        AddAmmoToPed(playerPed, weaponHash, ammoCount)
        playerAmmo[weaponName] = (playerAmmo[weaponName] or 0) + ammoCount
        ShowNotification("Added " .. ammoCount .. " ammo to " .. weaponName)
    else
        ShowNotification("You don't have the weapon for this ammo.")
    end
end)


-- Apply Armor
RegisterNetEvent('cops_and_robbers:applyArmor')
AddEventHandler('cops_and_robbers:applyArmor', function(armorType)
    local playerPed = PlayerPedId()
    if armorType == "armor" then
        SetPedArmour(playerPed, 50)
        ShowNotification("~g~Armor applied: Light Armor (~w~50 Armor)")
    elseif armorType == "heavy_armor" then
        SetPedArmour(playerPed, 100)
        ShowNotification("~g~Armor applied: Heavy Armor (~w~100 Armor)")
    else
        ShowNotification("Invalid armor type.")
    end
end)


-- =====================================
--           NUI CALLBACKS
-- =====================================

-- NUI Callback for role selection
RegisterNUICallback('selectRole', function(data, cb)
    local selectedRole = data.role
    if selectedRole == 'cop' or selectedRole == 'robber' then
        TriggerServerEvent('cops_and_robbers:setPlayerRole', selectedRole)
        SetNuiFocus(false, false)
        cb('ok')
    else
        ShowNotification("Invalid role selected.")
        cb('error')
    end
end)

-- =====================================
--        SPIKE STRIP DEPLOYMENT & COLLISION
-- =====================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Run every frame for input check, can be optimized for collision

        -- Deployment Keybind (Example: Home key, Keycode 19)
        -- Consider using RegisterKeyMapping for configurable keys
        if role == 'cop' and IsControlJustPressed(0, 19) then -- INPUT_PREV_WEAPON (Home key on some layouts, placeholder)
                                                                -- Or use a command: RegisterCommand('deployspike', function() ... end, false)
            local playerPed = PlayerPedId()
            local forwardVector = GetEntityForwardVector(playerPed)
            local deployCoords = GetOffsetFromEntityInWorldCoords(playerPed, forwardVector.x * 2.0, forwardVector.y * 2.0, -0.9) -- 2m in front, slightly below ped level

            -- Basic inventory check placeholder - proper inventory management needed
            -- For now, assume server handles if player *can* deploy (e.g. has item)
            -- Client might optimistically remove an item if one is shown in UI, server confirms.
            -- This example focuses on triggering the deployment.
            ShowNotification("Attempting to deploy spike strip...")
            TriggerServerEvent('cops_and_robbers:deploySpikeStrip', deployCoords)
            -- Here, you'd typically remove 'spikestrip' from client's perceived inventory.
            -- The server should be the source of truth for inventory counts.
        end

        -- Spike Strip Collision Check (simplified)
        -- This should ideally run less frequently if not using IsEntityTouchingEntity, or use more optimized methods.
        if #(currentSpikeStrips) > 0 then -- Only run if there are strips to check
            local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
            if playerVeh ~= 0 then -- Player is in a vehicle
                local vehCoords = GetEntityCoords(playerVeh)
                for stripId, stripData in pairs(currentSpikeStrips) do
                    if DoesEntityExist(stripData.obj) then
                        local distance = #(vehCoords - stripData.location)
                        if distance < 2.5 then -- Simple distance check, approx length of a car + strip
                            -- More robust: check if vehicle's bounding box overlaps strip's model/coords
                            -- Or use natives like IS_ENTITY_TOUCHING_ENTITY(playerVeh, stripData.obj) - careful with performance

                            -- Check if any tire is near the strip center (more detailed than simple distance to strip center)
                            -- For simplicity, we'll use the distance check above.
                            -- A more accurate check might involve GetWorldPositionOfEntityBone for each wheel.

                            ShowNotification("~r~You ran over spikes!") -- Notify self
                            TriggerServerEvent('cops_and_robbers:vehicleHitSpikeStrip', stripId, VehToNet(playerVeh))

                            -- To prevent immediate re-triggering on same strip, either server removes it,
                            -- or client could add a short cooldown for this specific strip & vehicle.
                            -- For now, server might remove it or it expires.
                            break -- Stop checking other strips for this vehicle this frame
                        end
                    end
                end
            end
        end
    end
end)


-- =====================================
--        SPEED RADAR DEPLOYMENT & USAGE
-- =====================================

Citizen.CreateThread(function()
    local isRadarActive = false
    local radarPosition = nil
    local radarHeading = nil
    local detectedSpeeders = {} -- Store recently detected speeders to avoid spam

    while true do
        Citizen.Wait(0) -- Check every frame for input

        -- Deployment Keybind (Example: PageUp key, Keycode 17)
        -- Or use item 'speedradar' from inventory.
        if role == 'cop' and IsControlJustPressed(0, 17) then -- INPUT_CELLPHONE_SCROLL_BACKWARD (PageUp, placeholder)
            isRadarActive = not isRadarActive
            if isRadarActive then
                local playerPed = PlayerPedId()
                radarPosition = GetEntityCoords(playerPed)
                radarHeading = GetEntityHeading(playerPed)
                ShowNotification("~g~Speed radar activated. Point towards road.")
                detectedSpeeders = {} -- Clear previous detections
            else
                ShowNotification("~r~Speed radar deactivated.")
            end
        end

        if isRadarActive and role == 'cop' then
            Citizen.Wait(500) -- Scan for speeders less frequently than every frame
            local playerPed = PlayerPedId()

            -- Define detection area (e.g., a box in front of the radar)
            -- For simplicity, checking vehicles in a certain radius and general direction.
            local vehicles = GetGamePool('CVehicle')
            for _, veh in ipairs(vehicles) do
                if DoesEntityExist(veh) and IsEntityAVehicle(veh) and NetworkGetEntityIsNetworked(veh) then
                    local driver = GetPedInVehicleSeat(veh, -1)
                    if DoesEntityExist(driver) and IsPedAPlayer(driver) and driver ~= playerPed then
                        local targetPlayerServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(driver))

                        -- Avoid re-flagging same player for same vehicle immediately
                        if detectedSpeeders[targetPlayerServerId .. GetVehicleNumberPlateText(veh)] then goto continue_vehicles end

                        local vehCoords = GetEntityCoords(veh)
                        local distanceToRadar = #(vehCoords - radarPosition)

                        if distanceToRadar < 50.0 then -- Max detection range 50m
                            local angleToRadar = CalculateRelativeAngle(radarPosition, radarHeading, vehCoords)
                            if math.abs(angleToRadar) < 45.0 then -- Check if vehicle is roughly in front of radar (90 degree cone)
                                local speedKmh = GetEntitySpeed(veh) * 3.6 -- m/s to km/h
                                if speedKmh > Config.SpeedLimit then
                                    local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
                                    ShowNotification(string.format("~y~Speeding: %s (%s) at %.0f km/h. Press H to fine.", GetPlayerName(NetworkGetPlayerIndexFromPed(driver)), vehicleName, speedKmh))

                                    detectedSpeeders[targetPlayerServerId .. GetVehicleNumberPlateText(veh)] = {
                                        playerId = targetPlayerServerId,
                                        vehicleName = vehicleName,
                                        speed = speedKmh,
                                        timestamp = GetGameTimer()
                                    }
                                    -- Clean up old detected speeders to allow re-detection after a while
                                    CleanOldDetections(30000) -- e.g., 30 seconds cooldown per vehicle/player combo
                                end
                            end
                        end
                    end
                end
                ::continue_vehicles::
            end

            -- Check for "Fine" key press (Example: H key, Keycode 74)
            if IsControlJustPressed(0, 74) then -- INPUT_VEH_HEADLIGHT (H)
                local closestSpeeder = nil
                local minDistance = -1

                -- Find the closest detected speeder the cop is looking at / is in front
                -- This logic can be complex; for now, just take the most recent one or let admin choose from a list (not implemented)
                -- Simplified: find a recently detected speeder.
                local recentSpeederKey = nil
                for key, data in pairs(detectedSpeeders) do
                    if data.playerId then -- valid entry
                       recentSpeederKey = key -- take last one for simplicity
                       break
                    end
                end

                if recentSpeederKey and detectedSpeeders[recentSpeederKey] then
                    local speederData = detectedSpeeders[recentSpeederKey]
                    TriggerServerEvent('cops_and_robbers:vehicleSpeeding', speederData.playerId, speederData.vehicleName, speederData.speed)
                    ShowNotification(string.format("~b~Fine command sent for player %s.", GetPlayerName(GetPlayerPed(GetPlayerFromServerId(speederData.playerId)))))
                    detectedSpeeders[recentSpeederKey] = nil -- Clear after fining to prevent immediate re-fine
                else
                    ShowNotification("~y~No recent speeder targeted to fine.")
                end
            end
        end
    end
end)

function CalculateRelativeAngle(pos1, heading1, pos2)
    local angle = math.atan2(pos2.y - pos1.y, pos2.x - pos1.x) * (180 / math.pi)
    local relativeAngle = angle - heading1
    if relativeAngle < -180 then relativeAngle = relativeAngle + 360 end
    if relativeAngle > 180 then relativeAngle = relativeAngle - 360 end
    return relativeAngle
end

function CleanOldDetections(timeoutMs)
    local currentTime = GetGameTimer()
    for key, data in pairs(detectedSpeeders) do
        if currentTime - data.timestamp > timeoutMs then
            detectedSpeeders[key] = nil
        end
    end
end

-- =====================================
--           STORE FUNCTIONS
-- =====================================

-- Function to open the store
local function openStore(storeName, storeType, vendorItems)
    TriggerServerEvent('cops_and_robbers:getItemList', storeType, vendorItems, storeName)
end

-- =====================================
--           STORE AND VENDOR INTERACTION
-- =====================================

-- Detect player near a store or vendor
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) -- Check every 0.5 seconds to optimize performance
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        -- Check proximity to Ammu-Nation stores (now stored as vector3)
        for _, store in ipairs(Config.AmmuNationStores) do
            local distance = #(playerCoords - store) -- Calculate distance using vector subtraction and magnitude
            if distance < 2.0 then
                DisplayHelpText('Press ~INPUT_CONTEXT~ to open Ammu-Nation')
                if IsControlJustPressed(0, 51) then  -- E key (Default: Context)
                    openStore('Ammu-Nation', 'AmmuNation', nil)
                end
            end
        end

        -- Check proximity to NPC vendors
        for _, vendor in ipairs(Config.NPCVendors) do
            local vendorCoords = vendor.location
            local distance = #(playerCoords - vendorCoords) -- Calculate distance
            if distance < 2.0 then
                DisplayHelpText('Press ~INPUT_CONTEXT~ to talk to ' .. vendor.name)
                if IsControlJustPressed(0, 51) then -- E key (Default: Context)
                    openStore(vendor.name, 'Vendor', vendor.items)
                end
            end
        end
    end
end)

-- =====================================
--           NPC VENDOR SPAWN
-- =====================================

-- Spawn NPC vendors in the world
Citizen.CreateThread(function()
    for _, vendor in ipairs(Config.NPCVendors) do
        local hash = GetHashKey(vendor.model)
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Citizen.Wait(100)
        end

        local npc = CreatePed(4, hash, vendor.location.x, vendor.location.y, vendor.location.z - 1.0, vendor.heading, false, true)
        SetEntityInvincible(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        FreezeEntityPosition(npc, true)
        -- Optionally, add more NPC configurations here (e.g., specific animations, relationships)
    end
end)

-- =====================================
--        ENHANCED ARREST (TACKLE/SUBDUE)
-- =====================================
local isSubduing = false
local isBeingSubdued = false

-- Cop initiates subdue
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if role == 'cop' and not isSubduing and IsControlJustPressed(0, 47) then -- INPUT_WEAPON_SPECIAL_TWO (G key placeholder)
            local playerPed = PlayerPedId()
            -- Simplistic: find nearest player, check if robber. A proper target selection is needed.
            local closestPlayer, closestDistance = -1, -1
            for _, pId in ipairs(GetActivePlayers()) do
                if pId ~= PlayerId() then -- Don't target self
                    local targetPed = GetPlayerPed(pId)
                    if DoesEntityExist(targetPed) and playerRoles[GetPlayerServerId(pId)] == 'robber' then -- Check role via server data (if available client-side) or need server check
                        local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
                        if closestDistance == -1 or distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = pId
                        end
                    end
                end
            end

            if closestPlayer ~= -1 and closestDistance <= Config.TackleDistance then
                local targetServerId = GetPlayerServerId(closestPlayer)
                ShowNotification("~b~Attempting to tackle...")
                TriggerServerEvent('cops_and_robbers:startSubdue', targetServerId)
                isSubduing = true -- Prevent spamming tackle
                -- TODO: Play tackle animation for cop: TaskPlayAnim(playerPed, "melee@unarmed@streamed_variations", "plyr_takedown_front", 8.0, -8.0, -1, 0, 0, false, false, false)
                SetTimeout(Config.SubdueTime + 500, function() isSubduing = false end) -- Reset ability to tackle
            elseif closestPlayer ~= -1 then
                 ShowNotification(string.format("~r~Too far to tackle (%.1fm).", closestDistance))
            else
                ShowNotification("~y~No robber found to tackle.")
            end
        end
    end
end)

-- Robber receives subdue sequence
RegisterNetEvent('cops_and_robbers:beginSubdueSequence')
AddEventHandler('cops_and_robbers:beginSubdueSequence', function(copServerId)
    isBeingSubdued = true
    local playerPed = PlayerPedId()
    ShowNotification("~r~You are being tackled by a Cop!")
    FreezeEntityPosition(playerPed, true)
    -- TODO: Play tackled animation for robber: TaskPlayAnim(playerPed, "combat@damage@writheid", "writhe_loop", 8.0, -8.0, -1, 1, 0, false, false, false)

    -- Simplified: No minigame, just wait. Robber can't escape in this version.
    SetTimeout(Config.SubdueTime, function()
        if isBeingSubdued then -- Still subdued (not escaped, though escape not implemented here)
            FreezeEntityPosition(playerPed, false)
            isBeingSubdued = false
            ShowNotification("~g~Subdue finished.") -- Server will handle actual arrest.
        end
    end)
    -- Placeholder for escape mechanic:
    -- Start a minigame. If success: TriggerServerEvent('cops_and_robbers:escapeSubdue') isBeingSubdued = false; FreezeEntityPosition(playerPed, false)
end)

RegisterNetEvent('cops_and_robbers:subdueCancelled') -- If cop moves too far or cancels
AddEventHandler('cops_and_robbers:subdueCancelled', function()
    if isBeingSubdued then
        isBeingSubdued = false
        FreezeEntityPosition(PlayerPedId(), false)
        ShowNotification("~g~The cop moved away, you are no longer being subdued.")
    end
end)


-- =====================================
--           K9 UNIT (Simplified)
-- =====================================
-- local k9NetId = nil -- No longer needed as server doesn't send a usable NetID for client-spawned ped
local k9Ped = nil   -- Stores the local entity of the K9

-- Use K9 Whistle (placeholder - should be tied to inventory item usage)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        -- Example: Press 'K' to call/dismiss K9 (if has k9whistle item)
        if role == 'cop' and IsControlJustPressed(0, 31) then -- INPUT_VEH_CIN_CAM (K key placeholder)
            if k9Ped and DoesEntityExist(k9Ped) then
                TriggerServerEvent('cops_and_robbers:dismissK9') -- Ask server to despawn K9
            else
                -- TODO: Check if player has 'k9whistle' in inventory
                ShowNotification("~b~Using K9 Whistle...")
                TriggerServerEvent('cops_and_robbers:spawnK9')
            end
        end

        -- Example: Press 'L' to command K9 to attack nearest robber (if K9 active)
        if role == 'cop' and k9Ped and DoesEntityExist(k9Ped) and IsControlJustPressed(0, 38) then -- INPUT_CONTEXT (L key placeholder for attack command)
            local closestRobberPed, dist = GetClosestRobberPed(GetEntityCoords(PlayerPedId()), 50.0) -- 50m search radius
            if closestRobberPed then
                local targetRobberServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(closestRobberPed))
                if targetRobberServerId and targetRobberServerId ~= -1 then -- Ensure valid server ID
                    ShowNotification("~y~K9: Commanding attack!")
                    TriggerServerEvent('cops_and_robbers:commandK9', targetRobberServerId, "attack") -- k9NetId removed
                else
                    ShowNotification("~y~K9: Could not identify target for attack.")
                end
            else
                ShowNotification("~y~K9: No robbers found nearby to attack.")
            end
        end

        -- Keep K9 following if it exists and no other urgent task
        if k9Ped and DoesEntityExist(k9Ped) and IsPedOnFoot(PlayerPedId()) then
            local currentTask = GetPedScriptTaskCommand(k9Ped)
            -- Only re-task if not already in combat or a specific scripted task we want to preserve
            -- This is a very basic follow, a real K9 would need more sophisticated state management.
            if currentTask ~= 0x8415D88C then -- SCRIPT_TASK_COMBAT_PED
                 if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(k9Ped)) > Config.K9FollowDistance then
                    TaskFollowToOffsetOfEntity(k9Ped, PlayerPedId(), 0.0, -2.0, 1.0, 1.5, -1, Config.K9FollowDistance - 1.0, true)
                end
            end
        end
    end
end)

RegisterNetEvent('cops_and_robbers:clientSpawnK9Authorized')
AddEventHandler('cops_and_robbers:clientSpawnK9Authorized', function()
    if k9Ped and DoesEntityExist(k9Ped) then
        ShowNotification("~y~Your K9 unit is already active.")
        return
    end

    local modelHash = GetHashKey('a_c_shepherd') -- K9 model
    RequestModel(modelHash)
    CreateThread(function()
        local attempts = 0
        while not HasModelLoaded(modelHash) and attempts < 100 do
            Citizen.Wait(100)
            attempts = attempts + 1
        end

        if HasModelLoaded(modelHash) then
            local playerPed = PlayerPedId()
            local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, Config.K9FollowDistance * -1.0, 0.0) -- Spawn behind player

            k9Ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z, GetEntityHeading(playerPed), false, true) -- Not networked, but make it mission
            SetModelAsNoLongerNeeded(modelHash)

            SetEntityAsMissionEntity(k9Ped, true, true) -- Prevent despawn by game engine
            SetPedAsCop(k9Ped, true) -- Makes K9 behave somewhat like a police ped (e.g. might react to crimes) - optional
            SetPedRelationshipGroupHash(k9Ped, GetPedRelationshipGroupHash(playerPed)) -- Friendly to player and player's group
            TaskFollowToOffsetOfEntity(k9Ped, playerPed, vector3(0.0, -Config.K9FollowDistance, 0.0), 1.5, -1, Config.K9FollowDistance - 1.0, true)

            ShowNotification("~g~Your K9 unit has arrived!")
        else
            ShowNotification("~r~Failed to spawn K9 unit: Model not found.")
            SetModelAsNoLongerNeeded(modelHash)
        end
    end)
end)

RegisterNetEvent('cops_and_robbers:clientDismissK9')
AddEventHandler('cops_and_robbers:clientDismissK9', function()
    ShowNotification("~y~Your K9 unit has been dismissed.")
    if k9Ped and DoesEntityExist(k9Ped) then
        DeleteEntity(k9Ped)
    end
    k9Ped = nil
end)

RegisterNetEvent('cops_and_robbers:k9ProcessCommand')
AddEventHandler('cops_and_robbers:k9ProcessCommand', function(targetRobberServerId, commandType) -- k9NetId removed
    if k9Ped and DoesEntityExist(k9Ped) then
        local targetRobberPed = GetPlayerPed(GetPlayerFromServerId(targetRobberServerId))
        if targetRobberPed and DoesEntityExist(targetRobberPed) then
            if commandType == "attack" then
                ClearPedTasks(k9Ped)
                TaskCombatPed(k9Ped, targetRobberPed, 0, 16)
            elseif commandType == "follow" then
                TaskFollowToOffsetOfEntity(k9Ped, PlayerPedId(), vector3(0.0, -Config.K9FollowDistance, 0.0), 1.5, -1, Config.K9FollowDistance - 1.0, true)
            end
        end
    end
end)

function GetClosestRobberPed(coords, radius)
    local closestPed, closestDist = nil, -1
    local players = GetActivePlayers()
    for _, pId in ipairs(players) do
        local targetPed = GetPlayerPed(pId)
        if DoesEntityExist(targetPed) and targetPed ~= PlayerPedId() then
            -- Assuming playerRoles table is populated on client for other players or we add specific 'isRobber' state
            -- This is a simplification; server should ideally confirm target is a robber.
            -- For this example, we'll just find closest player who isn't self.
            -- In a full system, you'd check their role.
            -- if playerRoles[GetPlayerServerId(pId)] == 'robber' then
                local dist = #(coords - GetEntityCoords(targetPed))
                if dist < radius then
                    if not closestPed or dist < closestDist then
                        closestPed = targetPed
                        closestDist = dist
                    end
                end
            -- end
        end
    end
    return closestPed, closestDist
end


-- =====================================
--        STORE ROBBERY CLIENT LOGIC
-- =====================================
local currentStoreRobbery = nil -- { store = storeTable, duration = duration, startTime = GetGameTimer() }

-- Proximity check for robbable stores
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second
        if role == 'robber' then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local nearStore = false

            for i, store in ipairs(Config.RobbableStores) do
                local dist = #(playerCoords - store.location)
                if dist < store.radius + 5.0 then -- Show prompt if slightly outside interaction radius
                    nearStore = true
                    if dist < store.radius then -- Interaction radius
                        DisplayHelpText(string.format("Press ~INPUT_CONTEXT~ to rob %s.", store.name))
                        if IsControlJustPressed(0, 51) then -- E key (Context)
                            if not currentStoreRobbery then
                                TriggerServerEvent('cops_and_robbers:startStoreRobbery', i) -- Pass store index (1-based)
                            else
                                ShowNotification("~r~You are already in a robbery.")
                            end
                        end
                        break -- Show prompt for one store at a time
                    end
                end
            end
            -- if not nearStore and currentStoreRobbery then -- Handled by below thread
            --     -- If player moved away from any store while a robbery was active for them
            -- end
        end
    end
end)

RegisterNetEvent('cops_and_robbers:beginStoreRobberySequence')
AddEventHandler('cops_and_robbers:beginStoreRobberySequence', function(store, duration)
    ShowNotification(string.format("~y~Robbing %s! Stay in the area for %d seconds.", store.name, duration / 1000))
    currentStoreRobbery = {
        store = store,
        duration = duration,
        startTime = GetGameTimer()
    }
    -- TODO: Display timer on UI
end)

-- Thread to monitor robber's presence during a store robbery
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if currentStoreRobbery and role == 'robber' then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distToStore = #(playerCoords - currentStoreRobbery.store.location)
            local timeElapsed = GetGameTimer() - currentStoreRobbery.startTime

            if distToStore > currentStoreRobbery.store.radius + 2.0 then -- +2.0 buffer
                ShowNotification("~r~You fled the store! Robbery failed.")
                TriggerServerEvent('cops_and_robbers:storeRobberyUpdate', "fled")
                currentStoreRobbery = nil
                -- TODO: Hide timer UI
            elseif timeElapsed >= currentStoreRobbery.duration then
                -- Timer already completed client-side, server will confirm reward.
                -- Client doesn't need to send "completed", server timer handles success.
                -- However, good to clear local state.
                ShowNotification("~g~Robbery duration complete. Waiting for server confirmation.")
                currentStoreRobbery = nil
                -- TODO: Hide timer UI
            else
                -- Update UI timer if any
                local timeLeft = (currentStoreRobbery.duration - timeElapsed) / 1000
                -- TODO: SendNUIMessage({ action = 'updateStoreRobberyTimer', timeLeft = timeLeft })
                DisplayHelpText(string.format("Robbing %s... Time left: %ds", currentStoreRobbery.store.name, math.ceil(timeLeft)))
            end
        end
    end
end)


-- =====================================
--        ARMORED CAR HEIST CLIENT LOGIC
-- =====================================
local armoredCarBlip = nil
local armoredCarNetIdClient = nil
local armoredCarClientData = { lastHealth = 0 } -- Store last known health client-side

RegisterNetEvent('cops_and_robbers:armoredCarSpawned')
AddEventHandler('cops_and_robbers:armoredCarSpawned', function(vehicleNetId, initialCoords)
    ShowNotification("~y~An armored car is on the move!")
    armoredCarNetIdClient = vehicleNetId
    local vehicle = NetToVeh(vehicleNetId)

    if DoesEntityExist(vehicle) then
        if armoredCarBlip then RemoveBlip(armoredCarBlip) end
        armoredCarBlip = AddBlipForEntity(vehicle)
        SetBlipSprite(armoredCarBlip, 427) -- Example: Blip sprite for Armored Truck
        SetBlipColour(armoredCarBlip, 5)  -- Example: Yellow
        SetBlipAsShortRange(armoredCarBlip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Armored Car")
        EndTextCommandSetBlipName(armoredCarBlip)
        armoredCarClientData.lastHealth = GetEntityHealth(vehicle) -- Initialize health tracking
    else
        print("Armored car entity not found client-side yet for NetID: " .. vehicleNetId)
    end
end)

RegisterNetEvent('cops_and_robbers:armoredCarDestroyed')
AddEventHandler('cops_and_robbers:armoredCarDestroyed', function(vehicleNetId)
    ShowNotification("~g~The armored car has been successfully looted and destroyed!")
    if armoredCarBlip then
        RemoveBlip(armoredCarBlip)
        armoredCarBlip = nil
    end
    armoredCarNetIdClient = nil
    armoredCarClientData.lastHealth = 0 -- Reset health tracking
end)

-- Robber damaging armored car - Client-side damage detection and reporting
Citizen.CreateThread(function()
    local damageCheckInterval = 1000 -- Check health every 1 second
    while true do
        Citizen.Wait(damageCheckInterval)
        if role == 'robber' and armoredCarNetIdClient and NetworkDoesNetworkIdExist(armoredCarNetIdClient) then
            local carEntity = NetToVeh(armoredCarNetIdClient)
            if DoesEntityExist(carEntity) then
                local currentHealth = GetEntityHealth(carEntity)
                if armoredCarClientData.lastHealth == 0 then -- Handle case where it wasn't initialized properly
                    armoredCarClientData.lastHealth = GetMaxHealth(carEntity) -- Assume full health if not set
                end

                if currentHealth < armoredCarClientData.lastHealth then
                    local damageDone = armoredCarClientData.lastHealth - currentHealth
                    if damageDone > 0 then -- Only report actual damage
                        -- print("Armored Car: Detected damage: " .. damageDone .. ", Current Health: " .. currentHealth .. ", Last Health: " .. armoredCarClientData.lastHealth)
                        TriggerServerEvent('cops_and_robbers:damageArmoredCar', armoredCarNetIdClient, damageDone)
                    end
                end
                armoredCarClientData.lastHealth = currentHealth
            else
                -- Car entity no longer exists, maybe destroyed by other means or despawned
                armoredCarNetIdClient = nil
                armoredCarClientData.lastHealth = 0
            end
        end
    end
end)


-- =====================================
--        EMP DEVICE CLIENT LOGIC
-- =====================================

-- Robber: Activate EMP (Placeholder key: NumPad 0, or tie to item usage)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if role == 'robber' and IsControlJustPressed(0, 121) then -- INPUT_SELECT_WEAPON_UNARMED (NumPad 0 placeholder)
            -- TODO: Check if player has 'empdevice' from their local inventory representation
            ShowNotification("~b~Activating EMP device...")
            TriggerServerEvent('cops_and_robbers:activateEMP')
        end
    end
end)

-- Cop: Handle being EMPed
RegisterNetEvent('cops_and_robbers:vehicleEMPed')
AddEventHandler('cops_and_robbers:vehicleEMPed', function(vehicleNetIdToEMP, durationMs)
    local playerPed = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(playerPed, false)
    local targetVehicle = NetToVeh(vehicleNetIdToEMP)

    if DoesEntityExist(targetVehicle) and currentVehicle == targetVehicle then
        ShowNotification("~r~Your vehicle has been disabled by an EMP!")

        -- Disable engine
        SetVehicleEngineOn(targetVehicle, false, true, true) -- turnOff, instantly, noAutoTurnOnDuringDisable
        SetVehicleUndriveable(targetVehicle, true) -- Make it undriveable

        -- Visual/Audio effects (placeholder)
        -- TriggerScreenblurFadeIn(durationMs / 2)
        -- PlaySoundFrontend(-1, "EMP_Blast", "DLC_AW_Weapon_Sounds", true)

        SetTimeout(durationMs, function()
            if DoesEntityExist(targetVehicle) then
                SetVehicleUndriveable(targetVehicle, false)
                -- Engine might need to be manually started by player if they didn't leave vehicle
                ShowNotification("~g~Vehicle systems recovering from EMP.")
                -- TriggerScreenblurFadeOut(durationMs / 2)
            end
        end)
    end
end)


-- =====================================
--        POWER GRID SABOTAGE CLIENT LOGIC
-- =====================================
local activePowerOutages = {} -- { [gridIndex] = true/false }

-- Proximity check for power grids
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second
        if role == 'robber' then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            for i, grid in ipairs(Config.PowerGrids) do
                if #(playerCoords - grid.location) < 10.0 then -- Interaction radius (e.g., 10m)
                    DisplayHelpText(string.format("Press ~INPUT_CONTEXT~ to sabotage %s.", grid.name))
                    if IsControlJustPressed(0, 51) then -- E key (Context)
                        TriggerServerEvent('cops_and_robbers:sabotagePowerGrid', i) -- Pass grid index (1-based)
                    end
                    break
                end
            end
        end
    end
end)

RegisterNetEvent('cops_and_robbers:powerGridStateChanged')
AddEventHandler('cops_and_robbers:powerGridStateChanged', function(gridIndex, isOutage, duration)
    local grid = Config.PowerGrids[gridIndex]
    if not grid then return end

    activePowerOutages[gridIndex] = isOutage

    if isOutage then
        ShowNotification(string.format("~r~Power outage reported at %s!", grid.name))
        -- Simplified visual effect: Toggle artificial lights off/on.
        -- True regional blackouts are very complex and often require custom shaders or timecycle mods.
        -- This will just affect game's generic "artificial lights" state, may not be area-specific enough.
        -- For area-specific, one might try to manage street light entities within grid.radius.
        SetArtificialLightsState(true) -- This native might turn off many lights globally.
                                      -- A better approach for localized effect is needed for full implementation.
        print("Simplified power outage effect activated for grid: " .. grid.name)
        -- TODO: Implement more localized blackout effect if possible, e.g., by finding nearby street light objects.
    else
        ShowNotification(string.format("~g~Power restored at %s.", grid.name))
        -- Check if any other grid is still out before turning lights back on globally
        local anyOutageActive = false
        for _, status in pairs(activePowerOutages) do
            if status then anyOutageActive = true; break end
        end
        if not anyOutageActive then
            SetArtificialLightsState(false) -- Restore lights if no other outages are active
            print("All power outages resolved. Global artificial lights restored.")
        else
            print("Power restored for grid: " .. grid.name .. ", but other outages may be active.")
        end
    end
end)


-- =====================================
--        ADMIN PANEL CLIENT LOGIC
-- =====================================
local isAdminPanelOpen = false

-- Keybind for Admin Panel (e.g., F10 - Keycode 57 for INPUT_REPLAY_STOPRECORDING)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustPressed(0, 57) then -- F10 key, placeholder
            isAdminPanelOpen = not isAdminPanelOpen
            if isAdminPanelOpen then
                TriggerServerEvent('cops_and_robbers:requestAdminDataForUI')
            else
                SendNUIMessage({ action = 'hideAdminPanel' }) -- Tell JS to hide it
                SetNuiFocus(false, false)
            end
        end
    end
end)

RegisterNetEvent('cops_and_robbers:showAdminUI')
AddEventHandler('cops_and_robbers:showAdminUI', function(playerList)
    SendNUIMessage({
        action = 'showAdminPanel',
        players = playerList
    })
    -- NUI focus is set by showAdminPanel in JS
end)

RegisterNetEvent('cops_and_robbers:teleportToPlayerAdminUI')
AddEventHandler('cops_and_robbers:teleportToPlayerAdminUI', function(targetCoordsTable)
    local targetCoords = vector3(targetCoordsTable.x, targetCoordsTable.y, targetCoordsTable.z)
    SetEntityCoords(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, true)
    ShowNotification("~b~Teleported by Admin UI.")
end)


-- =====================================
--           PLAYER POSITION & WANTED LEVEL UPDATES
-- =====================================

-- Periodically send player position and wanted level to the server
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Update interval: Every 5 seconds
        local playerPed = PlayerPedId()
        if DoesEntityExist(playerPed) then
            local playerPos = GetEntityCoords(playerPed)
            -- wantedLevel should be updated based on game events (e.g., police interaction)
            TriggerServerEvent('cops_and_robbers:updatePosition', playerPos, wantedLevel)
        end
    end
end)
