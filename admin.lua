-- admin.lua
-- Cops & Robbers FiveM Game Mode - Admin Script
-- Version: 1.1 | Date: 2025-02-11
-- This file contains admin commands and ban management for the game mode.

-- Admin identifiers are now managed in config.lua (Config.Admins)

-- Ban management is handled by server.lua via events.

-----------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------

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

-- Helper function to get player identifiers safely
local function GetSafePlayerIdentifiers(playerId)
    return GetPlayerIdentifiers(playerId)
end

-- Helper function to check if a player ID is valid (i.e. currently connected)
local function IsValidPlayer(targetId)
    targetId = tonumber(targetId)
    if not targetId then return false end

    for _, playerId in ipairs(GetPlayers()) do
        if playerId == targetId then
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
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
        DropPlayer(targetId, "You have been kicked by an admin.")
        TriggerClientEvent('chat:addMessage', -1, { args = { "^1Admin", "Player " .. GetPlayerName(targetId) .. " has been kicked." } })
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
    end

    if targetId and IsValidPlayer(targetId) then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
        -- Trigger server event to handle the ban
        TriggerServerEvent('cops_and_robbers:banPlayer', targetId, reason)
        -- Admin message is now handled by server.lua or could be confirmed via another event
        -- For now, we assume server.lua handles the global message and DropPlayer.
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Ban command sent for player " .. GetPlayerName(targetId) .. "." } })
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
    local amount = tonumber(args[2])

    if targetId and IsValidPlayer(targetId) and amount then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:setCash', targetId, amount) -- Changed to server event
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Set cash for " .. GetPlayerName(targetId) .. " to $" .. amount } })
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
    local amount = tonumber(args[2])

    if targetId and IsValidPlayer(targetId) and amount then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:addCash', targetId, amount) -- Changed to server event
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Added $" .. amount .. " to " .. GetPlayerName(targetId) } })
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
    local amount = tonumber(args[2])

    if targetId and IsValidPlayer(targetId) and amount then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:removeCash', targetId, amount) -- Changed to server event
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Removed $" .. amount .. " from " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /removecash <playerId> <amount>" } })
    end
end, false)

-- Give weapon command
RegisterCommand("giveweapon", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)
    local weaponName = args[2]

    if targetId and IsValidPlayer(targetId) and weaponName then
        -- local weaponHash = GetHashKey(weaponName) -- Line removed by subtask
        if weaponName and string.len(weaponName) > 0 then -- Modified by subtask: Basic check for non-empty weaponName
            TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
            TriggerServerEvent('cops_and_robbers:giveWeapon', targetId, weaponName) -- Changed to server event
            TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Gave weapon " .. weaponName .. " to " .. GetPlayerName(targetId) } })
        else
            TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid weapon name: " .. weaponName } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /giveweapon <playerId> <weaponName>" } })
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
    local weaponName = args[2]

    if targetId and IsValidPlayer(targetId) and weaponName then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:removeWeapon', targetId, weaponName) -- Changed to server event
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Removed weapon " .. weaponName .. " from " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /removeweapon <playerId> <weaponName>" } })
    end
end, false)

-- Reassign team command
RegisterCommand("reassign", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)
    local newRole = args[2]   -- Should be "cop" or "robber"

    if targetId and IsValidPlayer(targetId) and (newRole == "cop" or newRole == "robber") then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
        TriggerServerEvent('cops_and_robbers:reassignRoleServer', targetId, newRole) -- Ensure server event handles all logic
        -- Client event 'cops_and_robbers:reassignRole' or 'cops_and_robbers:setRole' is triggered by server for target client
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Reassigned " .. GetPlayerName(targetId) .. " to " .. newRole } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input. Usage: /reassign <playerId> <cop|robber>" } })
    end
end, false)

-- Spectate command
RegisterCommand("spectate", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)

    if targetId and IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:spectatePlayer', source, targetId) -- Spectate is a client action, source needs to be targetId for some implementations
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID: " .. (targetIdStr or "nil") } })
    end
end, false)

-- Freeze command
RegisterCommand("freeze", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end

    local targetIdStr = args[1]
    local targetId = tonumber(targetIdStr)

    if targetId and IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:toggleFreeze', targetId)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Toggled freeze for " .. GetPlayerName(targetId) } })
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
    local targetId = tonumber(targetIdStr)

    if targetId and IsValidPlayer(targetId) then
        TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand) -- Log before action
        TriggerClientEvent('cops_and_robbers:teleportToPlayer', source, targetId)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Teleported to " .. GetPlayerName(targetId) } })
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

    TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand)
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
    end

    TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand)
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
    end

    TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand)
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
    end

    TriggerServerEvent('cops_and_robbers:logAdminCommand', GetPlayerName(source), source, rawCommand)
    TriggerServerEvent('cops_and_robbers:adminTriggerPowerOutage', gridId)
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Power outage event triggered for grid ID: " .. gridId } })
end, false)
