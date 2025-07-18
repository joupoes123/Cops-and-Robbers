-- performance_test.lua
-- Performance testing and benchmarking utilities
-- Version: 1.2.0

-- Only load on server side
if not IsDuplicityVersion() then
    return
end

-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before performance_test.lua")
end

-- Initialize PerformanceTest module
PerformanceTest = PerformanceTest or {}

-- Test results storage
local testResults = {}
local isTestingActive = false

-- ====================================================================
-- MEMORY LEAK TESTING
-- ====================================================================

--- Test memory cleanup on player disconnect simulation
function PerformanceTest.TestMemoryCleanup()
    Log("[PERFORMANCE_TEST] Starting memory cleanup test...", Constants.LOG_LEVELS.INFO)
    
    local initialMemory = collectgarbage("count")
    local testPlayerId = 99999 -- Fake player ID for testing
    
    -- Simulate player data creation
    if PlayerManager then
        -- Create fake player data
        local fakePlayerData = {
            playerId = testPlayerId,
            name = "TestPlayer",
            role = "cop",
            money = 5000,
            inventory = {},
            level = 1,
            xp = 0
        }
        
        -- Simulate data operations
        for i = 1, 100 do
            -- Simulate inventory operations
            if SecureInventory then
                SecureInventory.AddItem(testPlayerId, "test_item_" .. i, 1)
            end
            
            -- Simulate transactions
            if SecureTransactions then
                SecureTransactions.CreateTransaction(testPlayerId, "buy", "test_item_" .. i, 1, 100)
            end
        end
    end
    
    local afterCreationMemory = collectgarbage("count")
    
    -- Test cleanup
    if MemoryManager then
        MemoryManager.CleanupPlayerData(testPlayerId)
        MemoryManager.PerformGarbageCollection()
    end
    
    local afterCleanupMemory = collectgarbage("count")
    
    local results = {
        initialMemory = initialMemory,
        afterCreationMemory = afterCreationMemory,
        afterCleanupMemory = afterCleanupMemory,
        memoryCreated = afterCreationMemory - initialMemory,
        memoryFreed = afterCreationMemory - afterCleanupMemory,
        cleanupEfficiency = ((afterCreationMemory - afterCleanupMemory) / (afterCreationMemory - initialMemory)) * 100
    }
    
    testResults.memoryCleanup = results
    
    Log(string.format("[PERFORMANCE_TEST] Memory cleanup test completed:"), Constants.LOG_LEVELS.INFO)
    Log(string.format("  Memory created: %.1fKB", results.memoryCreated), Constants.LOG_LEVELS.INFO)
    Log(string.format("  Memory freed: %.1fKB", results.memoryFreed), Constants.LOG_LEVELS.INFO)
    Log(string.format("  Cleanup efficiency: %.1f%%", results.cleanupEfficiency), Constants.LOG_LEVELS.INFO)
    
    return results
end

-- ====================================================================
-- DATA PERSISTENCE TESTING
-- ====================================================================

--- Test data persistence performance with batching
function PerformanceTest.TestDataPersistence()
    Log("[PERFORMANCE_TEST] Starting data persistence test...", Constants.LOG_LEVELS.INFO)
    
    if not DataManager then
        Log("[PERFORMANCE_TEST] DataManager not available, skipping test", Constants.LOG_LEVELS.WARN)
        return nil
    end
    
    local testData = {}
    local batchSizes = {1, 5, 10, 20, 50}
    local results = {}
    
    -- Generate test data
    for i = 1, 100 do
        testData[i] = {
            playerId = i,
            name = "TestPlayer" .. i,
            role = i % 2 == 0 and "cop" or "robber",
            money = math.random(1000, 10000),
            inventory = {},
            level = math.random(1, 50),
            xp = math.random(0, 1000)
        }
    end
    
    -- Test different batch sizes
    for _, batchSize in ipairs(batchSizes) do
        local startTime = GetGameTimer()
        local saveCount = 0
        
        -- Save data in batches
        for i = 1, #testData, batchSize do
            local batch = {}
            for j = i, math.min(i + batchSize - 1, #testData) do
                table.insert(batch, testData[j])
            end
            
            -- Simulate batch save
            for _, playerData in ipairs(batch) do
                DataManager.QueueSave(
                    string.format("test_player_%d.json", playerData.playerId),
                    playerData,
                    2 -- Normal priority
                )
                saveCount = saveCount + 1
            end
            
            Citizen.Wait(10) -- Small delay between batches
        end
        
        local endTime = GetGameTimer()
        local totalTime = endTime - startTime
        
        results[batchSize] = {
            batchSize = batchSize,
            totalTime = totalTime,
            saveCount = saveCount,
            averageTimePerSave = totalTime / saveCount,
            savesPerSecond = (saveCount / totalTime) * 1000
        }
        
        Log(string.format("[PERFORMANCE_TEST] Batch size %d: %d saves in %dms (%.1f saves/sec)",
            batchSize, saveCount, totalTime, results[batchSize].savesPerSecond), Constants.LOG_LEVELS.INFO)
    end
    
    testResults.dataPersistence = results
    return results
end

-- ====================================================================
-- CLIENT-SIDE UI TESTING
-- ====================================================================

--- Test UI performance by simulating DOM operations
function PerformanceTest.TestUIPerformance()
    Log("[PERFORMANCE_TEST] Starting UI performance test...", Constants.LOG_LEVELS.INFO)
    
    -- This test needs to be run on client side
    TriggerClientEvent('cnr:performUITest', -1)
    
    -- Wait for results
    Citizen.SetTimeout(5000, function()
        TriggerClientEvent('cnr:getUITestResults', -1)
    end)
end

-- ====================================================================
-- COMPREHENSIVE PERFORMANCE TEST
-- ====================================================================

--- Run all performance tests
function PerformanceTest.RunAllTests()
    if isTestingActive then
        Log("[PERFORMANCE_TEST] Tests already running, please wait...", Constants.LOG_LEVELS.WARN)
        return
    end
    
    isTestingActive = true
    Log("[PERFORMANCE_TEST] Starting comprehensive performance test suite...", Constants.LOG_LEVELS.INFO)
    
    local overallStartTime = GetGameTimer()
    
    -- Run memory cleanup test
    PerformanceTest.TestMemoryCleanup()
    Citizen.Wait(1000)
    
    -- Run data persistence test
    PerformanceTest.TestDataPersistence()
    Citizen.Wait(1000)
    
    -- Run UI performance test
    PerformanceTest.TestUIPerformance()
    Citizen.Wait(1000)
    
    local overallEndTime = GetGameTimer()
    local totalTestTime = overallEndTime - overallStartTime
    
    Log(string.format("[PERFORMANCE_TEST] All tests completed in %dms", totalTestTime), Constants.LOG_LEVELS.INFO)
    
    -- Generate report
    PerformanceTest.GenerateReport()
    
    isTestingActive = false
end

-- ====================================================================
-- REPORTING
-- ====================================================================

--- Generate performance test report
function PerformanceTest.GenerateReport()
    print("[PERFORMANCE_TEST] ==================== PERFORMANCE REPORT ====================")
    
    -- Memory cleanup report
    if testResults.memoryCleanup then
        local mc = testResults.memoryCleanup
        print(string.format("MEMORY CLEANUP:"))
        print(string.format("  Cleanup Efficiency: %.1f%%", mc.cleanupEfficiency))
        print(string.format("  Memory Freed: %.1fKB", mc.memoryFreed))
        
        if mc.cleanupEfficiency < 80 then
            print("  WARNING: Low cleanup efficiency detected!")
        end
    end
    
    -- Data persistence report
    if testResults.dataPersistence then
        print(string.format("DATA PERSISTENCE:"))
        local bestBatch = nil
        local bestPerformance = 0
        
        for batchSize, results in pairs(testResults.dataPersistence) do
            if results.savesPerSecond > bestPerformance then
                bestPerformance = results.savesPerSecond
                bestBatch = batchSize
            end
            print(string.format("  Batch Size %d: %.1f saves/sec", batchSize, results.savesPerSecond))
        end
        
        print(string.format("  OPTIMAL BATCH SIZE: %d (%.1f saves/sec)", bestBatch, bestPerformance))
    end
    
    -- System recommendations
    print(string.format("RECOMMENDATIONS:"))
    
    if testResults.memoryCleanup and testResults.memoryCleanup.cleanupEfficiency < 80 then
        print("  - Consider more aggressive garbage collection")
        print("  - Review memory cleanup procedures")
    end
    
    if testResults.dataPersistence then
        local bestBatch = nil
        local bestPerformance = 0
        for batchSize, results in pairs(testResults.dataPersistence) do
            if results.savesPerSecond > bestPerformance then
                bestPerformance = results.savesPerSecond
                bestBatch = batchSize
            end
        end
        print(string.format("  - Use batch size of %d for optimal data persistence", bestBatch))
    end
    
    print("[PERFORMANCE_TEST] ========================================================")
end

-- ====================================================================
-- ADMIN COMMANDS
-- ====================================================================

--- Register admin commands for performance testing
RegisterCommand('cnr_perftest', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    local testType = args[1] or "all"
    
    if testType == "memory" then
        PerformanceTest.TestMemoryCleanup()
    elseif testType == "data" then
        PerformanceTest.TestDataPersistence()
    elseif testType == "ui" then
        PerformanceTest.TestUIPerformance()
    elseif testType == "all" then
        PerformanceTest.RunAllTests()
    elseif testType == "report" then
        PerformanceTest.GenerateReport()
    else
        print("Usage: cnr_perftest [memory|data|ui|all|report]")
    end
end, false)

-- ====================================================================
-- CLIENT-SIDE EVENT HANDLERS
-- ====================================================================

RegisterNetEvent('cnr:uiTestResults')
AddEventHandler('cnr:uiTestResults', function(results)
    testResults.uiPerformance = results
    print("[PERFORMANCE_TEST] UI test results received:")
    if results.domOperations then
        print(string.format("  DOM Operations: %d", results.domOperations))
        print(string.format("  Average Render Time: %.1fms", results.averageRenderTime))
        print(string.format("  Cache Hit Rate: %.1f%%", results.cacheHitRate))
    end
end)

print("[PERFORMANCE_TEST] Performance testing system loaded. Use 'cnr_perftest' command to run tests.")
