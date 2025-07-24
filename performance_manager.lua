
-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before performance_manager.lua")
end

PerformanceManager = PerformanceManager or {}
MemoryManager = MemoryManager or {}
PerformanceOptimizer = PerformanceOptimizer or {}

-- ====================================================================
-- ====================================================================

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

--- Log memory management operations
--- @param message string Log message
--- @param level string Log level
local function LogMemoryManager(message, level)
    level = level or Constants.LOG_LEVELS.INFO
    if level == Constants.LOG_LEVELS.ERROR or level == Constants.LOG_LEVELS.WARN then
        if Log then
            Log(string.format("[CNR_MEMORY_MANAGER] [%s] %s", string.upper(level), message), level)
        else
            Log(string.format("[%s] %s", string.upper(level), message), level, "CNR_MEMORY_MANAGER")
        end
    end
end

--- Get table size safely
--- @param tbl table Table to measure
--- @return number Size of table
function GetTableSize(tbl)
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

--- Initialize memory management system
function MemoryManager.Initialize()
    LogMemoryManager("Initializing memory management system")
    
    -- Schedule regular cleanups
    MemoryManager.ScheduleCleanup("transactions", 5 * 60 * 1000) -- Every 5 minutes
    MemoryManager.ScheduleCleanup("inventory", 10 * 60 * 1000)   -- Every 10 minutes
    MemoryManager.ScheduleCleanup("garbage", 15 * 60 * 1000)     -- Every 15 minutes
    
    -- Log stats every 30 minutes
    PerformanceOptimizer.CreateOptimizedLoop(function()
        MemoryManager.LogMemoryStats()
        return true
    end, 30 * 60 * 1000, 60 * 60 * 1000, 5)
    
    LogMemoryManager("Memory management system initialized")
end

-- ====================================================================
-- ====================================================================

-- Performance monitoring data
local performanceMetrics = {
    frameTime = 0,
    memoryUsage = 0,
    activeThreads = 0,
    networkEvents = 0,
    lastUpdate = 0
}

-- Optimized loop management
local optimizedLoops = {}
local loopCounter = 0

-- Event batching system
local eventBatches = {}
local batchTimers = {}

--- Adjust loop interval based on performance metrics
--- @param loopData table Loop data structure
--- @param lastExecutionTime number Last execution time in milliseconds
local function AdjustLoopInterval(loopData, lastExecutionTime)
    -- If execution time is high, increase interval
    if lastExecutionTime > Constants.PERFORMANCE.MAX_EXECUTION_TIME_MS then
        loopData.currentInterval = math.min(loopData.currentInterval * 1.2, loopData.maxInterval)
    -- If execution time is low and we're not at base interval, decrease it
    elseif lastExecutionTime < Constants.PERFORMANCE.MAX_EXECUTION_TIME_MS * 0.5 and 
           loopData.currentInterval > loopData.baseInterval then
        loopData.currentInterval = math.max(loopData.currentInterval * 0.9, loopData.baseInterval)
    end
    
    -- Priority-based adjustments
    if loopData.priority <= 2 then
        -- High priority loops get preference
        loopData.currentInterval = math.max(loopData.currentInterval * 0.8, loopData.baseInterval)
    elseif loopData.priority >= 4 then
        -- Low priority loops get throttled more aggressively
        loopData.currentInterval = math.min(loopData.currentInterval * 1.5, loopData.maxInterval)
    end
end

--- Create an optimized loop that automatically adjusts its interval based on performance
--- @param callback function Function to execute
--- @param baseInterval number Base interval in milliseconds
--- @param maxInterval number Maximum interval in milliseconds
--- @param priority number Priority level (1-5, 1 being highest)
--- @return number Loop ID for management
function PerformanceOptimizer.CreateOptimizedLoop(callback, baseInterval, maxInterval, priority)
    loopCounter = loopCounter + 1
    priority = priority or 3
    maxInterval = maxInterval or baseInterval * 5
    
    local loopData = {
        id = loopCounter,
        callback = callback,
        baseInterval = baseInterval,
        maxInterval = maxInterval,
        currentInterval = baseInterval,
        priority = priority,
        lastExecution = 0,
        executionCount = 0,
        totalExecutionTime = 0,
        averageExecutionTime = 0,
        active = true
    }
    
    optimizedLoops[loopCounter] = loopData
    
    -- Start the loop thread
    Citizen.CreateThread(function()
        while loopData.active do
            local startTime = GetGameTimer()
            
            -- Execute callback with error handling
            local success, error = pcall(callback)
            if not success then
                Log(string.format("[CNR_PERFORMANCE] Loop %d error: %s", loopData.id, tostring(error)), Constants.LOG_LEVELS.ERROR)
            end
            
            -- Update performance metrics
            local executionTime = GetGameTimer() - startTime
            loopData.executionCount = loopData.executionCount + 1
            loopData.totalExecutionTime = loopData.totalExecutionTime + executionTime
            loopData.averageExecutionTime = loopData.totalExecutionTime / loopData.executionCount
            loopData.lastExecution = startTime
            
            -- Adjust interval based on performance
            AdjustLoopInterval(loopData, executionTime)
            
            Citizen.Wait(loopData.currentInterval)
        end
    end)
    
    Log(string.format("[CNR_PERFORMANCE] Created optimized loop %d (base: %dms, max: %dms, priority: %d)", 
        loopCounter, baseInterval, maxInterval, priority), Constants.LOG_LEVELS.INFO)
    
    return loopCounter
end

--- Stop an optimized loop
--- @param loopId number Loop ID to stop
function PerformanceOptimizer.StopOptimizedLoop(loopId)
    if optimizedLoops[loopId] then
        optimizedLoops[loopId].active = false
        optimizedLoops[loopId] = nil
        Log(string.format("[CNR_PERFORMANCE] Stopped optimized loop %d", loopId), Constants.LOG_LEVELS.INFO)
    end
end

--- Batch events to reduce network overhead
--- @param eventName string Event name
--- @param playerId number Player ID (or -1 for all players)
--- @param data any Event data
--- @param batchInterval number Batching interval in milliseconds
function PerformanceOptimizer.BatchEvent(eventName, playerId, data, batchInterval)
    batchInterval = batchInterval or 100 -- Default 100ms batching
    
    local batchKey = string.format("%s_%s", eventName, tostring(playerId))
    
    -- Initialize batch if it doesn't exist
    if not eventBatches[batchKey] then
        eventBatches[batchKey] = {
            eventName = eventName,
            playerId = playerId,
            data = {},
            count = 0
        }
    end
    
    -- Add data to batch
    table.insert(eventBatches[batchKey].data, data)
    eventBatches[batchKey].count = eventBatches[batchKey].count + 1
    
    -- Set timer if not already set
    if not batchTimers[batchKey] then
        batchTimers[batchKey] = Citizen.SetTimeout(batchInterval, function()
            PerformanceOptimizer.FlushEventBatch(batchKey)
        end)
    end
end

--- Flush a specific event batch
--- @param batchKey string Batch key
function PerformanceOptimizer.FlushEventBatch(batchKey)
    local batch = eventBatches[batchKey]
    if not batch or batch.count == 0 then
        return
    end
    
    -- Send batched event
    if batch.playerId == -1 then
        -- Send to all players
        TriggerClientEvent(batch.eventName, -1, batch.data)
    else
        -- Send to specific player
        TriggerClientEvent(batch.eventName, batch.playerId, batch.data)
    end
    
    -- Clean up
    eventBatches[batchKey] = nil
    batchTimers[batchKey] = nil
    
    Log(string.format("[CNR_PERFORMANCE] Flushed batch %s with %d events", batchKey, batch.count), Constants.LOG_LEVELS.DEBUG)
end

--- Flush all event batches immediately
function PerformanceOptimizer.FlushAllBatches()
    for batchKey, _ in pairs(eventBatches) do
        PerformanceOptimizer.FlushEventBatch(batchKey)
    end
end

--- Optimize table memory usage by removing nil values and compacting
--- @param tbl table Table to optimize
--- @return table Optimized table
function PerformanceOptimizer.OptimizeTable(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    
    local optimized = {}
    for k, v in pairs(tbl) do
        if v ~= nil then
            if type(v) == "table" then
                optimized[k] = PerformanceOptimizer.OptimizeTable(v)
            else
                optimized[k] = v
            end
        end
    end
    
    return optimized
end

--- Clean up unused references and force garbage collection
function PerformanceOptimizer.CleanupMemory()
    -- Clean up optimized loops that are no longer active
    for loopId, loopData in pairs(optimizedLoops) do
        if not loopData.active then
            optimizedLoops[loopId] = nil
        end
    end
    
    -- Clean up old event batches
    local currentTime = GetGameTimer()
    for batchKey, timer in pairs(batchTimers) do
        if currentTime - timer > 5000 then -- 5 second timeout
            eventBatches[batchKey] = nil
            batchTimers[batchKey] = nil
        end
    end
    
    -- Force garbage collection
    collectgarbage("collect")
    
    Log("[CNR_PERFORMANCE] Memory cleanup completed", Constants.LOG_LEVELS.DEBUG)
end

--- Update performance metrics
local function UpdatePerformanceMetrics()
    performanceMetrics.lastUpdate = GetGameTimer()
    performanceMetrics.activeThreads = GetTableSize(optimizedLoops)
    
    -- Calculate memory usage (approximation)
    local memBefore = collectgarbage("count")
    collectgarbage("collect")
    local memAfter = collectgarbage("count")
    performanceMetrics.memoryUsage = memAfter
    
    -- Restore memory state
    collectgarbage("restart")
end

--- Get current performance metrics
--- @return table Performance metrics
function PerformanceOptimizer.GetMetrics()
    UpdatePerformanceMetrics()
    return {
        frameTime = performanceMetrics.frameTime,
        memoryUsage = performanceMetrics.memoryUsage,
        activeThreads = performanceMetrics.activeThreads,
        networkEvents = performanceMetrics.networkEvents,
        lastUpdate = performanceMetrics.lastUpdate,
        optimizedLoops = GetTableSize(optimizedLoops),
        eventBatches = GetTableSize(eventBatches)
    }
end

--- Log performance statistics
function PerformanceOptimizer.LogStats()
    local metrics = PerformanceOptimizer.GetMetrics()
    Log(string.format("[CNR_PERFORMANCE] Stats - Memory: %.1fKB, Threads: %d, Loops: %d, Batches: %d",
        metrics.memoryUsage, metrics.activeThreads, metrics.optimizedLoops, metrics.eventBatches), Constants.LOG_LEVELS.DEBUG)
    
    -- Log individual loop performance
    for loopId, loopData in pairs(optimizedLoops) do
        if loopData.executionCount > 0 then
            Log(string.format("[CNR_PERFORMANCE] Loop %d - Avg: %.1fms, Count: %d, Interval: %dms",
                loopId, loopData.averageExecutionTime, loopData.executionCount, loopData.currentInterval), Constants.LOG_LEVELS.DEBUG)
        end
    end
end

--- Check for performance warnings
function PerformanceOptimizer.CheckPerformanceWarnings()
    local metrics = PerformanceOptimizer.GetMetrics()
    
    -- Memory warning
    if metrics.memoryUsage > Constants.PERFORMANCE.MEMORY_WARNING_THRESHOLD_MB * 1024 then
        Log(string.format("[CNR_PERFORMANCE] WARNING: High memory usage: %.1fMB", 
            metrics.memoryUsage / 1024), Constants.LOG_LEVELS.WARN)
        PerformanceOptimizer.CleanupMemory()
    end
    
    -- Loop performance warnings
    for loopId, loopData in pairs(optimizedLoops) do
        if loopData.averageExecutionTime > Constants.PERFORMANCE.MAX_EXECUTION_TIME_MS then
            Log(string.format("[CNR_PERFORMANCE] WARNING: Loop %d slow execution: %.1fms average",
                loopId, loopData.averageExecutionTime), Constants.LOG_LEVELS.WARN)
        end
    end
end

--- Optimized player iteration with early exit and batching
--- @param callback function Function to call for each player
--- @param batchSize number Number of players to process per frame
function PerformanceOptimizer.ForEachPlayerOptimized(callback, batchSize)
    batchSize = batchSize or 10
    local players = GetPlayers()
    local currentBatch = 0
    
    Citizen.CreateThread(function()
        for i, playerId in ipairs(players) do
            -- Validate player is still online
            if GetPlayerName(playerId) then
                local success, error = pcall(callback, tonumber(playerId))
                if not success then
                    print(string.format("[CNR_PERFORMANCE] Player iteration error for %s: %s", 
                        playerId, tostring(error)))
                end
            end
            
            currentBatch = currentBatch + 1
            
            -- Yield every batchSize players to prevent frame drops
            if currentBatch >= batchSize then
                currentBatch = 0
                Citizen.Wait(0)
            end
        end
    end)
end

--- Optimized distance checking with caching
local distanceCache = {}
local distanceCacheTime = {}

function PerformanceOptimizer.GetDistanceCached(pos1, pos2, cacheTime)
    cacheTime = cacheTime or 1000 -- 1 second cache by default
    
    local cacheKey = string.format("%.1f_%.1f_%.1f_%.1f_%.1f_%.1f", 
        pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z)
    
    local currentTime = GetGameTimer()
    
    -- Check cache
    if distanceCache[cacheKey] and 
       distanceCacheTime[cacheKey] and 
       (currentTime - distanceCacheTime[cacheKey]) < cacheTime then
        return distanceCache[cacheKey]
    end
    
    -- Calculate distance
    local distance = #(pos1 - pos2)
    
    -- Cache result
    distanceCache[cacheKey] = distance
    distanceCacheTime[cacheKey] = currentTime
    
    return distance
end

--- Clean distance cache periodically
local function CleanDistanceCache()
    local currentTime = GetGameTimer()
    local cleanupThreshold = 5000 -- 5 seconds
    
    for cacheKey, cacheTime in pairs(distanceCacheTime) do
        if (currentTime - cacheTime) > cleanupThreshold then
            distanceCache[cacheKey] = nil
            distanceCacheTime[cacheKey] = nil
        end
    end
end

--- Initialize performance optimizer
function PerformanceOptimizer.Initialize()
    Log("Performance Optimizer initialized", "info", "CNR_PERFORMANCE")
    
    -- Create monitoring loop
    PerformanceOptimizer.CreateOptimizedLoop(function()
        PerformanceOptimizer.CheckPerformanceWarnings()
    end, 30000, 60000, 4) -- Low priority, 30s base interval
    
    -- Create cleanup loop
    PerformanceOptimizer.CreateOptimizedLoop(function()
        PerformanceOptimizer.CleanupMemory()
        CleanDistanceCache()
    end, 60000, 120000, 5) -- Lowest priority, 1 minute base interval
    
    -- Create stats logging loop
    PerformanceOptimizer.CreateOptimizedLoop(function()
        PerformanceOptimizer.LogStats()
    end, 300000, 600000, 5) -- Lowest priority, 5 minute base interval
end

--- Cleanup on resource stop
function PerformanceOptimizer.Cleanup()
    Log("Cleaning up performance optimizer...", "info", "CNR_PERFORMANCE")
    
    -- Stop all optimized loops
    for loopId, _ in pairs(optimizedLoops) do
        PerformanceOptimizer.StopOptimizedLoop(loopId)
    end
    
    -- Flush all event batches
    PerformanceOptimizer.FlushAllBatches()
    
    -- Final memory cleanup
    PerformanceOptimizer.CleanupMemory()
    
    Log("Performance optimizer cleanup completed", "info", "CNR_PERFORMANCE")
end

-- ====================================================================
-- ====================================================================

function PerformanceManager.Initialize()
    Log("Initializing unified performance management system...", "info", "CNR_PERFORMANCE_MANAGER")
    
    MemoryManager.Initialize()
    
    PerformanceOptimizer.Initialize()
    
    Log("Unified performance management system initialized", "info", "CNR_PERFORMANCE_MANAGER")
end

function PerformanceManager.Cleanup()
    Log("Cleaning up unified performance management system...", "info", "CNR_PERFORMANCE_MANAGER")
    
    PerformanceOptimizer.Cleanup()
    
    for cleanupType, _ in pairs(activeCleanupTimers) do
        MemoryManager.StopScheduledCleanup(cleanupType)
    end
    
    Log("Unified performance management system cleanup completed", "info", "CNR_PERFORMANCE_MANAGER")
end

function PerformanceManager.GetCombinedStats()
    local memoryStats = MemoryManager.GetMemoryStats()
    local performanceStats = PerformanceOptimizer.GetMetrics()
    
    return {
        memory = memoryStats,
        performance = performanceStats,
        combined = {
            totalMemoryUsage = performanceStats.memoryUsage,
            totalActiveThreads = performanceStats.activeThreads,
            totalCleanupOperations = memoryStats.playerDataCleanups + memoryStats.transactionCleanups + memoryStats.inventoryCleanups
        }
    }
end

-- Auto-initialize when loaded
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for other systems to load
    PerformanceManager.Initialize()
end)

Log("[CNR_PERFORMANCE_MANAGER] Performance Manager loaded successfully (combines Memory Manager and Performance Optimizer)", Constants.LOG_LEVELS.INFO)
