-- server.lua
-- Version: <current_version_after_bounty_implementation_and_xp_perk_fixes>
-- Main changes in this version:
-- - Integrated Cop XP awards.
-- - Implemented server-side item/vehicle access restrictions based on level and role.
-- - Added server-side perk example: Increased Armor Durability for Cops.
-- - Added new crime 'power_grid_sabotaged_crime' handling.
-- - Added K9 Engagement tracking for K9 assist XP.
-- - Implemented Bounty System (Phase 2).
-- - Added missing XP awards for Armored Car Heist & Contraband.
-- - Implemented server-side logic for "extra_spike_strips" & "faster_contraband_collection" perks.
-- - Refined Cop Arrest XP based on wanted level.

-- Configuration shortcuts (Config must be loaded before Log if Log uses it)
-- However, config.lua is a shared_script, so Config global should be available.
-- For safety, ensure Log definition handles potential nil Config if script order changes.
local Config = Config -- Keep this near the top as Log depends on it.

local function Log(message, level)
    level = level or "info"
    -- Only show critical errors and warnings to reduce spam
    if level == "error" or level == "warn" then
        print("[CNR_CRITICAL_LOG] [" .. string.upper(level) .. "] " .. message)
    end
end

function shallowcopy(original)
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = v
    end
    return copy
end

function tablelength(T)
    if not T or type(T) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function MinimizeInventoryForSync(richInventory)
    if not richInventory then return {} end
    local minimalInv = {}
    for itemId, itemData in pairs(richInventory) do
        if itemData and itemData.count then
            minimalInv[itemId] = { count = itemData.count }
        end
    end
    return minimalInv
end

-- Safe table assignment wrapper for player IDs
local function SafeSetByPlayerId(tbl, playerId, value)
    if tbl and playerId and type(playerId) == "number" and playerId > 0 then
        tbl[playerId] = value
    end
end
local function SafeRemoveByPlayerId(tbl, playerId)
    if tbl and playerId and type(playerId) == "number" and playerId > 0 then
        tbl[playerId] = nil
    end
end
local function SafeGetByPlayerId(tbl, playerId)
    if tbl and playerId and type(playerId) == "number" and playerId > 0 then
        return tbl[playerId]
    end
    return nil
end

-- Safe wrapper for TriggerClientEvent to prevent nil player ID errors
local function SafeTriggerClientEvent(eventName, playerId, ...)
    if playerId and type(playerId) == "number" and playerId > 0 and GetPlayerName(playerId) then
        TriggerClientEvent(eventName, playerId, ...)
        return true
    else
        Log(string.format("SafeTriggerClientEvent: Invalid or offline player ID %s for event %s", tostring(playerId), eventName), "warn")
        return false
    end
end

-- Global state tables
local playersData = {}
local copsOnDuty = {}
local robbersActive = {}
local jail = {}
local wantedPlayers = {}
local activeCooldowns = {}
local purchaseHistory = {}
local bannedPlayers = {}
local k9Engagements = {}
local activeBounties = {}
local playerDeployedSpikeStripsCount = {} -- For extra_spike_strips perk
local activeSpikeStrips = {} -- To manage strip IDs and removal: {stripId = {copId = src, location = ...}}
local nextSpikeStripId = 1

-- Table to store last report times for specific crimes per player
local clientReportCooldowns = {}
local activeSubdues = {} -- Tracks active subdue attempts: activeSubdues[robberId] = { copId = copId, expiryTimer = timer }

-- Forward declaration for functions that might be called before definition due to event handlers
local GetPlayerLevelAndXP, AddXP, SetPlayerRole, IsPlayerCop, IsPlayerRobber, SavePlayerData, LoadPlayerData, CheckAndPlaceBounty, UpdatePlayerWantedLevel, ReduceWantedLevel, SendToJail

local SafeGetPlayerName = SafeGetPlayerName or function(id) return GetPlayerName(id) end


-- Function to load bans from bans.json
local function LoadBans()
    local banFile = LoadResourceFile(GetCurrentResourceName(), "bans.json")
    if banFile then
        local success, loaded = pcall(json.decode, banFile)
        if success and type(loaded) == "table" then
            for identifier, banInfo in pairs(loaded) do
                if not bannedPlayers[identifier] then -- Merge, Config.BannedPlayers can take precedence or be defaults
                    bannedPlayers[identifier] = banInfo
                end
            end
            Log("Loaded " .. tablelength(loaded) .. " bans from bans.json")
        else
            Log("Failed to decode bans.json: " .. tostring(loaded), "error")
        end
    else
        Log("bans.json not found. Only using bans from Config.BannedPlayers.")
    end
end

local function SaveBans()
    local success = SaveResourceFile(GetCurrentResourceName(), "bans.json", json.encode(bannedPlayers), -1)
    if success then
        Log("Saved bans to bans.json")
    else
        Log("Failed to save bans.json", "error")
    end
end

-- Function to load purchase history from purchase_history.json
local function LoadPurchaseHistory()
    local historyFile = LoadResourceFile(GetCurrentResourceName(), "purchase_history.json")
    if historyFile then
        local success, loaded = pcall(json.decode, historyFile)
        if success and type(loaded) == "table" then
            purchaseHistory = loaded
            Log("Loaded purchase history from purchase_history.json. Count: " .. tablelength(purchaseHistory))
        else
            Log("Failed to decode purchase_history.json: " .. tostring(loaded), "error")
            purchaseHistory = {} -- Start fresh if file is corrupt
        end
    else
        Log("purchase_history.json not found. Initializing empty history.")
        purchaseHistory = {}
    end
end

local function SavePurchaseHistory()
    if not Config.DynamicEconomy or not Config.DynamicEconomy.enabled then return end -- Only save if enabled
    local success = SaveResourceFile(GetCurrentResourceName(), "purchase_history.json", json.encode(purchaseHistory), -1)
    if success then
        Log("Saved purchase history to purchase_history.json")
    else
        Log("Failed to save purchase_history.json", "error")
    end
end

-- =================================================================================================
-- HELPER FUNCTIONS
-- =================================================================================================

-- Helper function to get a player's license identifier
local function GetPlayerLicense(playerId)
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

local function GetCnrPlayerData(playerId)
    return playersData[tonumber(playerId)]
end

-- Global access function for other server scripts
_G.GetCnrPlayerData = GetCnrPlayerData

local function GetPlayerMoney(playerId)
    local pId = tonumber(playerId)
    local pData = playersData[pId]
    if pData and pData.money then
        return pData.money
    end
    return 0
end

local function AddPlayerMoney(playerId, amount, type)
    type = type or 'cash' -- Assuming 'cash' is the primary type. Add handling for 'bank' if needed.
    local pId = tonumber(playerId)
    if not pId or pId <= 0 then
        Log(string.format("AddPlayerMoney: Invalid player ID %s.", tostring(playerId)), "error")
        return false
    end
    
    local pData = playersData[pId]
    if pData then
        if type == 'cash' then
            pData.money = (pData.money or 0) + amount
            Log(string.format("Added %d to player %s's %s account. New balance: %d", amount, playerId, type, pData.money))
            -- Send a notification to the client
            SafeTriggerClientEvent('chat:addMessage', pId, { args = {"^2Money", string.format("You received $%d.", amount)} })
            local pDataForBasicInfo = shallowcopy(pData)
            pDataForBasicInfo.inventory = nil
            SafeTriggerClientEvent('cnr:updatePlayerData', pId, pDataForBasicInfo)
            -- Inventory is not changed by this function, so no need to send cnr:syncInventory
            return true
        else
            Log(string.format("AddPlayerMoney: Unsupported account type '%s' for player %s.", type, playerId), "warn")
            return false
        end
    else
        Log(string.format("AddPlayerMoney: Player data not found for %s.", playerId), "error")
        return false
    end
end

local function RemovePlayerMoney(playerId, amount, type)
    type = type or 'cash'
    local pId = tonumber(playerId)
    if not pId or pId <= 0 then
        Log(string.format("RemovePlayerMoney: Invalid player ID %s.", tostring(playerId)), "error")
        return false
    end
    
    local pData = playersData[pId]
    if pData then
        if type == 'cash' then
            if (pData.money or 0) >= amount then
                pData.money = pData.money - amount
                Log(string.format("Removed %d from player %s's %s account. New balance: %d", amount, playerId, type, pData.money))
                local pDataForBasicInfo = shallowcopy(pData)
                pDataForBasicInfo.inventory = nil
                SafeTriggerClientEvent('cnr:updatePlayerData', pId, pDataForBasicInfo)
                -- Inventory is not changed by this function, so no need to send cnr:syncInventory
                return true
            else
                -- Notify the client about insufficient funds
                SafeTriggerClientEvent('chat:addMessage', pId, { args = {"^1Error", "You don't have enough money."} })
                return false
            end
        else
            Log(string.format("RemovePlayerMoney: Unsupported account type '%s' for player %s.", type, playerId), "warn")
            return false
        end
    else
        Log(string.format("RemovePlayerMoney: Player data not found for %s.", playerId), "error")
        return false
    end
end

local function IsAdmin(playerId)
    local src = tonumber(playerId) -- Ensure it is a number for GetPlayerIdentifiers
    if not src then return false end

    local identifiers = GetPlayerIdentifiers(tostring(src))
    if not identifiers then return false end

    if not Config or type(Config.Admins) ~= "table" then
        Log("IsAdmin Check: Config.Admins is not loaded or not a table.", "error")
        return false -- Should not happen if Config.lua is correct
    end

    for _, identifier in ipairs(identifiers) do
        if Config.Admins[identifier] then
            Log("IsAdmin Check: Player " .. src .. " with identifier " .. identifier .. " IS an admin.", "info")
            return true
        end
    end
    Log("IsAdmin Check: Player " .. src .. " is NOT an admin.", "info")
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    if pData then return pData.role end
    return "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    -- Ensure basePrice is a number
    basePrice = tonumber(basePrice) or 0
    
    if not Config.DynamicEconomy or not Config.DynamicEconomy.enabled then
        return basePrice
    end

    local currentTime = os.time()
    local timeframe = Config.DynamicEconomy.popularityTimeframe or (3 * 60 * 60) -- Default 3 hours
    local recentPurchases = 0

    for _, purchase in ipairs(purchaseHistory) do
        if purchase.itemId == itemId and (currentTime - purchase.timestamp) <= timeframe then
            recentPurchases = recentPurchases + (purchase.quantity or 1)
        end
    end

    local price = basePrice
    if recentPurchases > (Config.DynamicEconomy.popularityThresholdHigh or 10) then
        price = math.floor(basePrice * (Config.DynamicEconomy.priceIncreaseFactor or 1.2))
        Log(string.format("DynamicPrice: Item %s popular (%d purchases), price increased to %d from %d", itemId, recentPurchases, price, basePrice))
    elseif recentPurchases < (Config.DynamicEconomy.popularityThresholdLow or 2) then
        price = math.floor(basePrice * (Config.DynamicEconomy.priceDecreaseFactor or 0.8))
        Log(string.format("DynamicPrice: Item %s unpopular (%d purchases), price decreased to %d from %d", itemId, recentPurchases, price, basePrice))
    else
        Log(string.format("DynamicPrice: Item %s normal popularity (%d purchases), price remains %d", itemId, recentPurchases, price))
    end
    return price
end

-- =================================================================================================
-- PLAYER DATA MANAGEMENT (XP, LEVELS, SAVING/LOADING)
-- =================================================================================================

-- Simple (or placeholder) inventory interaction functions
-- In a full system, these would likely call exports from inventory_server.lua


-- OLD INVENTORY FUNCTIONS REMOVED - Using enhanced versions with save marking below

-- Ensure InitializePlayerInventory is defined (even if simple)
function InitializePlayerInventory(pData, playerId)
    if not pData then
        Log("InitializePlayerInventory: pData is nil for playerId " .. (playerId or "unknown"), "error")
        return
    end
    pData.inventory = pData.inventory or {}
    -- Log("InitializePlayerInventory: Ensured inventory table exists for player " .. (playerId or "unknown"), "info")
end

LoadPlayerData = function(playerId)
    -- Log(string.format("LoadPlayerData: Called for player ID %s.", playerId), "info")
    local pIdNum = tonumber(playerId)
    if not pIdNum or pIdNum <= 0 then
        Log(string.format("LoadPlayerData: Invalid player ID %s", tostring(playerId)), "error")
        return
    end
    
    -- Check if player is still online
    if not GetPlayerName(pIdNum) then
        Log(string.format("LoadPlayerData: Player %s is not online", pIdNum), "warn")
        return
    end

    -- Log(string.format("LoadPlayerData: Attempting to get license for player %s.", pIdNum), "info")
    local license = GetPlayerLicense(pIdNum) -- Use helper to get license

    local filename = nil
    if license then
        filename = "player_data/" .. license:gsub(":", "") .. ".json"
    else
        Log(string.format("LoadPlayerData: CRITICAL - Could not find license for player %s (Name: %s) even after playerConnecting. Attempting PID fallback (pid_%s.json), but this may lead to data inconsistencies or load failures if server IDs are not static.", pIdNum, GetPlayerName(pIdNum) or "N/A", pIdNum), "error")
        -- The playerConnecting handler should ideally prevent this state for legitimate players.
        -- If this occurs, it might be due to:
        -- 1. A non-player entity somehow triggering this (e.g., faulty admin command or event).
        -- 2. An issue with identifier loading that even retries couldn't solve.
        -- 3. The player disconnected very rapidly after connecting, before identifiers were fully processed by all systems.
        filename = "player_data/pid_" .. pIdNum .. ".json"
    end

    -- Log(string.format("LoadPlayerData: Using filename %s for player %s.", filename, pIdNum), "info")
    -- Log(string.format("LoadPlayerData: Attempting to load data from file %s for player %s.", filename, pIdNum), "info")
    local fileData = LoadResourceFile(GetCurrentResourceName(), filename)
    local loadedMoney = 0 -- Default money if not in save file or new player

    if fileData then
        -- Log(string.format("LoadPlayerData: File %s found for player %s. Attempting to decode JSON.", filename, pIdNum), "info")
        local success, data = pcall(json.decode, fileData)
        if success and type(data) == "table" then
            playersData[pIdNum] = data
            loadedMoney = data.money or 0 -- Load money from file if exists
            Log("Loaded player data for " .. pIdNum .. " from " .. filename .. ". Level: " .. (data.level or 0) .. ", Role: " .. (data.role or "citizen") .. ", Money: " .. loadedMoney)
        else
            Log("Failed to decode player data for " .. pIdNum .. " from " .. filename .. ". Using defaults. Error: " .. tostring(data), "error")
            playersData[pIdNum] = nil -- Force default initialization
        end
    else
        Log("No save file found for " .. pIdNum .. " at " .. filename .. ". Initializing default data.")
        playersData[pIdNum] = nil -- Force default initialization
    end

    if not playersData[pIdNum] then
        -- Log(string.format("LoadPlayerData: Initializing new default data structure for player %s.", pIdNum), "info")
        local playerPed = GetPlayerPed(pIdNum)
        local initialCoords = playerPed and GetEntityCoords(playerPed) or vector3(0,0,70) -- Fallback coords

        playersData[pIdNum] = {
            xp = 0, level = 1, role = "citizen",
            lastKnownPosition = initialCoords, -- Use current coords or a default spawn
            perks = {}, armorModifier = 1.0, bountyCooldownUntil = 0,
            money = Config.DefaultStartMoney or 5000 -- Use a config value for starting money
        }
        Log("Initialized default data for player " .. pIdNum .. ". Money: " .. playersData[pIdNum].money)
    else
        -- Ensure money is set if loaded from file, otherwise use default (already handled by loadedMoney init)
        playersData[pIdNum].money = playersData[pIdNum].money or Config.DefaultStartMoney or 5000
    end

    -- NEW PLACEMENT FOR isDataLoaded
    if playersData[pIdNum] then
        playersData[pIdNum].isDataLoaded = true
        Log("LoadPlayerData: Player data structure populated and isDataLoaded set to true for " .. pIdNum .. ".") -- Combined log
    else
        Log("LoadPlayerData: CRITICAL - playersData[pIdNum] is nil AFTER data load/init attempt for " .. pIdNum .. ". Cannot set isDataLoaded or proceed.", "error")
        return -- Cannot proceed if playersData[pIdNum] is still nil here
    end

    -- Now call functions that might rely on isDataLoaded or a fully ready player object
    SetPlayerRole(pIdNum, playersData[pIdNum].role, true)
    ApplyPerks(pIdNum, playersData[pIdNum].level, playersData[pIdNum].role)

    -- Log(string.format("LoadPlayerData: About to call InitializePlayerInventory for player %s.", pIdNum), "info")
    if playersData[pIdNum] then -- Re-check pData as ApplyPerks or SetPlayerRole might have side effects (though unlikely to nil it)
        InitializePlayerInventory(playersData[pIdNum], pIdNum)
    else
        Log("LoadPlayerData: CRITICAL - playersData[pIdNum] became nil before InitializePlayerInventory for " .. pIdNum, "error")
    end    local pDataForLoad = shallowcopy(playersData[pIdNum])
    pDataForLoad.inventory = nil
    SafeTriggerClientEvent('cnr:updatePlayerData', pIdNum, pDataForLoad)
    SafeTriggerClientEvent('cnr:syncInventory', pIdNum, MinimizeInventoryForSync(playersData[pIdNum].inventory))
    SafeTriggerClientEvent('cnr:wantedLevelSync', pIdNum, wantedPlayers[pIdNum] or { wantedLevel = 0, stars = 0 })
    -- Original position of isDataLoaded setting is now removed.
end

SavePlayerData = function(playerId)
    local pIdNum = tonumber(playerId)
    local pData = GetCnrPlayerData(pIdNum)
    if not pData then Log("SavePlayerData: No data for player " .. pIdNum, "warn"); return end

    local license = GetPlayerLicense(pIdNum) -- Use helper

    if not license then
        Log("SavePlayerData: Could not find license for player " .. pIdNum .. ". Using numeric ID as fallback filename. Data might not persist correctly across sessions if ID changes.", "warn")
        license = "pid_" .. pIdNum -- Fallback, not ideal for persistence if server IDs are not static
    end

    local filename = "player_data/" .. license:gsub(":", "") .. ".json"
    -- Ensure lastKnownPosition is updated before saving
    local playerPed = GetPlayerPed(pIdNum)
    if playerPed and GetEntityCoords(playerPed) then
        pData.lastKnownPosition = GetEntityCoords(playerPed)
    end
    local success = SaveResourceFile(GetCurrentResourceName(), filename, json.encode(pData), -1)
    if success then
        Log("Saved player data for " .. pIdNum .. " to " .. filename .. ".")
    else
        Log("Failed to save player data for " .. pIdNum .. " to " .. filename .. ".", "error")
    end
end

SetPlayerRole = function(playerId, role, skipNotify)
    local pIdNum = tonumber(playerId)
    if not pIdNum or pIdNum <= 0 then
        Log(string.format("SetPlayerRole: Invalid player ID %s", tostring(playerId)), "error")
        return
    end
    
    -- Check if player is still online
    if not GetPlayerName(pIdNum) then
        Log(string.format("SetPlayerRole: Player %s is not online", pIdNum), "warn")
        return
    end
    
    local playerName = GetPlayerName(pIdNum) or "Unknown"
    -- Log(string.format("SetPlayerRole DEBUG: Attempting to set role for pIdNum: %s, playerName: %s, to newRole: %s. Current role in playersData: %s", pIdNum, playerName, role, (playersData[pIdNum] and playersData[pIdNum].role or "nil_or_no_pData")), "info")

    local pData = playersData[pIdNum] -- Get pData directly
    if not pData or not pData.isDataLoaded then -- Check both for robustness
        Log(string.format("SetPlayerRole: Attempted to set role for %s (Name: %s) but data not loaded/ready. Role: %s. pData exists: %s, isDataLoaded: %s. This should have been caught by the caller.", pIdNum, playerName, role, tostring(pData ~= nil), tostring(pData and pData.isDataLoaded)), "warn")
        -- Do NOT trigger 'cnr:roleSelected' here, as the caller handles it.
        SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^1Error", "Role change failed: Player data integrity issue."} })
        return
    end

    -- Log(string.format("SetPlayerRole DEBUG: Before role update. pIdNum: %s, current playersData[pIdNum].role: %s, new role to set: %s", pIdNum, (playersData[pIdNum] and playersData[pIdNum].role or "nil_or_no_pData"), role), "info")
    pData.role = role
    -- Log(string.format("SetPlayerRole DEBUG: After role update. pIdNum: %s, playersData[pIdNum].role is now: %s", pIdNum, playersData[pIdNum].role), "info")
    -- player.Functions.SetMetaData("role", role) -- Example placeholder

    if role == "cop" then
        SafeSetByPlayerId(copsOnDuty, pIdNum, true)
        SafeRemoveByPlayerId(robbersActive, pIdNum)
        -- player.Functions.SetJob("leo", 0) -- Placeholder for framework integration
        SafeTriggerClientEvent('cnr:setPlayerRole', pIdNum, "cop")
        if not skipNotify then SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^3Role", "You are now a Cop."} }) end
        Log("Player " .. pIdNum .. " (" .. playerName .. ") set to Cop role.")
        SafeTriggerClientEvent('cops_and_robbers:bountyListUpdate', pIdNum, activeBounties)
    elseif role == "robber" then
        SafeSetByPlayerId(robbersActive, pIdNum, true)
        SafeRemoveByPlayerId(copsOnDuty, pIdNum)
        -- player.Functions.SetJob("unemployed", 0) -- Placeholder for framework integration
        SafeTriggerClientEvent('cnr:setPlayerRole', pIdNum, "robber")
        if not skipNotify then SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^3Role", "You are now a Robber."} }) end
        Log("Player " .. pIdNum .. " (" .. playerName .. ") set to Robber role.")
    else
        SafeRemoveByPlayerId(copsOnDuty, pIdNum)
        SafeRemoveByPlayerId(robbersActive, pIdNum)
        -- player.Functions.SetJob("unemployed", 0) -- Placeholder for framework integration
        SafeTriggerClientEvent('cnr:setPlayerRole', pIdNum, "citizen")
        if not skipNotify then SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^3Role", "You are now a Citizen."} }) end
        Log("Player " .. pIdNum .. " (" .. playerName .. ") set to Citizen role.")
    end
    ApplyPerks(pIdNum, playersData[pIdNum].level, role) -- Re-apply/update perks based on new role
    -- Log(string.format("SetPlayerRole DEBUG: Before TriggerClientEvent cnr:updatePlayerData. pIdNum: %s, Data being sent: %s", pIdNum, json.encode(playersData[pIdNum])), "info")
    local pDataForBasicInfo = shallowcopy(playersData[pIdNum])
    pDataForBasicInfo.inventory = nil
    SafeTriggerClientEvent('cnr:updatePlayerData', pIdNum, pDataForBasicInfo)
    SafeTriggerClientEvent('cnr:syncInventory', pIdNum, MinimizeInventoryForSync(playersData[pIdNum].inventory))
end

IsPlayerCop = function(playerId) return GetPlayerRole(playerId) == "cop" end
IsPlayerRobber = function(playerId) return GetPlayerRole(playerId) == "robber" end

local function CalculateLevel(xp, role)
    if not Config.LevelingSystemEnabled then return 1 end -- Return level 1 if system disabled
    local currentLevel = 1
    local cumulativeXp = 0

    -- Iterate up to Config.MaxLevel - 1 because XPTable defines XP to reach NEXT level
    for level = 1, (Config.MaxLevel or 10) - 1 do
        local xpForNext = (Config.XPTable and Config.XPTable[level]) or 999999
        cumulativeXp = cumulativeXp + xpForNext
        if xp >= cumulativeXp then
            currentLevel = level + 1
        else
            break -- Stop if player does not have enough XP for this level
        end
    end
    -- Ensure level does not exceed MaxLevel
    return math.min(currentLevel, (Config.MaxLevel or 10))
end

AddXP = function(playerId, amount, type)
    local pIdNum = tonumber(playerId)
    if not pIdNum or pIdNum <= 0 then
        Log("AddXP: Invalid player ID " .. tostring(playerId), "error")
        return
    end
    
    local pData = GetCnrPlayerData(pIdNum)
    if not pData then Log("AddXP: Player " .. (pIdNum or "unknown") .. " data not init.", "error"); return end
    if type and pData.role ~= type and type ~= "general" then return end

    pData.xp = pData.xp + amount
    local oldLevel = pData.level
    local newLevel = CalculateLevel(pData.xp, pData.role)

    if newLevel > oldLevel then
        pData.level = newLevel
        SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^2Level Up!", string.format("Congratulations! You've reached Level %d!", newLevel)} })
        SafeTriggerClientEvent('cnr:levelUp', pIdNum, newLevel, pData.xp)
        Log(string.format("Player %s leveled up to %d (XP: %d, Role: %s)", pIdNum, newLevel, pData.xp, pData.role))
        ApplyPerks(pIdNum, newLevel, pData.role)
    else
        SafeTriggerClientEvent('cnr:xpGained', pIdNum, amount, pData.xp)
        Log(string.format("Player %s gained %d XP (Total: %d, Role: %s)", pIdNum, amount, pData.xp, pData.role))
    end
    local pDataForBasicInfo = shallowcopy(pData)
    pDataForBasicInfo.inventory = nil
    SafeTriggerClientEvent('cnr:updatePlayerData', pIdNum, pDataForBasicInfo)
    SafeTriggerClientEvent('cnr:syncInventory', pIdNum, MinimizeInventoryForSync(pData.inventory))
end

ApplyPerks = function(playerId, level, role)
    local pIdNum = tonumber(playerId)
    if not pIdNum or pIdNum <= 0 then
        Log("ApplyPerks: Invalid player ID " .. tostring(playerId), "error")
        return
    end
    
    local pData = GetCnrPlayerData(pIdNum); if not pData then return end
    pData.perks = {} -- Reset perks
    pData.extraSpikeStrips = 0 -- Reset specific perk values
    pData.contrabandCollectionModifier = 1.0 -- Reset specific perk values
    pData.armorModifier = 1.0 -- Ensure armorModifier is also reset

    local unlocks = {}
    if role and Config.LevelUnlocks and Config.LevelUnlocks[role] then
        unlocks = Config.LevelUnlocks[role]
    else
        Log(string.format("ApplyPerks: No level unlocks defined for role '%s'. Player %s will have no role-specific level perks.", tostring(role), pIdNum))
        -- No need to immediately return, as pData.perks (now empty) and other perk-related values need to be synced.
    end

    for levelKey, levelUnlocksTable in pairs(unlocks) do
        if level >= levelKey then
            if type(levelUnlocksTable) == "table" then -- Ensure levelUnlocksTable is a table
                for _, perkDetail in ipairs(levelUnlocksTable) do
                    if type(perkDetail) == "table" then -- Ensure perkDetail is a table
                        -- Only try to set pData.perks if it's actually a perk and perkId is valid
                        if perkDetail.type == "passive_perk" and perkDetail.perkId then
                            pData.perks[perkDetail.perkId] = true
                            Log(string.format("Player %s unlocked perk: %s at level %d", pIdNum, perkDetail.perkId, levelKey))
                        -- else
                            -- Log for non-passive_perk types if needed for debugging, e.g.:
                            -- if perkDetail.type ~= "passive_perk" then
                            --     Log(string.format("ApplyPerks: Skipping non-passive_perk type '%s' for player %s at level %d.", tostring(perkDetail.type), pIdNum, levelKey))
                            -- end
                        end

                        -- Handle specific perk values (existing logic, ensure perkDetail.type matches and perkId is valid)
                        if perkDetail.type == "passive_perk" and perkDetail.perkId then
                            if perkDetail.perkId == "increased_armor_durability" and role == "cop" then
                                pData.armorModifier = perkDetail.value or Config.PerkEffects.IncreasedArmorDurabilityModifier or 1.25
                                Log(string.format("Player %s granted increased_armor_durability (modifier: %s).", pIdNum, pData.armorModifier))
                            elseif perkDetail.perkId == "extra_spike_strips" and role == "cop" then
                                pData.extraSpikeStrips = perkDetail.value or 1
                                Log(string.format("Player %s granted extra_spike_strips (value: %d).", pIdNum, pData.extraSpikeStrips))
                            elseif perkDetail.perkId == "faster_contraband_collection" and role == "robber" then
                                 pData.contrabandCollectionModifier = perkDetail.value or 0.8
                                 Log(string.format("Player %s granted faster_contraband_collection (modifier: %s).", pIdNum, pData.contrabandCollectionModifier))
                            end
                        end
                    else
                        Log(string.format("ApplyPerks: perkDetail at levelKey %s for role %s is not a table. Skipping.", levelKey, role), "warn")
                    end
                end
            else
                 Log(string.format("ApplyPerks: levelUnlocksTable at levelKey %s for role %s is not a table. Skipping.", levelKey, role), "warn")
            end
        end
    end
    local pDataForBasicInfo = shallowcopy(pData)
    pDataForBasicInfo.inventory = nil
    SafeTriggerClientEvent('cnr:updatePlayerData', pIdNum, pDataForBasicInfo)
    SafeTriggerClientEvent('cnr:syncInventory', pIdNum, MinimizeInventoryForSync(pData.inventory))
end


-- =================================================================================================
-- BOUNTY SYSTEM
-- =================================================================================================
function CheckAndPlaceBounty(playerId)
    local pIdNum = tonumber(playerId)
    if not Config.BountySettings.enabled then return end
    local wantedData = wantedPlayers[pIdNum]; local pData = GetCnrPlayerData(pIdNum)
    if not wantedData or not pData then return end

    if wantedData.stars >= Config.BountySettings.wantedLevelThreshold and
       not activeBounties[pIdNum] and (pData.bountyCooldownUntil or 0) < os.time() then
        local bountyAmount = Config.BountySettings.baseAmount
        local targetName = SafeGetPlayerName(pIdNum) or "Unknown Target"
        activeBounties[pIdNum] = { name = targetName, amount = bountyAmount, issueTimestamp = os.time(), lastIncreasedTimestamp = os.time(), expiresAt = os.time() + (Config.BountySettings.durationMinutes * 60) }
        Log(string.format("Bounty of $%d placed on %s (ID: %d) for reaching %d stars.", bountyAmount, targetName, pIdNum, wantedData.stars))
        TriggerClientEvent('cops_and_robbers:bountyListUpdate', -1, activeBounties)
        TriggerClientEvent('chat:addMessage', -1, { args = {"^1[BOUNTY PLACED]", string.format("A bounty of $%d has been placed on %s!", bountyAmount, targetName)} })
    end
end

CreateThread(function() -- Bounty Increase & Expiry Loop
    while true do Wait(60000)
        if not Config.BountySettings.enabled then goto continue_bounty_loop end
        local bountyUpdatedThisCycle = false; local currentTime = os.time()
        for playerIdStr, bountyData in pairs(activeBounties) do
            local playerId = tonumber(playerIdStr)
            -- local player = GetPlayerFromServerId(playerId) -- Not needed if player is offline, bounty can still tick or expire
            local pData = GetCnrPlayerData(playerId); local wantedData = wantedPlayers[playerId]
            local isPlayerOnline = GetPlayerName(playerId) ~= nil -- Check if player is online

            if isPlayerOnline and pData and wantedData and wantedData.stars >= Config.BountySettings.wantedLevelThreshold and currentTime < bountyData.expiresAt then
                if bountyData.amount < Config.BountySettings.maxBounty then
                    bountyData.amount = math.min(bountyData.amount + Config.BountySettings.increasePerMinute, Config.BountySettings.maxBounty)
                    bountyData.lastIncreasedTimestamp = currentTime
                    Log(string.format("Bounty for %s (ID: %d) increased to $%d.", bountyData.name, playerId, bountyData.amount)); bountyUpdatedThisCycle = true
                end
            elseif currentTime >= bountyData.expiresAt or (isPlayerOnline and pData and wantedData and wantedData.stars < Config.BountySettings.wantedLevelThreshold) then
                Log(string.format("Bounty of $%d expired/removed for %s (ID: %s). Player online: %s, Stars: %s", bountyData.amount, bountyData.name, playerId, tostring(isPlayerOnline), wantedData and wantedData.stars or "N/A")); activeBounties[playerId] = nil
                if pData then pData.bountyCooldownUntil = currentTime + (Config.BountySettings.cooldownMinutes * 60); if isPlayerOnline then SavePlayerData(playerId) end end
                bountyUpdatedThisCycle = true
            end
        end
        if bountyUpdatedThisCycle then TriggerClientEvent('cops_and_robbers:bountyListUpdate', -1, activeBounties) end
        ::continue_bounty_loop::
    end
end)

-- =================================================================================================
-- WANTED SYSTEM
-- =================================================================================================
UpdatePlayerWantedLevel = function(playerId, crimeKey, officerId)
    -- Only log TRACE if debug logging is enabled
    if Config.DebugLogging then
        print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel START - pID: %s, crime: %s, officer: %s', playerId, crimeKey, officerId or 'nil'))
    end
    local pIdNum = tonumber(playerId)
    if not pIdNum or pIdNum <= 0 then
        Log("UpdatePlayerWantedLevel: Invalid player ID " .. tostring(playerId), "error")
        return
    end
    
    if Config.DebugLogging then
        print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Player valid check. pIDNum: %s, Name: %s, IsRobber: %s', pIdNum, GetPlayerName(pIdNum) or "N/A", tostring(IsPlayerRobber(pIdNum))))
    end
    if GetPlayerName(pIdNum) == nil or not IsPlayerRobber(pIdNum) then return end -- Check player online using GetPlayerName

    local crimeConfig = Config.WantedSettings.crimes[crimeKey]
    if Config.DebugLogging then
        print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Crime config for %s is: %s', crimeKey, crimeConfig and json.encode(crimeConfig) or "nil"))
    end
    if not crimeConfig then Log("UpdatePlayerWantedLevel: Unknown crimeKey: " .. crimeKey, "error"); return end

    if not wantedPlayers[pIdNum] then wantedPlayers[pIdNum] = { wantedLevel = 0, stars = 0, lastCrimeTime = 0, crimesCommitted = {} } end
    local currentWanted = wantedPlayers[pIdNum]

    -- Use crimeConfig.points if defined, otherwise Config.WantedSettings.baseIncreasePoints
    local pointsToAdd = (type(crimeConfig) == "table" and crimeConfig.wantedPoints) or (type(crimeConfig) == "number" and crimeConfig) or Config.WantedSettings.baseIncreasePoints or 1
    local maxConfiguredWantedLevel = 0
    if Config.WantedSettings and Config.WantedSettings.levels and #Config.WantedSettings.levels > 0 then
        maxConfiguredWantedLevel = Config.WantedSettings.levels[#Config.WantedSettings.levels].threshold + 10 -- A bit above the highest threshold
    else
        maxConfiguredWantedLevel = 200 -- Fallback max wanted points if config is malformed
    end

    currentWanted.wantedLevel = math.min(currentWanted.wantedLevel + pointsToAdd, maxConfiguredWantedLevel)
    currentWanted.lastCrimeTime = os.time()
    if not currentWanted.crimesCommitted[crimeKey] then currentWanted.crimesCommitted[crimeKey] = 0 end
    currentWanted.crimesCommitted[crimeKey] = currentWanted.crimesCommitted[crimeKey] + 1

    local newStars = 0
    if Config.WantedSettings and Config.WantedSettings.levels then
        for i = #Config.WantedSettings.levels, 1, -1 do
            if currentWanted.wantedLevel >= Config.WantedSettings.levels[i].threshold then
                newStars = Config.WantedSettings.levels[i].stars
                break
            end
        end
    end    currentWanted.stars = newStars
    -- Reduced logging: Only log on significant changes to reduce spam
    if newStars ~= (currentWanted.previousStars or 0) then
        Log(string.format("Player %s committed crime '%s'. Points: %s. Wanted Lvl: %d, Stars: %d", pIdNum, crimeKey, pointsToAdd, currentWanted.wantedLevel, newStars))
        currentWanted.previousStars = newStars
    end    SafeTriggerClientEvent('cnr:wantedLevelSync', pIdNum, currentWanted) -- Syncs wantedLevel points and stars
    -- The [CNR_SERVER_DEBUG] print previously here is now covered by the TRACE print above.
    SafeTriggerClientEvent('cops_and_robbers:updateWantedDisplay', pIdNum, newStars, currentWanted.wantedLevel) -- Explicitly update client UI
    
    -- Send UI notification instead of chat message
    local uiLabel = ""
    for _, levelData in ipairs(Config.WantedSettings.levels or {}) do
        if levelData.stars == newStars then
            uiLabel = levelData.uiLabel
            break
        end
    end
    if uiLabel == "" then
        uiLabel = "Wanted: " .. string.rep("★", newStars) .. string.rep("☆", 5 - newStars)
    end
    
    SafeTriggerClientEvent('cnr:showWantedNotification', pIdNum, newStars, currentWanted.wantedLevel, uiLabel)

    local crimeDescription = (type(crimeConfig) == "table" and crimeConfig.description) or crimeKey:gsub("_"," "):gsub("%a", string.upper, 1)
    local robberPlayerName = GetPlayerName(pIdNum) or "Unknown Suspect"
    local robberPed = GetPlayerPed(pIdNum) -- Get ped once
    local robberCoords = robberPed and GetEntityCoords(robberPed) or nil

    if newStars > 0 and robberCoords then -- Only proceed if player has stars and valid coordinates
        -- NPC Police Response Logic (now explicitly server-triggered and configurable)
        if Config.WantedSettings.enableNPCResponse then
            if robberCoords then -- Ensure robberCoords is not nil before logging its components
                Log(string.format("UpdatePlayerWantedLevel: NPC Response ENABLED. Triggering cops_and_robbers:wantedLevelResponseUpdate for player %s (%d stars) at Coords: X:%.2f, Y:%.2f, Z:%.2f", pIdNum, newStars, robberCoords.x, robberCoords.y, robberCoords.z), "info")
            else
                Log(string.format("UpdatePlayerWantedLevel: NPC Response ENABLED for player %s (%d stars), but robberCoords are nil. Event will still be triggered.", pIdNum, newStars), "warn")
            end
            SafeTriggerClientEvent('cops_and_robbers:wantedLevelResponseUpdate', pIdNum, pIdNum, newStars, currentWanted.wantedLevel, robberCoords)
        else
            Log(string.format("UpdatePlayerWantedLevel: NPC Response DISABLED via Config.WantedSettings.enableNPCResponse for player %s (%d stars). Not triggering event.", pIdNum, newStars), "info")
        end

        -- Alert Human Cops (existing logic)
        for copId, _ in pairs(copsOnDuty) do
            if GetPlayerName(copId) ~= nil then -- Check cop is online
                SafeTriggerClientEvent('chat:addMessage', copId, { args = {"^5Police Alert", string.format("Suspect %s (%s) is %d-star wanted for %s.", robberPlayerName, pIdNum, newStars, crimeDescription)} })
                SafeTriggerClientEvent('cnr:updatePoliceBlip', copId, pIdNum, robberCoords, newStars, true)
            end
        end
    end

    if type(crimeConfig) == "table" and crimeConfig.xpForRobber and crimeConfig.xpForRobber > 0 then
        AddXP(pIdNum, crimeConfig.xpForRobber, "robber")
    end
    CheckAndPlaceBounty(pIdNum)
end

ReduceWantedLevel = function(playerId, amount)
    local pIdNum = tonumber(playerId)
    if not pIdNum or pIdNum <= 0 then
        Log("ReduceWantedLevel: Invalid player ID " .. tostring(playerId), "error")
        return
    end
    
    if wantedPlayers[pIdNum] then
        wantedPlayers[pIdNum].wantedLevel = math.max(0, wantedPlayers[pIdNum].wantedLevel - amount)
        local newStars = 0
        if Config.WantedSettings and Config.WantedSettings.levels then
            for i = #Config.WantedSettings.levels, 1, -1 do
                if wantedPlayers[pIdNum].wantedLevel >= Config.WantedSettings.levels[i].threshold then
                    newStars = Config.WantedSettings.levels[i].stars
                    break
                end
            end
        end
        wantedPlayers[pIdNum].stars = newStars
        SafeTriggerClientEvent('cnr:wantedLevelSync', pIdNum, wantedPlayers[pIdNum])        Log(string.format("Reduced wanted for %s. New Lvl: %d, Stars: %d", pIdNum, wantedPlayers[pIdNum].wantedLevel, newStars))
        if wantedPlayers[pIdNum].wantedLevel == 0 then
            SafeTriggerClientEvent('cnr:hideWantedNotification', pIdNum)
            SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^2Wanted", "You are no longer wanted."} })
            for copId, _ in pairs(copsOnDuty) do
                if GetPlayerName(copId) ~= nil then -- Check cop is online
                    SafeTriggerClientEvent('cnr:updatePoliceBlip', copId, pIdNum, nil, 0, false)
                end
            end
        end
        if newStars < Config.BountySettings.wantedLevelThreshold and activeBounties[pIdNum] then
             -- Bounty expiry due to wanted level drop is handled by the bounty loop
        end
    end
end

CreateThread(function() -- Wanted level decay
    while true do Wait(Config.WantedSettings.decayIntervalMs or 30000)
        local currentTime = os.time()
        for playerIdStr, data in pairs(wantedPlayers) do local playerId = tonumber(playerIdStr)
            if data.wantedLevel > 0 and (currentTime - data.lastCrimeTime) > (Config.WantedSettings.noCrimeCooldownMs / 1000) then
                ReduceWantedLevel(playerId, Config.WantedSettings.decayRatePoints)
            end
        end
    end
end)

-- =================================================================================================
-- JAIL SYSTEM
-- =================================================================================================
SendToJail = function(playerId, durationSeconds, arrestingOfficerId, arrestOptions)
    local pIdNum = tonumber(playerId)
    if not pIdNum or pIdNum <= 0 then
        Log("SendToJail: Invalid player ID " .. tostring(playerId), "error")
        return
    end
    
    if GetPlayerName(pIdNum) == nil then return end -- Check player online
    local jailedPlayerName = GetPlayerName(pIdNum) or "Unknown Suspect"
    arrestOptions = arrestOptions or {} -- Ensure options table exists

    -- Store original wanted data before resetting (for accurate XP calculation)
    local originalWantedData = {}
    if wantedPlayers[pIdNum] then
        originalWantedData.stars = wantedPlayers[pIdNum].stars or 0
        -- Copy other fields if needed for complex XP rules later
    else
        originalWantedData.stars = 0
    end

    jail[pIdNum] = { startTime = os.time(), duration = durationSeconds, remainingTime = durationSeconds, arrestingOfficer = arrestingOfficerId }
    wantedPlayers[pIdNum] = { wantedLevel = 0, stars = 0, lastCrimeTime = 0, crimesCommitted = {} } -- Reset wanted
    SafeTriggerClientEvent('cnr:wantedLevelSync', pIdNum, wantedPlayers[pIdNum])
    SafeTriggerClientEvent('cnr:sendToJail', pIdNum, durationSeconds, Config.PrisonLocation)
    SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^1Jail", string.format("You have been jailed for %d seconds.", durationSeconds)} })
    Log(string.format("Player %s jailed for %ds. Officer: %s. Options: %s", pIdNum, durationSeconds, arrestingOfficerId or "N/A", json.encode(arrestOptions)))

    local arrestingOfficerName = (arrestingOfficerId and GetPlayerName(arrestingOfficerId)) or "System"
    for copId, _ in pairs(copsOnDuty) do
        if GetPlayerName(copId) ~= nil then -- Check cop is online
            SafeTriggerClientEvent('chat:addMessage', copId, { args = {"^5Police Info", string.format("Suspect %s jailed by %s.", jailedPlayerName, arrestingOfficerName)} })
            SafeTriggerClientEvent('cnr:updatePoliceBlip', copId, pIdNum, nil, 0, false)
        end
    end

    if arrestingOfficerId and IsPlayerCop(arrestingOfficerId) then
        local officerIdNum = tonumber(arrestingOfficerId)
        if not officerIdNum or officerIdNum <= 0 then
            Log("SendToJail: Invalid arresting officer ID " .. tostring(arrestingOfficerId), "warn")
            return
        end
        
        local arrestXP = 0

        -- Use originalWantedData.stars for XP calculation
        if originalWantedData.stars >= 4 then arrestXP = Config.XPActionsCop.successful_arrest_high_wanted or 40
        elseif originalWantedData.stars >= 2 then arrestXP = Config.XPActionsCop.successful_arrest_medium_wanted or 25
        else arrestXP = Config.XPActionsCop.successful_arrest_low_wanted or 15 end

        AddXP(officerIdNum, arrestXP, "cop")
        SafeTriggerClientEvent('chat:addMessage', officerIdNum, { args = {"^2XP", string.format("Gained %d XP for arrest.", arrestXP)} })

        -- K9 Assist Bonus (existing logic, now using arrestOptions)
        local engagement = k9Engagements[pIdNum] -- pIdNum is the robber
        -- arrestOptions.isK9Assist would be set by K9 logic if it calls SendToJail
        if (engagement and engagement.copId == officerIdNum and (os.time() - engagement.time < (Config.K9AssistWindowSeconds or 30))) or arrestOptions.isK9Assist then
            local k9BonusXP = Config.XPActionsCop.k9_assist_arrest or 10 -- Corrected XP value
            AddXP(officerIdNum, k9BonusXP, "cop")
            SafeTriggerClientEvent('chat:addMessage', officerIdNum, { args = {"^2XP", string.format("+%d XP K9 Assist!", k9BonusXP)} })
            Log(string.format("Cop %s K9 assist XP %d for robber %s.", officerIdNum, k9BonusXP, pIdNum))
            k9Engagements[pIdNum] = nil -- Clear engagement after awarding
        end

        -- Subdue Arrest Bonus (New Logic)
        if arrestOptions.isSubdueArrest and not arrestOptions.isK9Assist then -- Avoid double bonus if K9 was also involved somehow in subdue
            local subdueBonusXP = Config.XPActionsCop.subdue_arrest_bonus or 10
            AddXP(officerIdNum, subdueBonusXP, "cop")
            SafeTriggerClientEvent('chat:addMessage', officerIdNum, { args = {"^2XP", string.format("+%d XP for Subdue Arrest!", subdueBonusXP)} })
            Log(string.format("Cop %s Subdue Arrest XP %d for robber %s.", officerIdNum, subdueBonusXP, pIdNum))
        end
        if Config.BountySettings.enabled and Config.BountySettings.claimMethod == "arrest" and activeBounties[pIdNum] then
            local bountyInfo = activeBounties[pIdNum]; local bountyAmt = bountyInfo.amount
            AddPlayerMoney(officerIdNum, bountyAmt)
            Log(string.format("Cop %s claimed $%d bounty on %s.", officerIdNum, bountyAmt, bountyInfo.name))
            local officerNameForBounty = GetPlayerName(officerIdNum) or "An officer"
            TriggerClientEvent('chat:addMessage', -1, { args = {"^1[BOUNTY CLAIMED]", string.format("%s claimed $%d bounty on %s!", officerNameForBounty, bountyAmt, bountyInfo.name)} })
            activeBounties[pIdNum] = nil; local robberPData = GetCnrPlayerData(pIdNum)
            if robberPData then robberPData.bountyCooldownUntil = os.time() + (Config.BountySettings.cooldownMinutes*60); if GetPlayerName(pIdNum) then SavePlayerData(pIdNum) end end
            TriggerClientEvent('cops_and_robbers:bountyListUpdate', -1, activeBounties)
        end
    end
end

CreateThread(function() -- Jail time update loop
    while true do Wait(1000)
        for playerId, jailData in pairs(jail) do 
            local pIdNum = tonumber(playerId)
            if pIdNum and pIdNum > 0 and GetPlayerName(pIdNum) ~= nil then -- Check player online
                jailData.remainingTime = jailData.remainingTime - 1
                if jailData.remainingTime <= 0 then
                    SafeTriggerClientEvent('cnr:releaseFromJail', pIdNum)
                    SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^2Jail", "You have been released."} }); Log("Player " .. pIdNum .. " released.")
                    jail[pIdNum] = nil
                elseif jailData.remainingTime % 60 == 0 then
                    SafeTriggerClientEvent('chat:addMessage', pIdNum, { args = {"^3Jail Info", string.format("Jail time remaining: %d sec.", jailData.remainingTime)} })
                end
            else
                Log("Player " .. tostring(playerId) .. " offline. Jail time paused.")
                -- Optionally, save player data here if jail time needs to persist accurately even if server restarts while player is offline & jailed.
                -- However, current SavePlayerData is usually tied to playerDrop.
            end
        end
    end
end)

RegisterNetEvent('cnr:playerSpawned')
AddEventHandler('cnr:playerSpawned', function()
    local src = source
    Log(string.format("Event cnr:playerSpawned received for player %s. Attempting to load data.", src), "info")
    LoadPlayerData(src)
end)

RegisterNetEvent('cnr:selectRole')
AddEventHandler('cnr:selectRole', function(selectedRole)
    local src = source
    local pIdNum = tonumber(src)
    local pData = GetCnrPlayerData(pIdNum)

    -- Check if player data is loaded
    if not pData or not pData.isDataLoaded then
        Log(string.format("cnr:selectRole: Player data not ready for %s. pData exists: %s, isDataLoaded: %s", pIdNum, tostring(pData ~= nil), tostring(pData and pData.isDataLoaded or false)), "warn")
        TriggerClientEvent('cnr:roleSelected', src, false, "Player data is not ready. Please wait a moment and try again.")
        return
    end    -- No need for the old `if not pData then` check as the above condition covers it.

    if selectedRole ~= "cop" and selectedRole ~= "robber" and selectedRole ~= "civilian" then
        TriggerClientEvent('cnr:roleSelected', src, false, "Invalid role selected.")
        return
    end
    
    -- Handle civilian role (no special spawn handling needed)
    if selectedRole == "civilian" then
        SetPlayerRole(pIdNum, nil) -- Clear role
        TriggerClientEvent('cnr:roleSelected', src, true, "You are now a civilian.")
        return
    end

    -- Set role server-side
    SetPlayerRole(pIdNum, selectedRole)
    -- Teleport to spawn and set ped model (client will handle visuals, but send spawn info)
    local spawnLocation = nil
    local spawnHeading = 0.0
    
    if selectedRole == "cop" and Config.SpawnPoints and Config.SpawnPoints.cop then
        spawnLocation = Config.SpawnPoints.cop
        spawnHeading = 270.0 -- Facing west (common for Mission Row PD)
    elseif selectedRole == "robber" and Config.SpawnPoints and Config.SpawnPoints.robber then
        spawnLocation = Config.SpawnPoints.robber
        spawnHeading = 180.0 -- Facing south
    end
    
    if spawnLocation then
        TriggerClientEvent('cnr:spawnPlayerAt', src, spawnLocation, spawnHeading, selectedRole)
        Log(string.format("Player %s spawned as %s at %s", GetPlayerName(src), selectedRole, tostring(spawnLocation)))
        print(string.format("[CNR_SERVER_DEBUG] Role selection successful: Player %s (%s) spawned as %s", 
            GetPlayerName(src), src, selectedRole))
    else
        Log(string.format("No spawn point found for role %s", selectedRole), "warn")
        print(string.format("[CNR_SERVER_WARN] No spawn point found for role %s for player %s", selectedRole, src))
        TriggerClientEvent('cnr:roleSelected', src, false, "No spawn point configured for this role.")
        return
    end
    -- Confirm to client
    TriggerClientEvent('cnr:roleSelected', src, true, "Role selected successfully.")
end)

RegisterNetEvent('cops_and_robbers:getItemList')
AddEventHandler('cops_and_robbers:getItemList', function(storeType, vendorItemIds, storeName) -- Renamed itemList to vendorItemIds for clarity
    local src = source
    local pData = GetCnrPlayerData(src)
    -- print('[CNR_SERVER_DEBUG] Received cops_and_robbers:getItemList from', src, 'storeType:', storeType, 'storeName:', storeName)

    if not storeName then
        print('[CNR_SERVER_ERROR] Store name missing in getItemList event from', src)
        return
    end

    -- The vendorItemIds from client (originating from Config.NPCVendors[storeName].items) is a list of strings.
    -- We need to transform this into a list of full item objects using Config.Items.
    if not vendorItemIds or type(vendorItemIds) ~= 'table' then
        print('[CNR_SERVER_ERROR] Item ID list missing or not a table for store', storeName, 'from', src)
        TriggerClientEvent('cops_and_robbers:sendItemList', src, storeName, {}) -- Send empty list on error
        return
    end

    local fullItemDetailsList = {}
    if Config.Items and type(Config.Items) == 'table' then
        for _, itemIdFromVendor in ipairs(vendorItemIds) do
            local foundItem = nil
            for _, configItem in ipairs(Config.Items) do
                if configItem.itemId == itemIdFromVendor then
                    -- Create a new table for the item to send, ensuring all necessary fields are present
                    foundItem = {                        itemId = configItem.itemId,
                        name = configItem.name,
                        basePrice = configItem.basePrice, -- NUI will use this as 'price'
                        price = configItem.basePrice, -- Explicitly add 'price' for NUI if it uses that
                        category = configItem.category,
                        forCop = configItem.forCop,
                        minLevelCop = configItem.minLevelCop,
                        minLevelRobber = configItem.minLevelRobber,
                        icon = configItem.icon, -- Add icon field for modern UI
                        -- Add any other fields the NUI might need, like description, weight, etc.
                        -- e.g., description = configItem.description or ""
                    }
                    -- Apply dynamic pricing if enabled
                    if Config.DynamicEconomy and Config.DynamicEconomy.enabled then
                        foundItem.price = CalculateDynamicPrice(foundItem.itemId, foundItem.basePrice)
                        -- If NUI also needs basePrice separately, keep it, otherwise price is now dynamic price
                    end
                    table.insert(fullItemDetailsList, foundItem)
                    break -- Found the item in Config.Items, move to next itemIdFromVendor
                end
            end
            if not foundItem then
                print(string.format("[CNR_SERVER_WARN] Item ID '%s' specified for vendor '%s' not found in Config.Items. Skipping.", itemIdFromVendor, storeName))
            end
        end
    else
        print("[CNR_SERVER_ERROR] Config.Items is not defined or not a table. Cannot populate item details.")
        TriggerClientEvent('cops_and_robbers:sendItemList', src, storeName, {}) -- Send empty list
        return
    end    -- Include player level, role, and cash information for UI to check restrictions and display
    local playerInfo = {
        level = pData and pData.level or 1,
        role = pData and pData.role or "citizen",
        cash = pData and (pData.cash or pData.money) or 0
    }

    -- print('[CNR_SERVER_DEBUG] Item list for', storeName, 'has', #fullItemDetailsList, 'items after processing.')
    -- Send the constructed list of full item details to the client
    TriggerClientEvent('cops_and_robbers:sendItemList', src, storeName, fullItemDetailsList, playerInfo)
    -- print('[CNR_SERVER_DEBUG] Triggered cops_and_robbers:sendItemList to', src, 'for store', storeName, 'with full details.')
end)

RegisterNetEvent('cops_and_robbers:getPlayerInventory')
AddEventHandler('cops_and_robbers:getPlayerInventory', function()
    local src = source
    local pData = GetCnrPlayerData(src)

    if not pData or not pData.inventory then
        print(string.format("[CNR_SERVER_ERROR] Player data or inventory not found for src %s in getPlayerInventory.", src))
        TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, {}) -- Send empty table if no inventory
        return
    end

    local processedInventoryForNui = {}
    -- No need to check Config.Items here on server for this specific NUI message,
    -- as NUI will do the lookup. Server just provides IDs and counts from player's actual inventory.

    for itemId, invItemData in pairs(pData.inventory) do
        -- invItemData is now { count = X, name = "Item Name", category = "Category", itemId = "itemId" }
        if invItemData and invItemData.count and invItemData.count > 0 then
            table.insert(processedInventoryForNui, {
                itemId = itemId, -- Or invItemData.itemId, they should be the same
                count = invItemData.count
            })
        end
    end    print(string.format("[CNR_SERVER_DEBUG] Selling: Sending %d unique item stacks to NUI for Sell Tab for player %s", #processedInventoryForNui, src))    TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, processedInventoryForNui)
end)

-- OLD HANDLERS REMOVED - Using enhanced versions below with inventory saving

-- =================================================================================================
-- ROBUST INVENTORY SAVING SYSTEM
-- =================================================================================================

-- Table to track players who need inventory save
local playersSavePending = {}

-- Function to mark player for inventory save
local function MarkPlayerForInventorySave(playerId)
    local pIdNum = tonumber(playerId)
    if pIdNum and pIdNum > 0 then
        playersSavePending[pIdNum] = true
    end
end

-- Function to save player data immediately (used for critical saves)
local function SavePlayerDataImmediate(playerId, reason)
    reason = reason or "manual"
    local pIdNum = tonumber(playerId)
    if not pIdNum or pIdNum <= 0 then return false end
    
    local pData = GetCnrPlayerData(pIdNum)
    if not pData then return false end
    
    local success = SavePlayerData(pIdNum)
    if success then
        playersSavePending[pIdNum] = nil -- Clear pending save flag
        Log(string.format("Immediate save completed for player %s (reason: %s)", pIdNum, reason))
        return true
    else
        Log(string.format("Failed immediate save for player %s (reason: %s)", pIdNum, reason), "error")
        return false
    end
end

-- Periodic save system - saves all pending players every 30 seconds
CreateThread(function()
    while true do
        Wait(30000) -- 30 seconds
        
        -- Save all players who have pending saves
        for playerId, needsSave in pairs(playersSavePending) do
            if needsSave and GetPlayerName(playerId) then
                SavePlayerDataImmediate(playerId, "periodic")
            end
        end
        
        -- Clean up offline players from pending saves
        for playerId, _ in pairs(playersSavePending) do
            if not GetPlayerName(playerId) then
                playersSavePending[playerId] = nil
            end
        end
    end
end)

-- Player connecting handler - for tracking new connections
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    Log(string.format("Player connecting: %s (ID: %s)", name, src))
    
    -- Clear any pending save for this player ID (in case of reconnect)
    playersSavePending[src] = nil
end)

-- Player dropped handler - immediate save on disconnect
AddEventHandler('playerDropped', function(reason)
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    
    Log(string.format("Player %s (ID: %s) disconnected. Reason: %s", playerName, src, reason))
    
    -- Immediately save player data before they disconnect
    SavePlayerDataImmediate(src, "disconnect")
    
    -- Clean up player from all tracking tables
    playersSavePending[src] = nil
    playersData[src] = nil
    copsOnDuty[src] = nil
    robbersActive[src] = nil
    wantedPlayers[src] = nil
    jail[src] = nil
    activeBounties[src] = nil
    -- ... add other tables as needed
end)

-- Enhanced buy/sell operations with immediate inventory saves
RegisterNetEvent('cops_and_robbers:buyItem')
AddEventHandler('cops_and_robbers:buyItem', function(itemId, quantity)
    local src = source
    local pData = GetCnrPlayerData(src)
    quantity = tonumber(quantity) or 1

    if not pData then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false)
        return
    end
    if quantity <= 0 then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false)
        return
    end

    local itemConfig = nil
    for _, cfgItem in ipairs(Config.Items) do
        if cfgItem.itemId == itemId then
            itemConfig = cfgItem
            break
        end
    end

    if not itemConfig then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false)
        return
    end

    -- Role/Level Checks
    if pData.role == "cop" and itemConfig.minLevelCop and pData.level < itemConfig.minLevelCop then
        Log(string.format("Player %s (Level: %d) tried to buy %s but needs cop level %d", src, pData.level, itemConfig.name, itemConfig.minLevelCop), "warn")
        TriggerClientEvent('cops_and_robbers:buyResult', src, false)
        return
    end
    if pData.role == "robber" and itemConfig.minLevelRobber and pData.level < itemConfig.minLevelRobber then
        Log(string.format("Player %s (Level: %d) tried to buy %s but needs robber level %d", src, pData.level, itemConfig.name, itemConfig.minLevelRobber), "warn")
        TriggerClientEvent('cops_and_robbers:buyResult', src, false)
        return
    end
    if itemConfig.forCop and pData.role ~= "cop" then
        Log(string.format("Player %s (Role: %s) tried to buy %s but it's cop-only", src, pData.role, itemConfig.name), "warn")
        TriggerClientEvent('cops_and_robbers:buyResult', src, false)
        return
    end    -- Calculate cost with dynamic pricing
    local totalCost = CalculateDynamicPrice(itemId, itemConfig.basePrice) * quantity

    if not RemovePlayerMoney(src, totalCost) then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false)
        return
    end

    -- Add to purchase history for dynamic pricing
    local currentTime = os.time()
    if not purchaseHistory[itemId] then purchaseHistory[itemId] = {} end
    table.insert(purchaseHistory[itemId], currentTime)

    -- Add item to inventory
    local success, msg = AddItemToPlayerInventory(src, itemId, quantity, itemConfig)
    if success then
        TriggerClientEvent('cops_and_robbers:buyResult', src, true)
        TriggerClientEvent('cops_and_robbers:refreshSellListIfNeeded', src)
        Log(string.format("Player %s bought %d x %s for $%d.", src, quantity, itemConfig.name, totalCost))
        
        -- IMMEDIATE SAVE after purchase
        SavePlayerDataImmediate(src, "purchase")
    else
        AddPlayerMoney(src, totalCost)
        TriggerClientEvent('cops_and_robbers:buyResult', src, false)
        Log(string.format("Player %s purchase of %s failed. Refunding $%d. Reason: %s", src, itemConfig.name, totalCost, msg), "error")
    end
end)

RegisterNetEvent('cops_and_robbers:sellItem')
AddEventHandler('cops_and_robbers:sellItem', function(itemId, quantity)
    local src = source
    local pData = GetCnrPlayerData(src)
    quantity = tonumber(quantity) or 1

    if not pData or not pData.inventory then
        TriggerClientEvent('cops_and_robbers:sellResult', src, false) -- No message
        return
    end

    local itemConfig = nil
    for _, cfgItem in ipairs(Config.Items) do
        if cfgItem.itemId == itemId then
            itemConfig = cfgItem
            break
        end
    end

    if not itemConfig or not itemConfig.sellPrice then
        TriggerClientEvent('cops_and_robbers:sellResult', src, false) -- No message
        return
    end

    local success, msg = RemoveItemFromPlayerInventory(src, itemId, quantity)
    if success then
        local totalEarned = itemConfig.sellPrice * quantity
        AddPlayerMoney(src, totalEarned)
        TriggerClientEvent('cops_and_robbers:sellResult', src, true) -- No message
        TriggerClientEvent('cops_and_robbers:refreshSellListIfNeeded', src)
        Log(string.format("Player %s sold %d x %s for $%d.", src, quantity, itemConfig.name, totalEarned))
        
        -- IMMEDIATE SAVE after sale
        SavePlayerDataImmediate(src, "sale")
    else
        TriggerClientEvent('cops_and_robbers:sellResult', src, false) -- No message
        Log(string.format("Player %s sell of %s failed. Reason: %s", src, itemConfig.name, msg), "error")
    end
end)

-- Enhanced respawn system with inventory restoration
RegisterNetEvent('cnr:playerRespawned')
AddEventHandler('cnr:playerRespawned', function()
    local src = source
    Log(string.format("Player %s respawned, restoring inventory", src))
    
    -- Reload and sync player inventory
    local pData = GetCnrPlayerData(src)
    if pData and pData.inventory then
        -- Send fresh inventory sync
        SafeTriggerClientEvent('cnr:syncInventory', src, MinimizeInventoryForSync(pData.inventory))
        Log(string.format("Restored inventory for respawned player %s with %d items", src, tablelength(pData.inventory or {})))
    else
        Log(string.format("No inventory to restore for player %s", src), "warn")
    end
end)

-- Enhanced player spawn handler with inventory sync
RegisterNetEvent('cnr:playerSpawned')
AddEventHandler('cnr:playerSpawned', function()
    local src = source
    Log(string.format("Event cnr:playerSpawned received for player %s. Attempting to load data.", src), "info")
    
    -- Load player data
    LoadPlayerData(src)
    
    -- Ensure inventory is properly synced after spawn
    Citizen.SetTimeout(2000, function() -- Give time for data to load
        local pData = GetCnrPlayerData(src)
        if pData and pData.inventory then
            SafeTriggerClientEvent('cnr:syncInventory', src, MinimizeInventoryForSync(pData.inventory))
            Log(string.format("Post-spawn inventory sync for player %s", src))
        end
    end)
end)

-- Enhanced AddItemToPlayerInventory with save marking
function AddItemToPlayerInventory(playerId, itemId, quantity, itemDetails)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return false, "Player data not found" end

    pData.inventory = pData.inventory or {}

    if not itemDetails or not itemDetails.name or not itemDetails.category then
        local foundConfigItem = nil
        for _, cfgItem in ipairs(Config.Items) do
            if cfgItem.itemId == itemId then
                foundConfigItem = cfgItem
                break
            end
        end
        if not foundConfigItem then
            Log(string.format("AddItemToPlayerInventory: CRITICAL - Item details not found in Config.Items for itemId '%s' and not passed correctly. Cannot add to inventory for player %s.", itemId, playerId), "error")
            return false, "Item configuration not found"
        end
        itemDetails = foundConfigItem
    end

    local currentCount = 0
    if pData.inventory[itemId] and pData.inventory[itemId].count then
        currentCount = pData.inventory[itemId].count
    end

    local newCount = currentCount + quantity

    pData.inventory[itemId] = {
        count = newCount,
        name = itemDetails.name,
        category = itemDetails.category,
        itemId = itemId
    }

    -- Mark for save
    MarkPlayerForInventorySave(playerId)

    local pDataForBasicInfo = shallowcopy(pData)
    pDataForBasicInfo.inventory = nil
    TriggerClientEvent('cnr:updatePlayerData', playerId, pDataForBasicInfo)
    TriggerClientEvent('cnr:syncInventory', playerId, MinimizeInventoryForSync(pData.inventory)) -- Send MINIMAL inventory separately
    Log(string.format("Added/updated %d of %s to player %s inventory. New count: %d. Name: %s, Category: %s", quantity, itemId, playerId, newCount, itemDetails.name, itemDetails.category))
    return true, "Item added/updated"
end

function RemoveItemFromPlayerInventory(playerId, itemId, quantity)
    local pData = GetCnrPlayerData(playerId)
    if not pData or not pData.inventory or not pData.inventory[itemId] or pData.inventory[itemId].count < quantity then
        return false, "Item not found or insufficient quantity"
    end

    pData.inventory[itemId].count = pData.inventory[itemId].count - quantity

    if pData.inventory[itemId].count <= 0 then
        pData.inventory[itemId] = nil
    end
    
    -- Mark for save
    MarkPlayerForInventorySave(playerId)
    
    local pDataForBasicInfo = shallowcopy(pData)
    pDataForBasicInfo.inventory = nil
    TriggerClientEvent('cnr:updatePlayerData', playerId, pDataForBasicInfo)
    TriggerClientEvent('cnr:syncInventory', playerId, MinimizeInventoryForSync(pData.inventory)) -- Send MINIMAL inventory separately
    Log(string.format("Removed %d of %s from player %s inventory.", quantity, itemId, playerId))
    return true, "Item removed"
end