-- inventory_server.lua
-- Handles all server-side custom inventory logic for Cops 'n' Robbers.

-- Ensure Config is accessible for Log function; it should be global if config.lua ran.
local Config = Config

local function Log(message, level)
    level = level or "info"
    local shouldLog = false
    if Config and Config.DebugLogging then
        shouldLog = true
    end

    -- Always log errors and warnings, even if DebugLogging is disabled
    if shouldLog or level == "error" or level == "warn" then
        if level == "error" then print("[CNR_INV_SERV_ERROR] " .. message)
        elseif level == "warn" then print("[CNR_INV_SERV_WARN] " .. message)
        else print("[CNR_INV_SERV_INFO] " .. message) end
    end
end

-- Initialize player inventory when they load (called from main server.lua)
-- Accepts pData directly to avoid global lookups. playerId is for logging.
function InitializePlayerInventory(pData, playerId)
    if pData and not pData.inventory then
        pData.inventory = {} -- { itemId = { count = X, metadata = {...} } }
        Log("Initialized empty inventory for player " .. (playerId or "Unknown"))
    end
end

-- CanCarryItem: Checks if a player can carry an item (placeholder)
-- Note: This function was not part of the refactor request but shown for context.
-- If it were to be refactored, it would also take pData.
function CanCarryItem(playerId, itemId, quantity)
    -- TODO: Implement weight/slot logic if desired
    return true -- Placeholder
end

-- AddItem: Adds an item to player's inventory
-- Accepts pData directly. playerId (4th arg) is for logging & events.
function AddItem(pData, itemId, quantity, playerId)
    quantity = tonumber(quantity) or 1

    if not pData then Log("AddItem: Player data (pData) not provided for player " .. (playerId or "Unknown"), "error"); return false end
    -- Ensure inventory table exists on pData
    if not pData.inventory then InitializePlayerInventory(pData, playerId) end

    local itemConfig = nil
    if Config and Config.Items and type(Config.Items) == "table" then
        for _, cfgItem in ipairs(Config.Items) do
            if cfgItem.itemId == itemId then
                itemConfig = cfgItem
                break
            end
        end
    else
        Log("AddItem: Config.Items not available or not properly configured for player " .. (playerId or "Unknown"), "error")
        return false
    end

    if not itemConfig then Log("AddItem: Item config not found for " .. itemId .. " for player " .. (playerId or "Unknown"), "warn"); return false end

    if not pData.inventory[itemId] then
        pData.inventory[itemId] = { count = 0, name = itemConfig.name, category = itemConfig.category } -- Store basic info
    end
    pData.inventory[itemId].count = pData.inventory[itemId].count + quantity
    Log(string.format("Added %dx %s to player %s's inventory. New count: %d", quantity, itemId, playerId or "Unknown", pData.inventory[itemId].count))
    if playerId then 
        local playerIdNum = tonumber(playerId)
        if playerIdNum then
            TriggerClientEvent('cnr:inventoryUpdated', playerIdNum, pData.inventory) -- Notify client of change
        end
    end
    return true
end

-- RemoveItem: Removes an item from player's inventory
-- Accepts pData directly. playerId (4th arg) is for logging & events.
function RemoveItem(pData, itemId, quantity, playerId)
    quantity = tonumber(quantity) or 1

    if not pData or not pData.inventory then Log("RemoveItem: Player data (pData) or inventory not provided for player " .. (playerId or "Unknown"), "error"); return false end

    if not pData.inventory[itemId] or pData.inventory[itemId].count < quantity then
        Log(string.format("RemoveItem: Player %s does not have %dx %s. Has: %d", playerId or "Unknown", quantity, itemId, (pData.inventory[itemId] and pData.inventory[itemId].count or 0)), "warn")
        return false
    end

    pData.inventory[itemId].count = pData.inventory[itemId].count - quantity
    if pData.inventory[itemId].count <= 0 then
        pData.inventory[itemId] = nil -- Remove item if count is zero
    end
    Log(string.format("Removed %dx %s from player %s's inventory.", quantity, itemId, playerId or "Unknown"))
    if playerId then 
        local playerIdNum = tonumber(playerId)
        if playerIdNum then
            TriggerClientEvent('cnr:inventoryUpdated', playerIdNum, pData.inventory) -- Notify client of change
        end
    end
    return true
end

-- GetInventory: Returns a player's inventory (or specific item count)
-- Accepts pData directly. playerId (3rd arg) is for potential future logging.
function GetInventory(pData, specificItemId, playerId)
    if not pData or not pData.inventory then
        Log(string.format("GetInventory: Player data (pData) or inventory not provided for player %s.", playerId or "Unknown"), "warn")
        return specificItemId and 0 or {}
    end

    if specificItemId then
        return (pData.inventory[specificItemId] and pData.inventory[specificItemId].count) or 0
    end
    return pData.inventory
end

-- HasItem: Checks if a player has a specific quantity of an item
-- Accepts pData directly. playerId (4th arg) is for passing to GetInventory.
function HasItem(pData, itemId, quantity, playerId)
    quantity = tonumber(quantity) or 1
    local currentCount = GetInventory(pData, itemId, playerId)
    return currentCount >= quantity
end

Log("Custom Inventory System (server-side) loaded.")
