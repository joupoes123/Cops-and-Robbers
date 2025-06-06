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
    -- Check if Config and Config.DebugLogging are available
    if Config and Config.DebugLogging then
        if level == "error" then print("[CNR_ERROR] " .. message)
        elseif level == "warn" then print("[CNR_WARN] " .. message)
        else print("[CNR_INFO] " .. message) end
    elseif level == "error" or level == "warn" then -- Always print errors/warnings if DebugLogging is off/Config unavailable
        print("[CNR_CRITICAL_LOG] [" .. string.upper(level) .. "] " .. message)
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
    local pData = playersData[pId]
    if pData then
        if type == 'cash' then
            pData.money = (pData.money or 0) + amount
            Log(string.format("Added %d to player %s's %s account. New balance: %d", amount, playerId, type, pData.money))
            -- Send a notification to the client
            TriggerClientEvent('chat:addMessage', pId, { args = {"^2Money", string.format("You received $%d.", amount)} })
            TriggerClientEvent('cnr:updatePlayerData', pId, pData) -- Ensure client UI updates if money is displayed
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
    local pData = playersData[pId]
    if pData then
        if type == 'cash' then
            if (pData.money or 0) >= amount then
                pData.money = pData.money - amount
                Log(string.format("Removed %d from player %s's %s account. New balance: %d", amount, playerId, type, pData.money))
                TriggerClientEvent('cnr:updatePlayerData', pId, pData) -- Ensure client UI updates
                return true
            else
                -- Notify the client about insufficient funds
                TriggerClientEvent('chat:addMessage', pId, { args = {"^1Error", "You don't have enough money."} })
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
-- ITEMS, SHOPS, AND INVENTORY
-- =================================================================================================
RegisterNetEvent('cnr:buyItem', function(itemId, quantity)
    local src = tonumber(source)
    local pData = GetCnrPlayerData(src)
    quantity = tonumber(quantity) or 1

    if not pData then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "Player data not found.")
        Log("cnr:buyItem - Player data not found for source: " .. src, "error")
        return
    end

    local itemConfig = nil
    for _, item in ipairs(Config.Items) do
        if item.itemId == itemId then
            itemConfig = item
            break
        end
    end

    if not itemConfig then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "Item not found in config.")
        Log("cnr:buyItem - ItemId " .. itemId .. " not found in Config.Items for source: " .. src, "warn")
        return
    end

    -- Level Restriction Check
    if pData.role == "cop" and itemConfig.minLevelCop and pData.level < itemConfig.minLevelCop then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "You are not high enough level for this item. (Required Cop Lvl: " .. itemConfig.minLevelCop .. ")")
        return
    elseif pData.role == "robber" and itemConfig.minLevelRobber and pData.level < itemConfig.minLevelRobber then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "You are not high enough level for this item. (Required Robber Lvl: " .. itemConfig.minLevelRobber .. ")")
        return
    end

    -- Cop Only Restriction Check
    if itemConfig.forCop and pData.role ~= "cop" then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "This item is restricted to Cops only.")
        return
    end

    local itemPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice)
    Log("cnr:buyItem - Item: " .. itemId .. ", Base Price: " .. itemConfig.basePrice .. ", Dynamic Price: " .. itemPrice)
    local totalCost = itemPrice * quantity

    if not RemovePlayerMoney(src, totalCost, 'cash') then
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "Not enough cash or payment failed.")
        return
    end

    -- Successfully removed money, now add item
    local added = AddItem(pData, itemId, quantity, src) -- Use custom AddItem, pass pData and src
    if added then
        TriggerClientEvent('cops_and_robbers:purchaseConfirmed', src, itemId, quantity)
        Log(string.format("Player %s purchased %dx %s for $%d", src, quantity, itemId, totalCost))
        -- Record purchase for dynamic economy
        if Config.DynamicEconomy and Config.DynamicEconomy.enabled then
            table.insert(purchaseHistory, { itemId = itemId, playerId = src, timestamp = os.time(), price = itemPrice, quantity = quantity }) -- Using dynamic price
        end
    else
        Log(string.format("Custom AddItem failed for %s, item %s, quantity %d.", src, itemId, quantity), "error")
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "Could not add item to inventory. Purchase reversed.")
        AddPlayerMoney(src, totalCost, 'cash') -- Refund
    end
end)

RegisterNetEvent('cnr:sellItem', function(itemId, quantity)
    local src = tonumber(source)
    local pData = GetCnrPlayerData(src)
    quantity = tonumber(quantity) or 1

    if not pData then
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "Player data not found.")
        return
    end

    local itemConfig = nil
    for _, item in ipairs(Config.Items) do
        if item.itemId == itemId then
            itemConfig = item
            break
        end
    end

    if not itemConfig then
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "Item not found in config.")
        return
    end

    if not itemConfig.basePrice then -- Ensure item has a price to base sell value on
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "Item cannot be sold (no price defined).")
        return
    end

    -- TODO: Use dynamic price for selling in a future step.
    local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
    local currentMarketPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice)
    local sellPricePerItem = math.floor(currentMarketPrice * sellPriceFactor)
    Log("cnr:sellItem - Item: " .. itemId .. ", Base Price: " .. itemConfig.basePrice .. ", Current Market Price: " .. currentMarketPrice .. ", Sell Price: " .. sellPricePerItem)
    local totalGain = sellPricePerItem * quantity

    local removed = RemoveItem(pData, itemId, quantity, src) -- Use custom RemoveItem, pass pData and src
    if removed then
        if AddPlayerMoney(src, totalGain, 'cash') then
            TriggerClientEvent('cops_and_robbers:sellConfirmed', src, itemId, quantity)
            Log(string.format("Player %s sold %dx %s for $%d", src, quantity, itemId, totalGain))
        else
            Log(string.format("Failed to add money to %s after selling %s. Attempting to refund item.", src, itemId), "error")
            AddItem(pData, itemId, quantity, src) -- Attempt to give item back, pass pData and src
            TriggerClientEvent('cops_and_robbers:sellFailed', src, "Could not process payment for sale. Item may have been refunded.")
        end
    else
        Log(string.format("Custom RemoveItem failed for %s, item %s, quantity %d.", src, itemId, quantity), "error")
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "Could not remove item from inventory.")
    end
end)

-- K9 System Events
RegisterNetEvent('cops_and_robbers:spawnK9', function()
    local src = tonumber(source)
    local pData = GetCnrPlayerData(src)

    if not pData then
        Log("cops_and_robbers:spawnK9 - Player data not found for source: " .. src, "error")
        return
    end

    if pData.role ~= "cop" then
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "Only Cops can use the K9 whistle."} })
        return
    end

    local k9WhistleConfig = nil
    for _, item in ipairs(Config.Items) do
        if item.itemId == "k9whistle" then -- Assuming "k9whistle" is the itemId in Config.Items
            k9WhistleConfig = item
            break
        end
    end

    if not k9WhistleConfig then
        Log("K9 Whistle item config not found in Config.Items!", "error")
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "K9 Whistle item not configured."} })
        return
    end

    if k9WhistleConfig.minLevelCop and pData.level < k9WhistleConfig.minLevelCop then
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "You are not high enough level to use the K9 Whistle. (Required Cop Lvl: " .. k9WhistleConfig.minLevelCop .. ")"} })
        return
    end

    -- Check for K9 whistle item in inventory
    if not HasItem(pData, 'k9whistle', 1, src) then -- Use custom HasItem, pass pData and src
         TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "You do not have a K9 Whistle."} })
         return
    end

    -- Potentially consume the whistle or have a cooldown managed by the item itself if it's not reusable.
    -- For now, just checking possession.

    TriggerClientEvent('cops_and_robbers:clientSpawnK9Authorized', src)
    Log("Authorized K9 spawn for Cop: " .. src)
end)

-- Basic dismiss and command relays (assuming they exist or are simple)
RegisterNetEvent('cops_and_robbers:dismissK9', function()
    local src = tonumber(source)
    if GetCnrPlayerData(src) and GetCnrPlayerData(src).role == "cop" then
        TriggerClientEvent('cops_and_robbers:clientDismissK9', src)
        Log("Cop " .. src .. " dismissed K9.")
    end
end)

RegisterNetEvent('cops_and_robbers:commandK9', function(targetRobberServerId, commandType)
    local src = tonumber(source)
    if GetCnrPlayerData(src) and GetCnrPlayerData(src).role == "cop" then
        -- Server could do more validation here if needed (e.g., target is valid robber)
        TriggerClientEvent('cops_and_robbers:k9ProcessCommand', src, tonumber(targetRobberServerId), commandType)
        Log(string.format("Cop %s commanded K9 (%s) for target %s", src, commandType, targetRobberServerId))
    end
end)

-- Vehicle Access Logic (Example: Called by a vehicle shop)
RegisterNetEvent('cnr:requestVehicleSpawn', function(vehicleModelName)
    local src = tonumber(source)
    local pData = GetCnrPlayerData(src)

    if not pData then
        Log("cnr:requestVehicleSpawn - Player data not found for source: " .. src, "error")
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "Your player data could not be found."} })
        return
    end

    local vehicleKey = vehicleModelName:lower() -- Assuming vehicleModelName is a string like "police"
    local foundUnlock = false
    local canAccess = false
    local requiredLevel = 0

    if Config.LevelUnlocks and Config.LevelUnlocks[pData.role] then
        for level, unlocks in pairs(Config.LevelUnlocks[pData.role]) do
            for _, unlockDetail in ipairs(unlocks) do
                if unlockDetail.type == "vehicle_access" and unlockDetail.vehicleHash:lower() == vehicleKey then
                    foundUnlock = true
                    requiredLevel = level
                    if pData.level >= level then
                        canAccess = true
                    end
                    goto check_done -- Found the specific vehicle unlock, no need to check further
                end
            end
        end
    end
    ::check_done::

    if not foundUnlock then
        -- If not found in level unlocks, assume it's a default vehicle accessible by anyone in the role (if applicable)
        -- or a vehicle not managed by level unlocks. For this example, we'll assume it's accessible if not explicitly restricted.
        -- A more robust system might have a base list of allowed vehicles per role.
        Log(string.format("cnr:requestVehicleSpawn - Vehicle %s not found in LevelUnlocks for role %s. Assuming default access.", vehicleModelName, pData.role))
        canAccess = true -- Defaulting to accessible if not in unlock list; adjust if default should be restricted.
    end

    if canAccess then
        TriggerClientEvent('chat:addMessage', src, { args = {"^2Access", string.format("Access GRANTED for %s.", vehicleModelName)} })
        Log(string.format("Player %s (Lvl %d) GRANTED access to vehicle %s (Required Lvl: %d for role %s).", src, pData.level, vehicleModelName, requiredLevel, pData.role))
        -- TODO: Actual vehicle spawning logic would go here, e.g.,
        -- CreateVehicle(vehicleModelName, coords, heading, true, true)
        -- Note: Spawning vehicles requires using FiveM natives and potentially a garage system.
    else
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Access", string.format("Access DENIED for %s. Required Level: %d.", vehicleModelName, requiredLevel)} })
        Log(string.format("Player %s (Lvl %d) DENIED access to vehicle %s (Required Lvl: %d for role %s).", src, pData.level, vehicleModelName, requiredLevel, pData.role))
    end
end)

-- =================================================================================================
-- PLAYER DATA MANAGEMENT (XP, LEVELS, SAVING/LOADING)
-- =================================================================================================

LoadPlayerData = function(playerId)
    local pIdNum = tonumber(playerId)
    -- local player = GetPlayerFromServerId(pIdNum) -- Example of framework-specific code removed
    -- if not player then Log("LoadPlayerData: Player " .. pIdNum .. " not found on server.", "error"); return end

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

    local fileData = LoadResourceFile(GetCurrentResourceName(), filename)
    local loadedMoney = 0 -- Default money if not in save file or new player

    if fileData then
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

    SetPlayerRole(pIdNum, playersData[pIdNum].role, true)
    ApplyPerks(pIdNum, playersData[pIdNum].level, playersData[pIdNum].role)
    if playersData[pIdNum] then -- Ensure pData exists before passing
        InitializePlayerInventory(playersData[pIdNum], pIdNum) -- Initialize inventory after player data is loaded/created
    else
        Log("LoadPlayerData: CRITICAL - playersData[pIdNum] is nil before InitializePlayerInventory for " .. pIdNum, "error")
    end
    TriggerClientEvent('cnr:updatePlayerData', pIdNum, playersData[pIdNum])
    TriggerClientEvent('cnr:wantedLevelSync', pIdNum, wantedPlayers[pIdNum] or { wantedLevel = 0, stars = 0 })
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
    -- local player = GetPlayerFromServerId(pIdNum) -- Example placeholder for framework code
    -- if not player then Log("SetPlayerRole: Player " .. pIdNum .. " not found.", "error"); return end
    local playerName = GetPlayerName(pIdNum) or "Unknown"
    Log(string.format("SetPlayerRole DEBUG: Attempting to set role for pIdNum: %s, playerName: %s, to newRole: %s. Current role in playersData: %s", pIdNum, playerName, role, (playersData[pIdNum] and playersData[pIdNum].role or "nil_or_no_pData")), "info")

    if not playersData[pIdNum] then
        Log(string.format("SetPlayerRole: CRITICAL - Player data for %s (Name: %s) not found when trying to set role to '%s'. Role selection aborted. Data should have been loaded on spawn.", pIdNum, playerName, role), "error")
        TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^1Error", "Your player data is not loaded correctly. Cannot set role."} })
        return -- Abort role change
    end

    Log(string.format("SetPlayerRole DEBUG: Before role update. pIdNum: %s, current playersData[pIdNum].role: %s, new role to set: %s", pIdNum, (playersData[pIdNum] and playersData[pIdNum].role or "nil_or_no_pData"), role), "info")
    playersData[pIdNum].role = role
    Log(string.format("SetPlayerRole DEBUG: After role update. pIdNum: %s, playersData[pIdNum].role is now: %s", pIdNum, playersData[pIdNum].role), "info")
    -- player.Functions.SetMetaData("role", role) -- Example placeholder

    if role == "cop" then
        copsOnDuty[pIdNum] = true; robbersActive[pIdNum] = nil
        -- player.Functions.SetJob("leo", 0) -- Placeholder for framework integration
        TriggerClientEvent('cnr:setPlayerRole', pIdNum, "cop")
        if not skipNotify then TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^3Role", "You are now a Cop."} }) end
        Log("Player " .. pIdNum .. " (" .. playerName .. ") set to Cop role.")
        TriggerClientEvent('cops_and_robbers:bountyListUpdate', pIdNum, activeBounties)
    elseif role == "robber" then
        robbersActive[pIdNum] = true; copsOnDuty[pIdNum] = nil
        -- player.Functions.SetJob("unemployed", 0) -- Placeholder for framework integration
        TriggerClientEvent('cnr:setPlayerRole', pIdNum, "robber")
        if not skipNotify then TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^3Role", "You are now a Robber."} }) end
        Log("Player " .. pIdNum .. " (" .. playerName .. ") set to Robber role.")
    else
        copsOnDuty[pIdNum] = nil; robbersActive[pIdNum] = nil
        -- player.Functions.SetJob("unemployed", 0) -- Placeholder for framework integration
        TriggerClientEvent('cnr:setPlayerRole', pIdNum, "citizen")
        if not skipNotify then TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^3Role", "You are now a Citizen."} }) end
        Log("Player " .. pIdNum .. " (" .. playerName .. ") set to Citizen role.")
    end
    ApplyPerks(pIdNum, playersData[pIdNum].level, role) -- Re-apply/update perks based on new role
    Log(string.format("SetPlayerRole DEBUG: Before TriggerClientEvent cnr:updatePlayerData. pIdNum: %s, Data being sent: %s", pIdNum, json.encode(playersData[pIdNum])), "info")
    TriggerClientEvent('cnr:updatePlayerData', pIdNum, playersData[pIdNum])
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
    local pData = GetCnrPlayerData(pIdNum)
    if not pData then Log("AddXP: Player " .. (pIdNum or "unknown") .. " data not init.", "error"); return end
    if type and pData.role ~= type and type ~= "general" then return end

    pData.xp = pData.xp + amount
    local oldLevel = pData.level
    local newLevel = CalculateLevel(pData.xp, pData.role)

    if newLevel > oldLevel then
        pData.level = newLevel
        TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^2Level Up!", string.format("Congratulations! You've reached Level %d!", newLevel)} })
        TriggerClientEvent('cnr:levelUp', pIdNum, newLevel, pData.xp)
        Log(string.format("Player %s leveled up to %d (XP: %d, Role: %s)", pIdNum, newLevel, pData.xp, pData.role))
        ApplyPerks(pIdNum, newLevel, pData.role)
    else
        TriggerClientEvent('cnr:xpGained', pIdNum, amount, pData.xp)
        Log(string.format("Player %s gained %d XP (Total: %d, Role: %s)", pIdNum, amount, pData.xp, pData.role))
    end
    TriggerClientEvent('cnr:updatePlayerData', pIdNum, pData)
end

ApplyPerks = function(playerId, level, role)
    local pIdNum = tonumber(playerId)
    local pData = GetCnrPlayerData(pIdNum); if not pData then return end
    pData.perks = {} -- Reset perks
    pData.extraSpikeStrips = 0 -- Reset specific perk values
    pData.contrabandCollectionModifier = 1.0 -- Reset specific perk values

    local unlocks = (role == "cop" and Config.LevelUnlocks.cop) or (role == "robber" and Config.LevelUnlocks.robber) or {}

    for levelKey, levelUnlocksTable in pairs(unlocks) do
        if level >= levelKey then
            for _, perkDetail in ipairs(levelUnlocksTable) do
                pData.perks[perkDetail.perkId] = true -- Generic perk flag
                Log(string.format("Player %s unlocked perk: %s at level %d", pIdNum, perkDetail.perkId, levelKey))
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
        end
    end
    TriggerClientEvent('cnr:updatePlayerData', pIdNum, pData)
end


-- =================================================================================================
-- BOUNTY SYSTEM
-- =================================================================================================
CheckAndPlaceBounty = function(playerId)
    local pIdNum = tonumber(playerId)
    if not Config.BountySettings.enabled then return end
    local wantedData = wantedPlayers[pIdNum]; local pData = GetCnrPlayerData(pIdNum)
    if not wantedData or not pData then return end

    if wantedData.stars >= Config.BountySettings.wantedLevelThreshold and
       not activeBounties[pIdNum] and (pData.bountyCooldownUntil or 0) < os.time() then
        local bountyAmount = Config.BountySettings.baseAmount
        local targetName = GetPlayerName(pIdNum) or "Unknown Target" -- Use FiveM native GetPlayerName

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
    local pIdNum = tonumber(playerId)
    if GetPlayerName(pIdNum) == nil or not IsPlayerRobber(pIdNum) then return end -- Check player online using GetPlayerName

    local crimeConfig = Config.WantedSettings.crimes[crimeKey]
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
    end
    currentWanted.stars = newStars

    Log(string.format("Player %s committed crime '%s'. Points: %s. Wanted Lvl: %d, Stars: %d", pIdNum, crimeKey, pointsToAdd, currentWanted.wantedLevel, newStars))
    TriggerClientEvent('cnr:wantedLevelSync', pIdNum, currentWanted) -- Syncs wantedLevel points and stars
    TriggerClientEvent('cops_and_robbers:updateWantedDisplay', pIdNum, newStars, currentWanted.wantedLevel) -- Explicitly update client UI
    TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^1Wanted", string.format("Wanted level increased! (%d Stars)", newStars)} })

    local crimeDescription = (type(crimeConfig) == "table" and crimeConfig.description) or crimeKey:gsub("_"," "):gsub("%a", string.upper, 1)
    local robberPlayerName = GetPlayerName(pIdNum) or "Unknown Suspect"
    local robberPed = GetPlayerPed(pIdNum) -- Get ped once
    local robberCoords = robberPed and GetEntityCoords(robberPed) or nil

    if newStars > 0 and robberCoords then -- Only proceed if player has stars and valid coordinates
        -- NPC Police Response Logic (now explicitly server-triggered and configurable)
        if Config.WantedSettings.enableNPCResponse then
            -- TriggerClientEvent('cops_and_robbers:wantedLevelResponseUpdate', pIdNum, pIdNum, newStars, currentWanted.wantedLevel, robberCoords)
            -- Log(string.format("UpdatePlayerWantedLevel: NPC Response ENABLED. Triggered cops_and_robbers:wantedLevelResponseUpdate for player %s (%d stars)", pIdNum, newStars), "info")
            Log(string.format("UpdatePlayerWantedLevel: NPC Response Trigger Suppressed (Aggressive Disable). Would have triggered for player %s (%d stars)", pIdNum, newStars), "warn")
        else
            Log(string.format("UpdatePlayerWantedLevel: NPC Response DISABLED via Config.WantedSettings.enableNPCResponse for player %s (%d stars).", pIdNum, newStars), "info")
            -- Optionally, if there's any fallback or alternative notification needed when NPC response is off, it could go here.
            -- For now, we just prevent the client event that spawns NPCs.
        end

        -- Alert Human Cops (existing logic)
        for copId, _ in pairs(copsOnDuty) do
            if GetPlayerName(copId) ~= nil then -- Check cop is online
                TriggerClientEvent('chat:addMessage', copId, { args = {"^5Police Alert", string.format("Suspect %s (%s) is %d-star wanted for %s.", robberPlayerName, pIdNum, newStars, crimeDescription)} })
                TriggerClientEvent('cnr:updatePoliceBlip', copId, pIdNum, robberCoords, newStars, true)
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
        TriggerClientEvent('cnr:wantedLevelSync', pIdNum, wantedPlayers[pIdNum])
        Log(string.format("Reduced wanted for %s. New Lvl: %d, Stars: %d", pIdNum, wantedPlayers[pIdNum].wantedLevel, newStars))
        if wantedPlayers[pIdNum].wantedLevel == 0 then
            TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^2Wanted", "You are no longer wanted."} })
            for copId, _ in pairs(copsOnDuty) do
                if GetPlayerName(copId) ~= nil then -- Check cop is online
                    TriggerClientEvent('cnr:updatePoliceBlip', copId, pIdNum, nil, 0, false)
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
    TriggerClientEvent('cnr:wantedLevelSync', pIdNum, wantedPlayers[pIdNum])
    TriggerClientEvent('cnr:sendToJail', pIdNum, durationSeconds, Config.PrisonLocation)
    TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^1Jail", string.format("You have been jailed for %d seconds.", durationSeconds)} })
    Log(string.format("Player %s jailed for %ds. Officer: %s. Options: %s", pIdNum, durationSeconds, arrestingOfficerId or "N/A", json.encode(arrestOptions)))

    local arrestingOfficerName = (arrestingOfficerId and GetPlayerName(arrestingOfficerId)) or "System"
    for copId, _ in pairs(copsOnDuty) do
        if GetPlayerName(copId) ~= nil then -- Check cop is online
            TriggerClientEvent('chat:addMessage', copId, { args = {"^5Police Info", string.format("Suspect %s jailed by %s.", jailedPlayerName, arrestingOfficerName)} })
            TriggerClientEvent('cnr:updatePoliceBlip', copId, pIdNum, nil, 0, false)
        end
    end

    if arrestingOfficerId and IsPlayerCop(arrestingOfficerId) then
        local officerIdNum = tonumber(arrestingOfficerId)
        local arrestXP = 0

        -- Use originalWantedData.stars for XP calculation
        if originalWantedData.stars >= 4 then arrestXP = Config.XPActionsCop.successful_arrest_high_wanted or 40
        elseif originalWantedData.stars >= 2 then arrestXP = Config.XPActionsCop.successful_arrest_medium_wanted or 25
        else arrestXP = Config.XPActionsCop.successful_arrest_low_wanted or 15 end

        AddXP(officerIdNum, arrestXP, "cop")
        TriggerClientEvent('chat:addMessage', officerIdNum, { args = {"^2XP", string.format("Gained %d XP for arrest.", arrestXP)} })

        -- K9 Assist Bonus (existing logic, now using arrestOptions)
        local engagement = k9Engagements[pIdNum] -- pIdNum is the robber
        -- arrestOptions.isK9Assist would be set by K9 logic if it calls SendToJail
        if (engagement and engagement.copId == officerIdNum and (os.time() - engagement.time < (Config.K9AssistWindowSeconds or 30))) or arrestOptions.isK9Assist then
            local k9BonusXP = Config.XPActionsCop.k9_assist_arrest or 10 -- Corrected XP value
            AddXP(officerIdNum, k9BonusXP, "cop")
            TriggerClientEvent('chat:addMessage', officerIdNum, { args = {"^2XP", string.format("+%d XP K9 Assist!", k9BonusXP)} })
            Log(string.format("Cop %s K9 assist XP %d for robber %s.", officerIdNum, k9BonusXP, pIdNum))
            k9Engagements[pIdNum] = nil -- Clear engagement after awarding
        end

        -- Subdue Arrest Bonus (New Logic)
        if arrestOptions.isSubdueArrest and not arrestOptions.isK9Assist then -- Avoid double bonus if K9 was also involved somehow in subdue
            local subdueBonusXP = Config.XPActionsCop.subdue_arrest_bonus or 10
            AddXP(officerIdNum, subdueBonusXP, "cop")
            TriggerClientEvent('chat:addMessage', officerIdNum, { args = {"^2XP", string.format("+%d XP for Subdue Arrest!", subdueBonusXP)} })
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
        for playerId, jailData in pairs(jail) do local pIdNum = tonumber(playerId)
            if GetPlayerName(pIdNum) ~= nil then -- Check player online
                jailData.remainingTime = jailData.remainingTime - 1
                if jailData.remainingTime <= 0 then
                    TriggerClientEvent('cnr:releaseFromJail', pIdNum)
                    TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^2Jail", "You have been released."} }); Log("Player " .. pIdNum .. " released.")
                    jail[pIdNum] = nil
                elseif jailData.remainingTime % 60 == 0 then
                    TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^3Jail Info", string.format("Jail time remaining: %d sec.", jailData.remainingTime)} })
                end
            else
                Log("Player " .. pIdNum .. " offline. Jail time paused.")
                -- Optionally, save player data here if jail time needs to persist accurately even if server restarts while player is offline & jailed.
                -- However, current SavePlayerData is usually tied to playerDrop.
            end
        end
    end
end)

-- =================================================================================================
-- ITEMS, SHOPS, AND INVENTORY (Functions like CanPlayerAffordAndAccessItem, cnr:buyItem, etc.)
-- =================================================================================================
RegisterNetEvent('cops_and_robbers:getItemList', function(storeType, vendorItemIds, storeName)
    local src = source
    local pData = GetCnrPlayerData(src)
    if not pData then
        Log("cops_and_robbers:getItemList - Player data not found for source: " .. src, "error")
        return
    end

    local itemsForStore = {}
    local itemsToProcess = {}

    if storeType == 'AmmuNation' then
        -- For AmmuNation, consider all general items from Config.Items
        for _, itemConfig in ipairs(Config.Items) do
            table.insert(itemsToProcess, itemConfig)
        end
    elseif storeType == 'Vendor' and vendorItemIds and type(vendorItemIds) == "table" then
        -- For specific vendors, use the item IDs provided by that vendor's config
        for _, itemIdFromVendor in ipairs(vendorItemIds) do
            for _, itemConfig in ipairs(Config.Items) do
                if itemConfig.itemId == itemIdFromVendor then
                    table.insert(itemsToProcess, itemConfig)
                    break -- Found the item in Config.Items
                end
            end
        end
    else
        Log("cops_and_robbers:getItemList - Invalid storeType or missing vendorItemIds for store: " .. storeName, "warn")
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "Store data missing or invalid.") -- Generic failure message
        return
    end

    -- Filter items based on player role, level, and other restrictions
    for _, itemConfig in ipairs(itemsToProcess) do
        local canAccess = true
        -- Cop Only Restriction Check
        if itemConfig.forCop and pData.role ~= "cop" then
            canAccess = false
        end

        -- Robber Only Restriction Check (if a future flag 'forRobber' is added)
        -- if itemConfig.forRobber and pData.role ~= "robber" then
        -- canAccess = false
        -- end

        -- Level Restriction Check
        if canAccess and pData.role == "cop" and itemConfig.minLevelCop and pData.level < itemConfig.minLevelCop then
            canAccess = false
        end
        if canAccess and pData.role == "robber" and itemConfig.minLevelRobber and pData.level < itemConfig.minLevelRobber then
            canAccess = false
        end

        -- Add other general level restrictions if any (e.g., itemConfig.minLevel and pData.level < itemConfig.minLevel)

        if canAccess then
            -- Calculate dynamic price
            local dynamicPrice = CalculateDynamicPrice(itemConfig.itemId, itemConfig.basePrice)
            table.insert(itemsForStore, {
                itemId = itemConfig.itemId,
                name = itemConfig.name,
                basePrice = itemConfig.basePrice, -- Keep base for reference if needed
                price = dynamicPrice, -- Actual selling price
                category = itemConfig.category,
                forCop = itemConfig.forCop,
                minLevelCop = itemConfig.minLevelCop,
                minLevelRobber = itemConfig.minLevelRobber
                -- Add any other properties the NUI might need
            })
        end
    end

    Log(string.format("Player %s (Role: %s, Level: %d) requesting item list for store: %s (%s). Sending %d items.", src, pData.role, pData.level, storeName, storeType, #itemsForStore))
    TriggerClientEvent('cops_and_robbers:sendItemList', src, storeName, itemsForStore)
end)
-- ... (Code from previous version, ensuring playerIds used as keys are numeric) ...

-- =================================================================================================
-- ROBBERY AND HEISTS (Functions like cnr:startStoreRobbery, etc.)
-- =================================================================================================
-- Add Armored Car Heist Completion XP
RegisterNetEvent('cnr:armoredCarHeistCompleted', function()
    local src = tonumber(source)
    if IsPlayerRobber(src) then
        -- XP Award
        local xpGained = Config.XPActionsRobber.successful_armored_car_heist or 50
        AddXP(src, xpGained, "robber")
        Log(string.format("Armored car heist XP (%d) awarded to robber %s", xpGained, src))

        -- Cash Reward
        local cashReward = 0
        if Config.ArmoredCar and Config.ArmoredCar.rewardMin and Config.ArmoredCar.rewardMax then
            cashReward = math.random(Config.ArmoredCar.rewardMin, Config.ArmoredCar.rewardMax)
            if cashReward > 0 then
                AddPlayerMoney(src, cashReward) -- Assumes 'cash' type by default
                Log(string.format("Armored car heist cash reward ($%d) awarded to robber %s", cashReward, src))
            end
        else
            Log("Armored Car Heist: Config.ArmoredCar.rewardMin/Max not defined. No cash reward given.", "warn")
        end

        -- Client Notification
        TriggerClientEvent('chat:addMessage', src, {
            args = {"^2Heist Success", string.format("You successfully completed the armored car heist! Gained %d XP and $%d.", xpGained, cashReward)}
        })

        -- Cooldown Management for the event itself would be handled by the event spawning logic, not here.
        -- This event is for player rewards upon their successful completion/participation.
    end
end)

-- Add Contraband Collection XP & Perk Logic
local activeContrabandDrops = {} -- Define this table to store active drop data including value and name

RegisterNetEvent('cnr:startCollectingContraband', function(dropId) -- Assuming client sends this
    local src = tonumber(source)
    local pData = GetCnrPlayerData(src)
    local collectionTime = Config.ContrabandCollectionTimeMs or 5000

    if pData and pData.perks and pData.perks.faster_contraband_collection then
        local perkModifier = pData.contrabandCollectionModifier or 1.0 -- Should be set in ApplyPerks
        collectionTime = math.floor(collectionTime * perkModifier)
        Log(string.format("Player %s applying faster_contraband_collection perk, new time: %dms", src, collectionTime))
    end
    -- TODO: Add logic to check if dropId is valid and available for collection
    TriggerClientEvent('cops_and_robbers:collectingContrabandStarted', src, dropId, collectionTime)
end)

RegisterNetEvent('cnr:finishCollectingContraband', function(dropId)
    local src = tonumber(source)
    local playerName = GetPlayerName(src)

    if not IsPlayerRobber(src) or not playerName then return end

    -- Validate the dropId and get its data
    local dropData = activeContrabandDrops[dropId] -- Assuming this table exists and is populated
    if not dropData then
        Log(string.format("Player %s (%s) tried to finish collecting non-existent or already collected dropId: %s", playerName, src, dropId), "warn")
        -- Optionally notify player of error
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "Contraband drop not found or already collected."} })
        return
    end

    local itemName = dropData.name or "Unknown Item"
    local itemValue = dropData.value or 0 -- Value from Config.ContrabandItems stored at spawn time
    local xpGained = Config.XPActionsRobber.contraband_collected or 15

    -- Award XP
    AddXP(src, xpGained, "robber")
    Log(string.format("Contraband collected: %s. XP (%d) awarded to robber %s (%s) for drop %s", itemName, xpGained, playerName, src, dropId))

    -- Award Cash
    if itemValue > 0 then
        AddPlayerMoney(src, itemValue)
        Log(string.format("Contraband cash reward ($%d) for %s awarded to robber %s (%s)", itemValue, itemName, playerName, src))
    else
        Log(string.format("Contraband %s had no value or value not configured. No cash reward for %s (%s).", itemName, playerName, src), "warn")
    end

    -- Notify player of success
    TriggerClientEvent('chat:addMessage', src, {
        args = {"^2Contraband", string.format("You collected %s! Gained %d XP and $%d.", itemName, xpGained, itemValue)}
    })

    -- Notify all clients that the drop has been collected (to remove blip/prop)
    TriggerClientEvent('cops_and_robbers:contrabandDropCollected', -1, dropId, playerName, itemName)

    -- Remove the drop from active list
    activeContrabandDrops[dropId] = nil
    Log(string.format("Contraband drop %s (item: %s) removed from active list.", dropId, itemName))
end)


-- =================================================================================================
-- ADMIN COMMANDS & FUNCTIONALITY (Commands like setrole, addxp, etc.)
-- =================================================================================================
-- ... (Code from previous version, ensuring playerIds used as keys are numeric) ...

-- =================================================================================================
-- SPIKE STRIP PERK LOGIC
-- =================================================================================================
local function getNextSpikeStripId()
    nextSpikeStripId = nextSpikeStripId + 1
    return "cnr_spike_" .. nextSpikeStripId
end

RegisterNetEvent('cnr:deploySpikeStrip', function(location)
    local src = tonumber(source)
    if not IsPlayerCop(src) then return end

    local spikeStripItemId = "spikestrip_item"

    -- 1. Check if player has the item
    local pData = GetCnrPlayerData(src) -- Get pData for HasItem and RemoveItem
    if not pData then
        Log("cnr:deploySpikeStrip - Player data not found for source: " .. src, "error")
        return
    end

    if not HasItem(pData, spikeStripItemId, 1, src) then
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "You don't have any spike strips."} })
        return
    end

    -- 2. Check deployment limit
    -- local pData = GetCnrPlayerData(src) -- Already fetched
    local currentDeployedCount = playerDeployedSpikeStripsCount[src] or 0
    local maxStrips = Config.MaxDeployedSpikeStrips

    if pData and pData.perks and pData.perks.extra_spike_strips then
        maxStrips = maxStrips + (pData.extraSpikeStrips or 0)
    end

    if currentDeployedCount >= maxStrips then
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "You've reached your maximum deployed spike strips."} })
        return
    end

    -- 3. Consume item and then deploy
    if RemoveItem(pData, spikeStripItemId, 1, src) then
        local stripId = getNextSpikeStripId()
        activeSpikeStrips[stripId] = { copId = src, location = location, timestamp = os.time() }
        playerDeployedSpikeStripsCount[src] = currentDeployedCount + 1

        TriggerClientEvent('cops_and_robbers:renderSpikeStrip', -1, stripId, location)
        Log(string.format("Cop %s deployed spike strip %s. Total deployed: %d/%d. Item consumed.", src, stripId, playerDeployedSpikeStripsCount[src], maxStrips))

        SetTimeout(Config.SpikeStripDuration, function()
            if activeSpikeStrips[stripId] then
                TriggerClientEvent('cops_and_robbers:removeSpikeStrip', -1, stripId)
                activeSpikeStrips[stripId] = nil
                if playerDeployedSpikeStripsCount[src] then -- Check if player's count exists
                     playerDeployedSpikeStripsCount[src] = math.max(0, (playerDeployedSpikeStripsCount[src] or 0) - 1) -- Ensure it doesn't go below 0
                     Log(string.format("Decremented spike strip count for %s after auto-removal. New count: %d", src, playerDeployedSpikeStripsCount[src]))
                end
                Log(string.format("Auto-removed spike strip %s for cop %s.", stripId, src))
            end
        end)
    else
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "Failed to use spike strip from inventory."} })
        Log(string.format("Cop %s had spike strip but RemoveItem failed for %s.", src, spikeStripItemId), "error")
    end
end)

RegisterNetEvent('cnr:vehicleHitSpikeStrip', function(stripId, vehicleNetId)
    local src = tonumber(source) -- This is the player whose vehicle hit the strip
    Log(string.format("Vehicle (owner: %s, netId: %s) hit spike strip %s", src, vehicleNetId, stripId))
    -- Effect is client-side, server might log or apply other consequences if needed.
    -- Spike strip assist XP would require more complex logic here or in arrest event.
end)


-- =================================================================================================
-- EVENT HANDLERS (SERVER-SIDE)
-- =================================================================================================
-- Use FiveM's playerJoining or a custom event triggered after spawn
AddEventHandler('playerJoining', function()
    local src = tonumber(source)
    -- Deferrals can be used here if needed, but LoadPlayerData is called with SetTimeout
    -- Log("Player " .. src .. " (" .. GetPlayerName(src) .. ") is joining. Attempting to load CnR data once spawned.")
    -- It's often better to load data once the player is fully spawned and has a ped.
    -- A common pattern is to have a client-side event notify the server once the player is ready.
    -- For now, we'll assume playerJoining is sufficient to start the load process,
    -- but LoadPlayerData itself fetches ped coordinates so it must happen after spawn.
    -- Let's create a new event 'cnr:playerSpawned' that client triggers.
end)

RegisterNetEvent('cnr:playerSpawned', function()
    local src = tonumber(source)
    local playerName = GetPlayerName(src) -- Get name once for efficiency
    local identifiers = GetPlayerIdentifiers(tostring(src))

    -- CRITICAL VALIDATION: Ensure player has name and identifiers after spawning
    if not playerName or playerName == "" or not identifiers or #identifiers == 0 then
        local kickReason = "Critical error: Unable to retrieve your player identifiers after spawning. Please reconnect. (Error: PS_ID_FAIL)"
        Log(string.format("CRITICAL: Player (ID: %s, Name: '%s') spawned but has missing name or no identifiers. Kicking. Identifiers found: %s",
            tostring(src), playerName or "N/A", identifiers and json.encode(identifiers) or "None"), "error")
        DropPlayer(src, kickReason)
        return -- Stop further processing for this player
    end

    Log(string.format("Player %s (ID: %s) has spawned. Name: '%s'. Identifiers validated. Proceeding with CnR data initialization.", src, playerName, json.encode(identifiers)))
    -- Small delay to ensure all initial FiveM processes for player are settled.
    SetTimeout(100, function()
        -- Re-check player validity before loading data, as they might have disconnected during the timeout
        if GetPlayerName(src) == nil then
            Log(string.format("Player %s (Original Name: %s) disconnected before LoadPlayerData could execute within cnr:playerSpawned timeout. Aborting data load.", src, playerName), "warn")
            return
        end
        LoadPlayerData(src)
        -- Sync necessary client data after load
        local pData = GetCnrPlayerData(src)
        if pData then
            TriggerClientEvent('cnr:updatePlayerData', src, pData)
            TriggerClientEvent('cnr:wantedLevelSync', src, wantedPlayers[src] or { wantedLevel = 0, stars = 0 })
            if pData.role == "cop" then
                TriggerClientEvent('cops_and_robbers:bountyListUpdate', src, activeBounties)
            end
        end
    end)
end)


AddEventHandler('playerDropped', function(reason)
    local src = tonumber(source)
    local playerName = GetPlayerName(src) or "Unknown" -- Get name before they fully drop
    Log("Player " .. src .. " (" .. playerName .. ") dropped. Reason: " .. reason .. ". Saving CnR data.")
    SavePlayerData(src)
    SavePurchaseHistory() -- Save purchase history on player drop
    if copsOnDuty[src] then copsOnDuty[src] = nil end
    if robbersActive[src] then robbersActive[src] = nil end
    if jail[src] then Log("Player " .. src .. " was in jail. Jail time will be paused/persisted.", "info") end
    -- activeHeists not defined in provided snippet; assumes any notifications are handled elsewhere
    -- Example if activeHeists were present:
    -- for storeId, heistData in pairs(activeHeists or {}) do
    --     if heistData.robberId == src then
    --         Log("Robbery at " .. storeId .. " cancelled: robber " .. src .. " disconnected.", "info")
    --         activeHeists[storeId].status = "cancelled_disconnect"
    --         for copId, _ in pairs(copsOnDuty) do
    --             if GetPlayerName(copId) then -- Check cop online
    --                 TriggerClientEvent('chat:addMessage', copId, { args = {"^5Police Alert", string.format("Robbery at %s ended, suspect disconnected.", (Config.RobbableStores and Config.RobbableStores[storeId] and Config.RobbableStores[storeId].name) or storeId)} })
    --             end
    --         end
    --     end
    -- end
    if k9Engagements[src] then Log(string.format("Cleared K9 engagement for dropped target: %d", src)); k9Engagements[src] = nil end
    for targetId, engagement in pairs(k9Engagements) do if engagement.copId == src then Log(string.format("Cleared K9 engagement by dropped cop %d for target: %d", src, targetId)); k9Engagements[targetId] = nil end end

    playerDeployedSpikeStripsCount[src] = nil -- Clear spike strip count for dropped player
    -- Remove spike strips deployed by this player
    local stripsToRemove = {}
    for stripId, data in pairs(activeSpikeStrips) do
        if data.copId == src then table.insert(stripsToRemove, stripId) end
    end
    for _, stripId in ipairs(stripsToRemove) do
        TriggerClientEvent('cops_and_robbers:removeSpikeStrip', -1, stripId)
        activeSpikeStrips[stripId] = nil
        Log(string.format("Removed spike strip %s due to deploying cop %s disconnecting.", stripId, src))
    end

    playersData[src] = nil; activeCooldowns[src] = nil
    clientReportCooldowns[src] = nil -- Clear report cooldowns for the disconnected player
    if activeSubdues[src] then -- If the dropped player was being subdued
        local subdueData = activeSubdues[src]
        if subdueData.expiryTimer then ClearTimeout(subdueData.expiryTimer) end
        Log(string.format("Subdue attempt on player %s cancelled due to disconnect.", src))
    end
    for robberId, subdueData in pairs(activeSubdues) do -- If the dropped player was the one subduing
        if subdueData.copId == src then
            if subdueData.expiryTimer then ClearTimeout(subdueData.expiryTimer) end
            TriggerClientEvent('cops_and_robbers:subdueCancelled', tonumber(robberId))
            Log(string.format("Subdue attempt by cop %s on %s cancelled due to cop disconnect.", src, robberId))
            activeSubdues[robberId] = nil
        end
    end
    Log("Cleaned up session data for player " .. src)
end)

RegisterNetEvent('cops_and_robbers:startSubdue', function(targetRobberServerId)
    local src = tonumber(source) -- This is the Cop
    local targetRobberNumId = tonumber(targetRobberServerId)

    if not IsPlayerCop(src) then
        Log(string.format("Non-cop %s attempted to subdue.", src), "warn")
        return
    end

    if not IsPlayerRobber(targetRobberNumId) or GetPlayerName(targetRobberNumId) == nil then
        Log(string.format("Cop %s attempted to subdue invalid or offline target %s.", src, targetRobberNumId), "warn")
        TriggerClientEvent('chat:addMessage', src, { args = {"^3System", "Invalid or offline target."} })
        return
    end

    if activeSubdues[targetRobberNumId] then
        Log(string.format("Robber %s is already being subdued or in a subdue process.", targetRobberNumId), "info")
        TriggerClientEvent('chat:addMessage', src, { args = {"^3System", "Target is already being subdued."} })
        return
    end

    -- TODO: Add distance check here between src (cop) and targetRobberNumId
    -- For now, we assume client did a basic distance check. A server check is crucial.
    -- local copCoords = GetEntityCoords(GetPlayerPed(src))
    -- local robberCoords = GetEntityCoords(GetPlayerPed(targetRobberNumId))
    -- if #(copCoords - robberCoords) > (Config.TackleDistance + 2.0) then -- Allow a small buffer over client check
    --     TriggerClientEvent('chat:addMessage', src, { args = {"^3System", "Target is too far."} })
    --     return
    -- end

    Log(string.format("Cop %s (%s) initiated subdue on Robber %s (%s).", GetPlayerName(src), src, GetPlayerName(targetRobberNumId), targetRobberNumId))
    TriggerClientEvent('cops_and_robbers:beginSubdueSequence', targetRobberNumId, src) -- Tell robber client they are being subdued

    activeSubdues[targetRobberNumId] = {
        copId = src,
        expiryTimer = SetTimeout(Config.SubdueTimeMs or 3000, function()
            if activeSubdues[targetRobberNumId] and activeSubdues[targetRobberNumId].copId == src then -- Check if still the same subdue attempt
                -- TODO: Final distance check before arrest
                -- local currentCopCoords = GetEntityCoords(GetPlayerPed(src))
                -- local currentRobberCoords = GetEntityCoords(GetPlayerPed(targetRobberNumId))
                -- if #(currentCopCoords - currentRobberCoords) <= (Config.TackleDistance + 1.0) then
                    Log(string.format("Subdue completed for Robber %s by Cop %s. Proceeding with arrest.", targetRobberNumId, src))

                    local robberWantedData = wantedPlayers[targetRobberNumId]
                    local starsAtArrest = robberWantedData and robberWantedData.stars or 0
                    local jailDuration = CalculateJailTime(starsAtArrest) -- Assuming CalculateJailTime function exists

                    SendToJail(targetRobberNumId, jailDuration, src, { isSubdueArrest = true })
                    activeSubdues[targetRobberNumId] = nil
                -- else
                --     Log(string.format("Subdue timed out but Cop %s moved too far from Robber %s. Arrest cancelled.", src, targetRobberNumId))
                --     TriggerClientEvent('cops_and_robbers:subdueCancelled', targetRobberNumId)
                --     activeSubdues[targetRobberNumId] = nil
                -- end
            end
        end)
    }
end)

-- Placeholder for CalculateJailTime if it doesn't exist elsewhere
-- This should ideally be more sophisticated based on wanted level/stars from Config
if CalculateJailTime == nil then
    CalculateJailTime = function(stars)
        local baseTime = 30 -- seconds
        return baseTime * (stars == 0 and 1 or stars) -- Min 30s, up to 150s for 5 stars (example)
    end
end

RegisterNetEvent('cops_and_robbers:subdueCancelled', function(reason) -- If client (robber) cancels (e.g. escapes)
    local src = tonumber(source) -- This is the Robber
    if activeSubdues[src] then
        local subdueData = activeSubdues[src]
        if subdueData.expiryTimer then ClearTimeout(subdueData.expiryTimer) end
        Log(string.format("Subdue on Robber %s was cancelled. Reason: %s", src, reason or "Robber action"))
        TriggerClientEvent('chat:addMessage', subdueData.copId, { args = {"^3System", "Suspect is no longer subdued."} })
        activeSubdues[src] = nil
    end
end)


RegisterNetEvent('cnr:requestRoleChange', function(role)
    local src = tonumber(source)
    if role == "cop" or role == "robber" or role == "citizen" then
        if role == "cop" and Config.MaxCops > 0 and tablelength(copsOnDuty) >= Config.MaxCops then
            TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "Max cops on duty."} })
            return
        end
        SetPlayerRole(src, role)
    else
        TriggerClientEvent('chat:addMessage', src, { args = {"^1Error", "Invalid role selected."} })
    end
end)

RegisterNetEvent('cnr:reportCrime', function(crimeKey, details) -- Removed victimPosition as it's not used
    local src = tonumber(source)
    if GetPlayerName(src) == nil or not IsPlayerRobber(src) then return end

    local pData = GetCnrPlayerData(src)
    if not pData then return end -- Should not happen if previous checks pass

    Log(string.format("Client Crime Report: '%s' by %s. Details: %s", crimeKey, src, json.encode(details)))

    -- Initialize cooldown table for player if not present
    if not clientReportCooldowns[src] then
        clientReportCooldowns[src] = {}
    end

    -- Define cooldowns for specific crimes (in seconds)
    local crimeSpecificCooldown = 0
    if crimeKey == 'assault_civilian' then
        crimeSpecificCooldown = 30 -- 30 seconds cooldown for reporting civilian assault
    elseif crimeKey == 'grand_theft_auto' then
        crimeSpecificCooldown = 60 -- 60 seconds cooldown for reporting GTA
    end

    if crimeSpecificCooldown > 0 then
        local lastReportTime = clientReportCooldowns[src][crimeKey] or 0
        if (os.time() - lastReportTime) < crimeSpecificCooldown then
            Log(string.format("Client Crime Report for '%s' by %s IGNORED due to cooldown. Last report: %s, Cooldown: %s", crimeKey, src, lastReportTime, crimeSpecificCooldown))
            TriggerClientEvent('chat:addMessage', src, { args = {"^3System", "Your report is too soon after a previous one."} })
            return -- Ignore report if it's within cooldown
        end
    end

    -- If report is not on cooldown or doesn't have a specific cooldown, proceed
    UpdatePlayerWantedLevel(src, crimeKey, nil) -- Pass nil for officerId for client-reported crimes

    -- Update the last report time for this crime
    if crimeSpecificCooldown > 0 then
        clientReportCooldowns[src][crimeKey] = os.time()
    end

    -- XP Award logic is handled within UpdatePlayerWantedLevel
    -- local crimeConfig = Config.WantedSettings.crimes[crimeKey]
    -- if crimeConfig and crimeConfig.xpForRobber and crimeConfig.xpForRobber > 0 then AddXP(src, crimeConfig.xpForRobber, "robber") end
    -- This was the original line here, but UpdatePlayerWantedLevel already contains similar logic.
end)

RegisterNetEvent('cnr:k9EngagedTarget', function(targetRobberServerId)
    local src = tonumber(source)
    local targetRobberNumId = tonumber(targetRobberServerId)
    if not IsPlayerCop(src) then Log(string.format("Warning: Non-cop %s tried K9 engage.", src), "warn"); return end
    if GetPlayerName(targetRobberNumId) == nil or not IsPlayerRobber(targetRobberNumId) then  -- Check target online
        Log(string.format("Warning: Cop %s K9 engage invalid or offline target %s.", src, targetRobberServerId), "warn")
        return
    end
    k9Engagements[targetRobberNumId] = { copId = src, time = os.time() }
    Log(string.format("K9 Engagement: Cop %s K9 engaged Robber %s.", src, targetRobberServerId))
end)

RegisterNetEvent('cops_and_robbers:setPlayerRole')
AddEventHandler('cops_and_robbers:setPlayerRole', function(selectedRole)
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    Log(string.format("NetEvent 'cops_and_robbers:setPlayerRole' received. Player: %s (ID: %s), Role: %s", playerName, src, selectedRole), "info")
    
    -- Call the main SetPlayerRole function
    -- The 'false' for skipNotify means they WILL get a chat message like "You are now a Cop."
    SetPlayerRole(src, selectedRole, false) 
end)

RegisterNetEvent("cops_and_robbers:banPlayer", function(targetId, reason)
    local sourceAdmin = tonumber(source) -- In server events, source is the player who triggered it, or server if from server console
    -- This event should ideally be triggered by an admin command that verifies IsAdmin(sourceAdmin).
    -- The IsAdmin function should be entirely framework independent.
    -- For now, we assume IsAdmin(sourceAdmin) is called before this event is triggered.

    local targetPlayerId = tonumber(targetId)
    local targetPlayerName = GetPlayerName(targetPlayerId) -- Get name for logging, even if offline for identifier ban

    if GetPlayerName(targetPlayerId) == nil then -- Target is offline
        Log("cops_and_robbers:banPlayer: Target player " .. targetPlayerId .. " is offline. Ban will proceed by identifier if found.", "warn")
        -- Allow banning offline players if an identifier can be constructed or is provided.
        -- This part requires a robust way to get identifiers for offline players if not directly passed.
        -- For now, we'll assume the ban is for an online player or this logic needs extension.
        -- If we only ban online players:
        if sourceAdmin and GetPlayerName(sourceAdmin) then
             TriggerClientEvent("chat:addMessage", sourceAdmin, { args = { "^1Admin", "Target player with ID " .. targetPlayerId .. " not found online for direct ban."} })
        end
        -- return -- Uncomment this to prevent banning offline players if identifiers cannot be reliably fetched.
    end

    local identifiers = GetPlayerIdentifiers(tostring(targetPlayerId))
    local primaryIdentifier = GetPlayerLicense(targetPlayerId) -- Use helper
    if not primaryIdentifier and identifiers and #identifiers > 0 then
        primaryIdentifier = identifiers[1] -- Fallback to first available identifier
        Log("cops_and_robbers:banPlayer: Using fallback identifier for ban: " .. primaryIdentifier, "warn")
    end


    if primaryIdentifier then
        local adminName = "System"
        if sourceAdmin and GetPlayerName(sourceAdmin) then
            adminName = GetPlayerName(sourceAdmin)
        elseif sourceAdmin == 0 then
            adminName = "Server Console"
        end

        bannedPlayers[primaryIdentifier] = {
            reason = reason or "No reason provided.",
            timestamp = os.time(),
            admin = adminName,
            name = targetPlayerName or "Unknown/Offline", -- Store name at time of ban
            expires = "permanent"
        }
        SaveBans()
        if GetPlayerName(targetPlayerId) ~= nil then -- If player is online, kick them
            DropPlayer(targetPlayerId, "You have been banned: " .. (reason or "No reason provided."))
        end
        local nameForMessage = targetPlayerName or ("Identifier " .. primaryIdentifier)
        TriggerClientEvent("chat:addMessage", -1, { args = { "^1Admin", "Player " .. nameForMessage .. " has been banned by " .. adminName .. ". Reason: " .. (reason or "N/A") } })
        Log("Player " .. nameForMessage .. " (" .. primaryIdentifier .. ") banned by " .. adminName .. ". Reason: " .. (reason or "N/A"), "info")
    else
        Log("Failed to ban player " .. (targetPlayerName or targetPlayerId) .. ": No primary identifier found.", "error")
        if sourceAdmin and GetPlayerName(sourceAdmin) then
            TriggerClientEvent("chat:addMessage", sourceAdmin, { args = { "^1Admin", "Could not get a suitable identifier for target player " .. (targetPlayerName or targetPlayerId) .. " to ban."} })
        end
    end
end)

-- =================================================================================================
-- MISC AND UTILITY FUNCTIONS
-- =================================================================================================
function tablelength(T) local count = 0; for _ in pairs(T) do count = count + 1 end; return count end

local function EnsurePlayerDataDirectory()
    local placeholder = "player_data/.gitkeep"
    if not LoadResourceFile(GetCurrentResourceName(), placeholder) then
        local success = SaveResourceFile(GetCurrentResourceName(), placeholder, "", -1)
        if success then
            Log("Initialized player_data directory.")
        else
            Log("Failed to create player_data directory. Check permissions.", "error")
        end
    end
end

Log("-------------------------------------------------", "info")
Log("Cops 'n' Robbers Gamemode Server Script Loaded", "info")
EnsurePlayerDataDirectory()
LoadBans() -- Load bans from file
LoadPurchaseHistory() -- Load purchase history
Log("Debug Logging: " .. (Config.DebugLogging and "Enabled" or "Disabled"), "info")
Log("-------------------------------------------------", "info")

CreateThread(function()
    while true do Wait(Config.PlayerCountSyncInterval * 1000)
        TriggerClientEvent('cnr:updatePlayerCounts', -1, tablelength(copsOnDuty), tablelength(robbersActive))
    end
end)

CreateThread(function() -- PeriodicSavePurchaseHistoryThread
    while true do
        Wait(1800000) -- Wait 30 minutes (1800000 ms)
        SavePurchaseHistory()
    end
end)

CreateThread(function()
    while true do Wait(300000)
        local currentTime = os.time(); local an_hour_ago = currentTime - 3600
        for targetId, engagement in pairs(k9Engagements) do
            if engagement.time < an_hour_ago then k9Engagements[targetId] = nil; Log(string.format("Cleaned up very old K9 engagement for target: %s", targetId)) end
        end
    end
end)

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    deferrals.defer()
    Citizen.Wait(250) -- Allow identifiers to load, can be adjusted.

    local playerSrcString = source -- This is the temporary server ID for the connecting player
    local pName = nil
    local identifiers = nil

    if playerSrcString then
        pName = GetPlayerName(playerSrcString) -- Get name early for logging if possible
        if pName and pName ~= "" then
            identifiers = GetPlayerIdentifiers(playerSrcString)
        end
    end

    if not playerSrcString or not pName or pName == "" or not identifiers or #identifiers == 0 then
        Log(string.format("playerConnecting: Could not reliably get identifiers for %s (Source ID: %s, Name: %s) at this stage. Allowing connection, subsequent checks will be critical.", playerName, tostring(playerSrcString), pName or "N/A"), "warn")
        -- Allow the player to connect; ban checks or data loading might use PID fallback if license isn't found later.
        -- The critical logging in LoadPlayerData will flag if license is still missing.
        deferrals.done()
        return
    end

    -- If we have identifiers, proceed with ban check.
    local matchedBan = nil
    local bannedIdentifier = nil

    for _, idStr in ipairs(identifiers) do
        if bannedPlayers[idStr] then
            matchedBan = bannedPlayers[idStr]
            bannedIdentifier = idStr
            break
        end
    end

    if matchedBan then
        local banInfo = matchedBan
        local expiryMsg = banInfo.expires == "permanent" and "Permanent" or "Expires: " .. os.date("%c", banInfo.expires)
        local reason = string.format("Banned.\nReason: %s\n%s\nBy: %s", banInfo.reason, expiryMsg, banInfo.admin or "System")
        deferrals.done(reason)
        Log(string.format("Banned player %s (Name: %s, ID: %s) attempted connect. Identifier: %s. Reason: %s", playerName, pName, tostring(playerSrcString), bannedIdentifier, banInfo.reason), "warn")
    else
        Log(string.format("Player %s (Name: %s, ID: %s) allowed to connect. No bans found during initial check. Identifiers: %s", playerName, pName, tostring(playerSrcString), json.encode(identifiers)))
        deferrals.done()
    end
end)

-- GetPlayerIdentifierByType is no longer needed as playerConnecting iterates all identifiers.

if not string.starts then function string.starts(String,Start) return string.sub(String,1,string.len(Start))==Start end end
PrintAllPlayerDataDebug = function() print("Current Player Data Store:") for k,v in pairs(playersData) do print("Player ID: "..k, json.encode(v)) end end
PrintActiveBountiesDebug = function() print("Active Bounties: ", json.encode(activeBounties)) end
PrintK9EngagementsDebug = function() print("K9 Engagements: ", json.encode(k9Engagements)) end

RegisterNetEvent('cnr:requestMyInventory')
AddEventHandler('cnr:requestMyInventory', function()
    local src = tonumber(source)
    local pData = GetCnrPlayerData(src)
    if pData and pData.inventory then
        -- Before sending, transform inventory for NUI if needed, especially for sell prices
        local nuiInventory = {}
        for itemId, itemData in pairs(pData.inventory) do
            local itemConfig = nil
            for _, cfgItem in ipairs(Config.Items) do
                if cfgItem.itemId == itemId then
                    itemConfig = cfgItem
                    break
                end
            end

            if itemConfig then
                local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
                local currentMarketPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice or 0)
                local sellPrice = math.floor(currentMarketPrice * sellPriceFactor)

                nuiInventory[itemId] = {
                    itemId = itemId, -- NUI might need this explicitly
                    name = itemData.name,
                    count = itemData.count,
                    category = itemData.category,
                    sellPrice = sellPrice -- Add sell price here
                    -- Add other relevant details for NUI if needed (e.g., item.label)
                }
            end
        end
        TriggerClientEvent('cnr:receiveMyInventory', src, nuiInventory)
    else
        TriggerClientEvent('cnr:receiveMyInventory', src, {}) -- Send empty if no inventory
    end
end)
