-- client.lua
-- Cops & Robbers FiveM Game Mode - Client Script
-- Version: 1.2 | Date: <current date>
-- Ped readiness flag and guards implemented.

-- _G.cnrSetDispatchServiceErrorLogged = false -- Removed as part of subtask
local g_isPlayerPedReady = false

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
local isCollectingFromDrop = nil
local collectionTimerEnd = 0

-- Safe Zone Client State
local isCurrentlyInSafeZone = false
local currentSafeZoneName = ""

-- Wanted System Expansion Client State
local currentPlayerNPCResponseEntities = {}
local corruptOfficialNPCs = {}
local copStoreBlips = {}
local currentHelpTextTarget = nil -- Moved to top level for broader access

-- Table to store protected peds (e.g., Cop Store ped)
local g_protectedPolicePeds = {}

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

-- Call this on resource start and when player spawns
Citizen.CreateThread(function()
    Citizen.Wait(2000)
    SpawnCopStorePed()
end)

-- =====================================
--           NETWORK EVENTS
-- =====================================

AddEventHandler('playerSpawned', function()
    TriggerServerEvent('cnr:playerSpawned') -- Corrected event name
    SendNUIMessage({ action = 'showRoleSelection', resourceName = GetCurrentResourceName() })
    SetNuiFocus(true, true) -- Ensure mouse pointer appears for role selection
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
    -- Update full inventory if present in newPlayerData
    if newPlayerData.inventory then
        local currentResourceName = GetCurrentResourceName()
        if exports[currentResourceName] and exports[currentResourceName].UpdateFullInventory then
            exports[currentResourceName]:UpdateFullInventory(newPlayerData.inventory)
        else
            -- Error case: export not found. Original print removed. Consider if error logging is still needed here, perhaps less verbose.
        end
    else
        -- Inventory is nil case. Original print removed.
        local currentResourceName = GetCurrentResourceName()
        if exports[currentResourceName] and exports[currentResourceName].UpdateFullInventory then
            exports[currentResourceName]:UpdateFullInventory(nil) -- Explicitly pass nil
        else
            -- Error case: export not found for nil sync. Original print removed.
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
    SendNUIMessage({ action = "updateXPBar", currentXP = playerData.xp, currentLevel = playerData.level, xpForNextLevel = CalculateXpForNextLevelClient(playerData.level, playerData.role) })
end)

RegisterNetEvent('cnr:levelUp')
AddEventHandler('cnr:levelUp', function(newLevel, newTotalXp)
    playerData.level = newLevel
    playerData.xp = newTotalXp
    ShowNotification("~g~LEVEL UP!~w~ You reached Level " .. newLevel .. "!" )
    SendNUIMessage({ action = "updateXPBar", currentXP = playerData.xp, currentLevel = playerData.level, xpForNextLevel = CalculateXpForNextLevelClient(playerData.level, playerData.role) })
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

RegisterNetEvent("cnr:roleSelected")
AddEventHandler("cnr:roleSelected", function(success, message)
    if success then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "hideRoleSelection" })
    else
        -- Re-enable UI and show error message
        SendNUIMessage({ action = "roleSelectionFailed", error = message or "Role selection failed." })
    end
end)

RegisterNetEvent('cnr:spawnPlayerAt')
AddEventHandler('cnr:spawnPlayerAt', function(location, heading, role)
    local playerPed = PlayerPedId()
    if location and type(location) == "table" and location.x and location.y and location.z then
        SetEntityCoords(playerPed, location.x, location.y, location.z, false, false, false, true)
        if heading then
            SetEntityHeading(playerPed, heading)
        end
        ShowNotification("Spawned as " .. tostring(role or "unknown"))
    else
        ShowNotification("~r~Error: Could not determine spawn point for your role.")
    end
    -- Apply visuals and loadout for the new role
    if role then
        ApplyRoleVisualsAndLoadout(role, nil)
    end
end)

-- Track if Cop Store UI is open
local isCopStoreUiOpen = false

-- Cop Store Ped Interaction Thread (improved: no flicker, suppress when UI open)
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

-- Handle item list from server and open Cop Store NUI
RegisterNetEvent('cops_and_robbers:sendItemList')
AddEventHandler('cops_and_robbers:sendItemList', function(storeName, items)
    if storeName == "Cop Store" then
        isCopStoreUiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openStore', storeName = storeName, items = items })
    end
end)

-- Handle closing the Cop Store UI from NUI
RegisterNUICallback("closeStore", function(_, cb)
    isCopStoreUiOpen = false
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
    handler = AddEventHandler('cops_and_robbers:buyResult', function(success, message)
        if responded then return end
        responded = true
        RemoveEventHandler(handler)
        cb({ success = success, message = message })
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
    handler = AddEventHandler('cops_and_robbers:sellResult', function(success, message)
        if responded then return end
        responded = true
        RemoveEventHandler(handler)
        cb({ success = success, message = message })
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
