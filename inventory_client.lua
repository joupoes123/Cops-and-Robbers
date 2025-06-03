-- inventory_client.lua
-- Handles client-side custom inventory logic and NUI interaction.

local localPlayerInventory = {}

RegisterNetEvent('cnr:inventoryUpdated')
AddEventHandler('cnr:inventoryUpdated', function(updatedInventory)
    localPlayerInventory = updatedInventory or {}
    -- If NUI store is open and on 'sell' tab, refresh it
    SendNUIMessage({
        action = 'refreshSellListIfNeeded', -- NUI needs to implement this
        inventory = localPlayerInventory
    })
    Log("Client inventory updated.")
end)

-- Called by client.lua when NUI requests inventory
function RequestInventoryForNUI(callback)
    -- This function will be called from client.lua's NUI callback.
    -- It triggers a server event, and the server's response will eventually call the NUI `callback`.
    local promise = {} -- Simple table to hold resolve/reject for the NUI callback

    local function handleReceiveMyInventory(inventoryData)
        RemoveEventHandler('cnr:receiveMyInventory', handleReceiveMyInventory) -- Clean up listener
        localPlayerInventory = inventoryData or {}
        if callback then
            callback(localPlayerInventory) -- Send data back to NUI via the original callback
        end
        promise.resolved = true
    end
    AddEventHandler('cnr:receiveMyInventory', handleReceiveMyInventory)

    TriggerServerEvent('cnr:requestMyInventory')
    Log("Requested inventory from server for NUI.")

    -- Fallback timeout in case server doesn't respond (optional but good practice)
    SetTimeout(5000, function()
        if not promise.resolved then
            RemoveEventHandler('cnr:receiveMyInventory', handleReceiveMyInventory)
            if callback then
                callback({ error = "Failed to get inventory: Timeout" })
            end
            Log("RequestInventoryForNUI timed out.", "warn")
        end
    end)
end

function GetLocalInventory()
    return localPlayerInventory
end

Log("Custom Inventory System (client-side) loaded.")

-- Helper function, ensure Log is defined or use print
function Log(message, level)
    level = level or "info"
    -- Basic print logging for client, can be expanded
    print("[CNR_INV_CLIENT] [" .. string.upper(level) .. "] " .. message)
end
