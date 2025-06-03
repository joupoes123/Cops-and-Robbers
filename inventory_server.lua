-- inventory_server.lua
-- Handles all server-side custom inventory logic for Cops 'n' Robbers.

-- Initialize player inventory when they load (called from main server.lua)
function InitializePlayerInventory(playerId)
    local pData = playersData[tonumber(playerId)]
    if pData and not pData.inventory then
        pData.inventory = {} -- { itemId = { count = X, metadata = {...} } }
        Log("Initialized empty inventory for player " .. playerId)
    end
end

-- CanCarryItem: Checks if a player can carry an item (placeholder)
function CanCarryItem(playerId, itemId, quantity)
    -- TODO: Implement weight/slot logic if desired
    return true -- Placeholder
end

-- AddItem: Adds an item to player's inventory
function AddItem(playerId, itemId, quantity)
    local pIdNum = tonumber(playerId)
    local pData = playersData[pIdNum]
    quantity = tonumber(quantity) or 1

    if not pData then Log("AddItem: Player data not found for " .. playerId, "error"); return false end
    if not pData.inventory then InitializePlayerInventory(pIdNum) end -- Should be initialized on load

    local itemConfig = nil
    for _, cfgItem in ipairs(Config.Items) do
        if cfgItem.itemId == itemId then
            itemConfig = cfgItem
            break
        end
    end

    if not itemConfig then Log("AddItem: Item config not found for " .. itemId, "warn"); return false end

    if not pData.inventory[itemId] then
        pData.inventory[itemId] = { count = 0, name = itemConfig.name, category = itemConfig.category } -- Store basic info
    end
    pData.inventory[itemId].count = pData.inventory[itemId].count + quantity
    Log(string.format("Added %dx %s to player %s's inventory. New count: %d", quantity, itemId, playerId, pData.inventory[itemId].count))
    TriggerClientEvent('cnr:inventoryUpdated', pIdNum, pData.inventory) -- Notify client of change
    return true
end

-- RemoveItem: Removes an item from player's inventory
function RemoveItem(playerId, itemId, quantity)
    local pIdNum = tonumber(playerId)
    local pData = playersData[pIdNum]
    quantity = tonumber(quantity) or 1

    if not pData or not pData.inventory then Log("RemoveItem: Player data or inventory not found for " .. playerId, "error"); return false end

    if not pData.inventory[itemId] or pData.inventory[itemId].count < quantity then
        Log(string.format("RemoveItem: Player %s does not have %dx %s. Has: %d", playerId, quantity, itemId, (pData.inventory[itemId] and pData.inventory[itemId].count or 0)), "warn")
        return false
    end

    pData.inventory[itemId].count = pData.inventory[itemId].count - quantity
    if pData.inventory[itemId].count <= 0 then
        pData.inventory[itemId] = nil -- Remove item if count is zero
    end
    Log(string.format("Removed %dx %s from player %s's inventory.", quantity, itemId, playerId))
    TriggerClientEvent('cnr:inventoryUpdated', pIdNum, pData.inventory) -- Notify client of change
    return true
end

-- GetInventory: Returns a player's inventory (or specific item count)
function GetInventory(playerId, specificItemId)
    local pIdNum = tonumber(playerId)
    local pData = playersData[pIdNum]
    if not pData or not pData.inventory then return specificItemId and 0 or {} end

    if specificItemId then
        return (pData.inventory[specificItemId] and pData.inventory[specificItemId].count) or 0
    end
    return pData.inventory
end

-- HasItem: Checks if a player has a specific quantity of an item
function HasItem(playerId, itemId, quantity)
    quantity = tonumber(quantity) or 1
    local currentCount = GetInventory(playerId, itemId)
    return currentCount >= quantity
end

Log("Custom Inventory System (server-side) loaded.")
