-- Shared Utilities for Cops and Robbers
-- Consolidates common functions used across multiple files

-- Logging function with configurable prefixes
function Log(message, level, prefix)
    level = level or "info"
    prefix = prefix or "CNR"
    
    local shouldLog = false
    if Config and Config.LoggingEnabled then
        if Config.DebugLevel == "debug" then
            shouldLog = true
        elseif Config.DebugLevel == "info" and (level == "info" or level == "warn" or level == "error") then
            shouldLog = true
        elseif Config.DebugLevel == "warn" and (level == "warn" or level == "error") then
            shouldLog = true
        elseif Config.DebugLevel == "error" and level == "error" then
            shouldLog = true
        end
    end
    
    -- Always log errors and warnings, even if DebugLogging is disabled
    if shouldLog or level == "error" or level == "warn" then
        if level == "error" then 
            print("[" .. prefix .. "_ERROR] " .. message)
        elseif level == "warn" then 
            print("[" .. prefix .. "_WARN] " .. message)
        else 
            print("[" .. prefix .. "_INFO] " .. message)
        end
    end
end

-- Safe wrapper for FiveM's GetPlayerName native
function SafeGetPlayerName(playerId)
    if not playerId then return nil end
    local idNum = tonumber(playerId)
    if not idNum then return nil end
    local success, name = pcall(function() return GetPlayerName(tostring(idNum)) end)
    if success and name and type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

-- Safe wrapper for triggering client events
function SafeTriggerClientEvent(eventName, playerId, ...)
    if playerId and type(playerId) == "number" and playerId > 0 and GetPlayerName(playerId) then
        TriggerClientEvent(eventName, playerId, ...)
        return true
    else
        Log(string.format("SafeTriggerClientEvent: Invalid or offline player ID %s for event %s", tostring(playerId), eventName), "warn", "CNR_SERVER")
        return false
    end
end

-- Safe wrapper for getting player identifiers
function GetSafePlayerIdentifiers(playerId)
    if not playerId then return nil end
    local success, identifiers = pcall(function() return GetPlayerIdentifiers(playerId) end)
    if success and identifiers then
        return identifiers
    end
    return nil
end

-- Check if player is admin
function IsPlayerAdmin(playerId)
    local playerIdentifiers = GetSafePlayerIdentifiers(playerId)
    if not playerIdentifiers then return false end

    -- Ensure Config and Config.Admins are loaded and available
    if not Config or type(Config.Admins) ~= "table" then
        Log("Config.Admins is not loaded or not a table. Ensure config.lua defines it correctly.", "error", "CNR_SERVER")
        return false
    end

    for _, identifier in ipairs(playerIdentifiers) do
        if Config.Admins[identifier] then
            return true
        end
    end
    return false
end

-- ====================================================================
-- ====================================================================

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
