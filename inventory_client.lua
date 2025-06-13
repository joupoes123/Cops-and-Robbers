-- inventory_client.lua
-- Handles client-side custom inventory logic and NUI interaction.

local clientConfigItems = nil -- Will store Config.Items from server

-- Function to get the items, accessible by other parts of this script
function GetClientConfigItems()
    return clientConfigItems
end

-- Export for other client scripts if necessary
-- exports('GetClientConfigItems', GetClientConfigItems)

-- Helper function
function Log(message, level)
    level = level or "info"
    print("[CNR_INV_CLIENT] [" .. string.upper(level) .. "] " .. message)
end

RegisterNetEvent('cnr:receiveMyInventory') -- Ensure client is registered to receive this event from server
local localPlayerInventory = {} -- This will store the RECONSTRUCTED rich inventory

RegisterNetEvent('cnr:inventoryUpdated')
AddEventHandler('cnr:inventoryUpdated', function(updatedMinimalInventory)
    Log("Received cnr:inventoryUpdated. This event might need review if cnr:syncInventory is primary.", "warn")
    UpdateFullInventory(updatedMinimalInventory)
end)

RegisterNetEvent('cnr:receiveConfigItems')
AddEventHandler('cnr:receiveConfigItems', function(receivedConfigItems)
    clientConfigItems = receivedConfigItems
    Log("Received Config.Items from server. Item count: " .. tablelength(clientConfigItems or {}), "info")

    SendNUIMessage({
        action = 'storeFullItemConfig',
        itemConfig = clientConfigItems
    })
    Log("Sent Config.Items to NUI via SendNUIMessage.", "info")

    -- Check if localPlayerInventory currently holds minimal data (e.g. from an early sync before config arrived)
    -- A simple heuristic: if an item exists and its 'name' field is the same as its 'itemId', it's likely minimal.
    if localPlayerInventory and next(localPlayerInventory) then
        local firstItemId = next(localPlayerInventory)
        if localPlayerInventory[firstItemId] and localPlayerInventory[firstItemId].name == firstItemId then
             Log("Config.Items received after minimal inventory was stored. Attempting full reconstruction.", "info")
             UpdateFullInventory(localPlayerInventory) -- Re-process with the now available config
        end
    end
end)

function UpdateFullInventory(minimalInventoryData)
    Log("UpdateFullInventory received data. Attempting reconstruction...", "info")
    local reconstructedInventory = {}
    local configItems = GetClientConfigItems()

    if not configItems then
        Log("UpdateFullInventory: clientConfigItems not yet available. Storing minimal inventory. EquipInventoryWeapons may not work fully.", "error")
        localPlayerInventory = minimalInventoryData or {}
        EquipInventoryWeapons()
        return
    end

    if minimalInventoryData and type(minimalInventoryData) == 'table' then
        for itemId, minItemData in pairs(minimalInventoryData) do
            if minItemData and minItemData.count and minItemData.count > 0 then
                local itemDetails = nil
                -- Find the item in the local Config.Items (assuming configItems is an array as per typical Config.Items structure)
                for _, cfgItem in ipairs(configItems) do
                    if cfgItem.itemId == itemId then
                        itemDetails = cfgItem
                        break
                    end
                end

                if itemDetails then
                    reconstructedInventory[itemId] = {
                        itemId = itemId,
                        name = itemDetails.name,
                        category = itemDetails.category,
                        count = minItemData.count,
                        basePrice = itemDetails.basePrice -- Store other useful info if needed
                    }
                else
                    Log(string.format("UpdateFullInventory: ItemId '%s' not found in local clientConfigItems. Storing with minimal details.", itemId), "warn")
                    reconstructedInventory[itemId] = { -- Fallback if item not in config (should be rare)
                        itemId = itemId,
                        name = itemId,
                        category = "Unknown",
                        count = minItemData.count
                    }
                end
            end
        end
    end

    localPlayerInventory = reconstructedInventory
    Log("Full inventory reconstructed. Item count: " .. tablelength(localPlayerInventory), "info")

    -- NUI is now primarily responsible for using its own fullItemConfig for the Sell tab.
    -- This message just signals that an update happened.
    SendNUIMessage({
        action = 'refreshSellListIfNeeded'
    })

    EquipInventoryWeapons()
    Log("UpdateFullInventory: Called EquipInventoryWeapons() after inventory reconstruction.", "info")
end


function RequestInventoryForNUI(callback)
    -- This function is now simplified. It returns the current client-side reconstructed inventory.
    -- The NUI should rely on `refreshSellListIfNeeded` (triggered by `cnr:syncInventory -> UpdateFullInventory`)
    -- for knowing when to re-fetch/re-render its sell list by calling the NUI callback `getPlayerInventory`.
    if callback then
        callback(GetLocalInventory())
    end
    Log("RequestInventoryForNUI: Provided current localPlayerInventory to callback.", "info")
end

function GetLocalInventory()
    return localPlayerInventory
end

Log("Custom Inventory System (client-side) loaded.")

local function tablelength(T)
  if type(T) ~= "table" then return 0 end
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function EquipInventoryWeapons()
    local playerPed = PlayerPedId()

    if not playerPed or playerPed == 0 or playerPed == -1 then
        Log("EquipInventoryWeapons: Invalid playerPed. Cannot equip weapons.", "error")
        return
    end

    Log("EquipInventoryWeapons: Starting. Inv count: " .. tablelength(localPlayerInventory), "info")

    if not localPlayerInventory or tablelength(localPlayerInventory) == 0 then
        Log("EquipInventoryWeapons: Player inventory is empty or nil.", "info")
        return
    end

    -- Debug: Log all items in inventory
    for itemId, itemData in pairs(localPlayerInventory) do
        Log(string.format("  DEBUG_INVENTORY: Item %s - Name: %s, Category: %s, Count: %s", itemId, tostring(itemData.name), tostring(itemData.category), tostring(itemData.count)), "info")
    end

    -- First, remove all weapons from the player to ensure clean state
    Log("EquipInventoryWeapons: Removing all existing weapons to ensure clean state.", "info")
    RemoveAllPedWeapons(playerPed, true)
    Citizen.Wait(100) -- Short wait to ensure weapons are removed

    local processedItemCount = 0
    local weaponsEquipped = 0
    for itemId, itemData in pairs(localPlayerInventory) do
        processedItemCount = processedItemCount + 1        if type(itemData) == "table" and itemData.category and itemData.count and itemData.name then
            if (itemData.category == "Weapons" or itemData.category == "Melee Weapons") and itemData.count > 0 then
                -- Convert itemId to uppercase for hash calculation (GTA weapon names are typically uppercase)
                local upperItemId = string.upper(itemId)
                local weaponHash = GetHashKey(upperItemId)
                
                -- Also try the original itemId if uppercase doesn't work
                if weaponHash == 0 or weaponHash == -1 then
                    weaponHash = GetHashKey(itemId)
                end
                
                Log(string.format("  DEBUG_HASH: ItemId: %s, UpperCase: %s, Hash: %s", itemId, upperItemId, weaponHash), "info")
                
                if weaponHash ~= 0 and weaponHash ~= -1 then
                    -- Determine ammo: use itemData.ammo if present, else default
                    local ammoCount = itemData.ammo
                    if ammoCount == nil then
                        if Config and Config.DefaultWeaponAmmo and Config.DefaultWeaponAmmo[itemId] then
                           ammoCount = Config.DefaultWeaponAmmo[itemId]
                        else
                           ammoCount = 150 -- Increased default ammo for better testing
                        end
                    end
                    
                    -- Give weapon with ammo
                    GiveWeaponToPed(playerPed, weaponHash, ammoCount, false, true)
                    Citizen.Wait(50) -- Small wait between weapons
                    
                    -- Ensure ammo is set correctly
                    SetPedAmmo(playerPed, weaponHash, ammoCount)
                    
                    -- Verify the weapon was equipped
                    local hasWeapon = HasPedGotWeapon(playerPed, weaponHash, false)
                    if hasWeapon then
                        weaponsEquipped = weaponsEquipped + 1
                        Log(string.format("  ✓ EQUIPPED: %s (ID: %s, Hash: %s) Ammo: %d", itemData.name or itemId, itemId, weaponHash, ammoCount), "info")
                    else
                        Log(string.format("  ✗ FAILED_EQUIP: %s (ID: %s, Hash: %s) - HasPedGotWeapon returned false", itemData.name or itemId, itemId, weaponHash), "error")
                    end
                else
                    Log(string.format("  ✗ INVALID_HASH: ItemId: %s (Name: %s) - Could not get valid weapon hash", itemId, itemData.name), "error")
                end
            else
                Log(string.format("  SKIPPED: Item %s (Name: %s) - Category: %s, Count: %s", itemId, tostring(itemData.name), tostring(itemData.category), tostring(itemData.count)), "info")
            end
        else
            Log(string.format("  WARNING: Item ID: %s missing data (Name: %s, Category: %s, Count: %s).", itemId, tostring(itemData.name), tostring(itemData.category), tostring(itemData.count)), "warn")
        end
    end
    
    Log(string.format("EquipInventoryWeapons: Finished. Processed %d items. Successfully equipped %d weapons.", processedItemCount, weaponsEquipped), "info")
    
    -- Final verification - list all weapons the player currently has
    Citizen.Wait(100)
    Log("EquipInventoryWeapons: Final weapon check:", "info")
    local configItems = GetClientConfigItems()
    if configItems then
        for _, cfgItem in ipairs(configItems) do
            if cfgItem.category == "Weapons" then
                local weaponHash = GetHashKey(cfgItem.itemId)
                if weaponHash ~= 0 and weaponHash ~= -1 then
                    local hasWeapon = HasPedGotWeapon(playerPed, weaponHash, false)
                    if hasWeapon then
                        local ammoCount = GetAmmoInPedWeapon(playerPed, weaponHash)
                        Log(string.format("  FINAL_CHECK: Player has %s (%s) with %d ammo", cfgItem.name, cfgItem.itemId, ammoCount), "info")
                    end
                end
            end
        end
    end
end

-- Request Config.Items when this script loads/player initializes
Citizen.SetTimeout(1000, function()
    if not clientConfigItems then
        TriggerServerEvent('cnr:requestConfigItems')
        Log("Requested Config.Items from server.", "info")
    end
end)
