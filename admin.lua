local admins = { "steam:110000112345678", "steam:110000123456789" }  -- Replace with actual admin identifiers

-- Helper function to check if a player is an admin
local function isAdmin(playerId)
    local playerIdentifier = GetPlayerIdentifiers(playerId)[1]
    for _, identifier in ipairs(admins) do
        if identifier == playerIdentifier then
            return true
        end
    end
    return false
end

-- Kick command
RegisterCommand("kick", function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "System", "You do not have permission to use this command." } })
        return
    end
    local targetId = tonumber(args[1])
    if targetId then
        DropPlayer(targetId, "You have been kicked by an admin.")
        TriggerClientEvent('chat:addMessage', -1, { args = { "Admin", "Player " .. GetPlayerName(targetId) .. " has been kicked." } })
    end
end, false)

-- Ban command (temporary, for demonstration)
local bannedPlayers = {}

RegisterCommand("ban", function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "System", "You do not have permission to use this command." } })
        return
    end
    local targetId = tonumber(args[1])
    if targetId then
        local identifier = GetPlayerIdentifiers(targetId)[1]
        bannedPlayers[identifier] = true
        DropPlayer(targetId, "You have been banned by an admin.")
        TriggerClientEvent('chat:addMessage', -1, { args = { "Admin", "Player " .. GetPlayerName(targetId) .. " has been banned." } })
    end
end, false)

-- Set cash command
RegisterCommand("setcash", function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "System", "You do not have permission to use this command." } })
        return
    end
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if targetId and amount then
        TriggerClientEvent('cops_and_robbers:setCash', targetId, amount)
        TriggerClientEvent('chat:addMessage', source, { args = { "Admin", "Set cash for " .. GetPlayerName(targetId) .. " to $" .. amount } })
    end
end, false)

-- Add cash command
RegisterCommand("addcash", function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "System", "You do not have permission to use this command." } })
        return
    end
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if targetId and amount then
        TriggerClientEvent('cops_and_robbers:addCash', targetId, amount)
        TriggerClientEvent('chat:addMessage', source, { args = { "Admin", "Added $" .. amount .. " to " .. GetPlayerName(targetId) } })
    end
end, false)

-- Remove cash command
RegisterCommand("removecash", function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "System", "You do not have permission to use this command." } })
        return
    end
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if targetId and amount then
        TriggerClientEvent('cops_and_robbers:removeCash', targetId, amount)
        TriggerClientEvent('chat:addMessage', source, { args = { "Admin", "Removed $" .. amount .. " from " .. GetPlayerName(targetId) } })
    end
end, false)

-- Add weapon command
RegisterCommand("giveweapon", function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "System", "You do not have permission to use this command." } })
        return
    end
    local targetId = tonumber(args[1])
    local weaponName = args[2]
    if targetId and weaponName then
        TriggerClientEvent('cops_and_robbers:giveWeapon', targetId, weaponName)
        TriggerClientEvent('chat:addMessage', source, { args = { "Admin", "Gave weapon " .. weaponName .. " to " .. GetPlayerName(targetId) } })
    end
end, false)

-- Remove weapon command
RegisterCommand("removeweapon", function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "System", "You do not have permission to use this command." } })
        return
    end
    local targetId = tonumber(args[1])
    local weaponName = args[2]
    if targetId and weaponName then
        TriggerClientEvent('cops_and_robbers:removeWeapon', targetId, weaponName)
        TriggerClientEvent('chat:addMessage', source, { args = { "Admin", "Removed weapon " .. weaponName .. " from " .. GetPlayerName(targetId) } })
    end
end, false)

-- Reassign team command
RegisterCommand("reassign", function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "System", "You do not have permission to use this command." } })
        return
    end
    local targetId = tonumber(args[1])
    local newRole = args[2]  -- Should be "cop" or "robber"
    if targetId and (newRole == "cop" or newRole == "robber") then
        TriggerClientEvent('cops_and_robbers:reassignRole', targetId, newRole)
        TriggerClientEvent('chat:addMessage', source, { args = { "Admin", "Reassigned " .. GetPlayerName(targetId) .. " to " .. newRole } })
    end
end, false)
