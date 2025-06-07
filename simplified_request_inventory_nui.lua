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
