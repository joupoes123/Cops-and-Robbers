-- player_manager.lua
-- Refactored player data management system with improved security and performance

-- Ensure required modules are loaded
if not Constants then
    error("Constants must be loaded before player_manager.lua")
end

if not Validation then
    error("Validation must be loaded before player_manager.lua")
end

if not DataManager then
    error("DataManager must be loaded before player_manager.lua")
end

-- Initialize PlayerManager module
PlayerManager = PlayerManager or {}

-- Player data cache (replaces global playersData)
local playerDataCache = {}
local playerLoadingStates = {}

-- Statistics
local playerStats = {
    totalLoads = 0,
    totalSaves = 0,
    failedLoads = 0,
    failedSaves = 0,
    averageLoadTime = 0,
    averageSaveTime = 0
}

-- ====================================================================
-- UTILITY FUNCTIONS
-- ====================================================================

--- Log player management operations
--- @param playerId number Player ID
--- @param operation string Operation type
--- @param message string Log message
--- @param level string Log level
local function LogPlayerManager(playerId, operation, message, level)
    level = level or Constants.LOG_LEVELS.INFO
    local playerName = GetPlayerName(playerId) or "Unknown"
    
    if level == Constants.LOG_LEVELS.ERROR or level == Constants.LOG_LEVELS.WARN then
        Log(string.format("[CNR_PLAYER_MANAGER] [%s] Player %s (%d) - %s: %s", 
            string.upper(level), playerName, playerId, operation, message))
    end
end

--- Get player license identifier safely
--- @param playerId number Player ID
--- @return string, boolean License identifier and success status
local function GetPlayerLicenseSafe(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not identifiers then
        return nil, false
    end
    
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, "license:") then
            return identifier, true
        end
    end
    
    return nil, false
end

--- Create default player data structure
--- @param playerId number Player ID
--- @return table Default player data
local function CreateDefaultPlayerData(playerId)
    local playerPed = GetPlayerPed(tostring(playerId))
    local initialCoords = vector3(0, 0, 70) -- Default spawn location
    
    if playerPed and playerPed ~= 0 then
        local coords = GetEntityCoords(playerPed)
        if coords then
            initialCoords = coords
        end
    end
    
    return {
        -- Basic player information
        playerId = playerId,
        license = GetPlayerLicenseSafe(playerId),
        name = GetPlayerName(playerId) or "Unknown",
        
        -- Game state
        role = Constants.ROLES.CITIZEN,
        level = 1,
        xp = 0,
        money = Constants.PLAYER_LIMITS.DEFAULT_STARTING_MONEY,
        
        -- Position and world state
        lastKnownPosition = initialCoords,
        
        -- Systems
        inventory = {},
        
        -- Timestamps
        firstJoined = os.time(),
        lastSeen = os.time(),
        
        -- Flags
        isDataLoaded = false,
        
        -- Statistics
        totalPlayTime = 0,
        sessionsPlayed = 1,
        
        -- Version for data migration
        dataVersion = Version.CURRENT
    }
end

--- Validate player data structure
--- @param playerData table Player data to validate
--- @return boolean, table Success status and validation issues
local function ValidatePlayerDataStructure(playerData)
    local issues = {}
    
    if not playerData or type(playerData) ~= "table" then
        table.insert(issues, "Player data is not a table")
        return false, issues
    end
    
    -- Check required fields
    local requiredFields = {
        "playerId", "role", "level", "xp", "money", "inventory"
    }
    
    for _, field in ipairs(requiredFields) do
        if playerData[field] == nil then
            table.insert(issues, string.format("Missing required field: %s", field))
        end
    end
    
    -- Validate field types and ranges
    if playerData.level and (type(playerData.level) ~= "number" or playerData.level < 1 or playerData.level > Constants.PLAYER_LIMITS.MAX_PLAYER_LEVEL) then
        table.insert(issues, "Invalid level value")
    end
    
    if playerData.money and (type(playerData.money) ~= "number" or playerData.money < 0) then
        table.insert(issues, "Invalid money value")
    end
    
    if playerData.xp and (type(playerData.xp) ~= "number" or playerData.xp < 0) then
        table.insert(issues, "Invalid XP value")
    end
    
    if playerData.inventory and type(playerData.inventory) ~= "table" then
        table.insert(issues, "Inventory is not a table")
    end
    
    return #issues == 0, issues
end

--- Fix player data issues
--- @param playerData table Player data to fix
--- @param playerId number Player ID
--- @return table Fixed player data
local function FixPlayerDataIssues(playerData, playerId)
    -- Ensure basic structure
    if not playerData or type(playerData) ~= "table" then
        LogPlayerManager(playerId, "fix_data", "Creating new data structure due to corruption")
        return CreateDefaultPlayerData(playerId)
    end
    
    -- Fix missing or invalid fields
    playerData.playerId = playerData.playerId or playerId
    playerData.role = playerData.role or Constants.ROLES.CITIZEN
    playerData.level = math.max(1, math.min(playerData.level or 1, Constants.PLAYER_LIMITS.MAX_PLAYER_LEVEL))
    playerData.xp = math.max(0, playerData.xp or 0)
    playerData.money = math.max(0, playerData.money or Constants.PLAYER_LIMITS.DEFAULT_STARTING_MONEY)
    playerData.inventory = playerData.inventory or {}
    playerData.lastSeen = os.time()
    playerData.dataVersion = Version.CURRENT
    
    -- Validate inventory integrity
    if SecureInventory then
        SecureInventory.FixInventoryIntegrity(playerId)
    end
    
    return playerData
end

-- ====================================================================
-- CORE PLAYER DATA FUNCTIONS
-- ====================================================================

--- Load player data with comprehensive validation and error handling
--- @param playerId number Player ID
--- @return boolean, string Success status and error message
function PlayerManager.LoadPlayerData(playerId)
    local startTime = GetGameTimer()
    
    -- Validate player
    local validPlayer, playerError = Validation.ValidatePlayer(playerId)
    if not validPlayer then
        return false, playerError
    end
    
    -- Check if already loading
    if playerLoadingStates[playerId] then
        LogPlayerManager(playerId, "load", "Data already loading, skipping duplicate request")
        return false, "Data already loading"
    end
    
    playerLoadingStates[playerId] = true
    
    -- Attempt to load from DataManager
    local success, playerData = DataManager.LoadPlayerData(playerId)
    
    if success then
        -- Validate loaded data
        local validData, issues = ValidatePlayerDataStructure(playerData)
        if not validData then
            LogPlayerManager(playerId, "load", 
                string.format("Data validation failed: %s", table.concat(issues, ", ")), 
                Constants.LOG_LEVELS.WARN)
            playerData = FixPlayerDataIssues(playerData, playerId)
        end
    else
        -- Create new player data
        LogPlayerManager(playerId, "load", "Creating new player data (first time or load failed)")
        playerData = CreateDefaultPlayerData(playerId)
    end
    
    -- Apply any necessary data migrations
    playerData = PlayerManager.MigratePlayerData(playerData, playerId)
    
    -- Cache the data
    playerDataCache[playerId] = playerData
    playerData.isDataLoaded = true
    
    -- Update statistics
    playerStats.totalLoads = playerStats.totalLoads + 1
    if not success then
        playerStats.failedLoads = playerStats.failedLoads + 1
    end
    
    local loadTime = GetGameTimer() - startTime
    playerStats.averageLoadTime = (playerStats.averageLoadTime + loadTime) / 2
    
    playerLoadingStates[playerId] = nil
    
    LogPlayerManager(playerId, "load", 
        string.format("Data loaded successfully (took %dms)", loadTime))
    
    return true, nil
end

--- Save player data with validation and error handling
--- @param playerId number Player ID
--- @param immediate boolean Whether to save immediately or queue
--- @return boolean, string Success status and error message
function PlayerManager.SavePlayerData(playerId, immediate)
    local startTime = GetGameTimer()
    immediate = immediate or false
    
    -- Validate player
    local validPlayer, playerError = Validation.ValidatePlayer(playerId)
    if not validPlayer then
        return false, playerError
    end
    
    -- Get player data from cache
    local playerData = playerDataCache[playerId]
    if not playerData then
        return false, "No player data to save"
    end
    
    -- Update last seen timestamp
    playerData.lastSeen = os.time()
    
    -- Update position if player is online
    local playerPed = GetPlayerPed(tostring(playerId))
    if playerPed and playerPed ~= 0 then
        local coords = GetEntityCoords(playerPed)
        if coords then
            playerData.lastKnownPosition = coords
        end
    end
    
    -- Validate data before saving
    local validData, issues = ValidatePlayerDataStructure(playerData)
    if not validData then
        LogPlayerManager(playerId, "save", 
            string.format("Data validation failed before save: %s", table.concat(issues, ", ")), 
            Constants.LOG_LEVELS.ERROR)
        return false, "Data validation failed"
    end
    
    -- Save using DataManager
    local success, error = DataManager.SavePlayerData(playerId, playerData, immediate)
    
    -- Update statistics
    playerStats.totalSaves = playerStats.totalSaves + 1
    if not success then
        playerStats.failedSaves = playerStats.failedSaves + 1
    end
    
    local saveTime = GetGameTimer() - startTime
    playerStats.averageSaveTime = (playerStats.averageSaveTime + saveTime) / 2
    
    if success then
        LogPlayerManager(playerId, "save", 
            string.format("Data saved successfully (took %dms, immediate: %s)", 
                saveTime, tostring(immediate)))
    else
        LogPlayerManager(playerId, "save", 
            string.format("Save failed: %s", error), 
            Constants.LOG_LEVELS.ERROR)
    end
    
    return success, error
end

--- Get player data from cache with validation
--- @param playerId number Player ID
--- @return table, boolean Player data and success status
function PlayerManager.GetPlayerData(playerId)
    -- Validate player
    local validPlayer, playerError = Validation.ValidatePlayer(playerId)
    if not validPlayer then
        return nil, false
    end
    
    local playerData = playerDataCache[playerId]
    if not playerData then
        LogPlayerManager(playerId, "get_data", "No cached data found", Constants.LOG_LEVELS.WARN)
        return nil, false
    end
    
    if not playerData.isDataLoaded then
        LogPlayerManager(playerId, "get_data", "Data not fully loaded", Constants.LOG_LEVELS.WARN)
        return nil, false
    end
    
    return playerData, true
end

--- Set player data in cache with validation
--- @param playerId number Player ID
--- @param playerData table Player data to set
--- @return boolean Success status
function PlayerManager.SetPlayerData(playerId, playerData)
    -- Validate player
    local validPlayer, playerError = Validation.ValidatePlayer(playerId)
    if not validPlayer then
        return false
    end
    
    -- Validate data structure
    local validData, issues = ValidatePlayerDataStructure(playerData)
    if not validData then
        LogPlayerManager(playerId, "set_data", 
            string.format("Invalid data structure: %s", table.concat(issues, ", ")), 
            Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    playerDataCache[playerId] = playerData
    DataManager.MarkPlayerForSave(playerId)
    
    return true
end

-- ====================================================================
-- DATA MIGRATION SYSTEM
-- ====================================================================

--- Migrate player data to current version
--- @param playerData table Player data to migrate
--- @param playerId number Player ID
--- @return table Migrated player data
function PlayerManager.MigratePlayerData(playerData, playerId)
    local currentVersion = Version.CURRENT
    local dataVersion = playerData.dataVersion or "1.0.0"
    
    if dataVersion == currentVersion then
        return playerData -- No migration needed
    end
    
    LogPlayerManager(playerId, "migrate", 
        string.format("Migrating data from version %s to %s", dataVersion, currentVersion))
    
    -- Migration logic for different versions
    if dataVersion == "1.0.0" or dataVersion == "1.1.0" then
        -- Add new fields introduced in 1.2.0
        playerData.dataVersion = currentVersion
        playerData.totalPlayTime = playerData.totalPlayTime or 0
        playerData.sessionsPlayed = playerData.sessionsPlayed or 1
        
        -- Ensure inventory structure is correct
        if not playerData.inventory or type(playerData.inventory) ~= "table" then
            playerData.inventory = {}
        end
        
        -- Fix any legacy role names
        if playerData.role == "civilian" then
            playerData.role = Constants.ROLES.CITIZEN
        end
    end
    
    LogPlayerManager(playerId, "migrate", "Data migration completed successfully")
    return playerData
end

-- ====================================================================
-- PLAYER LIFECYCLE MANAGEMENT
-- ====================================================================

--- Handle player connection
--- @param playerId number Player ID
function PlayerManager.OnPlayerConnected(playerId)
    LogPlayerManager(playerId, "connect", "Player connected, initializing data")
    
    -- Load player data
    local success, error = PlayerManager.LoadPlayerData(playerId)
    if not success then
        LogPlayerManager(playerId, "connect", 
            string.format("Failed to load data: %s", error), 
            Constants.LOG_LEVELS.ERROR)
        return
    end
    
    -- Initialize player systems
    PlayerManager.InitializePlayerSystems(playerId)
    
    LogPlayerManager(playerId, "connect", "Player initialization completed")
end

--- Handle player disconnection
--- @param playerId number Player ID
--- @param reason string Disconnect reason
function PlayerManager.OnPlayerDisconnected(playerId, reason)
    LogPlayerManager(playerId, "disconnect", 
        string.format("Player disconnected (reason: %s), saving data", reason or "unknown"))
    
    -- Save player data immediately
    local success, error = PlayerManager.SavePlayerData(playerId, true)
    if not success then
        LogPlayerManager(playerId, "disconnect", 
            string.format("Failed to save data: %s", error), 
            Constants.LOG_LEVELS.ERROR)
    end
    
    -- Clean up player from cache and other systems
    PlayerManager.CleanupPlayer(playerId)
    
    LogPlayerManager(playerId, "disconnect", "Player cleanup completed")
end

--- Initialize player systems after data load
--- @param playerId number Player ID
function PlayerManager.InitializePlayerSystems(playerId)
    local playerData = playerDataCache[playerId]
    if not playerData then
        LogPlayerManager(playerId, "init_systems", "No player data available", Constants.LOG_LEVELS.ERROR)
        return
    end
    
    -- Set player role (this will trigger role-specific initialization)
    PlayerManager.SetPlayerRole(playerId, playerData.role, true)
    
    -- Apply level-based perks
    if ApplyPerks then
        ApplyPerks(playerId, playerData.level, playerData.role)
    end
    
    -- Initialize inventory
    if not playerData.inventory then
        playerData.inventory = {}
    end
    
    -- Sync data to client
    PlayerManager.SyncPlayerDataToClient(playerId)
    
    LogPlayerManager(playerId, "init_systems", "Player systems initialized")
end

--- Sync player data to client
--- @param playerId number Player ID
function PlayerManager.SyncPlayerDataToClient(playerId)
    local playerData = playerDataCache[playerId]
    if not playerData then return end
    
    -- Send minimized inventory for performance
    if SecureInventory then
        local success, inventory = SecureInventory.GetInventory(playerId)
        if success then
            TriggerClientEvent(Constants.EVENTS.SERVER_TO_CLIENT.SYNC_INVENTORY, playerId, 
                MinimizeInventoryForSync(inventory))
        end
    end
    
    -- Send other player data
    TriggerClientEvent(Constants.EVENTS.SERVER_TO_CLIENT.UPDATE_PLAYER_DATA, playerId, {
        role = playerData.role,
        level = playerData.level,
        xp = playerData.xp,
        money = playerData.money
    })
end

--- Clean up player data and references
--- @param playerId number Player ID
function PlayerManager.CleanupPlayer(playerId)
    -- Remove from cache
    playerDataCache[playerId] = nil
    playerLoadingStates[playerId] = nil
    
    -- Clean up character data
    PlayerManager.CleanupPlayerCharacterData(playerId)
    
    -- Clean up other systems
    if Validation then
        Validation.CleanupPlayer(playerId)
    end
    
    if SecureInventory then
        SecureInventory.CleanupPlayer(playerId)
    end
    
    if SecureTransactions then
        SecureTransactions.CleanupPlayer(playerId)
    end
    
    LogPlayerManager(playerId, "cleanup", "Player cleanup completed")
end

--- Enhanced cleanup for memory manager integration
--- @param playerId number Player ID
--- @return number Number of items cleaned
function PlayerManager.CleanupPlayerCache(playerId)
    local cleanedItems = 0
    
    -- Remove from cache
    if playerDataCache[playerId] then
        playerDataCache[playerId] = nil
        cleanedItems = cleanedItems + 1
    end
    
    if playerLoadingStates[playerId] then
        playerLoadingStates[playerId] = nil
        cleanedItems = cleanedItems + 1
    end
    
    LogPlayerManager(playerId, "cleanup", string.format("Cache cleanup completed (%d items)", cleanedItems))
    return cleanedItems
end

-- ====================================================================
-- PLAYER UTILITY FUNCTIONS (Consolidated from server.lua)
-- ====================================================================

--- Get player's license identifier
--- @param playerId number Player ID
--- @return string|nil License identifier
function PlayerManager.GetPlayerLicense(playerId)
    local identifiers = GetPlayerIdentifiers(tostring(playerId))
    if identifiers then
        for _, identifier in ipairs(identifiers) do
            if string.match(identifier, "^license:") then
                return identifier
            end
        end
    end
    return nil
end

--- Get player money
--- @param playerId number Player ID
--- @return number Money amount
function PlayerManager.GetPlayerMoney(playerId)
    local playerData = playerDataCache[tonumber(playerId)]
    if playerData and playerData.money then
        return playerData.money
    end
    return 0
end

--- Add money to a player
--- @param playerId number Player ID
--- @param amount number Amount to add
--- @param type string Money type (default: 'cash')
--- @return boolean Success status
function PlayerManager.AddPlayerMoney(playerId, amount, type)
    type = type or 'cash'
    local pId = tonumber(playerId)
    if not pId or pId <= 0 then
        LogPlayerManager(pId, "add_money", string.format("Invalid player ID %s", tostring(playerId)), Constants.LOG_LEVELS.ERROR)
        return false
    end

    local playerData = playerDataCache[pId]
    if playerData then
        if type == 'cash' then
            playerData.money = (playerData.money or 0) + amount
            LogPlayerManager(pId, "add_money", string.format("Added %d to %s account. New balance: %d", amount, type, playerData.money))
            
            -- Send notification to client
            TriggerClientEvent('chat:addMessage', pId, { args = {"^2Money", string.format("You received $%d.", amount)} })
            
            -- Update client with new player data
            local pDataForBasicInfo = shallowcopy(playerData)
            pDataForBasicInfo.inventory = nil
            TriggerClientEvent('cnr:updatePlayerData', pId, pDataForBasicInfo)
            
            -- Mark for save
            DataManager.MarkPlayerForSave(pId)
            
            return true
        else
            LogPlayerManager(pId, "add_money", string.format("Unsupported account type '%s'", type), Constants.LOG_LEVELS.WARN)
            return false
        end
    else
        LogPlayerManager(pId, "add_money", "Player data not found", Constants.LOG_LEVELS.ERROR)
        return false
    end
end

--- Remove money from a player
--- @param playerId number Player ID
--- @param amount number Amount to remove
--- @param type string Money type (default: 'cash')
--- @return boolean Success status
function PlayerManager.RemovePlayerMoney(playerId, amount, type)
    type = type or 'cash'
    local pId = tonumber(playerId)
    if not pId or pId <= 0 then
        LogPlayerManager(pId, "remove_money", string.format("Invalid player ID %s", tostring(playerId)), Constants.LOG_LEVELS.ERROR)
        return false
    end

    local playerData = playerDataCache[pId]
    if playerData then
        if type == 'cash' then
            if (playerData.money or 0) >= amount then
                playerData.money = playerData.money - amount
                LogPlayerManager(pId, "remove_money", string.format("Removed %d from %s account. New balance: %d", amount, type, playerData.money))
                
                -- Update client with new player data
                local pDataForBasicInfo = shallowcopy(playerData)
                pDataForBasicInfo.inventory = nil
                TriggerClientEvent('cnr:updatePlayerData', pId, pDataForBasicInfo)
                
                -- Mark for save
                DataManager.MarkPlayerForSave(pId)
                
                return true
            else
                -- Notify client about insufficient funds
                TriggerClientEvent('chat:addMessage', pId, { args = {"^1Error", "You don't have enough money."} })
                return false
            end
        else
            LogPlayerManager(pId, "remove_money", string.format("Unsupported account type '%s'", type), Constants.LOG_LEVELS.WARN)
            return false
        end
    else
        LogPlayerManager(pId, "remove_money", "Player data not found", Constants.LOG_LEVELS.ERROR)
        return false
    end
end

--- Add XP to a player
--- @param playerId number Player ID
--- @param amount number XP amount to add
--- @return boolean Success status
function PlayerManager.AddPlayerXP(playerId, amount)
    local pId = tonumber(playerId)
    if not pId or pId <= 0 then
        LogPlayerManager(pId, "add_xp", string.format("Invalid player ID %s", tostring(playerId)), Constants.LOG_LEVELS.ERROR)
        return false
    end

    local playerData = playerDataCache[pId]
    if playerData then
        -- Add XP
        playerData.xp = (playerData.xp or 0) + amount
        
        -- Check if player leveled up
        local oldLevel = playerData.level or 1
        -- Use a simple level calculation formula
        local newLevel = math.floor(math.sqrt(playerData.xp / 100)) + 1
        playerData.level = newLevel
        
        -- Send XP notification to client
        TriggerClientEvent('cnr:xpGained', pId, amount)
        
        -- Send level up notification if needed
        if newLevel > oldLevel then
            TriggerClientEvent('cnr:levelUp', pId, newLevel)
            LogPlayerManager(pId, "add_xp", string.format("Player leveled up from %d to %d", oldLevel, newLevel))
        end
        
        -- Update client with new player data
        local pDataForBasicInfo = shallowcopy(playerData)
        pDataForBasicInfo.inventory = nil
        TriggerClientEvent('cnr:updatePlayerData', pId, pDataForBasicInfo)
        
        -- Mark for save
        DataManager.MarkPlayerForSave(pId)
        
        LogPlayerManager(pId, "add_xp", string.format("Added %d XP. Total: %d, Level: %d", amount, playerData.xp, newLevel))
        return true
    else
        LogPlayerManager(pId, "add_xp", "Player data not found", Constants.LOG_LEVELS.ERROR)
        return false
    end
end

--- Check if player is admin
--- @param playerId number Player ID
--- @return boolean Is admin
function PlayerManager.IsAdmin(playerId)
    local src = tonumber(playerId)
    if not src then return false end

    local identifiers = GetPlayerIdentifiers(tostring(src))
    if not identifiers then return false end

    if not Config or type(Config.Admins) ~= "table" then
        LogPlayerManager(src, "is_admin", "Config.Admins is not loaded or not a table", Constants.LOG_LEVELS.ERROR)
        return false
    end

    for _, identifier in ipairs(identifiers) do
        if Config.Admins[identifier] then
            LogPlayerManager(src, "is_admin", string.format("Player with identifier %s IS an admin", identifier))
            return true
        end
    end
    
    return false
end

--- Get player role
--- @param playerId number Player ID
--- @return string Player role
function PlayerManager.GetPlayerRole(playerId)
    local playerData = playerDataCache[tonumber(playerId)]
    if playerData then 
        return playerData.role 
    end
    return Constants.ROLES.CITIZEN
end

--- Check if player is cop
--- @param playerId number Player ID
--- @return boolean Is cop
function PlayerManager.IsPlayerCop(playerId)
    return PlayerManager.GetPlayerRole(playerId) == Constants.ROLES.COP
end

--- Check if player is robber
--- @param playerId number Player ID
--- @return boolean Is robber
function PlayerManager.IsPlayerRobber(playerId)
    return PlayerManager.GetPlayerRole(playerId) == Constants.ROLES.ROBBER
end

-- ====================================================================
-- ROLE MANAGEMENT
-- ====================================================================

--- Set player role with validation and system updates
--- @param playerId number Player ID
--- @param role string New role
--- @param skipNotify boolean Whether to skip notification
--- @return boolean Success status
function PlayerManager.SetPlayerRole(playerId, role, skipNotify)
    -- Validate player
    local validPlayer, playerError = Validation.ValidatePlayer(playerId)
    if not validPlayer then
        return false
    end
    
    -- Validate role
    local validRoles = {Constants.ROLES.COP, Constants.ROLES.ROBBER, Constants.ROLES.CITIZEN}
    local isValidRole = false
    for _, validRole in ipairs(validRoles) do
        if role == validRole then
            isValidRole = true
            break
        end
    end
    
    if not isValidRole then
        LogPlayerManager(playerId, "set_role", 
            string.format("Invalid role: %s", tostring(role)), 
            Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    local playerData = playerDataCache[playerId]
    if not playerData then
        LogPlayerManager(playerId, "set_role", "No player data available", Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    local oldRole = playerData.role
    playerData.role = role
    
    -- Update role-specific tracking (using existing global variables for compatibility)
    if copsOnDuty then
        copsOnDuty[playerId] = (role == Constants.ROLES.COP) or nil
    end
    
    if robbersActive then
        robbersActive[playerId] = (role == Constants.ROLES.ROBBER) or nil
    end
    
    -- Mark for save
    DataManager.MarkPlayerForSave(playerId)
    
    -- Notify player if not skipped
    if not skipNotify then
        TriggerClientEvent(Constants.EVENTS.SERVER_TO_CLIENT.SHOW_NOTIFICATION, playerId, 
            string.format("Role changed to %s", role), Constants.NOTIFICATION_TYPES.INFO)
    end
    
    LogPlayerManager(playerId, "set_role", 
        string.format("Role changed from %s to %s", oldRole, role))
    
    return true
end

-- ====================================================================
-- STATISTICS AND MONITORING
-- ====================================================================

--- Get player manager statistics
--- @return table Statistics
function PlayerManager.GetStats()
    return {
        totalLoads = playerStats.totalLoads,
        totalSaves = playerStats.totalSaves,
        failedLoads = playerStats.failedLoads,
        failedSaves = playerStats.failedSaves,
        loadSuccessRate = playerStats.totalLoads > 0 and 
            ((playerStats.totalLoads - playerStats.failedLoads) / playerStats.totalLoads * 100) or 0,
        saveSuccessRate = playerStats.totalSaves > 0 and 
            ((playerStats.totalSaves - playerStats.failedSaves) / playerStats.totalSaves * 100) or 0,
        averageLoadTime = playerStats.averageLoadTime,
        averageSaveTime = playerStats.averageSaveTime,
        cachedPlayers = tablelength(playerDataCache),
        loadingPlayers = tablelength(playerLoadingStates)
    }
end

--- Log player manager statistics
function PlayerManager.LogStats()
    local stats = PlayerManager.GetStats()
    Log(string.format("[CNR_PLAYER_MANAGER] Stats - Loads: %d (%.1f%% success), Saves: %d (%.1f%% success), Avg Load: %.1fms, Avg Save: %.1fms, Cached: %d, Loading: %d",
        stats.totalLoads, stats.loadSuccessRate, stats.totalSaves, stats.saveSuccessRate,
        stats.averageLoadTime, stats.averageSaveTime, stats.cachedPlayers, stats.loadingPlayers))
end

-- ====================================================================
-- CHARACTER EDITOR SYSTEM (Consolidated from character_editor_server.lua)
-- ====================================================================

-- Character data cache
local playerCharacterData = {}

--- Load player character data from file
--- @param playerId number Player ID
--- @return table Character data
function PlayerManager.LoadPlayerCharacters(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return {}
    end
    
    local fileName = "player_data/characters_" .. identifier:gsub(":", "_") .. ".json"
    
    -- Use FiveM's LoadResourceFile function
    local content = LoadResourceFile(GetCurrentResourceName(), fileName)
    
    if content then
        local success, data = pcall(json.decode, content)
        if success and data then
            return data
        else
            LogPlayerManager(playerId, "load_characters", "Failed to decode character data", Constants.LOG_LEVELS.ERROR)
        end
    end
    
    return {}
end

--- Save player character data to file
--- @param playerId number Player ID
--- @param characterData table Character data to save
--- @return boolean Success status
function PlayerManager.SavePlayerCharacters(playerId, characterData)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        LogPlayerManager(playerId, "save_characters", "No identifier available", Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    -- Get the resource path for proper file handling
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local playerDataDir = resourcePath .. "/player_data"
    
    -- Ensure player_data directory exists with proper path handling
    local success = pcall(function()
        -- Create directory using FiveM's built-in functions
        local dirExists = LoadResourceFile(GetCurrentResourceName(), "player_data/test.txt")
        if not dirExists then
            -- Try to create a test file to ensure directory exists
            SaveResourceFile(GetCurrentResourceName(), "player_data/.gitkeep", "# Directory placeholder", -1)
        end
    end)
    
    if not success then
        LogPlayerManager(playerId, "save_characters", "Could not verify player_data directory", Constants.LOG_LEVELS.WARN)
    end
    
    local fileName = "player_data/characters_" .. identifier:gsub(":", "_") .. ".json"
    
    -- Try to encode the data first
    local jsonData
    local encodeSuccess = pcall(function()
        jsonData = json.encode(characterData, {indent = true})
    end)
    
    if not encodeSuccess or not jsonData then
        LogPlayerManager(playerId, "save_characters", "Failed to encode character data", Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    -- Use FiveM's SaveResourceFile function for proper file handling
    local saveSuccess = pcall(function()
        SaveResourceFile(GetCurrentResourceName(), fileName, jsonData, -1)
    end)
    
    if not saveSuccess then
        LogPlayerManager(playerId, "save_characters", "Failed to save character data", Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    return true
end

--- Validate character data
--- @param characterData table Character data to validate
--- @param role string Player role
--- @return boolean, string Validation result and message
function PlayerManager.ValidateCharacterData(characterData, role)
    if not characterData or type(characterData) ~= "table" then
        return false, "Invalid character data"
    end
    
    -- Validate basic required fields
    local requiredFields = {"model", "face", "skin", "hair"}
    for _, field in ipairs(requiredFields) do
        if characterData[field] == nil then
            return false, "Missing required field: " .. field
        end
    end
    
    -- Ensure Config.CharacterEditor exists before validation
    if not Config.CharacterEditor or not Config.CharacterEditor.customization then
        LogPlayerManager(nil, "validate_character", "Config.CharacterEditor.customization not found, skipping detailed validation", Constants.LOG_LEVELS.WARN)
        return true, "Valid (basic validation only)"
    end
    
    -- Validate customization ranges
    local customization = Config.CharacterEditor.customization
    for feature, range in pairs(customization) do
        if characterData[feature] ~= nil then
            local value = characterData[feature]
            if type(value) == "number" then
                if value < range.min or value > range.max then
                    return false, "Invalid value for " .. feature .. ": " .. value
                end
            end
        end
    end
    
    -- Validate face features
    if characterData.faceFeatures then
        for feature, value in pairs(characterData.faceFeatures) do
            if customization[feature] then
                local range = customization[feature]
                if type(value) == "number" and value < range.min or value > range.max then
                    return false, "Invalid face feature value for " .. feature .. ": " .. value
                end
            end
        end
    end
    
    return true, "Valid"
end

--- Sanitize character data for security
--- @param characterData table Raw character data
--- @return table Sanitized character data
function PlayerManager.SanitizeCharacterData(characterData)
    local sanitized = {}
    
    -- Copy safe fields
    local safeFields = {
        "model", "face", "skin", "hair", "hairColor", "hairHighlight",
        "beard", "beardColor", "beardOpacity", "eyebrows", "eyebrowsColor", "eyebrowsOpacity",
        "eyeColor", "blush", "blushColor", "blushOpacity", "lipstick", "lipstickColor", "lipstickOpacity",
        "makeup", "makeupColor", "makeupOpacity", "ageing", "ageingOpacity", "complexion", "complexionOpacity",
        "sundamage", "sundamageOpacity", "freckles", "frecklesOpacity", "bodyBlemishes", "bodyBlemishesOpacity",
        "addBodyBlemishes", "addBodyBlemishesOpacity", "moles", "molesOpacity", "chesthair", "chesthairColor", "chesthairOpacity"
    }
    
    for _, field in ipairs(safeFields) do
        if characterData[field] ~= nil then
            sanitized[field] = characterData[field]
        end
    end
    
    -- Copy face features
    if characterData.faceFeatures and type(characterData.faceFeatures) == "table" then
        sanitized.faceFeatures = {}
        local safeFeatures = {
            "noseWidth", "noseHeight", "noseLength", "noseBridge", "noseTip", "noseShift",
            "browHeight", "browWidth", "cheekboneHeight", "cheekboneWidth", "cheeksWidth",
            "eyesOpening", "lipsThickness", "jawWidth", "jawHeight", "chinLength",
            "chinPosition", "chinWidth", "chinShape", "neckWidth"
        }
        
        for _, feature in ipairs(safeFeatures) do
            if characterData.faceFeatures[feature] ~= nil then
                sanitized.faceFeatures[feature] = characterData.faceFeatures[feature]
            end
        end
    end
    
    -- Copy components and props
    if characterData.components and type(characterData.components) == "table" then
        sanitized.components = {}
        for componentId, component in pairs(characterData.components) do
            if type(component) == "table" and component.drawable and component.texture then
                sanitized.components[componentId] = {
                    drawable = tonumber(component.drawable) or 0,
                    texture = tonumber(component.texture) or 0
                }
            end
        end
    end
    
    if characterData.props and type(characterData.props) == "table" then
        sanitized.props = {}
        for propId, prop in pairs(characterData.props) do
            if type(prop) == "table" and prop.drawable and prop.texture then
                sanitized.props[propId] = {
                    drawable = tonumber(prop.drawable) or -1,
                    texture = tonumber(prop.texture) or 0
                }
            end
        end
    end
    
    -- Copy tattoos
    if characterData.tattoos and type(characterData.tattoos) == "table" then
        sanitized.tattoos = {}
        for _, tattoo in ipairs(characterData.tattoos) do
            if type(tattoo) == "table" and tattoo.collection and tattoo.name then
                table.insert(sanitized.tattoos, {
                    collection = tostring(tattoo.collection),
                    name = tostring(tattoo.name)
                })
            end
        end
    end
    
    return sanitized
end

--- Get player character slots
--- @param playerId number Player ID
--- @return table Character slots data
function PlayerManager.GetPlayerCharacterSlots(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return {}
    end
    
    if not playerCharacterData[identifier] then
        playerCharacterData[identifier] = PlayerManager.LoadPlayerCharacters(playerId)
    end
    
    return playerCharacterData[identifier]
end

--- Save a character slot
--- @param playerId number Player ID
--- @param characterKey string Character key (e.g., "cop_1", "robber_1")
--- @param characterData table Character data
--- @param role string Player role
--- @return boolean, string Success status and message
function PlayerManager.SavePlayerCharacterSlot(playerId, characterKey, characterData, role)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return false, "Invalid player identifier"
    end
    
    -- Validate character data
    local isValid, errorMsg = PlayerManager.ValidateCharacterData(characterData, role)
    if not isValid then
        return false, errorMsg
    end
    
    -- Sanitize character data
    local sanitizedData = PlayerManager.SanitizeCharacterData(characterData)
    
    -- Load current character data
    if not playerCharacterData[identifier] then
        playerCharacterData[identifier] = PlayerManager.LoadPlayerCharacters(playerId)
    end
    
    -- Save character data
    playerCharacterData[identifier][characterKey] = sanitizedData
    
    -- Persist to file
    local success = PlayerManager.SavePlayerCharacters(playerId, playerCharacterData[identifier])
    if success then
        LogPlayerManager(playerId, "save_character_slot", string.format("Character %s saved successfully", characterKey))
        return true, "Character saved successfully"
    else
        return false, "Failed to save character data"
    end
end

--- Delete a character slot
--- @param playerId number Player ID
--- @param characterKey string Character key to delete
--- @return boolean, string Success status and message
function PlayerManager.DeletePlayerCharacterSlot(playerId, characterKey)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return false, "Invalid player identifier"
    end
    
    if not playerCharacterData[identifier] then
        playerCharacterData[identifier] = PlayerManager.LoadPlayerCharacters(playerId)
    end
    
    if playerCharacterData[identifier][characterKey] then
        playerCharacterData[identifier][characterKey] = nil
        
        local success = PlayerManager.SavePlayerCharacters(playerId, playerCharacterData[identifier])
        if success then
            LogPlayerManager(playerId, "delete_character_slot", string.format("Character %s deleted successfully", characterKey))
            return true, "Character deleted successfully"
        else
            return false, "Failed to delete character data"
        end
    else
        return false, "Character not found"
    end
end

--- Apply character to player
--- @param playerId number Player ID
--- @param characterKey string Character key to apply
--- @return boolean, string Success status and message
function PlayerManager.ApplyCharacterToPlayer(playerId, characterKey)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return false, "Invalid player identifier"
    end
    
    local characters = PlayerManager.GetPlayerCharacterSlots(playerId)
    local characterData = characters[characterKey]
    
    if not characterData then
        return false, "Character not found"
    end
    
    -- Trigger client to apply character
    TriggerClientEvent('cnr:applyCharacterData', playerId, characterData)
    
    LogPlayerManager(playerId, "apply_character", string.format("Character %s applied successfully", characterKey))
    return true, "Character applied successfully"
end

--- Get character data for role selection
--- @param playerId number Player ID
--- @param role string Role name
--- @param slot number Slot number (optional, defaults to 1)
--- @return table Character data or nil
function PlayerManager.GetCharacterForRoleSelection(playerId, role, slot)
    local characters = PlayerManager.GetPlayerCharacterSlots(playerId)
    local characterKey = role .. "_" .. (slot or 1)
    return characters[characterKey]
end

--- Check if player has created a character for a role
--- @param playerId number Player ID
--- @param role string Role name
--- @return boolean Has character
function PlayerManager.HasCharacterForRole(playerId, role)
    local characters = PlayerManager.GetPlayerCharacterSlots(playerId)
    local characterKey = role .. "_1"
    return characters[characterKey] ~= nil
end

--- Clean up character data for a player
--- @param playerId number Player ID
function PlayerManager.CleanupPlayerCharacterData(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if identifier and playerCharacterData[identifier] then
        playerCharacterData[identifier] = nil
        LogPlayerManager(playerId, "cleanup_characters", "Character data cleaned up")
    end
end

-- ====================================================================
-- CHARACTER EDITOR EVENT HANDLERS
-- ====================================================================

RegisterNetEvent('cnr:loadPlayerCharacters')
AddEventHandler('cnr:loadPlayerCharacters', function()
    local playerId = source
    local characters = PlayerManager.GetPlayerCharacterSlots(playerId)
    TriggerClientEvent('cnr:loadedPlayerCharacters', playerId, characters)
end)

RegisterNetEvent('cnr:saveCharacterData')
AddEventHandler('cnr:saveCharacterData', function(characterKey, characterData)
    local playerId = source
    
    -- Extract role from character key
    local role = string.match(characterKey, "^(%w+)_")
    if not role or (role ~= "cop" and role ~= "robber") then
        LogPlayerManager(playerId, "save_character_event", string.format("Invalid character key format: %s", characterKey), Constants.LOG_LEVELS.ERROR)
        return
    end
    
    local success, message = PlayerManager.SavePlayerCharacterSlot(playerId, characterKey, characterData, role)
    
    if success then
        TriggerClientEvent('cnr:characterSaveResult', playerId, true, message)
    else
        TriggerClientEvent('cnr:characterSaveResult', playerId, false, message)
        LogPlayerManager(playerId, "save_character_event", string.format("Failed to save character: %s", message), Constants.LOG_LEVELS.ERROR)
    end
end)

RegisterNetEvent('cnr:deleteCharacterData')
AddEventHandler('cnr:deleteCharacterData', function(characterKey)
    local playerId = source
    local success, message = PlayerManager.DeletePlayerCharacterSlot(playerId, characterKey)
    
    if success then
        TriggerClientEvent('cnr:characterDeleteResult', playerId, true, message)
    else
        TriggerClientEvent('cnr:characterDeleteResult', playerId, false, message)
        LogPlayerManager(playerId, "delete_character_event", string.format("Failed to delete character: %s", message), Constants.LOG_LEVELS.ERROR)
    end
end)

RegisterNetEvent('cnr:applyCharacterToPlayer')
AddEventHandler('cnr:applyCharacterToPlayer', function(characterKey)
    local playerId = source
    local success, message = PlayerManager.ApplyCharacterToPlayer(playerId, characterKey)
    
    if not success then
        LogPlayerManager(playerId, "apply_character_event", string.format("Failed to apply character: %s", message), Constants.LOG_LEVELS.ERROR)
    end
end)

RegisterNetEvent('cnr:getCharacterForRole')
AddEventHandler('cnr:getCharacterForRole', function(role, slot)
    local playerId = source
    local characterData = PlayerManager.GetCharacterForRoleSelection(playerId, role, slot)
    TriggerClientEvent('cnr:receiveCharacterForRole', playerId, characterData)
end)

-- ====================================================================
-- COMPATIBILITY FUNCTIONS
-- ====================================================================

--- Compatibility function for existing GetCnrPlayerData calls
--- @param playerId number Player ID
--- @return table Player data
function GetCnrPlayerData(playerId)
    local playerData, success = PlayerManager.GetPlayerData(playerId)
    return success and playerData or nil
end

--- Compatibility function for existing LoadPlayerData calls
--- @param playerId number Player ID
function LoadPlayerData(playerId)
    PlayerManager.LoadPlayerData(playerId)
end

--- Compatibility function for existing SavePlayerData calls
--- @param playerId number Player ID
function SavePlayerData(playerId)
    PlayerManager.SavePlayerData(playerId, false)
end

--- Compatibility function for immediate saves
--- @param playerId number Player ID
--- @param reason string Save reason
function SavePlayerDataImmediate(playerId, reason)
    PlayerManager.SavePlayerData(playerId, true)
end

--- Compatibility function for role setting
--- @param playerId number Player ID
--- @param role string Role to set
--- @param skipNotify boolean Skip notification
function SetPlayerRole(playerId, role, skipNotify)
    PlayerManager.SetPlayerRole(playerId, role, skipNotify)
end

--- Compatibility functions for moved player utility functions
function GetPlayerLicense(playerId)
    return PlayerManager.GetPlayerLicense(playerId)
end

function GetPlayerMoney(playerId)
    return PlayerManager.GetPlayerMoney(playerId)
end

function AddPlayerMoney(playerId, amount, type)
    return PlayerManager.AddPlayerMoney(playerId, amount, type)
end

function RemovePlayerMoney(playerId, amount, type)
    return PlayerManager.RemovePlayerMoney(playerId, amount, type)
end

function AddPlayerXP(playerId, amount)
    return PlayerManager.AddPlayerXP(playerId, amount)
end

function IsAdmin(playerId)
    return PlayerManager.IsAdmin(playerId)
end

function GetPlayerRole(playerId)
    return PlayerManager.GetPlayerRole(playerId)
end

function IsPlayerCop(playerId)
    return PlayerManager.IsPlayerCop(playerId)
end

function IsPlayerRobber(playerId)
    return PlayerManager.IsPlayerRobber(playerId)
end

-- Global exports for compatibility
_G.GetPlayerLicense = GetPlayerLicense
_G.GetPlayerMoney = GetPlayerMoney
_G.AddPlayerMoney = AddPlayerMoney
_G.RemovePlayerMoney = RemovePlayerMoney
_G.AddPlayerXP = AddPlayerXP
_G.IsAdmin = IsAdmin
_G.GetPlayerRole = GetPlayerRole
_G.IsPlayerCop = IsPlayerCop
_G.IsPlayerRobber = IsPlayerRobber

-- ====================================================================
-- INITIALIZATION
-- ====================================================================

--- Initialize player manager
function PlayerManager.Initialize()
    Log("[CNR_PLAYER_MANAGER] Player Manager initialized")
    
    -- Statistics logging thread
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(10 * Constants.TIME_MS.MINUTE)
            PlayerManager.LogStats()
        end
    end)
end

-- Initialize when loaded
PlayerManager.Initialize()

-- ====================================================================
-- CHARACTER EDITOR COMPATIBILITY FUNCTIONS
-- ====================================================================

--- Compatibility functions for existing character editor calls
function LoadPlayerCharacters(playerId)
    return PlayerManager.LoadPlayerCharacters(playerId)
end

function SavePlayerCharacters(playerId, characterData)
    return PlayerManager.SavePlayerCharacters(playerId, characterData)
end

function ValidateCharacterData(characterData, role)
    return PlayerManager.ValidateCharacterData(characterData, role)
end

function SanitizeCharacterData(characterData)
    return PlayerManager.SanitizeCharacterData(characterData)
end

function GetPlayerCharacterSlots(playerId)
    return PlayerManager.GetPlayerCharacterSlots(playerId)
end

function SavePlayerCharacterSlot(playerId, characterKey, characterData, role)
    return PlayerManager.SavePlayerCharacterSlot(playerId, characterKey, characterData, role)
end

function DeletePlayerCharacterSlot(playerId, characterKey)
    return PlayerManager.DeletePlayerCharacterSlot(playerId, characterKey)
end

function ApplyCharacterToPlayer(playerId, characterKey)
    return PlayerManager.ApplyCharacterToPlayer(playerId, characterKey)
end

function GetCharacterForRoleSelection(playerId, role, slot)
    return PlayerManager.GetCharacterForRoleSelection(playerId, role, slot)
end

function HasCharacterForRole(playerId, role)
    return PlayerManager.HasCharacterForRole(playerId, role)
end

-- ====================================================================
-- EXPORTS
-- ====================================================================

-- Export character editor functions for other scripts
exports('GetPlayerCharacterSlots', GetPlayerCharacterSlots)
exports('SavePlayerCharacterSlot', SavePlayerCharacterSlot)
exports('DeletePlayerCharacterSlot', DeletePlayerCharacterSlot)
exports('ApplyCharacterToPlayer', ApplyCharacterToPlayer)
exports('GetCharacterForRoleSelection', GetCharacterForRoleSelection)
exports('HasCharacterForRole', HasCharacterForRole)

-- ====================================================================
-- ====================================================================

-- Integration status tracking
local integrationStatus = {
    initialized = false,
    modulesLoaded = {},
    migrationComplete = false,
    startTime = 0
}

-- Legacy compatibility layer
local legacyFunctions = {}

--- Initialize all refactored systems in the correct order
function PlayerManager.InitializeIntegration()
    integrationStatus.startTime = GetGameTimer()
    
    Log("[CNR_INTEGRATION] Starting system initialization...", Constants.LOG_LEVELS.INFO)
    
    -- Initialize core systems first
    local initOrder = {
        {name = "Constants", module = Constants, required = true},
        {name = "Validation", module = Validation, required = true},
        {name = "DataManager", module = DataManager, required = true},
        {name = "SecureInventory", module = SecureInventory, required = true},
        {name = "SecureTransactions", module = SecureTransactions, required = true},
        {name = "PlayerManager", module = PlayerManager, required = true},
        {name = "PerformanceManager", module = PerformanceManager, required = false}
    }
    
    for _, system in ipairs(initOrder) do
        local success = PlayerManager.InitializeSystem(system.name, system.module, system.required)
        integrationStatus.modulesLoaded[system.name] = success
        
        if system.required and not success then
            error(string.format("Failed to initialize required system: %s", system.name))
        end
    end
    
    -- Set up legacy compatibility
    PlayerManager.SetupLegacyCompatibility()
    
    -- Perform data migration if needed
    PlayerManager.PerformDataMigration()
    
    -- Start monitoring systems
    PlayerManager.StartMonitoring()
    
    integrationStatus.initialized = true
    local initTime = GetGameTimer() - integrationStatus.startTime
    
    Log(string.format("[CNR_INTEGRATION] System initialization completed in %dms", initTime), Constants.LOG_LEVELS.INFO)
    
    -- Log initialization status
    PlayerManager.LogInitializationStatus()
end

--- Initialize a specific system with error handling
--- @param systemName string Name of the system
--- @param systemModule table System module
--- @param required boolean Whether the system is required
--- @return boolean Success status
function PlayerManager.InitializeSystem(systemName, systemModule, required)
    Log(string.format("[CNR_INTEGRATION] Initializing %s...", systemName), Constants.LOG_LEVELS.INFO)
    
    local success, error = pcall(function()
        if systemModule and systemModule.Initialize then
            systemModule.Initialize()
        end
    end)
    
    if success then
        Log(string.format("[CNR_INTEGRATION] ✅ %s initialized successfully", systemName), Constants.LOG_LEVELS.INFO)
        return true
    else
        local logLevel = required and "error" or "warn"
        Log(string.format("[CNR_INTEGRATION] ❌ Failed to initialize %s: %s", systemName, tostring(error)), logLevel == "error" and Constants.LOG_LEVELS.ERROR or Constants.LOG_LEVELS.WARN)
        return false
    end
end

--- Set up compatibility functions for existing code
function PlayerManager.SetupLegacyCompatibility()
    Log("[CNR_INTEGRATION] Setting up legacy compatibility layer...", Constants.LOG_LEVELS.INFO)
    
    -- Store original functions if they exist
    legacyFunctions.AddItemToPlayerInventory = AddItemToPlayerInventory
    legacyFunctions.RemoveItemFromPlayerInventory = RemoveItemFromPlayerInventory
    legacyFunctions.AddPlayerMoney = AddPlayerMoney
    legacyFunctions.RemovePlayerMoney = RemovePlayerMoney
    
    -- Replace with secure versions
    AddItemToPlayerInventory = function(playerId, itemId, quantity, itemDetails)
        local success, message = SecureInventory.AddItem(playerId, itemId, quantity, "legacy_add")
        return success, message
    end
    
    RemoveItemFromPlayerInventory = function(playerId, itemId, quantity)
        local success, message = SecureInventory.RemoveItem(playerId, itemId, quantity, "legacy_remove")
        return success, message
    end
    
    AddPlayerMoney = function(playerId, amount)
        local success, message = SecureTransactions.AddMoney(playerId, amount, "legacy_add")
        return success
    end
    
    RemovePlayerMoney = function(playerId, amount)
        local success, message = SecureTransactions.RemoveMoney(playerId, amount, "legacy_remove")
        return success
    end
    
    -- Enhanced MarkPlayerForInventorySave compatibility
    MarkPlayerForInventorySave = function(playerId)
        DataManager.MarkPlayerForSave(playerId)
    end
    
    -- InitializePlayerInventory compatibility
    InitializePlayerInventory = function(pData, playerId)
        if not pData then
            Log("[CNR_INTEGRATION] InitializePlayerInventory: pData is nil for playerId " .. (playerId or "unknown"), Constants.LOG_LEVELS.WARN)
            return
        end
        -- Ensure inventory exists in the expected format
        pData.inventory = pData.inventory or {}
        Log("[CNR_INTEGRATION] InitializePlayerInventory: Ensured inventory table exists for player " .. (playerId or "unknown"), Constants.LOG_LEVELS.DEBUG)
    end
    
    Log("[CNR_INTEGRATION] ✅ Legacy compatibility layer established", Constants.LOG_LEVELS.INFO)
end

--- Perform data migration from old format to new format
function PlayerManager.PerformDataMigration()
    Log("[CNR_INTEGRATION] Starting data migration...", Constants.LOG_LEVELS.INFO)
    
    -- Check if migration is needed
    local migrationNeeded = PlayerManager.CheckMigrationNeeded()
    
    if not migrationNeeded then
        Log("[CNR_INTEGRATION] No data migration needed", Constants.LOG_LEVELS.INFO)
        integrationStatus.migrationComplete = true
        return
    end
    
    -- Perform migration
    local success, error = pcall(function()
        PlayerManager.MigrateSystemData()
    end)
    
    if success then
        Log("[CNR_INTEGRATION] ✅ Data migration completed successfully", Constants.LOG_LEVELS.INFO)
        integrationStatus.migrationComplete = true
    else
        Log(string.format("[CNR_INTEGRATION] ❌ Data migration failed: %s", tostring(error)), Constants.LOG_LEVELS.ERROR)
    end
end

--- Check if data migration is needed
--- @return boolean Whether migration is needed
function PlayerManager.CheckMigrationNeeded()
    -- Check for old format files
    local oldFormatFiles = {
        "bans.json",
        "purchase_history.json"
    }
    
    for _, filename in ipairs(oldFormatFiles) do
        local fileData = LoadResourceFile(GetCurrentResourceName(), filename)
        if fileData then
            local success, data = pcall(json.decode, fileData)
            if success and data and not data.version then
                return true -- Old format detected
            end
        end
    end
    
    return false
end

--- Migrate system data files
function PlayerManager.MigrateSystemData()
    Log("Migrating system data...", "info", "CNR_INTEGRATION")
    
    -- Migrate bans.json
    local success, bansData = DataManager.LoadSystemData("bans")
    if success and bansData then
        if not bansData.version then
            bansData.version = Version.CURRENT
            bansData.migrated = os.time()
            DataManager.SaveSystemData("bans", bansData)
            Log("Migrated bans.json", "info", "CNR_INTEGRATION")
        end
    end
    
    -- Migrate purchase_history.json
    local success, purchaseData = DataManager.LoadSystemData("purchases")
    if success and purchaseData then
        if not purchaseData.version then
            purchaseData.version = Version.CURRENT
            purchaseData.migrated = os.time()
            DataManager.SaveSystemData("purchases", purchaseData)
            Log("Migrated purchase_history.json", "info", "CNR_INTEGRATION")
        end
    end
end

--- Start monitoring systems
function PlayerManager.StartMonitoring()
    Log("Starting system monitoring...", "info", "CNR_INTEGRATION")
    
    -- Create monitoring loop using PerformanceManager
    if PerformanceManager then
        PerformanceManager.CreateOptimizedLoop(function()
            PlayerManager.PerformHealthCheck()
        end, 60000, 120000, 3) -- 1 minute base interval, medium priority
        
        PerformanceManager.CreateOptimizedLoop(function()
            PlayerManager.LogSystemStats()
        end, 300000, 600000, 5) -- 5 minute base interval, low priority
    end
end

--- Perform health check on all systems
function PlayerManager.PerformHealthCheck()
    local issues = {}
    
    -- Check each system
    for systemName, loaded in pairs(integrationStatus.modulesLoaded) do
        if not loaded then
            table.insert(issues, string.format("%s not loaded", systemName))
        end
    end
    
    -- Check data integrity
    if DataManager then
        local stats = DataManager.GetStats()
        if stats.failedSaves > 0 then
            table.insert(issues, string.format("DataManager has %d failed saves", stats.failedSaves))
        end
    end
    
    -- Check performance
    if PerformanceManager then
        local metrics = PerformanceManager.GetMetrics()
        if metrics.memoryUsage > Constants.PERFORMANCE.MEMORY_WARNING_THRESHOLD_MB * 1024 then
            table.insert(issues, string.format("High memory usage: %.1fMB", metrics.memoryUsage / 1024))
        end
    end
    
    -- Log issues if any
    if #issues > 0 then
        Log(string.format("Health check found %d issues:", #issues), "warn", "CNR_INTEGRATION")
        for _, issue in ipairs(issues) do
            Log(string.format("- %s", issue), "warn", "CNR_INTEGRATION")
        end
    end
end

--- Log comprehensive system statistics
function PlayerManager.LogSystemStats()
    Log("=== SYSTEM STATISTICS ===", "info", "CNR_INTEGRATION")
    
    -- Integration status
    Log(string.format("Initialized: %s, Migration: %s", 
        tostring(integrationStatus.initialized), 
        tostring(integrationStatus.migrationComplete)), "info", "CNR_INTEGRATION")
    
    -- Module status
    for systemName, loaded in pairs(integrationStatus.modulesLoaded) do
        Log(string.format("%s: %s", systemName, loaded and "✅" or "❌"), "info", "CNR_INTEGRATION")
    end
    
    -- System-specific stats
    if DataManager then DataManager.LogStats() end
    if SecureInventory then SecureInventory.LogStats() end
    if SecureTransactions then SecureTransactions.LogStats() end
    if PlayerManager then PlayerManager.LogStats() end
    if PerformanceManager then PerformanceManager.LogStats() end
    
    Log("=== END STATISTICS ===", "info", "CNR_INTEGRATION")
end

--- Log initialization status
function PlayerManager.LogInitializationStatus()
    Log("=== INITIALIZATION SUMMARY ===", "info", "CNR_INTEGRATION")
    
    local totalSystems = 0
    local loadedSystems = 0
    
    for systemName, loaded in pairs(integrationStatus.modulesLoaded) do
        totalSystems = totalSystems + 1
        if loaded then loadedSystems = loadedSystems + 1 end
        
        Log(string.format("%s: %s", 
            systemName, loaded and "✅ LOADED" or "❌ FAILED"), "info", "CNR_INTEGRATION")
    end
    
    Log(string.format("Systems: %d/%d loaded", loadedSystems, totalSystems), "info", "CNR_INTEGRATION")
    Log(string.format("Migration: %s", 
        integrationStatus.migrationComplete and "✅ COMPLETE" or "❌ PENDING"), "info", "CNR_INTEGRATION")
    Log(string.format("Status: %s", 
        integrationStatus.initialized and "✅ READY" or "❌ NOT READY"), "info", "CNR_INTEGRATION")
    
    Log("=== END SUMMARY ===", "info", "CNR_INTEGRATION")
end

--- Get integration status
--- @return table Integration status information
function PlayerManager.GetIntegrationStatus()
    return {
        initialized = integrationStatus.initialized,
        migrationComplete = integrationStatus.migrationComplete,
        modulesLoaded = integrationStatus.modulesLoaded,
        uptime = GetGameTimer() - integrationStatus.startTime
    }
end

--- Check if all systems are ready
--- @return boolean Whether all systems are ready
function PlayerManager.IsReady()
    if not integrationStatus.initialized then return false end
    if not integrationStatus.migrationComplete then return false end
    
    for _, loaded in pairs(integrationStatus.modulesLoaded) do
        if not loaded then return false end
    end
    
    return true
end

--- Cleanup all systems on resource stop
function PlayerManager.CleanupIntegration()
    Log("Starting system cleanup...", "info", "CNR_INTEGRATION")
    
    -- Cleanup systems in reverse order
    local cleanupOrder = {
        "PerformanceManager", "PlayerManager", "SecureTransactions",
        "SecureInventory", "DataManager", "Validation"
    }
    
    for _, systemName in ipairs(cleanupOrder) do
        local system = _G[systemName]
        if system and system.Cleanup then
            local success, error = pcall(system.Cleanup)
            if success then
                Log(string.format("✅ %s cleaned up", systemName), "info", "CNR_INTEGRATION")
            else
                Log(string.format("❌ %s cleanup failed: %s", systemName, tostring(error)), "error", "CNR_INTEGRATION")
            end
        end
    end
    
    Log("System cleanup completed", "info", "CNR_INTEGRATION")
end

-- ====================================================================
-- ====================================================================

--- Handle resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Small delay to ensure all scripts are loaded
        Citizen.SetTimeout(1000, function()
            PlayerManager.InitializeIntegration()
        end)
    end
end)

--- Handle resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        PlayerManager.CleanupIntegration()
    end
end)

-- PlayerManager module is now available globally
