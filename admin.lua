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
    if not Config or type(Config.Admins) ~= "table" then
        return false
    end
    for _, identifier in ipairs(playerIdentifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
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
    for _, id in ipairs(GetPlayers()) do
        if tonumber(id) == targetId then return true end
    end
    return false
end

-----------------------------------------------------------
-- Admin Commands
-----------------------------------------------------------

-- Kick command
RegisterCommand("kick", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = args[1]
    if not IsValidPlayer(targetId) then return end
    DropPlayer(tostring(targetId), "You have been kicked by an admin.")
end, false)

-- Ban command
RegisterCommand("ban", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = args[1]
    if not IsValidPlayer(targetId) then return end
    local reason = table.concat(args, " ", 2) or "Banned by admin."
    TriggerEvent('cnr:banPlayer', targetId, reason)
    DropPlayer(tostring(targetId), reason)
end, false)

-- Set cash command
RegisterCommand("setcash", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if not IsValidPlayer(targetId) or not amount then return end
    TriggerEvent('cnr:setPlayerCash', targetId, amount)
end, false)

-- Add cash command
RegisterCommand("addcash", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if not IsValidPlayer(targetId) or not amount then return end
    TriggerEvent('cnr:addPlayerCash', targetId, amount)
end, false)

-- Remove cash command
RegisterCommand("removecash", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if not IsValidPlayer(targetId) or not amount then return end
    TriggerEvent('cnr:removePlayerCash', targetId, amount)
end, false)

-- Give weapon command
RegisterCommand("giveweapon", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = tonumber(args[1])
    local weapon = args[2]
    if not IsValidPlayer(targetId) or not weapon then return end
    TriggerEvent('cnr:giveWeapon', targetId, weapon)
end, false)

-- Remove weapon command
RegisterCommand("removeweapon", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = tonumber(args[1])
    local weapon = args[2]
    if not IsValidPlayer(targetId) or not weapon then return end
    TriggerEvent('cnr:removeWeapon', targetId, weapon)
end, false)

-- Reassign team command
RegisterCommand("reassign", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = tonumber(args[1])
    local newRole = args[2]
    if not IsValidPlayer(targetId) or not newRole then return end
    TriggerEvent('cnr:reassignRole', targetId, newRole)
end, false)

-- Freeze command
RegisterCommand("freeze", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = tonumber(args[1])
    if not IsValidPlayer(targetId) then return end
    TriggerEvent('cnr:freezePlayer', targetId)
end, false)

-- Teleport command
RegisterCommand("teleport", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local targetId = tonumber(args[1])
    if not IsValidPlayer(targetId) then return end
    TriggerEvent('cnr:teleportToPlayer', source, targetId)
end, false)

-- =====================================
-- Scenario Trigger Commands
-- =====================================
RegisterCommand("triggerarmoredcar", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Armored car event triggered." } })
    TriggerEvent('cnr:triggerArmoredCar')
end, false)

RegisterCommand("triggerbankheist", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local bankId = args[1] or "1"
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Bank heist event triggered for bank ID: " .. bankId } })
    TriggerEvent('cnr:triggerBankHeist', bankId)
end, false)

RegisterCommand("triggerstorerobbery", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local storeId = args[1] or "1"
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Store robbery event triggered for store ID: " .. storeId } })
    TriggerEvent('cnr:triggerStoreRobbery', storeId)
end, false)

RegisterCommand("triggerpoweroutage", function(source, args, rawCommand)
    if not IsAdmin(source) then return end
    local gridId = args[1] or "1"
    TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Power outage event triggered for grid ID: " .. gridId } })
    TriggerEvent('cnr:triggerPowerOutage', gridId)
end, false)
