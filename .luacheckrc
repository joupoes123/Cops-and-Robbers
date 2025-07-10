-- .luacheckrc (v3 - Final)

-- Final, more complete list of globals.
globals = {
  -- FiveM / CitizenFX Natives
  "Citizen", "CreateThread", "Wait", "vector3", "vector4", "GetHashKey",
  "RegisterCommand", "RegisterNetEvent", "RegisterServerEvent", "AddEventHandler",
  "TriggerEvent", "TriggerServerEvent", "TriggerClientEvent", "SetTimeout",
  "GetPlayerName", "GetPlayerPed", "PlayerPedId", "GetPlayerIdentifier", "GetPlayerIdentifiers", "GetPlayers",
  "GetPlayerWantedLevel", "SetPlayerWantedLevel", "SetPlayerWantedLevelNow", "GetPlayerLevel",
  "GetEntityCoords", "SetEntityCoords", "GetEntityModel", "DoesEntityExist", "SetEntityAsMissionEntity", "DeleteEntity", "FreezeEntityPosition", "GetEntityHealth", "SetEntityInvincible",
  "RequestModel", "HasModelLoaded", "SetPlayerModel", "PlayerId", "SetModelAsNoLongerNeeded", "RemoveAllPedWeapons", "GiveWeaponToPed", "HasWeaponAssetLoaded", "RequestWeaponAsset",
  "LoadResourceFile", "SaveResourceFile", "GetCurrentResourceName", "GetResourcePath",
  "SendNUIMessage", "RegisterNUICallback", "SetNuiFocus", "exports", "source", "json", "msgpack",
  "GetGameTimer", "IsDuplicityVersion", "tablelength", "IsPlayerAceAllowed", "DropPlayer",

  -- Your Custom Functions
  "SafeGetPlayerName", "SafeTriggerClientEvent", "GetSafePlayerIdentifiers", "IsPlayerAdmin", "Log",
  "GetCnrPlayerData", "SaveCnrPlayerData", "SendToJail", "ForceReleasePlayerFromJail", "jail",
  "shallowcopy", "ApplyPerks", "AddItemToPlayerInventory", "RemoveItemFromPlayerInventory", "AddPlayerMoney",
  "RemovePlayerMoney", "AddPlayerXP", "GetPlayerLicense", "CanCarryItem", "AddItem", "RemoveItem", "GetInventory",
  "HasItem", "AwardXP", "GetPlayerPerk", "TriggerAbilityEffect", "GetItemImagePath", "SafeSendNUIMessage",
  "InitializePlayerInventory", "InitializeBankAccount", "GetBankAccount", "LoadPlayerCharacters", "SavePlayerCharacters",
  "ValidateCharacterData", "SanitizeCharacterData", "GetPlayerCharacterSlots", "SavePlayerCharacterSlot", "DeletePlayerCharacterSlot",
  "ApplyCharacterToPlayer", "GetCharacterForRoleSelection", "HasCharacterForRole"
}

-- Allow these global tables to be created and modified by your scripts.
new_globals = {
  "Config", "Constants", "DataManager", "IntegrationManager", "MemoryManager",
  "PerformanceOptimizer", "PerformanceTest", "PlayerManager", "SecurityEnhancements",
  "SecurityTest", "SecureInventory", "SecureTransactions", "Validation",
  "copsOnDuty", "robbersActive", "completedTransactions", "rateLimitData"
}

-- A list of warning codes to ignore.
-- 631: Line contains only whitespace.
-- 212: Unused argument in a function.
-- 213: Unused loop variable.
-- 421: Unused upvalue.
-- 113: Setting a read-only global (for Config table).
ignore = {
  "631", "212", "213", "421", "113"
}

-- Set a more reasonable line length limit.
max_line_length = 160