-- security_enhancements.lua
-- Additional security enhancements and validation wrappers for legacy functions
-- Version: 1.2.0

-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before security_enhancements.lua")
end

if not Validation then
    error("Validation must be loaded before security_enhancements.lua")
end

-- Initialize SecurityEnhancements module
SecurityEnhancements = SecurityEnhancements or {}

-- Security monitoring
local securityStats = {
    blockedAttempts = 0,
    validationFailures = 0,
    suspiciousActivity = 0,
    lastResetTime = os.time()
}

-- Suspicious activity tracking
local suspiciousPlayers = {}

-- ====================================================================
-- ENHANCED VALIDATION WRAPPERS
-- ====================================================================

--- Enhanced wrapper for legacy AddItem function with comprehensive validation
--- @param pData table Player data
--- @param itemId string Item ID
--- @param quantity any Quantity to add
--- @param playerId number Player ID
--- @return boolean, string Success status and error message
function SecurityEnhancements.SecureAddItem(pData, itemId, quantity, playerId)
    -- Validate all inputs comprehensively
    local validPlayer, playerError = Validation.ValidatePlayer(playerId)
    if not validPlayer then
        SecurityEnhancements.LogSecurityEvent(playerId, "INVALID_PLAYER", playerError)
        return false, playerError
    end
    
    local validItem, itemConfig, itemError = Validation.ValidateItem(itemId)
    if not validItem then
        SecurityEnhancements.LogSecurityEvent(playerId, "INVALID_ITEM", itemError)
        return false, itemError
    end
    
    local validQty, validatedQuantity, qtyError = Validation.ValidateQuantity(quantity)
    if not validQty then
        SecurityEnhancements.LogSecurityEvent(playerId, "INVALID_QUANTITY", qtyError)
        return false, qtyError
    end
    
    -- Check for suspicious quantities
    if validatedQuantity > Constants.VALIDATION.MAX_ITEM_QUANTITY * 0.8 then
        SecurityEnhancements.FlagSuspiciousActivity(playerId, "HIGH_QUANTITY_REQUEST", 
            string.format("Requested %d of item %s", validatedQuantity, itemId))
    end
    
    -- Validate inventory space
    local validSpace, spaceError = Validation.ValidateInventorySpace(pData, validatedQuantity)
    if not validSpace then
        return false, spaceError
    end
    
    -- Rate limit inventory operations
    if not Validation.CheckRateLimit(playerId, "inventoryOps", 
        Constants.VALIDATION.MAX_INVENTORY_OPERATIONS_PER_SECOND, 
        Constants.TIME_MS.SECOND) then
        SecurityEnhancements.LogSecurityEvent(playerId, "RATE_LIMIT_EXCEEDED", "Inventory operations")
        return false, Constants.ERROR_MESSAGES.RATE_LIMITED
    end
    
    -- Call the original AddItem function with validated parameters
    return AddItem(pData, itemId, validatedQuantity, playerId)
end

--- Enhanced wrapper for money transactions with comprehensive validation
--- @param playerId number Player ID
--- @param amount any Amount to validate
--- @param operation string Operation type (add, remove, set)
--- @return boolean, number, string Success status, validated amount, and error message
function SecurityEnhancements.SecureMoneyTransaction(playerId, amount, operation)
    local validPlayer, playerError = Validation.ValidatePlayer(playerId)
    if not validPlayer then
        SecurityEnhancements.LogSecurityEvent(playerId, "INVALID_PLAYER", playerError)
        return false, 0, playerError
    end
    
    local allowNegative = (operation == "remove")
    local validMoney, validatedAmount, moneyError = Validation.ValidateMoney(amount, allowNegative)
    if not validMoney then
        SecurityEnhancements.LogSecurityEvent(playerId, "INVALID_MONEY", moneyError)
        return false, 0, moneyError
    end
    
    -- Check for suspicious amounts
    if validatedAmount > Constants.VALIDATION.MAX_MONEY_TRANSACTION * 0.5 then
        SecurityEnhancements.FlagSuspiciousActivity(playerId, "HIGH_MONEY_TRANSACTION", 
            string.format("Operation: %s, Amount: $%d", operation, validatedAmount))
    end
    
    -- Rate limit money transactions
    if not Validation.CheckRateLimit(playerId, "purchases", 
        Constants.VALIDATION.MAX_PURCHASES_PER_MINUTE, 
        Constants.TIME_MS.MINUTE) then
        SecurityEnhancements.LogSecurityEvent(playerId, "RATE_LIMIT_EXCEEDED", "Money transactions")
        return false, 0, Constants.ERROR_MESSAGES.RATE_LIMITED
    end
    
    return true, validatedAmount, nil
end

--- Enhanced admin command validation
--- @param adminId number Admin player ID
--- @param targetId number Target player ID
--- @param amount any Amount for admin command
--- @param command string Command name
--- @return boolean, number, string Success status, validated amount, and error message
function SecurityEnhancements.SecureAdminCommand(adminId, targetId, amount, command)
    -- Validate admin permissions
    local validAdmin, adminError = Validation.ValidateAdminPermission(adminId)
    if not validAdmin then
        SecurityEnhancements.LogSecurityEvent(adminId, "UNAUTHORIZED_ADMIN", adminError)
        return false, 0, adminError
    end
    
    -- Validate target player
    local validTarget, targetError = Validation.ValidatePlayer(targetId)
    if not validTarget then
        return false, 0, targetError
    end
    
    -- Validate amount
    local validMoney, validatedAmount, moneyError = Validation.ValidateMoney(amount, false)
    if not validMoney then
        return false, 0, moneyError
    end
    
    -- Log admin action for audit trail
    SecurityEnhancements.LogAdminAction(adminId, targetId, command, validatedAmount)
    
    return true, validatedAmount, nil
end

-- ====================================================================
-- SECURITY MONITORING
-- ====================================================================

--- Log security events for monitoring and analysis
--- @param playerId number Player ID
--- @param eventType string Type of security event
--- @param details string Event details
function SecurityEnhancements.LogSecurityEvent(playerId, eventType, details)
    local playerName = GetPlayerName(playerId) or "Unknown"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    Log(string.format("[CNR_SECURITY] [%s] Player %s (%d) - %s: %s", 
        timestamp, playerName, playerId, eventType, details), Constants.LOG_LEVELS.WARN)
    
    securityStats.validationFailures = securityStats.validationFailures + 1
    
    -- Track repeated failures
    if not suspiciousPlayers[playerId] then
        suspiciousPlayers[playerId] = {
            failureCount = 0,
            lastFailure = 0,
            events = {}
        }
    end
    
    suspiciousPlayers[playerId].failureCount = suspiciousPlayers[playerId].failureCount + 1
    suspiciousPlayers[playerId].lastFailure = GetGameTimer()
    table.insert(suspiciousPlayers[playerId].events, {
        type = eventType,
        details = details,
        timestamp = timestamp
    })
    
    -- Auto-kick for excessive failures
    if suspiciousPlayers[playerId].failureCount > 10 then
        SecurityEnhancements.HandleSuspiciousPlayer(playerId, "EXCESSIVE_VALIDATION_FAILURES")
    end
end

--- Flag suspicious activity for review
--- @param playerId number Player ID
--- @param activityType string Type of suspicious activity
--- @param details string Activity details
function SecurityEnhancements.FlagSuspiciousActivity(playerId, activityType, details)
    local playerName = GetPlayerName(playerId) or "Unknown"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    Log(string.format("[CNR_SUSPICIOUS] [%s] Player %s (%d) - %s: %s", 
        timestamp, playerName, playerId, activityType, details), Constants.LOG_LEVELS.WARN)
    
    securityStats.suspiciousActivity = securityStats.suspiciousActivity + 1
    
    -- Initialize tracking if needed
    if not suspiciousPlayers[playerId] then
        suspiciousPlayers[playerId] = {
            failureCount = 0,
            lastFailure = 0,
            events = {}
        }
    end
    
    table.insert(suspiciousPlayers[playerId].events, {
        type = "SUSPICIOUS_" .. activityType,
        details = details,
        timestamp = timestamp
    })
end

--- Log admin actions for audit trail
--- @param adminId number Admin player ID
--- @param targetId number Target player ID
--- @param command string Command executed
--- @param amount number Amount involved
function SecurityEnhancements.LogAdminAction(adminId, targetId, command, amount)
    local adminName = GetPlayerName(adminId) or "Unknown"
    local targetName = GetPlayerName(targetId) or "Unknown"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    Log(string.format("[CNR_ADMIN_AUDIT] [%s] Admin %s (%d) executed %s on %s (%d) with amount: %d", 
        timestamp, adminName, adminId, command, targetName, targetId, amount), Constants.LOG_LEVELS.INFO)
end

--- Handle suspicious players
--- @param playerId number Player ID
--- @param reason string Reason for action
function SecurityEnhancements.HandleSuspiciousPlayer(playerId, reason)
    local playerName = GetPlayerName(playerId) or "Unknown"
    
    Log(string.format("[CNR_SECURITY_ACTION] Kicking player %s (%d) for: %s", 
        playerName, playerId, reason), Constants.LOG_LEVELS.ERROR)
    
    -- Kick the player
    DropPlayer(playerId, string.format("Kicked for security violation: %s", reason))
    
    securityStats.blockedAttempts = securityStats.blockedAttempts + 1
end

--- Get security statistics
--- @return table Security statistics
function SecurityEnhancements.GetSecurityStats()
    return {
        blockedAttempts = securityStats.blockedAttempts,
        validationFailures = securityStats.validationFailures,
        suspiciousActivity = securityStats.suspiciousActivity,
        uptime = os.time() - securityStats.lastResetTime,
        suspiciousPlayersCount = tablelength(suspiciousPlayers)
    }
end

--- Reset security statistics
function SecurityEnhancements.ResetSecurityStats()
    securityStats = {
        blockedAttempts = 0,
        validationFailures = 0,
        suspiciousActivity = 0,
        lastResetTime = os.time()
    }
    suspiciousPlayers = {}
    Log("[CNR_SECURITY] Security statistics reset", Constants.LOG_LEVELS.INFO)
end

-- ====================================================================
-- CLEANUP FUNCTIONS
-- ====================================================================

--- Clean up security data for disconnected player
--- @param playerId number Player ID
function SecurityEnhancements.CleanupPlayer(playerId)
    suspiciousPlayers[playerId] = nil
end

--- Periodic cleanup of old security data
function SecurityEnhancements.PeriodicSecurityCleanup()
    local currentTime = GetGameTimer()
    local cleanupThreshold = 30 * Constants.TIME_MS.MINUTE -- 30 minutes
    
    for playerId, data in pairs(suspiciousPlayers) do
        -- Check if player is still connected
        if not GetPlayerName(playerId) then
            suspiciousPlayers[playerId] = nil
        elseif currentTime - data.lastFailure > cleanupThreshold then
            -- Reset failure count for players who haven't failed recently
            data.failureCount = math.max(0, data.failureCount - 1)
            
            -- Remove old events
            for i = #data.events, 1, -1 do
                if currentTime - data.events[i].timestamp > cleanupThreshold then
                    table.remove(data.events, i)
                end
            end
        end
    end
end

-- ====================================================================
-- ADMIN COMMANDS
-- ====================================================================

--- Register security admin commands
RegisterCommand('cnr_security_stats', function(source, args, rawCommand)
    if source ~= 0 and not IsPlayerAdmin(source) then
        return
    end
    
    local stats = SecurityEnhancements.GetSecurityStats()
    Log("[CNR_SECURITY_STATS] ==================== SECURITY STATISTICS ====================", Constants.LOG_LEVELS.INFO)
    Log(string.format("Blocked Attempts: %d", stats.blockedAttempts), Constants.LOG_LEVELS.INFO)
    Log(string.format("Validation Failures: %d", stats.validationFailures), Constants.LOG_LEVELS.INFO)
    Log(string.format("Suspicious Activities: %d", stats.suspiciousActivity), Constants.LOG_LEVELS.INFO)
    Log(string.format("Suspicious Players: %d", stats.suspiciousPlayersCount), Constants.LOG_LEVELS.INFO)
    Log(string.format("Uptime: %d seconds", stats.uptime), Constants.LOG_LEVELS.INFO)
    Log("[CNR_SECURITY_STATS] ========================================================", Constants.LOG_LEVELS.INFO)
end, false)

RegisterCommand('cnr_security_reset', function(source, args, rawCommand)
    if source ~= 0 and not IsPlayerAdmin(source) then
        return
    end
    
    SecurityEnhancements.ResetSecurityStats()
end, false)

-- ====================================================================
-- INITIALIZATION
-- ====================================================================

-- Set up periodic cleanup
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5 * Constants.TIME_MS.MINUTE) -- Every 5 minutes
        SecurityEnhancements.PeriodicSecurityCleanup()
    end
end)

-- Clean up on player disconnect
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    SecurityEnhancements.CleanupPlayer(playerId)
end)

Log("[CNR_SECURITY] Security enhancements loaded. Enhanced validation and monitoring active.", Constants.LOG_LEVELS.INFO)
