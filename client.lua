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
local playerStats = { heists = 0, arrests = 0, rewards = 0, experience = 0, level = 1 }
local currentObjective = nil
local wantedLevel = 0
local playerWeapons = {}
local playerAmmo = {}

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
