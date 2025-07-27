
-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before secure_systems.lua")
end

if not Validation then
    error("Validation must be loaded before secure_systems.lua")
end

if not DataManager then
    error("DataManager must be loaded before secure_systems.lua")
end

SecureInventory = SecureInventory or {}
SecureTransactions = SecureTransactions or {}

local function GenerateTransactionId()
    return string.format("txn_%d_%d", GetGameTimer(), math.random(10000, 99999))
end


local inventoryActiveTransactions = {}
local inventoryTransactionHistory = {}
local inventoryLocks = {}
local inventoryStats = {
    totalOperations = 0,
    failedOperations = 0,
    duplicateAttempts = 0,
    averageOperationTime = 0
}

local function LogInventory(playerId, operation, message, level)
    level = level or Constants.LOG_LEVELS.INFO
    local playerName = "System"
    if playerId and playerId > 0 then
        playerName = SafeGetPlayerName(playerId) or "Unknown"
    end
    if level == Constants.LOG_LEVELS.ERROR or level == Constants.LOG_LEVELS.WARN then
        Log(string.format("[CNR_SECURE_INVENTORY] [%s] Player %s (%s) - %s: %s", 
            string.upper(level), playerName, tostring(playerId or "system"), operation, message))
    end
end


function SecureInventory.AddItem(playerId, itemId, quantity, source)
    local startTime = GetGameTimer()
    inventoryStats.totalOperations = inventoryStats.totalOperations + 1
    
    local valid, validatedQuantity, error = Validation.ValidateQuantity(quantity)
    if not valid then
        LogInventory(playerId, "AddItem", string.format("Invalid quantity: %s", error), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, error
    end
    
    local valid, itemConfig, error = Validation.ValidateItem(itemId)
    if not valid then
        LogInventory(playerId, "AddItem", string.format("Invalid item: %s", error), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, error
    end
    
    if not playersData[playerId] then
        LogInventory(playerId, "AddItem", "Player data not found", Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, "Player data not found"
    end
    
    if not playersData[playerId].inventory then
        playersData[playerId].inventory = {}
    end
    
    local currentQuantity = playersData[playerId].inventory[itemId] or 0
    playersData[playerId].inventory[itemId] = currentQuantity + validatedQuantity
    
    local operationTime = GetGameTimer() - startTime
    inventoryStats.averageOperationTime = (inventoryStats.averageOperationTime + operationTime) / 2
    
    LogInventory(playerId, "AddItem", string.format("Added %d x %s (source: %s)", validatedQuantity, itemId, source or "unknown"))
    return true, nil
end

function SecureInventory.RemoveItem(playerId, itemId, quantity, reason)
    local startTime = GetGameTimer()
    inventoryStats.totalOperations = inventoryStats.totalOperations + 1
    
    local valid, validatedQuantity, error = Validation.ValidateQuantity(quantity)
    if not valid then
        LogInventory(playerId, "RemoveItem", string.format("Invalid quantity: %s", error), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, error
    end
    
    local valid, itemConfig, error = Validation.ValidateItem(itemId)
    if not valid then
        LogInventory(playerId, "RemoveItem", string.format("Invalid item: %s", error), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, error
    end
    
    if not playersData[playerId] or not playersData[playerId].inventory then
        LogInventory(playerId, "RemoveItem", "Player inventory not found", Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, "Player inventory not found"
    end
    
    local currentQuantity = playersData[playerId].inventory[itemId] or 0
    if currentQuantity < validatedQuantity then
        LogInventory(playerId, "RemoveItem", string.format("Insufficient quantity: has %d, needs %d", currentQuantity, validatedQuantity), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, "Insufficient quantity"
    end
    
    playersData[playerId].inventory[itemId] = currentQuantity - validatedQuantity
    if playersData[playerId].inventory[itemId] <= 0 then
        playersData[playerId].inventory[itemId] = nil
    end
    
    local operationTime = GetGameTimer() - startTime
    inventoryStats.averageOperationTime = (inventoryStats.averageOperationTime + operationTime) / 2
    
    LogInventory(playerId, "RemoveItem", string.format("Removed %d x %s (reason: %s)", validatedQuantity, itemId, reason or "unknown"))
    return true, nil
end

function SecureInventory.TransferItem(fromPlayerId, toPlayerId, itemId, quantity, reason)
    local startTime = GetGameTimer()
    inventoryStats.totalOperations = inventoryStats.totalOperations + 1
    
    local valid, validatedQuantity, error = Validation.ValidateQuantity(quantity)
    if not valid then
        LogInventory(fromPlayerId, "TransferItem", string.format("Invalid quantity: %s", error), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, error
    end
    
    local valid, itemConfig, error = Validation.ValidateItem(itemId)
    if not valid then
        LogInventory(fromPlayerId, "TransferItem", string.format("Invalid item: %s", error), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, error
    end
    
    local success, error = SecureInventory.RemoveItem(fromPlayerId, itemId, validatedQuantity, reason)
    if not success then
        LogInventory(fromPlayerId, "TransferItem", string.format("Failed to remove from source: %s", error), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, error
    end
    
    local success, error = SecureInventory.AddItem(toPlayerId, itemId, validatedQuantity, string.format("transfer_from_%d", fromPlayerId))
    if not success then
        SecureInventory.AddItem(fromPlayerId, itemId, validatedQuantity, "transfer_rollback")
        LogInventory(fromPlayerId, "TransferItem", string.format("Failed to add to target, rolled back: %s", error), Constants.LOG_LEVELS.ERROR)
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
        return false, error
    end
    
    local operationTime = GetGameTimer() - startTime
    inventoryStats.averageOperationTime = (inventoryStats.averageOperationTime + operationTime) / 2
    
    LogInventory(fromPlayerId, "TransferItem", string.format("Transferred %d x %s to player %d (reason: %s)", validatedQuantity, itemId, toPlayerId, reason or "unknown"))
    return true, nil
end

function SecureInventory.GetInventory(playerId)
    if not playersData[playerId] then
        LogInventory(playerId, "GetInventory", "Player data not found", Constants.LOG_LEVELS.ERROR)
        return nil
    end
    
    if not playersData[playerId].inventory then
        playersData[playerId].inventory = {}
    end
    
    local inventory = {}
    for itemId, quantity in pairs(playersData[playerId].inventory) do
        if quantity > 0 then
            inventory[itemId] = quantity
        end
    end
    
    return inventory
end

function SecureInventory.HasItem(playerId, itemId, quantity)
    local valid, validatedQuantity, error = Validation.ValidateQuantity(quantity or 1)
    if not valid then
        LogInventory(playerId, "HasItem", string.format("Invalid quantity: %s", error), Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    local valid, itemConfig, error = Validation.ValidateItem(itemId)
    if not valid then
        LogInventory(playerId, "HasItem", string.format("Invalid item: %s", error), Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    if not playersData[playerId] or not playersData[playerId].inventory then
        return false
    end
    
    local currentQuantity = playersData[playerId].inventory[itemId] or 0
    return currentQuantity >= validatedQuantity
end


local transactionActiveTransactions = {}
local transactionHistory = {}
local transactionStats = {
    totalTransactions = 0,
    successfulTransactions = 0,
    failedTransactions = 0,
    totalMoneyTransferred = 0,
    averageTransactionTime = 0,
    itemPurchases = {}
}

local function LogTransaction(playerId, operation, message, level)
    level = level or Constants.LOG_LEVELS.INFO
    local playerName = "System"
    if playerId and playerId > 0 then
        playerName = SafeGetPlayerName(playerId) or "Unknown"
    end
    if level == Constants.LOG_LEVELS.ERROR or level == Constants.LOG_LEVELS.WARN then
        Log(string.format("[CNR_SECURE_TRANSACTIONS] [%s] Player %s (%s) - %s: %s", 
            string.upper(level), playerName, tostring(playerId or "system"), operation, message))
    end
end


function SecureTransactions.ProcessPurchase(playerId, itemId, quantity)
    local startTime = GetGameTimer()
    transactionStats.totalTransactions = transactionStats.totalTransactions + 1
    
    local valid, validatedQuantity, error = Validation.ValidateQuantity(quantity)
    if not valid then
        LogTransaction(playerId, "ProcessPurchase", string.format("Invalid quantity: %s", error), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, error
    end
    
    local valid, itemConfig, error = Validation.ValidateItem(itemId)
    if not valid then
        LogTransaction(playerId, "ProcessPurchase", string.format("Invalid item: %s", error), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, error
    end
    
    if not playersData[playerId] then
        LogTransaction(playerId, "ProcessPurchase", "Player data not found", Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, "Player data not found"
    end
    
    local totalCost = (itemConfig.price or 0) * validatedQuantity
    if playersData[playerId].money < totalCost then
        LogTransaction(playerId, "ProcessPurchase", string.format("Insufficient funds: has $%d, needs $%d", playersData[playerId].money, totalCost), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, "Insufficient funds"
    end
    
    local success, error = SecureInventory.AddItem(playerId, itemId, validatedQuantity, "purchase")
    if not success then
        LogTransaction(playerId, "ProcessPurchase", string.format("Failed to add item: %s", error), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, error
    end
    
    playersData[playerId].money = playersData[playerId].money - totalCost
    transactionStats.successfulTransactions = transactionStats.successfulTransactions + 1
    transactionStats.totalMoneyTransferred = transactionStats.totalMoneyTransferred + totalCost
    
    if not transactionStats.itemPurchases[itemId] then
        transactionStats.itemPurchases[itemId] = 0
    end
    transactionStats.itemPurchases[itemId] = transactionStats.itemPurchases[itemId] + validatedQuantity
    
    local operationTime = GetGameTimer() - startTime
    transactionStats.averageTransactionTime = (transactionStats.averageTransactionTime + operationTime) / 2
    
    LogTransaction(playerId, "ProcessPurchase", string.format("Purchased %d x %s for $%d", validatedQuantity, itemId, totalCost))
    return true, nil
end

function SecureTransactions.ProcessSale(playerId, itemId, quantity)
    local startTime = GetGameTimer()
    transactionStats.totalTransactions = transactionStats.totalTransactions + 1
    
    local valid, validatedQuantity, error = Validation.ValidateQuantity(quantity)
    if not valid then
        LogTransaction(playerId, "ProcessSale", string.format("Invalid quantity: %s", error), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, error
    end
    
    local valid, itemConfig, error = Validation.ValidateItem(itemId)
    if not valid then
        LogTransaction(playerId, "ProcessSale", string.format("Invalid item: %s", error), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, error
    end
    
    if not SecureInventory.HasItem(playerId, itemId, validatedQuantity) then
        LogTransaction(playerId, "ProcessSale", string.format("Insufficient item quantity for sale"), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, "Insufficient item quantity"
    end
    
    local success, error = SecureInventory.RemoveItem(playerId, itemId, validatedQuantity, "sale")
    if not success then
        LogTransaction(playerId, "ProcessSale", string.format("Failed to remove item: %s", error), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, error
    end
    
    local salePrice = math.floor(((itemConfig.price or 0) * validatedQuantity) * 0.7)
    playersData[playerId].money = playersData[playerId].money + salePrice
    
    transactionStats.successfulTransactions = transactionStats.successfulTransactions + 1
    transactionStats.totalMoneyTransferred = transactionStats.totalMoneyTransferred + salePrice
    
    local operationTime = GetGameTimer() - startTime
    transactionStats.averageTransactionTime = (transactionStats.averageTransactionTime + operationTime) / 2
    
    LogTransaction(playerId, "ProcessSale", string.format("Sold %d x %s for $%d", validatedQuantity, itemId, salePrice))
    return true, salePrice
end

function SecureTransactions.AddMoney(playerId, amount, reason)
    local startTime = GetGameTimer()
    transactionStats.totalTransactions = transactionStats.totalTransactions + 1
    
    local valid, validatedAmount, error = Validation.ValidateMoney(amount, false)
    if not valid then
        LogTransaction(playerId, "AddMoney", string.format("Invalid amount: %s", error), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, error
    end
    
    if not playersData[playerId] then
        LogTransaction(playerId, "AddMoney", "Player data not found", Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, "Player data not found"
    end
    
    local newBalance = playersData[playerId].money + validatedAmount
    if newBalance > Constants.VALIDATION.MAX_MONEY_AMOUNT then
        LogTransaction(playerId, "AddMoney", string.format("Would exceed maximum money limit"), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, "Would exceed maximum money limit"
    end
    
    playersData[playerId].money = newBalance
    transactionStats.successfulTransactions = transactionStats.successfulTransactions + 1
    transactionStats.totalMoneyTransferred = transactionStats.totalMoneyTransferred + validatedAmount
    
    local operationTime = GetGameTimer() - startTime
    transactionStats.averageTransactionTime = (transactionStats.averageTransactionTime + operationTime) / 2
    
    LogTransaction(playerId, "AddMoney", string.format("Added $%d (reason: %s), new balance: $%d", validatedAmount, reason or "unknown", newBalance))
    return true, newBalance
end

function SecureTransactions.RemoveMoney(playerId, amount, reason)
    local startTime = GetGameTimer()
    transactionStats.totalTransactions = transactionStats.totalTransactions + 1
    
    local valid, validatedAmount, error = Validation.ValidateMoney(amount, false)
    if not valid then
        LogTransaction(playerId, "RemoveMoney", string.format("Invalid amount: %s", error), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, error
    end
    
    if not playersData[playerId] then
        LogTransaction(playerId, "RemoveMoney", "Player data not found", Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, "Player data not found"
    end
    
    if playersData[playerId].money < validatedAmount then
        LogTransaction(playerId, "RemoveMoney", string.format("Insufficient funds: has $%d, needs $%d", playersData[playerId].money, validatedAmount), Constants.LOG_LEVELS.ERROR)
        transactionStats.failedTransactions = transactionStats.failedTransactions + 1
        return false, "Insufficient funds"
    end
    
    local newBalance = playersData[playerId].money - validatedAmount
    playersData[playerId].money = newBalance
    
    transactionStats.successfulTransactions = transactionStats.successfulTransactions + 1
    transactionStats.totalMoneyTransferred = transactionStats.totalMoneyTransferred + validatedAmount
    
    local operationTime = GetGameTimer() - startTime
    transactionStats.averageTransactionTime = (transactionStats.averageTransactionTime + operationTime) / 2
    
    LogTransaction(playerId, "RemoveMoney", string.format("Removed $%d (reason: %s), new balance: $%d", validatedAmount, reason or "unknown", newBalance))
    return true, newBalance
end


RegisterNetEvent('cnr:getInventoryForUI')
AddEventHandler('cnr:getInventoryForUI', SecurityEnhancements.SecureEventHandler('cnr:getInventoryForUI', function(playerId)
    local inventory = SecureInventory.GetInventory(playerId)
    
    if inventory then
        TriggerClientEvent('cnr:receiveInventoryData', playerId, inventory)
        LogInventory(playerId, "GetInventoryForUI", "Sent inventory data to client")
    else
        LogInventory(playerId, "GetInventoryForUI", "Failed to retrieve inventory data", Constants.LOG_LEVELS.ERROR)
        TriggerClientEvent('cnr:inventoryError', playerId, "Failed to load inventory")
    end
end))

RegisterNetEvent('cnr:useItem')
AddEventHandler('cnr:useItem', SecurityEnhancements.SecureEventHandler('cnr:useItem', function(playerId, itemId)
    
    if not SecureInventory.HasItem(playerId, itemId, 1) then
        LogInventory(playerId, "UseItem", string.format("Player does not have item: %s", itemId), Constants.LOG_LEVELS.ERROR)
        TriggerClientEvent('cnr:itemUseError', playerId, "You don't have this item")
        return
    end
    
    local valid, itemConfig, error = Validation.ValidateItem(itemId)
    if not valid then
        LogInventory(playerId, "UseItem", string.format("Invalid item: %s", error), Constants.LOG_LEVELS.ERROR)
        TriggerClientEvent('cnr:itemUseError', playerId, "Invalid item")
        return
    end
    
    if itemConfig.consumable then
        local success, error = SecureInventory.RemoveItem(playerId, itemId, 1, "consumed")
        if not success then
            LogInventory(playerId, "UseItem", string.format("Failed to consume item: %s", error), Constants.LOG_LEVELS.ERROR)
            TriggerClientEvent('cnr:itemUseError', playerId, "Failed to use item")
            return
        end
    end
    
    TriggerClientEvent('cnr:itemUsed', playerId, itemId, itemConfig)
    LogInventory(playerId, "UseItem", string.format("Used item: %s", itemId))
end))

RegisterNetEvent('cnr:dropItem')
AddEventHandler('cnr:dropItem', SecurityEnhancements.SecureEventHandler('cnr:dropItem', function(playerId, itemId, quantity)
    local dropQuantity = quantity or 1
    
    local success, error = SecureInventory.RemoveItem(playerId, itemId, dropQuantity, "dropped")
    if not success then
        LogInventory(playerId, "DropItem", string.format("Failed to drop item: %s", error), Constants.LOG_LEVELS.ERROR)
        TriggerClientEvent('cnr:itemDropError', playerId, error)
        return
    end
    
    local playerPed = GetPlayerPed(playerId)
    local coords = GetEntityCoords(playerPed)
    
    TriggerClientEvent('cnr:itemDropped', -1, itemId, dropQuantity, coords)
    LogInventory(playerId, "DropItem", string.format("Dropped %d x %s at coordinates", dropQuantity, itemId))
end))


function InitializePlayerInventory(pData, playerId)
    if not pData then
        LogInventory(playerId, "InitializePlayerInventory", "Player data is nil", Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    if not pData.inventory then
        pData.inventory = {}
        LogInventory(playerId, "InitializePlayerInventory", "Created new inventory")
    end
    
    if not pData.inventoryWeight then
        pData.inventoryWeight = 0
    end
    
    if not pData.maxInventoryWeight then
        pData.maxInventoryWeight = Constants.PLAYER_LIMITS.MAX_INVENTORY_WEIGHT or 100
    end
    
    return true
end

function CanCarryItem(playerId, itemId, quantity)
    local valid, validatedQuantity, error = Validation.ValidateQuantity(quantity)
    if not valid then
        return false, error
    end
    
    local valid, itemConfig, error = Validation.ValidateItem(itemId)
    if not valid then
        return false, error
    end
    
    if not playersData[playerId] then
        return false, "Player data not found"
    end
    
    local itemWeight = (itemConfig.weight or 0) * validatedQuantity
    local currentWeight = playersData[playerId].inventoryWeight or 0
    local maxWeight = playersData[playerId].maxInventoryWeight or Constants.PLAYER_LIMITS.MAX_INVENTORY_WEIGHT or 100
    
    if (currentWeight + itemWeight) > maxWeight then
        return false, "Would exceed inventory weight limit"
    end
    
    return true, nil
end

function AddItem(pData, itemId, quantity, playerId)
    return SecureInventory.AddItem(playerId, itemId, quantity, "legacy_function")
end

function RemoveItem(pData, itemId, quantity, playerId)
    return SecureInventory.RemoveItem(playerId, itemId, quantity, "legacy_function")
end

function GetInventory(pData, specificItemId, playerId)
    if specificItemId then
        local inventory = SecureInventory.GetInventory(playerId)
        return inventory and inventory[specificItemId] or 0
    else
        return SecureInventory.GetInventory(playerId)
    end
end

function HasItem(pData, itemId, quantity, playerId)
    return SecureInventory.HasItem(playerId, itemId, quantity)
end

function SecureInventory.CleanupPlayerData(playerId)
    if not playerId then return end
    
    if playersData and playersData[playerId] and playersData[playerId].inventory then
        playersData[playerId].inventory = nil
        LogInventory(playerId, "CleanupPlayerData", "Player inventory data cleaned up")
    end
end

function SecureInventory.Initialize()
    LogInventory(nil, "Initialize", "SecureInventory system initialized")
    return true
end

function SecureTransactions.Initialize()
    LogTransaction(nil, "Initialize", "SecureTransactions system initialized")
    return true
end

SecureInventory.Initialize()
SecureTransactions.Initialize()

Log("[CNR_SECURE_SYSTEMS] Unified secure systems loaded (combines SecureInventory and SecureTransactions)", Constants.LOG_LEVELS.INFO)
