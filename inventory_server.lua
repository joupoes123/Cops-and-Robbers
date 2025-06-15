-- inventory_server.lua
-- Handles all server-side custom inventory logic for Cops 'n' Robbers.

-- Helper function to get player data - uses global function from server.lua
local function GetCnrPlayerData(playerId)
    if _G.GetCnrPlayerData then
        return _G.GetCnrPlayerData(playerId)
    end
    return nil
end

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

-- =====================================
--    INVENTORY UI SERVER FUNCTIONS
-- =====================================

-- Player equipped items tracking
local playerEquippedItems = {} -- [playerId] = { itemId = true, ... }

-- Event: Get inventory for UI
RegisterNetEvent('cnr:getInventoryForUI')
AddEventHandler('cnr:getInventoryForUI', function()
    local source = source
    local pData = GetCnrPlayerData(source)
    
    if not pData then
        Log("Failed to get player data for inventory UI request", "error")
        return
    end
    
    -- Get equipped items for this player
    local equipped = playerEquippedItems[source] or {}
    local equippedItemsArray = {}
    for itemId, _ in pairs(equipped) do
        table.insert(equippedItemsArray, itemId)
    end
    
    -- Send inventory and equipped items to client
    TriggerClientEvent('cnr:sendInventoryForUI', source, pData.inventory or {}, equippedItemsArray)
    Log(string.format("Sent inventory UI data to player %d", source))
end)

-- Event: Equip/unequip item
RegisterNetEvent('cnr:equipItem')
AddEventHandler('cnr:equipItem', function(itemId, shouldEquip)
    local source = source
    local pData = GetCnrPlayerData(source)
    
    if not pData or not pData.inventory then
        TriggerClientEvent('cnr:equipItemResult', source, false, "Player data not found")
        return
    end
    
    -- Check if player has the item
    if not HasItem(pData, itemId, 1, source) then
        TriggerClientEvent('cnr:equipItemResult', source, false, "You don't have this item")
        return
    end
    
    -- Initialize equipped items for player if not exists
    if not playerEquippedItems[source] then
        playerEquippedItems[source] = {}
    end
    
    local itemConfig = GetItemConfig(itemId)
    if not itemConfig then
        TriggerClientEvent('cnr:equipItemResult', source, false, "Invalid item")
        return
    end
    
    -- Check if item can be equipped
    if not CanItemBeEquipped(itemConfig) then
        TriggerClientEvent('cnr:equipItemResult', source, false, "This item cannot be equipped")
        return
    end
    
    local isCurrentlyEquipped = playerEquippedItems[source][itemId] == true
    
    if shouldEquip and not isCurrentlyEquipped then
        -- Equip item
        playerEquippedItems[source][itemId] = true
        
        -- Handle special equipment logic
        HandleItemEquip(source, itemId, itemConfig, pData)
        
        TriggerClientEvent('cnr:equipItemResult', source, true, "Item equipped")
        Log(string.format("Player %d equipped item %s", source, itemId))
        
    elseif not shouldEquip and isCurrentlyEquipped then
        -- Unequip item
        playerEquippedItems[source][itemId] = nil
        
        -- Handle special unequip logic
        HandleItemUnequip(source, itemId, itemConfig, pData)
        
        TriggerClientEvent('cnr:equipItemResult', source, true, "Item unequipped")
        Log(string.format("Player %d unequipped item %s", source, itemId))
    else
        TriggerClientEvent('cnr:equipItemResult', source, false, isCurrentlyEquipped and "Item already equipped" or "Item not equipped")
        return
    end
    
    -- Update inventory UI
    UpdateInventoryUI(source)
end)

-- Event: Use item
RegisterNetEvent('cnr:useItem')
AddEventHandler('cnr:useItem', function(itemId)
    local source = source
    local pData = GetCnrPlayerData(source)
    
    if not pData or not pData.inventory then
        TriggerClientEvent('cnr:useItemResult', source, false, "Player data not found", false)
        return
    end
    
    -- Check if player has the item
    if not HasItem(pData, itemId, 1, source) then
        TriggerClientEvent('cnr:useItemResult', source, false, "You don't have this item", false)
        return
    end
    
    local itemConfig = GetItemConfig(itemId)
    if not itemConfig then
        TriggerClientEvent('cnr:useItemResult', source, false, "Invalid item", false)
        return
    end
    
    -- Handle item usage
    local success, message, consumed = HandleItemUse(source, itemId, itemConfig, pData)
    
    if success and consumed then
        -- Remove item from inventory if it was consumed
        RemoveItem(pData, itemId, 1, source)
        UpdateInventoryUI(source)
    end
    
    TriggerClientEvent('cnr:useItemResult', source, success, message, consumed)
end)

-- Event: Drop item
RegisterNetEvent('cnr:dropItem')
AddEventHandler('cnr:dropItem', function(itemId, quantity)
    local source = source
    local pData = GetCnrPlayerData(source)
    
    if not pData or not pData.inventory then
        TriggerClientEvent('cnr:dropItemResult', source, false, "Player data not found")
        return
    end
    
    quantity = tonumber(quantity) or 1
    
    -- Check if player has enough of the item
    if not HasItem(pData, itemId, quantity, source) then
        TriggerClientEvent('cnr:dropItemResult', source, false, "You don't have enough of this item")
        return
    end
    
    -- Remove item from inventory
    if RemoveItem(pData, itemId, quantity, source) then
        -- Handle dropping logic (e.g., create world object)
        HandleItemDrop(source, itemId, quantity)
        
        -- If item was equipped and quantity drops to 0, unequip it
        if playerEquippedItems[source] and playerEquippedItems[source][itemId] then
            local remainingCount = GetInventory(pData, itemId, source)
            if remainingCount <= 0 then
                playerEquippedItems[source][itemId] = nil
                Log(string.format("Auto-unequipped %s for player %d (item dropped to 0)", itemId, source))
            end
        end
        
        UpdateInventoryUI(source)
        TriggerClientEvent('cnr:dropItemResult', source, true, "Item dropped")
        Log(string.format("Player %d dropped %dx %s", source, quantity, itemId))
    else
        TriggerClientEvent('cnr:dropItemResult', source, false, "Failed to drop item")
    end
end)

-- Helper function to get item config
function GetItemConfig(itemId)
    if Config and Config.Items and type(Config.Items) == "table" then
        for _, cfgItem in ipairs(Config.Items) do
            if cfgItem.itemId == itemId then
                return cfgItem
            end
        end
    end
    return nil
end

-- Helper function to check if item can be equipped
function CanItemBeEquipped(itemConfig)
    local equipableCategories = {"Weapons", "Melee Weapons", "Armor", "Cop Gear", "Utility"}
    
    for _, category in ipairs(equipableCategories) do
        if itemConfig.category == category then
            return true
        end
    end
    
    return false
end

-- Handle item equip logic
function HandleItemEquip(playerId, itemId, itemConfig, pData)
    -- Special handling for different item types
    if itemConfig.category == "Weapons" or itemConfig.category == "Melee Weapons" then
        -- Weapons are handled by the existing EquipInventoryWeapons function
        TriggerClientEvent('cnr:forceEquipWeapons', playerId)
        
    elseif itemConfig.category == "Armor" then
        -- Apply armor to player
        local armorAmount = 100
        if itemId == "heavy_armor" then
            armorAmount = 200
        end
        TriggerClientEvent('cnr:applyArmor', playerId, armorAmount)
        
    elseif itemConfig.category == "Cop Gear" then
        -- Handle cop gear
        if itemId == "spikestrip_item" then
            -- No immediate action needed, spike strips are deployed when used
        end
    end
end

-- Handle item unequip logic
function HandleItemUnequip(playerId, itemId, itemConfig, pData)
    -- Special handling for unequipping items
    if itemConfig.category == "Weapons" or itemConfig.category == "Melee Weapons" then
        -- Re-equip all weapons to update weapon wheel
        TriggerClientEvent('cnr:forceEquipWeapons', playerId)
        
    elseif itemConfig.category == "Armor" then
        -- Remove armor from player
        TriggerClientEvent('cnr:removeArmor', playerId)
    end
end

-- Handle item use logic
function HandleItemUse(playerId, itemId, itemConfig, pData)
    local consumed = false
    local message = "Item used"
    
    -- Handle different item types
    if itemId == "medkit" then
        -- Heal player
        TriggerClientEvent('cnr:healPlayer', playerId, 100)
        consumed = true
        message = "Medkit used - Health restored"
        
    elseif itemId == "firstaidkit" then
        -- Heal player partially
        TriggerClientEvent('cnr:healPlayer', playerId, 50)
        consumed = true
        message = "First aid kit used - Health partially restored"
        
    elseif itemId == "armor" then
        -- Apply armor
        TriggerClientEvent('cnr:applyArmor', playerId, 100)
        consumed = true
        message = "Armor applied"
        
    elseif itemId == "heavy_armor" then
        -- Apply heavy armor
        TriggerClientEvent('cnr:applyArmor', playerId, 200)
        consumed = true
        message = "Heavy armor applied"
        
    elseif itemId == "spikestrip_item" then
        -- Deploy spike strip
        local success = TriggerClientEvent('cnr:deploySpikeStrip', playerId)
        if success then
            consumed = true
            message = "Spike strip deployed"
        else
            message = "Failed to deploy spike strip"
            return false, message, consumed
        end
        
    else
        message = "This item cannot be used directly"
        return false, message, consumed
    end
    
    return true, message, consumed
end

-- Handle item drop logic
function HandleItemDrop(playerId, itemId, quantity)
    -- Get player position
    local playerPed = GetPlayerPed(playerId)
    if not playerPed then return end
    
    local coords = GetEntityCoords(playerPed)
    
    -- TODO: Create world object for dropped item
    -- For now, just log it
    Log(string.format("Player %d dropped %dx %s at coords %s", playerId, quantity, itemId, coords))
end

-- Update inventory UI for a player
function UpdateInventoryUI(playerId)
    local pData = GetCnrPlayerData(playerId)
    if not pData then return end
    
    local equipped = playerEquippedItems[playerId] or {}
    local equippedItemsArray = {}
    for itemId, _ in pairs(equipped) do
        table.insert(equippedItemsArray, itemId)
    end
    
    TriggerClientEvent('cnr:updateInventoryUI', playerId, pData.inventory or {}, equippedItemsArray)
end

-- Clean up equipped items when player disconnects
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    if playerEquippedItems[playerId] then
        playerEquippedItems[playerId] = nil
        Log(string.format("Cleaned up equipped items for disconnected player %d", playerId))
    end
end)

-- Export equipped items check function
function IsItemEquipped(playerId, itemId)
    return playerEquippedItems[playerId] and playerEquippedItems[playerId][itemId] == true
end

Log("Custom Inventory System (server-side) loaded.")
