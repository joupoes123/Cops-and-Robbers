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
    local activeHandler = nil
    local handlerExecuted = false

    local function originalHandleReceiveMyInventory(inventoryData)
        if handlerExecuted then return end
        handlerExecuted = true

        if activeHandler then
            RemoveEventHandler(activeHandler)
            activeHandler = nil
        end

        localPlayerInventory = inventoryData or {}
        if callback then
            callback(localPlayerInventory)
        end
        promise.resolved = true
    end

    activeHandler = AddEventHandler('cnr:receiveMyInventory', originalHandleReceiveMyInventory)

    TriggerServerEvent('cnr:requestMyInventory')
    Log("Requested inventory from server for NUI.")

    SetTimeout(5000, function()
        if not promise.resolved then
            if activeHandler and not handlerExecuted then
                RemoveEventHandler(activeHandler)
                activeHandler = nil
            end
            if callback and not handlerExecuted then
                callback({ error = "Failed to get inventory: Timeout" })
            end
            if not handlerExecuted then
                Log("RequestInventoryForNUI timed out.", "warn")
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
