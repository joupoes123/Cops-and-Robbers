-- admin.lua
-- Cops & Robbers FiveM Game Mode - Admin Script
-- Version: 1.1 | Date: 2025-02-11
-- This file contains admin commands and ban management for the game mode.

local json = require("json")

-- List of admin identifiers (replace with actual identifiers)
local Admins = { "fivem:8990", "steam:110000123456789" }

-- Persistent bans storage (local to this file)
local bannedPlayers = {}

-----------------------------------------------------------
-- Ban File Handling
-----------------------------------------------------------

-- Function to load bans from a file
local function LoadBans()
    local resourceName = GetCurrentResourceName()
    if not resourceName then
        print("Error: Unable to get current resource name.")
        return
    end

    local bans = LoadResourceFile(resourceName, "bans.json")
    if bans and bans ~= "" then
        local decodedBans = json.decode(bans)
        if decodedBans then
            bannedPlayers = decodedBans
        else
            print("Error decoding bans.json. Initializing empty bans.")
            bannedPlayers = {}
        end
    else
        print("Warning: bans.json file not found or empty.")
        bannedPlayers = {}
        local success = SaveResourceFile(resourceName, "bans.json", json.encode(bannedPlayers), -1)
        if not success then
            print("Error: Failed to save bans.json")
        end
    end
end

-- Function to save bans to a file
local function SaveBans()
    SaveResourceFile(GetCurrentResourceName(), "bans.json", json.encode(bannedPlayers), -1)
end

-- Load bans from file on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LoadBans()
    end
end)

-----------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------

-- Helper function to check if a player is an admin
function IsAdmin(playerId)
    local playerIdentifiers = GetSafePlayerIdentifiers(playerId)
    if not playerIdentifiers then return false end

    for _, identifier in ipairs(playerIdentifiers) do
        for _, adminIdentifier in ipairs(Admins) do
            if identifier == adminIdentifier then
                return true
            end
        end
    end
    return false
end

-- Helper function to get player identifiers safely
function GetSafePlayerIdentifiers(playerId)
    -- Check if sv_exposePlayerIdentifiersInHttpEndpoint is enabled before proceeding
    if GetConvar("sv_exposePlayerIdentifiersInHttpEndpoint", "false") == "false" then
        return nil
    end
    return GetPlayerIdentifiers(playerId)
end

-- Helper function to check if a player ID is valid (i.e. currently connected)
function IsValidPlayer(targetId)
    for _, playerId in ipairs(GetPlayers()) do
        if playerId == targetId then
            return true
        end
    end
    return false
end

-- Stub for weapon validation (if not defined elsewhere)
function IsWeaponValid(weaponHash)
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
    local targetId = args[1]  -- Expected to be a string
    if targetId and IsValidPlayer(targetId) then
        DropPlayer(targetId, "You have been kicked by an admin.")
        TriggerClientEvent('chat:addMessage', -1, { args = { "^1Admin", "Player " .. GetPlayerName(targetId) .. " has been kicked." } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID." } })
    end
end, false)

-- Ban command
RegisterCommand("ban", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    if targetId and IsValidPlayer(targetId) then
        local identifiers = GetSafePlayerIdentifiers(targetId)
        if identifiers then
            for _, identifier in ipairs(identifiers) do
                bannedPlayers[identifier] = true
            end
            SaveBans()
            DropPlayer(targetId, "You have been banned by an admin.")
            TriggerClientEvent('chat:addMessage', -1, { args = { "^1Admin", "Player " .. GetPlayerName(targetId) .. " has been banned." } })
        else
            TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Unable to ban player. Identifiers not available." } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID." } })
    end
end, false)

-- Set cash command
RegisterCommand("setcash", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    local amount = tonumber(args[2])
    if targetId and IsValidPlayer(targetId) and amount then
        TriggerClientEvent('cops_and_robbers:setCash', targetId, amount)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Set cash for " .. GetPlayerName(targetId) .. " to $" .. amount } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input." } })
    end
end, false)

-- Add cash command
RegisterCommand("addcash", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    local amount = tonumber(args[2])
    if targetId and IsValidPlayer(targetId) and amount then
        TriggerClientEvent('cops_and_robbers:addCash', targetId, amount)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Added $" .. amount .. " to " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input." } })
    end
end, false)

-- Remove cash command
RegisterCommand("removecash", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    local amount = tonumber(args[2])
    if targetId and IsValidPlayer(targetId) and amount then
        TriggerClientEvent('cops_and_robbers:removeCash', targetId, amount)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Removed $" .. amount .. " from " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input." } })
    end
end, false)

-- Give weapon command
RegisterCommand("giveweapon", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    local weaponName = args[2]
    if targetId and IsValidPlayer(targetId) and weaponName then
        local weaponHash = GetHashKey(weaponName)
        if IsWeaponValid(weaponHash) then
            TriggerClientEvent('cops_and_robbers:giveWeapon', targetId, weaponName)
            TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Gave weapon " .. weaponName .. " to " .. GetPlayerName(targetId) } })
        else
            TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid weapon name." } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input." } })
    end
end, false)

-- Remove weapon command
RegisterCommand("removeweapon", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    local weaponName = args[2]
    if targetId and IsValidPlayer(targetId) and weaponName then
        TriggerClientEvent('cops_and_robbers:removeWeapon', targetId, weaponName)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Removed weapon " .. weaponName .. " from " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input." } })
    end
end, false)

-- Reassign team command
RegisterCommand("reassign", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    local newRole = args[2]   -- Should be "cop" or "robber"
    if targetId and IsValidPlayer(targetId) and (newRole == "cop" or newRole == "robber") then
        TriggerEvent('cops_and_robbers:reassignRoleServer', targetId, newRole)
        TriggerClientEvent('cops_and_robbers:reassignRole', targetId, newRole)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Reassigned " .. GetPlayerName(targetId) .. " to " .. newRole } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid input." } })
    end
end, false)

-- Spectate command
RegisterCommand("spectate", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    if targetId and IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:spectatePlayer', source, targetId)
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID." } })
    end
end, false)

-- Freeze command
RegisterCommand("freeze", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    if targetId and IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:toggleFreeze', targetId)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Toggled freeze for " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID." } })
    end
end, false)

-- Teleport command
RegisterCommand("teleport", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Expected to be a string
    if targetId and IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:teleportToPlayer', source, targetId)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Teleported to " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID." } })
    end
end, false)
