-- client.lua

-- Variables and Data Structures
local role = nil
local playerCash = 0
local playerStats = { heists = 0, arrests = 0, rewards = 0, experience = 0, level = 1 }
local currentObjective = nil
local wantedLevel = 0
local playerWeapons = {}
local playerAmmo = {}

-- Request player data when the player spawns
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('cops_and_robbers:requestPlayerData')
end)

-- Receive player data from the server
RegisterNetEvent('cops_and_robbers:receivePlayerData')
AddEventHandler('cops_and_robbers:receivePlayerData', function(data)
    -- Give weapons back to the player
    local playerPed = PlayerPedId()
    for weaponName, _ in pairs(data.weapons) do
        local weaponHash = GetHashKey(weaponName)
        GiveWeaponToPed(playerPed, weaponHash, 0, false, false)
        playerWeapons[weaponName] = true
    end
    -- Restore inventory items if necessary
    -- Restore player money if you have a HUD to display it
end)

-- Weapon management functions
RegisterNetEvent('cops_and_robbers:addWeapon')
AddEventHandler('cops_and_robbers:addWeapon', function(weaponName)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    GiveWeaponToPed(playerPed, weaponHash, 0, false, false)
    playerWeapons[weaponName] = true
end)

RegisterNetEvent('cops_and_robbers:removeWeapon')
AddEventHandler('cops_and_robbers:removeWeapon', function(weaponName)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    RemoveWeaponFromPed(playerPed, weaponHash)
    playerWeapons[weaponName] = nil
end)

RegisterNetEvent('cops_and_robbers:addAmmo')
AddEventHandler('cops_and_robbers:addAmmo', function(weaponName, ammoCount)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    if HasPedGotWeapon(playerPed, weaponHash, false) then
        AddAmmoToPed(playerPed, weaponHash, ammoCount)
        playerAmmo[weaponName] = (playerAmmo[weaponName] or 0) + ammoCount
    else
        ShowNotification("You don't have the weapon for this ammo.")
    end
end)

-- Armor application
RegisterNetEvent('cops_and_robbers:applyArmor')
AddEventHandler('cops_and_robbers:applyArmor', function(armorType)
    local playerPed = PlayerPedId()
    if armorType == "armor" then
        SetPedArmour(playerPed, 50)
    elseif armorType == "heavy_armor" then
        SetPedArmour(playerPed, 100)
    end
end)

-- Event handler for purchase confirmation
RegisterNetEvent('cops_and_robbers:purchaseConfirmed')
AddEventHandler('cops_and_robbers:purchaseConfirmed', function(itemId, quantity)
    quantity = quantity or 1
    -- Find item details
    local itemName
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

-- Event handler for purchase failure
RegisterNetEvent('cops_and_robbers:purchaseFailed')
AddEventHandler('cops_and_robbers:purchaseFailed', function(reason)
    ShowNotification('Purchase failed: ' .. reason)
end)

-- Event handler for sell confirmation
RegisterNetEvent('cops_and_robbers:sellConfirmed')
AddEventHandler('cops_and_robbers:sellConfirmed', function(itemId, quantity)
    quantity = quantity or 1
    local itemName
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

-- Event handler for sell failure
RegisterNetEvent('cops_and_robbers:sellFailed')
AddEventHandler('cops_and_robbers:sellFailed', function(reason)
    ShowNotification('Sale failed: ' .. reason)
end)

-- Event handler to apply armor
RegisterNetEvent('cops_and_robbers:applyArmor')
AddEventHandler('cops_and_robbers:applyArmor', function(armorType)
    local playerPed = PlayerPedId()
    if armorType == "armor" then
        SetPedArmour(playerPed, 50)
    elseif armorType == "heavy_armor" then
        SetPedArmour(playerPed, 100)
    end
end)

-- Function to show notification
function ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawNotification(false, false)
end

-- NUI Callbacks
RegisterNUICallback('buyItem', function(data, cb)
    local itemId = data.itemId
    local quantity = data.quantity or 1
    TriggerServerEvent('cops_and_robbers:purchaseItem', itemId, quantity)
    cb('ok')
end)

RegisterNUICallback('sellItem', function(data, cb)
    local itemId = data.itemId
    local quantity = data.quantity or 1
    TriggerServerEvent('cops_and_robbers:sellItem', itemId, quantity)
    cb('ok')
end)

RegisterNUICallback('getPlayerInventory', function(data, cb)
    TriggerServerEvent('cops_and_robbers:getPlayerInventory')
    RegisterNetEvent('cops_and_robbers:sendPlayerInventory')
    AddEventHandler('cops_and_robbers:sendPlayerInventory', function(items)
        cb({ items = items })
    end)
end)

RegisterNUICallback('closeStore', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Function to open the store
function openStore(storeName, storeType, vendorItems)
    -- Request item list from server
    TriggerServerEvent('cops_and_robbers:getItemList', storeType, vendorItems)

    -- Receive item list from server
    RegisterNetEvent('cops_and_robbers:sendItemList')
    AddEventHandler('cops_and_robbers:sendItemList', function(itemList)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openStore',
            storeName = storeName,
            items = itemList
        })
    end)
end

-- Detect player near a store
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerCoords = GetEntityCoords(PlayerPedId())

        for _, store in ipairs(Config.AmmuNationStores) do
            local distance = #(playerCoords - vector3(store.x, store.y, store.z))
            if distance < 2.0 then
                DisplayHelpText('Press ~INPUT_CONTEXT~ to open Ammu-Nation')
                if IsControlJustPressed(0, 51) then  -- E key
                    openStore('Ammu-Nation', 'AmmuNation')
                end
            end
        end

        -- Handle NPC interactions
        for _, vendor in ipairs(Config.NPCVendors) do
            local distance = #(playerCoords - vector3(vendor.location.x, vendor.location.y, vendor.location.z))
            if distance < 2.0 then
                DisplayHelpText('Press ~INPUT_CONTEXT~ to talk to ' .. vendor.name)
                if IsControlJustPressed(0, 51) then
                    openStore(vendor.name, 'Vendor', vendor.items)
                end
            end
        end
    end
end)

-- Function to display help text
function DisplayHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Spawn NPC vendors
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
    end
end)

-- Import Configurations
local Config = Config

-- Initialize player role on resource start
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        TriggerServerEvent('cops_and_robbers:requestRole')
        displayRoleSelection()
    end
end)

-- Function to display role selection menu
function displayRoleSelection()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openRoleMenu' })
end

-- Receive role selection from NUI
RegisterNUICallback('selectRole', function(data, cb)
    role = data.role
    TriggerServerEvent('cops_and_robbers:setPlayerRole', role)
    SetNuiFocus(false, false)
    spawnPlayer(role)
    cb('ok')
end)

-- Spawn player based on role
function spawnPlayer(role)
    local spawnLocation = role == 'cop' and Config.CopSpawn or Config.RobberSpawn
    SetEntityCoords(PlayerPedId(), spawnLocation.x, spawnLocation.y, spawnLocation.z, false, false, false, true)
    -- Optionally, give initial weapons or items based on role
end

-- Receive and set player role from the server
RegisterNetEvent('cops_and_robbers:setRole')
AddEventHandler('cops_and_robbers:setRole', function(serverRole)
    role = serverRole
    spawnPlayer(role)
end)

-- Notify cops of a bank robbery with GPS update and sound
RegisterNetEvent('cops_and_robbers:notifyBankRobbery')
AddEventHandler('cops_and_robbers:notifyBankRobbery', function(bankId, bankLocation, bankName)
    if role == 'cop' then
        DisplayNotification("~r~Bank Robbery in Progress!~s~\nBank: " .. bankName)
        SetNewWaypoint(bankLocation.x, bankLocation.y)
    end
end)

-- Play sound notification for nearby cops
RegisterNetEvent('cops_and_robbers:playSound')
AddEventHandler('cops_and_robbers:playSound', function(sound)
    PlaySoundFrontend(-1, sound, "DLC_HEIST_FLEECA_SOUNDSET", true)
end)

-- Start the heist timer and update HUD
RegisterNetEvent('cops_and_robbers:startHeistTimer')
AddEventHandler('cops_and_robbers:startHeistTimer', function(bankId, time)
    SendNUIMessage({
        action = 'startHeistTimer',
        duration = time,
        bankName = Config.BankVaults[bankId].name
    })
end)

-- Display heist cooldown notification
RegisterNetEvent('cops_and_robbers:heistOnCooldown')
AddEventHandler('cops_and_robbers:heistOnCooldown', function()
    DisplayNotification("~r~You are currently on cooldown for attempting a heist.")
end)

-- Reward robbers with randomized amount and update stats
RegisterNetEvent('cops_and_robbers:receiveReward')
AddEventHandler('cops_and_robbers:receiveReward', function(amount)
    DisplayNotification("~g~Heist successful! Reward: $" .. amount)
    playerStats.rewards = playerStats.rewards + amount
    playerCash = playerCash + amount
    addExperience(500) -- Award experience for successful heist
end)

-- Arrest notification
RegisterNetEvent('cops_and_robbers:arrestNotification')
AddEventHandler('cops_and_robbers:arrestNotification', function(copId)
    DisplayNotification("~r~You have been arrested by " .. GetPlayerName(GetPlayerFromServerId(copId)) .. "!")
    wantedLevel = 0 -- Reset wanted level upon arrest
end)

-- Helper function to display notifications on screen
function DisplayNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, true)
end

-- Draw custom text on screen
function DrawCustomText(x, y, text)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Experience and Leveling System
function addExperience(amount)
    playerStats.experience = playerStats.experience + amount
    checkLevelUp()
end

function checkLevelUp()
    local currentLevel = playerStats.level
    local nextLevelExp = Config.Experience.Levels[currentLevel + 1] and Config.Experience.Levels[currentLevel + 1].exp or nil
    if nextLevelExp and playerStats.experience >= nextLevelExp then
        playerStats.level = playerStats.level + 1
        DisplayNotification("~b~You leveled up to Level " .. playerStats.level .. "!")
        giveLevelUpRewards()
    end
end

function giveLevelUpRewards()
    local rewards = Config.Experience.Rewards[role][playerStats.level]
    if rewards then
        if rewards.cash then
            playerCash = playerCash + rewards.cash
            DisplayNotification("~g~You received $" .. rewards.cash .. " as a level-up reward!")
        end
        if rewards.item then
            -- Give item to player (implementation depends on inventory system)
            DisplayNotification("~g~You received a " .. rewards.item .. " as a level-up reward!")
        end
    end
end

-- Wanted Level System
function increaseWantedLevel(amount)
    wantedLevel = math.min(wantedLevel + amount, 5)
    DisplayNotification("~r~Your wanted level increased to " .. wantedLevel .. "!")
    -- Update HUD or minimap with wanted level
end

function decreaseWantedLevel(amount)
    wantedLevel = math.max(wantedLevel - amount, 0)
    DisplayNotification("~g~Your wanted level decreased to " .. wantedLevel .. ".")
    -- Update HUD or minimap with wanted level
end

-- Jail System
RegisterNetEvent('cops_and_robbers:sendToJail')
AddEventHandler('cops_and_robbers:sendToJail', function(jailTime)
    local jailLocation = vector3(1651.0, 2570.0, 45.5) -- Prison location
    SetEntityCoords(PlayerPedId(), jailLocation.x, jailLocation.y, jailLocation.z, false, false, false, true)
    DisplayNotification("~r~You have been sent to jail for " .. jailTime .. " seconds.")
    -- Implement jail time countdown and restrictions
    Citizen.CreateThread(function()
        local remainingTime = jailTime
        while remainingTime > 0 do
            Citizen.Wait(1000)
            remainingTime = remainingTime - 1
            -- Restrict player actions while in jail
            DisableControlAction(0, 24, true) -- Disable attack
            DisableControlAction(0, 25, true) -- Disable aim
            DisableControlAction(0, 47, true) -- Disable weapon
            DisableControlAction(0, 58, true) -- Disable weapon
        end
        -- Release player from jail
        spawnPlayer(role)
        DisplayNotification("~g~You have been released from jail.")
    end)
end)

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Periodically send player position and wanted level to the server
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Every 5 seconds
        local playerPos = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('cops_and_robbers:updatePosition', playerPos, wantedLevel)
    end
end)
