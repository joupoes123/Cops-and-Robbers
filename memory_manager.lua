-- memory_manager.lua
-- Comprehensive memory management and cleanup system
-- Version: 1.2.0

-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before memory_manager.lua")
end

-- Initialize MemoryManager module
MemoryManager = MemoryManager or {}

-- Memory tracking tables
local memoryStats = {
    playerDataCleanups = 0,
    transactionCleanups = 0,
    inventoryCleanups = 0,
    totalMemoryFreed = 0,
    lastCleanupTime = 0
}

-- Cleanup schedules and timers
local cleanupSchedules = {}
local activeCleanupTimers = {}

-- Player disconnect cleanup queue
local disconnectCleanupQueue = {}

-- ====================================================================
-- UTILITY FUNCTIONS
-- ====================================================================

--- Log memory management operations
--- @param message string Log message
--- @param level string Log level
local function LogMemoryManager(message, level)
    level = level or Constants.LOG_LEVELS.INFO
    if level == Constants.LOG_LEVELS.ERROR or level == Constants.LOG_LEVELS.WARN then
        print(string.format("[CNR_MEMORY_MANAGER] [%s] %s", string.upper(level), message))
    end
end

--- Get table size safely
--- @param tbl table Table to measure
--- @return number Size of table
local function GetTableSize(tbl)
    if not tbl or type(tbl) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

--- Deep cleanup of nested tables
--- @param tbl table Table to clean
--- @param maxDepth number Maximum recursion depth
--- @return number Number of items cleaned
local function DeepCleanTable(tbl, maxDepth)
    maxDepth = maxDepth or 5
    if maxDepth <= 0 or not tbl or type(tbl) ~= "table" then
        return 0
    end
    
    local cleaned = 0
    for k, v in pairs(tbl) do
        if v == nil then
            tbl[k] = nil
            cleaned = cleaned + 1
        elseif type(v) == "table" then
            cleaned = cleaned + DeepCleanTable(v, maxDepth - 1)
        end
    end
    
    return cleaned
end

-- ====================================================================
-- PLAYER DATA CLEANUP
-- ====================================================================

--- Clean up all player-related data on disconnect
--- @param playerId number Player ID
function MemoryManager.CleanupPlayerData(playerId)
    local startTime = GetGameTimer()
    local cleanedItems = 0
    
    LogMemoryManager(string.format("Starting comprehensive cleanup for player %d", playerId))
    
    -- Global state tables cleanup (from server.lua)
    local globalTables = {
        'playersData', 'copsOnDuty', 'robbersActive', 'jail', 'wantedPlayers',
        'activeCooldowns', 'k9Engagements', 'activeBounties', 'playerDeployedSpikeStripsCount',
        'playerSpeedingData', 'playerVehicleData', 'playerRestrictedAreaData'
    }
    
    for _, tableName in ipairs(globalTables) do
        local globalTable = _G[tableName]
        if globalTable and globalTable[playerId] then
            globalTable[playerId] = nil
            cleanedItems = cleanedItems + 1
        end
    end
    
    -- Inventory system cleanup
    if _G.playerEquippedItems and _G.playerEquippedItems[playerId] then
        _G.playerEquippedItems[playerId] = nil
        cleanedItems = cleanedItems + 1
    end
    
    -- Secure inventory cleanup
    if SecureInventory then
        SecureInventory.CleanupPlayerData(playerId)
        cleanedItems = cleanedItems + 1
    end
    
    -- Transaction system cleanup
    if SecureTransactions then
        SecureTransactions.CleanupPlayerTransactions(playerId)
        cleanedItems = cleanedItems + 1
    end
    
    -- Validation system cleanup
    if Validation then
        Validation.CleanupPlayerData(playerId)
        cleanedItems = cleanedItems + 1
    end
    
    -- Player manager cache cleanup
    if PlayerManager then
        PlayerManager.CleanupPlayerCache(playerId)
        cleanedItems = cleanedItems + 1
    end
    
    -- Spike strips cleanup
    if _G.activeSpikeStrips then
        for stripId, stripData in pairs(_G.activeSpikeStrips) do
            if stripData and stripData.copId == playerId then
                _G.activeSpikeStrips[stripId] = nil
                cleanedItems = cleanedItems + 1
            end
        end
    end
    
    -- Update statistics
    memoryStats.playerDataCleanups = memoryStats.playerDataCleanups + 1
    memoryStats.totalMemoryFreed = memoryStats.totalMemoryFreed + cleanedItems
    
    local cleanupTime = GetGameTimer() - startTime
    LogMemoryManager(string.format("Player %d cleanup completed: %d items cleaned in %dms", 
        playerId, cleanedItems, cleanupTime))
end

--- Queue player for cleanup (handles rapid disconnects)
--- @param playerId number Player ID
--- @param reason string Disconnect reason
function MemoryManager.QueuePlayerCleanup(playerId, reason)
    -- Add to cleanup queue with timestamp
    disconnectCleanupQueue[playerId] = {
        timestamp = GetGameTimer(),
        reason = reason or "unknown"
    }
    
    -- Process cleanup after a short delay to handle rapid reconnects
    Citizen.SetTimeout(1000, function()
        if disconnectCleanupQueue[playerId] then
            MemoryManager.CleanupPlayerData(playerId)
            disconnectCleanupQueue[playerId] = nil
        end
    end)
end

-- ====================================================================
-- TRANSACTION CLEANUP
-- ====================================================================

--- Clean up old transactions and purchase history
function MemoryManager.CleanupOldTransactions()
    local startTime = GetGameTimer()
    local cleanedCount = 0
    
    -- Clean purchase history older than 7 days
    if _G.purchaseHistory then
        local cutoffTime = os.time() - (7 * 24 * 60 * 60) -- 7 days ago
        
        for transactionId, transaction in pairs(_G.purchaseHistory) do
            if transaction.timestamp and transaction.timestamp < cutoffTime then
                _G.purchaseHistory[transactionId] = nil
                cleanedCount = cleanedCount + 1
            end
        end
    end
    
    -- Clean up expired secure transactions
    if SecureTransactions then
        cleanedCount = cleanedCount + SecureTransactions.CleanupExpiredTransactions()
    end
    
    memoryStats.transactionCleanups = memoryStats.transactionCleanups + cleanedCount
    
    local cleanupTime = GetGameTimer() - startTime
    LogMemoryManager(string.format("Transaction cleanup completed: %d items cleaned in %dms", 
        cleanedCount, cleanupTime))
end

-- ====================================================================
-- INVENTORY CACHE CLEANUP
-- ====================================================================

--- Clean up inventory caches and unused data
function MemoryManager.CleanupInventoryCache()
    local startTime = GetGameTimer()
    local cleanedCount = 0
    
    -- Clean up equipped items for offline players
    if _G.playerEquippedItems then
        local onlinePlayers = {}
        for _, playerId in ipairs(GetPlayers()) do
            onlinePlayers[tonumber(playerId)] = true
        end
        
        for playerId, _ in pairs(_G.playerEquippedItems) do
            if not onlinePlayers[playerId] then
                _G.playerEquippedItems[playerId] = nil
                cleanedCount = cleanedCount + 1
            end
        end
    end
    
    -- Clean up secure inventory caches
    if SecureInventory then
        cleanedCount = cleanedCount + SecureInventory.CleanupInventoryCache()
    end
    
    memoryStats.inventoryCleanups = memoryStats.inventoryCleanups + cleanedCount
    
    local cleanupTime = GetGameTimer() - startTime
    LogMemoryManager(string.format("Inventory cache cleanup completed: %d items cleaned in %dms", 
        cleanedCount, cleanupTime))
end

-- ====================================================================
-- GARBAGE COLLECTION MANAGEMENT
-- ====================================================================

--- Perform comprehensive garbage collection
function MemoryManager.PerformGarbageCollection()
    local startTime = GetGameTimer()
    
    -- Get memory usage before cleanup
    local memBefore = collectgarbage("count")
    
    -- Clean up all systems
    MemoryManager.CleanupOldTransactions()
    MemoryManager.CleanupInventoryCache()
    
    -- Clean up global tables
    local globalTablesToClean = {
        'playersData', 'copsOnDuty', 'robbersActive', 'wantedPlayers',
        'activeCooldowns', 'purchaseHistory', 'k9Engagements', 'activeBounties'
    }
    
    for _, tableName in ipairs(globalTablesToClean) do
        local globalTable = _G[tableName]
        if globalTable then
            DeepCleanTable(globalTable)
        end
    end
    
    -- Force garbage collection
    collectgarbage("collect")
    
    -- Get memory usage after cleanup
    local memAfter = collectgarbage("count")
    local memoryFreed = memBefore - memAfter
    
    memoryStats.totalMemoryFreed = memoryStats.totalMemoryFreed + memoryFreed
    memoryStats.lastCleanupTime = GetGameTimer()
    
    local cleanupTime = GetGameTimer() - startTime
    LogMemoryManager(string.format("Garbage collection completed: %.1fKB freed in %dms", 
        memoryFreed, cleanupTime))
end

-- ====================================================================
-- SCHEDULED CLEANUP SYSTEM
-- ====================================================================

--- Schedule regular cleanup operations
--- @param cleanupType string Type of cleanup
--- @param intervalMs number Interval in milliseconds
function MemoryManager.ScheduleCleanup(cleanupType, intervalMs)
    if activeCleanupTimers[cleanupType] then
        return -- Already scheduled
    end
    
    local function runCleanup()
        if cleanupType == "transactions" then
            MemoryManager.CleanupOldTransactions()
        elseif cleanupType == "inventory" then
            MemoryManager.CleanupInventoryCache()
        elseif cleanupType == "garbage" then
            MemoryManager.PerformGarbageCollection()
        end
        
        -- Reschedule
        activeCleanupTimers[cleanupType] = Citizen.SetTimeout(intervalMs, runCleanup)
    end
    
    activeCleanupTimers[cleanupType] = Citizen.SetTimeout(intervalMs, runCleanup)
    LogMemoryManager(string.format("Scheduled %s cleanup every %dms", cleanupType, intervalMs))
end

--- Stop scheduled cleanup
--- @param cleanupType string Type of cleanup to stop
function MemoryManager.StopScheduledCleanup(cleanupType)
    if activeCleanupTimers[cleanupType] then
        activeCleanupTimers[cleanupType] = nil
        LogMemoryManager(string.format("Stopped scheduled %s cleanup", cleanupType))
    end
end

-- ====================================================================
-- MEMORY STATISTICS
-- ====================================================================

--- Get memory management statistics
--- @return table Memory statistics
function MemoryManager.GetMemoryStats()
    return {
        playerDataCleanups = memoryStats.playerDataCleanups,
        transactionCleanups = memoryStats.transactionCleanups,
        inventoryCleanups = memoryStats.inventoryCleanups,
        totalMemoryFreed = memoryStats.totalMemoryFreed,
        lastCleanupTime = memoryStats.lastCleanupTime,
        currentMemoryUsage = collectgarbage("count"),
        disconnectQueueSize = GetTableSize(disconnectCleanupQueue),
        activeCleanupTimers = GetTableSize(activeCleanupTimers)
    }
end

--- Log memory statistics
function MemoryManager.LogMemoryStats()
    local stats = MemoryManager.GetMemoryStats()
    LogMemoryManager(string.format(
        "Memory Stats - Player cleanups: %d, Transaction cleanups: %d, Inventory cleanups: %d, Memory freed: %.1fKB, Current usage: %.1fKB",
        stats.playerDataCleanups, stats.transactionCleanups, stats.inventoryCleanups,
        stats.totalMemoryFreed, stats.currentMemoryUsage
    ))
end

-- ====================================================================
-- INITIALIZATION
-- ====================================================================

--- Initialize memory management system
function MemoryManager.Initialize()
    LogMemoryManager("Initializing memory management system")
    
    -- Schedule regular cleanups
    MemoryManager.ScheduleCleanup("transactions", 5 * 60 * 1000) -- Every 5 minutes
    MemoryManager.ScheduleCleanup("inventory", 10 * 60 * 1000)   -- Every 10 minutes
    MemoryManager.ScheduleCleanup("garbage", 15 * 60 * 1000)     -- Every 15 minutes
    
    -- Log stats every 30 minutes
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(30 * 60 * 1000) -- 30 minutes
            MemoryManager.LogMemoryStats()
        end
    end)
    
    LogMemoryManager("Memory management system initialized")
end

-- Auto-initialize when loaded
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for other systems to load
    MemoryManager.Initialize()
end)

LogMemoryManager("Memory Manager loaded successfully")