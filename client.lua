-- client.lua
-- Cops & Robbers FiveM Game Mode - Client Script
-- Version: 1.1 | Date: 2025-02-11
-- This file handles client-side functionality including UI notifications,
-- role selection, vendor interactions, spawning, and other game-related events.

-- =====================================
--           CONFIGURATION
-- =====================================

Config = {}

-- Define items available in the game
Config.Items = {
    { itemId = 1, name = "Health Kit" },
    { itemId = 2, name = "Armor" },
    { itemId = 3, name = "Bandage" },
    -- Add more items as needed
}

-- Define Ammu-Nation store locations (using vector3 for consistency)
Config.AmmuNationStores = {
    vector3(452.6, -980.0, 30.7),
    vector3(1693.4, 3760.2, 34.7),
    -- Add more Ammu-Nation store locations as needed
}

-- Define NPC vendors with standardized vector3 locations
Config.NPCVendors = {
    {
        name = "Gun Dealer",
        model = "s_m_m_gunsmith_01",
        location = vector3(2126.7, 4794.1, 41.1),
        heading = 90.0,
        items = { 1, 2, 3 } -- Item IDs from Config.Items
    },
    {
        name = "Weapon Trader",
        model = "s_m_m_gunsmith_02",
        location = vector3(256.5, -50.0, 69.2),
        heading = 45.0,
        items = { 2, 3 } -- Item IDs from Config.Items
    },
    -- Add more vendors as needed
}

-- Define spawn points for each role
Config.SpawnPoints = {
    cop = vector3(452.6, -980.0, 30.7),       -- Police station location
    robber = vector3(2126.7, 4794.1, 41.1)    -- Countryside airport location
}

-- Define prison location
Config.PrisonLocation = vector3(1651.0, 2570.0, 45.5) -- Prison coordinates

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
function ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawNotification(false, true)
end

-- Function to display help text
function DisplayHelpText(text)
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
function openStore(storeName, storeType, vendorItems)
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
            local distance = #(playerCoords - store)
            if distance < 2.0 then
                DisplayHelpText('Press ~INPUT_CONTEXT~ to open Ammu-Nation')
                if IsControlJustPressed(0, 51) then  -- E key
                    openStore('Ammu-Nation', 'AmmuNation', nil)
                end
            end
        end

        -- Check proximity to NPC vendors
        for _, vendor in ipairs(Config.NPCVendors) do
            local vendorCoords = vendor.location
            local distance = #(playerCoords - vendorCoords)
            if distance < 2.0 then
                DisplayHelpText('Press ~INPUT_CONTEXT~ to talk to ' .. vendor.name)
                if IsControlJustPressed(0, 51) then
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
        -- Optionally, add more NPC configurations here
    end
end)

-- =====================================
--           PLAYER POSITION & WANTED LEVEL UPDATES
-- =====================================

-- Periodically send player position and wanted level to the server
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Every 5 seconds
        local playerPed = PlayerPedId()
        if DoesEntityExist(playerPed) then
            local playerPos = GetEntityCoords(playerPed)
            TriggerServerEvent('cops_and_robbers:updatePosition', playerPos, wantedLevel)
        end
    end
end)
