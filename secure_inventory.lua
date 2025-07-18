-- secure_inventory.lua
-- Secure inventory system with anti-duplication measures and comprehensive validation
-- Version: 1.2.0

-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before secure_inventory.lua")
end

if not Validation then
    error("Validation must be loaded before secure_inventory.lua")
end

if not DataManager then
    error("DataManager must be loaded before secure_inventory.lua")
end

-- Initialize SecureInventory module
SecureInventory = SecureInventory or {}

-- Transaction tracking to prevent duplication
local activeTransactions = {}
local transactionHistory = {}
local inventoryLocks = {}

-- Performance monitoring
local inventoryStats = {
    totalOperations = 0,
    failedOperations = 0,
    duplicateAttempts = 0,
    averageOperationTime = 0
}

-- ====================================================================
-- UTILITY FUNCTIONS
-- ====================================================================


--- Generate unique transaction ID
--- @return string Unique transaction ID
local function GenerateTransactionId()
    return string.format("txn_%d_%d", GetGameTimer(), math.random(10000, 99999))
end

--- Log inventory operations
--- @param playerId number Player ID
--- @param operation string Operation type
--- @param message string Log message
--- @param level string Log level
local function LogInventory(playerId, operation, message, level)
    level = level or Constants.LOG_LEVELS.INFO
    local playerName = GetPlayerName(playerId) or "Unknown"
    
    if level == Constants.LOG_LEVELS.ERROR or level == Constants.LOG_LEVELS.WARN then
        Log(string.format("[CNR_SECURE_INVENTORY] [%s] Player %s (%d) - %s: %s", 
            string.upper(level), playerName, playerId, operation, message))
    end
end

--- Check if inventory is locked for a player
--- @param playerId number Player ID
--- @return boolean Whether inventory is locked
local function IsInventoryLocked(playerId)
    local lock = inventoryLocks[playerId]
    if not lock then return false end
    
    -- Check if lock has expired
    if GetGameTimer() - lock.timestamp > Constants.TIME_MS.SECOND * 5 then
        inventoryLocks[playerId] = nil
        return false
    end
    
    return true
end

--- Lock inventory for a player during operations
--- @param playerId number Player ID
--- @param operation string Operation type
local function LockInventory(playerId, operation)
    inventoryLocks[playerId] = {
        operation = operation,
        timestamp = GetGameTimer()
    }
end

--- Unlock inventory for a player
--- @param playerId number Player ID
local function UnlockInventory(playerId)
    inventoryLocks[playerId] = nil
end

-- ====================================================================
-- TRANSACTION SYSTEM
-- ====================================================================

--- Start a new inventory transaction
--- @param playerId number Player ID
--- @param operation string Operation type
--- @param itemId string Item ID
--- @param quantity number Quantity
--- @return string, boolean Transaction ID and success status
local function StartTransaction(playerId, operation, itemId, quantity)
    -- Check if inventory is locked
    if IsInventoryLocked(playerId) then
        LogInventory(playerId, operation, "Inventory locked, transaction denied", Constants.LOG_LEVELS.WARN)
        return nil, false
    end
    
    -- Check for duplicate transactions
    local currentTime = GetGameTimer()
    for txnId, txn in pairs(activeTransactions) do
        if txn.playerId == playerId and txn.itemId == itemId and 
           txn.operation == operation and (currentTime - txn.startTime) < 1000 then
            inventoryStats.duplicateAttempts = inventoryStats.duplicateAttempts + 1
            LogInventory(playerId, operation, 
                string.format("Duplicate transaction attempt blocked: %s x%d", itemId, quantity), 
                Constants.LOG_LEVELS.WARN)
            return nil, false
        end
    end
    
    local transactionId = GenerateTransactionId()
    
    activeTransactions[transactionId] = {
        playerId = playerId,
        operation = operation,
        itemId = itemId,
        quantity = quantity,
        startTime = currentTime,
        completed = false
    }
    
    -- Lock inventory during transaction
    LockInventory(playerId, operation)
    
    LogInventory(playerId, operation, 
        string.format("Transaction started: %s - %s x%d (ID: %s)", operation, itemId, quantity, transactionId))
    
    return transactionId, true
end

--- Complete a transaction
--- @param transactionId string Transaction ID
--- @param success boolean Whether transaction was successful
local function CompleteTransaction(transactionId, success)
    local transaction = activeTransactions[transactionId]
    if not transaction then
        return false
    end
    
    transaction.completed = true
    transaction.endTime = GetGameTimer()
    transaction.success = success
    
    -- Unlock inventory
    UnlockInventory(transaction.playerId)
    
    -- Move to history
    transactionHistory[transactionId] = transaction
    activeTransactions[transactionId] = nil
    
    -- Update stats
    inventoryStats.totalOperations = inventoryStats.totalOperations + 1
    if not success then
        inventoryStats.failedOperations = inventoryStats.failedOperations + 1
    end
    
    local operationTime = transaction.endTime - transaction.startTime
    inventoryStats.averageOperationTime = (inventoryStats.averageOperationTime + operationTime) / 2
    
    LogInventory(transaction.playerId, transaction.operation, 
        string.format("Transaction completed: %s (took %dms)", 
            success and "SUCCESS" or "FAILED", operationTime))
    
    return true
end

--- Clean up old transactions
local function CleanupTransactions()
    local currentTime = GetGameTimer()
    local cleanupThreshold = 5 * Constants.TIME_MS.MINUTE
    
    -- Clean active transactions (should not happen normally)
    for txnId, txn in pairs(activeTransactions) do
        if currentTime - txn.startTime > Constants.TIME_MS.SECOND * 10 then
            LogInventory(txn.playerId, txn.operation, 
                string.format("Cleaning up stale transaction: %s", txnId), 
                Constants.LOG_LEVELS.WARN)
            UnlockInventory(txn.playerId)
            activeTransactions[txnId] = nil
        end
    end
    
    -- Clean transaction history
    for txnId, txn in pairs(transactionHistory) do
        if currentTime - txn.endTime > cleanupThreshold then
            transactionHistory[txnId] = nil
        end
    end
end

-- ====================================================================
-- SECURE INVENTORY OPERATIONS
-- ====================================================================

--- Securely add item to player inventory
--- @param playerId number Player ID
--- @param itemId string Item ID
--- @param quantity number Quantity to add
--- @param source string Source of the item (purchase, admin, etc.)
--- @return boolean, string Success status and message
function SecureInventory.AddItem(playerId, itemId, quantity, source)
    local startTime = GetGameTimer()
    source = source or "unknown"
    
    -- Validate inputs
    local valid, error = Validation.ValidatePlayer(playerId)
    if not valid then return false, error end
    
    local validItem, itemConfig, itemError = Validation.ValidateItem(itemId)
    if not validItem then return false, itemError end
    
    local validQty, validatedQuantity, qtyError = Validation.ValidateQuantity(quantity)
    if not validQty then return false, qtyError end
    
    -- Validate inventory operation
    local validOp, opError = Validation.ValidateInventoryOperation(playerId, "add")
    if not validOp then return false, opError end
    
    -- Get player data
    local playerData = GetCnrPlayerData(playerId)
    if not playerData then
        return false, Constants.ERROR_MESSAGES.PLAYER_NOT_FOUND
    end
    
    -- Check inventory space
    local validSpace, spaceError = Validation.ValidateInventorySpace(playerData, validatedQuantity)
    if not validSpace then return false, spaceError end
    
    -- Start transaction
    local transactionId, txnSuccess = StartTransaction(playerId, "add", itemId, validatedQuantity)
    if not txnSuccess then
        return false, "Transaction could not be started"
    end
    
    -- Initialize inventory if needed
    if not playerData.inventory then
        playerData.inventory = {}
    end
    
    -- Add item
    if not playerData.inventory[itemId] then
        playerData.inventory[itemId] = {
            count = 0,
            name = itemConfig.name,
            category = itemConfig.category,
            addedTime = os.time(),
            source = source
        }
    end
    
    local oldCount = playerData.inventory[itemId].count
    playerData.inventory[itemId].count = oldCount + validatedQuantity
    playerData.inventory[itemId].lastModified = os.time()
    
    -- Mark for save
    DataManager.MarkPlayerForSave(playerId)
    
    -- Complete transaction
    CompleteTransaction(transactionId, true)
    
    -- Notify client
    TriggerClientEvent(Constants.EVENTS.SERVER_TO_CLIENT.INVENTORY_UPDATED, playerId, 
        MinimizeInventoryForSync(playerData.inventory))
    
    LogInventory(playerId, "add", 
        string.format("Added %dx %s (source: %s, new total: %d)", 
            validatedQuantity, itemConfig.name, source, playerData.inventory[itemId].count))
    
    return true, string.format("Added %dx %s", validatedQuantity, itemConfig.name)
end

--- Securely remove item from player inventory
--- @param playerId number Player ID
--- @param itemId string Item ID
--- @param quantity number Quantity to remove
--- @param reason string Reason for removal
--- @return boolean, string Success status and message
function SecureInventory.RemoveItem(playerId, itemId, quantity, reason)
    reason = reason or "unknown"
    
    -- Validate inputs
    local valid, error = Validation.ValidatePlayer(playerId)
    if not valid then return false, error end
    
    local validItem, itemConfig, itemError = Validation.ValidateItem(itemId)
    if not validItem then return false, itemError end
    
    local validQty, validatedQuantity, qtyError = Validation.ValidateQuantity(quantity)
    if not validQty then return false, qtyError end
    
    -- Validate inventory operation
    local validOp, opError = Validation.ValidateInventoryOperation(playerId, "remove")
    if not validOp then return false, opError end
    
    -- Get player data
    local playerData = GetCnrPlayerData(playerId)
    if not playerData or not playerData.inventory then
        return false, Constants.ERROR_MESSAGES.PLAYER_NOT_FOUND
    end
    
    -- Check if player has the item
    local playerItem = playerData.inventory[itemId]
    if not playerItem or playerItem.count < validatedQuantity then
        return false, string.format("Insufficient items: have %d, need %d", 
            playerItem and playerItem.count or 0, validatedQuantity)
    end
    
    -- Start transaction
    local transactionId, txnSuccess = StartTransaction(playerId, "remove", itemId, validatedQuantity)
    if not txnSuccess then
        return false, "Transaction could not be started"
    end
    
    -- Remove item
    local oldCount = playerItem.count
    playerItem.count = oldCount - validatedQuantity
    playerItem.lastModified = os.time()
    
    -- Remove item completely if count reaches zero
    if playerItem.count <= 0 then
        playerData.inventory[itemId] = nil
    end
    
    -- Mark for save
    DataManager.MarkPlayerForSave(playerId)
    
    -- Complete transaction
    CompleteTransaction(transactionId, true)
    
    -- Notify client
    TriggerClientEvent(Constants.EVENTS.SERVER_TO_CLIENT.INVENTORY_UPDATED, playerId, 
        MinimizeInventoryForSync(playerData.inventory))
    
    LogInventory(playerId, "remove", 
        string.format("Removed %dx %s (reason: %s, remaining: %d)", 
            validatedQuantity, itemConfig.name, reason, playerItem and playerItem.count or 0))
    
    return true, string.format("Removed %dx %s", validatedQuantity, itemConfig.name)
end

--- Securely transfer item between players
--- @param fromPlayerId number Source player ID
--- @param toPlayerId number Target player ID
--- @param itemId string Item ID
--- @param quantity number Quantity to transfer
--- @param reason string Reason for transfer
--- @return boolean, string Success status and message
function SecureInventory.TransferItem(fromPlayerId, toPlayerId, itemId, quantity, reason)
    reason = reason or "transfer"
    
    -- Validate both players
    local validFrom, errorFrom = Validation.ValidatePlayer(fromPlayerId)
    if not validFrom then return false, "Source player: " .. errorFrom end
    
    local validTo, errorTo = Validation.ValidatePlayer(toPlayerId)
    if not validTo then return false, "Target player: " .. errorTo end
    
    -- Prevent self-transfer
    if fromPlayerId == toPlayerId then
        return false, "Cannot transfer to yourself"
    end
    
    -- Remove from source
    local removeSuccess, removeError = SecureInventory.RemoveItem(fromPlayerId, itemId, quantity, 
        string.format("transfer_to_%d", toPlayerId))
    if not removeSuccess then
        return false, "Transfer failed: " .. removeError
    end
    
    -- Add to target
    local addSuccess, addError = SecureInventory.AddItem(toPlayerId, itemId, quantity, 
        string.format("transfer_from_%d", fromPlayerId))
    if not addSuccess then
        -- Rollback: add back to source
        SecureInventory.AddItem(fromPlayerId, itemId, quantity, "rollback_transfer")
        return false, "Transfer failed: " .. addError
    end
    
    LogInventory(fromPlayerId, "transfer", 
        string.format("Transferred %dx %s to player %d (reason: %s)", 
            quantity, itemId, toPlayerId, reason))
    
    return true, string.format("Transferred %dx %s", quantity, itemId)
end

--- Get player inventory with validation
--- @param playerId number Player ID
--- @return boolean, table Success status and inventory data
function SecureInventory.GetInventory(playerId)
    local valid, error = Validation.ValidatePlayer(playerId)
    if not valid then return false, error end
    
    local playerData = GetCnrPlayerData(playerId)
    if not playerData then
        return false, Constants.ERROR_MESSAGES.PLAYER_NOT_FOUND
    end
    
    return true, playerData.inventory or {}
end

--- Check if player has specific item and quantity
--- @param playerId number Player ID
--- @param itemId string Item ID
--- @param quantity number Required quantity
--- @return boolean, number Whether player has item and actual count
function SecureInventory.HasItem(playerId, itemId, quantity)
    quantity = quantity or 1
    
    local success, inventory = SecureInventory.GetInventory(playerId)
    if not success then return false, 0 end
    
    local item = inventory[itemId]
    if not item or not item.count then return false, 0 end
    
    return item.count >= quantity, item.count
end

-- ====================================================================
-- ANTI-DUPLICATION MEASURES
-- ====================================================================

--- Validate inventory integrity
--- @param playerId number Player ID
--- @return boolean, table Validation status and issues found
function SecureInventory.ValidateInventoryIntegrity(playerId)
    local success, inventory = SecureInventory.GetInventory(playerId)
    if not success then return false, {inventory} end
    
    local issues = {}
    
    for itemId, itemData in pairs(inventory) do
        -- Check item exists in config
        local validItem, itemConfig = Validation.ValidateItem(itemId)
        if not validItem then
            table.insert(issues, string.format("Unknown item: %s", itemId))
        end
        
        -- Check count is valid
        if not itemData.count or type(itemData.count) ~= "number" or itemData.count < 0 then
            table.insert(issues, string.format("Invalid count for %s: %s", itemId, tostring(itemData.count)))
        end
        
        -- Check for excessive quantities
        if itemData.count > Constants.VALIDATION.MAX_ITEM_QUANTITY then
            table.insert(issues, string.format("Excessive quantity for %s: %d", itemId, itemData.count))
        end
    end
    
    if #issues > 0 then
        LogInventory(playerId, "integrity_check", 
            string.format("Found %d integrity issues", #issues), 
            Constants.LOG_LEVELS.WARN)
    end
    
    return #issues == 0, issues
end

--- Fix inventory integrity issues
--- @param playerId number Player ID
--- @return boolean, number Success status and number of fixes applied
function SecureInventory.FixInventoryIntegrity(playerId)
    local playerData = GetCnrPlayerData(playerId)
    if not playerData or not playerData.inventory then
        return false, 0
    end
    
    local fixes = 0
    
    for itemId, itemData in pairs(playerData.inventory) do
        local changed = false
        
        -- Remove unknown items
        local validItem = Validation.ValidateItem(itemId)
        if not validItem then
            playerData.inventory[itemId] = nil
            fixes = fixes + 1
            LogInventory(playerId, "fix_integrity", string.format("Removed unknown item: %s", itemId))
        else
            -- Fix invalid counts
            if not itemData.count or type(itemData.count) ~= "number" or itemData.count < 0 then
                itemData.count = 0
                changed = true
            end
            
            -- Cap excessive quantities
            if itemData.count > Constants.VALIDATION.MAX_ITEM_QUANTITY then
                itemData.count = Constants.VALIDATION.MAX_ITEM_QUANTITY
                changed = true
            end
            
            -- Remove items with zero count
            if itemData.count <= 0 then
                playerData.inventory[itemId] = nil
                changed = true
            end
            
            if changed then
                fixes = fixes + 1
                LogInventory(playerId, "fix_integrity", string.format("Fixed item: %s", itemId))
            end
        end
    end
    
    if fixes > 0 then
        DataManager.MarkPlayerForSave(playerId)
        TriggerClientEvent(Constants.EVENTS.SERVER_TO_CLIENT.INVENTORY_UPDATED, playerId, 
            MinimizeInventoryForSync(playerData.inventory))
    end
    
    return true, fixes
end

-- ====================================================================
-- STATISTICS AND MONITORING
-- ====================================================================

--- Get inventory system statistics
--- @return table Statistics
function SecureInventory.GetStats()
    return {
        totalOperations = inventoryStats.totalOperations,
        failedOperations = inventoryStats.failedOperations,
        duplicateAttempts = inventoryStats.duplicateAttempts,
        successRate = inventoryStats.totalOperations > 0 and 
            ((inventoryStats.totalOperations - inventoryStats.failedOperations) / inventoryStats.totalOperations * 100) or 0,
        averageOperationTime = inventoryStats.averageOperationTime,
        activeTransactions = tablelength(activeTransactions),
        lockedInventories = tablelength(inventoryLocks)
    }
end

--- Log inventory statistics
function SecureInventory.LogStats()
    local stats = SecureInventory.GetStats()
    Log(string.format("[CNR_SECURE_INVENTORY] Stats - Operations: %d, Failed: %d, Duplicates: %d, Success Rate: %.1f%%, Avg Time: %.1fms, Active: %d, Locked: %d",
        stats.totalOperations, stats.failedOperations, stats.duplicateAttempts,
        stats.successRate, stats.averageOperationTime, stats.activeTransactions, stats.lockedInventories))
end

-- ====================================================================
-- INITIALIZATION AND CLEANUP
-- ====================================================================

--- Initialize secure inventory system
function SecureInventory.Initialize()
    Log("[CNR_SECURE_INVENTORY] Secure Inventory System initialized")
    
    -- Start cleanup thread
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Constants.TIME_MS.MINUTE)
            CleanupTransactions()
        end
    end)
    
    -- Statistics logging thread
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(10 * Constants.TIME_MS.MINUTE)
            SecureInventory.LogStats()
        end
    end)
end

--- Enhanced cleanup with memory manager integration
--- @param playerId number Player ID
function SecureInventory.CleanupPlayer(playerId)
    -- Remove any active transactions
    for txnId, txn in pairs(activeTransactions) do
        if txn.playerId == playerId then
            activeTransactions[txnId] = nil
        end
    end
    
    -- Unlock inventory
    UnlockInventory(playerId)
    
    LogInventory(playerId, "cleanup", "Player inventory cleaned up")
end

--- Cleanup player data for memory manager
--- @param playerId number Player ID
--- @return number Number of items cleaned
function SecureInventory.CleanupPlayerData(playerId)
    local cleanedItems = 0
    
    -- Remove active transactions
    for txnId, txn in pairs(activeTransactions) do
        if txn.playerId == playerId then
            activeTransactions[txnId] = nil
            cleanedItems = cleanedItems + 1
        end
    end
    
    -- Unlock inventory
    UnlockInventory(playerId)
    cleanedItems = cleanedItems + 1
    
    LogInventory(playerId, "cleanup", string.format("Memory cleanup completed (%d items)", cleanedItems))
    return cleanedItems
end

--- Cleanup inventory cache for offline players
--- @return number Number of items cleaned
function SecureInventory.CleanupInventoryCache()
    local onlinePlayers = {}
    for _, playerId in ipairs(GetPlayers()) do
        onlinePlayers[tonumber(playerId)] = true
    end
    
    local cleanedCount = 0
    
    -- Clean up active transactions for offline players
    for txnId, txn in pairs(activeTransactions) do
        if not onlinePlayers[txn.playerId] then
            activeTransactions[txnId] = nil
            cleanedCount = cleanedCount + 1
        end
    end
    
    return cleanedCount
end

-- ====================================================================
-- EVENT HANDLERS (Consolidated from inventory_server.lua)
-- ====================================================================

--- Event: Get inventory for UI
RegisterNetEvent('cnr:getInventoryForUI')
AddEventHandler('cnr:getInventoryForUI', function()
    local playerId = source
    local success, inventory = SecureInventory.GetInventory(playerId)
    
    if success then
        -- Send minimized inventory to client
        local minimizedInventory = MinimizeInventoryForSync(inventory)
        TriggerClientEvent('cnr:receiveInventoryForUI', playerId, minimizedInventory)
    else
        LogSecureInventory(playerId, "get_inventory_ui", "Failed to get inventory for UI", Constants.LOG_LEVELS.ERROR)
        TriggerClientEvent('cnr:receiveInventoryForUI', playerId, {})
    end
end)

--- Event: Use item
RegisterNetEvent('cnr:useItem')
AddEventHandler('cnr:useItem', function(itemId)
    local playerId = source
    
    -- Validate input
    local validString, stringError = ValidateString(itemId, Constants.VALIDATION.MAX_STRING_LENGTH, false)
    if not validString then
        LogInventory(playerId, "use_item", "Invalid item ID: " .. stringError, Constants.LOG_LEVELS.WARN)
        return
    end
    
    -- Check if player has the item
    local hasItem, actualCount = SecureInventory.HasItem(playerId, itemId, 1)
    if not hasItem then
        TriggerClientEvent('cnr:showNotification', playerId, "You don't have this item", Constants.NOTIFICATION_TYPES.ERROR)
        return
    end
    
    -- Get item config
    local validItem, itemConfig, itemError = Validation.ValidateItem(itemId)
    if not validItem then
        LogInventory(playerId, "use_item", string.format("Unknown item: %s - %s", itemId, itemError), Constants.LOG_LEVELS.WARN)
        return
    end
    local consumed = false
    
    -- Handle different item types
    if itemConfig.category == "Medical" then
        -- Handle medical items
        if itemId == "medkit" then
            TriggerClientEvent('cnr:healPlayer', playerId, 100)
            consumed = true
        elseif itemId == "bandage" then
            TriggerClientEvent('cnr:healPlayer', playerId, 25)
            consumed = true
        end
    elseif itemConfig.category == "Food" then
        -- Handle food items
        TriggerClientEvent('cnr:healPlayer', playerId, itemConfig.healAmount or 10)
        consumed = true
    elseif itemConfig.category == "Tools" then
        -- Tools are not consumed on use
        TriggerClientEvent('cnr:showNotification', playerId, string.format("Using %s", itemConfig.name), Constants.NOTIFICATION_TYPES.INFO)
    end
    
    -- Remove item if consumed
    if consumed then
        local success, error = SecureInventory.RemoveItem(playerId, itemId, 1, "item_used")
        if success then
            TriggerClientEvent('cnr:showNotification', playerId, string.format("Used %s", itemConfig.name), Constants.NOTIFICATION_TYPES.SUCCESS)
            LogSecureInventory(playerId, "use_item", string.format("Used item: %s", itemId))
        else
            LogSecureInventory(playerId, "use_item", string.format("Failed to remove used item: %s", error), Constants.LOG_LEVELS.ERROR)
        end
    end
end)

--- Event: Drop item
RegisterNetEvent('cnr:dropItem')
AddEventHandler('cnr:dropItem', function(itemId, quantity)
    local playerId = source
    quantity = tonumber(quantity) or 1
    
    -- Validate input
    local validString, stringError = ValidateString(itemId, Constants.VALIDATION.MAX_STRING_LENGTH, false)
    if not validString then
        LogInventory(playerId, "drop_item", "Invalid item ID: " .. stringError, Constants.LOG_LEVELS.WARN)
        return
    end
    
    local validQty, validatedQuantity, qtyError = Validation.ValidateQuantity(quantity)
    if not validQty then
        LogInventory(playerId, "drop_item", "Invalid quantity: " .. qtyError, Constants.LOG_LEVELS.WARN)
        return
    end
    quantity = validatedQuantity
    
    -- Check if player has enough items
    local hasItem, actualCount = SecureInventory.HasItem(playerId, itemId, quantity)
    if not hasItem then
        TriggerClientEvent('cnr:showNotification', playerId, "You don't have enough of this item", Constants.NOTIFICATION_TYPES.ERROR)
        return
    end
    
    -- Remove item from inventory
    local success, error = SecureInventory.RemoveItem(playerId, itemId, quantity, "item_dropped")
    if success then
        -- Get item config for display
        local validItem, itemConfig = Validation.ValidateItem(itemId)
        local itemName = (validItem and itemConfig and itemConfig.name) or itemId
        
        TriggerClientEvent('cnr:showNotification', playerId, 
            string.format("Dropped %dx %s", quantity, itemName), 
            Constants.NOTIFICATION_TYPES.INFO)
        
        LogSecureInventory(playerId, "drop_item", string.format("Dropped %dx %s", quantity, itemId))
        
    else
        LogSecureInventory(playerId, "drop_item", string.format("Failed to drop item: %s", error), Constants.LOG_LEVELS.ERROR)
        TriggerClientEvent('cnr:showNotification', playerId, "Failed to drop item", Constants.NOTIFICATION_TYPES.ERROR)
    end
end)

--- Event: Request player inventory
RegisterServerEvent('cnr:requestMyInventory')
AddEventHandler('cnr:requestMyInventory', function()
    local playerId = source
    local success, inventory = SecureInventory.GetInventory(playerId)
    
    if success then
        local minimizedInventory = MinimizeInventoryForSync(inventory)
        TriggerClientEvent('cnr:receiveMyInventory', playerId, minimizedInventory)
    else
        LogSecureInventory(playerId, "request_inventory", "Failed to get inventory", Constants.LOG_LEVELS.ERROR)
        TriggerClientEvent('cnr:receiveMyInventory', playerId, {})
    end
end)

--- Event: Request config items
RegisterServerEvent('cnr:requestConfigItems')
AddEventHandler('cnr:requestConfigItems', function()
    local playerId = source
    
    if Config and Config.Items then
        TriggerClientEvent('cnr:receiveConfigItems', playerId, Config.Items)
    else
        LogSecureInventory(playerId, "request_config", "Config.Items not available", Constants.LOG_LEVELS.WARN)
        TriggerClientEvent('cnr:receiveConfigItems', playerId, {})
    end
end)

-- ====================================================================
-- COMPATIBILITY FUNCTIONS (from inventory_server.lua)
-- ====================================================================

--- Initialize player inventory (compatibility function)
--- @param pData table Player data
--- @param playerId number Player ID
function InitializePlayerInventory(pData, playerId)
    if pData and not pData.inventory then
        pData.inventory = {}
        LogSecureInventory(playerId, "init_inventory", "Initialized empty inventory")
    end
end

--- Check if player can carry item (compatibility function)
--- @param playerId number Player ID
--- @param itemId string Item ID
--- @param quantity number Quantity to check
--- @return boolean Can carry
function CanCarryItem(playerId, itemId, quantity)
    -- Use secure inventory validation
    local success, inventory = SecureInventory.GetInventory(playerId)
    if not success then return false end
    
    -- Check if item exists in configuration
    local validItem, itemConfig, itemError = Validation.ValidateItem(itemId)
    if not validItem then
        LogInventory(playerId, "can_carry", string.format("Unknown item ID: %s - %s", itemId, itemError), Constants.LOG_LEVELS.WARN)
        return false
    end
    
    -- Calculate current inventory count
    local currentCount = 0
    for _, item in pairs(inventory) do
        currentCount = currentCount + (item.count or 0)
    end
    
    -- Basic slot limit check using constants
    local maxSlots = Constants.PLAYER_LIMITS.MAX_INVENTORY_SLOTS
    return (currentCount + quantity) <= maxSlots
end

--- Add item (compatibility function)
--- @param pData table Player data (unused in secure version)
--- @param itemId string Item ID
--- @param quantity number Quantity
--- @param playerId number Player ID
--- @return boolean Success
function AddItem(pData, itemId, quantity, playerId)
    local success, error = SecureInventory.AddItem(playerId, itemId, quantity, "legacy_add")
    return success
end

--- Remove item (compatibility function)
--- @param pData table Player data (unused in secure version)
--- @param itemId string Item ID
--- @param quantity number Quantity
--- @param playerId number Player ID
--- @return boolean Success
function RemoveItem(pData, itemId, quantity, playerId)
    local success, error = SecureInventory.RemoveItem(playerId, itemId, quantity, "legacy_remove")
    return success
end

--- Get inventory (compatibility function)
--- @param pData table Player data (unused in secure version)
--- @param specificItemId string Specific item ID (optional)
--- @param playerId number Player ID
--- @return table Inventory
function GetInventory(pData, specificItemId, playerId)
    local success, inventory = SecureInventory.GetInventory(playerId)
    if not success then return {} end
    
    if specificItemId then
        return inventory[specificItemId] or {}
    end
    
    return inventory
end

--- Check if player has item (compatibility function)
--- @param pData table Player data (unused in secure version)
--- @param itemId string Item ID
--- @param quantity number Quantity
--- @param playerId number Player ID
--- @return boolean Has item
function HasItem(pData, itemId, quantity, playerId)
    local hasItem, actualCount = SecureInventory.HasItem(playerId, itemId, quantity)
    return hasItem
end

-- Initialize when loaded
SecureInventory.Initialize()

-- SecureInventory module is now available globally
