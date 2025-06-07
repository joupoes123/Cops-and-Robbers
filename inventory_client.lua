-- inventory_client.lua
-- Handles client-side custom inventory logic and NUI interaction.

-- Helper function
function Log(message, level)
    level = level or "info"
    -- Basic print logging for client, can be expanded
    print("[CNR_INV_CLIENT] [" .. string.upper(level) .. "] " .. message)
end

RegisterNetEvent('cnr:receiveMyInventory') -- Ensure client is registered to receive this event from server

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

function RequestInventoryForNUI(callback)
    local promise = {}
    local activeHandler = nil -- Declare activeHandler

    -- Define the actual handler function
    local function originalHandleReceiveMyInventory(inventoryData)
        if activeHandler then -- Check if handler is still active
            RemoveEventHandler('cnr:receiveMyInventory', activeHandler) -- Use activeHandler to remove
            activeHandler = nil -- Mark as inactive/cleaned up
        end
        localPlayerInventory = inventoryData or {}
        if callback then
            callback(localPlayerInventory)
        end
        promise.resolved = true
    end

    activeHandler = originalHandleReceiveMyInventory -- Assign the function to activeHandler

    AddEventHandler('cnr:receiveMyInventory', activeHandler) -- Register with the activeHandler reference

    TriggerServerEvent('cnr:requestMyInventory')
    Log("Requested inventory from server for NUI.")

    SetTimeout(5000, function()
        if not promise.resolved then
            if activeHandler then -- Check if handler is still active before trying to remove
                RemoveEventHandler('cnr:receiveMyInventory', activeHandler)
                activeHandler = nil -- Mark as cleaned up
            end
            if callback then
                -- Ensure callback is still valid if it was tied to the handler context (though less likely here)
                callback({ error = "Failed to get inventory: Timeout" })
            end
            Log("RequestInventoryForNUI timed out.", "warn")
        else
            -- If promise was resolved, but somehow timeout still runs, ensure activeHandler is nil
            if activeHandler then
                 -- This case should ideally not be hit if promise.resolved = true means originalHandleReceiveMyInventory ran.
                 -- However, to be absolutely safe and prevent future issues if logic changes:
                Log("RequestInventoryForNUI: Promise resolved but timeout ran with activeHandler still set. Cleaning up.", "warn")
                RemoveEventHandler('cnr:receiveMyInventory', activeHandler)
                activeHandler = nil
            end
        end
    end)
end

function GetLocalInventory()
    return localPlayerInventory
end

Log("Custom Inventory System (client-side) loaded.")

-- Global diagnostic handler for cnr:receiveMyInventory
-- AddEventHandler('cnr:receiveMyInventory', function(diag_data)
--     print("[CNR_DIAGNOSTIC_PRINT] GLOBAL_HANDLER for cnr:receiveMyInventory received data: " .. (json.encode and json.encode(diag_data) or "RAW_DATA_RECEIVED_BY_GLOBAL_HANDLER"))
--     -- Optionally, try to send a simple NUI message to see if NUI is responsive from this context
--     -- SendNUIMessage({ action = 'globalHandlerDebug', payload = diag_data })
-- end)
