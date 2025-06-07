AddEventHandler('cnr:requestMyInventory', function()
    local src = tonumber(source)

    print("[CNR_DIAGNOSTIC_PRINT] Entered cnr:requestMyInventory handler for player " .. src)

    local testInventory = {
        ["test_item1"] = {
            itemId = "test_item1",
            name = "Test Wrench",
            count = 1,
            sellPrice = 15
        },
        ["test_item2"] = {
            itemId = "test_item2",
            name = "Test Donut",
            count = 5,
            sellPrice = 3
        }
    }

    print(string.format("[CNR_DIAGNOSTIC_PRINT] Sending hardcoded testInventory to player %s: %s", src, json.encode(testInventory))) -- Assuming json.encode is available for logging

    TriggerClientEvent('cnr:receiveMyInventory', src, testInventory)
end)
