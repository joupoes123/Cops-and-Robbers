-- Luacheck configuration for FiveM Cops and Robbers resource
std = 'lua53'
globals = {
    -- FiveM globals
    'GetHashKey', 'GetPlayerName', 'GetPlayerPed', 'GetPlayerServerId',
    'TriggerEvent', 'TriggerClientEvent', 'TriggerServerEvent',
    'RegisterNetEvent', 'AddEventHandler', 'RegisterCommand',
    'GetGameTimer', 'Citizen', 'IsDuplicityVersion',
    'SendNUIMessage', 'SetNuiFocus', 'json',
    -- Resource globals
    'Config', 'Constants', 'Log', 'Validation', 'SecurityEnhancements',
    'DataManager', 'MemoryManager', 'PlayerManager', 'SecureInventory',
    'SecureTransactions', 'PerformanceTest', 'SecurityTest', 'SystemTest'
}
ignore = {
    '212', -- Unused argument
    '213', -- Unused loop variable
    '631'  -- Line is too long
}
