-- client.lua

-- Variables and Data Structures
local role = nil
local playerCash = 0
local playerStats = { heists = 0, arrests = 0, rewards = 0, experience = 0, level = 1 }
local currentObjective = nil
local wantedLevel = 0

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
