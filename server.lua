-- server.lua

-- Import Configurations
local Config = Config

-- Variables and Data Structures
local cops = {}
local robbers = {}
local heistCooldowns = {} -- Track robbers' cooldown status
local playerStats = {}
local playerRoles = {}
local playerPositions = {}
local bannedPlayers = {}

-- Load bans from file on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LoadBans()
    end
end)

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
        if tonumber(playerId) == targetId then
            return true
        end
    end
    return false
end

-- Check and initialize player stats
local function initializePlayerStats(player)
    if not playerStats[player] then
        playerStats[player] = { heists = 0, arrests = 0, rewards = 0, experience = 0, level = 1 }
    end
end

-- Receive player role from client
RegisterNetEvent('cops_and_robbers:setPlayerRole')
AddEventHandler('cops_and_robbers:setPlayerRole', function(role)
    local playerId = source
    playerRoles[playerId] = role
    if role == 'cop' then
        cops[playerId] = true
        robbers[playerId] = nil
    else
        robbers[playerId] = true
        cops[playerId] = nil
    end
    TriggerClientEvent('cops_and_robbers:setRole', playerId, role)
end)

-- Receive player positions and wanted levels from clients
RegisterNetEvent('cops_and_robbers:updatePosition')
AddEventHandler('cops_and_robbers:updatePosition', function(position, wantedLevel)
    local playerId = source
    playerPositions[playerId] = { position = position, wantedLevel = wantedLevel }
end)

-- Helper function to notify nearby cops with sound alert and GPS update
local function notifyNearbyCops(bankId, bankLocation, bankName)
    for copId, _ in pairs(cops) do
        local copData = playerPositions[copId]
        if copData then
            local distance = #(copData.position - bankLocation)
            if distance <= Config.HeistRadius then
                TriggerClientEvent('cops_and_robbers:notifyBankRobbery', copId, bankId, bankLocation, bankName)
                TriggerClientEvent('cops_and_robbers:playSound', copId, "Bank_Alarm")
            end
        end
    end
end

-- Start a bank heist if the robber is not on cooldown
RegisterNetEvent('cops_and_robbers:startHeist')
AddEventHandler('cops_and_robbers:startHeist', function(bankId)
    local source = source
    if not robbers[source] then
        return -- Only robbers can start heists
    end

    local currentTime = os.time()
    if heistCooldowns[source] and currentTime < heistCooldowns[source] then
        TriggerClientEvent('cops_and_robbers:heistOnCooldown', source)
        return
    end

    -- Set cooldown for the player
    heistCooldowns[source] = currentTime + Config.HeistCooldown

    local bank = Config.BankVaults[bankId]
    if bank then
        notifyNearbyCops(bank.id, bank.location, bank.name)
        TriggerClientEvent('cops_and_robbers:startHeistTimer', -1, bank.id, 600)  -- Heist timer of 10 minutes
    end
end)

-- Register event to handle arrests and update stats
RegisterNetEvent('cops_and_robbers:arrestRobber')
AddEventHandler('cops_and_robbers:arrestRobber', function(robberId)
    local source = source
    if not cops[source] then
        return -- Only cops can arrest robbers
    end
    if not robbers[robberId] then
        return -- Target must be a robber
    end

    initializePlayerStats(source)
    initializePlayerStats(robberId)

    playerStats[source].arrests = playerStats[source].arrests + 1
    playerStats[source].experience = playerStats[source].experience + 500
    TriggerClientEvent('cops_and_robbers:arrestNotification', robberId, source)
    TriggerClientEvent('cops_and_robbers:sendToJail', robberId, 300) -- Send robber to jail for 5 minutes
end)

-- Periodically check for wanted robbers and notify cops
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) -- Every 10 seconds
        for robberId, data in pairs(playerPositions) do
            if robbers[robberId] and data.wantedLevel >= 3 then
                notifyCopsOfWantedRobber(robberId, data.position)
            end
        end
    end
end)

-- Function to notify cops of a wanted robber
function notifyCopsOfWantedRobber(robberId, robberPosition)
    for copId, _ in pairs(cops) do
        TriggerClientEvent('cops_and_robbers:notifyWantedRobber', copId, robberId, robberPosition)
    end
end

-- Player Connecting Ban Check
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local playerId = source
    local identifiers = GetPlayerIdentifiers(playerId)
    for _, identifier in ipairs(identifiers) do
        if bannedPlayers[identifier] then
            setKickReason("You are banned from this server.")
            CancelEvent()
            return
        end
    end
end)

-- Remove players from role tables when they leave
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    cops[playerId] = nil
    robbers[playerId] = nil
    playerRoles[playerId] = nil
    playerPositions[playerId] = nil
end)