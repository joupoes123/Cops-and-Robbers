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
    local handlerExecuted = false -- New flag

    -- Define the actual handler function
    local function originalHandleReceiveMyInventory(inventoryData)
        if handlerExecuted then return end -- Prevent re-entry
        handlerExecuted = true -- Mark as executed

        -- if activeHandler then -- Check if handler is still active -- No longer needed to check activeHandler for removal
        activeHandler = nil -- Mark as inactive/cleaned up by clearing our reference
        -- end
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
            if activeHandler and not handlerExecuted then -- Check flag here too
                -- RemoveEventHandler('cnr:receiveMyInventory', activeHandler) -- Removed
                activeHandler = nil -- Mark as cleaned up
            end
            if callback and not handlerExecuted then -- Only call error callback if main logic didn't run
                -- Ensure callback is still valid if it was tied to the handler context (though less likely here)
                callback({ error = "Failed to get inventory: Timeout" })
            end
            if not handlerExecuted then -- Only log timeout if main logic didn't run
                Log("RequestInventoryForNUI timed out.", "warn")
            end
        else
            -- If promise was resolved (meaning originalHandleReceiveMyInventory ran and set handlerExecuted to true)
            -- but timeout still runs, activeHandler might have already been set to nil.
            -- The original logic here for cleanup if activeHandler is still set is probably fine,
            -- as handlerExecuted would be true.
            if activeHandler then
                 -- This case should ideally not be hit if promise.resolved = true means originalHandleReceiveMyInventory ran.
                 -- However, to be absolutely safe and prevent future issues if logic changes:
                Log("RequestInventoryForNUI: Promise resolved but timeout ran with activeHandler still set. Cleaning up.", "warn")
                -- RemoveEventHandler('cnr:receiveMyInventory', activeHandler) -- Removed
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
