AddEventHandler('cnr:requestMyInventory', function()
    local src = tonumber(source)
    local pData = GetCnrPlayerData(src)
    if pData and pData.inventory then
        -- Before sending, transform inventory for NUI if needed, especially for sell prices
        local nuiInventory = {}
        for itemId, itemData in pairs(pData.inventory) do
            local itemConfig = nil
            for _, cfgItem in ipairs(Config.Items) do -- Assuming Config.Items is accessible
                if cfgItem.itemId == itemId then
                    itemConfig = cfgItem
                    break
                end
            end

            if itemConfig then
                local sellPriceFactor = (Config.DynamicEconomy and Config.DynamicEconomy.sellPriceFactor) or 0.5
                local currentMarketPrice = CalculateDynamicPrice(itemId, itemConfig.basePrice or 0) -- Assuming CalculateDynamicPrice is accessible
                local sellPrice = math.floor(currentMarketPrice * sellPriceFactor)

                nuiInventory[itemId] = {
                    itemId = tostring(itemId),
                    name = tostring(itemData.name or itemConfig.name or "Unknown Item"), -- Ensure string
                    count = tonumber(itemData.count or 0), -- Ensure number
                    sellPrice = tonumber(sellPrice or 0) -- Ensure number
                    -- category field removed
                    -- DO NOT add itemConfig directly or other potentially complex fields
                }
            else
                 -- Log if an item in player inventory doesn't have a matching config in Config.Items
                 Log(string.format("[CNR_SERVER_INVENTORY] Warning: Item %s in player %s inventory not found in Config.Items. It will not be sent to NUI.", tostring(itemId), src), "warn")
            end
        end

        Log(string.format("[CNR_SERVER_INVENTORY] Player %s raw inventory item count before NUI processing: %d", src, tablelength(pData.inventory)), "info") -- Assuming tablelength is accessible
        Log(string.format("[CNR_SERVER_INVENTORY] Player %s NUI-formatted inventory item count before truncation: %d", src, tablelength(nuiInventory)), "info")

        local maxItemsToSend = 30 -- Test limit
        local originalItemCount = tablelength(nuiInventory)
        local finalNuiInventory = nuiInventory -- Use by default

        if originalItemCount > maxItemsToSend then
            Log(string.format("[CNR_SERVER_INVENTORY] Player %s NUI inventory count (%d) exceeds test limit (%d). Truncating.", src, originalItemCount, maxItemsToSend), "warn")
            local truncatedInventory = {}
            local count = 0
            -- Iterate over the original nuiInventory to maintain its structure
            for k, v in pairs(nuiInventory) do
                if count >= maxItemsToSend then
                    break
                end
                truncatedInventory[k] = v
                count = count + 1
            end
            finalNuiInventory = truncatedInventory -- This is what will be sent and logged
            Log(string.format("[CNR_SERVER_INVENTORY] Player %s NUI inventory truncated to %d items.", src, tablelength(finalNuiInventory)), "info")
        end

        local sampleCount = 0
        local nuiInventorySampleForLog = {}
        for k, v in pairs(finalNuiInventory) do
            if sampleCount < 5 then -- Log details for up to 5 items
                nuiInventorySampleForLog[k] = v
                sampleCount = sampleCount + 1
            else
                break
            end
        end
        Log(string.format("[CNR_SERVER_INVENTORY] Inventory sample being sent to player %s: %s", src, json.encode(nuiInventorySampleForLog)), "info") -- Assuming json.encode is accessible

        -- Attempt to encode the full inventory for logging its size and checking for errors
        local success, resultOrError = pcall(json.encode, finalNuiInventory)
        if not success then
            Log(string.format("[CNR_SERVER_INVENTORY] CRITICAL: Failed to json.encode full finalNuiInventory for player %s for logging purposes. Error: %s", src, tostring(resultOrError)), "error")
            -- Note: We still attempt to send finalNuiInventory below as the error might be specific to encoding certain complex structures
            -- that are fine for network transport but not for json.encode, or vice-versa.
            -- Or, the NUI data itself might be problematic.
        else
            local actualEncodedInventoryString = resultOrError
            Log(string.format("[CNR_SERVER_INVENTORY] Successfully json.encoded full finalNuiInventory for player %s for logging. Approx size: %d bytes.", src, string.len(actualEncodedInventoryString)), "info")
            if string.len(actualEncodedInventoryString) > 60000 then -- Log warning if potentially too large for network event
                 Log(string.format("[CNR_SERVER_INVENTORY] WARNING: Encoded finalNuiInventory for player %s is large (%d bytes). This might exceed network event limits if not handled carefully by FiveM.", src, string.len(actualEncodedInventoryString)), "warn")
            end
        end

        -- This sends the raw lua table 'finalNuiInventory', FiveM handles its own serialization for events.
        TriggerClientEvent('cnr:receiveMyInventory', src, finalNuiInventory)
    else
        Log(string.format("[CNR_SERVER_INVENTORY] No inventory data found for player %s or pData is nil. Sending empty inventory.", src), "info")
        TriggerClientEvent('cnr:receiveMyInventory', src, {}) -- Send empty if no inventory
    end
end)
