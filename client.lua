-- client.lua
-- Cops & Robbers FiveM Game Mode - Client Script
-- Version: 1.2 | Date: June 17, 2025
-- Ped readiness flag and guards implemented.

-- =====================================
--     REGISTER NET EVENTS (MUST BE FIRST)
-- =====================================

-- Register all client events that will be triggered from server
RegisterNetEvent('cnr:sendInventoryForUI')
RegisterNetEvent('cnr:updatePlayerData')
RegisterNetEvent('cnr:spawnPlayerAt')
RegisterNetEvent('cnr:receiveMyInventory')
RegisterNetEvent('cnr:syncInventory')
RegisterNetEvent('cnr:inventoryUpdated')
RegisterNetEvent('cnr:receiveConfigItems')
RegisterNetEvent('cnr:showWantedLevel')
RegisterNetEvent('cnr:hideWantedLevel')
RegisterNetEvent('cnr:updateWantedLevel')
RegisterNetEvent('cops_and_robbers:sendPlayerInventory')
RegisterNetEvent('cops_and_robbers:buyResult')
RegisterNetEvent('cnr:showAdminPanel')
RegisterNetEvent('cnr:showRobberMenu')
RegisterNetEvent('cnr:xpGained')
RegisterNetEvent('cnr:levelUp')
RegisterNetEvent('cops_and_robbers:updateWantedDisplay')

-- =====================================
--           VARIABLES
-- =====================================

-- Player-related variables
local g_isPlayerPedReady = false
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
local currentWantedLevel = 0
local currentWantedStarsClient = 0
local currentWantedPointsClient = 0
local wantedUiLabel = ""
local lastSpeedCheckTime = 0
local speedLimit = 40.0 -- mph
local lastWantedLevelTime = 0

local xpForNextLevelDisplay = 0

-- Contraband Drop Client State
local activeDropBlips = {}
local clientActiveContrabandDrops = {}

-- Blip tracking
local copStoreBlips = {}
local robberStoreBlips = {}

-- Track protected peds to prevent NPC suppression from affecting them
local g_protectedPolicePeds = {}

-- Track spawned NPCs to prevent duplicates
local g_spawnedNPCs = {}
local g_spawnedVehicles = {}
local g_robberVehiclesSpawned = false

-- Safe Zone Client State
local isCurrentlyInSafeZone = false
local currentSafeZoneName = ""

-- Wanted System Expansion Client State
local currentPlayerNPCResponseEntities = {}
local corruptOfficialNPCs = {}
local currentHelpTextTarget = nil

-- Contraband collection state
local isCollectingFromDrop = nil
local collectionTimerEnd = 0

-- Store UI state
local isCopStoreUiOpen = false
local isRobberStoreUiOpen = false

-- =====================================
--           HELPER FUNCTIONS
-- =====================================

-- Define Log function for consistent logging across client
local function Log(message, level)
    level = level or "info"
    -- Only show critical errors and warnings to reduce spam
    if level == "error" or level == "warn" then
        print("[CNR_CLIENT_CRITICAL] [" .. string.upper(level) .. "] " .. message)
    end
end

-- Helper function to draw text on screen
function DrawText2D(x, y, text, scale, color)
    SetTextFont(4)
    SetTextProportional(false)
    SetTextScale(scale, scale)
    SetTextColour(color[1], color[2], color[3], color[4])
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Helper function to show notifications
local function ShowNotification(text)
    if not text or text == "" then
        print("ShowNotification: Received nil or empty text.")
        return
    end
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawNotification(false, true)
end

-- Helper function to display help text
local function DisplayHelpText(text)
    if not text or text == "" then
        print("DisplayHelpText: Received nil or empty text.")
        return
    end
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Helper function to calculate XP required for next level
function CalculateXpForNextLevelClient(currentLevel, playerRole)
    -- Base XP requirements
    local baseXP = 100
    local multiplier = 1.5
    
    -- Role-specific XP scaling
    local roleMultiplier = 1.0
    if playerRole == "cop" then
        roleMultiplier = 1.2  -- Cops need slightly more XP to level up
    elseif playerRole == "robber" then
        roleMultiplier = 1.0  -- Robbers have standard XP requirements
    end
    
    -- Calculate next level XP requirement: baseXP * (multiplier ^ currentLevel) * roleMultiplier
    return math.floor(baseXP * (multiplier ^ currentLevel) * roleMultiplier)
end

-- Helper function to count table entries
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Helper function to spawn player at role-specific location
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

-- Apply role-specific visual appearance and basic loadout
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
    local modelHash = nil    if newRole == "cop" then
        modelToLoad = "s_m_y_cop_01"
    elseif newRole == "robber" then
        modelToLoad = "mp_m_waremech_01"  -- Changed to warehouse mechanic model
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
        playerWeapons["weapon_stungun"] = true
        playerAmmo["weapon_stungun"] = 5
        print("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: Gave taser to cop.")
    elseif newRole == "robber" then
        local batHash = GetHashKey("weapon_bat")
        GiveWeaponToPed(playerPed, batHash, 1, false, true)
        playerWeapons["weapon_bat"] = true
        playerAmmo["weapon_bat"] = 1
        print("[CNR_CLIENT_DEBUG] ApplyRoleVisualsAndLoadout: Gave bat to robber.")

        -- Note: Robber vehicles are spawned on resource start, not per-player
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

-- Patch: Exclude protected peds from police suppression
local function IsPedProtected(ped)
    return g_protectedPolicePeds[ped] == true
end

-- =====================================
--       WANTED LEVEL NOTIFICATIONS
-- =====================================

-- Handle wanted level notifications from server
AddEventHandler('cnr:showWantedLevel', function(stars, points, level)
    print("[CNR_CLIENT_DEBUG] Showing wanted level notification: " .. stars .. " stars, " .. points .. " points, level " .. level)
    SendNUIMessage({
        action = 'showWantedNotification',
        stars = stars,
        points = points,
        level = level
    })
end)

AddEventHandler('cnr:hideWantedLevel', function()
    print("[CNR_CLIENT_DEBUG] Hiding wanted level notification")
    SendNUIMessage({
        action = 'hideWantedNotification'
    })
end)

AddEventHandler('cnr:updateWantedLevel', function(stars, points, level)
    print("[CNR_CLIENT_DEBUG] Updating wanted level: " .. stars .. " stars, " .. points .. " points, level " .. level)
    SendNUIMessage({
        action = 'showWantedNotification', 
        stars = stars,
        points = points,
        level = level
    })
end)

-- =====================================
--   NPC POLICE SUPPRESSION
-- =====================================

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

-- Unlimited Stamina Thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        local playerPed = PlayerPedId()
        if playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed) then
            RestorePlayerStamina(PlayerId(), 100.0)
        end
    end
end)

-- Inventory Key Binding (M Key)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100) -- Reduced frequency to prevent performance issues
        if IsControlJustPressed(0, Config.Keybinds.openInventory or 244) then -- M Key (INPUT_INTERACTION_MENU)
            print("[CNR_CLIENT_DEBUG] M key pressed, attempting to open inventory")
            local currentResourceName = GetCurrentResourceName()
            print(string.format("[CNR_CLIENT_DEBUG] Current resource name: %s", currentResourceName))

            if exports[currentResourceName] and exports[currentResourceName].ToggleInventoryUI then
                print("[CNR_CLIENT_DEBUG] ToggleInventoryUI export found, calling it")
                exports[currentResourceName]:ToggleInventoryUI()
            else
                print("[CNR_CLIENT_DEBUG] ToggleInventoryUI export not found, using fallback event")
                -- Fallback: try to trigger inventory event
                TriggerEvent('cnr:openInventory')
            end
        end
    end
end)

-- Register the inventory commands that are missing
RegisterCommand('getweapons', function()
    local currentResourceName = GetCurrentResourceName()
    if exports[currentResourceName] and exports[currentResourceName].EquipInventoryWeapons then
        exports[currentResourceName]:EquipInventoryWeapons()
        print("[CNR_CLIENT] Weapons equipped from inventory")
    else
        print("[CNR_CLIENT_ERROR] EquipInventoryWeapons export not found")
    end
end, false)

RegisterCommand('equipweapns', function()
    local currentResourceName = GetCurrentResourceName()
    if exports[currentResourceName] and exports[currentResourceName].EquipInventoryWeapons then
        exports[currentResourceName]:EquipInventoryWeapons()
        print("[CNR_CLIENT] Weapons equipped from inventory")
    else
        print("[CNR_CLIENT_ERROR] EquipInventoryWeapons export not found")
    end
end, false)

-- =====================================
--       WANTED LEVEL DETECTION SYSTEM
-- =====================================

-- Wanted Level Detection Thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second
        
        local playerPed = PlayerPedId()
        if playerPed and playerPed ~= 0 and playerPed ~= -1 and DoesEntityExist(playerPed) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                local speed = GetEntitySpeed(vehicle) * 2.236936 -- Convert m/s to mph
                local currentTime = GetGameTimer()
                
                -- Check for speeding (increase wanted level)
                if speed > speedLimit and (currentTime - lastWantedLevelTime) > 5000 then -- 5 second cooldown
                    if currentWantedLevel < 5 then
                        currentWantedLevel = currentWantedLevel + 1
                        lastWantedLevelTime = currentTime
                        TriggerEvent('cnr:updateWantedLevel', currentWantedLevel)
                        ShowNotification("~r~Wanted Level Increased: " .. currentWantedLevel .. " star" .. (currentWantedLevel > 1 and "s" or ""))
                        print(string.format("[CNR_CLIENT_DEBUG] Wanted level increased to %d due to speeding (%.1f mph)", currentWantedLevel, speed))
                    end
                end
            end
              -- Decrease wanted level over time when not committing crimes (check outside vehicle too)
            local currentTime = GetGameTimer()
            if currentWantedLevel > 0 and (currentTime - lastWantedLevelTime) > 30000 then -- 30 seconds without new crimes
                currentWantedLevel = math.max(0, currentWantedLevel - 1)
                lastWantedLevelTime = currentTime
                TriggerEvent('cnr:updateWantedLevel', currentWantedLevel)
                if currentWantedLevel > 0 then
                    ShowNotification("~y~Wanted Level Decreased: " .. currentWantedLevel .. " star" .. (currentWantedLevel > 1 and "s" or ""))
                else
                    ShowNotification("~g~Wanted Level Cleared")
                end
                print(string.format("[CNR_CLIENT_DEBUG] Wanted level decreased to %d", currentWantedLevel))
            end
        end
    end
end)

-- =====================================
--          MISSING KEYBINDS
-- =====================================

-- F2 - Robber Menu / Admin Panel
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if IsControlJustPressed(0, Config.Keybinds.toggleAdminPanel or 289) then -- F2
            -- Check if player is admin first, otherwise show robber menu
            TriggerServerEvent('cnr:checkAdminStatus')
        end
    end
end)

-- F5 - Role Selection Menu
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if IsControlJustPressed(0, 166) then -- F5 key
            print("[CNR_CLIENT_DEBUG] F5 pressed - opening role selection")
            TriggerEvent('cnr:showRoleSelection')
        end
    end
end)

-- Event handlers for admin status check
AddEventHandler('cnr:showAdminPanel', function()
    -- Show admin panel UI
    SendNUIMessage({
        action = 'showAdminPanel'
    })
    SetNuiFocus(true, true)
end)

AddEventHandler('cnr:showRobberMenu', function()
    -- Show robber-specific menu
    SendNUIMessage({
        action = 'showRobberMenu'
    })
    SetNuiFocus(true, true)
end)

-- =====================================
--           STORE BLIP MANAGEMENT
-- =====================================

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

-- =====================================
--           NPC MANAGEMENT
-- =====================================

-- Helper to spawn the Cop Store ped and protect it from suppression
function SpawnCopStorePed()
    -- Check if already spawned
    if g_spawnedNPCs["CopStore"] then
        return
    end

    local vendor = nil
    if Config and Config.NPCVendors then
        for _, v in ipairs(Config.NPCVendors) do
            if v.name == "Cop Store" then
                vendor = v
                break
            end
        end
    end
    if not vendor then
        print("[CNR_CLIENT_ERROR] Cop Store vendor not found in Config.NPCVendors")
        return
    end

    local model = GetHashKey("s_m_m_ciasec_01") -- Use a unique cop-like model not used by NPC police
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(10) end

    -- Handle both vector3 and vector4 formats for location
    local x, y, z, heading
    if vendor.location.w then
        -- vector4 format
        x, y, z, heading = vendor.location.x, vendor.location.y, vendor.location.z, vendor.location.w
    else
        -- vector3 format with separate heading
        x, y, z = vendor.location.x, vendor.location.y, vendor.location.z
        heading = vendor.heading or 0.0
    end

    local ped = CreatePed(4, model, x, y, z - 1.0, heading, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false) -- Corrected: use boolean false
    SetPedCombatAttributes(ped, 17, true) -- Corrected: use boolean true
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    g_protectedPolicePeds[ped] = true
    g_spawnedNPCs["CopStore"] = ped
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
            -- Check if already spawned
            if g_spawnedNPCs[vendor.name] then
                goto continue
            end
              local modelHash = GetHashKey(vendor.model or "s_m_y_dealer_01")
            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do
                Citizen.Wait(10)
            end

            -- Handle both vector3 and vector4 formats for location
            local x, y, z, heading
            if vendor.location.w then
                -- vector4 format
                x, y, z, heading = vendor.location.x, vendor.location.y, vendor.location.z, vendor.location.w
            else
                -- vector3 format with separate heading
                x, y, z = vendor.location.x, vendor.location.y, vendor.location.z
                heading = vendor.heading or 0.0
            end

            local ped = CreatePed(4, modelHash, x, y, z - 1.0, heading, false, true)
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
            g_spawnedNPCs[vendor.name] = ped

            print(string.format("[CNR_CLIENT_DEBUG] Spawned and protected %s ped at %s", vendor.name, tostring(vendor.location)))

            ::continue::
        end
    end
end

-- Vehicle spawning system for robbers
function SpawnRobberVehicles()
    -- Prevent multiple spawning
    if g_robberVehiclesSpawned then
        print("[CNR_CLIENT_DEBUG] Robber vehicles already spawned, skipping")
        return
    end

    if not Config or not Config.RobberVehicleSpawns then
        print("[CNR_CLIENT_ERROR] SpawnRobberVehicles: Config.RobberVehicleSpawns not found")
        return
    end

    print("[CNR_CLIENT_DEBUG] Spawning robber vehicles...")
    g_robberVehiclesSpawned = true

    for _, vehicleSpawn in ipairs(Config.RobberVehicleSpawns) do
        if vehicleSpawn.location and vehicleSpawn.model then
            local modelHash = GetHashKey(vehicleSpawn.model)
            RequestModel(modelHash)

            -- Wait for model to load
            local attempts = 0
            while not HasModelLoaded(modelHash) and attempts < 100 do
                Citizen.Wait(50)
                attempts = attempts + 1
            end
              if HasModelLoaded(modelHash) then
                -- Handle both vector3 and vector4 formats
                local x, y, z, heading
                if vehicleSpawn.location.w then
                    -- vector4 format
                    x, y, z, heading = vehicleSpawn.location.x, vehicleSpawn.location.y, vehicleSpawn.location.z, vehicleSpawn.location.w
                else
                    -- vector3 format with separate heading
                    x, y, z = vehicleSpawn.location.x, vehicleSpawn.location.y, vehicleSpawn.location.z
                    heading = vehicleSpawn.heading or 0.0
                end

                local vehicle = CreateVehicle(
                    modelHash,
                    x, y, z,
                    heading,
                    true, -- isNetwork
                    false -- netMissionEntity
                )

                if vehicle and DoesEntityExist(vehicle) then
                    -- Make vehicle available and persistent
                    SetEntityAsMissionEntity(vehicle, true, true)
                    SetVehicleOnGroundProperly(vehicle)
                    SetVehicleEngineOn(vehicle, false, true, false)
                    SetVehicleDoorsLocked(vehicle, 1) -- Unlocked
                    print(string.format("[CNR_CLIENT_DEBUG] Spawned robber vehicle %s at %s", vehicleSpawn.model, tostring(vehicleSpawn.location)))
                else
                    print(string.format("[CNR_CLIENT_ERROR] Failed to create vehicle %s", vehicleSpawn.model))
                end
            else
                print(string.format("[CNR_CLIENT_ERROR] Failed to load model %s after 100 attempts", vehicleSpawn.model))
            end

            SetModelAsNoLongerNeeded(modelHash)
        end
    end
end

-- Call this on resource start and when player spawns
Citizen.CreateThread(function()
    Citizen.Wait(2000)
    SpawnCopStorePed()
    SpawnRobberStorePeds()
    SpawnRobberVehicles() -- Added vehicle spawning for robbers
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
    local newUiLabel = ""    if stars > 0 then
        for _, levelData in ipairs(Config.WantedSettings.levels) do
            if levelData.stars == stars then
                newUiLabel = levelData.uiLabel
                break
            end
        end
        if newUiLabel == "" then newUiLabel = "Wanted: " .. string.rep("*", stars) end
    end
    wantedUiLabel = newUiLabel
    SetWantedLevelForPlayerRole(stars, points)
end)

-- =====================================
--           NUI CALLBACKS
-- =====================================

-- NUI Callback for Role Selection
RegisterNUICallback('selectRole', function(data, cb)
    if not data or not data.role then
        cb({ success = false, error = "Invalid role data received" })
        return
    end
    
    local selectedRole = data.role
    if selectedRole ~= "cop" and selectedRole ~= "robber" then
        cb({ success = false, error = "Invalid role selected" })
        return
    end
    
    -- Send role selection to server
    TriggerServerEvent('cnr:selectRole', selectedRole)
    
    -- Hide the UI
    SetNuiFocus(false, false)
    
    -- Return success to NUI
    cb({ success = true })
end)

-- =====================================
--           EVENT HANDLERS
-- =====================================

-- Event handler for showing role selection UI
RegisterNetEvent('cnr:showRoleSelection')
AddEventHandler('cnr:showRoleSelection', function()
    SendNUIMessage({ 
        action = 'showRoleSelection', 
        resourceName = GetCurrentResourceName() 
    })
    SetNuiFocus(true, true)
end)
