-- client.lua
-- Cops & Robbers FiveM Game Mode - Client Script
-- Version: 1.2 | Date: <current date>
-- Ped readiness flag and guards implemented.

-- _G.cnrSetDispatchServiceErrorLogged = false -- Removed as part of subtask
local g_isPlayerPedReady = false

-- =====================================
--           HELPER FUNCTIONS
-- =====================================

-- Define Log function for consistent logging across client
local function Log(message, level)
    level = level or "info"
    -- Check if Config and Config.DebugLogging are available
    if Config and Config.DebugLogging then
        if level == "error" then print("[CNR_CLIENT_ERROR] " .. message)
        elseif level == "warn" then print("[CNR_CLIENT_WARN] " .. message)
        else print("[CNR_CLIENT_INFO] " .. message) end
    elseif level == "error" or level == "warn" then -- Always print errors/warnings if DebugLogging is off/Config unavailable
        print("[CNR_CLIENT_CRITICAL] [" .. string.upper(level) .. "] " .. message)
    end
end

-- =====================================
--           CONFIGURATION
-- =====================================

-- Config is loaded from shared_scripts 'config.lua'

-- =====================================
--           VARIABLES
-- =====================================

-- Player-related variables
local role = nil
local playerCash = 0
local currentSpikeStrips = {}
local spikeStripModelHash = GetHashKey("p_ld_stinger_s")
local playerStats = {
    heists = 0,
    arrests = 0,
    rewards = 0
}
local currentObjective = nil
local playerWeapons = {}
local playerAmmo = {}

-- Player Data (Synced from Server)
local playerData = {
    xp = 0,
    level = 1,
    role = "citizen",
    perks = {},
    armorModifier = 1.0,
    money = 0
}

-- Wanted System Client State
local currentWantedStarsClient = 0
local currentWantedPointsClient = 0
local wantedUiLabel = ""

local xpForNextLevelDisplay = 0

-- Contraband Drop Client State
local activeDropBlips = {}
local clientActiveContrabandDrops = {}

-- Blip tracking
local copStoreBlips = {}
local robberStoreBlips = {}

-- Track protected peds to prevent NPC suppression from affecting them
local g_protectedPolicePeds = {}

-- Safe Zone Client State
local isCurrentlyInSafeZone = false
local currentSafeZoneName = ""

-- Wanted System Expansion Client State
local currentPlayerNPCResponseEntities = {}
local corruptOfficialNPCs = {}
local currentHelpTextTarget = nil -- Moved to top level for broader access

-- Contraband collection state
local isCollectingFromDrop = nil
local collectionTimerEnd = 0

-- Store UI state
local isCopStoreUiOpen = false
local isRobberStoreUiOpen = false

-- Patch: Exclude protected peds from police suppression
local function IsPedProtected(ped)
    return g_protectedPolicePeds[ped] == true
end

-- =========================
--   NPC POLICE SUPPRESSION
-- =========================

-- Helper: Safe call for SetDispatchServiceActive (for environments where it may not be defined)
local function SafeSetDispatchServiceActive(service, toggle)
    local hash = GetHashKey("SetDispatchServiceActive")
    if Citizen and Citizen.InvokeNative and hash then
        -- 0xDC0F817884CDD856 is the native hash for SetDispatchServiceActive
        local nativeHash = 0xDC0F817884CDD856
        local ok, err = pcall(function()
            Citizen.InvokeNative(nativeHash, service, toggle)
        end)
        if not ok then
            print("[CNR_CLIENT_WARN] SetDispatchServiceActive (InvokeNative) failed for service " .. tostring(service) .. ": " .. tostring(err))
        end
    else
        -- fallback: do nothing
    end
end

-- Utility: Check if a ped is an NPC cop (by model or relationship group)
local function IsPedNpcCop(ped)
    if not DoesEntityExist(ped) then return false end
    local model = GetEntityModel(ped)
    local relGroup = GetPedRelationshipGroupHash(ped)
    local copModels = {
        [GetHashKey("s_m_y_cop_01")] = true,
        [GetHashKey("s_f_y_cop_01")] = true,
        [GetHashKey("s_m_y_swat_01")] = true,
        [GetHashKey("s_m_y_hwaycop_01")] = true,
        [GetHashKey("s_m_y_sheriff_01")] = true,
        [GetHashKey("s_f_y_sheriff_01")] = true,
    }
    return (copModels[model] or relGroup == GetHashKey("COP")) and not IsPedAPlayer(ped)
end

-- Aggressive police NPC suppression: Removes police NPCs and their vehicles near players with a wanted level.
Citizen.CreateThread(function()
    local policeSuppressInterval = 500 -- ms
    print("[CNR_CLIENT_DEBUG] Aggressive Police NPC Suppression Thread Started. Interval: " .. policeSuppressInterval .. "ms")
    while true do
        Citizen.Wait(policeSuppressInterval)
        local playerPed = PlayerPedId()
        if not (playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed)) then goto continue_police_suppression end
        local handle, ped = FindFirstPed()
        local success, nextPed = true, ped
        repeat
            if DoesEntityExist(ped) and ped ~= playerPed and IsPedNpcCop(ped) and not IsPedProtected(ped) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                SetEntityAsMissionEntity(ped, false, true)
                ClearPedTasksImmediately(ped)
                DeletePed(ped)
                if vehicle ~= 0 and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
                    SetEntityAsMissionEntity(vehicle, false, true)
                    DeleteEntity(vehicle)
                end
            end
            success, nextPed = FindNextPed(handle)
            ped = nextPed
        until not success
        EndFindPed(handle)
        ::continue_police_suppression::
    end
end)

-- Prevent NPC police from responding to wanted levels (but keep wanted level for robbers)
Citizen.CreateThread(function()
    local interval = 1000
    while true do
        Citizen.Wait(interval)
        local playerId = PlayerId()
        local playerPed = PlayerPedId()
        if not (playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed)) then goto continue_police_ignore end
        SetPoliceIgnorePlayer(playerPed, true)
        for i = 1, 15 do
            SafeSetDispatchServiceActive(i, false)
        end
        if role == "cop" then
            if GetPlayerWantedLevel(playerId) > 0 then
                SetPlayerWantedLevel(playerId, 0, false)
                SetPlayerWantedLevelNow(playerId, false)
            end
        end
        ::continue_police_ignore::
    end
end)

-- Enhanced cop wanted level suppression
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if role == "cop" then
            local playerId = PlayerId()
            local currentWantedLevel = GetPlayerWantedLevel(playerId)
            
            if currentWantedLevel > 0 then
                print("[CNR_CLIENT_DEBUG] Suppressing wanted level for cop player")
                SetPlayerWantedLevel(playerId, 0, false)
                SetPlayerWantedLevelNow(playerId, false)
            end
            
            -- Ensure police blips are hidden for cop players
            SetPoliceIgnorePlayer(PlayerPedId(), true)
        end
    end
end)

-- =====================================
--           HELPER FUNCTIONS
-- =====================================

local function ShowNotification(text)
    if not text or text == "" then
        print("ShowNotification: Received nil or empty text.")
        return
    end
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawNotification(false, true)
end

local function DisplayHelpText(text)
    if not text or text == "" then
        print("DisplayHelpText: Received nil or empty text.")
        return
    end
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function spawnPlayer(playerRole)
    if not playerRole then
        print("Error: spawnPlayer called with nil role.")
        ShowNotification("~r~Error: Could not determine spawn point. Role not set.")
        return
    end
    local spawnPoint = Config.SpawnPoints[playerRole]
    if spawnPoint and spawnPoint.x and spawnPoint.y and spawnPoint.z then
        local playerPed = PlayerPedId()
        if playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed) then
            SetEntityCoords(playerPed, spawnPoint.x, spawnPoint.y, spawnPoint.z, false, false, false, true)
            ShowNotification("Spawned as " .. playerRole)
        else
            print("[CNR_CLIENT_WARN] spawnPlayer: playerPed invalid, cannot set coords.")
        end
    else
        print("Error: Invalid or missing spawn point for role: " .. tostring(playerRole))
        ShowNotification("~r~Error: Spawn point not found for your role.")
    end
end

local function ApplyRoleVisualsAndLoadout(newRole, oldRole)
    local playerPed = PlayerPedId()
    if not (playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed)) then
        print("[CNR_CLIENT_ERROR] ApplyRoleVisualsAndLoadout: Invalid playerPed.")
        return
    end
    print(string.format("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: newRole=%s, oldRole=%s", newRole, oldRole or "nil"))
    RemoveAllPedWeapons(playerPed, true)
    playerWeapons = {}
    playerAmmo = {}
    print("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: All weapons removed.")
    local modelToLoad = nil
    local modelHash = nil
    if newRole == "cop" then
        modelToLoad = "s_m_y_cop_01"
    elseif newRole == "robber" then
        modelToLoad = "a_m_m_farmer_01"
    else
        modelToLoad = "a_m_m_farmer_01"
    end
    modelHash = GetHashKey(modelToLoad)
    print(string.format("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: Attempting to load model: %s (Hash: %s)", modelToLoad, modelHash))
    if modelHash and modelHash ~= 0 and modelHash ~= -1 then
        RequestModel(modelHash)
        local attempts = 0
        while not HasModelLoaded(modelHash) and attempts < 100 do
            Citizen.Wait(50)
            attempts = attempts + 1
        end
        if HasModelLoaded(modelHash) then
            print(string.format("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: Model %s loaded. Setting player model.", modelToLoad))
            SetPlayerModel(PlayerId(), modelHash)
            Citizen.Wait(10)
            SetPedDefaultComponentVariation(playerPed)
            if modelToLoad == "mp_m_freemode_01" then
                print("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: Applying freemode component randomization for mp_m_freemode_01.")
                SetPedRandomComponentVariation(playerPed, 0)
            end
            SetModelAsNoLongerNeeded(modelHash)
        else
            print(string.format("[CNR_CLIENT_ERROR] ApplyRoleVisualsAndLoadout: Failed to load model %s after 100 attempts.", modelToLoad))
        end
    else
        print(string.format("[CNR_CLIENT_ERROR] ApplyRoleVisualsAndLoadout: Invalid model hash for %s.", modelToLoad))
    end
    Citizen.Wait(500)
    playerPed = PlayerPedId()
    if not (playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed)) then
        print("[CNR_CLIENT_ERROR] ApplyRoleVisualsAndLoadout: Invalid playerPed after model change attempt.")
        return
    end
    if newRole == "cop" then
        local taserHash = GetHashKey("weapon_stungun")
        GiveWeaponToPed(playerPed, taserHash, 5, false, true)
        playerWeapons["weapon_stungun"] = true; playerAmmo["weapon_stungun"] = 5
        print("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: Gave taser to cop.")
    elseif newRole == "robber" then
        local batHash = GetHashKey("weapon_bat")
        GiveWeaponToPed(playerPed, batHash, 1, false, true)
        playerWeapons["weapon_bat"] = true; playerAmmo["weapon_bat"] = 1
        print("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: Gave bat to robber.")
    end
    ShowNotification(string.format("~g~Role changed to %s. Model and basic loadout applied.", newRole))

   -- Equip weapons from inventory after role visuals and loadout are applied
   Citizen.Wait(50) -- Optional small delay to ensure ped model is fully set and previous weapons are processed.
   local currentResourceName = GetCurrentResourceName()
   if exports[currentResourceName] and exports[currentResourceName].EquipInventoryWeapons then
       print(string.format("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: Calling %s:EquipInventoryWeapons to restore owned weapons.", currentResourceName))
       exports[currentResourceName]:EquipInventoryWeapons()
   else
       print(string.format("[CNR_CLIENT_ERROR] ApplyRoleVisualsAndLoadout: Could not find export EquipInventoryWeapons in resource %s.", currentResourceName))
   end
end

-- Ensure SetWantedLevelForPlayerRole is defined before all uses
local function SetWantedLevelForPlayerRole(stars, points)
    local playerId = PlayerId()
    if role == 'cop' then
        SetPlayerWantedLevel(playerId, 0, false)
        SetPlayerWantedLevelNow(playerId, false)
    elseif role == 'robber' then
        SetPlayerWantedLevel(playerId, stars, false)
        SetPlayerWantedLevelNow(playerId, false)
    end
end

function UpdateCopStoreBlips()
    if not Config.NPCVendors then
        print("[CNR_CLIENT_WARN] UpdateCopStoreBlips: Config.NPCVendors not found.")
        return
    end
    if type(Config.NPCVendors) ~= "table" or (getmetatable(Config.NPCVendors) and getmetatable(Config.NPCVendors).__name == "Map") then
        print("[CNR_CLIENT_ERROR] UpdateCopStoreBlips: Config.NPCVendors is not an array. Cannot iterate.")
        return
    end
    for i, vendor in ipairs(Config.NPCVendors) do
        if vendor and vendor.location and vendor.name then
            local blipKey = tostring(vendor.location.x .. "_" .. vendor.location.y .. "_" .. vendor.location.z)
            if vendor.name == "Cop Store" then
                if role == "cop" then
                    if not copStoreBlips[blipKey] or not DoesBlipExist(copStoreBlips[blipKey]) then
                        local blip = AddBlipForCoord(vendor.location.x, vendor.location.y, vendor.location.z)
                        SetBlipSprite(blip, 60)
                        SetBlipColour(blip, 3)
                        SetBlipScale(blip, 0.8)
                        SetBlipAsShortRange(blip, true)
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentSubstringPlayerName(vendor.name)
                        EndTextCommandSetBlipName(blip)
                        copStoreBlips[blipKey] = blip
                        print(string.format("[CNR_CLIENT_DEBUG] Created blip for Cop Store '%s' at: %s", vendor.name, blipKey))
                    end
                else
                    if copStoreBlips[blipKey] and DoesBlipExist(copStoreBlips[blipKey]) then
                        RemoveBlip(copStoreBlips[blipKey])
                        copStoreBlips[blipKey] = nil
                        print(string.format("[CNR_CLIENT_DEBUG] Removed Cop Store blip for non-cop role at: %s", blipKey))
                    end
                end
            else
                if copStoreBlips[blipKey] and DoesBlipExist(copStoreBlips[blipKey]) then
                    print(string.format("[CNR_CLIENT_WARN] Removing stray blip from copStoreBlips, associated with a non-Cop Store: '%s' at %s", vendor.name, blipKey))
                    RemoveBlip(copStoreBlips[blipKey])
                    copStoreBlips[blipKey] = nil
                end
            end
        else
            print(string.format("[CNR_CLIENT_WARN] UpdateCopStoreBlips: Invalid vendor entry at index %d.", i))
        end
    end
    for blipKey, blipId in pairs(copStoreBlips) do
        local stillExistsAndIsCopStore = false
        if Config.NPCVendors and type(Config.NPCVendors) == "table" then
            for _, vendor in ipairs(Config.NPCVendors) do
                if vendor and vendor.location and vendor.name then
                    if tostring(vendor.location.x .. "_" .. vendor.location.y .. "_" .. vendor.location.z) == blipKey and vendor.name == "Cop Store" then
                        stillExistsAndIsCopStore = true
                        break
                    end
                end
            end
        end
        if not stillExistsAndIsCopStore then
            if blipId and DoesBlipExist(blipId) then
                RemoveBlip(blipId)
            end
            copStoreBlips[blipKey] = nil
            print(string.format("[CNR_CLIENT_DEBUG] Cleaned up orphaned/renamed Cop Store blip for key: %s", blipKey))
        end
    end
    print("[CNR_CLIENT_DEBUG] UpdateCopStoreBlips finished. Current copStoreBlips count: " .. tablelength(copStoreBlips))
end

-- Update Robber Store Blips (visible only to robbers)
function UpdateRobberStoreBlips()
    if not Config.NPCVendors then
        print("[CNR_CLIENT_WARN] UpdateRobberStoreBlips: Config.NPCVendors not found.")
        return
    end
    if type(Config.NPCVendors) ~= "table" or (getmetatable(Config.NPCVendors) and getmetatable(Config.NPCVendors).__name == "Map") then
        print("[CNR_CLIENT_ERROR] UpdateRobberStoreBlips: Config.NPCVendors is not an array. Cannot iterate.")
        return
    end
    for i, vendor in ipairs(Config.NPCVendors) do
        if vendor and vendor.location and vendor.name and (vendor.name == "Black Market Dealer" or vendor.name == "Gang Supplier") then
            local blipKey = tostring(vendor.location.x .. "_" .. vendor.location.y .. "_" .. vendor.location.z)
            if vendor.name == "Black Market Dealer" or vendor.name == "Gang Supplier" then
                if not robberStoreBlips[blipKey] or not DoesBlipExist(robberStoreBlips[blipKey]) then
                    local blip = AddBlipForCoord(vendor.location.x, vendor.location.y, vendor.location.z)
                    if vendor.name == "Black Market Dealer" then
                        SetBlipSprite(blip, 266) -- Gun store icon
                        SetBlipColour(blip, 1) -- Red
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString("Black Market")
                        EndTextCommandSetBlipName(blip)
                    else -- Gang Supplier
                        SetBlipSprite(blip, 267) -- Ammu-nation icon
                        SetBlipColour(blip, 5) -- Yellow
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString("Gang Supplier")
                        EndTextCommandSetBlipName(blip)
                    end
                    SetBlipScale(blip, 0.8)
                    SetBlipAsShortRange(blip, true)
                    robberStoreBlips[blipKey] = blip
                    print(string.format("[CNR_CLIENT_DEBUG] Created robber store blip for '%s' at %s", vendor.name, tostring(vendor.location)))
                end
            else
                if robberStoreBlips[blipKey] and DoesBlipExist(robberStoreBlips[blipKey]) then
                    print(string.format("[CNR_CLIENT_WARN] Removing stray blip from robberStoreBlips, associated with a non-Robber Store: '%s' at %s", vendor.name, blipKey))
                    RemoveBlip(robberStoreBlips[blipKey])
                    robberStoreBlips[blipKey] = nil
                end
            end
        else
            print(string.format("[CNR_CLIENT_WARN] UpdateRobberStoreBlips: Invalid vendor entry at index %d.", i))
        end
    end
    -- Clean up orphaned blips
    for blipKey, blipId in pairs(robberStoreBlips) do
        local stillExistsAndIsRobberStore = false
        if Config.NPCVendors and type(Config.NPCVendors) == "table" then
            for _, vendor in ipairs(Config.NPCVendors) do
                if vendor and vendor.location and vendor.name then
                    if tostring(vendor.location.x .. "_" .. vendor.location.y .. "_" .. vendor.location.z) == blipKey and (vendor.name == "Black Market Dealer" or vendor.name == "Gang Supplier") then
                        stillExistsAndIsRobberStore = true
                        break
                    end
                end
            end
        end
        if not stillExistsAndIsRobberStore then
            if blipId and DoesBlipExist(blipId) then
                RemoveBlip(blipId)
            end
            robberStoreBlips[blipKey] = nil
            print(string.format("[CNR_CLIENT_DEBUG] Cleaned up orphaned/renamed Robber Store blip for key: %s", blipKey))
        end
    end
    print("[CNR_CLIENT_DEBUG] UpdateRobberStoreBlips finished. Current robberStoreBlips count: " .. tablelength(robberStoreBlips))
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Helper to spawn the Cop Store ped and protect it from suppression
function SpawnCopStorePed()
    local vendor = nil
    if Config and Config.NPCVendors then
        for _, v in ipairs(Config.NPCVendors) do
            if v.name == "Cop Store" then vendor = v; break end
        end
    end
    if not vendor then print("[CNR_CLIENT_ERROR] Cop Store vendor not found in Config.NPCVendors"); return end
    local model = GetHashKey("s_m_m_ciasec_01") -- Use a unique cop-like model not used by NPC police
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(10) end
    local ped = CreatePed(4, model, vendor.location.x, vendor.location.y, vendor.location.z - 1.0, vendor.heading or 0.0, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false) -- Corrected: use boolean false
    SetPedCombatAttributes(ped, 17, true) -- Corrected: use boolean true
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    g_protectedPolicePeds[ped] = true
    print("[CNR_CLIENT_DEBUG] Spawned and protected Cop Store ped at PD.")
end

-- Helper to spawn Robber Store peds and protect them from suppression
function SpawnRobberStorePeds()
    if not Config or not Config.NPCVendors then
        print("[CNR_CLIENT_ERROR] SpawnRobberStorePeds: Config.NPCVendors not found")
        return
    end
    
    for _, vendor in ipairs(Config.NPCVendors) do
        if vendor.name == "Black Market Dealer" or vendor.name == "Gang Supplier" then
            local modelHash = GetHashKey(vendor.model or "s_m_y_dealer_01")
            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do 
                Citizen.Wait(10) 
            end
            
            local ped = CreatePed(4, modelHash, vendor.location.x, vendor.location.y, vendor.location.z - 1.0, vendor.heading or 0.0, false, true)
            SetEntityAsMissionEntity(ped, true, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedFleeAttributes(ped, 0, false)
            SetPedCombatAttributes(ped, 17, true)
            SetPedCanRagdoll(ped, false)
            SetPedDiesWhenInjured(ped, false)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            
            -- Add to protected peds to prevent deletion by NPC suppression
            g_protectedPolicePeds[ped] = true
            
            print(string.format("[CNR_CLIENT_DEBUG] Spawned and protected %s ped at %s", vendor.name, tostring(vendor.location)))
        end
    end
end

-- Call this on resource start and when player spawns
Citizen.CreateThread(function()
    Citizen.Wait(2000)
    SpawnCopStorePed()
    SpawnRobberStorePeds()
    -- Initial blip setup based on current role
    if role == "cop" then
        UpdateCopStoreBlips()
    elseif role == "robber" then
        UpdateRobberStoreBlips()
    end
end)

-- =====================================
--           NETWORK EVENTS
-- =====================================

AddEventHandler('playerSpawned', function()
    TriggerServerEvent('cnr:playerSpawned') -- Corrected event name
    
    -- Only show role selection if player doesn't have a role yet
    if not role or role == "" then
        SendNUIMessage({ action = 'showRoleSelection', resourceName = GetCurrentResourceName() })
        SetNuiFocus(true, true) -- Ensure mouse pointer appears for role selection
    else
        -- Player already has a role, respawn them at their role's spawn point
        local spawnPoint = Config.SpawnPoints[role]
        if spawnPoint then
            local playerPed = PlayerPedId()
            SetEntityCoords(playerPed, spawnPoint.x, spawnPoint.y, spawnPoint.z, false, false, false, true)
            if role == "cop" then
                SetEntityHeading(playerPed, 270.0)
            elseif role == "robber" then
                SetEntityHeading(playerPed, 180.0)
            end
            ShowNotification("Respawned as " .. role)
            -- Reapply role visuals and loadout
            ApplyRoleVisualsAndLoadout(role, nil)
        end
    end
end)

RegisterNetEvent('cnr:updatePlayerData')
AddEventHandler('cnr:updatePlayerData', function(newPlayerData)
    print(string.format("[CNR_CLIENT_DEBUG] Received cnr:updatePlayerData. Current client role: %s, New role from server: %s, Money: %s, XP: %s, Level: %s", role or "nil", newPlayerData and newPlayerData.role or "nil", newPlayerData and newPlayerData.money or "nil", newPlayerData and newPlayerData.xp or "nil", newPlayerData and newPlayerData.level or "nil"))
    if not newPlayerData then
        print("Error: 'cnr:updatePlayerData' received nil data.")
        ShowNotification("~r~Error: Failed to load player data.")
        return
    end
    local oldRole = playerData.role
    playerData = newPlayerData
    playerCash = newPlayerData.money or 0
    role = playerData.role
    local playerPedOnUpdate = PlayerPedId()
    -- Inventory is now handled by cnr:syncInventory event

    -- Update blips based on role
    if role == "cop" then
        UpdateCopStoreBlips()
        -- Clear robber store blips for cops
        for blipKey, blipId in pairs(robberStoreBlips) do
            if blipId and DoesBlipExist(blipId) then
                RemoveBlip(blipId)
            end
            robberStoreBlips[blipKey] = nil
        end
    elseif role == "robber" then
        UpdateRobberStoreBlips()
        -- Clear cop store blips for robbers
        for blipKey, blipId in pairs(copStoreBlips) do
            if blipId and DoesBlipExist(blipId) then
                RemoveBlip(blipId)
            end
            copStoreBlips[blipKey] = nil
        end
    else
        -- Clear all store blips for citizens
        for blipKey, blipId in pairs(copStoreBlips) do
            if blipId and DoesBlipExist(blipId) then
                RemoveBlip(blipId)
            end
            copStoreBlips[blipKey] = nil
        end
        for blipKey, blipId in pairs(robberStoreBlips) do
            if blipId and DoesBlipExist(blipId) then
                RemoveBlip(blipId)
            end
            robberStoreBlips[blipKey] = nil
        end
    end

    if role and oldRole ~= role then
        if playerPedOnUpdate and playerPedOnUpdate ~= 0 and playerPedOnUpdate ~= -1 and DoesEntityExist(playerPedOnUpdate) then
            ApplyRoleVisualsAndLoadout(role, oldRole)
            Citizen.Wait(100)
            spawnPlayer(role)
        else
            print("[CNR_CLIENT_WARN] cnr:updatePlayerData: playerPed invalid during role change spawn.")
        end
    elseif not oldRole and role and role ~= "citizen" then
        if playerPedOnUpdate and playerPedOnUpdate ~= 0 and playerPedOnUpdate ~= -1 and DoesEntityExist(playerPedOnUpdate) then
            ApplyRoleVisualsAndLoadout(role, oldRole)
            Citizen.Wait(100)
            spawnPlayer(role)
        else
            print("[CNR_CLIENT_WARN] cnr:updatePlayerData: playerPed invalid during initial role spawn.")
        end
    elseif not oldRole and role and role == "citizen" then
        if playerPedOnUpdate and playerPedOnUpdate ~= 0 and playerPedOnUpdate ~= -1 and DoesEntityExist(playerPedOnUpdate) then
            spawnPlayer(role)
        else
            print("[CNR_CLIENT_WARN] cnr:updatePlayerData: playerPed invalid during initial citizen spawn.")
        end
    end
    SendNUIMessage({ action = 'updateMoney', cash = playerCash })
    UpdateCopStoreBlips() -- removed argument
    SendNUIMessage({
        action = "updateXPBar",
        currentXP = playerData.xp,
        currentLevel = playerData.level,
        xpForNextLevel = CalculateXpForNextLevelClient(playerData.level, playerData.role)
    })
    ShowNotification(string.format("Data Synced: Lvl %d, XP %d, Role %s", playerData.level, playerData.xp, playerData.role))
    if newPlayerData.weapons and type(newPlayerData.weapons) == "table" then
        if playerPedOnUpdate and playerPedOnUpdate ~= 0 and playerPedOnUpdate ~= -1 and DoesEntityExist(playerPedOnUpdate) then
            playerWeapons = {}
            playerAmmo = {}
            for weaponName, ammoCount in pairs(newPlayerData.weapons) do
                local weaponHash = GetHashKey(weaponName)
                if weaponHash ~= 0 and weaponHash ~= -1 then
                    GiveWeaponToPed(playerPedOnUpdate, weaponHash, ammoCount or 0, false, false)
                    playerWeapons[weaponName] = true
                    playerAmmo[weaponName] = ammoCount or 0
                else
                    print("Warning: Invalid weaponName received in newPlayerData: " .. tostring(weaponName))
                end
            end
        else
            print("[CNR_CLIENT_WARN] cnr:updatePlayerData: playerPed invalid, cannot give weapons.")
        end
    end
    if not g_isPlayerPedReady and role and role ~= "citizen" then
        Citizen.CreateThread(function()
            Citizen.Wait(1500)
            g_isPlayerPedReady = true
            print("[CNR_CLIENT] Player Ped is now considered READY (g_isPlayerPedReady = true). Role: " .. role)
        end)
    elseif role == "citizen" and g_isPlayerPedReady then
        g_isPlayerPedReady = false
        print("[CNR_CLIENT] Player Ped is NO LONGER READY (g_isPlayerPedReady = false) due to role change to citizen.")
    end
end)

RegisterNetEvent('cnr:xpGained')
AddEventHandler('cnr:xpGained', function(amount, newTotalXp)
    playerData.xp = newTotalXp
    ShowNotification(string.format("~g~+%d XP! (Total: %d)", amount, newTotalXp))
    SendNUIMessage({ 
        action = "updateXPBar", 
        currentXP = playerData.xp, 
        currentLevel = playerData.level, 
        xpForNextLevel = CalculateXpForNextLevelClient(playerData.level, playerData.role),
        xpGained = amount
    })
end)

RegisterNetEvent('cnr:levelUp')
AddEventHandler('cnr:levelUp', function(newLevel, newTotalXp)
    local oldLevel = playerData.level
    playerData.level = newLevel
    playerData.xp = newTotalXp
    ShowNotification("~g~LEVEL UP!~w~ You reached Level " .. newLevel .. "!" )
    SendNUIMessage({ 
        action = "updateXPBar", 
        currentXP = playerData.xp, 
        currentLevel = playerData.level, 
        xpForNextLevel = CalculateXpForNextLevelClient(playerData.level, playerData.role),
        xpGained = 0 -- Level up doesn't show XP gain, just the level animation
    })
end)

RegisterNetEvent('cops_and_robbers:updateWantedDisplay')
AddEventHandler('cops_and_robbers:updateWantedDisplay', function(stars, points)
    currentWantedStarsClient = stars
    currentWantedPointsClient = points
    local newUiLabel = ""
    if stars > 0 then
        for _, levelData in ipairs(Config.WantedSettings.levels) do if levelData.stars == stars then newUiLabel = levelData.uiLabel; break end end
        if newUiLabel == "" then newUiLabel = "Wanted: " .. string.rep("*", stars) end
    end
    wantedUiLabel = newUiLabel
    SetWantedLevelForPlayerRole(stars, points)
end)

-- Missing event handler for wanted level synchronization
RegisterNetEvent('cnr:wantedLevelSync')
AddEventHandler('cnr:wantedLevelSync', function(wantedData)
    if wantedData then
        currentWantedStarsClient = wantedData.stars or 0
        currentWantedPointsClient = wantedData.wantedLevel or 0
        local newUiLabel = ""
        if wantedData.stars > 0 then
            for _, levelData in ipairs(Config.WantedSettings.levels) do 
                if levelData.stars == wantedData.stars then 
                    newUiLabel = levelData.uiLabel
                    break 
                end 
            end
            if newUiLabel == "" then newUiLabel = "Wanted: " .. string.rep("*", wantedData.stars) end
        end
        wantedUiLabel = newUiLabel
        SetWantedLevelForPlayerRole(wantedData.stars, wantedData.wantedLevel)
        print(string.format("[CNR_CLIENT_DEBUG] Wanted level synced: Stars=%d, Points=%d", wantedData.stars, wantedData.wantedLevel))
    end
end)

RegisterNetEvent('cops_and_robbers:wantedLevelResponseUpdate')
AddEventHandler('cops_and_robbers:wantedLevelResponseUpdate', function(targetPlayerId, stars, points, lastKnownCoords)
    -- This event handler is currently not responsible for spawning custom NPC police responses.
    -- Ambient ped clearing is handled by a separate periodic thread.
    -- Default police dispatch is suppressed by the 'Default Police Disabler Thread'.
    -- Log if needed for debugging that this event was received.
    print(string.format("[CNR_CLIENT] Event cops_and_robbers:wantedLevelResponseUpdate received for player %s. Stars: %d. Currently, this event does not spawn custom NPCs.", targetPlayerId, stars))
end)

RegisterNetEvent('cops_and_robbers:contrabandDropSpawned')
AddEventHandler('cops_and_robbers:contrabandDropSpawned', function(dropId, location, itemName, itemModelHash)
    if activeDropBlips[dropId] then RemoveBlip(activeDropBlips[dropId]) end
    local blip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(blip, 1); SetBlipColour(blip, 2); SetBlipScale(blip, 1.5); SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING"); AddTextComponentSubstringPlayerName("Contraband: " .. itemName); EndTextCommandSetBlipName(blip)
    activeDropBlips[dropId] = blip
    local propEntity = nil
    if itemModelHash then
        local model = (type(itemModelHash) == "number" and itemModelHash) or GetHashKey(itemModelHash)
        RequestModel(model)
        CreateThread(function()
             while not g_isPlayerPedReady do Citizen.Wait(500) end
            local attempts = 0; while not HasModelLoaded(model) and attempts < 100 do Citizen.Wait(100); attempts = attempts + 1 end
            if HasModelLoaded(model) then
                propEntity = CreateObject(model, location.x, location.y, location.z - 0.9, false, true, true)
                PlaceObjectOnGroundProperly(propEntity)
                if clientActiveContrabandDrops[dropId] then clientActiveContrabandDrops[dropId].propEntity = propEntity else DeleteEntity(propEntity) end
            end
            SetModelAsNoLongerNeeded(model)
        end)
    end
    clientActiveContrabandDrops[dropId] = { id = dropId, location = location, name = itemName, modelHash = itemModelHash, propEntity = propEntity }
    ShowNotification("~y~A new contraband drop has appeared: " .. itemName)
end)

RegisterNetEvent('cops_and_robbers:contrabandDropCollected')
AddEventHandler('cops_and_robbers:contrabandDropCollected', function(dropId, collectorName, itemName)
    if activeDropBlips[dropId] then RemoveBlip(activeDropBlips[dropId]); activeDropBlips[dropId] = nil end
    if clientActiveContrabandDrops[dropId] then
        if clientActiveContrabandDrops[dropId].propEntity and DoesEntityExist(clientActiveContrabandDrops[dropId].propEntity) then DeleteEntity(clientActiveContrabandDrops[dropId].propEntity) end
        clientActiveContrabandDrops[dropId] = nil
    end
    if isCollectingFromDrop == dropId then isCollectingFromDrop = nil; collectionTimerEnd = 0 end
    ShowNotification("~g~Contraband '" .. itemName .. "' was collected by " .. collectorName .. ".")
end)

RegisterNetEvent('cops_and_robbers:collectingContrabandStarted')
AddEventHandler('cops_and_robbers:collectingContrabandStarted', function(dropId, collectionTime)
    isCollectingFromDrop = dropId; collectionTimerEnd = GetGameTimer() + collectionTime
    ShowNotification("~b~Collecting contraband... Hold position.")
end)

Citizen.CreateThread(function()
    while not g_isPlayerPedReady do Citizen.Wait(500) end
    print("[CNR_CLIENT] Thread for Contraband Interaction now starting its main loop.")
    local lastInteractionCheck = 0; local interactionCheckInterval = 250; local activeCollectionWait = 50
    while true do
        local loopWait = interactionCheckInterval
        local playerPed = PlayerPedId()
        if not (playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed)) then Citizen.Wait(1000); goto continue_contraband_loop end
        if role == 'robber' then
            local playerCoords = GetEntityCoords(playerPed)
            if not isCollectingFromDrop then
                if (GetGameTimer() - lastInteractionCheck) > interactionCheckInterval then
                    for dropId, dropData in pairs(clientActiveContrabandDrops) do
                        if dropData.location and #(playerCoords - dropData.location) < 3.0 then
                            DisplayHelpText("Press ~INPUT_CONTEXT~ to collect contraband (" .. dropData.name .. ")")
                            if IsControlJustReleased(0, 51) then TriggerServerEvent('cops_and_robbers:startCollectingContraband', dropId) end
                            loopWait = activeCollectionWait; break
                        end
                    end; lastInteractionCheck = GetGameTimer()
                end
            else
                loopWait = activeCollectionWait
                local currentDropData = clientActiveContrabandDrops[isCollectingFromDrop]
                if currentDropData and currentDropData.location then
                    if #(playerCoords - currentDropData.location) > 5.0 then ShowNotification("~r~Contraband collection cancelled: Moved too far."); isCollectingFromDrop = nil; collectionTimerEnd = 0
                    elseif GetGameTimer() >= collectionTimerEnd then ShowNotification("~g~Collection complete! Verifying with server..."); TriggerServerEvent('cops_and_robbers:finishCollectingContraband', isCollectingFromDrop); isCollectingFromDrop = nil; collectionTimerEnd = 0 end
                else isCollectingFromDrop = nil; collectionTimerEnd = 0 end
            end
        end
        Citizen.Wait(loopWait)
        ::continue_contraband_loop::
    end
end)

Citizen.CreateThread(function()
    local clearCheckInterval = 500 -- milliseconds (e.g., every 0.5 seconds as per refined subtask)

    while true do
        Citizen.Wait(clearCheckInterval)

        local playerId = PlayerId()
        local playerPed = PlayerPedId()

        if not (playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed)) then
            goto continue_ambient_clear_loop -- Skip if player ped is not valid
        end

        -- Only run if player has a wanted level
        if currentWantedStarsClient > 0 then
            local playerCoords = GetEntityCoords(playerPed)
            local clearRadius = Config.PoliceClearRadius or 100.0 -- Use config value or default

            local handle, ped = FindFirstPed()
            local success, nextPed = true, ped
            repeat
                if DoesEntityExist(ped) and ped ~= playerPed and IsPedNpcCop(ped) then
                    local currentPedCoords = GetEntityCoords(ped)
                    if #(playerCoords - currentPedCoords) < clearRadius then
                        -- Only delete the ped if it's not in a vehicle
                        local vehicle = GetVehiclePedIsIn(ped, false)
                        if vehicle == 0 then
                            SetEntityAsMissionEntity(ped, false, true)
                            ClearPedTasksImmediately(ped)
                            DeletePed(ped)
                        end
                    end
                end
                success, nextPed = FindNextPed(handle)
                ped = nextPed
            until not success
            EndFindPed(handle)
        end
        ::continue_ambient_clear_loop::
    end
end)

-- Ensure CalculateXpForNextLevelClient is defined before use
function CalculateXpForNextLevelClient(currentLevel, playerRole)
    if not Config.LevelingSystemEnabled then return 999999 end
    local maxLvl = Config.MaxLevel or 10
    if currentLevel >= maxLvl then return playerData.xp end
    if Config.XPTable and Config.XPTable[currentLevel] then return Config.XPTable[currentLevel]
    else print("CalculateXpForNextLevelClient: XP requirement for level " .. currentLevel .. " not found. Returning high value.", "warn"); return 999999 end
end

-- Handle role selection from NUI
RegisterNUICallback("selectRole", function(data, cb)
    local selectedRole = data.role
    if selectedRole == "cop" or selectedRole == "robber" then
        TriggerServerEvent("cnr:selectRole", selectedRole)
        -- UI will be hidden once the server confirms
        cb({ success = true, pending = true })
    else
        cb({ success = false, error = "Invalid role" })
    end
end)

RegisterNUICallback("setNuiFocus", function(data, cb)
    local hasFocus = data.hasFocus
    local hasCursor = data.hasCursor

    -- Log the received values for debugging
    -- print(string.format("[CNR_CLIENT_NUI] setNuiFocus callback received: hasFocus=%s, hasCursor=%s", tostring(hasFocus), tostring(hasCursor)))

    SetNuiFocus(hasFocus, hasCursor)
    SetNuiFocusKeepInput(false) -- Typically you want input to go to the game or UI, not both. Set to true if specific cases need it.

    -- It's good practice to send a callback response if the NUI script expects one,
    -- even if it's just a simple acknowledgment.
    cb({ success = true, message = "NUI focus updated" })
end)

RegisterNetEvent('cnr:syncInventory')
AddEventHandler('cnr:syncInventory', function(inventoryData)
    local currentResourceName = GetCurrentResourceName()
    if exports[currentResourceName] and exports[currentResourceName].UpdateFullInventory then
        exports[currentResourceName]:UpdateFullInventory(inventoryData)
        -- Log("cnr:syncInventory: Called UpdateFullInventory.", "info")
    else
        -- Log("cnr:syncInventory: Export UpdateFullInventory not found.", "error") -- Use Log if available, otherwise print
        print("[CNR_CLIENT_ERROR] cnr:syncInventory: Export UpdateFullInventory not found in resource " .. currentResourceName)
    end
end)

RegisterNetEvent("cnr:roleSelected")
AddEventHandler("cnr:roleSelected", function(success, message)
    Log(string.format("[CNR_ROLE_SELECT] cnr:roleSelected event received. Success: %s, Message: %s", tostring(success), tostring(message)), "info")
    if success then
        Log("[CNR_ROLE_SELECT] Attempting to release NUI focus (SetNuiFocus false, false)...", "info")
        SetNuiFocus(false, false)
        Log("[CNR_ROLE_SELECT] SetNuiFocus(false, false) called.", "info")

        Log("[CNR_ROLE_SELECT] Attempting to send NUI message hideRoleSelection...", "info")
        SendNUIMessage({ action = "hideRoleSelection" })
        Log("[CNR_ROLE_SELECT] NUI message hideRoleSelection sent.", "info")
    else
        Log("[CNR_ROLE_SELECT] Role selection failed on server. Sending roleSelectionFailed to NUI.", "warn")
        SendNUIMessage({ action = "roleSelectionFailed", error = message or "Role selection failed." })
    end
end)

RegisterNetEvent('cnr:spawnPlayerAt')
AddEventHandler('cnr:spawnPlayerAt', function(location, heading, role)
    print(string.format("[CNR_CLIENT_DEBUG] cnr:spawnPlayerAt received: location=%s, heading=%s, role=%s", 
        tostring(location), tostring(heading), tostring(role)))
    
    local playerPed = PlayerPedId()
    local spawnX, spawnY, spawnZ = nil, nil, nil
    
    -- Handle both vector3 and table formats for location
    if location then
        if type(location) == "vector3" then
            spawnX, spawnY, spawnZ = location.x, location.y, location.z
        elseif type(location) == "table" and location.x and location.y and location.z then
            spawnX, spawnY, spawnZ = location.x, location.y, location.z
        end
    end
    
    if spawnX and spawnY and spawnZ then
        SetEntityCoords(playerPed, spawnX, spawnY, spawnZ, false, false, false, true)
        if heading then
            SetEntityHeading(playerPed, heading)
        end
        ShowNotification("Spawned as " .. tostring(role or "unknown"))
        print(string.format("[CNR_CLIENT_DEBUG] Player successfully spawned at %f, %f, %f as %s", 
            spawnX, spawnY, spawnZ, tostring(role)))
    else
        print(string.format("[CNR_CLIENT_ERROR] Invalid spawn location received: %s", tostring(location)))
        ShowNotification("~r~Error: Could not determine spawn point for your role.")
    end
    -- Apply visuals and loadout for the new role
    if role then
        ApplyRoleVisualsAndLoadout(role, nil)
    end
end)

-- Handle role selection from NUI
Citizen.CreateThread(function()
    local copStorePromptActive = false
    while true do
        Citizen.Wait(100)
        if role == "cop" and Config and Config.NPCVendors and not isCopStoreUiOpen then
            local shown = false
            for _, vendor in ipairs(Config.NPCVendors) do
                if vendor.name == "Cop Store" and vendor.location then
                    local playerPed = PlayerPedId()
                    if playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed) then
                        local playerCoords = GetEntityCoords(playerPed)
                        local dist = #(playerCoords - vendor.location)
                        if dist < 2.0 then
                            if not copStorePromptActive then
                                DisplayHelpText("Press ~INPUT_CONTEXT~ to open Cop Store")
                                copStorePromptActive = true
                            end
                            shown = true
                            if IsControlJustReleased(0, 51) then -- INPUT_CONTEXT (E)
                                print("[CNR_CLIENT_DEBUG] Opening Cop Store. Current isCopStoreUiOpen:", isCopStoreUiOpen)
                                TriggerServerEvent('cops_and_robbers:getItemList', 'Vendor', vendor.items, vendor.name)
                                Citizen.Wait(500) -- Prevent double-trigger
                            end
                        end
                    end
                end
            end
            if not shown and copStorePromptActive then
                ClearAllHelpMessages()
                copStorePromptActive = false
            end
        else
            if copStorePromptActive then
                ClearAllHelpMessages()
                copStorePromptActive = false
            end
            Citizen.Wait(300)
        end
    end
end)

-- Handle item list from server and open Store NUI
RegisterNetEvent('cops_and_robbers:sendItemList')
AddEventHandler('cops_and_robbers:sendItemList', function(storeName, items, playerInfo)
    if storeName == "Cop Store" then
        print("[CNR_CLIENT_DEBUG] Received item list for Cop Store. Setting isCopStoreUiOpen to true")
        isCopStoreUiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openStore', storeName = storeName, items = items, playerInfo = playerInfo })
    elseif storeName == "Black Market Dealer" or storeName == "Gang Supplier" then
        print("[CNR_CLIENT_DEBUG] Received item list for " .. storeName .. ". Setting isRobberStoreUiOpen to true")
        isRobberStoreUiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openStore', storeName = storeName, items = items, playerInfo = playerInfo })
    end
end)

-- Handle closing the Store UI from NUI
RegisterNUICallback("closeStore", function(_, cb)
    print("[CNR_CLIENT_DEBUG] Closing Store. Setting store UI flags to false")
    isCopStoreUiOpen = false
    isRobberStoreUiOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false) -- Extra safety to fully release focus
    cb({ success = true })
end)

-- Handle getPlayerInventory for Sell tab (fetches real inventory)
RegisterNUICallback("getPlayerInventory", function(data, cb)
    local responded = false
    local handler
    handler = AddEventHandler('cops_and_robbers:sendPlayerInventory', function(inv)
        if responded then return end
        responded = true
        RemoveEventHandler(handler)
        cb({ inventory = inv or {} })
    end)
    TriggerServerEvent('cops_and_robbers:getPlayerInventory')
    Citizen.SetTimeout(2000, function()
        if not responded then
            RemoveEventHandler(handler)
            cb({ inventory = {} })
        end
    end)
end)

-- Handle buyItem from NUI
RegisterNUICallback("buyItem", function(data, cb)
    if not data or not data.itemId or not data.quantity then
        cb({ success = false, error = "Invalid buy request" })
        return
    end
    local responded = false
    local handler
    handler = AddEventHandler('cops_and_robbers:buyResult', function(success) -- message argument removed
        if responded then return end
        responded = true
        RemoveEventHandler(handler)
        cb({ success = success }) -- message property removed
        -- Refresh inventory in UI after buy
        SendNUIMessage({ action = 'refreshInventory' })
    end)
    TriggerServerEvent('cops_and_robbers:buyItem', data.itemId, tonumber(data.quantity) or 1)
    Citizen.SetTimeout(2000, function()
        if not responded then
            RemoveEventHandler(handler)
            cb({ success = false, error = "No response from server." })
        end
    end)
end)

-- Handle sellItem from NUI
RegisterNUICallback("sellItem", function(data, cb)
    if not data or not data.itemId or not data.quantity then
        cb({ success = false, error = "Invalid sell request" })
        return
    end
    local responded = false
    local handler
    handler = AddEventHandler('cops_and_robbers:sellResult', function(success) -- message argument removed
        if responded then return end
        responded = true
        RemoveEventHandler(handler)
        cb({ success = success }) -- message property removed
        -- Refresh inventory in UI after sell
        SendNUIMessage({ action = 'refreshInventory' })
    end)
    TriggerServerEvent('cops_and_robbers:sellItem', data.itemId, tonumber(data.quantity) or 1)
    Citizen.SetTimeout(2000, function()
        if not responded then
            RemoveEventHandler(handler)
            cb({ success = false, error = "No response from server." })
        end
    end)
end)

-- Register client events that server sends
RegisterNetEvent('cops_and_robbers:sendPlayerInventory')
RegisterNetEvent('cops_and_robbers:buyResult')
RegisterNetEvent('cops_and_robbers:sellResult')
RegisterNetEvent('cops_and_robbers:refreshSellListIfNeeded')

-- Handle refresh sell list request from server
AddEventHandler('cops_and_robbers:refreshSellListIfNeeded', function()
    -- Send refresh message to NUI if store is open and on sell tab
    SendNUIMessage({ action = 'refreshSellListIfNeeded' })
end)

-- Debug event to force re-equip weapons
RegisterNetEvent('cnr:forceEquipWeapons')
AddEventHandler('cnr:forceEquipWeapons', function()
    -- Force call the inventory client function to re-equip weapons
    if exports['Cops-and-Robbers'] then
        -- If the function is exported, call it
        -- exports['Cops-and-Robbers']:EquipInventoryWeapons()
        -- For now, we'll trigger the inventory update which should call EquipInventoryWeapons
        TriggerServerEvent('cnr:requestPlayerInventory')
    end
end)

-- Add a client command to manually test weapon equipping
RegisterCommand("testequip", function()
    if exports and exports['inventory_client'] and exports['inventory_client'].EquipInventoryWeapons then
        exports['inventory_client'].EquipInventoryWeapons()
    else
        -- Call the function directly if it exists in this scope
        if EquipInventoryWeapons then
            EquipInventoryWeapons()
        else
            TriggerServerEvent('cnr:requestConfigItems') -- Request config items first
            Citizen.Wait(1000) -- Wait a bit
            -- Try to call inventory client function
            TriggerEvent('cnr:testEquipWeapons')
        end
    end
    print("[CNR_CLIENT_DEBUG] Manual weapon equip test triggered")
end, false)

-- Robber Store Ped Interaction Thread
Citizen.CreateThread(function()
    local robberStorePromptActive = false
    while true do
        Citizen.Wait(100)
        if role == "robber" and Config and Config.NPCVendors and not isRobberStoreUiOpen then
            local shown = false
            for _, vendor in ipairs(Config.NPCVendors) do
                if (vendor.name == "Black Market Dealer" or vendor.name == "Gang Supplier") and vendor.location then
                    local playerPed = PlayerPedId()
                    if playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed) then
                        local playerCoords = GetEntityCoords(playerPed)
                        local dist = #(playerCoords - vendor.location)
                        if dist < 2.0 then
                            if not robberStorePromptActive then
                                local storeType = vendor.name == "Black Market Dealer" and "Black Market" or "Gang Supplier"
                                DisplayHelpText("Press ~INPUT_CONTEXT~ to open " .. storeType)
                                robberStorePromptActive = true
                            end
                            shown = true
                            if IsControlJustReleased(0, 51) then -- INPUT_CONTEXT (E)
                                print("[CNR_CLIENT_DEBUG] Opening " .. vendor.name .. ". Current isRobberStoreUiOpen:", isRobberStoreUiOpen)
                                TriggerServerEvent('cops_and_robbers:getItemList', 'Vendor', vendor.items, vendor.name)
                                Citizen.Wait(500) -- Prevent double-trigger
                            end
                        end
                    end
                end
            end
            if not shown and robberStorePromptActive then
                ClearAllHelpMessages()
                robberStorePromptActive = false
            end
        else
            if robberStorePromptActive then
                ClearAllHelpMessages()
                robberStorePromptActive = false
            end
            Citizen.Wait(300)
        end
    end
end)

-- =================================================================================================
-- CRIME DETECTION SYSTEM
-- =================================================================================================

-- Vehicle theft detection
local lastVehicle = nil
local vehicleOwnershipCheck = {}

CreateThread(function()
    while true do
        Wait(1000)
        if role == "robber" then
            local playerPed = PlayerPedId()
            if playerPed and DoesEntityExist(playerPed) then
                local currentVehicle = GetVehiclePedIsIn(playerPed, false)
                
                if currentVehicle ~= 0 and currentVehicle ~= lastVehicle then
                    local driver = GetPedInVehicleSeat(currentVehicle, -1)
                    if driver == playerPed then
                        -- Check if this is a stolen vehicle
                        local vehicleNetworkId = NetworkGetNetworkIdFromEntity(currentVehicle)
                        local isPlayerVehicle = false
                        
                        -- Check if this vehicle was spawned by the player legitimately
                        for playerId = 0, 255 do
                            if NetworkIsPlayerActive(playerId) then
                                local otherPed = GetPlayerPed(playerId)
                                if otherPed ~= playerPed and DoesEntityExist(otherPed) then
                                    local lastVehicleOfOther = GetVehiclePedIsIn(otherPed, true)
                                    if lastVehicleOfOther == currentVehicle then
                                        isPlayerVehicle = true
                                        break
                                    end
                                end
                            end
                        end
                        
                        -- Check if vehicle had NPC driver
                        local wasNPCVehicle = vehicleOwnershipCheck[currentVehicle] or false
                        if not wasNPCVehicle then
                            -- Check if there are NPC passengers that suggest this was an NPC vehicle
                            for seat = -1, GetVehicleMaxNumberOfPassengers(currentVehicle) do
                                local passenger = GetPedInVehicleSeat(currentVehicle, seat)
                                if passenger ~= 0 and passenger ~= playerPed and not IsPedAPlayer(passenger) then
                                    wasNPCVehicle = true
                                    break
                                end
                            end
                        end
                        
                        -- Trigger vehicle theft if it's not the player's own vehicle
                        if not isPlayerVehicle or wasNPCVehicle then
                            print("[CNR_CLIENT_DEBUG] Vehicle theft detected")
                            TriggerServerEvent('cnr:reportCrime', 'grand_theft_auto')
                        end
                    end
                    lastVehicle = currentVehicle
                elseif currentVehicle == 0 then
                    lastVehicle = nil
                end
            end
        end
    end
end)

-- Track vehicle ownership for better theft detection
CreateThread(function()
    while true do
        Wait(2000)
        local playerPed = PlayerPedId()
        if playerPed and DoesEntityExist(playerPed) then
            local handle, vehicle = FindFirstVehicle()
            local success = true
            while success do
                if DoesEntityExist(vehicle) then
                    local driver = GetPedInVehicleSeat(vehicle, -1)
                    if driver ~= 0 and not IsPedAPlayer(driver) then
                        vehicleOwnershipCheck[vehicle] = true
                    end
                end
                success, vehicle = FindNextVehicle(handle)
            end
            EndFindVehicle(handle)
        end
    end
end)

-- Speeding detection
local lastSpeedCheck = 0
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds
        if role == "robber" then
            local currentTime = GetGameTimer()
            if currentTime - lastSpeedCheck > 5000 then
                local playerPed = PlayerPedId()
                if playerPed and DoesEntityExist(playerPed) then
                    local vehicle = GetVehiclePedIsIn(playerPed, false)
                    if vehicle ~= 0 then
                        local speed = GetEntitySpeed(vehicle) * 2.237 -- Convert to MPH
                        if speed > 80 then -- High speed threshold
                            print("[CNR_CLIENT_DEBUG] Speeding detected: " .. math.floor(speed) .. " MPH")
                            TriggerServerEvent('cnr:reportCrime', 'speeding')
                        end
                    end
                end
                lastSpeedCheck = currentTime
            end
        end
    end
end)

-- Violence detection (shooting)
local lastShotTime = 0
CreateThread(function()
    while true do
        Wait(500)
        if role == "robber" then
            local playerPed = PlayerPedId()
            if playerPed and DoesEntityExist(playerPed) then
                if IsPedShooting(playerPed) then
                    local currentTime = GetGameTimer()
                    if currentTime - lastShotTime > 3000 then -- Prevent spam
                        -- Check if shooting at police or civilians
                        local coords = GetEntityCoords(playerPed)
                        local nearbyPeds = GetNearbyPeds(coords, 50.0)
                        
                        for _, ped in ipairs(nearbyPeds) do
                            if DoesEntityExist(ped) and ped ~= playerPed then
                                if IsPedNpcCop(ped) then
                                    print("[CNR_CLIENT_DEBUG] Assault on police detected")
                                    TriggerServerEvent('cnr:reportCrime', 'assault_cop')
                                elseif not IsPedAPlayer(ped) then
                                    print("[CNR_CLIENT_DEBUG] Assault on civilian detected") 
                                    TriggerServerEvent('cnr:reportCrime', 'assault_civilian')
                                end
                            end
                        end
                        lastShotTime = currentTime
                    end
                end
            end
        end
    end
end)

-- Helper function to get nearby peds
function GetNearbyPeds(coords, radius)
    local peds = {}
    local handle, ped = FindFirstPed()
    local success = true
    while success do
        if DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            if #(coords - pedCoords) <= radius then
                table.insert(peds, ped)
            end
        end
        success, ped = FindNextPed(handle)
    end
    EndFindPed(handle)
    return peds
end

-- Restricted area detection
local lastAreaCheck = 0
local inRestrictedArea = {}

CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds
        if role == "robber" then
            local currentTime = GetGameTimer()
            if currentTime - lastAreaCheck > 5000 then
                local playerPed = PlayerPedId()
                if playerPed and DoesEntityExist(playerPed) then
                    local playerCoords = GetEntityCoords(playerPed)
                      -- Check restricted areas from config
                    if Config.RestrictedAreas then
                        for i, area in ipairs(Config.RestrictedAreas) do
                            local distance = #(playerCoords - area.center)
                            if distance <= area.radius then
                                if not inRestrictedArea[i] then
                                    inRestrictedArea[i] = true
                                    print(string.format("[CNR_CLIENT_DEBUG] Entered restricted area: %s", area.name))
                                    
                                    -- Send area info to server for minimum star enforcement
                                    TriggerServerEvent('cnr:reportRestrictedAreaEntry', area)
                                    
                                    if area.message then
                                        ShowNotification(area.message)
                                    end
                                end
                            else
                                if inRestrictedArea[i] then
                                    inRestrictedArea[i] = false
                                    print(string.format("[CNR_CLIENT_DEBUG] Left restricted area: %s", area.name))
                                end
                            end
                        end
                    end
                end
                lastAreaCheck = currentTime
            end
        else
            -- Reset restricted area status if not a robber
            for i, _ in pairs(inRestrictedArea) do
                inRestrictedArea[i] = false
            end
        end
    end
end)

-- Hit and Run Detection
local lastVehicleCollision = 0
local lastPedHit = {}

CreateThread(function()
    while true do
        Wait(100) -- Check frequently for hit and run
        if role == "robber" then
            local playerPed = PlayerPedId()
            if playerPed and DoesEntityExist(playerPed) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                if vehicle ~= 0 then
                    local currentTime = GetGameTimer()
                    
                    -- Check if vehicle collided with anything recently
                    if HasEntityCollidedWithAnything(vehicle) and currentTime - lastVehicleCollision > 2000 then
                        local vehicleCoords = GetEntityCoords(vehicle)
                        local nearbyPeds = GetNearbyPeds(vehicleCoords, 10.0)
                        
                        for _, ped in ipairs(nearbyPeds) do
                            if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
                                -- Check if ped is injured or dead from vehicle collision
                                if (IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or IsPedInjured(ped)) then
                                    local pedId = tostring(ped)
                                    if not lastPedHit[pedId] or currentTime - lastPedHit[pedId] > 10000 then
                                        lastPedHit[pedId] = currentTime
                                        
                                        -- Check if it's a cop or civilian
                                        if IsPedNpcCop(ped) then
                                            print("[CNR_CLIENT_DEBUG] Hit and run on police officer detected")
                                            TriggerServerEvent('cnr:reportCrime', 'hit_and_run_cop')
                                        else
                                            print("[CNR_CLIENT_DEBUG] Hit and run on civilian detected")
                                            TriggerServerEvent('cnr:reportCrime', 'hit_and_run_civilian')
                                        end
                                        
                                        -- If ped is dead, also report murder
                                        if IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) then
                                            if IsPedNpcCop(ped) then
                                                print("[CNR_CLIENT_DEBUG] Murder of police officer detected")
                                                TriggerServerEvent('cnr:reportCrime', 'cop_murder')
                                            else
                                                print("[CNR_CLIENT_DEBUG] Murder of civilian detected")
                                                TriggerServerEvent('cnr:reportCrime', 'civilian_murder')
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        lastVehicleCollision = currentTime
                    end
                end
            end
        end
    end
end)

-- Enhanced Murder Detection (non-vehicle)
local lastMurderCheck = 0

CreateThread(function()
    while true do
        Wait(1000) -- Check every second
        if role == "robber" then
            local currentTime = GetGameTimer()
            if currentTime - lastMurderCheck > 1000 then
                local playerPed = PlayerPedId()
                if playerPed and DoesEntityExist(playerPed) then
                    local playerCoords = GetEntityCoords(playerPed)
                    local nearbyPeds = GetNearbyPeds(playerCoords, 15.0)
                    
                    for _, ped in ipairs(nearbyPeds) do
                        if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
                            -- Check if ped just died and player was the source
                            if IsPedDeadOrDying(ped, true) and GetPedSourceOfDeath(ped) == playerPed then
                                local pedId = tostring(ped)
                                if not lastPedHit[pedId] then
                                    lastPedHit[pedId] = currentTime
                                    
                                    if IsPedNpcCop(ped) then
                                        print("[CNR_CLIENT_DEBUG] Direct murder of police officer detected")
                                        TriggerServerEvent('cnr:reportCrime', 'cop_murder')
                                    else
                                        print("[CNR_CLIENT_DEBUG] Direct murder of civilian detected")
                                        TriggerServerEvent('cnr:reportCrime', 'civilian_murder')
                                    end
                                end
                            end
                        end
                    end
                    lastMurderCheck = currentTime
                end
            end
        end
    end
end)

-- Helper function to clear role-specific blips
local function ClearRoleSpecificBlips()
    -- Clear cop store blips
    for blipKey, blipId in pairs(copStoreBlips) do
        if blipId and DoesBlipExist(blipId) then
            RemoveBlip(blipId)
        end
    end
    copStoreBlips = {}
    
    -- Clear robber store blips  
    for blipKey, blipId in pairs(robberStoreBlips) do
        if blipId and DoesBlipExist(blipId) then
            RemoveBlip(blipId)
        end
    end
    robberStoreBlips = {}
end

-- Command to open role selection menu
RegisterCommand("selectrole", function(source, args, rawCommand)
    local selectedRole = args[1]
    
    if selectedRole then
        -- If a role is specified, select it directly
        selectedRole = string.lower(selectedRole)
        if selectedRole == "cop" or selectedRole == "robber" or selectedRole == "civilian" then
            if selectedRole == "civilian" then
                -- Handle civilian role (reset to no role)
                role = nil
                playerData.role = nil
                ShowNotification("Role cleared. You are now a civilian.")
                -- Clear any role-specific blips/UI
                ClearRoleSpecificBlips()
                return
            else
                TriggerServerEvent("cnr:selectRole", selectedRole)
            end
        else
            ShowNotification("~r~Invalid role. Use: cop, robber, or civilian")
        end    else
        -- No role specified, open the role selection UI
        SendNUIMessage({ action = 'showRoleSelection', resourceName = GetCurrentResourceName() })
        SetNuiFocus(true, true)
    end
end, false)

-- Death detection and auto-respawn system
Citizen.CreateThread(function()
    local wasPlayerDead = false
    
    while true do
        Citizen.Wait(1000) -- Check every second
        
        local playerPed = PlayerPedId()
        local isPlayerDead = IsEntityDead(playerPed) or IsPedDeadOrDying(playerPed, true)
        
        if isPlayerDead and not wasPlayerDead then
            -- Player just died
            wasPlayerDead = true
            
            -- Ensure UI focus is cleared when player dies
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            
        elseif not isPlayerDead and wasPlayerDead then
            -- Player just respawned
            wasPlayerDead = false
            
            -- The playerSpawned event will handle the rest
        end
    end
end)

-- Emergency escape key handler to close stuck UI
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if IsControlJustReleased(0, 322) then -- ESC key
            -- Check if NUI focus is active and player is not in a valid UI state
            local isInUI = false -- You can add logic here to check if legitimately in UI
            
            -- Force close UI if player seems stuck
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            SendNUIMessage({ action = 'hideRoleSelection' })
            SendNUIMessage({ action = 'closeStore' })
        end
    end
end)

-- Wanted Level UI Notification Event Handlers
RegisterNetEvent('cnr:showWantedNotification')
AddEventHandler('cnr:showWantedNotification', function(stars, points, levelLabel)
    SendNUIMessage({
        action = "showWantedNotification",
        stars = stars,
        points = points,
        level = levelLabel
    })
end)

RegisterNetEvent('cnr:hideWantedNotification')
AddEventHandler('cnr:hideWantedNotification', function()
    SendNUIMessage({
        action = "hideWantedNotification"
    })
end)
