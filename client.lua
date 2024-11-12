local role
local bankVaults = {
    { location = vector3(150.0, -1040.0, 29.0), name = "Pacific Standard Bank", id = 1 },
    { location = vector3(-1212.0, -330.0, 37.8), name = "Fleeca Bank", id = 2 },
}
local playerCash = 0
local playerStats = { heists = 0, arrests = 0, rewards = 0 }

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
    local remainingTime = time
    Citizen.CreateThread(function()
        while remainingTime > 0 do
            Citizen.Wait(1000)
            remainingTime = remainingTime - 1
            -- Display heist timer
            DrawText(0.5, 0.5, string.format("Heist Time Remaining: %02d:%02d", math.floor(remainingTime / 60), remainingTime % 60))
        end
    end)
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
end)

-- Arrest notification
RegisterNetEvent('cops_and_robbers:arrestNotification')
AddEventHandler('cops_and_robbers:arrestNotification', function(copId)
    DisplayNotification("~r~You have been arrested by " .. GetPlayerName(copId) .. "!")
end)

-- Helper function to display notifications on screen
function DisplayNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, true)
end

-- Draw text on screen
function DrawText(x, y, text)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- ADMIN FUNCTIONS

-- Set cash for the player
RegisterNetEvent('cops_and_robbers:setCash')
AddEventHandler('cops_and_robbers:setCash', function(amount)
    playerCash = amount
    DisplayNotification("~g~Your cash has been set to: $" .. amount)
end)

-- Add cash for the player
RegisterNetEvent('cops_and_robbers:addCash')
AddEventHandler('cops_and_robbers:addCash', function(amount)
    playerCash = playerCash + amount
    DisplayNotification("~g~You received: $" .. amount)
end)

-- Remove cash for the player
RegisterNetEvent('cops_and_robbers:removeCash')
AddEventHandler('cops_and_robbers:removeCash', function(amount)
    playerCash = playerCash - amount
    DisplayNotification("~r~You lost: $" .. amount)
end)

-- Give a weapon to the player
RegisterNetEvent('cops_and_robbers:giveWeapon')
AddEventHandler('cops_and_robbers:giveWeapon', function(weaponName)
    GiveWeaponToPed(PlayerPedId(), GetHashKey(weaponName), 100, false, false)
    DisplayNotification("~g~You received a " .. weaponName)
end)

-- Remove a weapon from the player
RegisterNetEvent('cops_and_robbers:removeWeapon')
AddEventHandler('cops_and_robbers:removeWeapon', function(weaponName)
    RemoveWeaponFromPed(PlayerPedId(), GetHashKey(weaponName))
    DisplayNotification("~r~Your " .. weaponName .. " has been removed")
end)

-- Reassign the player's role
RegisterNetEvent('cops_and_robbers:reassignRole')
AddEventHandler('cops_and_robbers:reassignRole', function(newRole)
    role = newRole
    DisplayNotification("~b~Your role has been changed to " .. newRole)
end)

-- Objective Display for Cop and Robber
RegisterNetEvent('cops_and_robbers:setObjective')
AddEventHandler('cops_and_robbers:setObjective', function(objectives)
    if role == 'cop' then
        currentObjective = objectives.cops
    else
        currentObjective = objectives.robbers
    end
    DisplayObjective(currentObjective)
end)

-- Display objectives on player’s HUD
function DisplayObjective(objective)
    -- Function to display objectives on screen (implement with UI or DrawText)
    DisplayNotification("Objective: " .. objective)
end

-- Random Event: Police Checkpoint
RegisterNetEvent('cops_and_robbers:eventPoliceCheckpoint')
AddEventHandler('cops_and_robbers:eventPoliceCheckpoint', function()
    if role == 'robber' then
        DisplayNotification("Caution: Police checkpoint nearby. Evade!")
        -- Add checkpoints on map and possible cop patrols
    end
end)

-- Random Event: Supply Drop for Robbers
RegisterNetEvent('cops_and_robbers:eventSupplyDrop')
AddEventHandler('cops_and_robbers:eventSupplyDrop', function(dropLocation)
    if role == 'robber' then
        DisplayNotification("Supply drop available at marked location!")
        SetNewWaypoint(dropLocation.x, dropLocation.y)
    end
end)

-- Random Event: Backup Request for Cops
RegisterNetEvent('cops_and_robbers:eventBackupRequest')
AddEventHandler('cops_and_robbers:eventBackupRequest', function(backupLocation)
    if role == 'cop' then
        DisplayNotification("Backup request! Head to the marked location.")
        SetNewWaypoint(backupLocation.x, backupLocation.y)
    end
end)

-- Bounty System Notification
RegisterNetEvent('cops_and_robbers:notifyBounty')
AddEventHandler('cops_and_robbers:notifyBounty', function(targetRobber, reward)
    if role == 'cop' then
        DisplayNotification("Bounty placed on " .. GetPlayerName(targetRobber) .. "! Reward: $" .. reward)
    elseif role == 'robber' and GetPlayerServerId(PlayerId()) == targetRobber then
        DisplayNotification("You have a bounty on your head! Evade capture!")
    end
end)
