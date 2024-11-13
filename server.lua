-- server.lua

-- Import Configurations
-- Config is already available globally from 'config.lua' via 'shared_scripts' in 'fxmanifest.lua'

-- Variables and Data Structures
local playerData = {}
local cops = {}
local robbers = {}
local heistCooldowns = {} -- Track robbers' cooldown status
local playerStats = {}
local playerRoles = {}
local playerPositions = {}
local bannedPlayers = {}
local purchaseHistory = {}

-- Ensure 'player_data' directory exists
local function ensurePlayerDataDirectory()
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local dir = resourcePath .. "/player_data"
    if not IsDirectory(dir) then
        CreateDirectory(dir)
    end
end

function IsDirectory(path)
    local response = os.rename(path, path)
    if response then
        return true
    else
        return false
    end
end

function CreateDirectory(path)
    if os.getenv("HOME") then
        -- Linux or macOS
        os.execute("mkdir -p \"" .. path .. "\"")
    else
        -- Windows
        os.execute("mkdir \"" .. path .. "\"")
    end
end

ensurePlayerDataDirectory()

-- Function to load player data from file
function loadPlayerData(source)
    local identifiers = GetPlayerIdentifiers(source)
    local identifier = identifiers[1]  -- Use the first identifier (e.g., Steam ID)
    local data = {
        money = 2500,  -- Default starting money
        inventory = {},
        weapons = {}
    }

    local filePath = "player_data/" .. identifier .. ".json"
    local fileData = LoadResourceFile(GetCurrentResourceName(), filePath)
    if fileData then
        local loadedData = json.decode(fileData)
        if loadedData then
            data = loadedData
        end
    end

    playerData[source] = data
end

-- Function to save player data to file
function savePlayerData(source)
    local data = playerData[source]
    if data then
        local identifiers = GetPlayerIdentifiers(source)
        local identifier = identifiers[1]
        local filePath = "player_data/" .. identifier .. ".json"
        SaveResourceFile(GetCurrentResourceName(), filePath, json.encode(data), -1)
    end
end

-- Event handler for player connecting (load player data and check for bans)
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)

    deferrals.defer()
    Wait(0)
    deferrals.update("Checking your ban status...")

    -- Check for bans
    for _, identifier in ipairs(identifiers) do
        if bannedPlayers[identifier] then
            deferrals.done("You are banned from this server.")
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

-- Get player data
function getPlayerData(source)
    return playerData[source]
end

-- Add money to player
function addPlayerMoney(source, amount)
    local data = getPlayerData(source)
    if data then
        data.money = data.money + amount
    end
end

-- Remove money from player
function removePlayerMoney(source, amount)
    local data = getPlayerData(source)
    if data then
        data.money = data.money - amount
    end
end

-- Get player money
function getPlayerMoney(source)
    local data = getPlayerData(source)
    if data then
        return data.money
    else
        return 0
    end
end

-- Add item to player inventory
function addPlayerInventoryItem(source, itemId, quantity)
    local data = getPlayerData(source)
    if data then
        data.inventory[itemId] = (data.inventory[itemId] or 0) + quantity
    end
end

-- Remove item from player inventory
function removePlayerInventoryItem(source, itemId, quantity)
    local data = getPlayerData(source)
    if data and data.inventory[itemId] then
        data.inventory[itemId] = data.inventory[itemId] - quantity
        if data.inventory[itemId] <= 0 then
            data.inventory[itemId] = nil
        end
    end
end

-- Get player inventory item count
function getPlayerInventoryItemCount(source, itemId)
    local data = getPlayerData(source)
    if data and data.inventory[itemId] then
        return data.inventory[itemId]
    else
        return 0
    end
end

-- Add weapon to player
function addPlayerWeapon(source, weaponName)
    local data = getPlayerData(source)
    if data then
        data.weapons[weaponName] = true
        TriggerClientEvent('cops_and_robbers:addWeapon', source, weaponName)
    end
end

-- Remove weapon from player
function removePlayerWeapon(source, weaponName)
    local data = getPlayerData(source)
    if data and data.weapons[weaponName] then
        data.weapons[weaponName] = nil
        TriggerClientEvent('cops_and_robbers:removeWeapon', source, weaponName)
    end
end

-- Check if player has weapon
function playerHasWeapon(source, weaponName)
    local data = getPlayerData(source)
    if data and data.weapons[weaponName] then
        return true
    else
        return false
    end
end

-- Function to get item details by itemId
function getItemById(itemId)
    for _, item in ipairs(Config.Items) do
        if item.itemId == itemId then
            return item
        end
    end
    return nil
end

-- Function to give item(s) to player
function givePlayerItem(source, item, quantity)
    quantity = quantity or 1
    if item.category == "Weapons" or item.category == "Melee Weapons" then
        -- For weapons, give only one
        if not playerHasWeapon(source, item.itemId) then
            addPlayerWeapon(source, item.itemId)
            savePlayerData(source)
        else
            TriggerClientEvent('cops_and_robbers:showNotification', source, "You already own this weapon.")
        end
    elseif item.category == "Ammunition" then
        local ammoCount = getAmmoCountForItem(item.itemId) * quantity
        local weaponName = item.itemId:gsub("ammo_", "weapon_")
        if playerHasWeapon(source, weaponName) then
            TriggerClientEvent('cops_and_robbers:addAmmo', source, weaponName, ammoCount)
        else
            TriggerClientEvent('cops_and_robbers:showNotification', source, "You don't have the weapon for this ammo.")
        end
    elseif item.category == "Armor" then
        -- Armor is applied immediately
        TriggerClientEvent('cops_and_robbers:applyArmor', source, item.itemId)
    else
        addPlayerInventoryItem(source, item.itemId, quantity)
        savePlayerData(source)
    end
end

-- Function to get ammo count based on ammo type
function getAmmoCountForItem(ammoId)
    local ammoCounts = {
        ammo_pistol = 24,
        ammo_smg = 60,
        ammo_rifle = 60,
        ammo_shotgun = 16,
        ammo_sniper = 10,
    }
    return ammoCounts[ammoId] or 0
end

-- Purchase history management

-- Function to load purchase history from file
function loadPurchaseHistory()
    local fileData = LoadResourceFile(GetCurrentResourceName(), "purchase_history.json")
    if fileData and fileData ~= "" then
        purchaseHistory = json.decode(fileData)
    else
        purchaseHistory = {}
        initializePurchaseData()
    end
end

-- Function to save purchase history to file
function savePurchaseHistory()
    SaveResourceFile(GetCurrentResourceName(), "purchase_history.json", json.encode(purchaseHistory), -1)
end

-- Initialize purchase data
function initializePurchaseData()
    for _, item in ipairs(Config.Items) do
        purchaseHistory[item.itemId] = {}
    end
end

-- Load purchase history on server start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        loadPurchaseHistory()
        LoadBans() -- Load bans from file
    end
end)

-- Function to calculate dynamic price
function getDynamicPrice(itemId)
    local basePrice
    for _, item in ipairs(Config.Items) do
        if item.itemId == itemId then
            basePrice = item.basePrice
            break
        end
    end

    if not basePrice then
        return nil  -- Item not found
    end

    -- Ensure that purchaseHistory[itemId] exists
    if not purchaseHistory[itemId] then
        purchaseHistory[itemId] = {}
    end

    local purchaseCount = #purchaseHistory[itemId]

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

-- Event handler for item purchase with quantity
RegisterNetEvent('cops_and_robbers:purchaseItem')
AddEventHandler('cops_and_robbers:purchaseItem', function(itemId, quantity)
    local source = source
    local timestamp = os.time()
    quantity = tonumber(quantity) or 1

    -- Validate item
    local item = getItemById(itemId)
    if not item then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', source, 'Invalid item.')
        return
    end

    -- Validate quantity
    if quantity < 1 or quantity > 100 then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', source, 'Invalid quantity.')
        return
    end

    -- Handle player cash balance
    local playerMoney = getPlayerMoney(source)
    local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
    local totalPrice = dynamicPrice * quantity
    if playerMoney < totalPrice then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', source, 'Insufficient funds.')
        return
    end

    -- Deduct money and give item(s)
    removePlayerMoney(source, totalPrice)
    givePlayerItem(source, item, quantity)

    -- Save player data
    savePlayerData(source)

    -- Record the purchase
    if not purchaseHistory[itemId] then
        purchaseHistory[itemId] = {}
    end

    for i = 1, quantity do
        table.insert(purchaseHistory[itemId], timestamp)
    end

    -- Remove outdated purchases
    local timeframeStart = timestamp - Config.PopularityTimeframe
    local updatedHistory = {}
    for _, purchaseTime in ipairs(purchaseHistory[itemId]) do
        if purchaseTime >= timeframeStart then
            table.insert(updatedHistory, purchaseTime)
        end
    end
    purchaseHistory[itemId] = updatedHistory

    -- Save purchase history
    savePurchaseHistory()

    -- Acknowledge the purchase
    TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, itemId, quantity)
end)

-- Event handler for selling items
RegisterNetEvent('cops_and_robbers:sellItem')
AddEventHandler('cops_and_robbers:sellItem', function(itemId, quantity)
    local source = source
    quantity = tonumber(quantity) or 1

    -- Validate item
    local item = getItemById(itemId)
    if not item then
        TriggerClientEvent('cops_and_robbers:sellFailed', source, 'Invalid item.')
        return
    end

    -- Validate quantity
    if quantity < 1 or quantity > 100 then
        TriggerClientEvent('cops_and_robbers:sellFailed', source, 'Invalid quantity.')
        return
    end

    -- Handle player inventory
    local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
    local sellPrice = math.floor(dynamicPrice * Config.SellPriceFactor)
    local totalSellPrice = sellPrice * quantity

    if item.category == "Weapons" or item.category == "Melee Weapons" then
        if playerHasWeapon(source, item.itemId) then
            removePlayerWeapon(source, item.itemId)
            addPlayerMoney(source, totalSellPrice)
            savePlayerData(source)
            TriggerClientEvent('cops_and_robbers:sellConfirmed', source, itemId, 1)
        else
            TriggerClientEvent('cops_and_robbers:sellFailed', source, 'You do not own this weapon.')
        end
    else
        local itemCount = getPlayerInventoryItemCount(source, item.itemId)
        if itemCount >= quantity then
            removePlayerInventoryItem(source, item.itemId, quantity)
            addPlayerMoney(source, totalSellPrice)
            savePlayerData(source)
            TriggerClientEvent('cops_and_robbers:sellConfirmed', source, itemId, quantity)
        else
            TriggerClientEvent('cops_and_robbers:sellFailed', source, 'Insufficient items.')
        end
    end
end)

-- Event handler for client requesting item list
RegisterNetEvent('cops_and_robbers:getItemList')
AddEventHandler('cops_and_robbers:getItemList', function(storeType, vendorItems)
    local source = source
    local itemList = {}

    for _, item in ipairs(Config.Items) do
        if (storeType == "AmmuNation") or (storeType == "Vendor" and hasValue(vendorItems, item.itemId)) then
            local dynamicPrice = getDynamicPrice(item.itemId) or item.basePrice
            table.insert(itemList, {
                name = item.name,
                itemId = item.itemId,
                price = dynamicPrice,
                category = item.category,
            })
        end
    end

    TriggerClientEvent('cops_and_robbers:sendItemList', source, itemList)
end)

-- Helper function to check if a value exists in a table
function hasValue(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- Event handler to send player data to client
RegisterNetEvent('cops_and_robbers:requestPlayerData')
AddEventHandler('cops_and_robbers:requestPlayerData', function()
    local source = source
    local data = getPlayerData(source)
    if data then
        TriggerClientEvent('cops_and_robbers:receivePlayerData', source, data)
    end
end)

-- Event handler for player inventory request
RegisterNetEvent('cops_and_robbers:getPlayerInventory')
AddEventHandler('cops_and_robbers:getPlayerInventory', function()
    local source = source
    local data = getPlayerData(source)
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

        TriggerClientEvent('cops_and_robbers:sendPlayerInventory', source, items)
    end
end)

-- Load bans from file
function LoadBans()
    local bans = LoadResourceFile(GetCurrentResourceName(), "bans.json")
    if bans and bans ~= "" then
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

-- Function to notify cops of a wanted robber
function notifyCopsOfWantedRobber(robberId, robberPosition)
    for copId, _ in pairs(cops) do
        TriggerClientEvent('cops_and_robbers:notifyWantedRobber', copId, robberId, robberPosition)
    end
end

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
