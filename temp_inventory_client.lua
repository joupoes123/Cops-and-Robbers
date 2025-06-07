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

-- Simplified version of RequestInventoryForNUI
function RequestInventoryForNUI(callbackNUI) -- Renamed callback for clarity
    local handlerWasCalled = false
    local eventHandler = nil -- Store the handler reference

    -- Define the event handling function
    local function receiveInventoryHandler(inventoryData)
        if handlerWasCalled then
            Log("RequestInventoryForNUI: receiveInventoryHandler called but handlerWasCalled is true. Skipping.", "debug")
            return
        end
        handlerWasCalled = true

        -- Attempt to remove the event handler using its reference
        if eventHandler then
            RemoveEventHandler(eventHandler)
            Log("RequestInventoryForNUI: Removed cnr:receiveMyInventory handler after successful receive.", "debug")
            eventHandler = nil -- Clear the reference
        else
            Log("RequestInventoryForNUI: eventHandler reference was nil upon successful receive. Cannot remove.", "warn")
        end

        localPlayerInventory = inventoryData or {} -- Assuming localPlayerInventory is defined globally or up-scoped
        if callbackNUI then
            callbackNUI(localPlayerInventory)
        end
        Log("Inventory received from server for NUI and processed.")
    end

    -- Register the event handler and store its reference
    -- Important: The event name here must match what the server triggers.
    eventHandler = AddEventHandler('cnr:receiveMyInventory', receiveInventoryHandler)
    Log("RequestInventoryForNUI: Added cnr:receiveMyInventory handler.", "debug")

    TriggerServerEvent('cnr:requestMyInventory')
    Log("Requested inventory from server for NUI.")

    -- Timeout logic
    SetTimeout(5000, function()
        if handlerWasCalled then
            Log("RequestInventoryForNUI: Timeout function ran, but handlerWasCalled is true. Skipping timeout logic.", "debug")
            return
        end
        handlerWasCalled = true -- Mark as called to prevent the main handler if it arrives late

        if eventHandler then
            RemoveEventHandler(eventHandler)
            Log("RequestInventoryForNUI: Timeout occurred, removed cnr:receiveMyInventory handler.", "warn")
            eventHandler = nil -- Clear the reference
        else
            Log("RequestInventoryForNUI: Timeout occurred, but eventHandler reference was already nil. Cannot remove.", "warn")
        end

        if callbackNUI then
            callbackNUI({ error = "Failed to get inventory: Timeout" })
        end
        Log("RequestInventoryForNUI timed out, error callback sent to NUI.", "warn")
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
