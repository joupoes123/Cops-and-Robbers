-- security_enhancements.lua
-- Additional security enhancements and validation wrappers for legacy functions

-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before security_enhancements.lua")
end

-- Initialize Validation module (merged from validation.lua)
Validation = Validation or {}

-- Initialize SecurityEnhancements module
SecurityEnhancements = SecurityEnhancements or {}

-- Rate limiting storage (from validation.lua)
local rateLimits = {}
local playerEventCounts = {}

-- ====================================================================
-- ====================================================================

--- Safely convert value to number with bounds checking
--- @param value any The value to convert
--- @param min number Minimum allowed value
--- @param max number Maximum allowed value
--- @param default number Default value if conversion fails
--- @return number The validated number
local function SafeToNumber(value, min, max, default)
    local num = tonumber(value)
    if not num then return default end
    if min and num < min then return min end
    if max and num > max then return max end
    return num
end

--- Check if a string is valid and within length limits
--- @param str string The string to validate
--- @param maxLength number Maximum allowed length
--- @param allowEmpty boolean Whether empty strings are allowed
--- @return boolean, string Success status and error message
local function ValidateString(str, maxLength, allowEmpty)
    if not str then
        return false, "String is nil"
    end
    
    if type(str) ~= "string" then
        return false, "Value is not a string"
    end
    
    if not allowEmpty and #str == 0 then
        return false, "String cannot be empty"
    end
    
    if maxLength and #str > maxLength then
        return false, string.format("String too long (max: %d, got: %d)", maxLength, #str)
    end
    
    return true, nil
end

--- @param playerId any Player ID to validate
--- @return boolean, string Success status and error message
function Validation.ValidatePlayer(playerId)
    local id = tonumber(playerId)
    if not id then
        return false, "Invalid player ID format"
    end
    
    if id < 1 or id > 1024 then
        return false, "Player ID out of valid range"
    end
    
    -- Check if player is connected
    local playerName = GetPlayerName(id)
    if not playerName then
        return false, "Player not found or disconnected"
    end
    
    return true, nil
end

--- @param itemId any Item ID to validate
--- @return boolean, table, string Success status, item config, and error message
function Validation.ValidateItem(itemId)
    if not itemId then
        return false, nil, "Item ID is nil"
    end
    
    if type(itemId) ~= "string" then
        return false, nil, "Item ID must be a string"
    end
    
    if not Config or not Config.Items then
        return false, nil, "Item configuration not available"
    end
    
    local itemConfig = Config.Items[itemId]
    if not itemConfig then
        return false, nil, string.format("Item '%s' does not exist", itemId)
    end
    
    return true, itemConfig, nil
end

--- @param quantity any Quantity to validate
--- @return boolean, number, string Success status, validated quantity, and error message
function Validation.ValidateQuantity(quantity)
    local qty = tonumber(quantity)
    if not qty then
        return false, 0, "Invalid quantity format"
    end
    
    if qty < 0 then
        return false, 0, "Quantity cannot be negative"
    end
    
    if qty > Constants.VALIDATION.MAX_ITEM_QUANTITY then
        return false, 0, string.format("Quantity too large (max: %d)", Constants.VALIDATION.MAX_ITEM_QUANTITY)
    end
    
    -- Round to integer
    qty = math.floor(qty)
    
    return true, qty, nil
end

--- @param amount any Amount to validate
--- @param allowNegative boolean Whether negative amounts are allowed
--- @return boolean, number, string Success status, validated amount, and error message
function Validation.ValidateMoney(amount, allowNegative)
    local money = tonumber(amount)
    if not money then
        return false, 0, "Invalid money format"
    end
    
    if not allowNegative and money < 0 then
        return false, 0, "Money amount cannot be negative"
    end
    
    if money > Constants.VALIDATION.MAX_MONEY_AMOUNT then
        return false, 0, string.format("Money amount too large (max: $%d)", Constants.VALIDATION.MAX_MONEY_AMOUNT)
    end
    
    if money < Constants.VALIDATION.MIN_MONEY_AMOUNT then
        return false, 0, string.format("Money amount too small (min: $%d)", Constants.VALIDATION.MIN_MONEY_AMOUNT)
    end
    
    money = math.floor(money * 100) / 100
    
    return true, money, nil
end

--- @param pData table Player data
--- @param quantity number Quantity to add
--- @return boolean, string Success status and error message
function Validation.ValidateInventorySpace(pData, quantity)
    if not pData then
        return false, "Player data not available"
    end
    
    if not pData.inventory then
        return false, "Player inventory not initialized"
    end
    
    local currentItems = 0
    for _, itemData in pairs(pData.inventory) do
        if itemData and itemData.count then
            currentItems = currentItems + itemData.count
        end
    end
    
    if currentItems + quantity > Constants.VALIDATION.MAX_INVENTORY_ITEMS then
        return false, string.format("Not enough inventory space (current: %d, adding: %d, max: %d)", 
            currentItems, quantity, Constants.VALIDATION.MAX_INVENTORY_ITEMS)
    end
    
    return true, nil
end

--- @param playerId number Player ID to check
--- @return boolean, string Success status and error message
function Validation.ValidateAdminPermission(playerId)
    local validPlayer, playerError = Validation.ValidatePlayer(playerId)
    if not validPlayer then
        return false, playerError
    end
    
    if not IsPlayerAdmin then
        return false, "Admin system not available"
    end
    
    if not IsPlayerAdmin(playerId) then
        return false, "Player does not have admin permissions"
    end
    
    return true, nil
end

--- @param playerId number Player ID
--- @param action string Action type
--- @param maxCount number Maximum allowed count
--- @param timeWindow number Time window in milliseconds
--- @return boolean Whether action is allowed
function Validation.CheckRateLimit(playerId, action, maxCount, timeWindow)
    local currentTime = GetGameTimer()
    local key = string.format("%d_%s", playerId, action)
    
    if not rateLimits[key] then
        rateLimits[key] = {
            count = 0,
            windowStart = currentTime
        }
    end
    
    local rateData = rateLimits[key]
    
    if currentTime - rateData.windowStart > timeWindow then
        rateData.count = 0
        rateData.windowStart = currentTime
    end
    
    -- Check if limit exceeded
    if rateData.count >= maxCount then
        return false
    end
    
    rateData.count = rateData.count + 1
    return true
end

--- @param x any X coordinate
--- @param y any Y coordinate
--- @param z any Z coordinate
--- @return boolean, table, string Success status, validated coordinates, and error message
function Validation.ValidateCoordinates(x, y, z)
    local coords = {
        x = tonumber(x),
        y = tonumber(y),
        z = tonumber(z)
    }
    
    if not coords.x or not coords.y or not coords.z then
        return false, nil, "Invalid coordinate format"
    end
    
    -- Check if coordinates are within reasonable bounds for GTA V map
    if coords.x < -4000 or coords.x > 4000 or
       coords.y < -4000 or coords.y > 4000 or
       coords.z < -1000 or coords.z > 1000 then
        return false, nil, "Coordinates out of valid range"
    end
    
    return true, coords, nil
end

--- @param model any Vehicle model to validate
--- @return boolean, number, string Success status, validated model hash, and error message
function Validation.ValidateVehicleModel(model)
    local modelHash
    
    if type(model) == "string" then
        modelHash = GetHashKey(model)
    elseif type(model) == "number" then
        modelHash = model
    else
        return false, 0, "Invalid vehicle model format"
    end
    
    if not IsModelValid(modelHash) then
        return false, 0, "Vehicle model does not exist"
    end
    
    if not IsModelAVehicle(modelHash) then
        return false, 0, "Model is not a vehicle"
    end
    
    return true, modelHash, nil
end

--- @param weapon any Weapon to validate
--- @return boolean, number, string Success status, validated weapon hash, and error message
function Validation.ValidateWeapon(weapon)
    local weaponHash
    
    if type(weapon) == "string" then
        weaponHash = GetHashKey(weapon)
    elseif type(weapon) == "number" then
        weaponHash = weapon
    else
        return false, 0, "Invalid weapon format"
    end
    
    -- Check if weapon exists in game
    if not IsWeaponValid(weaponHash) then
        return false, 0, "Weapon does not exist"
    end
    
    return true, weaponHash, nil
end

--- @param xp any XP amount to validate
--- @return boolean, number, string Success status, validated XP, and error message
function Validation.ValidateXP(xp)
    local experience = tonumber(xp)
    if not experience then
        return false, 0, "Invalid XP format"
    end
    
    if experience < 0 then
        return false, 0, "XP cannot be negative"
    end
    
    if experience > Constants.VALIDATION.MAX_XP_AMOUNT then
        return false, 0, string.format("XP amount too large (max: %d)", Constants.VALIDATION.MAX_XP_AMOUNT)
    end
    
    -- Round to integer
    experience = math.floor(experience)
    
    return true, experience, nil
end

--- @param level any Level to validate
--- @return boolean, number, string Success status, validated level, and error message
function Validation.ValidateLevel(level)
    local lvl = tonumber(level)
    if not lvl then
        return false, 0, "Invalid level format"
    end
    
    if lvl < 1 then
        return false, 0, "Level must be at least 1"
    end
    
    if lvl > Constants.VALIDATION.MAX_LEVEL then
        return false, 0, string.format("Level too high (max: %d)", Constants.VALIDATION.MAX_LEVEL)
    end
    
    -- Round to integer
    lvl = math.floor(lvl)
    
    return true, lvl, nil
end

--- @param role any Role to validate
--- @return boolean, string, string Success status, validated role, and error message
function Validation.ValidateRole(role)
    if not role then
        return false, nil, "Role is nil"
    end
    
    if type(role) ~= "string" then
        return false, nil, "Role must be a string"
    end
    
    local validRoles = {"cop", "robber", "civilian"}
    local lowerRole = string.lower(role)
    
    for _, validRole in ipairs(validRoles) do
        if lowerRole == validRole then
            return true, validRole, nil
        end
    end
    
    return false, nil, string.format("Invalid role '%s'. Valid roles: %s", role, table.concat(validRoles, ", "))
end

--- @param message any Message to validate
--- @return boolean, string, string Success status, validated message, and error message
function Validation.ValidateChatMessage(message)
    local validString, stringError = ValidateString(message, Constants.VALIDATION.MAX_CHAT_LENGTH, false)
    if not validString then
        return false, nil, stringError
    end
    
    local lowerMessage = string.lower(message)
    local bannedWords = {"hack", "cheat", "exploit", "mod menu"}
    
    for _, word in ipairs(bannedWords) do
        if string.find(lowerMessage, word) then
            return false, nil, "Message contains inappropriate content"
        end
    end
    
    return true, message, nil
end

--- @param itemId any Item ID
--- @param quantity any Quantity
--- @param totalCost any Total cost
--- @return boolean, table, string Success status, validated purchase data, and error message
function Validation.ValidatePurchase(itemId, quantity, totalCost)
    local validItem, itemConfig, itemError = Validation.ValidateItem(itemId)
    if not validItem then
        return false, nil, itemError
    end
    
    local validQty, validatedQuantity, qtyError = Validation.ValidateQuantity(quantity)
    if not validQty then
        return false, nil, qtyError
    end
    
    local validCost, validatedCost, costError = Validation.ValidateMoney(totalCost, false)
    if not validCost then
        return false, nil, costError
    end
    
    local expectedCost = itemConfig.price * validatedQuantity
    if math.abs(validatedCost - expectedCost) > 0.01 then
        return false, nil, string.format("Cost mismatch (expected: $%.2f, got: $%.2f)", expectedCost, validatedCost)
    end
    
    return true, {
        itemId = itemId,
        quantity = validatedQuantity,
        cost = validatedCost,
        itemConfig = itemConfig
    }, nil
end

--- Clean up validation data for disconnected player
--- @param playerId number Player ID
function Validation.CleanupPlayer(playerId)
    for key in pairs(rateLimits) do
        if string.find(key, "^" .. playerId .. "_") then
            rateLimits[key] = nil
        end
    end
    
    playerEventCounts[playerId] = nil
end

--- Periodic cleanup of old rate limit data
function Validation.PeriodicCleanup()
    local currentTime = GetGameTimer()
    local cleanupThreshold = 10 * Constants.TIME_MS.MINUTE -- 10 minutes
    
    for key, data in pairs(rateLimits) do
        if currentTime - data.windowStart > cleanupThreshold then
            rateLimits[key] = nil
        end
    end
    
    -- Clean up disconnected players
    for playerId in pairs(playerEventCounts) do
        if not GetPlayerName(playerId) then
            playerEventCounts[playerId] = nil
        end
    end
end

-- Set up periodic cleanup thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Constants.TIME_MS.MINUTE) -- Every minute
        Validation.PeriodicCleanup()
    end
end)

-- Clean up on player disconnect
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    Validation.CleanupPlayer(playerId)
end)

-- ====================================================================
-- ADDITIONAL VALIDATION FUNCTIONS (from validation.lua)
-- ====================================================================

--- Log validation errors with context
--- @param playerId number Player ID for context
--- @param operation string The operation being validated
--- @param error string The validation error
local function LogValidationError(playerId, operation, error)
    local playerName = GetPlayerName(playerId) or "Unknown"
    if Log then
        Log(string.format("[CNR_VALIDATION_ERROR] Player %s (%d) - %s: %s", 
            playerName, playerId, operation, error), Constants.LOG_LEVELS.ERROR)
    else
        Log(string.format("Player %s (%d) - %s: %s", 
            playerName, playerId, operation, error), "error", "CNR_VALIDATION_ERROR")
    end
end

--- Initialize rate limiting for a player
--- @param playerId number Player ID
local function InitializeRateLimit(playerId)
    if not rateLimits[playerId] then
        rateLimits[playerId] = {
            events = {},
            purchases = {},
            inventoryOps = {}
        }
    end
end

--- Check if player is rate limited for a specific action (enhanced version)
--- @param playerId number Player ID
--- @param actionType string Type of action (events, purchases, inventoryOps)
--- @param maxCount number Maximum allowed actions
--- @param timeWindow number Time window in milliseconds
--- @return boolean Whether the action is allowed
function Validation.CheckRateLimit(playerId, actionType, maxCount, timeWindow)
    InitializeRateLimit(playerId)
    
    local currentTime = GetGameTimer()
    local playerLimits = rateLimits[playerId][actionType]
    
    -- Clean old entries
    for i = #playerLimits, 1, -1 do
        if currentTime - playerLimits[i] > timeWindow then
            table.remove(playerLimits, i)
        end
    end
    
    -- Check if limit exceeded
    if #playerLimits >= maxCount then
        LogValidationError(playerId, "RateLimit", 
            string.format("Exceeded %s limit: %d/%d in %dms", actionType, #playerLimits, maxCount, timeWindow))
        return false
    end
    
    -- Add current action
    table.insert(playerLimits, currentTime)
    return true
end

--- Validate player has required role
--- @param playerId number Player ID
--- @param requiredRole string Required role
--- @param playerData table Player data (optional, will fetch if not provided)
--- @return boolean, string Success status and error message
function Validation.ValidatePlayerRole(playerId, requiredRole, playerData)
    local valid, error = Validation.ValidatePlayer(playerId)
    if not valid then return false, error end
    
    if not playerData then
        playerData = GetCnrPlayerData(playerId)
    end
    
    if not playerData then
        return false, Constants.ERROR_MESSAGES.PLAYER_NOT_FOUND
    end
    
    if playerData.role ~= requiredRole then
        return false, string.format("Role '%s' required, player has '%s'", requiredRole, playerData.role or "none")
    end
    
    return true, nil
end

--- Validate player has required level
--- @param playerId number Player ID
--- @param requiredLevel number Required level
--- @param playerData table Player data (optional)
--- @return boolean, string Success status and error message
function Validation.ValidatePlayerLevel(playerId, requiredLevel, playerData)
    local valid, error = Validation.ValidatePlayer(playerId)
    if not valid then return false, error end
    
    if not playerData then
        playerData = GetCnrPlayerData(playerId)
    end
    
    if not playerData then
        return false, Constants.ERROR_MESSAGES.PLAYER_NOT_FOUND
    end
    
    local playerLevel = playerData.level or 1
    if playerLevel < requiredLevel then
        return false, string.format("Level %d required, player is level %d", requiredLevel, playerLevel)
    end
    
    return true, nil
end

--- Validate player can afford item purchase
--- @param playerId number Player ID
--- @param itemConfig table Item configuration
--- @param quantity number Quantity to purchase
--- @param playerData table Player data (optional)
--- @return boolean, number, string Success status, total cost, and error message
function Validation.ValidateItemPurchase(playerId, itemConfig, quantity, playerData)
    if not playerData then
        playerData = GetCnrPlayerData(playerId)
    end
    
    if not playerData then
        return false, 0, Constants.ERROR_MESSAGES.PLAYER_NOT_FOUND
    end
    
    local totalCost = (itemConfig.basePrice or 0) * quantity
    
    -- Validate cost is reasonable
    if totalCost > Constants.VALIDATION.MAX_MONEY_TRANSACTION then
        return false, totalCost, "Transaction amount too large"
    end
    
    -- Check player funds
    local playerMoney = playerData.money or 0
    if playerMoney < totalCost then
        return false, totalCost, Constants.ERROR_MESSAGES.INSUFFICIENT_FUNDS
    end
    
    -- Check role restrictions
    if itemConfig.forCop and playerData.role ~= Constants.ROLES.COP then
        return false, totalCost, "Item restricted to police officers"
    end
    
    -- Check level requirements
    local requiredLevel = nil
    if playerData.role == Constants.ROLES.COP and itemConfig.minLevelCop then
        requiredLevel = itemConfig.minLevelCop
    elseif playerData.role == Constants.ROLES.ROBBER and itemConfig.minLevelRobber then
        requiredLevel = itemConfig.minLevelRobber
    end
    
    if requiredLevel then
        local playerLevel = playerData.level or 1
        if playerLevel < requiredLevel then
            return false, totalCost, string.format("Level %d required for this item", requiredLevel)
        end
    end
    
    return true, totalCost, nil
end

--- Validate player has item for sale
--- @param playerId number Player ID
--- @param itemId string Item ID
--- @param quantity number Quantity to sell
--- @param playerData table Player data (optional)
--- @return boolean, string Success status and error message
function Validation.ValidateItemSale(playerId, itemId, quantity, playerData)
    if not playerData then
        playerData = GetCnrPlayerData(playerId)
    end
    
    if not playerData or not playerData.inventory then
        return false, Constants.ERROR_MESSAGES.PLAYER_NOT_FOUND
    end
    
    local playerItem = playerData.inventory[itemId]
    if not playerItem or not playerItem.count then
        return false, Constants.ERROR_MESSAGES.INSUFFICIENT_ITEMS
    end
    
    if playerItem.count < quantity then
        return false, string.format("Insufficient items: have %d, need %d", playerItem.count, quantity)
    end
    
    return true, nil
end

--- Validate player has sufficient funds
--- @param playerId number Player ID
--- @param amount number Amount needed
--- @param playerData table Player data (optional)
--- @return boolean, string Success status and error message
function Validation.ValidatePlayerFunds(playerId, amount, playerData)
    if not playerData then
        playerData = GetCnrPlayerData(playerId)
    end
    
    if not playerData then
        return false, Constants.ERROR_MESSAGES.PLAYER_NOT_FOUND
    end
    
    local playerMoney = playerData.money or 0
    if playerMoney < amount then
        return false, string.format("Insufficient funds: have $%d, need $%d", playerMoney, amount)
    end
    
    return true, nil
end

--- Validate inventory operation
--- @param playerId number Player ID
--- @param operation string Operation type
--- @return boolean, string Success status and error message
function Validation.ValidateInventoryOperation(playerId, operation)
    -- Rate limit inventory operations
    if not Validation.CheckRateLimit(playerId, "inventoryOps", 
        Constants.VALIDATION.MAX_INVENTORY_OPERATIONS_PER_SECOND, 
        Constants.TIME_MS.SECOND) then
        return false, Constants.ERROR_MESSAGES.RATE_LIMITED
    end
    
    local valid, error = Validation.ValidatePlayer(playerId)
    if not valid then return false, error end
    
    local validOperations = {"equip", "unequip", "use", "drop", "add", "remove"}
    local isValidOperation = false
    for _, validOp in ipairs(validOperations) do
        if operation == validOp then
            isValidOperation = true
            break
        end
    end
    
    if not isValidOperation then
        return false, "Invalid inventory operation: " .. tostring(operation)
    end
    
    return true, nil
end

--- Validate network event parameters
--- @param playerId number Player ID
--- @param eventName string Event name
--- @param params table Event parameters
--- @return boolean, string Success status and error message
function Validation.ValidateNetworkEvent(playerId, eventName, params)
    -- Rate limit general events
    if not Validation.CheckRateLimit(playerId, "events", 
        Constants.VALIDATION.MAX_EVENTS_PER_SECOND, 
        Constants.TIME_MS.SECOND) then
        return false, Constants.ERROR_MESSAGES.RATE_LIMITED
    end
    
    local valid, error = Validation.ValidatePlayer(playerId)
    if not valid then return false, error end
    
    local validError = ValidateString(eventName, Constants.VALIDATION.MAX_STRING_LENGTH, false)
    if not validError then
        return false, "Invalid event name"
    end
    
    if params and type(params) ~= "table" then
        return false, "Event parameters must be a table"
    end
    
    return true, nil
end

--- Clean up validation data for disconnected player (enhanced)
--- @param playerId number Player ID
--- @return number Number of items cleaned
function Validation.CleanupPlayerData(playerId)
    local cleanedItems = 0
    
    -- Clear rate limiting data for this player
    if rateLimits[playerId] then
        rateLimits[playerId] = nil
        cleanedItems = cleanedItems + 1
    end
    
    -- Clear any cached validation results
    -- (Add more cleanup as validation system grows)
    
    LogValidationError(playerId, "cleanup", string.format("Validation cleanup completed (%d items)", cleanedItems))
    return cleanedItems
end

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

--- @param eventName string Name of the event for logging
--- @param handler function Original event handler function
--- @return function Wrapped handler with validation
function SecurityEnhancements.SecureEventHandler(eventName, handler)
    return function(...)
        local playerId = source
        
        -- Validate player
        local validPlayer, playerError = Validation.ValidatePlayer(playerId)
        if not validPlayer then
            SecurityEnhancements.LogSecurityEvent(playerId, "INVALID_PLAYER", playerError)
            return
        end
        
        -- Rate limit check
        if not Validation.CheckRateLimit(playerId, "events", 
            Constants.VALIDATION.MAX_EVENTS_PER_SECOND, 
            Constants.TIME_MS.SECOND) then
            SecurityEnhancements.LogSecurityEvent(playerId, "RATE_LIMIT_EXCEEDED", "Event operation")
            return
        end
        
        return handler(playerId, ...)
    end
end

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
