-- .luacheckrc (v2)

-- A more complete list of global variables that Luacheck should recognize.
globals = {
  -- FiveM / CitizenFX Natives
  "Citizen", "CreateThread", "Wait", "vector3", "vector4", "GetHashKey",
  "RegisterCommand", "RegisterNetEvent", "RegisterServerEvent", "AddEventHandler",
  "TriggerEvent", "TriggerServerEvent", "TriggerClientEvent",
  "GetPlayerName", "GetPlayerPed", "PlayerPedId", "GetPlayerIdentifier", "GetPlayerIdentifiers", "GetPlayers", "GetPlayerWantedLevel", "SetPlayerWantedLevel", "SetPlayerWantedLevelNow",
  "GetEntityCoords", "SetEntityCoords", "GetEntityModel", "DoesEntityExist", "SetEntityAsMissionEntity", "DeleteEntity", "FreezeEntityPosition", "GetEntityHealth", "SetEntityInvincible",
  "RequestModel", "HasModelLoaded", "SetPlayerModel", "PlayerId", "SetModelAsNoLongerNeeded", "RemoveAllPedWeapons", "GiveWeaponToPed", "HasWeaponAssetLoaded", "RequestWeaponAsset",
  "LoadResourceFile", "SaveResourceFile", "GetCurrentResourceName", "GetResourcePath",
  "SendNUIMessage", "RegisterNUICallback", "SetNuiFocus", "exports", "source", "json", "msgpack",
  "GetGameTimer", "IsDuplicityVersion", "tablelength", "IsPlayerAceAllowed", "DropPlayer",

  -- Your Custom Functions (from safe_utils.lua and others)
  "SafeGetPlayerName",
  "SafeTriggerClientEvent",
  "GetSafePlayerIdentifiers",
  "IsPlayerAdmin",
  "Log",

  -- Game-specific functions from your code
  "GetCnrPlayerData",
  "SaveCnrPlayerData",
  "SendToJail",
  "ForceReleasePlayerFromJail",
  "jail", -- This seems to be a global table or variable
  "shallowcopy",
  "ApplyPerks",
  "AddItemToPlayerInventory",
  "RemoveItemFromPlayerInventory",
  "AddPlayerMoney",
  "RemovePlayerMoney",
  "AddPlayerXP"
}

-- Allow these global tables to be created and modified by your scripts.
new_globals = {
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
  "copsOnDuty",
  "robbersActive",
  "completedTransactions"
}

-- A list of warning codes to ignore.
-- 212: Unused argument in a function.
-- 213: Unused loop variable.
-- 421: Unused upvalue.
-- 113: Setting a read-only global variable (for Config table).
ignore = {
  "212",
  "213",
  "421",
  "113"
}

-- Set a more reasonable line length limit.
max_line_length = 360