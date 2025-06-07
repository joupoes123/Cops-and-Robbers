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

-- Robust version of RequestInventoryForNUI with activeHandler and promise
function RequestInventoryForNUI(callbackNUI)
    local promise = {}
    local activeHandler = nil

    local function originalHandleReceiveMyInventory(inventoryData)
        if activeHandler then
            RemoveEventHandler('cnr:receiveMyInventory', activeHandler)
            activeHandler = nil
        end
        localPlayerInventory = inventoryData or {}
        if callbackNUI then
            callbackNUI(localPlayerInventory)
        end
        promise.resolved = true
        Log("Inventory received from server for NUI and processed by originalHandleReceiveMyInventory.")
    end

    activeHandler = originalHandleReceiveMyInventory
    AddEventHandler('cnr:receiveMyInventory', activeHandler)
    Log("RequestInventoryForNUI: Added cnr:receiveMyInventory handler (originalHandleReceiveMyInventory).", "debug")

    TriggerServerEvent('cnr:requestMyInventory')
    Log("Requested inventory from server for NUI.")

    SetTimeout(5000, function()
        if not promise.resolved then
            if activeHandler then
                RemoveEventHandler('cnr:receiveMyInventory', activeHandler)
                activeHandler = nil
                Log("RequestInventoryForNUI: Timeout occurred, removed cnr:receiveMyInventory handler (originalHandleReceiveMyInventory).", "warn")
            end
            if callbackNUI then
                callbackNUI({ error = "Failed to get inventory: Timeout" })
            end
            Log("RequestInventoryForNUI timed out, error callback sent to NUI.", "warn")
        else
            -- This case (promise resolved but timeout still runs and activeHandler is somehow still set) should be rare.
            if activeHandler then
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
AddEventHandler('cnr:receiveMyInventory', function(diag_data)
    print("[CNR_DIAGNOSTIC_PRINT] GLOBAL_HANDLER for cnr:receiveMyInventory received data: " .. (json.encode and json.encode(diag_data) or "RAW_DATA_RECEIVED_BY_GLOBAL_HANDLER"))
    -- Optionally, try to send a simple NUI message to see if NUI is responsive from this context
    -- SendNUIMessage({ action = 'globalHandlerDebug', payload = diag_data })
end)