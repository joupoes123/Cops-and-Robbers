-- security_test.lua
-- Security validation testing utilities
-- Version: 1.2.0

-- Only load on server side
if not IsDuplicityVersion() then
    return
end

-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before security_test.lua")
end

if not Validation then
    error("Validation must be loaded before security_test.lua")
end

-- Initialize SecurityTest module
SecurityTest = SecurityTest or {}

-- Test results storage
local testResults = {}

-- ====================================================================
-- VALIDATION TESTING
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
-- ADMIN COMMANDS
-- ====================================================================

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
        print("Usage: cnr_security_test [validation|ratelimit|enhancements|all|report]")
    end
end, false)

print("[SECURITY_TEST] Security testing system loaded. Use 'cnr_security_test' command to run tests.")
