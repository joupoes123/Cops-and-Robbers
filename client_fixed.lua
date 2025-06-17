-- client.lua
-- Cops & Robbers FiveM Game Mode - Client Script
-- Version: 1.2 | Date: <current date>
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

-- _G.cnrSetDispatchServiceErrorLogged = false -- Removed as part of subtask
local g_isPlayerPedReady = false

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

-- Helper function to show notifications
function ShowNotification(msg)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
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

-- Inventory Key Binding (I Key)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100) -- Reduced frequency to prevent performance issues
        if IsControlJustPressed(0, Config.Keybinds.openInventory or 244) then -- M Key (INPUT_INTERACTION_MENU)
            print("[CNR_CLIENT_DEBUG] I key pressed, attempting to open inventory")
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

local currentWantedLevel = 0
local lastSpeedCheckTime = 0
local speedLimit = 40.0 -- mph
local lastWantedLevelTime = 0

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
RegisterNetEvent('cnr:showAdminPanel')
AddEventHandler('cnr:showAdminPanel', function()
    -- Show admin panel UI
    SendNUIMessage({
        action = 'showAdminPanel'
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('cnr:showRobberMenu')
AddEventHandler('cnr:showRobberMenu', function()
    -- Show robber-specific menu
    SendNUIMessage({
        action = 'showRobberMenu'
    })
    SetNuiFocus(true, true)
end)

-- =====================================
--           ROLE MANAGEMENT
-- =====================================

-- Handle role selection from NUI
RegisterNUICallback("selectRole", function(data, cb)
    if data and data.role then
        print("[CNR_CLIENT_DEBUG] Role selected from NUI: " .. data.role)
        TriggerServerEvent('cops_and_robbers:selectRole', data.role)
        cb({ success = true })
    else
        print("[CNR_CLIENT_ERROR] Invalid role selection data from NUI")
        cb({ success = false, error = "Invalid role data" })
    end
end)

-- Handle NUI focus changes
RegisterNUICallback("setNuiFocus", function(data, cb)
    if data and type(data.hasFocus) == "boolean" and type(data.hasCursor) == "boolean" then
        SetNuiFocus(data.hasFocus, data.hasCursor)
        cb({ success = true })
    else
        cb({ success = false, error = "Invalid focus data" })
    end
end)

-- =====================================
--         STORE SYSTEM
-- =====================================

-- Handle item list from server and open Store NUI
RegisterNetEvent('cops_and_robbers:sendItemList')
AddEventHandler('cops_and_robbers:sendItemList', function(storeName, items, playerInfo)
    print("[CNR_CLIENT_DEBUG] Received item list for " .. storeName .. ". Item count: " .. (items and #items or 0))
    
    -- Ensure fullItemConfig is sent to NUI before opening store
    if not GetClientConfigItems() then
        print("[CNR_CLIENT_DEBUG] Config.Items not available yet, requesting from server before opening store")
        TriggerServerEvent('cnr:requestConfigItems')
        
        -- Wait a moment for config to arrive
        Citizen.Wait(200)
    else
        print("[CNR_CLIENT_DEBUG] Config.Items already available for store")
    end
    
    if storeName == "Cop Store" then
        print("[CNR_CLIENT_DEBUG] Opening Cop Store UI")
        isCopStoreUiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openStore', storeName = storeName, items = items, playerInfo = playerInfo })
    elseif storeName == "Black Market Dealer" or storeName == "Gang Supplier" then
        print("[CNR_CLIENT_DEBUG] Opening " .. storeName .. " UI")
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
    print("[CNR_CLIENT_DEBUG] NUI getPlayerInventory callback triggered")
    local responded = false
    local handler
    handler = AddEventHandler('cops_and_robbers:sendPlayerInventory', function(inv)
        if responded then 
            print("[CNR_CLIENT_DEBUG] getPlayerInventory response already sent, ignoring duplicate")
            return 
        end
        responded = true
        RemoveEventHandler(handler)
        print("[CNR_CLIENT_DEBUG] Received inventory from server for NUI. Item count: " .. (inv and #inv or 0))
        cb({ inventory = inv or {} })
    end)
    
    print("[CNR_CLIENT_DEBUG] Triggering getPlayerInventory server event")
    TriggerServerEvent('cops_and_robbers:getPlayerInventory')
    
    -- Timeout handler
    Citizen.SetTimeout(3000, function()
        if not responded then
            print("[CNR_CLIENT_ERROR] getPlayerInventory timeout - no response from server after 3 seconds")
            responded = true
            RemoveEventHandler(handler)
            cb({ inventory = {}, error = "Timeout: No response from server" })
        end
    end)
end)

-- Handle buyItem from NUI
RegisterNUICallback("buyItem", function(data, cb)
    if not data or not data.itemId or not data.quantity then
        cb({ success = false, error = "Invalid buy request" })
        return
    end
    
    print(string.format("[CNR_CLIENT_DEBUG] Buying item: %s x%d", data.itemId, data.quantity))
    
    local responded = false
    local handler = AddEventHandler('cops_and_robbers:buyResult', function(success, message, newCash)
        if responded then return end
        responded = true
        RemoveEventHandler(handler)
        cb({ success = success, message = message, newCash = newCash })
    end)
    
    TriggerServerEvent('cops_and_robbers:buyItem', data.itemId, data.quantity)
    
    -- Timeout
    Citizen.SetTimeout(5000, function()
        if not responded then
            responded = true
            RemoveEventHandler(handler)
            cb({ success = false, error = "Purchase request timed out" })
        end
    end)
end)

-- Handle sellItem from NUI
RegisterNUICallback("sellItem", function(data, cb)
    if not data or not data.itemId or not data.quantity then
        cb({ success = false, error = "Invalid sell request" })
        return
    end
    
    print(string.format("[CNR_CLIENT_DEBUG] Selling item: %s x%d", data.itemId, data.quantity))
    
    local responded = false
    local handler = AddEventHandler('cops_and_robbers:sellResult', function(success, message, newCash)
        if responded then return end
        responded = true
        RemoveEventHandler(handler)
        cb({ success = success, message = message, newCash = newCash })
        
        -- Refresh inventory in NUI after successful sell
        if success then
            SendNUIMessage({ action = 'refreshInventory' })
        end
    end)
    
    TriggerServerEvent('cops_and_robbers:sellItem', data.itemId, data.quantity)
    
    -- Timeout
    Citizen.SetTimeout(5000, function()
        if not responded then
            responded = true
            RemoveEventHandler(handler)
            cb({ success = false, error = "Sell request timed out" })
        end
    end)
end)

-- Function to calculate table length
function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Function to calculate XP for next level on client (simplified)
function CalculateXpForNextLevelClient(currentLevel, playerRole)
    local baseXp = 100
    local multiplier = 1.5
    return math.floor(baseXp * (multiplier ^ (currentLevel - 1)))
end

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
