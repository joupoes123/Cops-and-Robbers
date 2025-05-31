-- server.lua
-- Cops & Robbers FiveM Game Mode - Server Script
-- Version: 1.1 | Date: 2025-02-11
-- This file handles core server-side logic including player data management,
-- game state, event handling, and interactions with configuration.

-- =====================================
--         CONFIGURATION NOTES
-- =====================================
-- Ensure that config.lua is loaded before server.lua.
-- This is typically handled by the order of scripts in fxmanifest.lua.
-- Example from fxmanifest.lua:
-- shared_scripts {
--     '@ox_lib/init.lua', -- If using ox_lib for features like JSON
--     'config.lua'        -- Must be loaded before server.lua if server.lua uses Config.* at global scope
-- }
-- server_scripts {
--     'server.lua',
--     'admin.lua'         -- admin.lua might depend on events/vars in server.lua
-- }

-- =====================================
--         LOGGING FUNCTION
-- =====================================
-- Logs a given text string to actions.log and the server console with a timestamp.
-- @param text string: The text to log.
function LogAdminAction(text)
    local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
    local logLine = timestamp .. text

    -- Append to actions.log file.
    -- Using SaveResourceFile with -1 length appends to the file.
    local success = SaveResourceFile(GetCurrentResourceName(), "actions.log", logLine .. "\n", -1)
    if not success then
        print("Error: Failed to save to actions.log for resource " .. GetCurrentResourceName())
    end
    print(logLine) -- Also print to server console for real-time view.
end

-- =====================================
--         GLOBAL STATE VARIABLES
-- =====================================
-- These tables store the dynamic state of the game mode.
-- They are local to this script's scope but act as global state containers for the resource.

-- Player-specific data, keyed by player server ID.
local playerData                    = {} -- Stores data like money, inventory, weapons, wanted status, role, XP, level, perks.
                                         -- Example: { [playerId] = { money=5000, inventory={...}, weapons={...}, wantedPoints=0, ... } }

-- Quick lookups for roles.
local cops                          = {} -- { [playerId] = true }
local robbers                       = {} -- { [playerId] = true }
local playerRoles                   = {} -- { [playerId] = "cop" or "robber" } -- More explicit role storage.

-- Player runtime information.
local playerPositions               = {} -- { [playerId] = { position = vector3, clientReportedWantedLevel = number } } -- Client reported wanted level can be stale.
local playerStats                   = {} -- { [playerId] = { heists=0, arrests=0, rewards=0 } } -- Basic gameplay stats. XP/Level are in playerData.
local playerUpdateTimestamps        = {} -- { [playerId] = timestamp } -- For throttling frequent events like position updates.

-- Cooldowns and Timers.
local heistCooldowns                = {} -- { [playerId_or_heistKey] = timestamp } -- For player-specific or global heist cooldowns.
local purchaseHistory               = {} -- { [itemId] = { purchaseTimestamp1, purchaseTimestamp2, ... } } -- For dynamic pricing.
local bannedPlayers                 = {} -- { [identifierString] = { reason="...", timestamp=os.time(), adminName="..." } } -- Loaded from bans.json and Config.BannedPlayers.

-- Feature-specific state tables.
local deployedSpikeStrips           = {} -- { [stripId] = { id, ownerPlayerId, location, expirationTimer } }
local spikeStripCounter             = 0  -- Simple incremental ID generator for spike strips.
local playerSpikeStripCount         = {} -- { [playerId] = count } -- Tracks number of currently deployed spike strips by a player.

local activeContrabandDrops         = {} -- { [dropId] = { id, location, itemConfig, playersCollecting = { [playerId]=startTime } } }
local nextContrabandDropTimestamp   = 0  -- Game timer for the next scheduled contraband drop.

local activeNPCResponseGroups       = {} -- Manages currently active NPC police groups for wanted players. Structure depends on management needs.
local playerCorruptOfficialCooldowns= {} -- { [playerId] = { [officialIndex] = gameTimerTimestamp } }
local playerAppearanceChangeCooldowns = {} -- { [playerId] = { [storeIndex] = gameTimerTimestamp } }
local activeSubdues                 = {} -- { [robberId] = { copId = copId, timer = subdueTimer } } -- Tracks active subdue attempts.
local activeK9s                     = {} -- { [copId] = true } -- Simplified tracking if a cop has an authorized K9.
local robberyCooldownsStore         = {} -- { [storeIndex] = os.time()_timestamp } -- Cooldowns for individual stores.
local activeStoreRobberies          = {} -- { [robberId] = { storeConfig, successTimer } } -- Tracks active store robberies by player.
local powerGridStatus               = {} -- { [gridIndex] = { onCooldownUntil = os.time()_timestamp, isDown = boolean } } -- Tracks power grid states.

-- Armored Car Heist State
local armoredCarActive              = false -- Is an armored car event currently active?
local armoredCarEntityNetId         = nil   -- Network ID of the armored car entity. (Using NetID for cross-script reference if needed)
local armoredCarHeistCooldownTimer  = 0     -- os.time() timestamp until the next heist can naturally occur.
local armoredCarCurrentHealth       = 0     -- Server-side tracking of armored car health.


-- =====================================
--      CONFIG ITEMS INDEXING
-- =====================================
-- Build a lookup table for Config.Items for faster access by itemId.
-- This is done at script start for efficiency.
local ConfigItemsById = {}
if Config and Config.Items and type(Config.Items) == "table" then
    for _, item in ipairs(Config.Items) do
        if item and item.itemId then -- Ensure item and itemId are valid
            ConfigItemsById[item.itemId] = item
        else
            print("Warning: Invalid item found in Config.Items during indexing: " .. json.encode(item or "nil"))
        end
    end
    -- print("Config.Items indexed successfully. " .. tablelength(ConfigItemsById) .. " items loaded.") -- For debugging
else
    print("CRITICAL ERROR: Config.Items is not loaded or is not a table. Ensure config.lua is correct and loaded before server.lua. Many features will fail.")
end

-- =====================================
--           HELPER FUNCTIONS
-- =====================================

-- Checks if a table (typically an array, uses ipairs) contains a specific value.
-- @param tbl table: The table to check.
-- @param value any: The value to search for.
-- @return boolean: True if the value is found, false otherwise.
local function hasValue(tbl, value)
    if not tbl or type(tbl) ~= "table" then
        print(string.format("Error: hasValue received non-table or nil. Type: %s", type(tbl)))
        return false
    end
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Retrieves a predefined ammo count for a given ammo item ID (e.g., "ammo_pistol").
-- These are default "clip" sizes when ammo is purchased or granted.
-- @param ammoId string: The item ID of the ammunition.
-- @return number: The quantity of ammo to grant, or 0 if not defined.
local function getAmmoCountForItem(ammoId)
    -- Consider moving this table to Config.lua if it needs to be more configurable.
    local ammoCounts = {
        ammo_pistol  = 24,
        ammo_smg     = 60,
        ammo_rifle   = 60,
        ammo_shotgun = 16,
        ammo_sniper  = 10,
        -- Add more ammo types as needed, matching itemIds in Config.Items
    }
    return ammoCounts[ammoId] or 0 -- Return 0 if no specific count is defined for the ammoId.
end

-- Calculates the number of key-value pairs in a table (useful for non-indexed tables where # might not work as expected).
-- @param T table: The table to count.
-- @return number: The number of key-value pairs, or 0 if T is not a table.
local function tablelength(T)
    if not T or type(T) ~= "table" then
        print(string.format("Error: tablelength received non-table or nil. Type: %s", type(T)))
        return 0
    end
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

-- Initializes the purchase history table structure for all items defined in Config.Items.
-- This ensures that each item has an entry in purchaseHistory, even if no purchases have been made.
-- Called on resource start if loading from file fails or the file doesn't exist.
local function initializePurchaseData()
    if not Config or not Config.Items or type(Config.Items) ~= "table" then
        print("Error in initializePurchaseData: Config.Items not available or not a table. Purchase history might be incomplete.")
        return
    end
    purchaseHistory = purchaseHistory or {} -- Ensure purchaseHistory itself is a table
    for _, item in ipairs(Config.Items) do
        if item and item.itemId then
            if purchaseHistory[item.itemId] == nil then -- Only initialize if not already loaded (e.g. from file)
                purchaseHistory[item.itemId] = {}
            end
        end
    end
end

-- Saves the current state of the bannedPlayers table to bans.json.
-- Uses JSON encoding for storage.
local function saveBans()
    local jsonData = json.encode(bannedPlayers, { indent = true }) -- Use indent for readability
    if jsonData then
        local success = SaveResourceFile(GetCurrentResourceName(), "bans.json", jsonData, -1) -- Length -1 should overwrite
        if not success then
            print("Error: Failed to save bans.json for resource " .. GetCurrentResourceName())
        end
    else
        print("Error: Could not encode bannedPlayers to JSON for resource " .. GetCurrentResourceName())
    end
end

-- Loads player data from a JSON file based on their primary identifier (e.g., license or steam ID).
-- Initializes with default data if no file exists, if the file is empty, or if decoding fails.
-- Merges loaded data with defaults to ensure all necessary fields are present.
-- @param source number: The player's server ID.
local function loadPlayerData(source)
    local identifiers = GetPlayerIdentifiers(source)
    if not identifiers or #identifiers == 0 then
        print(string.format("Error: loadPlayerData - Could not retrieve identifiers for player source %s. Cannot load data.", tostring(source)))
        -- Potentially kick player or assign temporary data if identifiers are crucial.
        -- For now, will proceed with default data but log this as a critical issue if it happens.
        -- playerData[source] = { ... default temporary structure ... }
        return
    end

    -- Prefer license identifier if available, otherwise use the first one.
    local primaryIdentifier = identifiers[1] -- Default to first identifier
    for _, idStr in ipairs(identifiers) do
        if string.sub(idStr, 1, string.len("license:")) == "license:" then
            primaryIdentifier = idStr
            break
        end
    end

    -- Default data structure for new players or if loading fails.
    -- Ensures all expected fields are present.
    local defaultData = {
        money                 = Config.DefaultStartMoney or 2500,
        inventory             = {}, -- { [itemId] = quantity }
        weapons               = {}, -- { [weaponHashString] = true }
        wantedPoints          = 0,
        currentWantedStars    = 0,
        lastCrimeTimestamp    = 0,  -- Game timer for last crime
        lastSeenByCopTimestamp= 0,  -- Game timer for last cop sight (for wanted decay)
        role                  = nil,-- "cop" or "robber", to be set by player or admin
        xp                    = 0,
        level                 = 1,
        unlockedPerks         = {}, -- { [perkId] = true/value }
        stats                 = { heists = 0, arrests = 0, rewards = 0 } -- Separate stats sub-table
    }

    local filePath = "player_data/" .. primaryIdentifier .. ".json"
    local fileData = LoadResourceFile(GetCurrentResourceName(), filePath)
    local dataToUse = defaultData -- Start with defaults

    if fileData and fileData ~= "" then
        local success, loadedData = pcall(json.decode, fileData)
        if success and loadedData and type(loadedData) == "table" then
            -- Merge loaded data with default data to ensure all keys exist and handle schema changes.
            for k, v_default in pairs(defaultData) do
                if loadedData[k] == nil then -- If key from default is missing in loaded, add it.
                    loadedData[k] = v_default
                elseif type(v_default) == "table" and type(loadedData[k]) == "table" then -- If both are tables, merge them.
                    for sub_k, sub_v_default in pairs(v_default) do
                        if loadedData[k][sub_k] == nil then
                            loadedData[k][sub_k] = sub_v_default
                        end
                    end
                end
            end
            dataToUse = loadedData
            -- print(string.format("Successfully loaded and merged player data for %s (Source: %s)", primaryIdentifier, tostring(source))) -- Debug
        else
            print(string.format("Error: Failed to decode JSON for player %s (Source: %s). File content: '%s'. Using default data.", primaryIdentifier, tostring(source), fileData:sub(1,200)))
        end
    else
        -- print(string.format("No player data file found for %s (Source: %s). Initializing with default data.", primaryIdentifier, tostring(source))) -- Debug
    end

    -- Final checks for critical sub-tables to prevent runtime errors.
    dataToUse.inventory = dataToUse.inventory or {}
    dataToUse.weapons = dataToUse.weapons or {}
    dataToUse.unlockedPerks = dataToUse.unlockedPerks or {}
    dataToUse.stats = dataToUse.stats or { heists = 0, arrests = 0, rewards = 0 }
    if dataToUse.xp == nil then dataToUse.xp = 0 end
    if dataToUse.level == nil then dataToUse.level = 1 end

    playerData[source] = dataToUse
end

-- Saves a player's current data to a JSON file named after their primary identifier.
-- @param source number: The player's server ID.
local function savePlayerData(source)
    local data = playerData[source]
    if not data then
        print(string.format("Error: savePlayerData - No data found in memory for player source %s. Cannot save.", tostring(source)))
        return
    end

    local identifiers = GetPlayerIdentifiers(source)
    if not identifiers or #identifiers == 0 then
        print(string.format("Error: savePlayerData - Could not retrieve identifiers for player source %s. Cannot save.", tostring(source)))
        return
    end

    local primaryIdentifier = identifiers[1]
    for _, idStr in ipairs(identifiers) do
        if string.sub(idStr, 1, string.len("license:")) == "license:" then
            primaryIdentifier = idStr
            break
        end
    end

    local filePath = "player_data/" .. primaryIdentifier .. ".json"
    local jsonData = json.encode(data, { indent = true }) -- Encode with indentation for readability.

    if jsonData then
        -- Ensure the player_data directory exists. This is usually handled by resource structure,
        -- but server write errors might occur if not. (Handled by FiveM resource system mostly)
        local success = SaveResourceFile(GetCurrentResourceName(), filePath, jsonData, -1) -- Length -1 overwrites the file.
        if not success then
            print(string.format("CRITICAL ERROR: Failed to save player data to %s for resource %s. Check permissions and file path.", filePath, GetCurrentResourceName()))
        -- else
            -- print(string.format("Successfully saved player data for %s (Source: %s)", primaryIdentifier, tostring(source))) -- Debug, can be spammy
        end
    else
        print(string.format("CRITICAL ERROR: Could not encode player data to JSON for player %s (Source: %s). Data not saved.", primaryIdentifier, tostring(source)))
    end
end

-- Retrieves a player's data from the in-memory store.
-- @param source number: The player's server ID.
-- @return table|nil: The player's data table, or nil if not found.
local function getPlayerData(source)
    if not playerData[source] then
        -- This can happen if accessed before player is fully loaded or after disconnect.
        -- Depending on usage, might want to print an error or just return nil silently.
        -- Consider if this should attempt a loadPlayerData(source) if data is nil, though that implies synchronous file I/O which is bad.
        -- print(string.format("Warning: getPlayerData requested for source %s but no data found in memory.", tostring(source))) -- Debug
    end
    return playerData[source]
end

-----------------------------------------------------------
-- Wanted System Functions
-----------------------------------------------------------

-- Updates a player's wanted star level based on their current wanted points.
-- Notifies the client to update their display and triggers NPC response updates if star level changes.
-- @param playerId number: The server ID of the player.
local function UpdatePlayerWantedLevel(playerId)
    local pData = getPlayerData(playerId) -- Use the helper function for consistency
    if not pData then
        print(string.format("Error: UpdatePlayerWantedLevel - No player data found for playerId %s.", tostring(playerId)))
        return
    end

    local currentPoints = pData.wantedPoints or 0
    local newStarLevel = 0

    if not Config.WantedSettings or not Config.WantedSettings.levels or type(Config.WantedSettings.levels) ~= "table" then
        print("Error: UpdatePlayerWantedLevel - Config.WantedSettings.levels is not defined or not a table.")
        return
    end

    -- Determine new star level based on points thresholds (from highest to lowest)
    for i = #Config.WantedSettings.levels, 1, -1 do
        local levelInfo = Config.WantedSettings.levels[i]
        if levelInfo and type(levelInfo) == "table" and levelInfo.threshold and currentPoints >= levelInfo.threshold then
            newStarLevel = levelInfo.stars or 0
            break
        end
    end

    local oldStarLevel = pData.currentWantedStars or 0

    -- Trigger client update if star level OR points changed since last notification to client.
    if oldStarLevel ~= newStarLevel or pData.lastNotifiedWantedPoints ~= currentPoints then
        pData.currentWantedStars = newStarLevel
        pData.lastNotifiedWantedPoints = currentPoints -- Track last notified points to avoid redundant client updates for point changes within the same star level.

        TriggerClientEvent('cops_and_robbers:updateWantedDisplay', playerId, newStarLevel, currentPoints)
        LogAdminAction(string.format("Wanted Level Update: Player %s (ID: %d) now %d stars, %d points.", GetPlayerName(playerId) or "N/A", playerId, newStarLevel, currentPoints))

        -- Trigger NPC response update if star level changes (up, down, or to/from zero).
        if newStarLevel ~= oldStarLevel then
            local playerPosData = playerPositions[playerId]
            local playerCoords = playerPosData and playerPosData.position or nil
            if playerCoords and type(playerCoords) == "table" and playerCoords.x then -- Basic validation of coords
                -- Server can manage/throttle activeNPCResponseGroups count here if needed.
                TriggerClientEvent('cops_and_robbers:wantedLevelResponseUpdate', playerId, newStarLevel, currentPoints, playerCoords)
            else
                print(string.format("Warning: UpdatePlayerWantedLevel - No valid known coordinates for player %s (ID: %d) to send NPC response.", GetPlayerName(playerId) or "N/A", playerId))
            end
        end
        -- No savePlayerData(playerId) here; should be called by the function that modified wantedPoints.
    end
end

-- Increases a player's wanted points for a specific crime.
-- Updates their wanted level and saves their data.
-- @param playerId number: The server ID of the player.
-- @param crimeTypeKey string: The key corresponding to an entry in Config.WantedSettings.crimes.
local function IncreaseWantedPoints(playerId, crimeTypeKey)
    local pData = getPlayerData(playerId)
    if not pData then
        print(string.format("Error: IncreaseWantedPoints - No player data found for playerId %s.", tostring(playerId)))
        return
    end

    if not Config.WantedSettings or not Config.WantedSettings.crimes or type(Config.WantedSettings.crimes) ~= "table" or
       not Config.WantedSettings.crimes[crimeTypeKey] or type(Config.WantedSettings.crimes[crimeTypeKey]) ~= "number" then
        print(string.format("Error: IncreaseWantedPoints - Invalid crimeTypeKey '%s' or Config.WantedSettings.crimes not correctly defined.", tostring(crimeTypeKey)))
        return
    end

    local pointsToAdd = Config.WantedSettings.crimes[crimeTypeKey]
    pData.wantedPoints = (pData.wantedPoints or 0) + pointsToAdd
    pData.lastCrimeTimestamp = GetGameTimer() -- Update timestamp of last criminal activity for decay logic.

    LogAdminAction(string.format("Wanted Points Increased: Player %s (ID: %d) +%d for '%s'. Total: %d.", GetPlayerName(playerId) or "N/A", playerId, pointsToAdd, crimeTypeKey, pData.wantedPoints))
    UpdatePlayerWantedLevel(playerId) -- Update star display and NPC response.
    savePlayerData(playerId)          -- Persist changes.
end

-----------------------------------------------------------
-- Basic Player Economy & Item Functions (Wrappers around playerData)
-- Note: These are low-level helpers. Higher-level functions (like purchaseItem) should call these AND savePlayerData.
-----------------------------------------------------------

-----------------------------------------------------------
-- Player Leveling System Core Functions
-----------------------------------------------------------

-- Applies any unlocks defined in Config.LevelUnlocks for a player reaching a new level.
-- Notifies the player about their unlocks.
-- @param playerId number: The server ID of the player.
-- @param newLevel number: The new level the player has reached.
local function ApplyLevelUnlocks(playerId, newLevel)
    local pData = getPlayerData(playerId)
    if not pData or not pData.role then
        print(string.format("Error: ApplyLevelUnlocks - Player data or role not found for ID %s.", tostring(playerId)))
        return
    end

    if not Config.LevelingSystemEnabled then return end -- System disabled
    if not Config.LevelUnlocks or type(Config.LevelUnlocks) ~= "table" or
       not Config.LevelUnlocks[pData.role] or type(Config.LevelUnlocks[pData.role]) ~= "table" then
        -- No unlocks defined for this role, or LevelUnlocks table is missing/malformed.
        -- print(string.format("Debug: No LevelUnlocks defined for role %s or table malformed.", pData.role)) -- Optional debug
        return
    end

    local unlocksForLevel = Config.LevelUnlocks[pData.role][newLevel]
    if unlocksForLevel and type(unlocksForLevel) == "table" then
        for _, unlockInfo in ipairs(unlocksForLevel) do
            if unlockInfo and type(unlockInfo) == "table" and unlockInfo.type then
                local unlockMessage = unlockInfo.message or ("New Unlock: " .. (unlockInfo.itemId or unlockInfo.perkId or unlockInfo.name or "Perk/Item"))

                LogAdminAction(string.format("Level Unlock: Player %s (ID: %d, Role: %s, Level: %d) unlocked '%s'. Details: %s",
                                GetPlayerName(playerId) or "N/A", playerId, pData.role, newLevel, unlockInfo.type, json.encode(unlockInfo)))
                TriggerClientEvent('chat:addMessage', playerId, { args = { "^3[LEVEL UNLOCK]^7", unlockMessage } })

                if unlockInfo.type == "passive_perk" and unlockInfo.perkId then
                    pData.unlockedPerks = pData.unlockedPerks or {} -- Ensure perks table exists
                    pData.unlockedPerks[unlockInfo.perkId] = unlockInfo.value or true -- Store perk value or true if it's just a flag
                    -- LogAdminAction(string.format("Passive perk '%s' (value: %s) applied to player %s.",
                    --                 unlockInfo.perkId, tostring(pData.unlockedPerks[unlockInfo.perkId]), GetPlayerName(playerId)))
                elseif unlockInfo.type == "item_access" and unlockInfo.itemId then
                    -- Item access is typically handled by store logic checking player level against item.minLevelCop/Robber.
                    -- No specific server-side flag needed in pData unless other systems use it directly.
                    -- LogAdminAction(string.format("Item access for '%s' noted for player %s (shop will verify level).",
                    --                 unlockInfo.itemId, GetPlayerName(playerId)))
                elseif unlockInfo.type == "vehicle_access" and unlockInfo.vehicleHash then
                    -- Vehicle access is handled by vehicle shops/spawners checking player level.
                    -- LogAdminAction(string.format("Vehicle access for '%s' (%s) noted for player %s (spawners will verify level).",
                    --                 unlockInfo.name or unlockInfo.vehicleHash, unlockInfo.vehicleHash, GetPlayerName(playerId)))
                else
                    print(string.format("Warning: ApplyLevelUnlocks - Unknown unlock type '%s' for player %s, level %d.", unlockInfo.type, playerId, newLevel))
                end
                -- Other unlock types (e.g., direct item grant, money reward) could be added here.
            end
        end
        -- savePlayerData(playerId) is called by AddXP after all level ups and unlocks are processed.
    end
end

-- Checks if a player has enough XP to level up and processes the level up.
-- Recursively calls itself if multiple level-ups are possible due to large XP gain.
-- Assumes Config.XPTable[level] is the XP needed to complete (level-1) and reach 'level'.
-- @param playerId number: The server ID of the player.
-- @return boolean: True if a level up occurred, false otherwise.
local function CheckForLevelUp(playerId)
    local pData = getPlayerData(playerId)
    if not pData or not Config.LevelingSystemEnabled or not Config.XPTable or type(Config.XPTable) ~= "table" or not Config.MaxLevel then
        print(string.format("Error: CheckForLevelUp - Player data (ID: %s) or leveling system config missing/invalid.", tostring(playerId)))
        return false
    end

    if pData.level >= Config.MaxLevel then
        return false -- Already at max level
    end

    -- XP needed to complete the current level and reach (pData.level + 1)
    local xpNeededForNextLevelSegment = Config.XPTable[pData.level + 1]

    if not xpNeededForNextLevelSegment or type(xpNeededForNextLevelSegment) ~= "number" then
        print(string.format("Error: CheckForLevelUp - XP requirement for level %d not found or invalid in Config.XPTable.", pData.level + 1))
        return false -- Cannot determine XP needed for next level
    end

    if pData.xp >= xpNeededForNextLevelSegment then
        pData.level = pData.level + 1
        pData.xp = pData.xp - xpNeededForNextLevelSegment -- XP carries over to the new level's progress.

        LogAdminAction(string.format("Level Up: Player %s (ID: %d) reached Level %d! Remaining XP for current level progress: %d.",
                        GetPlayerName(playerId) or "N/A", playerId, pData.level, pData.xp))
        TriggerClientEvent('cops_and_robbers:playerLeveledUp', playerId, pData.level, GetPlayerName(playerId) or "N/A")

        ApplyLevelUnlocks(playerId, pData.level) -- Apply any unlocks for the new level.

        -- Recursively check for further level-ups if player gained substantial XP.
        CheckForLevelUp(playerId)
        return true -- A level-up occurred.
    end
    return false -- No level-up this time.
end


-- Adds XP to a player for a specific action and checks for level ups.
-- Notifies the client about XP changes.
-- @param playerId number: The server ID of the player.
-- @param actionKey string: The key for the action performed (e.g., "successful_store_robbery_medium").
local function AddXP(playerId, actionKey)
    local pData = getPlayerData(playerId)
    if not pData or not Config.LevelingSystemEnabled then
        -- print(string.format("Debug: AddXP - Leveling system disabled or no player data for ID %s.", tostring(playerId))) -- Optional
        return
    end

    local playerRole = pData.role
    local roleXpActionsTable
    if playerRole == 'robber' then
        roleXpActionsTable = Config.XPActionsRobber
    elseif playerRole == 'cop' then
        roleXpActionsTable = Config.XPActionsCop
    else
        -- print(string.format("Warning: AddXP - Player %s (ID: %s) has no valid role for XP gain.", GetPlayerName(playerId) or "N/A", playerId)) -- Optional
        return -- No valid role for XP gain.
    end

    if not roleXpActionsTable or type(roleXpActionsTable) ~= "table" then
        print(string.format("Error: AddXP - XP actions table for role '%s' is not configured correctly.", tostring(playerRole)))
        return
    end

    local xpAmount = roleXpActionsTable[actionKey]
    if xpAmount and type(xpAmount) == "number" and xpAmount > 0 then
        pData.xp = (pData.xp or 0) + xpAmount
        LogAdminAction(string.format("XP Gained: Player %s (ID: %d, Role: %s) +%d XP for action '%s'. Total XP: %d, Level: %d.",
                        GetPlayerName(playerId) or "N/A", playerId, playerRole, xpAmount, actionKey, pData.xp, pData.level))

        CheckForLevelUp(playerId) -- This will handle level ups and recursive checks.

        -- Determine XP needed for the *current* next level segment for UI display purposes.
        local xpForNextLevelSegmentDisplay
        if pData.level >= Config.MaxLevel then
            xpForNextLevelSegmentDisplay = pData.xp -- At max level, client can show this as "Max" or current XP.
        else
            xpForNextLevelSegmentDisplay = Config.XPTable[pData.level + 1] or "Error" -- XP needed to complete current level.
        end

        TriggerClientEvent('cops_and_robbers:updateXPDisplay', playerId, pData.level, pData.xp, xpForNextLevelSegmentDisplay)
        savePlayerData(playerId) -- Save player data after XP change and potential level up.
    elseif not xpAmount then
        print(string.format("Warning: AddXP - No XP amount defined for actionKey '%s' for role '%s'.", tostring(actionKey), playerRole))
    end
end

-- Adds a specified amount of money to a player's account.
-- @param source number: The player's server ID.
-- @param amount number: The amount of money to add. Must be positive.
-- @return boolean: True if money was added, false otherwise (e.g., invalid amount, no player data).
local function addPlayerMoney(source, amount)
    local data = getPlayerData(source)
    if not data then
        print(string.format("Error: addPlayerMoney - No player data for source %s.", tostring(source)))
        return false
    end
    if type(amount) ~= "number" or amount <= 0 then
        print(string.format("Error: addPlayerMoney - Invalid amount %s for source %s.", tostring(amount), tostring(source)))
        return false
    end

    data.money = (data.money or 0) + amount
    -- Caller should handle savePlayerData(source) if it's the end of an operation.
    return true
end

-- Removes a specified amount of money from a player's account.
-- Ensures money does not go below zero.
-- @param source number: The player's server ID.
-- @param amount number: The amount of money to remove. Must be positive.
-- @return boolean: True if money was removed or adjusted, false otherwise.
local function removePlayerMoney(source, amount)
    local data = getPlayerData(source)
    if not data then
        print(string.format("Error: removePlayerMoney - No player data for source %s.", tostring(source)))
        return false
    end
    if type(amount) ~= "number" or amount <= 0 then
        print(string.format("Error: removePlayerMoney - Invalid amount %s for source %s.", tostring(amount), tostring(source)))
        return false
    end

    data.money = (data.money or 0) - amount
    if data.money < 0 then
        data.money = 0
    end
    -- Caller should handle savePlayerData(source).
    return true
end

-- Retrieves a player's current money.
-- @param source number: The player's server ID.
-- @return number: The player's money, or 0 if data not found or money not set.
local function getPlayerMoney(source)
    local data = getPlayerData(source)
    return (data and data.money) or 0
end

-- Adds an item with a specified quantity to a player's inventory.
-- @param source number: The player's server ID.
-- @param itemId string: The ID of the item to add.
-- @param quantity number: The quantity of the item to add. Must be positive.
-- @return boolean: True if item was added, false otherwise.
local function addPlayerInventoryItem(source, itemId, quantity)
    local data = getPlayerData(source)
    if not data then
        print(string.format("Error: addPlayerInventoryItem - No player data for source %s.", tostring(source)))
        return false
    end
    if not itemId or type(itemId) ~= "string" then
        print(string.format("Error: addPlayerInventoryItem - Invalid itemId %s for source %s.", tostring(itemId), tostring(source)))
        return false
    end
    if type(quantity) ~= "number" or quantity <= 0 then
        print(string.format("Error: addPlayerInventoryItem - Invalid quantity %s for item %s, source %s.", tostring(quantity), itemId, tostring(source)))
        return false
    end

    data.inventory = data.inventory or {} -- Ensure inventory table exists.
    data.inventory[itemId] = (data.inventory[itemId] or 0) + quantity
    -- Caller should handle savePlayerData(source).
    return true
end

-- Removes an item with a specified quantity from a player's inventory.
-- If quantity reduces item count to 0 or less, the item is removed from inventory.
-- @param source number: The player's server ID.
-- @param itemId string: The ID of the item to remove.
-- @param quantity number: The quantity of the item to remove. Must be positive.
-- @return boolean: True if item was removed or quantity reduced, false otherwise.
local function removePlayerInventoryItem(source, itemId, quantity)
    local data = getPlayerData(source)
    if not data or not data.inventory or not data.inventory[itemId] then
        -- print(string.format("Warning: removePlayerInventoryItem - Player %s does not have item %s or no inventory.", tostring(source), tostring(itemId))) -- Can be spammy
        return false
    end
    if type(quantity) ~= "number" or quantity <= 0 then
        print(string.format("Error: removePlayerInventoryItem - Invalid quantity %s for item %s, source %s.", tostring(quantity), itemId, tostring(source)))
        return false
    end

    if data.inventory[itemId] > quantity then
        data.inventory[itemId] = data.inventory[itemId] - quantity
    else
        data.inventory[itemId] = nil -- Remove item if count is zero or less after subtraction.
    end
    -- Caller should handle savePlayerData(source).
    return true
end

-- Retrieves the count of a specific item in a player's inventory.
-- @param source number: The player's server ID.
-- @param itemId string: The ID of the item to check.
-- @return number: The count of the item, or 0 if not found or data missing.
local function getPlayerInventoryItemCount(source, itemId)
    local data = getPlayerData(source)
    return (data and data.inventory and data.inventory[itemId]) or 0
end

-- Adds a weapon to a player's weapon list and triggers client-side weapon grant.
-- Does not handle ammo here; ammo should be managed separately or via givePlayerItem.
-- @param source number: The player's server ID.
-- @param weaponName string: The hash/name of the weapon (should match an itemId in Config.Items).
-- @param ammoCount number (optional): Amount of ammo to give with the weapon. Defaults to 0.
-- @return boolean: True if weapon was added, false otherwise.
local function addPlayerWeapon(source, weaponName, ammoCount)
    local data = getPlayerData(source)
    if not data then
        print(string.format("Error: addPlayerWeapon - No player data for source %s.", tostring(source)))
        return false
    end
    if not weaponName or type(weaponName) ~= "string" then
        print(string.format("Error: addPlayerWeapon - Invalid weaponName %s for source %s.", tostring(weaponName), tostring(source)))
        return false
    end

    ammoCount = tonumber(ammoCount) or 0 -- Default to 0 if not specified or invalid

    data.weapons = data.weapons or {} -- Ensure weapons table exists.
    data.weapons[weaponName] = true   -- Mark weapon as possessed.
    TriggerClientEvent('cops_and_robbers:addWeapon', source, weaponName, ammoCount) -- Notify client to give weapon with ammo.
    -- Caller should handle savePlayerData(source).
    return true
end

-- Removes a weapon from a player's weapon list and triggers client-side weapon removal.
-- Also removes associated ammo from client-side tracking if any (client handles actual ammo removal).
-- @param source number: The player's server ID.
-- @param weaponName string: The hash/name of the weapon.
-- @return boolean: True if weapon was marked for removal, false otherwise.
local function removePlayerWeapon(source, weaponName)
    local data = getPlayerData(source)
    if not data or not data.weapons or not data.weapons[weaponName] then
        -- print(string.format("Warning: removePlayerWeapon - Player %s does not have weapon %s.", tostring(source), weaponName)) -- Can be spammy
        return false
    end
    if not weaponName or type(weaponName) ~= "string" then
        print(string.format("Error: removePlayerWeapon - Invalid weaponName %s for source %s.", tostring(weaponName), tostring(source)))
        return false
    end

    data.weapons[weaponName] = nil -- Remove weapon from server-side list.
    TriggerClientEvent('cops_and_robbers:removeWeapon', source, weaponName) -- Notify client to remove weapon.
    -- Caller should handle savePlayerData(source).
    return true
end

-- Checks if a player currently possesses a specific weapon according to server-side data.
-- @param source number: The player's server ID.
-- @param weaponName string: The hash/name of the weapon.
-- @return boolean: True if the player has the weapon, false otherwise.
local function playerHasWeapon(source, weaponName)
    local data = getPlayerData(source)
    return (data and data.weapons and data.weapons[weaponName] == true) or false
end

-- Retrieves item details from the pre-indexed ConfigItemsById table.
-- @param itemId string: The ID of the item.
-- @return table|nil: The item's configuration table from Config.Items, or nil if not found.
local function getItemById(itemId)
    if not itemId or type(itemId) ~= "string" then
        -- print("Warning: getItemById received invalid itemId type: " .. type(itemId)) -- Optional debug
        return nil
    end
    return ConfigItemsById[itemId] -- Assumes ConfigItemsById is populated correctly at startup.
end

-- Gives an item (weapon, ammo, utility) to a player, handling different item categories appropriately.
-- Notifies client of purchase success/failure.
-- @param source number: The player's server ID.
-- @param item table: The item's configuration table (from Config.Items via getItemById).
-- @param quantity number: The quantity to give (relevant for stackable items).
-- @return boolean: True if item processing was attempted, false on initial validation failure.
local function givePlayerItem(source, item, quantity)
    quantity = tonumber(quantity) or 1 -- Ensure quantity is a number, default to 1.
    if not item or type(item) ~= "table" or not item.category or not item.itemId then
        print(string.format("Error: givePlayerItem - Invalid item object received for source %s. Item: %s", tostring(source), json.encode(item or "nil")))
        TriggerClientEvent('cops_and_robbers:purchaseFailed', source, "~r~Internal server error: Invalid item data.") -- Generic error to client
        return false
    end

    local pData = getPlayerData(source)
    if not pData then
        print(string.format("Error: givePlayerItem - No player data for source %s when trying to give item %s.", tostring(source), item.itemId))
        TriggerClientEvent('cops_and_robbers:purchaseFailed', source, "~r~Your player data could not be found.")
        return false
    end

    -- Check level restrictions
    if item.minLevelCop and pData.role == 'cop' and (pData.level or 1) < item.minLevelCop then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', source, string.format("~r~Requires Cop Level %d.", item.minLevelCop))
        return false
    end
    if item.minLevelRobber and pData.role == 'robber' and (pData.level or 1) < item.minLevelRobber then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', source, string.format("~r~Requires Robber Level %d.", item.minLevelRobber))
        return false
    end

    if item.category == "Weapons" or item.category == "Melee Weapons" then
        if not playerHasWeapon(source, item.itemId) then
            local defaultAmmo = getAmmoCountForItem(item.itemId:gsub("weapon_", "ammo_")) -- Attempt to get default ammo for new weapon
            addPlayerWeapon(source, item.itemId, defaultAmmo) -- Pass default ammo
            TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, item.itemId, 1)
        else
            TriggerClientEvent('cops_and_robbers:purchaseFailed', source, "~y~You already own this weapon.")
        end
    elseif item.category == "Ammunition" then
        local ammoClipSize = getAmmoCountForItem(item.itemId)
        local totalAmmoToAdd = ammoClipSize * quantity
        local weaponNameForAmmoType = item.itemId:gsub("^ammo_", "weapon_") -- e.g., "ammo_pistol" -> "weapon_pistol"

        -- Check if player has *any* weapon that uses this ammo type.
        -- This is a simplification. A more robust system would map ammo types to specific compatible weapons.
        local hasCompatibleWeapon = false
        if pData.weapons then
            for weaponId, _ in pairs(pData.weapons) do
                -- Crude check: if weaponId contains the ammo type string (e.g. "weapon_pistol" for "ammo_pistol")
                -- This needs a proper mapping in Config if weapons don't follow strict naming for their ammo.
                if string.find(weaponId, weaponNameForAmmoType:gsub("weapon_","")) then
                    hasCompatibleWeapon = true
                    TriggerClientEvent('cops_and_robbers:addAmmo', source, weaponId, totalAmmoToAdd) -- Give ammo to the first compatible weapon found
                    break
                end
            end
        end

        if hasCompatibleWeapon then
            TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, item.itemId, quantity)
        else
            TriggerClientEvent('cops_and_robbers:purchaseFailed', source, string.format("~r~You don't have a compatible weapon for %s.", item.name))
        end
    elseif item.category == "Armor" then
        TriggerClientEvent('cops_and_robbers:applyArmor', source, item.itemId) -- Client applies armor effect.
        TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, item.itemId, 1) -- Armor is usually single quantity.
    else -- Default to general inventory items (Utility, Accessories, etc.)
        addPlayerInventoryItem(source, item.itemId, quantity)
        TriggerClientEvent('cops_and_robbers:purchaseConfirmed', source, item.itemId, quantity)
    end
    -- Caller (e.g. purchaseItem event) is responsible for savePlayerData(source).
    return true
end

-- Initializes a player's stats in the global playerStats table if they don't exist.
-- Note: Player XP and Level are stored in playerData, not here. This is for other stats.
-- @param playerId number: The player's server ID.
local function initializePlayerStats(playerId)
    if not playerStats[playerId] then
        playerStats[playerId] = {
            heists  = 0,
            arrests = 0,
            rewards = 0
            -- Experience and level are managed within playerData directly by the new leveling system.
        }
    end
end

-- =====================================
--       PURCHASE HISTORY MANAGEMENT & DYNAMIC PRICING
-- =====================================

-- Loads purchase history from 'purchase_history.json'.
-- If the file doesn't exist or is corrupt, it initializes an empty history.
-- Ensures all items from Config.Items have an entry in purchaseHistory after loading.
local function loadPurchaseHistory()
    local fileData = LoadResourceFile(GetCurrentResourceName(), "purchase_history.json")
    if fileData and fileData ~= "" then
        local success, decodedData = pcall(json.decode, fileData)
        if success and decodedData and type(decodedData) == "table" then
            purchaseHistory = decodedData
            -- print("Purchase history loaded successfully from purchase_history.json.") -- Debug
        else
            print(string.format("Error: Failed to decode purchase_history.json or data is not a table. Content: %s. Initializing empty purchase history.", fileData:sub(1,200)))
            purchaseHistory = {}
        end
    else
        -- print("No purchase_history.json found or file is empty. Initializing empty purchase history.") -- Debug
        purchaseHistory = {}
    end
    -- Ensure all items from Config.Items have an initialized entry in purchaseHistory.
    initializePurchaseData()
end

-- Saves the current purchaseHistory table to 'purchase_history.json'.
local function savePurchaseHistory()
    if not Config.DynamicEconomy or not Config.DynamicEconomy.enabled then
        -- print("Dynamic economy disabled, not saving purchase history.") -- Optional debug
        return
    end
    local jsonData = json.encode(purchaseHistory, { indent = true })
    if jsonData then
        local success = SaveResourceFile(GetCurrentResourceName(), "purchase_history.json", jsonData, -1) -- Overwrite
        if not success then
            print("Error: Failed to save purchase_history.json for resource " .. GetCurrentResourceName())
        end
    else
        print("Error: Could not encode purchaseHistory to JSON for resource " .. GetCurrentResourceName())
    end
end

-- Calculates the dynamic price of an item based on its recent purchase frequency.
-- @param itemId string: The ID of the item.
-- @return number|nil: The calculated dynamic price, or the base price if conditions for adjustment aren't met or dynamic pricing is disabled. Returns nil if item not found.
local function getDynamicPrice(itemId)
    local item = getItemById(itemId)
    if not item or type(item.basePrice) ~= "number" then
        print(string.format("Error: getDynamicPrice - Item '%s' or its basePrice not found/invalid in Config.Items.", tostring(itemId)))
        return nil
    end

    local basePrice = item.basePrice
    if not Config.DynamicEconomy or not Config.DynamicEconomy.enabled then
        return basePrice -- Dynamic economy disabled, return base price.
    end

    -- Ensure purchaseHistory for this specific itemId is initialized.
    if not purchaseHistory[itemId] or type(purchaseHistory[itemId]) ~= "table" then
        purchaseHistory[itemId] = {} -- Initialize if somehow missed, though loadPurchaseHistory should handle this.
        -- print(string.format("Warning: Purchase history for item '%s' was not initialized prior to getDynamicPrice. Using base price.", itemId))
    end

    -- Ensure Config settings for dynamic pricing are available.
    local deConfig = Config.DynamicEconomy
    if not deConfig.popularityTimeframe or not deConfig.popularityThresholdHigh or not deConfig.popularityThresholdLow or
       not deConfig.priceIncreaseFactor or not deConfig.priceDecreaseFactor then
        print(string.format("Error: Dynamic pricing configuration settings (Config.DynamicEconomy) are missing or incomplete. Using base price for '%s'.", itemId))
        return basePrice
    end

    local currentTime = os.time()
    local timeframeStart = currentTime - deConfig.popularityTimeframe

    local purchaseCountInTimeframe = 0
    for _, purchaseTime in ipairs(purchaseHistory[itemId]) do
        if type(purchaseTime) == "number" and purchaseTime >= timeframeStart then
            purchaseCountInTimeframe = purchaseCountInTimeframe + 1
        end
    end

    if purchaseCountInTimeframe >= deConfig.popularityThresholdHigh then
        return math.floor(basePrice * deConfig.priceIncreaseFactor)
    elseif purchaseCountInTimeframe <= deConfig.popularityThresholdLow then
        return math.floor(basePrice * deConfig.priceDecreaseFactor)
    else
        return basePrice -- Normal price if between thresholds or exactly on them if not >= high or <= low.
    end
end

-- =====================================
--           BAN MANAGEMENT
-- =====================================

-- Loads bans from 'bans.json' and merges them with any bans defined directly in Config.BannedPlayers.
-- Entries in Config.BannedPlayers will overwrite those from bans.json if identifiers match.
-- Saves the potentially merged list back to 'bans.json' to ensure persistence and synchronization.
local function LoadBans()
    local loadedBansFromFile = {}
    local bansFileContent = LoadResourceFile(GetCurrentResourceName(), "bans.json")

    if bansFileContent and bansFileContent ~= "" then
        local success, decodedBans = pcall(json.decode, bansFileContent)
        if success and decodedBans and type(decodedBans) == "table" then
            loadedBansFromFile = decodedBans
            -- print("Bans loaded successfully from bans.json.") -- Debug
        else
            print(string.format("Error: Failed to decode bans.json or data is not a table. Content: '%s'. Starting with empty bans from file.", bansFileContent:sub(1,200)))
            -- Do not initialize to {} here, as Config.BannedPlayers might still provide bans.
        end
    else
        -- print("No bans.json found or file is empty. Will rely on Config.BannedPlayers if any.") -- Debug
    end

    -- Merge Config.BannedPlayers into the loaded bans. Config entries can overwrite file entries if identifiers match.
    bannedPlayers = loadedBansFromFile -- Start with what was loaded (or empty if nothing loaded/failed)
    if Config and Config.BannedPlayers and type(Config.BannedPlayers) == "table" then
        for identifier, banInfo in pairs(Config.BannedPlayers) do
            if type(identifier) == "string" and type(banInfo) == "table" then
                 bannedPlayers[identifier] = banInfo -- Config takes precedence or adds new.
            else
                print(string.format("Warning: Invalid entry in Config.BannedPlayers. Identifier: %s", tostring(identifier)))
            end
        end
    end

    saveBans() -- Save the potentially merged and updated list back to bans.json.
end


-- =====================================
--       ADMIN HELPER FUNCTIONS
-- =====================================

-- Checks if a player is an admin based on their identifiers matching entries in Config.Admins.
-- @param playerId number: The server ID of the player to check.
-- @return boolean: True if the player is an admin, false otherwise.
local function IsAdmin(playerId)
    if playerId == nil then
        -- print("Warning: IsAdmin called with nil playerId.") -- Optional debug
        return false
    end

    local playerIdentifiers = GetPlayerIdentifiers(playerId)
    if not playerIdentifiers or #playerIdentifiers == 0 then
        -- print(string.format("Warning: IsAdmin could not get identifiers for playerId %s.", tostring(playerId))) -- Optional debug
        return false
    end

    if not Config or not Config.Admins or type(Config.Admins) ~= "table" then
        print("CRITICAL ERROR: Config.Admins is not loaded or is not a table. Ensure config.lua defines it correctly and is loaded before server.lua. Admin checks will fail.")
        return false -- Cannot determine admin status without a valid Config.Admins table.
    end

    for _, identifier in ipairs(playerIdentifiers) do
        if type(identifier) == "string" and Config.Admins[identifier] == true then -- Explicitly check for boolean true.
            return true
        end
    end
    return false
end

-- Checks if a given player ID corresponds to a currently connected player.
-- @param targetId any: The player ID to validate. Will be converted to a number.
-- @return boolean: True if the player is valid and online, false otherwise.
local function IsValidPlayer(targetId)
    if targetId == nil then return false end

    local numericTargetId = tonumber(targetId)
    if not numericTargetId then
        -- print(string.format("Warning: IsValidPlayer received a non-numeric targetId: %s.", tostring(targetId))) -- Optional debug
        return false
    end

    -- GetPlayers() returns a table of active player server IDs.
    for _, onlinePlayerId in ipairs(GetPlayers()) do
        if onlinePlayerId == numericTargetId then
            -- Check if player is actually active (not just in GetPlayers list during connection/disconnection flux)
            -- GetPlayerName will return nil if player is not fully connected or has dropped.
            if GetPlayerName(numericTargetId) then
                return true
            end
        end
    end
    return false
end


-- =====================================
--           CORE EVENT HANDLERS
-- =====================================

-- Handles player connection: checks bans, loads player data, and logs connection.
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source -- Player's server ID
    local identifiers = GetPlayerIdentifiers(src)

    deferrals.defer() -- Defer connection to perform asynchronous checks.
    Citizen.Wait(0)   -- Allow deferral to take effect.

    deferrals.update("Checking your ban status...")
    Citizen.Wait(100) -- Simulate a small delay for UX.

    -- Check for bans against any of the player's identifiers.
    if identifiers and #identifiers > 0 then
        for _, identifier in ipairs(identifiers) do
            if bannedPlayers[identifier] then -- bannedPlayers is loaded by LoadBans()
                local banInfo = bannedPlayers[identifier]
                local banReason = banInfo.reason or "No reason provided."
                local adminName = banInfo.admin or "System"
                local banTimestamp = banInfo.timestamp and os.date("%Y-%m-%d %H:%M:%S", banInfo.timestamp) or "N/A"
                local logMsg = string.format("Connection Denied: Player %s (Identifiers: %s). Banned by %s on %s. Reason: %s",
                                playerName, table.concat(identifiers, ", "), adminName, banTimestamp, banReason)
                LogAdminAction(logMsg)
                deferrals.done(string.format("You are banned from this server.\nReason: %s\nBanned by: %s on %s", banReason, adminName, banTimestamp))
                CancelEvent() -- Stop the connection.
                return
            end
        end
    else
        -- This case should be rare for legitimate players. Could indicate an issue with identifier retrieval.
        LogAdminAction(string.format("Player Connecting: %s (ID: %d) - No identifiers found. Allowing connection for now, but this is unusual.", playerName, src))
        -- Depending on server policy, you might kick players with no identifiers:
        -- deferrals.done("Could not retrieve your game identifiers. Please try reconnecting or contact server staff if this persists.")
        -- CancelEvent()
        -- return
    end

    LogAdminAction(string.format("Player Connecting: %s (ID: %d, Identifiers: %s)", playerName, src, table.concat(identifiers, ", ")))

    deferrals.update("Loading your player data...")
    Citizen.Wait(200) -- Simulate data loading delay.

    loadPlayerData(src) -- Load or initialize player data.
    -- Ensure critical player data aspects are initialized if somehow missed by loadPlayerData defaults
    playerRoles[src] = playerData[src] and playerData[src].role or nil
    if playerRoles[src] == 'cop' then cops[src] = true elseif playerRoles[src] == 'robber' then robbers[src] = true end
    initializePlayerStats(src) -- Initialize playerStats entry if not already present

    -- Player is now loaded, log final connection message
    LogAdminAction(string.format("Player Connected: %s (ID: %d). Role: %s", GetPlayerName(src), src, playerRoles[src] or "None"))

    deferrals.done() -- Allow connection to proceed.
end)

-- Handles player disconnection: saves player data, logs disconnection, and cleans up any active states.
AddEventHandler('playerDropped', function(reason)
    local src = source
    local playerName = GetPlayerName(src) or ("PlayerID " .. src) -- Get name before data is potentially nilled.

    LogAdminAction(string.format("Player Disconnected: %s (ID: %d). Reason: %s", playerName, src, reason))

    local disconnectedPlayerRole = playerRoles[src]

    -- Clean up states if the disconnected player was involved in specific activities.
    if disconnectedPlayerRole == 'cop' then
        -- If cop was subduing someone, cancel it.
        for robberId, subdueData in pairs(activeSubdues) do
            if subdueData.copId == src then
                ClearTimeout(subdueData.timer)
                activeSubdues[robberId] = nil
                if IsValidPlayer(robberId) then
                    TriggerClientEvent('cops_and_robbers:subdueCancelled', robberId)
                    LogAdminAction(string.format("Subdue auto-cancelled: Cop %s (ID: %d) disconnected while subduing Robber %s (ID: %d).",
                                    playerName, src, GetPlayerName(robberId) or ("ID " .. robberId), robberId))
                end
                break
            end
        end
        -- If cop had an active K9.
        if activeK9s[src] then
            activeK9s[src] = nil
            LogAdminAction(string.format("K9 status cleared for disconnected Cop %s (ID: %d).", playerName, src))
            -- Client-side K9 ped is handled by its owner's client.lua upon disconnect/resource stop.
        end
    elseif disconnectedPlayerRole == 'robber' then
        -- If robber was being subdued, clear it.
        if activeSubdues[src] then
            ClearTimeout(activeSubdues[src].timer)
            local subduingCopId = activeSubdues[src].copId
            activeSubdues[src] = nil
            if IsValidPlayer(subduingCopId) then
                 TriggerClientEvent('cops_and_robbers:showNotification', subduingCopId, "~y~The suspect you were subduing has disconnected.")
            end
            LogAdminAction(string.format("Subdue auto-cancelled: Robber %s (ID: %d) disconnected while being subdued by Cop (ID: %d).",
                            playerName, src, subduingCopId))
        end
        -- If robber was in activeStoreRobberies, clear their specific robbery attempt.
        if activeStoreRobberies[src] then
            local storeName = (activeStoreRobberies[src].store and activeStoreRobberies[src].store.name) or "Unknown Store"
            ClearTimeout(activeStoreRobberies[src].successTimer)
            LogAdminAction(string.format("Store Robbery auto-cancelled: Robber %s (ID: %d) disconnected during robbery at %s.",
                            playerName, src, storeName))
            activeStoreRobberies[src] = nil
        end
        -- Contraband collection: If a robber disconnects while collecting, remove them from the collecting list.
        for dropId, drop in pairs(activeContrabandDrops) do
            if drop.playersCollecting and drop.playersCollecting[src] then
                drop.playersCollecting[src] = nil
                LogAdminAction(string.format("Contraband collection stopped for disconnected player %s on drop %s.", playerName, dropId))
            end
        end
    end

    -- Save final player data before removing from memory.
    if playerData[src] then -- Only save if data exists
        savePlayerData(src)
    end

    -- Clear player's runtime data from server memory.
    playerData[src] = nil
    cops[src] = nil
    robbers[src] = nil
    playerRoles[src] = nil
    playerPositions[src] = nil
    playerStats[src] = nil
    playerUpdateTimestamps[src] = nil
    playerSpikeStripCount[src] = nil
    -- Remove from cooldown tables if any player-specific cooldowns are tracked by src ID directly.
    if heistCooldowns and heistCooldowns[src] then heistCooldowns[src] = nil end
    if playerCorruptOfficialCooldowns and playerCorruptOfficialCooldowns[src] then playerCorruptOfficialCooldowns[src] = nil end
    if playerAppearanceChangeCooldowns and playerAppearanceChangeCooldowns[src] then playerAppearanceChangeCooldowns[src] = nil end
end)

-- Event handler to send player data to client upon request (e.g., after role selection or on spawn).
RegisterNetEvent('cops_and_robbers:requestPlayerData')
AddEventHandler('cops_and_robbers:requestPlayerData', function()
    local src = source
    local data = getPlayerData(src) -- Uses the helper function that returns nil if no data
    if data then
        TriggerClientEvent('cops_and_robbers:receivePlayerData', src, data)
    else
        print(string.format("Warning: Player data requested by source %s (Name: %s) but no data found in memory.", src, GetPlayerName(src) or "N/A"))
        -- Optionally, attempt to load data again or send an error/default state to client.
        -- loadPlayerData(src) -- Be cautious with synchronous loads here if not expected.
        -- TriggerClientEvent('cops_and_robbers:receivePlayerData', src, getPlayerData(src) or {}) -- Send empty if still no data
    end
end)

-- Event handler for item purchase with quantity.
RegisterNetEvent('cops_and_robbers:purchaseItem')
AddEventHandler('cops_and_robbers:purchaseItem', function(itemId, quantity)
    local src = source
    local pData = getPlayerData(src)
    if not pData then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "~r~Your player data couldn't be loaded.")
        return
    end

    quantity = tonumber(quantity) or 1
    if quantity < 1 or quantity > 100 then -- Basic quantity validation. Max 100 per single purchase.
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "~r~Invalid quantity specified.")
        return
    end

    local item = getItemById(itemId)
    if not item then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "~r~Invalid item selected.")
        return
    end

    -- Check role restrictions (e.g., "forCop = true")
    if item.forCop and (not playerRoles[src] or playerRoles[src] ~= 'cop') then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "~r~This item is restricted to Cops.")
        return
    end
    -- Check level restrictions
    if item.minLevelCop and playerRoles[src] == 'cop' and (pData.level or 1) < item.minLevelCop then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, string.format("~r~Requires Cop Level %d.",item.minLevelCop))
        return
    end
    if item.minLevelRobber and playerRoles[src] == 'robber' and (pData.level or 1) < item.minLevelRobber then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, string.format("~r~Requires Robber Level %d.",item.minLevelRobber))
        return
    end

    local dynamicPrice = getDynamicPrice(itemId)
    if not dynamicPrice or type(dynamicPrice) ~= "number" then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "~r~Could not determine item price.")
        print(string.format("Error: purchaseItem - Failed to get dynamic price for item %s for player %s.", itemId, src))
        return
    end
    local totalPrice = dynamicPrice * quantity

    if pData.money < totalPrice then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "~r~Insufficient funds.")
        return
    end

    -- Attempt to give item first; if successful, then remove money and save.
    if givePlayerItem(src, item, quantity) then -- givePlayerItem now handles its own client notifications for success/failure.
        removePlayerMoney(src, totalPrice)

        -- Record the purchase for dynamic pricing, if enabled.
        if Config.DynamicEconomy and Config.DynamicEconomy.enabled then
            local timestamp = os.time()
            purchaseHistory[itemId] = purchaseHistory[itemId] or {} -- Ensure array exists
            for i = 1, quantity do
                table.insert(purchaseHistory[itemId], timestamp)
            end

            -- Clean up old entries from purchase history.
            local updatedItemPurchaseHistory = {}
            local timeframeStart = timestamp - (Config.DynamicEconomy.popularityTimeframe or 3*60*60)
            for _, purchaseTime in ipairs(purchaseHistory[itemId]) do
                if type(purchaseTime) == "number" and purchaseTime >= timeframeStart then
                    table.insert(updatedItemPurchaseHistory, purchaseTime)
                end
            end
            purchaseHistory[itemId] = updatedItemPurchaseHistory
            savePurchaseHistory() -- Save updated history.
        end

        savePlayerData(src) -- Save player data after successful transaction.
        LogAdminAction(string.format("Item Purchased: Player %s (ID: %d) bought %d x %s for $%d.", GetPlayerName(src) or "N/A", src, quantity, item.name or itemId, totalPrice))
    else
        -- givePlayerItem would have sent a failure notification to client already.
        LogAdminAction(string.format("Item Purchase Failed (givePlayerItem returned false): Player %s (ID: %d) for item %s.", GetPlayerName(src) or "N/A", src, item.name or itemId))
    end
end)

-- Event handler for selling items.
RegisterNetEvent('cops_and_robbers:sellItem')
AddEventHandler('cops_and_robbers:sellItem', function(itemId, quantity)
    local src = source
    local pData = getPlayerData(src)
    if not pData then
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "~r~Your player data couldn't be loaded.")
        return
    end

    quantity = tonumber(quantity) or 1
    if quantity < 1 or quantity > 1000 then -- Max quantity for selling, can be higher than buying.
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "~r~Invalid quantity specified.")
        return
    end

    local item = getItemById(itemId)
    if not item then
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "~r~Invalid item selected for selling.")
        return
    end

    local dynamicPrice = getDynamicPrice(itemId) -- Base price if dynamic pricing disabled or item not found in history.
    if not dynamicPrice or type(dynamicPrice) ~= "number" then
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "~r~Could not determine item value.")
        print(string.format("Error: sellItem - Failed to get dynamic price for item %s for player %s.", itemId, src))
        return
    end

    local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
    local sellPricePerUnit = math.floor(dynamicPrice * sellPriceFactor)
    if sellPricePerUnit <= 0 then -- Prevent selling items for free or negative value if config is bad
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "~r~This item cannot be sold for a valid price.")
        return
    end
    local totalSellValue = sellPricePerUnit * quantity

    local itemCategory = item.category
    local soldSuccessfully = false

    if itemCategory == "Weapons" or itemCategory == "Melee Weapons" then
        -- For weapons, assume selling one at a time (quantity = 1).
        if quantity > 1 then TriggerClientEvent('cops_and_robbers:sellFailed', src, "~r~You can only sell one weapon at a time."); return end
        if playerHasWeapon(src, item.itemId) then
            if removePlayerWeapon(src, item.itemId) then
                addPlayerMoney(src, sellPricePerUnit)
                soldSuccessfully = true
            end
        else
            TriggerClientEvent('cops_and_robbers:sellFailed', src, "~r~You do not own this weapon.")
            return
        end
    else -- General inventory items
        local currentItemCount = getPlayerInventoryItemCount(src, item.itemId)
        if currentItemCount >= quantity then
            if removePlayerInventoryItem(src, item.itemId, quantity) then
                addPlayerMoney(src, totalSellValue)
                soldSuccessfully = true
            end
        else
            TriggerClientEvent('cops_and_robbers:sellFailed', src, string.format("~r~Insufficient items. You have %d.", currentItemCount))
            return
        end
    end

    if soldSuccessfully then
        savePlayerData(src)
        TriggerClientEvent('cops_and_robbers:sellConfirmed', src, item.name, quantity, totalSellValue) -- Client notification
        LogAdminAction(string.format("Item Sold: Player %s (ID: %d) sold %d x %s for $%d.", GetPlayerName(src) or "N/A", src, quantity, item.name or itemId, totalSellValue))
    else
        -- Specific failure messages should have been sent already by removePlayerWeapon or removePlayerInventoryItem logic if they failed.
        -- This is a fallback.
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "~r~Could not sell the item(s).")
    end
end)

-- Event handler for client requesting item list for a store/vendor.
RegisterNetEvent('cops_and_robbers:getItemList')
AddEventHandler('cops_and_robbers:getItemList', function(storeType, vendorItems, storeName)
    local src = source
    local pData = getPlayerData(src) -- Get player data for role and level checks
    local itemList = {}

    if not Config.Items or type(Config.Items) ~= "table" then
        print("CRITICAL Error: Config.Items not found or not a table for getItemList.")
        TriggerClientEvent('cops_and_robbers:sendItemList', src, storeName or "Store", {}) -- Send empty list
        return
    end

    for _, itemConfig in ipairs(Config.Items) do
        local isItemAvailableForStore = false

        -- Role and Level Checks
        local canAccess = true
        if pData and pData.role == 'cop' and itemConfig.minLevelCop and (pData.level or 1) < itemConfig.minLevelCop then
            canAccess = false
        end
        if pData and pData.role == 'robber' and itemConfig.minLevelRobber and (pData.level or 1) < item.minLevelRobber then
            canAccess = false
        end

        if canAccess then
            if storeType == "AmmuNation" then
                -- Ammu-Nations typically sell Weapons, Melee Weapons, Ammunition, Armor, and some Utility.
                if itemConfig.category == "Weapons" or itemConfig.category == "Melee Weapons" or
                   itemConfig.category == "Ammunition" or itemConfig.category == "Armor" or
                   (itemConfig.category == "Utility" and not itemConfig.forCop) then -- General utility items
                    isItemAvailableForStore = true
                end
                -- Filter out cop-specific gear unless the player is a cop.
                if itemConfig.forCop and (not pData or pData.role ~= 'cop') then
                    isItemAvailableForStore = false
                end
            elseif storeType == "Vendor" and vendorItems and type(vendorItems) == "table" and hasValue(vendorItems, itemConfig.itemId) then
                -- For specific NPC vendors, only list items they are configured to sell.
                isItemAvailableForStore = true
                -- Additional role/level checks for vendor items if needed, similar to AmmuNation.
                if itemConfig.forCop and (not pData or pData.role ~= 'cop') then
                     isItemAvailableForStore = false
                end
            end
        end

        if isItemAvailableForStore then
            local dynamicPrice = getDynamicPrice(itemConfig.itemId)
            if dynamicPrice == nil then dynamicPrice = itemConfig.basePrice end -- Fallback if dynamic price fails

            table.insert(itemList, {
                name = itemConfig.name,
                itemId = itemConfig.itemId,
                price = dynamicPrice,
                category = itemConfig.category,
                forCop = itemConfig.forCop or false, -- Pass forCop status for client UI
                minLevelCop = itemConfig.minLevelCop,     -- Pass level requirements
                minLevelRobber = itemConfig.minLevelRobber
            })
        end
    end
    TriggerClientEvent('cops_and_robbers:sendItemList', src, storeName or "Store", itemList)
end)

-- Event handler to send player's current inventory to the client (for display in NUI, etc.).
RegisterNetEvent('cops_and_robbers:getPlayerInventory')
AddEventHandler('cops_and_robbers:getPlayerInventory', function()
    local src = source
    local pData = getPlayerData(src)
    local inventoryForClient = {}

    if pData then
        -- Process standard inventory items (those with quantities).
        if pData.inventory and type(pData.inventory) == "table" then
            for itemId, count in pairs(pData.inventory) do
                if count > 0 then -- Only include items with a count > 0
                    local itemConfig = getItemById(itemId)
                    if itemConfig then
                        local dynamicPrice = getDynamicPrice(itemId) or itemConfig.basePrice
                        local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
                        local sellPrice = math.floor(dynamicPrice * sellPriceFactor)
                        table.insert(inventoryForClient, {
                            name = itemConfig.name,
                            itemId = itemConfig.itemId,
                            count = count,
                            sellPrice = sellPrice,
                            category = itemConfig.category
                        })
                    else
                        print(string.format("Warning: getPlayerInventory - Item config not found for itemId '%s' in player %s's inventory.", itemId, src))
                    end
                end
            end
        end

        -- Process weapons (typically count as 1, sell price might differ or be non-sellable).
        if pData.weapons and type(pData.weapons) == "table" then
            for weaponHash, _ in pairs(pData.weapons) do -- weaponHash is the itemId for weapons
                local itemConfig = getItemById(weaponHash)
                if itemConfig then
                    local dynamicPrice = getDynamicPrice(weaponHash) or itemConfig.basePrice
                    local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
                    local sellPrice = math.floor(dynamicPrice * sellPriceFactor)
                    table.insert(inventoryForClient, {
                        name = itemConfig.name,
                        itemId = itemConfig.itemId,
                        count = 1, -- Weapons are typically single items.
                        sellPrice = sellPrice, -- Or specific weapon sell price logic if different from general items.
                        category = itemConfig.category
                    })
                else
                     print(string.format("Warning: getPlayerInventory - Item config not found for weaponHash '%s' in player %s's weapons.", weaponHash, src))
                end
            end
        end
        TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, inventoryForClient)
    else
        print(string.format("Warning: Player inventory requested by source %s (Name: %s) but no player data found.", src, GetPlayerName(src) or "N/A"))
        TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, {}) -- Send empty inventory.
    end
end)

-- Event handler for when a player selects or changes their role.
-- Includes logic for team balancing incentives.
RegisterNetEvent('cops_and_robbers:setPlayerRole')
AddEventHandler('cops_and_robbers:setPlayerRole', function(selectedRole)
    local src = source
    local pData = getPlayerData(src)
    if not pData then
        print(string.format("Error: setPlayerRole - No player data found for source %s.", tostring(src)))
        TriggerClientEvent('cops_and_robbers:showNotification', src, "~r~Error setting role: Player data not found.")
        return
    end

    if selectedRole ~= "cop" and selectedRole ~= "robber" then
        print(string.format("Warning: setPlayerRole - Invalid role '%s' selected by source %s.", tostring(selectedRole), tostring(src)))
        TriggerClientEvent('cops_and_robbers:showNotification', src, "~r~Invalid role selected.")
        return -- Invalid role.
    end

    local previousPlayerRole = pData.role -- Get current role from pData, not potentially stale playerRoles[src]

    -- Team Balancing Incentive Check (only if role changes or is initially set and incentive system enabled)
    if Config.TeamBalanceSettings and Config.TeamBalanceSettings.enabled and previousPlayerRole ~= selectedRole then
        local numCops = 0
        local numRobbers = 0
        -- Count current team members accurately from pData of all connected players
        for _, onlinePlayerId in ipairs(GetPlayers()) do
            local onlinePData = getPlayerData(onlinePlayerId)
            if onlinePData and onlinePData.role then
                if onlinePData.role == 'cop' then
                    numCops = numCops + 1
                elseif onlinePData.role == 'robber' then
                    numRobbers = numRobbers + 1
                end
            end
        end

        -- Adjust counts based on the current player potentially leaving their old team *before* joining new one.
        if previousPlayerRole == 'cop' then
            numCops = math.max(0, numCops - 1)
        elseif previousPlayerRole == 'robber' then
            numRobbers = math.max(0, numRobbers - 1)
        end

        local incentiveApplied = false
        local incentiveCash = Config.TeamBalanceSettings.incentiveCash or 0
        local threshold = Config.TeamBalanceSettings.threshold or 1 -- Default threshold if not set

        if selectedRole == 'cop' then
            -- Incentive if joining cops and cops are outnumbered by at least 'threshold'
            if numCops < numRobbers and (numRobbers - numCops) >= threshold then
                if addPlayerMoney(src, incentiveCash) then
                    TriggerClientEvent('chat:addMessage', src, { args = { "^2[System]", string.format(Config.TeamBalanceSettings.notificationMessage or "Bonus: $%s for joining %s!", incentiveCash, "Cops") } })
                    LogAdminAction(string.format("TeamBalance: Player %s (ID: %d) received $%s incentive for joining Cops. Cops: %d, Robbers: %d (before this player's join).", GetPlayerName(src) or "N/A", src, incentiveCash, numCops, numRobbers))
                    incentiveApplied = true
                end
            end
        elseif selectedRole == 'robber' then
            -- Incentive if joining robbers and robbers are outnumbered by at least 'threshold'
            if numRobbers < numCops and (numCops - numRobbers) >= threshold then
                 if addPlayerMoney(src, incentiveCash) then
                    TriggerClientEvent('chat:addMessage', src, { args = { "^2[System]", string.format(Config.TeamBalanceSettings.notificationMessage or "Bonus: $%s for joining %s!", incentiveCash, "Robbers") } })
                    LogAdminAction(string.format("TeamBalance: Player %s (ID: %d) received $%s incentive for joining Robbers. Cops: %d, Robbers: %d (before this player's join).", GetPlayerName(src) or "N/A", src, incentiveCash, numCops, numRobbers))
                    incentiveApplied = true
                end
            end
        end
        -- savePlayerData will be called once after all role changes.
    end

    -- Update role in server-side state tables and persistent playerData.
    playerRoles[src] = selectedRole -- For quick server-side lookups.
    pData.role = selectedRole      -- Persisted in playerData.

    if selectedRole == 'cop' then
        cops[src] = true
        robbers[src] = nil
    elseif selectedRole == 'robber' then
        robbers[src] = true
        cops[src] = nil
    end

    TriggerClientEvent('cops_and_robbers:setRole', src, selectedRole) -- Notify client of their new role for UI/logic updates.
    savePlayerData(src) -- Save data after role change and potential incentive.
    LogAdminAction(string.format("Role Set: Player %s (ID: %d) set to %s. Previous role: %s.", GetPlayerName(src) or "N/A", src, selectedRole, previousPlayerRole or "None"))

    -- Trigger initial XP display if leveling system is enabled.
    if Config.LevelingSystemEnabled then
        local currentLevel = pData.level or 1
        local currentXP = pData.xp or 0
        local xpForNextDisplaySegment
        if currentLevel >= Config.MaxLevel then
            xpForNextDisplaySegment = currentXP -- At max level, client can show this as "Max" or current XP.
        else
            xpForNextDisplaySegment = (Config.XPTable and Config.XPTable[currentLevel + 1]) or "Error" -- XP needed to complete current level.
        end
        TriggerClientEvent('cops_and_robbers:updateXPDisplay', src, currentLevel, currentXP, xpForNextDisplaySegment)
    end
end)

-- Event handler for receiving player position updates from clients.
-- Includes throttling and logic for updating 'lastSeenByCopTimestamp' for wanted players.
RegisterNetEvent('cops_and_robbers:updatePosition')
AddEventHandler('cops_and_robbers:updatePosition', function(position, clientReportedWantedLevel)
    local src = source
    local pData = getPlayerData(src)
    if not pData then return end -- If no player data, nothing to do.

    local now = GetGameTimer() -- Current game time in milliseconds.

    -- Throttle updates: ignore if less than a short interval (e.g., 100ms) since last update for this player.
    if playerUpdateTimestamps[src] and (now - playerUpdateTimestamps[src]) < 100 then -- 100ms = 0.1s
        return
    end
    playerUpdateTimestamps[src] = now

    -- Store the reported position and client-side wanted level.
    -- Ensure position is a valid vector3-like table before storing.
    if type(position) == "table" and position.x and position.y and position.z then
        playerPositions[src] = { position = position, clientReportedWantedLevel = tonumber(clientReportedWantedLevel) or 0 }
    else
        -- print(string.format("Warning: Invalid position data received from player %s.", src)) -- Optional debug
        playerPositions[src] = playerPositions[src] or { position = vector3(0,0,0), clientReportedWantedLevel = 0} -- Keep old or default if new is bad
    end

    -- Wanted system: Update lastSeenByCopTimestamp if player is wanted and near a cop.
    if pData.wantedPoints and pData.wantedPoints > 0 and playerPositions[src] then
        local playerCoords = vector3(playerPositions[src].position.x, playerPositions[src].position.y, playerPositions[src].position.z)

        for copId, _ in pairs(cops) do -- Iterate only over players currently in 'cops' table.
            if copId ~= src and playerPositions[copId] and playerPositions[copId].position then
                local copPosData = playerPositions[copId].position
                if type(copPosData) == "table" and copPosData.x and copPosData.y and copPosData.z then
                    local copCoordsVec = vector3(copPosData.x, copPosData.y, copPosData.z)
                    local sightDistance = (Config.WantedSettings and Config.WantedSettings.copSightDistance) or 75.0 -- Default sight distance.
                    if #(playerCoords - copCoordsVec) < sightDistance then
                        pData.lastSeenByCopTimestamp = GetGameTimer()
                        -- LogAdminAction(string.format("Wanted Player %s seen by Cop %s", GetPlayerName(src), GetPlayerName(copId))) -- Debug, can be spammy.
                        break -- Seen by one cop is enough for this update cycle.
                    end
                end
            end
        end
        -- No savePlayerData(src) here, as lastSeenByCopTimestamp is transient and affects decay logic, not core persistent data needing immediate save.
    end
end)

-----------------------------------------------------------
-- Wanted Level Decay Thread
-----------------------------------------------------------
-- This thread periodically checks and decays wanted points for players
-- who have not committed recent crimes and are not currently seen by police.
Citizen.CreateThread(function()
    while true do
        -- Use configured decay interval or default to 30 seconds.
        local decayIntervalMs = (Config.WantedSettings and Config.WantedSettings.decayIntervalMs) or 30000
        Citizen.Wait(decayIntervalMs)

        if not Config.WantedSettings or not Config.WantedSettings.noCrimeCooldownMs or
           not Config.WantedSettings.copSightCooldownMs or not Config.WantedSettings.decayRatePoints then
            -- print("Warning: Wanted decay settings (Config.WantedSettings) are not fully configured. Decay paused.") -- Optional: less spammy
            goto continue_decay_loop -- Skip this iteration if config is missing critical parts.
        end

        local currentTimeMs = GetGameTimer() -- Use game timer for consistency with other timestamps.

        for _, playerId in ipairs(GetPlayers()) do -- Iterate over all connected players.
            local pData = getPlayerData(playerId)
            if pData and pData.wantedPoints and pData.wantedPoints > 0 then
                -- Check if player has been "clean" (no new crimes) for the noCrimeCooldownMs period.
                local timeSinceLastCrimeMs = currentTimeMs - (pData.lastCrimeTimestamp or 0)
                -- Check if player has been out of cop sight for the copSightCooldownMs period.
                local timeSinceLastSeenByCopMs = currentTimeMs - (pData.lastSeenByCopTimestamp or 0)

                if timeSinceLastCrimeMs >= Config.WantedSettings.noCrimeCooldownMs and
                   timeSinceLastSeenByCopMs >= Config.WantedSettings.copSightCooldownMs then

                    local oldPoints = pData.wantedPoints
                    pData.wantedPoints = math.max(0, pData.wantedPoints - Config.WantedSettings.decayRatePoints)

                    if pData.wantedPoints ~= oldPoints then
                        -- LogAdminAction for decay can be spammy. Consider logging only significant changes or disabling for normal operation.
                        -- LogAdminAction(string.format("Wanted Decay: Player %s (ID: %d) points %d -> %d.", GetPlayerName(playerId) or "N/A", playerId, oldPoints, pData.wantedPoints))
                        UpdatePlayerWantedLevel(playerId) -- Update stars and notify client.
                        savePlayerData(playerId)          -- Persist the change in wanted points.
                    end
                end
            end
        end
        ::continue_decay_loop:: -- Label for the goto statement.
    end
end)


-----------------------------------------------------------
-- Contraband Drop System
-----------------------------------------------------------
-- Spawns a contraband drop at a random available location from Config.ContrabandDropLocations.
local function SpawnContrabandDrop()
    if not Config.ContrabandDropLocations or type(Config.ContrabandDropLocations) ~= "table" or #Config.ContrabandDropLocations == 0 or
       not Config.ContrabandItems or type(Config.ContrabandItems) ~= "table" or #Config.ContrabandItems == 0 or
       not Config.MaxActiveContrabandDrops or type(Config.MaxActiveContrabandDrops) ~= "number" then
        print("Error: Contraband drop system configuration (ContrabandDropLocations, ContrabandItems, MaxActiveContrabandDrops) is missing or incomplete.")
        return
    end

    if tablelength(activeContrabandDrops) >= Config.MaxActiveContrabandDrops then
        -- print("Debug: Max active contraband drops reached (" .. Config.MaxActiveContrabandDrops .. ").")
        return
    end

    local availableLocations = {}
    for _, loc in ipairs(Config.ContrabandDropLocations) do
        local locInUse = false
        for _, activeDrop in pairs(activeContrabandDrops) do
            -- Compare locations carefully, especially if they are vector3 objects.
            if activeDrop.location and loc.x == activeDrop.location.x and loc.y == activeDrop.location.y and loc.z == activeDrop.location.z then
                locInUse = true
                break
            end
        end
        if not locInUse then
            table.insert(availableLocations, loc)
        end
    end

    if #availableLocations == 0 then
        -- print("Debug: No available (unused) locations for contraband drop at the moment.")
        return
    end

    -- Select a random location and item for the drop.
    local randomLocation = availableLocations[math.random(#availableLocations)]
    local randomItemConfig = Config.ContrabandItems[math.random(#Config.ContrabandItems)] -- This is the item's definition from config.
    local dropId = "drop_" .. GetConvar("sv_hostname", "server") .. "_" .. math.random(10000, 99999) -- Generate a more unique ID.

    activeContrabandDrops[dropId] = {
        id = dropId,
        location = randomLocation,
        item = randomItemConfig,    -- Store the full item config for value, name, modelHash.
        playersCollecting = {}      -- { [playerId] = gameTimerTimestamp_startTime }
    }

    TriggerClientEvent('cops_and_robbers:contrabandDropSpawned', -1, dropId, randomLocation, randomItemConfig.name, randomItemConfig.modelHash)
    LogAdminAction(string.format("Contraband Drop Spawned: ID %s, Item %s (%s), Value $%d, Location %s",
                    dropId, randomItemConfig.name, randomItemConfig.itemId, randomItemConfig.value, json.encode(randomLocation)))
end

-- Thread to periodically attempt spawning contraband drops based on configured interval.
Citizen.CreateThread(function()
    while true do
        local intervalMs = (Config.ContrabandDropIntervalMs and Config.ContrabandDropIntervalMs > 0) and Config.ContrabandDropIntervalMs or (30 * 60 * 1000) -- Default 30 mins
        Citizen.Wait(intervalMs / 10) -- Check more frequently (e.g., every 1/10th of interval) but use full interval for actual spawn decision.

        if GetGameTimer() >= nextContrabandDropTimestamp then
            SpawnContrabandDrop()
            nextContrabandDropTimestamp = GetGameTimer() + intervalMs
            -- LogAdminAction("Next contraband drop scheduled around: " .. os.date("%X", math.floor((GetGameTimer() + intervalMs) / 1000))) -- Can be spammy.
        end
    end
end)

-- Event handler for when a robber starts collecting contraband from a drop.
RegisterNetEvent('cops_and_robbers:startCollectingContraband')
AddEventHandler('cops_and_robbers:startCollectingContraband', function(dropId)
    local robberId = source
    local drop = activeContrabandDrops[dropId]

    if not drop then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~This contraband drop is no longer available.")
        return
    end

    if not playerRoles[robberId] or playerRoles[robberId] ~= 'robber' then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Only robbers can collect contraband.")
        return
    end

    -- Simple model: first to finish successfully gets it. Multiple can attempt.
    drop.playersCollecting[robberId] = GetGameTimer() -- Store start time.
    local collectionTimeMs = Config.ContrabandCollectionTimeMs or 5000
    TriggerClientEvent('cops_and_robbers:collectingContrabandStarted', robberId, dropId, collectionTimeMs)
    LogAdminAction(string.format("Contraband Collection Started: Robber %s (ID: %d) on drop %s (%s).",
                    GetPlayerName(robberId) or "N/A", robberId, dropId, drop.item.name))
end)

-- Event handler for when a robber finishes (or attempts to finish) collecting contraband.
RegisterNetEvent('cops_and_robbers:finishCollectingContraband')
AddEventHandler('cops_and_robbers:finishCollectingContraband', function(dropId)
    local robberId = source
    local drop = activeContrabandDrops[dropId] -- Re-fetch, drop might have been collected by another player.

    if not drop then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~This contraband drop is no longer available or was already collected.")
        return
    end

    if not drop.playersCollecting or not drop.playersCollecting[robberId] then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Collection not started or was interrupted by another player.")
        return
    end

    local collectionStartTimeMs = drop.playersCollecting[robberId]
    local requiredTimeMs = Config.ContrabandCollectionTimeMs or 5000
    -- Allow a small buffer (e.g., 500ms) for network latency and client-side timer accuracy.
    if (GetGameTimer() - collectionStartTimeMs) < (requiredTimeMs - 500) then
        TriggerClientEvent('cops_and_robbers:showNotification', robberId, "~r~Collection interrupted or completed too quickly.")
        LogAdminAction(string.format("Contraband Collection Fail (Too Fast/Interrupted): Robber %s (ID: %d) on drop %s.",
                        GetPlayerName(robberId) or "N/A", robberId, dropId))
        drop.playersCollecting[robberId] = nil -- Allow re-try or implement stricter lockout if desired.
        return
    end

    -- Success: Grant reward, log, notify, and remove drop.
    local itemValue = drop.item.value or 0
    addPlayerMoney(robberId, itemValue)
    -- savePlayerData(robberId) -- save is handled by AddXP

    LogAdminAction(string.format("Contraband Collected: Robber %s (ID: %d) collected %s from drop %s for $%d.",
                    GetPlayerName(robberId) or "N/A", robberId, drop.item.name, dropId, itemValue))
    TriggerClientEvent('cops_and_robbers:showNotification', robberId, string.format("~g~You collected %s worth $%d!", drop.item.name, itemValue))
    AddXP(robberId, 'contraband_collected') -- Grant XP, which also saves player data.

    -- Announce to everyone else that this drop is collected and remove it.
    TriggerClientEvent('cops_and_robbers:contrabandDropCollected', -1, dropId, GetPlayerName(robberId) or "N/A", drop.item.name)
    activeContrabandDrops[dropId] = nil -- Remove the drop, making it unavailable for others.
end)

-----------------------------------------------------------

-- =====================================
--    CRIME NOTIFICATION & HEIST MANAGEMENT
-- =====================================

-- Notifies nearby cops about a crime event (e.g., bank heists, store robberies).
-- @param crimeKey string: A unique key for the crime instance (e.g., "bank_1", "store_LTDGas").
-- @param crimeLocation vector3: The coordinates of the crime.
-- @param crimeDisplayName string: The user-friendly name of the location/event (e.g., "Pacific Standard Bank").
-- @param messageFormat string: The notification message format (e.g., "~r~Crime Alert! %s is being robbed!").
-- @param soundName string (optional): Name of a sound to play for the notified cops (client handles playback).
local function NotifyNearbyCopsGeneric(crimeKey, crimeLocation, crimeDisplayName, messageFormat, soundName)
    if not crimeLocation or not crimeDisplayName or not messageFormat then
        print(string.format("Error: NotifyNearbyCopsGeneric - Missing parameters. Key: %s", tostring(crimeKey)))
        return
    end

    local notificationMessage = string.format(messageFormat, crimeDisplayName)
    local notificationRadius = Config.HeistRadius or 1000.0 -- General radius for these types of alerts.

    for copId, _ in pairs(cops) do -- Iterate only over players in the 'cops' table.
        local copPData = getPlayerData(copId)
        local copPosData = playerPositions[copId]
        if copPData and copPosData and copPosData.position then
            local copPosVec = vector3(copPosData.position.x, copPosData.position.y, copPosData.position.z)
            if #(copPosVec - crimeLocation) <= notificationRadius then
                -- Send a more structured event to client for better handling of blips, sounds, messages.
                TriggerClientEvent('cops_and_robbers:genericCrimeNotification', copId, {
                    key = crimeKey,
                    location = crimeLocation,
                    displayName = crimeDisplayName,
                    message = notificationMessage,
                    sound = soundName -- Client can decide to play this or not.
                })
            end
        end
    end
end

-- Start a bank heist if the robber is not on cooldown.
RegisterNetEvent('cops_and_robbers:startHeist')
AddEventHandler('cops_and_robbers:startHeist', function(bankId)
    local src = source
    if not robbers[src] then -- Check if player is a robber using the 'robbers' table.
        TriggerClientEvent('cops_and_robbers:showNotification', src, "~r~Only Robbers can start heists.")
        return
    end

    local currentTime = os.time()
    -- Assuming heistCooldowns stores player-specific cooldowns.
    if heistCooldowns[src] and currentTime < heistCooldowns[src] then
        local remainingTime = heistCooldowns[src] - currentTime
        TriggerClientEvent('cops_and_robbers:showNotification', src, string.format("~r~You are on heist cooldown for another %d seconds.", remainingTime))
        return
    end

    local bank = Config.BankVaults[bankId] -- bankId is expected to be the numeric ID from the config table.
    if not bank then
        LogAdminAction(string.format("Bank Heist Fail: Robber %s (ID: %d) attempted invalid bank ID %s.", GetPlayerName(src) or "N/A", src, tostring(bankId)))
        TriggerClientEvent('cops_and_robbers:heistFailed', src, "~r~Invalid bank ID selected.")
        return
    end

    -- Set cooldown for the player for this specific type of major heist.
    local cooldownDuration = (Config.HeistSettings and Config.HeistSettings.globalCooldownMs and Config.HeistSettings.globalCooldownMs / 1000) or Config.HeistCooldown or 600
    heistCooldowns[src] = currentTime + cooldownDuration

    NotifyNearbyCopsGeneric("bank_"..bank.id, bank.location, bank.name, "~r~Bank Heist in Progress!~s~Location: %s", "Bank_Alarm")
    LogAdminAction(string.format("Bank Heist Started: Robber %s (ID: %d) started heist at Bank %s (%s).", GetPlayerName(src) or "N/A", src, bankId, bank.name))

    local heistDurationSecs = (Config.HeistTimers and Config.HeistTimers.defaultHeistDurationSecs) or 600
    TriggerClientEvent('cops_and_robbers:showHeistTimerUI', src, bank.name, heistDurationSecs) -- Send duration in seconds.
end)

-- =====================================
--        WANTED LEVEL SYSTEM (Notifications to Cops)
-- =====================================

-- Function to notify cops of a wanted robber's last known position.
-- This is a conceptual function; actual implementation depends on how detailed notifications should be.
local function notifyCopsOfWantedRobber(robberId, robberName, robberPosition, wantedLevelStars)
    if not robberPosition or not robberPosition.x then return end -- Ensure position is valid.

    local message = string.format("~y~Wanted Suspect: %s (%d stars) last seen near %s.", robberName, wantedLevelStars, "Street Name (TODO)") -- TODO: Reverse geocode position to street name if possible.

    for copId, _ in pairs(cops) do
        -- Could add distance check here to only notify cops within a certain range of the robber or the crime.
        TriggerClientEvent('cops_and_robbers:showNotification', copId, message)
        -- More advanced: TriggerClientEvent('cops_and_robbers:updateWantedSuspectBlip', copId, robberId, robberPosition, wantedLevelStars)
    end
end

-- Periodically check for highly wanted robbers and notify cops.
Citizen.CreateThread(function()
    local checkInterval = 30000 -- Check every 30 seconds.
    local wantedThresholdForAlert = (Config.WantedSettings and Config.WantedSettings.levels and Config.WantedSettings.levels[3] and Config.WantedSettings.levels[3].stars) or 3 -- e.g., 3 stars

    while true do
        Citizen.Wait(checkInterval)
        for robberId, pData in pairs(playerData) do
            if playerRoles[robberId] == 'robber' and pData.currentWantedStars and pData.currentWantedStars >= wantedThresholdForAlert then
                local posData = playerPositions[robberId]
                if posData and posData.position then
                    -- LogAdminAction(string.format("Alerting cops about wanted player %s (%d stars)", GetPlayerName(robberId) or "N/A", pData.currentWantedStars)) -- Debug
                    notifyCopsOfWantedRobber(robberId, GetPlayerName(robberId) or "Unknown", posData.position, pData.currentWantedStars)
                end
            end
        end
    end
end)

-- =====================================
--        NUI CALLBACKS (SERVER-SIDE)
-- =====================================
-- These functions handle callbacks from the NUI interface (e.g., store purchases, admin panel actions).

-- Handles item purchase requests from NUI. This largely mirrors 'cops_and_robbers:purchaseItem' but is called from NUI.
RegisterNUICallback('buyItem', function(data, cb)
    local src = source
    local itemId = data.itemId
    local quantity = tonumber(data.quantity) or 1
    local pData = getPlayerData(src)

    if not pData then cb({ status = 'failed', message = 'Player data not found.' }); return end

    local item = getItemById(itemId)
    if not item then cb({ status = 'failed', message = 'Invalid item.' }); return end

    if quantity < 1 or quantity > 100 then cb({ status = 'failed', message = 'Invalid quantity.' }); return end

    if item.forCop and (pData.role ~= 'cop') then cb({ status = 'failed', message = 'This item is restricted to Cops.'}); return end
    if item.minLevelCop and pData.role == 'cop' and (pData.level or 1) < item.minLevelCop then cb({ status = 'failed', message = string.format("~r~Requires Cop Level %d.", item.minLevelCop)}); return end
    if item.minLevelRobber and pData.role == 'robber' and (pData.level or 1) < item.minLevelRobber then cb({ status = 'failed', message = string.format("~r~Requires Robber Level %d.", item.minLevelRobber)}); return end

    local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
    local totalPrice = dynamicPrice * quantity
    if pData.money < totalPrice then cb({ status = 'failed', message = 'Insufficient funds.' }); return end

    if givePlayerItem(src, item, quantity) then
        removePlayerMoney(src, totalPrice)
        if Config.DynamicEconomy and Config.DynamicEconomy.enabled then
            local timestamp = os.time()
            purchaseHistory[itemId] = purchaseHistory[itemId] or {}
            for i = 1, quantity do table.insert(purchaseHistory[itemId], timestamp) end
            local updatedHistory = {}
            local timeframeStart = timestamp - (Config.DynamicEconomy.popularityTimeframe or 3*60*60)
            for _, purchaseTime in ipairs(purchaseHistory[itemId]) do if type(purchaseTime) == "number" and purchaseTime >= timeframeStart then table.insert(updatedHistory, purchaseTime) end end
            purchaseHistory[itemId] = updatedHistory
            savePurchaseHistory()
        end
        savePlayerData(src)
        LogAdminAction(string.format("NUI Purchase: Player %s (ID: %d) purchased %d x %s for $%d.", GetPlayerName(src) or "N/A", src, quantity, item.name or itemId, totalPrice))
        cb({ status = 'success', itemName = item.name, quantity = quantity, newBalance = pData.money })
    else
        -- givePlayerItem should have sent a specific failure reason.
        LogAdminAction(string.format("NUI Purchase Fail (givePlayerItem): Player %s (ID: %d) for item %s.", GetPlayerName(src) or "N/A", src, item.name or itemId))
        cb({ status = 'failed', message = 'Failed to receive item.'}) -- Generic, as givePlayerItem sends specifics
    end
end)

-- Handles item sell requests from NUI.
RegisterNUICallback('sellItem', function(data, cb)
    local src = source
    local itemId = data.itemId
    local quantity = tonumber(data.quantity) or 1
    local pData = getPlayerData(src)

    if not pData then cb({ status = 'failed', message = 'Player data not found.' }); return end
    LogAdminAction(string.format("NUI Sell Attempt: Player %s (ID: %d) item %s, quantity %d.", GetPlayerName(src) or "N/A", src, itemId, quantity))

    local item = getItemById(itemId)
    if not item then cb({ status = 'failed', message = 'Invalid item.' }); return end

    if quantity < 1 or quantity > 1000 then cb({ status = 'failed', message = 'Invalid quantity.' }); return end

    local dynamicPrice = getDynamicPrice(itemId) or item.basePrice
    local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
    local sellPricePerUnit = math.floor(dynamicPrice * sellPriceFactor)
    if sellPricePerUnit <= 0 then cb({ status = 'failed', message = 'This item cannot be sold for a valid price.' }); return end
    local totalSellValue = sellPricePerUnit * quantity

    local soldSuccessfully = false
    if item.category == "Weapons" or item.category == "Melee Weapons" then
        if quantity > 1 then cb({ status = 'failed', message = 'You can only sell one weapon at a time.' }); return end
        if playerHasWeapon(src, item.itemId) then
            if removePlayerWeapon(src, item.itemId) then addPlayerMoney(src, sellPricePerUnit); soldSuccessfully = true; end
        else cb({ status = 'failed', message = 'You do not own this weapon.' }); return end
    else
        local currentItemCount = getPlayerInventoryItemCount(src, item.itemId)
        if currentItemCount >= quantity then
            if removePlayerInventoryItem(src, item.itemId, quantity) then addPlayerMoney(src, totalSellValue); soldSuccessfully = true; end
        else cb({ status = 'failed', message = string.format("Insufficient items. You have %d.", currentItemCount) }); return end
    end

    if soldSuccessfully then
        savePlayerData(src)
        LogAdminAction(string.format("NUI Sell: Player %s (ID: %d) sold %d x %s for $%d.", GetPlayerName(src) or "N/A", src, quantity, item.name or itemId, totalSellValue))
        cb({ status = 'success', itemName = item.name, quantity = quantity, newBalance = pData.money })
    else
        LogAdminAction(string.format("NUI Sell Fail (Logic): Player %s (ID: %d) for item %s.", GetPlayerName(src) or "N/A", src, item.name or itemId))
        cb({ status = 'failed', message = 'Could not sell item(s).' })
    end
end)

-- Handles NUI request to get the player's current inventory.
RegisterNUICallback('getPlayerInventory', function(data, cb)
    local src = source
    local pData = getPlayerData(src)
    local inventoryForClient = {}

    if pData then
        if pData.inventory and type(pData.inventory) == "table" then
            for itemId, count in pairs(pData.inventory) do
                if count > 0 then
                    local itemDetails = getItemById(itemId)
                    if itemDetails then
                        local dynamicPrice = getDynamicPrice(itemId) or itemDetails.basePrice
                        local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
                        local sellPrice = math.floor(dynamicPrice * sellPriceFactor)
                        table.insert(inventoryForClient, {
                            name = itemDetails.name, itemId = itemId, count = count,
                            sellPrice = sellPrice, category = itemDetails.category
                        })
                    else print(string.format("Warning: NUI GetInventory - Item config not found for itemId '%s' in player %s's inventory.", itemId, src)) end
                end
            end
        end
        if pData.weapons and type(pData.weapons) == "table" then
            for weaponHash, _ in pairs(pData.weapons) do
                local itemDetails = getItemById(weaponHash)
                if itemDetails then
                    local dynamicPrice = getDynamicPrice(weaponHash) or itemDetails.basePrice
                    local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
                    local sellPrice = math.floor(dynamicPrice * sellPriceFactor)
                    table.insert(inventoryForClient, {
                        name = itemDetails.name, itemId = weaponHash, count = 1,
                        sellPrice = sellPrice, category = itemDetails.category
                    })
                else print(string.format("Warning: NUI GetInventory - Item config not found for weaponHash '%s' in player %s's weapons.", weaponHash, src)) end
            end
        end
        cb({ items = inventoryForClient })
    else
        LogAdminAction(string.format("NUI GetInventory Fail: Player %s (ID: %d) - no player data found.", GetPlayerName(src) or "N/A", src))
        cb({ items = {} })
    end
end)


-- =====================================
>>>>>>> REPLACE
