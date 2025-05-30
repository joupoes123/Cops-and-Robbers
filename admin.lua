-- admin.lua
-- Cops & Robbers FiveM Game Mode - Admin Script
-- Version: 1.1 | Date: 2025-02-11
-- This file contains admin commands and ban management for the game mode.

local json = require("json")

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
    -- Check if sv_exposePlayerIdentifiersInHttpEndpoint is enabled before proceeding
    if GetConvar("sv_exposePlayerIdentifiersInHttpEndpoint", "false") == "false" then
        return nil
    end
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

-- Stub for weapon validation (if not defined elsewhere)
local function IsWeaponValid(weaponHash)
    -- Implement actual weapon validation logic if necessary.
    -- For now, assume any non-zero weapon hash is valid.
    return weaponHash and weaponHash ~= 0
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
        TriggerClientEvent('cops_and_robbers:setCash', targetId, amount)
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
        TriggerClientEvent('cops_and_robbers:addCash', targetId, amount)
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
        TriggerClientEvent('cops_and_robbers:removeCash', targetId, amount)
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
        local weaponHash = GetHashKey(weaponName)
        if IsWeaponValid(weaponHash) then
            TriggerClientEvent('cops_and_robbers:giveWeapon', targetId, weaponName)
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
        TriggerClientEvent('cops_and_robbers:removeWeapon', targetId, weaponName)
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
        TriggerEvent('cops_and_robbers:reassignRoleServer', targetId, newRole)
        TriggerClientEvent('cops_and_robbers:reassignRole', targetId, newRole) -- This likely needs to be handled server-side or call a server event
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
        TriggerClientEvent('cops_and_robbers:teleportToPlayer', source, targetId) -- Teleport is a client action, source needs to be targetId for some implementations
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Teleported to " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID: " .. (targetIdStr or "nil") } })
    end
end, false)
