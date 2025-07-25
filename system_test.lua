-- Version: 1.2.0

-- Only load on server side
if not IsDuplicityVersion() then
    return
end

-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before system_test.lua")
end

if not Validation then
    error("Validation must be loaded before system_test.lua")
end

SystemTest = SystemTest or {}
PerformanceTest = PerformanceTest or {}
SecurityTest = SecurityTest or {}

-- Test results storage
local testResults = {}
local isTestingActive = false

-- ====================================================================
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
-- ====================================================================

--- Test input validation with various edge cases
function SecurityTest.TestInputValidation()
    Log("[SECURITY_TEST] Starting input validation tests...", Constants.LOG_LEVELS.INFO)
    
    local results = {
        quantityTests = {},
        moneyTests = {},
        stringTests = {},
        playerTests = {}
    }
    
    -- Test quantity validation
    local quantityTestCases = {
        {input = 1, expected = true, description = "Valid minimum quantity"},
        {input = 999, expected = true, description = "Valid maximum quantity"},
        {input = 0, expected = false, description = "Invalid zero quantity"},
        {input = -1, expected = false, description = "Invalid negative quantity"},
        {input = 1000, expected = false, description = "Invalid excessive quantity"},
        {input = "abc", expected = false, description = "Invalid string quantity"},
        {input = nil, expected = false, description = "Invalid nil quantity"}
    }
    
    for _, testCase in ipairs(quantityTestCases) do
        local valid, validatedQuantity, error = Validation.ValidateQuantity(testCase.input)
        local passed = (valid == testCase.expected)
        
        table.insert(results.quantityTests, {
            input = testCase.input,
            expected = testCase.expected,
            actual = valid,
            passed = passed,
            description = testCase.description,
            error = error
        })
        
        Log(string.format("[SECURITY_TEST] Quantity test: %s - %s", 
            testCase.description, passed and "PASS" or "FAIL"), Constants.LOG_LEVELS.INFO)
    end
    
    -- Test money validation
    local moneyTestCases = {
        {input = 1, expected = true, description = "Valid minimum money"},
        {input = 1000000, expected = true, description = "Valid maximum money"},
        {input = 0, expected = false, description = "Invalid zero money"},
        {input = -1, expected = false, description = "Invalid negative money"},
        {input = 1000001, expected = false, description = "Invalid excessive money"},
        {input = "999", expected = true, description = "Valid string number"},
        {input = "abc", expected = false, description = "Invalid string money"}
    }
    
    for _, testCase in ipairs(moneyTestCases) do
        local valid, validatedAmount, error = Validation.ValidateMoney(testCase.input, false)
        local passed = (valid == testCase.expected)
        
        table.insert(results.moneyTests, {
            input = testCase.input,
            expected = testCase.expected,
            actual = valid,
            passed = passed,
            description = testCase.description,
            error = error
        })
        
        Log(string.format("[SECURITY_TEST] Money test: %s - %s", 
            testCase.description, passed and "PASS" or "FAIL"), Constants.LOG_LEVELS.INFO)
    end
    
    testResults.inputValidation = results
    return results
end

--- Test rate limiting functionality
function SecurityTest.TestRateLimiting()
    Log("[SECURITY_TEST] Starting rate limiting tests...", Constants.LOG_LEVELS.INFO)
    
    local testPlayerId = 99999 -- Fake player ID for testing
    local results = {
        inventoryRateLimit = {},
        purchaseRateLimit = {},
        eventRateLimit = {}
    }
    
    -- Test inventory rate limiting
    local inventoryLimit = Constants.VALIDATION.MAX_INVENTORY_OPERATIONS_PER_SECOND
    local allowedCount = 0
    local blockedCount = 0
    
    for i = 1, inventoryLimit + 5 do
        local allowed = Validation.CheckRateLimit(testPlayerId, "inventoryOps", 
            inventoryLimit, Constants.TIME_MS.SECOND)
        
        if allowed then
            allowedCount = allowedCount + 1
        else
            blockedCount = blockedCount + 1
        end
    end
    
    results.inventoryRateLimit = {
        limit = inventoryLimit,
        allowedCount = allowedCount,
        blockedCount = blockedCount,
        passed = (allowedCount == inventoryLimit and blockedCount == 5)
    }
    
    Log(string.format("[SECURITY_TEST] Inventory rate limit: %d allowed, %d blocked - %s",
        allowedCount, blockedCount, results.inventoryRateLimit.passed and "PASS" or "FAIL"), Constants.LOG_LEVELS.INFO)
    
    -- Clean up test data
    Validation.CleanupRateLimit(testPlayerId)
    
    testResults.rateLimiting = results
    return results
end

--- Test security enhancements if available
function SecurityTest.TestSecurityEnhancements()
    Log("[SECURITY_TEST] Starting security enhancements tests...", Constants.LOG_LEVELS.INFO)
    
    if not SecurityEnhancements then
        Log("[SECURITY_TEST] SecurityEnhancements module not available, skipping tests", Constants.LOG_LEVELS.WARN)
        return nil
    end
    
    local results = {
        secureAddItem = {},
        secureMoneyTransaction = {},
        suspiciousActivity = {}
    }
    
    local testPlayerId = 99999
    
    -- Test secure money transaction
    local moneyTestCases = {
        {amount = 100, operation = "add", expected = true},
        {amount = -50, operation = "remove", expected = true},
        {amount = 2000000, operation = "add", expected = false}, -- Exceeds limit
        {amount = "abc", operation = "add", expected = false}
    }
    
    for _, testCase in ipairs(moneyTestCases) do
        local valid, validatedAmount, error = SecurityEnhancements.SecureMoneyTransaction(
            testPlayerId, testCase.amount, testCase.operation)
        
        local passed = (valid == testCase.expected)
        
        table.insert(results.secureMoneyTransaction, {
            amount = testCase.amount,
            operation = testCase.operation,
            expected = testCase.expected,
            actual = valid,
            passed = passed,
            error = error
        })
        
        Log(string.format("[SECURITY_TEST] Secure money transaction (%s %s): %s",
            testCase.operation, tostring(testCase.amount), passed and "PASS" or "FAIL"), Constants.LOG_LEVELS.INFO)
    end
    
    -- Test security statistics
    local stats = SecurityEnhancements.GetSecurityStats()
    results.securityStats = {
        available = true,
        stats = stats
    }
    
    Log(string.format("[SECURITY_TEST] Security stats: %d validation failures, %d suspicious activities",
        stats.validationFailures, stats.suspiciousActivity), Constants.LOG_LEVELS.INFO)
    
    testResults.securityEnhancements = results
    return results
end

--- Run all security tests
function SecurityTest.RunAllTests()
    Log("[SECURITY_TEST] Starting comprehensive security test suite...", Constants.LOG_LEVELS.INFO)
    
    local overallStartTime = GetGameTimer()
    
    -- Run input validation tests
    SecurityTest.TestInputValidation()
    Citizen.Wait(500)
    
    -- Run rate limiting tests
    SecurityTest.TestRateLimiting()
    Citizen.Wait(500)
    
    -- Run security enhancements tests
    SecurityTest.TestSecurityEnhancements()
    Citizen.Wait(500)
    
    local overallEndTime = GetGameTimer()
    local totalTestTime = overallEndTime - overallStartTime
    
    Log(string.format("[SECURITY_TEST] All security tests completed in %dms", totalTestTime), Constants.LOG_LEVELS.INFO)
    
    -- Generate report
    SecurityTest.GenerateReport()
end

--- Generate security test report
function SecurityTest.GenerateReport()
    print("[SECURITY_TEST] ==================== SECURITY TEST REPORT ====================")
    
    -- Input validation report
    if testResults.inputValidation then
        local iv = testResults.inputValidation
        local quantityPassed = 0
        local moneyPassed = 0
        
        for _, test in ipairs(iv.quantityTests) do
            if test.passed then quantityPassed = quantityPassed + 1 end
        end
        
        for _, test in ipairs(iv.moneyTests) do
            if test.passed then moneyPassed = moneyPassed + 1 end
        end
        
        print(string.format("INPUT VALIDATION:"))
        print(string.format("  Quantity Tests: %d/%d passed", quantityPassed, #iv.quantityTests))
        print(string.format("  Money Tests: %d/%d passed", moneyPassed, #iv.moneyTests))
    end
    
    -- Rate limiting report
    if testResults.rateLimiting then
        local rl = testResults.rateLimiting
        print(string.format("RATE LIMITING:"))
        print(string.format("  Inventory Rate Limit: %s", rl.inventoryRateLimit.passed and "PASS" or "FAIL"))
    end
    
    -- Security enhancements report
    if testResults.securityEnhancements then
        local se = testResults.securityEnhancements
        local moneyPassed = 0
        
        for _, test in ipairs(se.secureMoneyTransaction) do
            if test.passed then moneyPassed = moneyPassed + 1 end
        end
        
        print(string.format("SECURITY ENHANCEMENTS:"))
        print(string.format("  Secure Money Transactions: %d/%d passed", moneyPassed, #se.secureMoneyTransaction))
        
        if se.securityStats and se.securityStats.available then
            print(string.format("  Security Monitoring: ACTIVE"))
        end
    end
    
    print("[SECURITY_TEST] ========================================================")
end

-- ====================================================================
-- ====================================================================

function SystemTest.RunAllTests()
    Log("[SYSTEM_TEST] Starting comprehensive system test suite...", Constants.LOG_LEVELS.INFO)
    
    local overallStartTime = GetGameTimer()
    
    Log("[SYSTEM_TEST] Running performance tests...", Constants.LOG_LEVELS.INFO)
    PerformanceTest.RunAllTests()
    Citizen.Wait(2000)
    
    Log("[SYSTEM_TEST] Running security tests...", Constants.LOG_LEVELS.INFO)
    SecurityTest.RunAllTests()
    Citizen.Wait(1000)
    
    local overallEndTime = GetGameTimer()
    local totalTestTime = overallEndTime - overallStartTime
    
    Log(string.format("[SYSTEM_TEST] All system tests completed in %dms", totalTestTime), Constants.LOG_LEVELS.INFO)
    
    SystemTest.GenerateUnifiedReport()
end

function SystemTest.GenerateUnifiedReport()
    print("[SYSTEM_TEST] ==================== UNIFIED SYSTEM TEST REPORT ====================")
    
    PerformanceTest.GenerateReport()
    
    print("")
    
    SecurityTest.GenerateReport()
    
    print("[SYSTEM_TEST] ==================== SYSTEM HEALTH ASSESSMENT ====================")
    
    local healthScore = 100
    local issues = {}
    
    if testResults.memoryCleanup and testResults.memoryCleanup.cleanupEfficiency < 80 then
        healthScore = healthScore - 20
        table.insert(issues, "Low memory cleanup efficiency")
    end
    
    if testResults.inputValidation then
        local totalTests = #testResults.inputValidation.quantityTests + #testResults.inputValidation.moneyTests
        local passedTests = 0
        
        for _, test in ipairs(testResults.inputValidation.quantityTests) do
            if test.passed then passedTests = passedTests + 1 end
        end
        for _, test in ipairs(testResults.inputValidation.moneyTests) do
            if test.passed then passedTests = passedTests + 1 end
        end
        
        local validationScore = (passedTests / totalTests) * 100
        if validationScore < 90 then
            healthScore = healthScore - (100 - validationScore)
            table.insert(issues, string.format("Validation tests failing (%.1f%% pass rate)", validationScore))
        end
    end
    
    if testResults.rateLimiting and not testResults.rateLimiting.inventoryRateLimit.passed then
        healthScore = healthScore - 15
        table.insert(issues, "Rate limiting not functioning correctly")
    end
    
    print(string.format("OVERALL SYSTEM HEALTH: %.1f%%", healthScore))
    
    if #issues > 0 then
        print("CRITICAL ISSUES DETECTED:")
        for _, issue in ipairs(issues) do
            print(string.format("  - %s", issue))
        end
    else
        print("NO CRITICAL ISSUES DETECTED")
    end
    
    print("[SYSTEM_TEST] ========================================================================")
end

function SystemTest.GetTestResults()
    return testResults
end

function SystemTest.ClearTestResults()
    testResults = {}
    Log("[SYSTEM_TEST] Test results cleared", Constants.LOG_LEVELS.INFO)
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
        Log("Usage: cnr_perftest [memory|data|ui|all|report]", "info", "CNR_ADMIN")
    end
end, false)

--- Register admin commands for security testing
RegisterCommand('cnr_security_test', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    local testType = args[1] or "all"
    
    if testType == "validation" then
        SecurityTest.TestInputValidation()
    elseif testType == "ratelimit" then
        SecurityTest.TestRateLimiting()
    elseif testType == "enhancements" then
        SecurityTest.TestSecurityEnhancements()
    elseif testType == "all" then
        SecurityTest.RunAllTests()
    elseif testType == "report" then
        SecurityTest.GenerateReport()
    else
        Log("Usage: cnr_security_test [validation|ratelimit|enhancements|all|report]", "info", "CNR_ADMIN")
    end
end, false)

RegisterCommand('cnr_system_test', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    local testType = args[1] or "all"
    
    if testType == "performance" then
        PerformanceTest.RunAllTests()
    elseif testType == "security" then
        SecurityTest.RunAllTests()
    elseif testType == "all" then
        SystemTest.RunAllTests()
    elseif testType == "report" then
        SystemTest.GenerateUnifiedReport()
    elseif testType == "clear" then
        SystemTest.ClearTestResults()
    else
        Log("Usage: cnr_system_test [performance|security|all|report|clear]", "info", "CNR_ADMIN")
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

Log("Unified system testing loaded. Commands: cnr_perftest, cnr_security_test, cnr_system_test", "info", "SYSTEM_TEST")
