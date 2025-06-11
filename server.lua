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
local Config = Config -- Keep this near the top as Log depends on it

local function Log(message, level)
    level = level or "info"
    if Config and Config.DebugLogging then
        print("[CNR_SERVER][" .. string.upper(level) .. "] " .. message)
    end
end

local function GetPlayerLicense(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, 7) == "license" then
            return id
        end
    end
    return nil
end

local function GetCnrPlayerData(playerId)
    return playersData[tonumber(playerId)]
end

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

local function GetPlayerMoney(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.money or 0
end

local function AddPlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = (pData.money or 0) + (tonumber(amount) or 0)
end

local function RemovePlayerMoney(playerId, amount, type)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    pData.money = math.max(0, (pData.money or 0) - (tonumber(amount) or 0))
end

local function IsAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    if not Config or type(Config.Admins) ~= "table" then return false end
    for _, identifier in ipairs(identifiers) do
        for _, adminId in ipairs(Config.Admins) do
            if identifier == adminId then return true end
        end
    end
    return false
end

local function GetPlayerRole(playerId)
    local pData = GetCnrPlayerData(playerId)
    return pData and pData.role or "citizen"
end

local function CalculateDynamicPrice(itemId, basePrice)
    return basePrice
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

        -- Trigger client-side events for equipping/using items
        if itemConfig then -- Ensure itemConfig is available
            if itemConfig.category == "Weapons" or itemConfig.category == "Melee Weapons" then
                local defaultAmmo = 1 -- Default for melee
                if itemConfig.category == "Weapons" then
                    -- More specific ammo defaults could be set here based on weapon type if desired
                    -- For now, a generic small amount for newly purchased firearms.
                    defaultAmmo = tonumber(itemConfig.defaultAmmo) or 12
                end
                TriggerClientEvent('cops_and_robbers:addWeapon', src, itemConfig.itemId, defaultAmmo)
                Log(string.format("Triggered addWeapon for player %s, item %s, ammo %d", src, itemConfig.itemId, defaultAmmo))
            elseif itemConfig.category == "Armor" then
                TriggerClientEvent('cops_and_robbers:applyArmor', src, itemConfig.itemId)
                Log(string.format("Triggered applyArmor for player %s, item %s", src, itemConfig.itemId))
            elseif itemConfig.category == "Ammunition" then
                if itemConfig.weaponLink and itemConfig.ammoAmount then
                    local totalAmmoToAdd = quantity * itemConfig.ammoAmount -- quantity is how many "packs" of ammo were bought
                    TriggerClientEvent('cops_and_robbers:addAmmo', src, itemConfig.weaponLink, totalAmmoToAdd)
                    Log(string.format("Player %s purchased %dx %s. Triggered client event addAmmo for weapon %s with %d total rounds.", src, quantity, itemId, itemConfig.weaponLink, totalAmmoToAdd))
                else
                    Log(string.format("Player %s purchased ammo %s, but it's missing weaponLink or ammoAmount in Config.Items. Cannot trigger addAmmo automatically.", src, itemId), "warn")
                end
            end
        end
    else
        Log(string.format("Custom AddItem failed for %s, item %s, quantity %d.", src, itemId, quantity), "error")
        TriggerClientEvent('cops_and_robbers:purchaseFailed', src, "Could not add item to inventory. Purchase reversed.")
        AddPlayerMoney(src, totalCost, 'cash') -- Refund
    end
end)

RegisterNetEvent('cnr:sellItemServerEvent')
AddEventHandler('cnr:sellItemServerEvent', function(itemId, quantity)
    local src = tonumber(source)
    quantity = tonumber(quantity) or 1

    Log(string.format("[SERVER_EVENT] cnr:sellItemServerEvent triggered by %s for item %s, quantity %d", src, itemId, quantity))

    local pData = GetCnrPlayerData(src)

    if not pData then
        Log(string.format("[SERVER_EVENT] cnr:sellItemServerEvent FAIL for %s: Player data not found.", src), "warn")
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
        Log(string.format("[SERVER_EVENT] cnr:sellItemServerEvent FAIL for %s: Item %s not in config.", src, itemId), "warn")
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "Item not found in config.")
        return
    end

    if not itemConfig.basePrice then -- Assuming items without a basePrice cannot be sold or have no value.
        Log(string.format("[SERVER_EVENT] cnr:sellItemServerEvent FAIL for %s: Item %s cannot be sold (no price).", src, itemId), "warn")
        TriggerClientEvent('cops_and_robbers:sellFailed', src, "Item cannot be sold (no price defined).")
        return
    end

    local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
    local currentMarketPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice) -- Assumes CalculateDynamicPrice exists
    local sellPricePerItem = math.floor(currentMarketPrice * sellPriceFactor)
    Log("[SERVER_EVENT] cnr:sellItemServerEvent - Item: " .. itemId .. ", Base Price: " .. (itemConfig.basePrice or "N/A") .. ", Current Market Price: " .. currentMarketPrice .. ", Sell Price: " .. sellPricePerItem)
    local totalGain = sellPricePerItem * quantity

    -- Assuming RemoveItem function exists and works similarly to AddItem,
    -- taking pData, itemId, quantity, and src.
    -- It should return true on success, false on failure.
    local removed = RemoveItem(pData, itemId, quantity, src)
    if removed then
        if AddPlayerMoney(src, totalGain, 'cash') then -- Assumes AddPlayerMoney exists
            TriggerClientEvent('cops_and_robbers:sellConfirmed', src, itemId, quantity)
            Log(string.format("[SERVER_EVENT] cnr:sellItemServerEvent SUCCESS for %s: Sold %dx %s for $%d.", src, quantity, itemId, totalGain))
            -- Potentially trigger an inventory update for the client if your NUI relies on it
            -- TriggerClientEvent('cnr:inventoryUpdated', src, pData.inventory)
        else
            Log(string.format("[SERVER_EVENT] cnr:sellItemServerEvent FAIL for %s: Sold %s, but failed to add money. Attempting to refund item.", src, itemId), "error")
            -- Attempt to give the item back if adding money failed.
            AddItem(pData, itemId, quantity, src) -- Assumes AddItem exists
            TriggerClientEvent('cops_and_robbers:sellFailed', src, "Payment processing error for sale. Item may have been refunded.")
        end
    else
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
    TriggerClientEvent('cnr:updatePlayerData', pIdNum, pData) -- This was already here, ensure it stays
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
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel START - pID: %s, crime: %s, officer: %s', playerId, crimeKey, officerId or 'nil'))
    local pIdNum = tonumber(playerId)
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Player valid check. pIDNum: %s, Name: %s, IsRobber: %s', pIdNum, GetPlayerName(pIdNum) or "N/A", tostring(IsPlayerRobber(pIdNum))))
    if GetPlayerName(pIdNum) == nil or not IsPlayerRobber(pIdNum) then return end -- Check player online

    local crimeConfig = Config.WantedSettings.crimes[crimeKey]
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Crime config for %s is: %s', crimeKey, crimeConfig and json.encode(crimeConfig) or "nil"))
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
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Wanted calculation complete. pID: %s, Stars: %d, Points: %d', pIdNum, newStars, currentWanted.wantedLevel))

    Log(string.format("Player %s committed crime '%s'. Points: %s. Wanted Lvl: %d, Stars: %d", pIdNum, crimeKey, pointsToAdd, currentWanted.wantedLevel, newStars))
    TriggerClientEvent('cnr:wantedLevelSync', pIdNum, currentWanted) -- Syncs wantedLevel points and stars
    -- The [CNR_SERVER_DEBUG] print previously here is now covered by the TRACE print above.
    TriggerClientEvent('cops_and_robbers:updateWantedDisplay', pIdNum, newStars, currentWanted.wantedLevel) -- Explicitly update client UI
    TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^1Wanted", string.format("Wanted level increased! (%d Stars)", newStars)} })

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
            TriggerClientEvent('cops_and_robbers:wantedLevelResponseUpdate', pIdNum, pIdNum, newStars, currentWanted.wantedLevel, robberCoords)
        else
            Log(string.format("UpdatePlayerWantedLevel: NPC Response DISABLED via Config.WantedSettings.enableNPCResponse for player %s (%d stars). Not triggering event.", pIdNum, newStars), "info")
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

-- Cop Store/Inventory NUI: Get Player Inventory for Sell Tab
RegisterNetEvent('cops_and_robbers:getPlayerInventory')
AddEventHandler('cops_and_robbers:getPlayerInventory', function()
    local src = source
    local pData = GetCnrPlayerData(src)
    if not pData or not pData.inventory then
        TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, {})
        return
    end
    local nuiInventory = {}
    for itemId, itemData in pairs(pData.inventory) do
        local itemConfig = nil
        for _, cfgItem in ipairs(Config.Items) do
            if cfgItem.itemId == itemId then itemConfig = cfgItem; break end
        end
        if itemConfig then
            local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
            local currentMarketPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice or 0)
            local sellPrice = math.floor(currentMarketPrice * sellPriceFactor)
            nuiInventory[itemId] = {
                itemId = tostring(itemId),
                name = tostring(itemData.name or itemConfig.name or "Unknown Item"),
                count = tonumber(itemData.count or 0),
                category = tostring(itemConfig.category or "Other"),
                sellPrice = tonumber(sellPrice or 0)
            }
        end
    end
    TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, nuiInventory)
end)

-- Cop Store NUI: Buy Item
RegisterNetEvent('cops_and_robbers:buyItem')
AddEventHandler('cops_and_robbers:buyItem', function(itemId, quantity)
    local src = source
    local pData = GetCnrPlayerData(src)
    quantity = tonumber(quantity) or 1

    if not pData then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "Player data not found.")
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
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "Item not found in config.")
        return
    end

    -- Level Restriction Check
    if pData.role == "cop" and itemConfig.minLevelCop and pData.level < itemConfig.minLevelCop then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "You are not high enough level for this item. (Required Cop Lvl: " .. itemConfig.minLevelCop .. ")")
        return
    elseif pData.role == "robber" and itemConfig.minLevelRobber and pData.level < itemConfig.minLevelRobber then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "You are not high enough level for this item. (Required Robber Lvl: " .. itemConfig.minLevelRobber .. ")")
        return
    end

    -- Cop Only Restriction Check
    if itemConfig.forCop and pData.role ~= "cop" then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "This item is restricted to Cops only.")
        return
    end

    local itemPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice)
    Log("cnr:buyItem - Item: " .. itemId .. ", Base Price: " .. itemConfig.basePrice .. ", Dynamic Price: " .. itemPrice)
    local totalCost = itemPrice * quantity

    if not RemovePlayerMoney(src, totalCost, 'cash') then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "Not enough cash or payment failed.")
        return
    end

    -- Successfully removed money, now add item
    local added = AddItem(pData, itemId, quantity, src) -- Use custom AddItem, pass pData and src
    if added then
        TriggerClientEvent('cops_and_robbers:buyResult', src, true, "Purchase successful!")
        TriggerClientEvent('cnr:inventoryUpdated', src, pData.inventory)
    else
        AddPlayerMoney(src, totalCost, 'cash') -- Refund
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "Could not add item to inventory. Purchase reversed.")
    end
end)

-- Cop Store NUI: Sell Item
RegisterNetEvent('cops_and_robbers:sellItem')
AddEventHandler('cops_and_robbers:sellItem', function(itemId, quantity)
    local src = source
    local pData = GetCnrPlayerData(src)
    quantity = tonumber(quantity) or 1

    if not pData then
        TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Player data not found.")
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
        TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Item not found in config.")
        return
    end

    if not itemConfig.basePrice then
        TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Item cannot be sold (no price defined).")
        return
    end

    local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
    local currentMarketPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice)
    local sellPricePerItem = math.floor(currentMarketPrice * sellPriceFactor)
    local totalGain = sellPricePerItem * quantity

    -- Assuming RemoveItem function exists and works similarly to AddItem,
    -- taking pData, itemId, quantity, and src.
    -- It should return true on success, false on failure.
    local removed = RemoveItem(pData, itemId, quantity, src)
    if removed then
        if AddPlayerMoney(src, totalGain, 'cash') then -- Assumes AddPlayerMoney exists
            TriggerClientEvent('cops_and_robbers:sellResult', src, true, "Sold successfully!")
            TriggerClientEvent('cnr:inventoryUpdated', src, pData.inventory)
        else
            AddItem(pData, itemId, quantity, src) -- Refund item
            TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Payment processing error for sale. Item may have been refunded.")
        end
    else
        TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Could not remove item from inventory.")
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
    TriggerClientEvent('cnr:updatePlayerData', pIdNum, pData) -- This was already here, ensure it stays
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
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel START - pID: %s, crime: %s, officer: %s', playerId, crimeKey, officerId or 'nil'))
    local pIdNum = tonumber(playerId)
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Player valid check. pIDNum: %s, Name: %s, IsRobber: %s', pIdNum, GetPlayerName(pIdNum) or "N/A", tostring(IsPlayerRobber(pIdNum))))
    if GetPlayerName(pIdNum) == nil or not IsPlayerRobber(pIdNum) then return end -- Check player online

    local crimeConfig = Config.WantedSettings.crimes[crimeKey]
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Crime config for %s is: %s', crimeKey, crimeConfig and json.encode(crimeConfig) or "nil"))
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
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Wanted calculation complete. pID: %s, Stars: %d, Points: %d', pIdNum, newStars, currentWanted.wantedLevel))

    Log(string.format("Player %s committed crime '%s'. Points: %s. Wanted Lvl: %d, Stars: %d", pIdNum, crimeKey, pointsToAdd, currentWanted.wantedLevel, newStars))
    TriggerClientEvent('cnr:wantedLevelSync', pIdNum, currentWanted) -- Syncs wantedLevel points and stars
    -- The [CNR_SERVER_DEBUG] print previously here is now covered by the TRACE print above.
    TriggerClientEvent('cops_and_robbers:updateWantedDisplay', pIdNum, newStars, currentWanted.wantedLevel) -- Explicitly update client UI
    TriggerClientEvent('chat:addMessage', pIdNum, { args = {"^1Wanted", string.format("Wanted level increased! (%d Stars)", newStars)} })

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
            TriggerClientEvent('cops_and_robbers:wantedLevelResponseUpdate', pIdNum, pIdNum, newStars, currentWanted.wantedLevel, robberCoords)
        else
            Log(string.format("UpdatePlayerWantedLevel: NPC Response DISABLED via Config.WantedSettings.enableNPCResponse for player %s (%d stars). Not triggering event.", pIdNum, newStars), "info")
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

-- Cop Store/Inventory NUI: Get Player Inventory for Sell Tab
RegisterNetEvent('cops_and_robbers:getPlayerInventory')
AddEventHandler('cops_and_robbers:getPlayerInventory', function()
    local src = source
    local pData = GetCnrPlayerData(src)
    if not pData or not pData.inventory then
        TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, {})
        return
    end
    local nuiInventory = {}
    for itemId, itemData in pairs(pData.inventory) do
        local itemConfig = nil
        for _, cfgItem in ipairs(Config.Items) do
            if cfgItem.itemId == itemId then itemConfig = cfgItem; break end
        end
        if itemConfig then
            local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
            local currentMarketPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice or 0)
            local sellPrice = math.floor(currentMarketPrice * sellPriceFactor)
            nuiInventory[itemId] = {
                itemId = tostring(itemId),
                name = tostring(itemData.name or itemConfig.name or "Unknown Item"),
                count = tonumber(itemData.count or 0),
                category = tostring(itemConfig.category or "Other"),
                sellPrice = tonumber(sellPrice or 0)
            }
        end
    end
    TriggerClientEvent('cops_and_robbers:sendPlayerInventory', src, nuiInventory)
end)

-- Cop Store NUI: Buy Item
RegisterNetEvent('cops_and_robbers:buyItem')
AddEventHandler('cops_and_robbers:buyItem', function(itemId, quantity)
    local src = source
    local pData = GetCnrPlayerData(src)
    quantity = tonumber(quantity) or 1

    if not pData then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "Player data not found.")
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
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "Item not found in config.")
        return
    end

    -- Level Restriction Check
    if pData.role == "cop" and itemConfig.minLevelCop and pData.level < itemConfig.minLevelCop then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "You are not high enough level for this item. (Required Cop Lvl: " .. itemConfig.minLevelCop .. ")")
        return
    elseif pData.role == "robber" and itemConfig.minLevelRobber and pData.level < itemConfig.minLevelRobber then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "You are not high enough level for this item. (Required Robber Lvl: " .. itemConfig.minLevelRobber .. ")")
        return
    end

    -- Cop Only Restriction Check
    if itemConfig.forCop and pData.role ~= "cop" then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "This item is restricted to Cops only.")
        return
    end

    local itemPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice)
    Log("cnr:buyItem - Item: " .. itemId .. ", Base Price: " .. itemConfig.basePrice .. ", Dynamic Price: " .. itemPrice)
    local totalCost = itemPrice * quantity

    if not RemovePlayerMoney(src, totalCost, 'cash') then
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "Not enough cash or payment failed.")
        return
    end

    -- Successfully removed money, now add item
    local added = AddItem(pData, itemId, quantity, src) -- Use custom AddItem, pass pData and src
    if added then
        TriggerClientEvent('cops_and_robbers:buyResult', src, true, "Purchase successful!")
        TriggerClientEvent('cnr:inventoryUpdated', src, pData.inventory)
    else
        AddPlayerMoney(src, totalCost, 'cash') -- Refund
        TriggerClientEvent('cops_and_robbers:buyResult', src, false, "Could not add item to inventory. Purchase reversed.")
    end
end)

-- Cop Store NUI: Sell Item
RegisterNetEvent('cops_and_robbers:sellItem')
AddEventHandler('cops_and_robbers:sellItem', function(itemId, quantity)
    local src = source
    local pData = GetCnrPlayerData(src)
    quantity = tonumber(quantity) or 1

    if not pData then
        TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Player data not found.")
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
        TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Item not found in config.")
        return
    end

    if not itemConfig.basePrice then
        TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Item cannot be sold (no price defined).")
        return
    end

    local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
    local currentMarketPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice)
    local sellPricePerItem = math.floor(currentMarketPrice * sellPriceFactor)
    local totalGain = sellPricePerItem * quantity

    -- Assuming RemoveItem function exists and works similarly to AddItem,
    -- taking pData, itemId, quantity, and src.
    -- It should return true on success, false on failure.
    local removed = RemoveItem(pData, itemId, quantity, src)
    if removed then
        if AddPlayerMoney(src, totalGain, 'cash') then -- Assumes AddPlayerMoney exists
            TriggerClientEvent('cops_and_robbers:sellResult', src, true, "Sold successfully!")
            TriggerClientEvent('cnr:inventoryUpdated', src, pData.inventory)
        else
            AddItem(pData, itemId, quantity, src) -- Refund item
            TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Payment processing error for sale. Item may have been refunded.")
        end
    else
        TriggerClientEvent('cops_and_robbers:sellResult', src, false, "Could not remove item from inventory.")
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
    TriggerClientEvent('cnr:updatePlayerData', pIdNum, pData) -- This was already here, ensure it stays
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
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel START - pID: %s, crime: %s, officer: %s', playerId, crimeKey, officerId or 'nil'))
    local pIdNum = tonumber(playerId)
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Player valid check. pIDNum: %s, Name: %s, IsRobber: %s', pIdNum, GetPlayerName(pIdNum) or "N/A", tostring(IsPlayerRobber(pIdNum))))
    if GetPlayerName(pIdNum) == nil or not IsPlayerRobber(pIdNum) then return end -- Check player online

    local crimeConfig = Config.WantedSettings.crimes[crimeKey]
    print(string.format('[CNR_SERVER_TRACE] UpdatePlayerWantedLevel: Crime config for %s is: %s', crimeKey, crimeConfig and json.encode(crimeConfig) or "nil"))
    if not crimeConfig then Log("UpdatePlayerWantedLevel: Unknown crimeKey: " .. crimeKey, "error"); return end

    if not wantedPlayers[pIdNum] then wantedPlayers[pIdNum] = { wantedLevel = 0, stars = 0, lastCrimeTime = 0, crimesCommitted = {} } end
    local currentWanted = wantedPlayers[pIdNum]

    -- Use crimeConfig.points if defined, otherwise Config.WantedSettings.baseIncreasePoints
    local pointsToAdd = (type(crimeConfig) == "table" and crimeConfig.wantedPoints) or (type(crimeConfig)