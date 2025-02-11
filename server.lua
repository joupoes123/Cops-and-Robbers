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
        weapons = {}
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

-- Helper function to check if a player is an admin
local function IsAdmin(playerId)
    local playerIdentifiers = GetPlayerIdentifiers(playerId)
    if not playerIdentifiers then return false end

    for _, identifier in ipairs(playerIdentifiers) do
        if Config.Admins[identifier] then
            return true
        end
    end
    return false
end

-- Helper function to check if a player ID is valid (i.e. connected)
local function IsValidPlayer(targetId)
    for _, playerId in ipairs(GetPlayers()) do
        if playerId == tostring(targetId) then
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
            deferrals.done("You are banned from this server. Reason: " .. (bannedPlayers[identifier].reason or "No reason provided."))
            CancelEvent()
            return
        end
    end

    deferrals.update("Loading your player data...")

    -- Load player data
    loadPlayerData(src)

    deferrals.done()
end)

-- Event handler for player disconnecting
AddEventHandler('playerDropped', function(reason)
    local src = source
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
AddEventHandler('cops_and_robbers:setPlayerRole', function(role)
    local src = source
    playerRoles[src] = role
    if role == 'cop' then
        cops[src] = true
        robbers[src] = nil
    elseif role == 'robber' then
        robbers[src] = true
        cops[src] = nil
    else
        -- Invalid role
        playerRoles[src] = nil
    end
    TriggerClientEvent('cops_and_robbers:setRole', src, role)
end)

-- Receive player positions and wanted levels from clients (with throttling)
RegisterNetEvent('cops_and_robbers:updatePosition')
AddEventHandler('cops_and_robbers:updatePosition', function(position, wantedLvl)
    local src = source
    local now = GetGameTimer() -- Returns time in ms
    if playerUpdateTimestamps[src] and (now - playerUpdateTimestamps[src]) < 100 then
        return -- Throttle updates: ignore if less than 100ms since last update
    end
    playerUpdateTimestamps[src] = now
    playerPositions[src] = { position = position, wantedLevel = wantedLvl }
end)

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
        TriggerClientEvent('cops_and_robbers:startHeistTimer', src, bank.id, Config.HeistTimers.heistDuration)  -- Heist timer duration from config
    else
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
end)

-- =====================================
--           SERVER-SIDE EVENT HANDLERS (ADMIN)
-- =====================================

-- Handler for banning a player (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:banPlayer')
AddEventHandler('cops_and_robbers:banPlayer', function(targetId, reason)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
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
    DropPlayer(targetId, "You have been banned from this server. Reason: " .. reason)
end)

-- Handler for setting a player's cash (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:setCash')
AddEventHandler('cops_and_robbers:setCash', function(targetId, amount)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    local data = getPlayerData(targetId)
    if data then
        data.money = amount
        savePlayerData(targetId)
        TriggerClientEvent('cops_and_robbers:showNotification', targetId, "Your cash has been set to $" .. amount)
    else
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

    addPlayerMoney(targetId, amount)
    savePlayerData(targetId)
    TriggerClientEvent('cops_and_robbers:showNotification', targetId, "You have received $" .. amount .. " from an admin.")
end)

-- Handler for removing cash from a player (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:removeCash')
AddEventHandler('cops_and_robbers:removeCash', function(targetId, amount)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    removePlayerMoney(targetId, amount)
    savePlayerData(targetId)
    TriggerClientEvent('cops_and_robbers:showNotification', targetId, "An admin has removed $" .. amount .. " from your account.")
end)

-- Handler for giving a weapon to a player (triggered by admin.lua)
RegisterNetEvent('cops_and_robbers:giveWeapon')
AddEventHandler('cops_and_robbers:giveWeapon', function(targetId, weaponName)
    local adminSrc = source
    if not IsAdmin(adminSrc) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "You are not authorized to perform this action.")
        return
    end

    if not IsValidPlayer(targetId) then
        TriggerClientEvent('cops_and_robbers:showNotification', adminSrc, "Target player is not online.")
        return
    end

    local weapon = getItemById(weaponName)
    if weapon and (weapon.category == "Weapons" or weapon.category == "Melee Weapons") then
        addPlayerWeapon(targetId, weaponName)
        savePlayerData(targetId)
        TriggerClientEvent('cops_and_robbers:showNotification', targetId, "You have been given a " .. weapon.name .. " by an admin.")
    else
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
        removePlayerWeapon(targetId, weaponName)
        savePlayerData(targetId)
        TriggerClientEvent('cops_and_robbers:showNotification', targetId, "Your " .. weaponName .. " has been removed by an admin.")
    else
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
    playerRoles[targetId] = newRole
    if newRole == 'cop' then
        cops[targetId] = true
        robbers[targetId] = nil
    elseif newRole == 'robber' then
        robbers[targetId] = true
        cops[targetId] = nil
    end

    savePlayerData(targetId)
    TriggerClientEvent('cops_and_robbers:setRole', targetId, newRole)
    TriggerClientEvent('cops_and_robbers:showNotification', targetId, "Your role has been changed to " .. newRole .. " by an admin.")
end)

-- =====================================
--           INITIALIZATION
-- =====================================

-- Initialize purchase history and bans on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        loadPurchaseHistory()
        LoadBans() -- Load bans from file and merge with Config.BannedPlayers
    end
end)
