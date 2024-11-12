local cops = {}
local robbers = {}
local maxPlayers = 64
local heistRadius = 1000.0  -- Radius for notification to nearby cops
local heistCooldown = 600 -- 10-minute cooldown for robbers
local heistCooldowns = {} -- Track robbers' cooldown status
local copSpawn = vector3(452.6, -980.0, 30.7)
local robberSpawn = vector3(2126.7, 4794.1, 41.1)
local policeVehicles = { 'police', 'police2', 'police3' }
local civilianVehicles = { 'sultan', 'futo', 'blista' }
local bankVaults = {
    { location = vector3(150.0, -1040.0, 29.0), name = "Pacific Standard Bank", id = 1 },
    { location = vector3(-1212.0, -330.0, 37.8), name = "Fleeca Bank", id = 2 },
}

-- List of admins by identifier (replace with actual identifiers)
local admins = { "steam:110000112345678", "steam:110000123456789" }  -- Example admin identifiers

-- Track player stats for leaderboard
local playerStats = {}

-- Check and initialize player stats
local function initializePlayerStats(player)
    if not playerStats[player] then
        playerStats[player] = { heists = 0, arrests = 0, rewards = 0 }
    end
end

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

-- Award player with random reward and update stats
local function awardRandomReward(player)
    local reward = math.random(500, 2000)  -- Random reward between $500 and $2000
    playerStats[player].rewards = playerStats[player].rewards + reward
    TriggerClientEvent('cops_and_robbers:receiveReward', player, reward)
end

-- Helper function to notify nearby cops with sound alert and GPS update
local function notifyNearbyCops(bankId, bankLocation, bankName)
    for _, copId in ipairs(cops) do
        local copPosition = GetEntityCoords(GetPlayerPed(copId))
        local distance = #(copPosition - bankLocation)
        
        if distance <= heistRadius then
            TriggerClientEvent('cops_and_robbers:notifyBankRobbery', copId, bankId, bankLocation, bankName)
            TriggerClientEvent('cops_and_robbers:playSound', copId, "bank_alarm") -- Sound notification
        end
    end
end

-- Start a bank heist if the robber is not on cooldown
RegisterNetEvent('cops_and_robbers:startHeist')
AddEventHandler('cops_and_robbers:startHeist', function(bankId)
    local source = source
    if heistCooldowns[source] and GetGameTimer() < heistCooldowns[source] then
        TriggerClientEvent('cops_and_robbers:heistOnCooldown', source)
        return
    end

    -- Set cooldown for the player
    heistCooldowns[source] = GetGameTimer() + heistCooldown * 1000

    local bank = bankVaults[bankId]
    if bank then
        notifyNearbyCops(bank.id, bank.location, bank.name)
        TriggerClientEvent('cops_and_robbers:startHeistTimer', -1, bank.id, 600)  -- Heist timer of 10 minutes
    end
end)

-- Register event to handle arrests and update stats
RegisterNetEvent('cops_and_robbers:arrestRobber')
AddEventHandler('cops_and_robbers:arrestRobber', function(robberId)
    local source = source
    initializePlayerStats(source)
    initializePlayerStats(robberId)

    playerStats[source].arrests = playerStats[source].arrests + 1
    TriggerClientEvent('cops_and_robbers:arrestNotification', robberId, source)
end)

-- ADMIN COMMANDS

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
