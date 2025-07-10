-- .luacheckrc configuration file

-- A list of global variables that Luacheck should recognize.
-- This includes common FiveM natives and functions from your other files.
globals = {
  -- FiveM / CitizenFX Natives
  "Citizen", "CreateThread", "Wait", "vector3", "vector4",
  "RegisterCommand", "RegisterNetEvent", "AddEventHandler", "TriggerEvent", "TriggerServerEvent", "TriggerClientEvent",
  "GetPlayerName", "GetPlayerPed", "PlayerPedId", "GetPlayerIdentifier", "GetPlayerIdentifiers", "GetPlayers",
  "GetEntityCoords", "SetEntityCoords", "GetEntityModel", "DoesEntityExist", "SetEntityAsMissionEntity",
  "GetHashKey", "RequestModel", "HasModelLoaded", "SetPlayerModel", "PlayerId", "SetModelAsNoLongerNeeded",
  "GiveWeaponToPed", "HasWeaponAssetLoaded", "RequestWeaponAsset",
  "LoadResourceFile", "SaveResourceFile", "GetCurrentResourceName", "GetResourcePath",
  "SendNUIMessage", "RegisterNUICallback", "SetNuiFocus", "exports", "source", "json",

  -- Your own global tables
  "Config",
  "Constants",
  "DataManager",
  "IntegrationManager",
  "MemoryManager",
  "PerformanceOptimizer",
  "PerformanceTest",
  "PlayerManager",
  "SecurityEnhancements",
  "SecurityTest",
  "SecureInventory",
  "SecureTransactions",
  "Validation"
}

-- Allow scripts to define new global functions and read from the globals list above.
-- This is useful for modular code where one file defines a function that another uses.
read_globals = {
  "Config",
  "Constants",
  "DataManager",
  "IntegrationManager",
  "MemoryManager",
  "PerformanceOptimizer",
  "PerformanceTest",
  "PlayerManager",
  "SecurityEnhancements",
  "SecurityTest",
  "SecureInventory",
  "SecureTransactions",
  "Validation",
  "Log" -- Assuming 'Log' is a custom global function you've defined for logging
}

-- A list of warning codes to ignore. You can customize this list.
-- 212: Unused argument in a function. (Common for event handlers)
-- 213: Unused loop variable.
-- 421: Unused upvalue.
ignore = {
  "212",
  "213",
  "421"
}

-- You can optionally set a new line length limit. 160 is often more reasonable.
max_line_length = 360