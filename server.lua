-- server.lua

-- =====================================
--           CONFIGURATION
-- =====================================

-- Ensure that config.lua is loaded before server.lua.
-- In FiveM, both config.lua and server.lua are included in the fxmanifest.lua or __resource.lua
-- Ensure config.lua is listed before server.lua to allow access to Config tables

-- Example fxmanifest.lua snippet:
-- fx_version 'cerulean'
-- game 'gta5'

-- server_scripts {
--     'config.lua',
--     'server.lua',
--     'admin.lua', -- Ensure admin.lua is listed after server.lua if necessary
-- }

-- =====================================
--           LOGGING FUNCTION
-- =====================================
function LogAdminAction(text)
    local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
    local logLine = timestamp .. text

    -- Workaround for appending to a file
    local existingLog = LoadResourceFile(GetCurrentResourceName(), "actions.log")
    if not existingLog then existingLog = "" end

    local newLogContent = existingLog .. logLine .. "\n"
    local success = SaveResourceFile(GetCurrentResourceName(), "actions.log", newLogContent, -1)
    if not success then
        print("Error: Failed to save to actions.log")
    end
    print(logLine) -- Also print to server console for real-time view
end

-- =====================================
--           VARIABLES
-- =====================================

-- Declare all necessary variables as local to prevent global namespace pollution
local playerData = {}
local cops = {}
local robbers = {}
local heistCooldowns = {}
local playerStats = {}
local playerRoles = {}
local playerPositions = {}
local purchaseHistory = {}
local bannedPlayers = {}

-- Table for throttling updatePosition events (in ms)
local playerUpdateTimestamps = {}
local deployedSpikeStrips = {} -- Stores { id, owner, location, expirationTimer }
local spikeStripCounter = 0 -- Simple ID generator
local playerSpikeStripCount = {} -- Stores { [playerId] = count }

-- Contraband Drop Variables
local activeContrabandDrops = {}
local nextContrabandDropTimestamp = 0

-- =====================================
--      CONFIG ITEMS INDEXING
-- =====================================
-- Build lookup table for Config.Items for faster access
local ConfigItemsById = {}
if Config and Config.Items then
    for _, item in ipairs(Config.Items) do
        ConfigItemsById[item.itemId] = item
    end
end

-- =====================================
--           HELPER FUNCTIONS
-- =====================================

-- Helper function to check if a value exists in a table
local function hasValue(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Function to get ammo count based on ammo type
local function getAmmoCountForItem(ammoId)
    local ammoCounts = {
        ammo_pistol = 24,
        ammo_smg = 60,
        ammo_rifle = 60,
        ammo_shotgun = 16,
        ammo_sniper = 10,
        -- Add more ammo types as needed
    }
    return ammoCounts[ammoId] or 0
end

-- Helper function to get the number of key-value pairs in a table
local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Function to initialize purchase data
local function initializePurchaseData()
    for _, item in ipairs(Config.Items) do
        purchaseHistory[item.itemId] = {}
    end
end

-- Function to save bans to a file
local function saveBans()
    local jsonData = json.encode(bannedPlayers, { indent = true })
    if jsonData then
        SaveResourceFile(GetCurrentResourceName(), "bans.json", jsonData, -1)
    else
        print("Error encoding bans.json.")
    end
end

-- Function to load player data from file
local function loadPlayerData(source)
    local identifiers = GetPlayerIdentifiers(source)
    if not identifiers or #identifiers == 0 then return end

    local identifier = identifiers[1]  -- Use the first identifier (e.g., Steam ID)
    local data = {
        money = 2500,
        inventory = {},
        weapons = {},
        wantedPoints = 0,
        currentWantedStars = 0,
        lastCrimeTimestamp = 0,
        lastSeenByCopTimestamp = 0
    }

    local filePath = "player_data/" .. identifier .. ".json"
    local fileData = LoadResourceFile(GetCurrentResourceName(), filePath)
    if fileData and fileData ~= "" then
        local success, loadedData = pcall(json.decode, fileData)
        if success and loadedData then
            data = loadedData
        else
            print(("Error decoding JSON for player %s"):format(identifier))
        end
    end

    playerData[source] = data
end

-- Function to save player data to file
local function savePlayerData(source)
    local data = playerData[source]
    if data then
        local identifiers = GetPlayerIdentifiers(source)
        if not identifiers or #identifiers == 0 then return end

        local identifier = identifiers[1]
        local filePath = "player_data/" .. identifier .. ".json"
        local jsonData = json.encode(data, { indent = true })

        if jsonData then
            SaveResourceFile(GetCurrentResourceName(), filePath, jsonData, -1)
        else
            print(("Error encoding JSON for player %s"):format(identifier))
        end
    end
end

-- Function to get player data
local function getPlayerData(source)
    return playerData[source]
end

-----------------------------------------------------------
-- Wanted System Functions
-----------------------------------------------------------
local function UpdatePlayerWantedLevel(playerId)
    if not playerData[playerId] then return end

    local currentPoints = playerData[playerId].wantedPoints
    local newStarLevel = 0
    for i = #Config.WantedSettings.levels, 1, -1 do
        if currentPoints >= Config.WantedSettings.levels[i].threshold then
            newStarLevel = Config.WantedSettings.levels[i].stars
            break
        end
    end

    if playerData[playerId].currentWantedStars ~= newStarLevel or playerData[playerId].lastNotifiedWantedPoints ~= currentPoints then
        playerData[playerId].currentWantedStars = newStarLevel
        playerData[playerId].lastNotifiedWantedPoints = currentPoints -- Track last notified points
        TriggerClientEvent('cops_and_robbers:updateWantedDisplay', playerId, newStarLevel, currentPoints)
        -- LogAdminAction(string.format("Wanted Level Update: Player %s (ID: %d) new stars: %d, points: %d", GetPlayerName(playerId), playerId, newStarLevel, currentPoints))
    end
end

local function IncreaseWantedPoints(playerId, crimeTypeKey)
    if not playerData[playerId] or not Config.WantedSettings.crimes[crimeTypeKey] then
        if not Config.WantedSettings.crimes[crimeTypeKey] then
            print("IncreaseWantedPoints: Invalid crimeTypeKey: " .. crimeTypeKey)
        end
        return
    end

    local pointsToAdd = Config.WantedSettings.crimes[crimeTypeKey]
    playerData[playerId].wantedPoints = playerData[playerId].wantedPoints + pointsToAdd
    playerData[playerId].lastCrimeTimestamp = GetGameTimer()

    LogAdminAction(string.format("Wanted Points Increased: Player %s (ID: %d) +%d for %s. Total: %d", GetPlayerName(playerId), playerId, pointsToAdd, crimeTypeKey, playerData[playerId].wantedPoints))
    UpdatePlayerWantedLevel(playerId)
    savePlayerData(playerId) -- Save player data after wanted points change
end

-----------------------------------------------------------

-- Add money to player
local function addPlayerMoney(source, amount)
    local data = getPlayerData(source)
    if data then
        data.money = (data.money or 0) + amount
    end
end

-- Remove money from player
local function removePlayerMoney(source, amount)
    local data = getPlayerData(source)
    if data then
        data.money = (data.money or 0) - amount
        if data.money < 0 then data.money = 0 end
    end
end

-- Get player money
local function getPlayerMoney(source)
    local data = getPlayerData(source)
    if data then
        return data.money or 0
    else
        return 0
    end
end

-- Add item to player inventory
local function addPlayerInventoryItem(source, itemId, quantity)
    local data = getPlayerData(source)
    if data then
        data.inventory[itemId] = (data.inventory[itemId] or 0) + quantity
    end
end

-- Remove item from player inventory
local function removePlayerInventoryItem(source, itemId, quantity)
    local data = getPlayerData(source)
    if data and data.inventory[itemId] then
        data.inventory[itemId] = data.inventory[itemId] - quantity
        if data.inventory[itemId] <= 0 then
            data.inventory[itemId] = nil
        end
    end
end

-- Get player inventory item count
local function getPlayerInventoryItemCount(source, itemId)
    local data = getPlayerData(source)
    if data and data.inventory[itemId] then
        return data.inventory[itemId]
    else
        return 0
    end
end

-- Add weapon to player
local function addPlayerWeapon(source, weaponName)
    local data = getPlayerData(source)
    if data then
        data.weapons[weaponName] = true
        TriggerClientEvent('cops_and_robbers:addWeapon', source, weaponName)
    end
end

-- Remove weapon from player
local function removePlayerWeapon(source, weaponName)
    local data = getPlayerData(source)
    if data and data.weapons[weaponName] then
        data.weapons[weaponName] = nil
        TriggerClientEvent('cops_and_robbers:removeWeapon', source, weaponName)
    end
end

-- Check if player has weapon
local function playerHasWeapon(source, weaponName)
    local data = getPlayerData(source)
    if data and data.weapons[weaponName] then
        return true
    else
        return false
    end
end

-- Function to get item details by itemId using the lookup table
local function getItemById(itemId)
    return ConfigItemsById[itemId]
end

-- Function to give item(s) to player
local function givePlayerItem(source, item, quantity)
    quantity = quantity or 1
    if not item or not item.category then
        TriggerClientEvent('cops_and_robbers:showNotification', source, "Invalid item data.")
        return
    end

    if item.category == "Weapons" or item.category == "Melee Weapons" then
        -- For weapons, give only one
        if not playerHasWeapon(source, item.itemId) then
            addPlayerWeapon(source, item.itemId)
            savePlayerData(source)
            TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, item.itemId, 1)
        else
            TriggerClientEvent('cops_and_robbers:purchaseFailed', source, "You already own this weapon.")
        end
    elseif item.category == "Ammunition" then
        local ammoCount = getAmmoCountForItem(item.itemId) * quantity
        -- Extract weapon name from ammo itemId (e.g., "ammo_pistol" -> "weapon_pistol")
        local weaponName = item.itemId:gsub("^ammo_", "weapon_")
        if playerHasWeapon(source, weaponName) then
            TriggerClientEvent('cops_and_robbers:addAmmo', source, weaponName, ammoCount)
            savePlayerData(source)
            TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, item.itemId, quantity)
        else
            TriggerClientEvent('cops_and_robbers:purchaseFailed', source, "You don't have the weapon for this ammo.")
        end
    elseif item.category == "Armor" then
        -- Armor is applied immediately
        TriggerClientEvent('cops_and_robbers:applyArmor', source, item.itemId)
        savePlayerData(source)
        TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, item.itemId, 1)
    else
        addPlayerInventoryItem(source, item.itemId, quantity)
        savePlayerData(source)
        TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, item.itemId, quantity)
    end
end

-- Function to initialize player stats
local function initializePlayerStats(player)
    if not playerStats[player] then
        playerStats[player] = { heists = 0, arrests = 0, rewards = 0, experience = 0, level = 1 }
    end
end

-- =====================================
--       PURCHASE HISTORY MANAGEMENT
-- =====================================

-- Function to load purchase history from file
local function loadPurchaseHistory()
    local fileData = LoadResourceFile(GetCurrentResourceName(), "purchase_history.json")
    if fileData and fileData ~= "" then
        local success, decodedData = pcall(json.decode, fileData)
        if success and decodedData then
            purchaseHistory = decodedData
        else
            print("Error decoding purchase_history.json. Initializing empty purchase history.")
            purchaseHistory = {}
            initializePurchaseData()
        end
    else
        purchaseHistory = {}
        initializePurchaseData()
    end
end

-- Function to save purchase history to file
local function savePurchaseHistory()
    local jsonData = json.encode(purchaseHistory, { indent = true })
    if jsonData then
        SaveResourceFile(GetCurrentResourceName(), "purchase_history.json", jsonData, -1)
    else
        print("Error encoding purchase_history.json.")
    end
end

-- Function to calculate dynamic price
local function getDynamicPrice(itemId)
    local item = getItemById(itemId)
    if not item then
        return nil  -- Item not found
    end

    local basePrice = item.basePrice

    -- Ensure that purchaseHistory[itemId] exists
    if not purchaseHistory[itemId] then
        purchaseHistory[itemId] = {}
    end

    local currentTime = os.time()
    local timeframeStart = currentTime - Config.PopularityTimeframe

    -- Count purchases within the timeframe
    local purchaseCount = 0
    for _, purchaseTime in ipairs(purchaseHistory[itemId]) do
        if purchaseTime >= timeframeStart then
            purchaseCount = purchaseCount + 1
        end
    end

    if purchaseCount >= Config.PopularityThreshold.high then
        -- Item is popular, increase price
        return math.floor(basePrice * Config.PriceIncreaseFactor)
    elseif purchaseCount <= Config.PopularityThreshold.low then
        -- Item is less popular, decrease price
        return math.floor(basePrice * Config.PriceDecreaseFactor)
    else
        -- Normal price
        return basePrice
    end
end

-- =====================================
--           BAN MANAGEMENT
-- =====================================

-- Function to load bans from file and Config.BannedPlayers
local function LoadBans()
    -- Load bans from bans.json
    local bans = LoadResourceFile(GetCurrentResourceName(), "bans.json")
    if bans and bans ~= "" then
        local success, decodedBans = pcall(json.decode, bans)
        if success and decodedBans then
            for identifier, banInfo in pairs(decodedBans) do
                bannedPlayers[identifier] = banInfo
            end
        else
            print("Error decoding bans.json. Initializing empty bans.")
            bannedPlayers = {}
        end
    else
        bannedPlayers = {}
    end

    -- Merge Config.BannedPlayers into bannedPlayers
    for identifier, banInfo in pairs(Config.BannedPlayers) do
        bannedPlayers[identifier] = banInfo
    end

    -- Save merged bans back to file
    saveBans()
end

-- =====================================
--       ADMIN FUNCTIONS
-- =====================================

-- Helper function to check if a player is an admin (should be identical to admin.lua's version)
local function IsAdmin(playerId)
    local playerIdentifiers = GetPlayerIdentifiers(playerId) -- Using GetPlayerIdentifiers directly for server-side
    if not playerIdentifiers then return false end

    if not Config or type(Config.Admins) ~= "table" then
        print("Error: Config.Admins is not loaded or not a table. Ensure config.lua defines it correctly.")
        return false
    end

    for _, identifier in ipairs(playerIdentifiers) do
        if Config.Admins[identifier] then
            return true
        end
    end
    return false
end

-- Helper function to check if a player ID is valid (i.e. currently connected)
-- Expects targetId to be a number (player ID as GetPlayers() returns numbers)
local function IsValidPlayer(targetId)
    -- Ensure targetId is a number, as it might come as a string from events triggered by commands.
    -- Admin commands in admin.lua already convert it to a number.
    if type(targetId) ~= "number" then
        targetId = tonumber(targetId)
        if not targetId then
            print("IsValidPlayer: targetId is not a valid number: " .. tostring(targetId))
            return false
        end
    end

    for _, playerId in ipairs(GetPlayers()) do
        if playerId == targetId then
            return true
        end
    end
    return false
end

-- =====================================
--           EVENT HANDLERS
-- =====================================

-- Event handler for player connecting (load player data and check for bans)
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)

    deferrals.defer()
    Citizen.Wait(0)
    deferrals.update("Checking your ban status...")

    -- Check for bans
    for _, identifier in ipairs(identifiers) do
        if bannedPlayers[identifier] then
            local banReason = bannedPlayers[identifier].reason or "No reason provided."
            LogAdminAction(string.format("Connection Denied: Player %s (Identifiers: %s). Reason: Banned - %s", name, table.concat(identifiers, ", "), banReason))
            deferrals.done("You are banned from this server. Reason: " .. banReason)
            CancelEvent()
            return
        end
    end

    LogAdminAction(string.format("Player Connecting: %s (ID: %d, Identifiers: %s)", name, src, table.concat(identifiers, ", ")))
    deferrals.update("Loading your player data...")

    -- Load player data
    loadPlayerData(src)

    deferrals.done()
    LogAdminAction(string.format("Player Connected: %s (ID: %d)", GetPlayerName(src), src))
end)

-- Event handler for player disconnecting
AddEventHandler('playerDropped', function(reason)
    local src = source
    LogAdminAction(string.format("Player Disconnected: %s (ID: %d). Reason: %s", GetPlayerName(src), src, reason))
    savePlayerData(src)
    playerData[src] = nil
    cops[src] = nil
    robbers[src] = nil
    playerRoles[src] = nil
    playerPositions[src] = nil
end)

-- Event handler to send player data to client
RegisterNetEvent('cops_and_robbers:requestPlayerData')
AddEventHandler('cops_and_robbers:requestPlayerData', function()
    local src = source
    local data = getPlayerData(src)
    if data then
        TriggerClientEvent('cops_and_robbers:receivePlayerData', src, data)
    end
end)

-- Event handler for item purchase with quantity
RegisterNetEvent('cops_and_robbers:purchaseItem')
AddEventHandler('cops_and_robbers:purchaseItem', function(itemId, quantity)
    local src = source
    local timestamp = os.time()
    quantity = tonumber(quantity) or 1

    -- Validate item
    local item = getItemById(itemId)
    if not item then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, 'Invalid item.')
        return
    end

    -- Validate quantity
    if quantity < 1 or quantity > 100 then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, 'Invalid quantity.')
        return
    end

    -- Handle player cash balance
    local playerMoney = getPlayerMoney(src)
    local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
    local totalPrice = dynamicPrice * quantity
    if playerMoney < totalPrice then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, 'Insufficient funds.')
        return
    end

    -- Deduct money and give item(s)
    removePlayerMoney(src, totalPrice)
    givePlayerItem(src, item, quantity)

    -- Record the purchase
    if not purchaseHistory[itemId] then
        purchaseHistory[itemId] = {}
    end

    for i = 1, quantity do
        table.insert(purchaseHistory[itemId], timestamp)
    end

    -- Remove outdated purchases
    local updatedHistory = {}
    for _, purchaseTime in ipairs(purchaseHistory[itemId]) do
        if purchaseTime >= (timestamp - Config.PopularityTimeframe) then
            table.insert(updatedHistory, purchaseTime)
        end
    end
    purchaseHistory[itemId] = updatedHistory

    -- Save purchase history
    savePurchaseHistory()

    -- Acknowledge the purchase
    TriggerClientEvent('cops_and_robbers:purchaseConfirmed', src, itemId, quantity)
end)

-- Event handler for selling items
RegisterNetEvent('cops_and_robbers:sellItem')
AddEventHandler('cops_and_robbers:sellItem', function(itemId, quantity)
    local src = source
    quantity = tonumber(quantity) or 1

    -- Validate item
    local item = getItemById(itemId)
    if not item then
        TriggerClientEvent('cops_and_robbers:sellFailed', src, 'Invalid item.')
        return
    end

    -- Validate quantity
    if quantity < 1 or quantity > 100 then
        TriggerClientEvent('cops_and_robbers:sellFailed', src, 'Invalid quantity.')
        return
    end

    -- Handle player inventory
    local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
    local sellPrice = math.floor(dynamicPrice * Config.SellPriceFactor)
    local totalSellPrice = sellPrice * quantity

    if item.category == "Weapons" or item.category == "Melee Weapons" then
        if playerHasWeapon(src, item.itemId) then
            removePlayerWeapon(src, item.itemId)
            addPlayerMoney(src, sellPrice) -- Selling one weapon grants one sellPrice
            savePlayerData(src)
            TriggerClientEvent('cops_and_robbers:sellConfirmed', src, item.itemId, 1)
        else
            TriggerClientEvent('cops_and_robbers:sellFailed', src, 'You do not own this weapon.')
        end
    else
        local itemCount = getPlayerInventoryItemCount(src, item.itemId)
        if itemCount >= quantity then
            removePlayerInventoryItem(src, item.itemId, quantity)
            addPlayerMoney(src, totalSellPrice)
            savePlayerData(src)
            TriggerClientEvent('cops_and_robbers:sellConfirmed', src, item.itemId, quantity)
        else
            TriggerClientEvent('cops_and_robbers:sellFailed', src, 'Insufficient items.')
        end
    end
end)

-- Event handler for client requesting item list
RegisterNetEvent('cops_and_robbers:getItemList')
AddEventHandler('cops_and_robbers:getItemList', function(storeType, vendorItems, storeName)
    local src = source
    local itemList = {}

    for _, item in ipairs(Config.Items) do
        if storeType == "AmmuNation" or (storeType == "Vendor" and vendorItems and hasValue(vendorItems, item.itemId)) then
            local dynamicPrice = getDynamicPrice(item.itemId) or item.basePrice
            table.insert(itemList, {
                name = item.name,
                itemId = item.itemId,
                price = dynamicPrice,
                category = item.category,
            })
        end
    end

    TriggerClientEvent('cops_and_robbers:sendItemList', src, storeName, itemList)
end)

-- Event handler to send player inventory to client
RegisterNetEvent('cops_and_robbers:getPlayerInventory')
AddEventHandler('cops_and_robbers:getPlayerInventory', function()
    local src = source
    local data = getPlayerData(src)
    if data then
        local items = {}
        -- Inventory items
        for itemId, count in pairs(data.inventory) do
            local item = getItemById(itemId)
            if item then
                local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
                local sellPrice = math.floor(dynamicPrice * Config.SellPriceFactor)
                table.insert(items, {
                    name = item.name,
                    itemId = item.itemId,
                    count = count,
                    sellPrice = sellPrice
                })
            end
        end

        -- Weapons
        for weaponName, _ in pairs(data.weapons) do
            local item = getItemById(weaponName)
            if item then
                local dynamicPrice = getDynamicPrice(weaponName) or item.basePrice
                local sellPrice = math.floor(dynamicPrice * Config.SellPriceFactor)
                table.insert(items, {
                    name = item.name,
                    itemId = item.itemId,
                    count = 1,
                    sellPrice = sellPrice
                })
            end
        end

        TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, items)
    end
end)

-- Receive player role from client
RegisterNetEvent('cops_and_robbers:setPlayerRole')
AddEventHandler('cops_and_robbers:setPlayerRole', function(selectedRole) -- Renamed 'role' to 'selectedRole' for clarity
    local src = source
    local previousPlayerRole = playerRoles[src] -- Get the player's current role before changing

    -- Team Balancing Incentive Check
    if Config.TeamBalanceSettings.enabled and previousPlayerRole ~= selectedRole then -- Only apply if role actually changes or is newly set
        local numCops = 0
        local numRobbers = 0
        for _, r in pairs(playerRoles) do
            if r == 'cop' then
                numCops = numCops + 1
            elseif r == 'robber' then
                numRobbers = numRobbers + 1
            end
        end

        -- If player had a role, temporarily adjust count for the check as if they've left their old team
        if previousPlayerRole == 'cop' then
            numCops = numCops - 1
        elseif previousPlayerRole == 'robber' then
            numRobbers = numRobbers - 1
        end

        local incentiveApplied = false
        if selectedRole == 'cop' then
            if numCops < numRobbers and (numRobbers - numCops) >= Config.TeamBalanceSettings.threshold then
                addPlayerMoney(src, Config.TeamBalanceSettings.incentiveCash)
                TriggerClientEvent('chat:addMessage', src, { args = { "^2System", string.format(Config.TeamBalanceSettings.notificationMessage, Config.TeamBalanceSettings.incentiveCash, "Cops") } })
                LogAdminAction(string.format("TeamBalance: Player %s (ID: %d) received $%s incentive for joining Cops. Cops: %d, Robbers: %d (before join)", GetPlayerName(src), src, Config.TeamBalanceSettings.incentiveCash, numCops, numRobbers))
                incentiveApplied = true
            end
        elseif selectedRole == 'robber' then
            if numRobbers < numCops and (numCops - numRobbers) >= Config.TeamBalanceSettings.threshold then
                addPlayerMoney(src, Config.TeamBalanceSettings.incentiveCash)
                TriggerClientEvent('chat:addMessage', src, { args = { "^2System", string.format(Config.TeamBalanceSettings.notificationMessage, Config.TeamBalanceSettings.incentiveCash, "Robbers") } })
                LogAdminAction(string.format("TeamBalance: Player %s (ID: %d) received $%s incentive for joining Robbers. Cops: %d, Robbers: %d (before join)", GetPlayerName(src), src, Config.TeamBalanceSettings.incentiveCash, numCops, numRobbers))
                incentiveApplied = true
            end
        end
        if incentiveApplied then
            savePlayerData(src) -- Save player data if money was added
        end
    end

    -- Proceed with existing role assignment logic
    playerRoles[src] = selectedRole
    if selectedRole == 'cop' then
        cops[src] = true
        robbers[src] = nil
    elseif selectedRole == 'robber' then
        robbers[src] = true
        cops[src] = nil
    else
        -- Invalid role
        playerRoles[src] = nil -- Should ideally not happen if NUI is well-designed
    end
    TriggerClientEvent('cops_and_robbers:setRole', src, selectedRole)
    if playerData[src] then -- Ensure player data exists before trying to set role in it
        playerData[src].role = selectedRole -- Persist role in playerData
        savePlayerData(src) -- Save data after role change
    end
end)

-- Receive player positions and wanted levels from clients (with throttling)
RegisterNetEvent('cops_and_robbers:updatePosition')
AddEventHandler('cops_and_robbers:updatePosition', function(position, wantedLvlClient) -- Renamed wantedLvl to wantedLvlClient to avoid confusion with server data
    local src = source
    local now = GetGameTimer() -- Returns time in ms
    if playerUpdateTimestamps[src] and (now - playerUpdateTimestamps[src]) < 100 then
        return -- Throttle updates: ignore if less than 100ms since last update
    end
    playerUpdateTimestamps[src] = now
    playerPositions[src] = { position = position, wantedLevel = wantedLvlClient } -- Store client reported wanted level if needed, or use server's

    -- Wanted system: Update lastSeenByCopTimestamp if player is wanted and near a cop
    if playerData[src] and playerData[src].wantedPoints > 0 then
        local playerCoords = vector3(position.x, position.y, position.z)
        for copId, _ in pairs(cops) do
            if cops[copId] and playerPositions[copId] then -- Check if copId is valid and has position data
                local copCoords = vector3(playerPositions[copId].position.x, playerPositions[copId].position.y, playerPositions[copId].position.z)
                if #(playerCoords - copCoords) < 75.0 then -- Cop sight distance (e.g., 75 units)
                    playerData[src].lastSeenByCopTimestamp = GetGameTimer()
                    -- LogAdminAction(string.format("Wanted Player %s seen by Cop %s", GetPlayerName(src), GetPlayerName(copId))) -- Optional: for debugging
                    break -- Seen by one cop is enough for this update
                end
            end
        end
    end
end)

-----------------------------------------------------------
-- Wanted Level Decay Thread
-----------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.WantedSettings.decayInterval)
        local currentTime = GetGameTimer()

        for _, pId in ipairs(GetPlayers()) do
            if playerData[pId] and playerData[pId].wantedPoints > 0 then
                local pData = playerData[pId]
                if (currentTime - pData.lastCrimeTimestamp) > Config.WantedSettings.decayCooldown and
                   (currentTime - pData.lastSeenByCopTimestamp) > Config.WantedSettings.sightCooldown then

                    local oldPoints = pData.wantedPoints
                    pData.wantedPoints = math.max(0, pData.wantedPoints - Config.WantedSettings.decayRate)

                    if pData.wantedPoints ~= oldPoints then
                        -- LogAdminAction(string.format("Wanted Decay: Player %s (ID: %d) points %d -> %d", GetPlayerName(pId), pId, oldPoints, pData.wantedPoints))
                        UpdatePlayerWantedLevel(pId)
                        savePlayerData(pId) -- Save player data after decay
                    end
                end
            end
        end
    end
end)

-----------------------------------------------------------
-- Contraband Drop System
-----------------------------------------------------------
local function SpawnContrabandDrop()
    if tablelength(activeContrabandDrops) >= Config.MaxActiveContrabandDrops then
        -- print("Max active contraband drops reached.")
        return
    end

    -- Find an available location (not currently in use)
    local availableLocations = {}
    for _, loc in ipairs(Config.ContrabandDropLocations) do
        local inUse = false
        for _, activeDrop in pairs(activeContrabandDrops) do
            if activeDrop.location.x == loc.x and activeDrop.location.y == loc.y and activeDrop.location.z == loc.z then
                inUse = true
                break
            end
        end
        if not inUse then
            table.insert(availableLocations, loc)
        end
    end

    if #availableLocations == 0 then
        -- print("No available locations for contraband drop.")
        return
    end

    local location = availableLocations[math.random(#availableLocations)]
    local item = Config.ContrabandItems[math.random(#Config.ContrabandItems)]
    local dropId = "drop_" .. math.random(10000, 99999) -- Generate a somewhat unique ID

    activeContrabandDrops[dropId] = {
        id = dropId,
        location = location,
        item = item,
        playersCollecting = {} -- Stores { playerId = startTime }
    }

    TriggerClientEvent('cops_and_robbers:contrabandDropSpawned', -1, dropId, location, item.name, item.modelHash) -- Send modelHash to client
    LogAdminAction(string.format("Contraband Drop Spawned: ID %s, Item %s, Location %s", dropId, item.name, json.encode(location)))
    print(string.format("Contraband Drop Spawned: ID %s, Item %s at %s", dropId, item.name, json.encode(location)))
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) -- Check every 10 seconds, for example
        if GetGameTimer() >= nextContrabandDropTimestamp then
            SpawnContrabandDrop()
            nextContrabandDropTimestamp = GetGameTimer() + Config.ContrabandDropInterval
            -- LogAdminAction("Next contraband drop scheduled around: " .. os.date("%X", math.floor((GetGameTimer() + Config.ContrabandDropInterval) / 1000)))
        end
    end
end)

RegisterNetEvent('cops_and_robbers:startCollectingContraband')
AddEventHandler('cops_and_robbers:startCollectingContraband', function(dropId)
    local robberId = source
    local drop = activeContrabandDrops[dropId]

    if not drop then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~This contraband drop is no longer available.")
        return
    end

    if not playerRoles[robberId] or playerRoles[robberId] ~= 'robber' then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Only robbers can collect contraband.")
        return
    end

    -- Optional: Check if someone else is already successfully collected (though drop would be nil)
    -- More complex logic could be added here if multiple players can attempt simultaneously but only one wins.
    -- For now, simple approach: player starts collecting, server validates on finish.

    drop.playersCollecting[robberId] = GetGameTimer()
    TriggerClientEvent('cops_and_robbers:collectingContrabandStarted', robberId, dropId, Config.ContrabandCollectionTime)
    LogAdminAction(string.format("Contraband Collection Started: Robber %s (ID: %d) on drop %s (%s).", GetPlayerName(robberId), robberId, dropId, drop.item.name))
end)

RegisterNetEvent('cops_and_robbers:finishCollectingContraband')
AddEventHandler('cops_and_robbers:finishCollectingContraband', function(dropId)
    local robberId = source
    local drop = activeContrabandDrops[dropId]

    if not drop then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~This contraband drop is no longer available or was already collected.")
        return
    end

    if not drop.playersCollecting[robberId] then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Collection not started or was interrupted.")
        return
    end

    local collectionStartTime = drop.playersCollecting[robberId]
    if (GetGameTimer() - collectionStartTime) < Config.ContrabandCollectionTime - 500 then -- Allow a small buffer for network latency
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Collection interrupted or too fast.")
        LogAdminAction(string.format("Contraband Collection Fail (Too Fast): Robber %s (ID: %d) on drop %s.", GetPlayerName(robberId), robberId, dropId))
        drop.playersCollecting[robberId] = nil -- Allow re-try if needed, or implement stricter lockout
        return
    end

    addPlayerMoney(robberId, drop.item.value)
    savePlayerData(robberId) -- Ensure data is saved after getting reward

    LogAdminAction(string.format("Contraband Collected: Robber %s (ID: %d) collected %s from drop %s for $%d.", GetPlayerName(robberId), robberId, drop.item.name, dropId, drop.item.value))
    TriggerClientEvent('cops_and_robbers:showNotification', robberId, string.format("~g~You collected %s worth $%d!", drop.item.name, drop.item.value))

    -- Announce to everyone else
    TriggerClientEvent('cops_and_robbers:contrabandDropCollected', -1, dropId, GetPlayerName(robberId), drop.item.name)

    activeContrabandDrops[dropId] = nil -- Remove the drop
end)

-----------------------------------------------------------

-- =====================================
--           HEIST MANAGEMENT
-- =====================================

-- Function to notify nearby cops with GPS update and sound
local function notifyNearbyCops(bankId, bankLocation, bankName)
    for copId, _ in pairs(cops) do
        local copData = playerPositions[copId]
        if copData then
            local copPos = vector3(copData.position.x, copData.position.y, copData.position.z)
            local distance = #(copPos - bankLocation)
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
    local src = source
    if not robbers[src] then
        return -- Only robbers can start heists
    end

    local currentTime = os.time()
    if heistCooldowns[src] and currentTime < heistCooldowns[src] then
        TriggerClientEvent('cops_and_robbers:heistOnCooldown', src)
        return
    end

    -- Set cooldown for the player
    heistCooldowns[src] = currentTime + Config.HeistCooldown

    local bank = Config.BankVaults[bankId]
    if bank then
        notifyNearbyCops(bank.id, bank.location, bank.name)
        LogAdminAction(string.format("Bank Heist Started: Robber %s (ID: %d) started heist at Bank %s (%s).", GetPlayerName(src), src, bankId, bank.name))
        -- Send bank name and duration to the robber's client to show timer via NUI
        TriggerClientEvent('cops_and_robbers:showHeistTimerUI', src, bank.name, Config.HeistTimers.heistDuration)
    else
        LogAdminAction(string.format("Bank Heist Fail: Robber %s (ID: %d) attempted invalid bank ID %s.", GetPlayerName(src), src, bankId))
        TriggerClientEvent('cops_and_robbers:heistFailed', src, "Invalid bank ID.")
    end
end)

-- =====================================
--        WANTED LEVEL SYSTEM
-- =====================================

-- Function to notify cops of a wanted robber
local function notifyCopsOfWantedRobber(robberId, robberPosition)
    for copId, _ in pairs(cops) do
        TriggerClientEvent('cops_and_robbers:notifyWantedRobber', copId, robberId, robberPosition)
    end
end

-- Periodically check for wanted robbers and notify cops
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) -- Every 10 seconds
        for robberId, data in pairs(playerPositions) do
            if robbers[robberId] and data.wantedLevel and data.wantedLevel >= Config.WantedLevels[3].stars then
                notifyCopsOfWantedRobber(robberId, data.position)
            end
        end
    end
end)

-- =====================================
--           NUI CALLBACKS (SERVER)
-- =====================================

RegisterNUICallback('buyItem', function(data, cb)
    local src = source
    local itemId = data.itemId
    local quantity = tonumber(data.quantity) or 1

    -- Validate item
    local item = getItemById(itemId)
    if not item then
        cb({ status = 'failed', message = 'Invalid item.' })
        return
    end

    -- Validate quantity
    if quantity < 1 or quantity > 100 then -- Max quantity check
        cb({ status = 'failed', message = 'Invalid quantity.' })
        return
    end

    -- Handle player cash balance
    local playerMoney = getPlayerMoney(src)
    local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
    local totalPrice = dynamicPrice * quantity
    if playerMoney < totalPrice then
        cb({ status = 'failed', message = 'Insufficient funds.' })
        return
    end

    -- Check if item is for Cops only
    if item.forCop and (not playerRoles[src] or playerRoles[src] ~= 'cop') then
        cb({ status = 'failed', message = 'This item is restricted to Cops.'})
        return
    end

    -- Deduct money and give item(s) - This logic is similar to 'cops_and_robbers:purchaseItem'
    removePlayerMoney(src, totalPrice)
    givePlayerItem(src, item, quantity) -- This function already handles client notifications and saving player data

    -- Record the purchase (as in 'cops_and_robbers:purchaseItem')
    local timestamp = os.time()
    if not purchaseHistory[itemId] then
        purchaseHistory[itemId] = {}
    end
    for i = 1, quantity do
        table.insert(purchaseHistory[itemId], timestamp)
    end
    local updatedHistory = {}
    for _, purchaseTime in ipairs(purchaseHistory[itemId]) do
        if purchaseTime >= (timestamp - Config.PopularityTimeframe) then
            table.insert(updatedHistory, purchaseTime)
        end
    end
    purchaseHistory[itemId] = updatedHistory
    savePurchaseHistory()
    LogAdminAction(string.format("NUI Purchase: Player %s (ID: %d) purchased %d x %s for $%d.", GetPlayerName(src), src, quantity, item.name, totalPrice))
    cb({ status = 'success', itemName = item.name, quantity = quantity })
end)

RegisterNUICallback('sellItem', function(data, cb)
    local src = source
    LogAdminAction(string.format("NUI Sell Attempt: Player %s (ID: %d) item %s, quantity %d.", GetPlayerName(src), src, data.itemId, data.quantity or 1))
    local itemId = data.itemId
    local quantity = tonumber(data.quantity) or 1

    local item = getItemById(itemId)
    if not item then
        cb({ status = 'failed', message = 'Invalid item.' })
        return
    end

    if quantity < 1 or quantity > 100 then -- Max quantity, could be item specific for selling
        cb({ status = 'failed', message = 'Invalid quantity.' })
        return
    end

    local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
    local sellPrice = math.floor(dynamicPrice * Config.SellPriceFactor)
    local totalSellPrice = sellPrice * quantity

    local successSell = false
    if item.category == "Weapons" or item.category == "Melee Weapons" then
        if playerHasWeapon(src, item.itemId) then
            removePlayerWeapon(src, item.itemId) -- This triggers client event
            addPlayerMoney(src, sellPrice)
            savePlayerData(src)
            successSell = true
        else
            cb({ status = 'failed', message = 'You do not own this weapon.' })
            return
        end
    else
        local itemCount = getPlayerInventoryItemCount(src, item.itemId)
        if itemCount >= quantity then
            removePlayerInventoryItem(src, item.itemId, quantity)
            addPlayerMoney(src, totalSellPrice)
            savePlayerData(src)
            successSell = true
        else
            cb({ status = 'failed', message = 'Insufficient items.' })
            return
        end
    end

    if successSell then
        LogAdminAction(string.format("NUI Sell: Player %s (ID: %d) sold %d x %s for $%d.", GetPlayerName(src), src, quantity, item.name, totalSellPrice))
        cb({ status = 'success', itemName = item.name, quantity = quantity })
    else
        -- Should have been caught by specific checks, but as a fallback
        LogAdminAction(string.format("NUI Sell Fail: Player %s (ID: %d) failed to sell %d x %s.", GetPlayerName(src), src, quantity, item.name))
        cb({ status = 'failed', message = 'Could not sell item.' })
    end
end)

RegisterNUICallback('getPlayerInventory', function(data, cb)
    local src = source
    -- LogAdminAction(string.format("NUI GetInventory: Player %s (ID: %d) fetched inventory.", GetPlayerName(src), src)) -- Can be spammy
    local playerDataInstance = getPlayerData(src)
    local inventoryForClient = {}

    if playerDataInstance then
        -- Inventory items
        if playerDataInstance.inventory then
            for itemId, count in pairs(playerDataInstance.inventory) do
                local itemDetails = getItemById(itemId)
                if itemDetails then
                    local dynamicPrice = getDynamicPrice(itemId) or itemDetails.basePrice
                    local sellPrice = math.floor(dynamicPrice * Config.SellPriceFactor)
                    table.insert(inventoryForClient, {
                        name = itemDetails.name,
                        itemId = itemId,
                        count = count,
                        sellPrice = sellPrice,
                        category = itemDetails.category -- Optional: useful for client-side filtering if needed
                    })
                end
            end
        end
        -- Weapons
        if playerDataInstance.weapons then
            for weaponName, _ in pairs(playerDataInstance.weapons) do
                local itemDetails = getItemById(weaponName)
                if itemDetails then
                    local dynamicPrice = getDynamicPrice(weaponName) or itemDetails.basePrice
                    local sellPrice = math.floor(dynamicPrice * Config.SellPriceFactor)
                    table.insert(inventoryForClient, {
                        name = itemDetails.name,
                        itemId = weaponName,
                        count = 1, -- Weapons are typically count 1
                        sellPrice = sellPrice,
                        category = itemDetails.category
                    })
                end
            end
        end
        cb({ items = inventoryForClient })
    else
        LogAdminAction(string.format("NUI GetInventory Fail: Player %s (ID: %d) - no player data.", GetPlayerName(src), src))
        cb({ items = {} }) -- Send empty list if no player data
    end
end)


-- =====================================
--        SPIKE STRIP EVENTS
-- =====================================
RegisterNetEvent('cops_and_robbers:deploySpikeStrip')
AddEventHandler('cops_and_robbers:deploySpikeStrip', function(deploymentLocation)
    local src = source
    if not playerRoles[src] or playerRoles[src] ~= 'cop' then
        TriggerClientEvent('cops_and_robbers:showNotification', src, "~r~Only Cops can deploy spike strips.")
        return
    end

    -- Check if player has spike strips (simplified: server trusts client removed one for now, or implement server inventory check)
    -- For now, we focus on deployment limit
    playerSpikeStripCount[src] = playerSpikeStripCount[src] or 0
    if playerSpikeStripCount[src] >= Config.MaxDeployedSpikeStrips then
        TriggerClientEvent('cops_and_robbers:showNotification', src, "~r~You have reached your maximum deployed spike strips.")
        return
    end

    spikeStripCounter = spikeStripCounter + 1
    local stripId = "spikestrip_" .. spikeStripCounter

    local expirationTimer = SetTimeout(Config.SpikeStripDuration, function()
        if deployedSpikeStrips[stripId] then
            TriggerClientEvent('cops_and_robbers:removeSpikeStrip', -1, stripId) -- Notify all clients
            deployedSpikeStrips[stripId] = nil
            if playerSpikeStripCount[deployedSpikeStrips[stripId].owner] then
                 playerSpikeStripCount[deployedSpikeStrips[stripId].owner] = playerSpikeStripCount[deployedSpikeStrips[stripId].owner] - 1
            end
            print("Spike strip " .. stripId .. " expired and removed.")
        end
    end)

    deployedSpikeStrips[stripId] = {
        id = stripId,
        owner = src,
        location = deploymentLocation,
        expirationTimer = expirationTimer
    }
    playerSpikeStripCount[src] = playerSpikeStripCount[src] + 1

    LogAdminAction(string.format("Spike Strip Deployed: Cop %s (ID: %d) deployed strip %s at %s.", GetPlayerName(src), src, stripId, json.encode(deploymentLocation)))
    TriggerClientEvent('cops_and_robbers:renderSpikeStrip', -1, stripId, deploymentLocation) -- Notify all clients to render
    TriggerClientEvent('cops_and_robbers:showNotification', src, "~g~Spike strip deployed. ID: " .. stripId)
end)

RegisterNetEvent('cops_and_robbers:vehicleHitSpikeStrip')
AddEventHandler('cops_and_robbers:vehicleHitSpikeStrip', function(stripId, vehicleNetId)
    local src = source -- client who owns the vehicle that hit the strip
    local strip = deployedSpikeStrips[stripId]

    if not strip then
        print("Vehicle hit an unknown or already removed spike strip: " .. stripId)
        return
    end

    print("Vehicle (NetID: " .. vehicleNetId .. ") hit spike strip " .. stripId .. " deployed by player " .. strip.owner)
    -- Notify the client that owns the vehicle to burst its tires
    TriggerClientEvent('cops_and_robbers:applySpikeEffectToVehicle', src, vehicleNetId)

    -- Optionally, remove the spike strip after one hit or N hits
    -- For now, it stays until duration or owner removes it (not implemented yet)
    -- Or remove it now:
    -- ClearTimeout(strip.expirationTimer)
    -- deployedSpikeStrips[stripId] = nil
    -- if playerSpikeStripCount[strip.owner] then
    --     playerSpikeStripCount[strip.owner] = playerSpikeStripCount[strip.owner] - 1
    -- end
    -- TriggerClientEvent('cops_and_robbers:removeSpikeStrip', -1, stripId)
end)


-- =====================================
--        SPEED RADAR EVENTS
-- =====================================
RegisterNetEvent('cops_and_robbers:vehicleSpeeding')
AddEventHandler('cops_and_robbers:vehicleSpeeding', function(targetPlayerId, vehicleName, speed)
    local src = source -- Cop who issued the fine
    if not playerRoles[src] or playerRoles[src] ~= 'cop' then
        TriggerClientEvent('cops_and_robbers:showNotification', src, "~r~Only Cops can issue speeding tickets.")
        return
    end

    if not IsValidPlayer(targetPlayerId) then
        TriggerClientEvent('cops_and_robbers:showNotification', src, "~r~Target player for speeding ticket is not online.")
        return
    end

    local targetPlayerData = getPlayerData(targetPlayerId)
    if not targetPlayerData then
        TriggerClientEvent('cops_and_robbers:showNotification', src, "~r~Could not find data for target player.")
        return
    end

    removePlayerMoney(targetPlayerId, Config.SpeedingFine)
    -- savePlayerData(targetPlayerId) -- Save is handled by IncreaseWantedPoints

    -- Notify target player
    local fineMessage = string.format("~r~You have been fined $%d for speeding in a %s at %.0f km/h.", Config.SpeedingFine, vehicleName, speed)
    LogAdminAction(string.format("Speeding Fine Issued: Cop %s (ID: %d) fined Player %s (ID: %d) $%d for driving %s at %.0f km/h.", GetPlayerName(src), src, GetPlayerName(targetPlayerId), targetPlayerId, Config.SpeedingFine, vehicleName, speed))
    TriggerClientEvent('cops_and_robbers:showNotification', targetPlayerId, fineMessage)

    -- Notify cop
    local copMessage = string.format("~g~Issued speeding ticket of $%d to player %s (ID: %d).", Config.SpeedingFine, GetPlayerName(targetPlayerId), targetPlayerId)
    TriggerClientEvent('cops_and_robbers:showNotification', src, copMessage)

    -- Increase wanted points for speeding
    IncreaseWantedPoints(targetPlayerId, 'speeding')

    -- Optional: Add to cop's stats
    -- playerStats[src].ticketsIssued = (playerStats[src].ticketsIssued or 0) + 1
    -- playerStats[src].moneyFromTickets = (playerStats[src].moneyFromTickets or 0) + Config.SpeedingFine
    -- savePlayerData(src) -- if stats are part of playerData
end)


-- =====================================
--        ENHANCED ARREST (TACKLE/SUBDUE) EVENTS
-- =====================================
local activeSubdues = {} -- { [robberId] = { copId = copId, timer = subdueTimer } }

RegisterNetEvent('cops_and_robbers:startSubdue')
AddEventHandler('cops_and_robbers:startSubdue', function(robberServerId)
    local copServerId = source

    if not playerRoles[copServerId] or playerRoles[copServerId] ~= 'cop' then
        LogAdminAction(string.format("Failed Subdue Attempt: Non-cop Player %s (ID: %d) on target %d.", GetPlayerName(copServerId), copServerId, robberServerId))
        TriggerClientEvent('cops_and_robbers:showNotification', copServerId, "~r~Only Cops can subdue.")
        return
    end

    if not playerRoles[robberServerId] or playerRoles[robberServerId] ~= 'robber' then
        LogAdminAction(string.format("Failed Subdue Attempt: Cop %s (ID: %d) on non-robber target %s (ID: %d).", GetPlayerName(copServerId), copServerId, GetPlayerName(robberServerId), robberServerId))
        TriggerClientEvent('cops_and_robbers:showNotification', copServerId, "~r~Target is not a Robber.")
        return
    end

    if activeSubdues[robberServerId] then
        LogAdminAction(string.format("Failed Subdue Attempt: Cop %s (ID: %d) on already subdued target %s (ID: %d).", GetPlayerName(copServerId), copServerId, GetPlayerName(robberServerId), robberServerId))
        TriggerClientEvent('cops_and_robbers:showNotification', copServerId, "~r~Target is already being subdued.")
        return
    end

    -- TODO: Add distance check here if not already done client-side or for anti-cheat
    LogAdminAction(string.format("Subdue Started: Cop %s (ID: %d) is subduing Robber %s (ID: %d).", GetPlayerName(copServerId), copServerId, GetPlayerName(robberServerId), robberServerId))
    TriggerClientEvent('cops_and_robbers:beginSubdueSequence', robberServerId, copServerId)

    local subdueTimer = SetTimeout(Config.SubdueTime, function()
        if activeSubdues[robberServerId] and activeSubdues[robberServerId].copId == copServerId then
            -- Proceed with arrest
            initializePlayerStats(copServerId)
            initializePlayerStats(robberServerId)

            playerStats[copServerId].arrests = (playerStats[copServerId].arrests or 0) + 1
            playerStats[copServerId].experience = (playerStats[copServerId].experience or 0) + 500 -- Example XP

            -- Using existing arrest notification and jailing logic from arrestRobber event for consistency
    LogAdminAction(string.format("Arrest (Subdue): Cop %s (ID: %d) arrested Robber %s (ID: %d).", GetPlayerName(copServerId), copServerId, GetPlayerName(robberServerId), robberServerId))
            TriggerClientEvent('cops_and_robbers:arrestNotification', robberServerId, copServerId)
            TriggerClientEvent('cops_and_robbers:sendToJail', robberServerId, 300) -- 300 seconds = 5 minutes (Consider Config value)

            TriggerClientEvent('cops_and_robbers:showNotification', copServerId, "~g~Successfully subdued and arrested " .. GetPlayerName(robberServerId))

            activeSubdues[robberServerId] = nil -- Clear subdue state
        end
    end)

    activeSubdues[robberServerId] = { copId = copServerId, timer = subdueTimer }
    TriggerClientEvent('cops_and_robbers:showNotification', copServerId, "~b~Subduing " .. GetPlayerName(robberServerId) .. "...")
end)

RegisterNetEvent('cops_and_robbers:escapeSubdue')
AddEventHandler('cops_and_robbers:escapeSubdue', function()
    local robberServerId = source
    if activeSubdues[robberServerId] then
        ClearTimeout(activeSubdues[robberServerId].timer)
        local copServerId = activeSubdues[robberServerId].copId
        activeSubdues[robberServerId] = nil
        LogAdminAction(string.format("Subdue Escaped: Robber %s (ID: %d) escaped from Cop %s (ID: %d).", GetPlayerName(robberServerId), robberServerId, GetPlayerName(copServerId), copServerId))
        TriggerClientEvent('cops_and_robbers:showNotification', copServerId, "~r~" .. GetPlayerName(robberServerId) .. " escaped your subdue attempt!")
        TriggerClientEvent('cops_and_robbers:showNotification', robberServerId, "~g~You escaped!")
        -- Unfreeze robber client-side if they were frozen by beginSubdueSequence
        TriggerClientEvent('cops_and_robbers:subdueCancelled', robberServerId)
    end
end)


-- =====================================
--        STORE ROBBERY EVENTS
-- =====================================
local robberyCooldownsStore = {} -- { [storeIndex] = os.time() + cooldown }
local activeStoreRobberies = {} -- { [robberId] = { storeIndex = storeIndex, successTimer = timer } }

RegisterNetEvent('cops_and_robbers:startStoreRobbery')
AddEventHandler('cops_and_robbers:startStoreRobbery', function(storeIndex)
    local robberId = source
    local store = Config.RobbableStores[storeIndex]

    if not playerRoles[robberId] or playerRoles[robberId] ~= 'robber' then
        -- LogAdminAction(string.format("Failed Store Robbery Attempt: Non-robber Player %s (ID: %d) at store %s.", GetPlayerName(robberId), robberId, storeIndex))
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Only Robbers can start store robberies.")
        return
    end

    if not store then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Invalid store.")
        return
    end

    if robberyCooldownsStore[storeIndex] and os.time() < robberyCooldownsStore[storeIndex] then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~" .. store.name .. " is on cooldown.")
        return
    end

    local copsOnline = 0
    for _, isCop in pairs(cops) do
        if isCop then copsOnline = copsOnline + 1 end
    end
    if copsOnline < store.copsNeeded then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, string.format("~r~Not enough Cops online. Requires %d.", store.copsNeeded))
        return
    end

    if activeStoreRobberies[robberId] then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~You are already robbing a store.")
        return
    end

    robberyCooldownsStore[storeIndex] = os.time() + store.cooldown

    -- Notify nearby Cops
    notifyNearbyCops("storeRobbery_"..storeIndex, store.location, store.name)
    LogAdminAction(string.format("Store Robbery Started: Robber %s (ID: %d) at %s (%s). Cops online: %d", GetPlayerName(robberId), robberId, storeIndex, store.name, copsOnline))

    TriggerClientEvent('cops_and_robbers:beginStoreRobberySequence', robberId, store, Config.StoreRobberyDuration)

    local successTimer = SetTimeout(Config.StoreRobberyDuration, function()
        if activeStoreRobberies[robberId] and activeStoreRobberies[robberId].storeIndex == storeIndex then
            addPlayerMoney(robberId, store.reward)
            -- savePlayerData(robberId) -- Save is handled by IncreaseWantedPoints
            LogAdminAction(string.format("Store Robbery Success: Robber %s (ID: %d) robbed %s for $%d.", GetPlayerName(robberId), robberId, store.name, store.reward))
            TriggerClientEvent('cops_and_robbers:showNotification', robberId, string.format("~g~Successfully robbed %s for $%d!", store.name, store.reward))

            -- Increase wanted points for store robbery
            IncreaseWantedPoints(robberId, 'store_robbery_medium') -- Assuming medium for general stores

            activeStoreRobberies[robberId] = nil
        end
    end)
    activeStoreRobberies[robberId] = { storeIndex = storeIndex, successTimer = successTimer }
    TriggerClientEvent('cops_and_robbers:showNotification', robberId, string.format("~y~Robbing %s... Stay inside for %d seconds.", store.name, Config.StoreRobberyDuration / 1000))
end)

RegisterNetEvent('cops_and_robbers:storeRobberyUpdate')
AddEventHandler('cops_and_robbers:storeRobberyUpdate', function(status)
    local robberId = source
    if activeStoreRobberies[robberId] then
        if status == "fled" then
            ClearTimeout(activeStoreRobberies[robberId].successTimer)
            LogAdminAction(string.format("Store Robbery Fled: Robber %s (ID: %d) fled from %s.", GetPlayerName(robberId), robberId, activeStoreRobberies[robberId].store.name))
            TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~You fled the store, robbery failed.")
            -- Optional: Notify cops the robber fled.
        end
        activeStoreRobberies[robberId] = nil
    end
end)


-- =====================================
--        ARMORED CAR HEIST EVENTS
-- =====================================
local armoredCarActive = false
local armoredCarEntity = nil
local armoredCarHeistCooldownTimer = 0
local armoredCarCurrentHealth = 0

function SpawnArmoredCar(forcedByAdmin)
    if armoredCarActive and not forcedByAdmin then return end
    if os.time() < armoredCarHeistCooldownTimer and not forcedByAdmin then
        LogAdminAction(string.format("Armored Car Spawn Denied: Cooldown active until %s.", os.date("%X", armoredCarHeistCooldownTimer)))
        return
    end

    local copsOnline = 0
    for _, isCop in pairs(cops) do
        if isCop then copsOnline = copsOnline + 1 end
    end
    if copsOnline < Config.ArmoredCarHeistCopsNeeded then
        print("Armored Car: Not enough cops online to start heist.")
        return
    end

    local model = GetHashKey(Config.ArmoredCar.model)
    RequestModel(model)
    -- Add a timeout for model loading if needed, then:
    -- while not HasModelLoaded(model) do Citizen.Wait(100) end

    -- This needs to be run in a context where it can create vehicles, e.g. main thread or specific event
    -- For now, conceptual placement. Real spawning might need to be triggered differently or ensure context.
    -- The following is a simplified spawn logic. A robust one would handle model loading waits.
    CreateThread(function() -- Use a new thread for model loading and vehicle creation
        if not HasModelLoaded(model) then
            RequestModel(model)
            local attempts = 0
            while not HasModelLoaded(model) and attempts < 100 do -- Max 10 seconds wait
                Citizen.Wait(100)
                attempts = attempts + 1
            end
        end

        if not HasModelLoaded(model) then
            print("Failed to load armored car model: " .. Config.ArmoredCar.model)
            SetModelAsNoLongerNeeded(model)
            return
        end

        armoredCarEntity = CreateVehicle(model, Config.ArmoredCar.spawnPoint.x, Config.ArmoredCar.spawnPoint.y, Config.ArmoredCar.spawnPoint.z, GetEntityHeading(PlayerPedId()), true, true)
        SetVehicleHealth(armoredCarEntity, Config.ArmoredCar.health)
        SetVehicleMaxHealth(armoredCarEntity, Config.ArmoredCar.health) -- Ensure max health is also set
        armoredCarCurrentHealth = Config.ArmoredCar.health
        SetEntityAsMissionEntity(armoredCarEntity, true, true) -- Prevent despawn

        -- Create NPC driver
        local driverPed = CreatePedInVehicle(armoredCarEntity, 4, GetHashKey("s_m_m_armoured_01"), -1, true, true) -- Vehicle type, ped model, seat index
        SetPedAsCop(driverPed, true) -- Make driver behave like a cop/guard
        SetEntityInvincible(driverPed, true) -- Make driver invincible
        TaskVehicleDriveAlongRoute(driverPed, armoredCarEntity, Config.ArmoredCar.route, 10.0, 0, 0, "DRIVING_STYLE_AVOID_EMPTY") -- Simplified route logic

        armoredCarActive = true
        armoredCarHeistCooldownTimer = os.time() + Config.ArmoredCarHeistCooldown

        LogAdminAction(string.format("Armored Car Spawned: NetID: %d. Cops online: %d. Cooldown until: %s. Forced by Admin: %s", VehToNet(armoredCarEntity), copsOnline, os.date("%X", armoredCarHeistCooldownTimer), tostring(forcedByAdmin == true)))
        TriggerClientEvent('cops_and_robbers:armoredCarSpawned', -1, VehToNet(armoredCarEntity), GetEntityCoords(armoredCarEntity))
        SetModelAsNoLongerNeeded(model)
    end)
end

-- Periodically try to spawn armored car (example: every 5 minutes if conditions met)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- 5 minutes
        SpawnArmoredCar(false) -- Not forced by admin
    end
end)

RegisterNetEvent('cops_and_robbers:damageArmoredCar')
AddEventHandler('cops_and_robbers:damageArmoredCar', function(vehicleNetId, damageAmount)
    local robberId = source
    if not armoredCarActive or not DoesEntityExist(NetToVeh(vehicleNetId)) or NetToVeh(vehicleNetId) ~= armoredCarEntity then
        return
    end

    armoredCarCurrentHealth = armoredCarCurrentHealth - damageAmount
    SetVehicleHealth(armoredCarEntity, math.max(0, armoredCarCurrentHealth))
    LogAdminAction(string.format("Armored Car Damaged: Robber %s (ID: %d) damaged Armored Car (NetID: %d) by %d. New Health: %d", GetPlayerName(robberId), robberId, vehicleNetId, damageAmount, armoredCarCurrentHealth))

    if armoredCarCurrentHealth <= 0 then
        armoredCarActive = false
        addPlayerMoney(robberId, Config.ArmoredCar.reward)
        -- savePlayerData(robberId) -- Save is handled by IncreaseWantedPoints

        LogAdminAction(string.format("Armored Car Destroyed: Robber %s (ID: %d) destroyed Armored Car (NetID: %d) and collected $%d.", GetPlayerName(robberId), robberId, vehicleNetId, Config.ArmoredCar.reward))
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, string.format("~g~Armored car destroyed! You collected $%d.", Config.ArmoredCar.reward))
        TriggerClientEvent('cops_and_robbers:armoredCarDestroyed', -1, vehicleNetId)

        -- Increase wanted points for armored car heist
        -- Increase wanted points for armored car heist
        IncreaseWantedPoints(robberId, 'armored_car_heist')

        local driver = GetPedInVehicleSeat(armoredCarEntity, -1)
        if driver and DoesEntityExist(driver) then DeleteEntity(driver) end
        if DoesEntityExist(armoredCarEntity) then DeleteEntity(armoredCarEntity) end
        armoredCarEntity = nil
    end
end)


-- =====================================
--        EMP DEVICE EVENTS
-- =====================================
RegisterNetEvent('cops_and_robbers:activateEMP')
AddEventHandler('cops_and_robbers:activateEMP', function()
    local robberId = source
    if not playerRoles[robberId] or playerRoles[robberId] ~= 'robber' then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Only Robbers can use EMP devices.")
        return
    end

    -- TODO: Check if player has 'empdevice' in server inventory and consume it.
    -- removePlayerInventoryItem(robberId, "empdevice", 1)
    -- savePlayerData(robberId)
    -- For now, assume they used one if they triggered the event.

    local robberPed = GetPlayerPed(robberId)
    if not DoesEntityExist(robberPed) then return end
    local robberLocation = GetEntityCoords(robberPed)

    LogAdminAction(string.format("EMP Activated: Robber %s (ID: %d) at %s.", GetPlayerName(robberId), robberId, json.encode(robberLocation)))
    TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~b~EMP activated!")

    -- Find nearby Cop vehicles
    for _, copId in ipairs(GetPlayers()) do
        if playerRoles[copId] and playerRoles[copId] == 'cop' then
            local copPed = GetPlayerPed(copId)
            if DoesEntityExist(copPed) then
                local vehicle = GetVehiclePedIsIn(copPed, false)
                if vehicle ~= 0 then -- Is in a vehicle
                    local vehicleLocation = GetEntityCoords(vehicle)
                    if #(robberLocation - vehicleLocation) <= Config.EMPRadius then
                        LogAdminAction(string.format("EMP Effect: Cop %s (ID: %d) vehicle (NetID: %d) EMPed by Robber %s.", GetPlayerName(copId), copId, VehToNet(vehicle), GetPlayerName(robberId)))
                        TriggerClientEvent('cops_and_robbers:vehicleEMPed', copId, VehToNet(vehicle), Config.EMPDisableDuration)
                    end
                end
            end
        end
    end
end)


-- =====================================
--        POWER GRID SABOTAGE EVENTS
-- =====================================
local powerGridStatus = {} -- { [gridIndex] = { onCooldownUntil = timestamp, isDown = boolean } }

RegisterNetEvent('cops_and_robbers:sabotagePowerGrid')
AddEventHandler('cops_and_robbers:sabotagePowerGrid', function(gridIndex)
    local robberId = source
    local grid = Config.PowerGrids[gridIndex]

    if not playerRoles[robberId] or playerRoles[robberId] ~= 'robber' then
        LogAdminAction(string.format("Power Sabotage Fail: Non-robber Player %s (ID: %d) at grid %s.", GetPlayerName(robberId), robberId, gridIndex))
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Only Robbers can sabotage power grids.")
        return
    end

    if not grid then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Invalid power grid.")
        return
    end

    powerGridStatus[gridIndex] = powerGridStatus[gridIndex] or { onCooldownUntil = 0, isDown = false }

    if os.time() < powerGridStatus[gridIndex].onCooldownUntil then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~" .. grid.name .. " is still recovering from last sabotage.")
        return
    end

    if powerGridStatus[gridIndex].isDown then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~" .. grid.name .. " power is already out.")
        return
    end

    powerGridStatus[gridIndex].isDown = true
    powerGridStatus[gridIndex].onCooldownUntil = os.time() + Config.PowerGridSabotageCooldown

    TriggerClientEvent('cops_and_robbers:powerGridStateChanged', -1, gridIndex, true, Config.PowerOutageDuration)
    TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~y~Successfully sabotaged " .. grid.name .. "! Lights out for " .. (Config.PowerOutageDuration/1000) .. "s.")
    -- Notify cops as well
    for pId, pData in pairs(playerData) do
        if playerRoles[pId] == 'cop' then
            TriggerClientEvent('cops_and_robbers:showNotification', pId, "~r~Warning: " .. grid.name .. " has been sabotaged! Power outage in effect.")
        end
    end


    SetTimeout(Config.PowerOutageDuration, function()
        if powerGridStatus[gridIndex] and powerGridStatus[gridIndex].isDown then
            powerGridStatus[gridIndex].isDown = false
            TriggerClientEvent('cops_and_robbers:powerGridStateChanged', -1, gridIndex, false, 0)
            print("Power restored for grid: " .. grid.name)
            -- Notify all players that power is back for that grid
            TriggerClientEvent('cops_and_robbers:showNotification', -1, "~g~Power has been restored at " .. grid.name .. ".")
        end
    end)
end)


-- =====================================
--        K9 UNIT (SIMPLIFIED) EVENTS
-- =====================================
local activeK9s = {} -- { [copId] = k9NetId }

RegisterNetEvent('cops_and_robbers:spawnK9')
AddEventHandler('cops_and_robbers:spawnK9', function()
    local copId = source
    if not playerRoles[copId] or playerRoles[copId] ~= 'cop' then
        TriggerClientEvent('cops_and_robbers:showNotification', copId, "~r~Only Cops can use K9 units.")
        return
    end

    if activeK9s[copId] then
        TriggerClientEvent('cops_and_robbers:showNotification', copId, "~y~You already have a K9 unit active.")
        -- Optionally, resend existing K9 net ID: TriggerClientEvent('cops_and_robbers:k9Spawned', copId, activeK9s[copId])
        return
    end

    -- TODO: Check if player has 'k9whistle' item in server inventory

    -- For simplicity, K9 is spawned by the server and its network ID sent to client.
    -- A more robust approach might have client spawn it and register netID with server.
    -- This part is highly dependent on how peds are managed and synced.
    -- The following is a conceptual placeholder for ped creation.
    -- Proper ped creation requires more setup (model loading, setting attributes, tasks).
    -- This assumes a server-side entity that clients will see.
    -- For a truly server-controlled ped, AI needs to be server-driven or replicated carefully.
    -- The current client-side logic implies the K9's owner client will largely control its detailed behavior.

    -- Placeholder: In a real scenario, you'd create a ped here.
    -- For this conceptual implementation, we authorize client to spawn its own K9.
    activeK9s[copId] = true -- Mark that this cop has an active K9

    LogAdminAction(string.format("K9 Authorized: Cop %s (ID: %d) authorized to spawn K9.", GetPlayerName(copId), copId))
    TriggerClientEvent('cops_and_robbers:clientSpawnK9Authorized', copId)
end)

RegisterNetEvent('cops_and_robbers:dismissK9')
AddEventHandler('cops_and_robbers:dismissK9', function()
    local copId = source
    if activeK9s[copId] then
        activeK9s[copId] = nil -- Mark K9 as no longer active for this cop
        LogAdminAction(string.format("K9 Dismissed: Cop %s (ID: %d) dismissed K9.", GetPlayerName(copId), copId))
        TriggerClientEvent('cops_and_robbers:clientDismissK9', copId) -- Tell client to remove its K9
    end
end)

RegisterNetEvent('cops_and_robbers:commandK9')
AddEventHandler('cops_and_robbers:commandK9', function(targetRobberServerId, commandType) -- k9NetId removed
    local copId = source
    if not activeK9s[copId] then -- Check if cop is authorized to have/command a K9
        TriggerClientEvent('cops_and_robbers:showNotification', copId, "~r~You do not have an active K9 unit.")
        return
    end

    if not IsValidPlayer(targetRobberServerId) or not playerRoles[targetRobberServerId] or playerRoles[targetRobberServerId] ~= 'robber' then
        TriggerClientEvent('cops_and_robbers:showNotification', copId, "~r~Invalid target for K9 command.")
        return
    end

    -- Relay command to the cop's client who owns/manages the K9's detailed AI
    LogAdminAction(string.format("K9 Command Relayed: Cop %s (ID: %d) commanded K9 to %s Player %s (ID: %d).", GetPlayerName(copId), copId, commandType, GetPlayerName(targetRobberServerId), targetRobberServerId))
    TriggerClientEvent('cops_and_robbers:k9ProcessCommand', copId, targetRobberServerId, commandType) -- k9NetId removed
    TriggerClientEvent('cops_and_robbers:showNotification', copId, "~b~K9 command issued.")
end)


-- =====================================
--           ARREST HANDLING
-- =====================================

-- Register event to handle arrests and update stats
RegisterNetEvent('cops_and_robbers:arrestRobber')
AddEventHandler('cops_and_robbers:arrestRobber', function(robberId)
    local copId = source
    if not cops[copId] then
        return -- Only cops can arrest robbers
    end
    if not robbers[robberId] then
        return -- Target must be a robber
    end

    initializePlayerStats(copId)
    initializePlayerStats(robberId)

    playerStats[copId].arrests = playerStats[copId].arrests + 1
    playerStats[copId].experience = playerStats[copId].experience + 500
    TriggerClientEvent('cops_and_robbers:arrestNotification', robberId, copId)
    TriggerClientEvent('cops_and_robbers:sendToJail', robberId, 300) -- Send robber to jail for 5 minutes

    -- If a robber is arrested, their wanted points could be reset or reduced.
    -- For now, we'll reset them to 0.
    if playerData[robberId] then
        playerData[robberId].wantedPoints = 0
        playerData[robberId].lastCrimeTimestamp = 0 -- Reset timestamps
        playerData[robberId].lastSeenByCopTimestamp = 0
        UpdatePlayerWantedLevel(robberId)
        savePlayerData(robberId)
        LogAdminAction(string.format("Wanted Points Reset: Robber %s (ID: %d) arrested, points reset.", GetPlayerName(robberId), robberId))
    end
end)

-- Placeholder for Bank Heist Success event to increase wanted points
-- AddEventHandler('cops_and_robbers:bankHeistSuccess', function(robberId)
--    IncreaseWantedPoints(robberId, 'bank_heist_major')
-- end)

-- Placeholder for Assault/Murder Cop events
-- AddEventHandler('cops_and_robbers:copAssaulted', function(attackerPlayerId, victimCopId)
--    IncreaseWantedPoints(attackerPlayerId, 'assault_cop')
-- end)
-- AddEventHandler('cops_and_robbers:copKilled', function(killerPlayerId, victimCopId)
--    IncreaseWantedPoints(killerPlayerId, 'murder_cop')
-- end)
-- AddEventHandler('cops_and_robbers:civilianKilledByPlayer', function(killerPlayerId, victimPedNetId)
--    IncreaseWantedPoints(killerPlayerId, 'murder_civilian');
-- end)


-- =====================================
--           SERVER-SIDE EVENT HANDLERS (ADMIN)
-- =====================================

-- Handler for banning a player (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:banPlayer')
AddEventHandler('cops_and_robbers:banPlayer', function(targetId, reason)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        LogAdminAction(string.format("Admin Command Fail: Unauthorized ban attempt by Player %s (ID: %d) on target %d.", GetPlayerName(adminSrc), adminSrc, targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    local identifiers = GetPlayerIdentifiers(targetId)
    if not identifiers or #identifiers == 0 then
        TriggerClientEvent('chat:addMessage', adminSrc, {
            args = { "^1Server", "Unable to retrieve identifiers for player." }
        })
        return
    end

    for _, identifier in ipairs(identifiers) do
        bannedPlayers[identifier] = { reason = reason, timestamp = os.time() }
    end

    saveBans()
    LogAdminAction(string.format("Admin Command: %s (ID: %d) banned Player %s (ID: %d). Reason: %s. Identifiers: %s", GetPlayerName(adminSrc), adminSrc, GetPlayerName(targetId), targetId, reason, table.concat(identifiers, ", ")))
    DropPlayer(targetId, "You have been banned from this server. Reason: " .. reason)
    TriggerClientEvent('chat:addMessage', -1, { args = { "^1Server", "Player " .. GetPlayerName(targetId) .. " has been banned. Reason: " .. reason } })
end)

-- Handler for setting a player's cash (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:setCash')
AddEventHandler('cops_and_robbers:setCash', function(targetId, amount)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        LogAdminAction(string.format("Admin Command Fail: Unauthorized setCash attempt by Player %s (ID: %d) on target %d.", GetPlayerName(adminSrc), adminSrc, targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    local data = getPlayerData(targetId)
    if data then
        local oldAmount = data.money or 0
        data.money = amount
        savePlayerData(targetId)
        LogAdminAction(string.format("Admin Command: %s (ID: %d) set cash for Player %s (ID: %d) from $%d to $%d.", GetPlayerName(adminSrc), adminSrc, GetPlayerName(targetId), targetId, oldAmount, amount))
        TriggerClientEvent('cops_and_robbers:showNotification', targetId, "Your cash has been set to $" .. amount)
    else
        LogAdminAction(string.format("Admin Command Fail: %s (ID: %d) failed setCash for Player %s (ID: %d) - player data not found.", GetPlayerName(adminSrc), adminSrc, GetPlayerName(targetId), targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Failed to set cash. Player data not found.")
    end
end)

-- Handler for adding cash to a player (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:addCash')
AddEventHandler('cops_and_robbers:addCash', function(targetId, amount)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    local oldAmount = getPlayerMoney(targetId) -- get money before adding
    addPlayerMoney(targetId, amount)
    savePlayerData(targetId)
    LogAdminAction(string.format("Admin Command: %s (ID: %d) added $%d cash to Player %s (ID: %d). Old: $%d, New: $%d.", GetPlayerName(adminSrc), adminSrc, amount, GetPlayerName(targetId), targetId, oldAmount, getPlayerMoney(targetId)))
    TriggerClientEvent('cops_and_robbers:showNotification', targetId, "You have received $" .. amount .. " from an admin.")
end)

-- Handler for removing cash from a player (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:removeCash')
AddEventHandler('cops_and_robbers:removeCash', function(targetId, amount)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        LogAdminAction(string.format("Admin Command Fail: Unauthorized removeCash attempt by Player %s (ID: %d) on target %d.", GetPlayerName(adminSrc), adminSrc, targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    local oldAmount = getPlayerMoney(targetId)
    removePlayerMoney(targetId, amount)
    savePlayerData(targetId)
    LogAdminAction(string.format("Admin Command: %s (ID: %d) removed $%d cash from Player %s (ID: %d). Old: $%d, New: $%d.", GetPlayerName(adminSrc), adminSrc, amount, GetPlayerName(targetId), targetId, oldAmount, getPlayerMoney(targetId)))
    TriggerClientEvent('cops_and_robbers:showNotification', targetId, "An admin has removed $" .. amount .. " from your account.")
end)

-- Handler for giving a weapon to a player (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:giveWeapon')
AddEventHandler('cops_and_robbers:giveWeapon', function(targetId, weaponName)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        LogAdminAction(string.format("Admin Command Fail: Unauthorized giveWeapon attempt by Player %s (ID: %d) on target %d.", GetPlayerName(adminSrc), adminSrc, targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    local weapon = getItemById(weaponName)
    if weapon and (weapon.category == "Weapons" or weapon.category == "Melee Weapons") then
        addPlayerWeapon(targetId, weaponName) -- This already triggers client event 'cops_and_robbers:addWeapon'
        savePlayerData(targetId)
        LogAdminAction(string.format("Admin Command: %s (ID: %d) gave weapon %s to Player %s (ID: %d).", GetPlayerName(adminSrc), adminSrc, weaponName, GetPlayerName(targetId), targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', targetId, "You have been given a " .. weapon.name .. " by an admin.")
    else
        LogAdminAction(string.format("Admin Command Fail: %s (ID: %d) failed giveWeapon %s to Player %s (ID: %d) - invalid weapon.", GetPlayerName(adminSrc), adminSrc, weaponName, GetPlayerName(targetId), targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Invalid weapon name.")
    end
end)

-- Handler for removing a weapon from a player (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:removeWeapon')
AddEventHandler('cops_and_robbers:removeWeapon', function(targetId, weaponName)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    if playerHasWeapon(targetId, weaponName) then
        removePlayerWeapon(targetId, weaponName) -- This already triggers client event 'cops_and_robbers:removeWeapon'
        savePlayerData(targetId)
        LogAdminAction(string.format("Admin Command: %s (ID: %d) removed weapon %s from Player %s (ID: %d).", GetPlayerName(adminSrc), adminSrc, weaponName, GetPlayerName(targetId), targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', targetId, "Your " .. weaponName .. " has been removed by an admin.")
    else
        LogAdminAction(string.format("Admin Command Fail: %s (ID: %d) failed removeWeapon %s from Player %s (ID: %d) - player does not have weapon.", GetPlayerName(adminSrc), adminSrc, weaponName, GetPlayerName(targetId), targetId))
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Player does not have this weapon.")
    end
end)

-- Handler for reassigning a player's role (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:reassignRoleServer')
AddEventHandler('cops_and_robbers:reassignRoleServer', function(targetId, newRole)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if newRole ~= "cop" and newRole ~= "robber" then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Invalid role specified.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    -- Update the player's role
    local oldRole = playerRoles[targetId] or "N/A"
    playerRoles[targetId] = newRole
    if newRole == 'cop' then
        cops[targetId] = true
        robbers[targetId] = nil
    elseif newRole == 'robber' then
        robbers[targetId] = true
        cops[targetId] = nil
    end

    savePlayerData(targetId)
    LogAdminAction(string.format("Admin Command: %s (ID: %d) reassigned Player %s (ID: %d) from role %s to %s.", GetPlayerName(adminSrc), adminSrc, GetPlayerName(targetId), targetId, oldRole, newRole))
    TriggerClientEvent('cops_and_robbers:setRole', targetId, newRole) -- Client updates its local role state
    TriggerClientEvent('cops_and_robbers:showNotification', targetId, "Your role has been changed to " .. newRole .. " by an admin.")
end)

-- =====================================
-- ADMIN PANEL NUI CALLBACKS & LOGGING EVENT
-- =====================================
RegisterNetEvent('cops_and_robbers:logAdminCommand') -- Event for admin.lua to call
AddEventHandler('cops_and_robbers:logAdminCommand', function(adminName, adminId, commandString)
    LogAdminAction(string.format("Admin Command Used: %s (ID: %d) executed: %s", adminName, adminId, commandString))
end)

RegisterNUICallback('adminCheckAndFetchPlayers', function(data, cb)
    local src = source
    if IsAdmin(src) then
        LogAdminAction(string.format("Admin Panel: %s (ID: %d) accessed player list.", GetPlayerName(src), src))
        local playerListForNUI = {}
        for _, pId in ipairs(GetPlayers()) do
            local pData = getPlayerData(pId)
            table.insert(playerListForNUI, {
                serverId = pId,
                name = GetPlayerName(pId),
                role = playerRoles[pId] or "N/A",
                cash = pData and pData.money or 0
            })
        end
        cb({isAdmin = true, players = playerListForNUI})
    else
        LogAdminAction(string.format("Admin Panel Fail: Unauthorized access attempt by Player %s (ID: %d).", GetPlayerName(src), src))
        cb({isAdmin = false})
    end
end)

RegisterNUICallback('adminKickPlayer', function(data, cb)
    local src = source
    if IsAdmin(src) then
        local targetId = tonumber(data.targetId)
        if targetId and IsValidPlayer(targetId) then
            LogAdminAction(string.format("Admin Panel: %s (ID: %d) KICKED Player %s (ID: %d).", GetPlayerName(src), src, GetPlayerName(targetId), targetId))
            DropPlayer(targetId, "Kicked by Admin via UI.")
            cb({status = 'ok', message = 'Player kicked.'})
        else
            LogAdminAction(string.format("Admin Panel Kick Fail: %s (ID: %d) on target %s - invalid target.", GetPlayerName(src), src, tostring(data.targetId)))
            cb({status = 'failed', message = 'Invalid target ID or player not online.'})
        end
    else
        cb({status = 'failed', message = 'Not an admin.'})
    end
end)

RegisterNUICallback('adminBanPlayer', function(data, cb)
    local src = source
    if IsAdmin(src) then
        local targetId = tonumber(data.targetId)
        local reason = data.reason or "Banned by Admin via UI."
        if targetId and IsValidPlayer(targetId) then
            local identifiers = GetPlayerIdentifiers(targetId)
            if identifiers and #identifiers > 0 then
                for _, identifier in ipairs(identifiers) do
                    bannedPlayers[identifier] = { reason = reason, timestamp = os.time(), admin = GetPlayerName(src) }
                end
                saveBans()
                LogAdminAction(string.format("Admin Panel: %s (ID: %d) BANNED Player %s (ID: %d). Reason: %s. Identifiers: %s", GetPlayerName(src), src, GetPlayerName(targetId), targetId, reason, table.concat(identifiers, ", ")))
                DropPlayer(targetId, "Banned by Admin: " .. reason)
                cb({status = 'ok', message = 'Player banned.'})
            else
                LogAdminAction(string.format("Admin Panel Ban Fail (No Identifiers): %s (ID: %d) on target %s (ID: %d).", GetPlayerName(src), src, GetPlayerName(targetId), targetId))
                cb({status = 'failed', message = 'Could not retrieve player identifiers.'})
            end
        else
            LogAdminAction(string.format("Admin Panel Ban Fail (Invalid Target): %s (ID: %d) on target %s.", GetPlayerName(src), src, tostring(data.targetId)))
            cb({status = 'failed', message = 'Invalid target ID or player not online.'})
        end
    else
        cb({status = 'failed', message = 'Not an admin.'})
    end
end)

RegisterNUICallback('adminTeleportToPlayer', function(data, cb)
    local src = source
    if IsAdmin(src) then
        local targetId = tonumber(data.targetId)
        if targetId and IsValidPlayer(targetId) then
            local targetPed = GetPlayerPed(targetId)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                LogAdminAction(string.format("Admin Panel: %s (ID: %d) teleported to Player %s (ID: %d) at %s.", GetPlayerName(src), src, GetPlayerName(targetId), targetId, json.encode(targetCoords)))
                TriggerClientEvent('cops_and_robbers:teleportToPlayerAdminUI', src, targetCoords)
                cb({status = 'ok', message = 'Teleport initiated.'})
            else
                LogAdminAction(string.format("Admin Panel Teleport Fail (No Ped): %s (ID: %d) to target %s (ID: %d).", GetPlayerName(src), src, GetPlayerName(targetId), targetId))
                cb({status = 'failed', message = 'Target ped does not exist.'})
            end
        else
            LogAdminAction(string.format("Admin Panel Teleport Fail (Invalid Target): %s (ID: %d) to target %s.", GetPlayerName(src), src, tostring(data.targetId)))
            cb({status = 'failed', message = 'Invalid target ID or player not online.'})
        end
    else
        cb({status = 'failed', message = 'Not an admin.'})
    end
end)

-- =====================================
-- ADMIN SCENARIO TRIGGER EVENTS
-- =====================================
RegisterNetEvent('cops_and_robbers:adminTriggerArmoredCar')
AddEventHandler('cops_and_robbers:adminTriggerArmoredCar', function()
    local src = source
    if IsAdmin(src) then
        LogAdminAction(string.format("Admin Scenario: %s (ID: %d) triggered Armored Car.", GetPlayerName(src), src))
        armoredCarActive = false -- Allow immediate respawn by bypassing active check
        armoredCarHeistCooldownTimer = 0 -- Bypass cooldown
        SpawnArmoredCar(true) -- Pass 'true' to indicate admin forced
    else
        LogAdminAction(string.format("Admin Scenario Fail: Unauthorized Armored Car trigger by %s (ID: %d).", GetPlayerName(src), src))
    end
end)

RegisterNetEvent('cops_and_robbers:adminTriggerBankHeist')
AddEventHandler('cops_and_robbers:adminTriggerBankHeist', function(bankId)
    local src = source
    if IsAdmin(src) then
        local bank = Config.BankVaults[bankId]
        if bank then
            LogAdminAction(string.format("Admin Scenario: %s (ID: %d) triggered Bank Heist at %s (%s).", GetPlayerName(src), src, bankId, bank.name))
            notifyNearbyCops(bank.id, bank.location, bank.name)
            -- Could also trigger timer for a random robber or just announce globally
            TriggerClientEvent('cops_and_robbers:showNotification', -1, string.format("~r~ADMIN EVENT: A heist at %s has been initiated!", bank.name))
        else
            LogAdminAction(string.format("Admin Scenario Fail: %s (ID: %d) triggered Bank Heist with invalid ID %s.", GetPlayerName(src), src, bankId))
        end
    else
        LogAdminAction(string.format("Admin Scenario Fail: Unauthorized Bank Heist trigger by %s (ID: %d).", GetPlayerName(src), src))
    end
end)

RegisterNetEvent('cops_and_robbers:adminTriggerStoreRobbery')
AddEventHandler('cops_and_robbers:adminTriggerStoreRobbery', function(storeIndex)
    local src = source
    if IsAdmin(src) then
        local store = Config.RobbableStores[storeIndex]
        if store then
            LogAdminAction(string.format("Admin Scenario: %s (ID: %d) triggered Store Robbery at %s (%s).", GetPlayerName(src), src, storeIndex, store.name))
            notifyNearbyCops("storeRobbery_"..storeIndex, store.location, store.name)
            robberyCooldownsStore[storeIndex] = 0 -- Reset cooldown for admin trigger
            TriggerClientEvent('cops_and_robbers:showNotification', -1, string.format("~r~ADMIN EVENT: A robbery at %s has been initiated!", store.name))
        else
            LogAdminAction(string.format("Admin Scenario Fail: %s (ID: %d) triggered Store Robbery with invalid index %s.", GetPlayerName(src), src, storeIndex))
        end
    else
        LogAdminAction(string.format("Admin Scenario Fail: Unauthorized Store Robbery trigger by %s (ID: %d).", GetPlayerName(src), src))
    end
end)

RegisterNetEvent('cops_and_robbers:adminTriggerPowerOutage')
AddEventHandler('cops_and_robbers:adminTriggerPowerOutage', function(gridIndex)
    local src = source
    if IsAdmin(src) then
        local grid = Config.PowerGrids[gridIndex]
        if grid then
            powerGridStatus[gridIndex] = powerGridStatus[gridIndex] or { onCooldownUntil = 0, isDown = false }
            powerGridStatus[gridIndex].isDown = true
            powerGridStatus[gridIndex].onCooldownUntil = os.time() + Config.PowerGridSabotageCooldown -- Still apply cooldown to prevent spam by players after admin trigger

            LogAdminAction(string.format("Admin Scenario: %s (ID: %d) triggered Power Outage at %s (%s).", GetPlayerName(src), src, gridIndex, grid.name))
            TriggerClientEvent('cops_and_robbers:powerGridStateChanged', -1, gridIndex, true, Config.PowerOutageDuration)
            TriggerClientEvent('cops_and_robbers:showNotification', -1, string.format("~r~ADMIN EVENT: A power outage at %s has been initiated!", grid.name))

            SetTimeout(Config.PowerOutageDuration, function()
                if powerGridStatus[gridIndex] and powerGridStatus[gridIndex].isDown then
                    powerGridStatus[gridIndex].isDown = false
                    TriggerClientEvent('cops_and_robbers:powerGridStateChanged', -1, gridIndex, false, 0)
                    LogAdminAction(string.format("Admin Scenario: Power automatically restored for grid %s (%s).", gridIndex, grid.name))
                    TriggerClientEvent('cops_and_robbers:showNotification', -1, "~g~Power has been restored at " .. grid.name .. ".")
                end
            end)
        else
             LogAdminAction(string.format("Admin Scenario Fail: %s (ID: %d) triggered Power Outage with invalid ID %s.", GetPlayerName(src), src, gridIndex))
        end
    else
        LogAdminAction(string.format("Admin Scenario Fail: Unauthorized Power Outage trigger by %s (ID: %d).", GetPlayerName(src), src))
    end
end)


-- =====================================
--           INITIALIZATION
-- =====================================

-- Initialize purchase history and bans on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        loadPurchaseHistory()
        LoadBans() -- Load bans from file and merge with Config.BannedPlayers
        -- Clear any persisted spike strips on resource restart (they are runtime entities)
        deployedSpikeStrips = {}
        playerSpikeStripCount = {}
        spikeStripCounter = 0
        activeSubdues = {} -- Clear active subdues on restart
        activeK9s = {} -- Clear active K9s on restart
        robberyCooldownsStore = {}
        activeStoreRobberies = {}
        -- Armored car related state reset
        if armoredCarEntity and DoesEntityExist(armoredCarEntity) then
            local driver = GetPedInVehicleSeat(armoredCarEntity, -1)
            if driver and DoesEntityExist(driver) then DeleteEntity(driver) end
            DeleteEntity(armoredCarEntity)
        end
        armoredCarEntity = nil
        armoredCarActive = false
        armoredCarHeistCooldownTimer = 0 -- Reset cooldown to allow immediate spawn if conditions met after restart
        powerGridStatus = {} -- Clear power grid statuses
        activeContrabandDrops = {} -- Clear active contraband drops
        nextContrabandDropTimestamp = GetGameTimer() + Config.ContrabandDropInterval -- Schedule first drop after restart
        LogAdminAction("Contraband drop system initialized. Next drop in ~" .. (Config.ContrabandDropInterval / 60000) .. " minutes.")
    end
end)
