-- admin.lua

-- List of admins by identifier (replace with actual identifiers)
Admins = { "steam:110000112345678", "steam:110000123456789" }

-- Persistent bans storage
bannedPlayers = {}

-- Function to load bans from a file
function LoadBans()
    local bans = LoadResourceFile(GetCurrentResourceName(), "bans.json")
    if bans then
        bannedPlayers = json.decode(bans)
    else
        bannedPlayers = {}
    end
end

-- Function to save bans to a file
function SaveBans()
    SaveResourceFile(GetCurrentResourceName(), "bans.json", json.encode(bannedPlayers), -1)
end

-- Load bans from file on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LoadBans()
    end
end)

-- Helper function to check if a player is an admin
function IsAdmin(playerId)
    local playerIdentifiers = GetPlayerIdentifiers(playerId)
    for _, identifier in ipairs(playerIdentifiers) do
        for _, adminIdentifier in ipairs(Admins) do
            if identifier == adminIdentifier then
                return true
            end
        end
    end
    return false
end

-- Helper function to check if a player ID is valid
function IsValidPlayer(targetId)
    for _, playerId in ipairs(GetPlayers()) do
        if playerId == targetId then
            return true
        end
    end
    return false
end

-- Kick command
RegisterCommand("kick", function(source, args, rawCommand)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1System", "You do not have permission to use this command." } })
        return
    end
    local targetId = args[1]  -- Keep as string
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
    local targetId = args[1]  -- Keep as string
    if targetId and IsValidPlayer(targetId) then
        local identifiers = GetPlayerIdentifiers(targetId)
        for _, identifier in ipairs(identifiers) do
            bannedPlayers[identifier] = true
        end
        SaveBans()
        DropPlayer(targetId, "You have been banned by an admin.")
        TriggerClientEvent('chat:addMessage', -1, { args = { "^1Admin", "Player " .. GetPlayerName(targetId) .. " has been banned." } })
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
    local targetId = args[1]  -- Keep as string
    local amount = tonumber(args[2])
    if targetId and IsValidPlayer(targetId) and amount then
        -- Update cash on the server side if applicable
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
    local targetId = args[1]  -- Keep as string
    local amount = tonumber(args[2])
    if targetId and IsValidPlayer(targetId) and amount then
        -- Update cash on the server side if applicable
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
    local targetId = args[1]  -- Keep as string
    local amount = tonumber(args[2])
    if targetId and IsValidPlayer(targetId) and amount then
        -- Update cash on the server side if applicable
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
    local targetId = args[1]  -- Keep as string
    local weaponName = args[2]
    if targetId and IsValidPlayer(targetId) and weaponName then
        if IsWeaponValid(GetHashKey(weaponName)) then
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
    local targetId = args[1]  -- Keep as string
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
    local targetId = args[1]  -- Keep as string
    local newRole = args[2]  -- Should be "cop" or "robber"
    if targetId and IsValidPlayer(targetId) and (newRole == "cop" or newRole == "robber") then
        -- Update role on the server side
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
    local targetId = args[1]  -- Keep as string
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
    local targetId = args[1]  -- Keep as string
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
    local targetId = args[1]  -- Keep as string
    if targetId and IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:teleportToPlayer', source, targetId)
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Teleported to " .. GetPlayerName(targetId) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Admin", "Invalid player ID." } })
    end
end, false)
