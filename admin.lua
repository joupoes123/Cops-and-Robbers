-- admin.lua
-- Cops & Robbers FiveM Game Mode - Admin Script
-- Version: 1.1 | Date: 2025-02-11
-- This file contains admin commands and ban management for the game mode.

-- Admin identifiers are now managed in config.lua (Config.Admins)

-- Ban management is handled by server.lua via events.

-----------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------

-- Helper function to get player identifiers safely
local function GetSafePlayerIdentifiers(playerId)
    return GetPlayerIdentifiers(playerId)
end

-- Helper function to safely get player name
local function GetSafePlayerName(playerId)
    local name = GetPlayerName(tostring(playerId))
    return name and name or "Unknown Player"
end

-- Helper function to check if a player is an admin
local function IsAdmin(playerId)
    local playerIdentifiers = GetSafePlayerIdentifiers(playerId)
    if not playerIdentifiers then return false end

    -- Ensure Config and Config.Admins are loaded and available
    if not Config or type(Config.Admins) ~= "table" then
        print("Error: Config.Admins is not loaded or not a table. Ensure config.lua defines it correctly.")
        return false
    end

    for _, identifier in ipairs(playerIdentifiers) do
        -- Check if the player's identifier exists as a key in the Config.Admins table
        if Config.Admins[identifier] then
            return true
        end
    end
    return false
end

-- Helper function to check if a player ID is valid (i.e. currently connected)
local function IsValidPlayer(targetId)
    targetId = tonumber(targetId)
    if not targetId then return false end

    for _, playerId in ipairs(GetPlayers()) do
        if tonumber(playerId) == targetId then
            return true
        end
    end
    return false
end

-----------------------------------------------------------
-- Admin Commands
-----------------------------------------------------------

-- Kick command
RegisterCommand("kick", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)

    if targetId and IsValidPlayer(targetId) then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        DropPlayer(tostring(targetId), "You have been kicked by an admin.")
        TriggerClientEvent('chat:addMessage', -1, { args = { "^1Admin", "Player " .. GetSafePlayerName(targetId) .. " has been kicked." } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID: " .. (targetIdStr or "nil") } })
    end
end, false)

-- Ban command
RegisterCommand("ban", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)
    local reason = table.concat(args, " ", 2) -- Combine remaining args for reason

    if not reason or reason == "" then
        reason = "No reason provided."
    end    if targetId and IsValidPlayer(targetId) then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        -- Trigger server event to handle the ban
        TriggerServerEvent('cops_and_robbers:banPlayer', targetId, reason)
        -- Admin message is now handled by server.lua or could be confirmed via another event
        -- For now, we assume server.lua handles the global message and DropPlayer.
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Ban command sent for player " .. GetSafePlayerName(targetId) .. "." } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID: " .. (targetIdStr or "nil") } })
    end
end, false)

-- Set cash command
RegisterCommand("setcash", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)
    local amount = tonumber(args[2])    if targetId and IsValidPlayer(targetId) and amount then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:setCash', targetId, amount) -- Changed to server event
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Set cash for " .. GetSafePlayerName(targetId) .. " to $" .. amount } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /setcash <playerId> <amount>" } })
    end
end, false)

-- Add cash command
RegisterCommand("addcash", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)
    local amount = tonumber(args[2])    if targetId and IsValidPlayer(targetId) and amount then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:addCash', targetId, amount) -- Changed to server event
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Added $" .. amount .. " to " .. GetSafePlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /addcash <playerId> <amount>" } })
    end
end, false)

-- Remove cash command
RegisterCommand("removecash", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)
    local amount = tonumber(args[2])    if targetId and IsValidPlayer(targetId) and amount then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:removeCash', targetId, amount) -- Changed to server event
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Removed $" .. amount .. " from " .. GetSafePlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /removecash <playerId> <amount>" } })
    end
end, false)



-- Remove weapon command
RegisterCommand("removeweapon", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)
    local weaponName = args[2]    if targetId and IsValidPlayer(targetId) and weaponName then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:removeWeapon', targetId, weaponName) -- Changed to server event
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Removed weapon " .. weaponName .. " from " .. GetSafePlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /removeweapon <playerId> <weaponName>" } })
    end
end, false)

-- Reassign team command
RegisterCommand("reassign", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)
    local newRole = args[2]   -- Should be "cop" or "robber"

    if targetId and IsValidPlayer(targetId) and (newRole == "cop" or newRole == "robber") then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:reassignRoleServer', targetId, newRole) -- Ensure server event handles all logic
        -- Client event 'cops_and_robbers:reassignRole' or 'cops_and_robbers:setRole' is triggered by server for target client
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Reassigned " .. GetSafePlayerName(targetId) .. " to " .. newRole } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /reassign <playerId> <cop|robber>" } })
    end
end, false)

-- Freeze command
RegisterCommand("freeze", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)    if targetId and IsValidPlayer(targetId) then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        TriggerClientEvent('cops_and_robbers:toggleFreeze', targetId)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Toggled freeze for " .. GetSafePlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID: " .. (targetIdStr or "nil") } })
    end
end, false)

-- Teleport command
RegisterCommand("teleport", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)    if targetId and IsValidPlayer(targetId) then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand) -- Log before action
        TriggerClientEvent('cops_and_robbers:teleportToPlayer', source, targetId)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Teleported to " .. GetSafePlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID: " .. (targetIdStr or "nil") } })
    end
end, false)

-- =====================================
-- Scenario Trigger Commands
-- =====================================
RegisterCommand("triggerarmoredcar", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand)
    TriggerServerEvent('cops_and_robbers:adminTriggerArmoredCar')
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Armored car event triggered." } })
end, false)

RegisterCommand("triggerbankheist", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local bankId = tonumber(args[1])
    if not bankId then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Usage: /triggerbankheist <bankId>" } })
        return
    end    TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand)
    TriggerServerEvent('cops_and_robbers:adminTriggerBankHeist', bankId)
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Bank heist event triggered for bank ID: " .. bankId } })
end, false)

RegisterCommand("triggerstorerobbery", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local storeId = tonumber(args[1])
    if not storeId then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Usage: /triggerstorerobbery <storeId>" } })
        return
    end    TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand)
    TriggerServerEvent('cops_and_robbers:adminTriggerStoreRobbery', storeId)
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Store robbery event triggered for store ID: " .. storeId } })
end, false)

RegisterCommand("triggerpoweroutage", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local gridId = tonumber(args[1])
    if not gridId then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Usage: /triggerpoweroutage <gridId>" } })
        return
    end    TriggerServerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand)
    TriggerServerEvent('cops_and_robbers:adminTriggerPowerOutage', gridId)
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Power outage event triggered for grid ID: " .. gridId } })
end, false)

-- Set level command
RegisterCommand("setlevel", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetId = tonumber(args[1])
    local newLevel = tonumber(args[2])

    if not targetId or not newLevel then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Usage: /setlevel <playerId> <level>" } })
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID." } })
        return
    end    if newLevel < 1 or newLevel > 100 then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Level must be between 1 and 100." } })
        return
    end    TriggerEvent('cops_and_robbers:logAdminCommand', GetSafePlayerName(source), source, rawCommand)
    TriggerEvent('cops_and_robbers:adminSetLevel', targetId, newLevel)

    TriggerClientEvent('chat:addMessage', source, {
        args = { "^1Admin", string.format("Set level for %s to %d", GetSafePlayerName(targetId), newLevel) }
    })
    TriggerClientEvent('chat:addMessage', targetId, {
        args = { "^1Admin", string.format("Admin set your level to %d", newLevel) }
    })
end, false)
