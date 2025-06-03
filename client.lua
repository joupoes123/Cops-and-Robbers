-- client.lua
-- Cops & Robbers FiveM Game Mode - Client Script
-- Version: 1.1 | Date: 2025-02-11
-- This file handles client-side functionality including UI notifications,
-- role selection, vendor interactions, spawning, and other game-related events.

-- =====================================
--           CONFIGURATION
-- =====================================

-- Config is loaded from shared_scripts 'config.lua'

-- =====================================
--           VARIABLES
-- =====================================

-- Player-related variables
local role = nil                        -- Current player role ('cop', 'robber', or nil)
local playerCash = 0                    -- Current player cash
local currentSpikeStrips = {}           -- Table to store client-side spike strip entities: { [stripId] = { entity = prop_entity, location = vector3, obj = objHandle } }
local spikeStripModelHash = GetHashKey("p_ld_stinger_s") -- Model hash for spike strips
local playerStats = {                   -- Basic player statistics (legacy, new data in playerData)
    heists = 0,
    arrests = 0,
    rewards = 0
    -- experience and level are now part of playerData
}
local currentObjective = nil            -- Current objective for the player (not heavily used in provided code)
local playerWeapons = {}                -- Tracks weapons the player currently possesses (client-side perception) e.g. { ["WEAPON_PISTOL"] = true }
local playerAmmo = {}                   -- Tracks ammo counts for weapons (client-side perception) e.g. { ["WEAPON_PISTOL"] = 50 }

-- Player Data (Synced from Server)
local playerData = {
    xp = 0,
    level = 1,
    role = "citizen",
    perks = {},
    armorModifier = 1.0,
    money = 0 -- Can be part of playerData or separate like playerCash
}

-- Wanted System Client State
local currentWantedStarsClient = 0      -- Current number of wanted stars for the player (0-5)
local currentWantedPointsClient = 0     -- Current wanted points (numerical value, used for decay/increase)
local wantedUiLabel = ""                -- Text label for UI display of wanted status (e.g., "Wanted: ***")

-- Player Leveling System Client State (now mostly derived from playerData)
-- local currentXP = 0                  -- DEPRECATED: Use playerData.xp
-- local currentLevel = 1               -- DEPRECATED: Use playerData.level
local xpForNextLevelDisplay = 0         -- XP needed to reach the next level (used for UI progress bar) - This can still be useful

-- Contraband Drop Client State
local activeDropBlips = {}              -- Stores blip handles for active contraband drops, keyed by dropId: { [dropId] = blipHandle }
local clientActiveContrabandDrops = {}  -- Stores detailed info about client-side contraband drops, keyed by dropId: { [dropId] = { id, location, name, modelHash, propEntity } }
local isCollectingFromDrop = nil        -- Holds the dropId if the player is currently collecting from a drop, otherwise nil
local collectionTimerEnd = 0            -- Timestamp (GetGameTimer()) for when the current contraband collection process will end

-- Safe Zone Client State
local isCurrentlyInSafeZone = false     -- Boolean flag indicating if the player is currently inside any safe zone
local currentSafeZoneName = ""          -- Name of the safe zone the player is currently in

-- Wanted System Expansion Client State
local currentPlayerNPCResponseEntities = {} -- Stores peds and vehicles for current player's NPC response: { pedOrVehHandle, ... }
local corruptOfficialNPCs = {}          -- Stores spawned peds for corrupt officials, keyed by officialIndex from config: { [officialIndex] = pedHandle }

-- =====================================
--           HELPER FUNCTIONS
-- =====================================

-- Function to display notifications on screen
-- @param text string: The message to display.
local function ShowNotification(text)
    if not text or text == "" then
        print("ShowNotification: Received nil or empty text.")
        return
    end
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawNotification(false, true)
end

-- Function to display help text (on-screen prompt)
-- @param text string: The help message to display.
local function DisplayHelpText(text)
    if not text or text == "" then
        print("DisplayHelpText: Received nil or empty text.")
        return
    end
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Function to spawn player at a predefined point based on their role
-- @param playerRole string: The role of the player ('cop' or 'robber').
local function spawnPlayer(playerRole)
    if not playerRole then
        print("Error: spawnPlayer called with nil role.")
        ShowNotification("~r~Error: Could not determine spawn point. Role not set.")
        return
    end
    local spawnPoint = Config.SpawnPoints[playerRole]
    if spawnPoint and spawnPoint.x and spawnPoint.y and spawnPoint.z then
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, spawnPoint.x, spawnPoint.y, spawnPoint.z, false, false, false, true)
        -- SetEntityHeading(playerPed, spawnPoint.h or 0.0) -- Consider adding heading to config if desired
        ShowNotification("Spawned as " .. playerRole)
    else
        print("Error: Invalid or missing spawn point for role: " .. tostring(playerRole))
        ShowNotification("~r~Error: Spawn point not found for your role.")
    end
end

-- =====================================
--           NETWORK EVENTS
-- =====================================

-- Event: 'playerSpawned' - Triggered when the player initially spawns into the server.
-- Action: Requests player data from the server and shows the role selection UI.
AddEventHandler('playerSpawned', function()
    -- Request player data from the server. This might include role, cash, stats etc. if previously saved.
    TriggerServerEvent('cops_and_robbers:requestPlayerData')
    
    -- Show NUI role selection screen
    -- Ensure NUI is ready before sending messages, or have a queue system in NUI's JS.
    SendNUIMessage({ action = 'showRoleSelection' })
    SetNuiFocus(true, true) -- Give focus to NUI for role selection
end)

-- Event: 'cnr:updatePlayerData' - Receives comprehensive player data from the server.
-- Action: Updates client-side variables with received data, spawns player if role changes, and equips weapons if needed.
RegisterNetEvent('cnr:updatePlayerData')
AddEventHandler('cnr:updatePlayerData', function(newPlayerData)
    if not newPlayerData then
        print("Error: 'cnr:updatePlayerData' received nil data.")
        ShowNotification("~r~Error: Failed to load player data.")
        return
    end

    local oldRole = playerData.role
    playerData = newPlayerData -- Overwrite local playerData with the new comprehensive data from server

    -- Update legacy variables for compatibility or if still used by some UI parts
    playerCash = newPlayerData.money or (QBCore and QBCore.Functions.GetPlayerData().money.cash) or 0 -- Fallback if money not in playerData
    role = playerData.role -- Update global 'role' variable

    if role and oldRole ~= role then -- Spawn if role changed significantly
        spawnPlayer(role)
    elseif not oldRole and role then -- First time role is set
        spawnPlayer(role)
    end

    -- Update UI elements
    SendNUIMessage({ action = 'updateMoney', cash = playerCash })
    SendNUIMessage({
        action = "updateXPBar",
        currentXP = playerData.xp,
        currentLevel = playerData.level,
        xpForNextLevel = CalculateXpForNextLevelClient(playerData.level, playerData.role) -- Calculate or get from server
    })
    ShowNotification(string.format("Data Synced: Lvl %d, XP %d, Role %s", playerData.level, playerData.xp, playerData.role), "info", 2000)

    -- Weapon handling can be complex; server should be source of truth.
    -- This basic version just ensures weapons listed in playerData are given.
    -- A more robust system would diff current weapons against playerData.weapons.
    -- For now, let's assume server sends this event AFTER giving weapons if they change.
    -- Or, if playerData contains a 'weapons' table:
    if newPlayerData.weapons and type(newPlayerData.weapons) == "table" then
        local playerPed = PlayerPedId()
        playerWeapons = {} -- Clear existing client-side weapon list
        playerAmmo = {}    -- Clear existing client-side ammo list
        for weaponName, ammoCount in pairs(newPlayerData.weapons) do
            local weaponHash = GetHashKey(weaponName)
            if weaponHash ~= 0 and weaponHash ~= -1 then
                GiveWeaponToPed(playerPed, weaponHash, ammoCount or 0, false, false)
                playerWeapons[weaponName] = true
                playerAmmo[weaponName] = ammoCount or 0
            else
                print("Warning: Invalid weaponName received in newPlayerData: " .. tostring(weaponName))
            end
        end
    end
end)

-- Helper function to calculate XP needed for next level (client-side display approximation)
-- Server's CalculateLevel is the source of truth. This is for UI.
function CalculateXpForNextLevelClient(currentLevel, playerRole)
    if not Config.LevelingSystemEnabled then return 999999 end

    local maxLvl = Config.MaxLevel or 10
    if currentLevel >= maxLvl then
        return playerData.xp -- Or a specific value/string indicating max level achieved
    end

    if Config.XPTable and Config.XPTable[currentLevel] then
        return Config.XPTable[currentLevel]
    else
        print("CalculateXpForNextLevelClient: XP requirement for level " .. currentLevel .. " not found in Config.XPTable. Returning high value.", "warn") -- Changed Log to print
        return 999999 -- Fallback if XP for next level is not defined
    end
end


-- =====================================
--        PLAYER LEVELING SYSTEM (CLIENT) - Mostly Handled by cnr:updatePlayerData
-- =====================================

-- This event is kept for direct XP gain notifications if server sends them separately.
RegisterNetEvent('cnr:xpGained')
AddEventHandler('cnr:xpGained', function(amount, newTotalXp)
    playerData.xp = newTotalXp
    ShowNotification(string.format("~g~+%d XP! (Total: %d)", amount, newTotalXp), "info", 3000)
    SendNUIMessage({
        action = "updateXPBar",
        currentXP = playerData.xp,
        currentLevel = playerData.level,
        xpForNextLevel = CalculateXpForNextLevelClient(playerData.level, playerData.role)
    })
end)

-- This event is kept for direct Level Up notifications if server sends them separately.
RegisterNetEvent('cnr:levelUp')
AddEventHandler('cnr:levelUp', function(newLevel, newTotalXp)
    playerData.level = newLevel
    playerData.xp = newTotalXp -- XP might reset or be adjusted on level up by server
    ShowNotification("~g~LEVEL UP!~w~ You reached Level " .. newLevel .. "!", "success", 10000)
    SendNUIMessage({
        action = "updateXPBar",
        currentXP = playerData.xp,
        currentLevel = playerData.level,
        xpForNextLevel = CalculateXpForNextLevelClient(playerData.level, playerData.role)
    })
    -- Server's cnr:updatePlayerData will follow with full perk updates etc.
end)


-- =====================================
--        WANTED SYSTEM (CLIENT)
-- =====================================
-- Wanted System: Update wanted level display
RegisterNetEvent('cops_and_robbers:updateWantedDisplay')
AddEventHandler('cops_and_robbers:updateWantedDisplay', function(stars, points)
    currentWantedStarsClient = stars
    currentWantedPointsClient = points

    local newUiLabel = ""
    if stars > 0 then
        for _, levelData in ipairs(Config.WantedSettings.levels) do
            if levelData.stars == stars then
                newUiLabel = levelData.uiLabel
                break
            end
        end
        if newUiLabel == "" then -- Fallback if label not found for star count, though config should cover it
            newUiLabel = "Wanted: " .. string.rep("*", stars)
        end
    else
        newUiLabel = "" -- Or "Not Wanted"
    end
    wantedUiLabel = newUiLabel

    -- Update native FiveM wanted level display
    SetPlayerWantedLevel(PlayerId(), stars, false)
    SetPlayerWantedLevelNow(PlayerId(), false) -- Apply immediately without delay/fade

    -- If you had a custom UI element for wanted level, you'd update it here.
    -- Example: SendNUIMessage({ action = 'updateWantedUI', label = wantedUiLabel, points = currentWantedPointsClient })
    -- ShowNotification("Wanted Level: " .. wantedUiLabel .. " (" .. currentWantedPointsClient .. " pts)") -- For debugging
end)

-- Handles server-triggered updates to NPC police response based on wanted level.
RegisterNetEvent('cops_and_robbers:wantedLevelResponseUpdate')
AddEventHandler('cops_and_robbers:wantedLevelResponseUpdate', function(targetPlayerId, stars, points, lastKnownCoords)
    if targetPlayerId ~= PlayerId() then return end -- Only process for this client if they are the target.

    -- 1. Clear previously spawned NPC response groups for this player
    for _, entity in ipairs(currentPlayerNPCResponseEntities) do
        if DoesEntityExist(entity) then
            local model = GetEntityModel(entity)
            DeleteEntity(entity)
            SetModelAsNoLongerNeeded(model) -- Release model
        end
    end
    currentPlayerNPCResponseEntities = {}

    if stars == 0 then -- No wanted level, no response needed beyond clearing old ones.
        ShowNotification("~g~Police response stood down.")
        return
    end

    ShowNotification(string.format("~y~Wanted Level: %d star(s). (NPC response disabled)", stars)) -- Modified by subtask

    local presetStarLevel = math.min(stars, #Config.WantedNPCPresets)
    if not Config.WantedNPCPresets[presetStarLevel] then
        print("No NPC response preset found for effective wanted level: " .. presetStarLevel)
        return
    end

    local responseGroupsConfig = Config.WantedNPCPresets[presetStarLevel]
    local playerPed = PlayerPedId()
    local activeSpawnedGroupsCount = 0 -- Track how many groups successfully spawn from this response wave

    for _, groupInfo in ipairs(responseGroupsConfig) do
        if activeSpawnedGroupsCount >= Config.MaxActiveNPCResponseGroups then
            print("Max active NPC response groups reached for this wave.")
            break
        end

        --vvv-- NPC Spawning Loop Disabled by Subtask --vvv--
        -- The following loop responsible for spawning NPC response units has been commented out.
        -- if Config.MaxActiveNPCResponseGroups == 0 then print("NPC responses globally disabled via MaxActiveNPCResponseGroups=0 in config.") end
        --[[ CreateThread(function() -- Spawn each group in its own thread for model loading
            local groupEntitiesThisSpawn = {} -- Track entities for this specific group for timed removal
            local vehicle = nil
            local actualSpawnPos = vector3(lastKnownCoords.x, lastKnownCoords.y, lastKnownCoords.z) -- Use last known coords as base

            -- Determine spawn position (further away, try for roadside)
            local spawnOffsetAttempt = vector3(math.random(70,120) * (math.random(0,1)*2-1) + 0.01, math.random(70,120) * (math.random(0,1)*2-1) + 0.01, 2.0)
            local foundSpawn, safeSpawnPos = GetSafeCoordForPed(actualSpawnPos + spawnOffsetAttempt, true, 0)
            if not foundSpawn then
                foundSpawn, safeSpawnPos = GetSafeRoadsideCoords(actualSpawnPos + spawnOffsetAttempt, 15.0)
            end
            if foundSpawn then actualSpawnPos = safeSpawnPos else actualSpawnPos = actualSpawnPos + vector3(0,0,1.0) end


            -- Handle helicopter chance
            if groupInfo.helicopterChance and groupInfo.helicopter and math.random() < groupInfo.helicopterChance then
                local heliModel = (type(groupInfo.helicopter) == "number" and groupInfo.helicopter) or GetHashKey(groupInfo.helicopter)
                RequestModel(heliModel)
                local attempts = 0; while not HasModelLoaded(heliModel) and attempts < 50 do Citizen.Wait(50); attempts = attempts + 1 end
                if HasModelLoaded(heliModel) then
                    vehicle = CreateVehicle(heliModel, actualSpawnPos.x, actualSpawnPos.y, actualSpawnPos.z + 50.0, GetEntityHeading(playerPed), true, false)
                    SetModelAsNoLongerNeeded(heliModel)
                    table.insert(groupEntitiesThisSpawn, vehicle)
                    table.insert(currentPlayerNPCResponseEntities, vehicle)
                else SetModelAsNoLongerNeeded(heliModel); print("Failed to load helicopter model: " .. groupInfo.helicopter) end
            elseif groupInfo.vehicle then
                local vehicleModel = (type(groupInfo.vehicle) == "number" and groupInfo.vehicle) or GetHashKey(groupInfo.vehicle)
                RequestModel(vehicleModel)
                local attempts = 0; while not HasModelLoaded(vehicleModel) and attempts < 50 do Citizen.Wait(50); attempts = attempts + 1 end
                if HasModelLoaded(vehicleModel) then
                    vehicle = CreateVehicle(vehicleModel, actualSpawnPos.x, actualSpawnPos.y, actualSpawnPos.z, GetEntityHeading(playerPed) + 180.0, true, false)
                    SetModelAsNoLongerNeeded(vehicleModel)
                    table.insert(groupEntitiesThisSpawn, vehicle)
                    table.insert(currentPlayerNPCResponseEntities, vehicle)
                else SetModelAsNoLongerNeeded(vehicleModel); print("Failed to load vehicle model: " .. groupInfo.vehicle) end
            end

            local weaponHash = (type(groupInfo.weapon) == "number" and groupInfo.weapon) or GetHashKey(groupInfo.weapon)
            local pedModelHash = (type(groupInfo.pedModel) == "number" and groupInfo.pedModel) or GetHashKey(groupInfo.pedModel or "s_m_y_cop_01") -- Default to cop if not specified

            RequestModel(pedModelHash)
            local attempts = 0; while not HasModelLoaded(pedModelHash) and attempts < 50 do Citizen.Wait(50); attempts = attempts + 1 end

            if HasModelLoaded(pedModelHash) then
                for i = 1, groupInfo.count do
                    local ped
                    if vehicle and i <= GetVehicleMaxNumberOfPassengers(vehicle) then
                        local seat = -1 + (i-1) -- Driver first, then passengers
                        if GetPedInVehicleSeat(vehicle, seat) == 0 then -- Check if seat is free
                           ped = CreatePedInsideVehicle(vehicle, 26, pedModelHash, seat, true, false)
                        end
                    else
                        ped = CreatePed(26, pedModelHash, actualSpawnPos.x + math.random(-5,5), actualSpawnPos.y + math.random(-5,5), actualSpawnPos.z, GetEntityHeading(playerPed), true, false)
                    end

                    if ped then
                        GiveWeaponToPed(ped, weaponHash, 250, false, true)
                        SetPedArmour(ped, groupInfo.armour or 25)
                        SetPedAccuracy(ped, groupInfo.accuracy or 15)
                        SetPedCombatAttributes(ped, 46, true) -- BF_CanFightArmedPedsWhenNotArmed
                        if groupInfo.combatAttributes then
                           for attrId, valBool in pairs(groupInfo.combatAttributes) do SetPedCombatAttributes(ped, attrId, valBool) end
                        end
                        SetPedSeeingRange(ped, groupInfo.sightDistance or 80.0)
                        SetEntityIsTargetPriority(ped, true, 0)
                        SetPedRelationshipGroupHash(ped, GetHashKey("COP")) -- Make them part of cop group

                        if vehicle and GetPedInVehicleSeat(vehicle, -1) == ped then -- If this ped is the driver
                            TaskVehicleDriveToCoord(ped, vehicle, GetEntityCoords(playerPed).x, GetEntityCoords(playerPed).y, GetEntityCoords(playerPed).z, 25.0, 1, GetHashKey(Config.PoliceVehicles[1] or "police"), 786603, 10.0, -1)
                            SetPedKeepTask(ped, true)
                        else -- Passenger or on foot
                            TaskCombatPed(ped, playerPed, 0, 16)
                        end
                        table.insert(groupEntitiesThisSpawn, ped)
                        table.insert(currentPlayerNPCResponseEntities, ped)
                    end
                end
            end
            SetModelAsNoLongerNeeded(pedModelHash)
            activeSpawnedGroupsCount = activeSpawnedGroupsCount + 1

            -- Simple despawn timer for this specific group's entities
            Citizen.Wait(180000) -- Despawn after 3 minutes
            for _, entityToClean in pairs(groupEntitiesThisSpawn) do
                if DoesEntityExist(entityToClean) then
                    for k, trackedEntity in pairs(currentPlayerNPCResponseEntities) do
                        if trackedEntity == entityToClean then table.remove(currentPlayerNPCResponseEntities, k); break end
                    end
                    local model = GetEntityModel(entityToClean)
                    DeleteEntity(entityToClean)
                    SetModelAsNoLongerNeeded(model)
                end
            end
            -- print("NPC Response group (part) despawned after timeout: " .. groupInfo.spawnGroup)
        end) --]]
        --^^^-- NPC Spawning Loop Disabled by Subtask --^^^--
    end
end)

-----------------------------------------------------------
-- Contraband Drop Client Events and Logic
-----------------------------------------------------------
-- Event handler for when a new contraband drop is spawned by the server.
-- Creates a blip, potentially a prop, and stores drop info.
RegisterNetEvent('cops_and_robbers:contrabandDropSpawned')
AddEventHandler('cops_and_robbers:contrabandDropSpawned', function(dropId, location, itemName, itemModelHash)
    if activeDropBlips[dropId] then -- Defensively remove old blip if ID somehow reused before cleanup
        RemoveBlip(activeDropBlips[dropId])
    end

    local blip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(blip, 1) -- Default blip sprite, can be changed (e.g., 478 for package)
    SetBlipColour(blip, 2) -- Red, for example
    SetBlipScale(blip, 1.5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Contraband: " .. itemName)
    EndTextCommandSetBlipName(blip)

    activeDropBlips[dropId] = blip

    local propEntity = nil
    if itemModelHash then
        local model = (type(itemModelHash) == "number" and itemModelHash) or GetHashKey(itemModelHash)
        if HasModelLoaded(model) then
            propEntity = CreateObject(model, location.x, location.y, location.z - 0.9, false, true, true) -- No network, yes physics, dynamic
            PlaceObjectOnGroundProperly(propEntity)
        else
            RequestModel(model)
            CreateThread(function()
                local attempts = 0
                while not HasModelLoaded(model) and attempts < 100 do
                    Citizen.Wait(100)
                    attempts = attempts + 1
                end
                if HasModelLoaded(model) then
                    propEntity = CreateObject(model, location.x, location.y, location.z - 0.9, false, true, true)
                    PlaceObjectOnGroundProperly(propEntity)
                    if clientActiveContrabandDrops[dropId] then -- Check if drop still exists
                        clientActiveContrabandDrops[dropId].propEntity = propEntity
                    else -- Drop might have been collected while model was loading
                        DeleteEntity(propEntity)
                    end
                end
                SetModelAsNoLongerNeeded(model)
            end)
        end
    end

    clientActiveContrabandDrops[dropId] = {
        id = dropId,
        location = location,
        name = itemName,
        modelHash = itemModelHash,
        propEntity = propEntity
    }
    ShowNotification("~y~A new contraband drop has appeared: " .. itemName)
end)

-- Event handler for when a contraband drop is collected by any player.
-- Cleans up the local blip and prop.
RegisterNetEvent('cops_and_robbers:contrabandDropCollected')
AddEventHandler('cops_and_robbers:contrabandDropCollected', function(dropId, collectorName, itemName)
    if activeDropBlips[dropId] then
        RemoveBlip(activeDropBlips[dropId])
        activeDropBlips[dropId] = nil
    end

    if clientActiveContrabandDrops[dropId] then
        if clientActiveContrabandDrops[dropId].propEntity and DoesEntityExist(clientActiveContrabandDrops[dropId].propEntity) then
            DeleteEntity(clientActiveContrabandDrops[dropId].propEntity)
        end
        clientActiveContrabandDrops[dropId] = nil
    end

    if isCollectingFromDrop == dropId then
        isCollectingFromDrop = nil -- Reset collection state if this client was collecting this drop
        collectionTimerEnd = 0
        -- TODO: Hide UI progress bar if it was shown (e.g., SendNUIMessage({action = 'hideContrabandProgress'}))
    end
    ShowNotification("~g~Contraband '" .. itemName .. "' was collected by " .. collectorName .. ".")
end)

-- Event handler for when the current client is authorized to start collecting a contraband drop.
RegisterNetEvent('cops_and_robbers:collectingContrabandStarted')
AddEventHandler('cops_and_robbers:collectingContrabandStarted', function(dropId, collectionTime)
    isCollectingFromDrop = dropId
    collectionTimerEnd = GetGameTimer() + collectionTime
    ShowNotification("~b~Collecting contraband... Hold position.")
    -- TODO: Show UI progress bar (e.g., SendNUIMessage({action = 'showContrabandProgress', duration = collectionTime}))
end)

-- Thread for handling contraband drop interaction (proximity checks, collection progress).
Citizen.CreateThread(function()
    local lastInteractionCheck = 0
    local interactionCheckInterval = 250 -- ms, for proximity checks when not collecting
    local activeCollectionWait = 50     -- ms, for faster updates when actively collecting

    while true do
        local loopWait = interactionCheckInterval -- Default wait time for the loop when not collecting
        local playerPed = PlayerPedId()

        if DoesEntityExist(playerPed) and role == 'robber' then
            local playerCoords = GetEntityCoords(playerPed)

            if not isCollectingFromDrop then
                -- Only check for nearby drops periodically if not already collecting
                if (GetGameTimer() - lastInteractionCheck) > interactionCheckInterval then
                    local foundNearbyDrop = false
                    for dropId, dropData in pairs(clientActiveContrabandDrops) do
                        if dropData.location then
                            local distance = #(playerCoords - dropData.location)
                            if distance < 3.0 then -- Interaction radius
                                DisplayHelpText("Press ~INPUT_CONTEXT~ to collect contraband (" .. dropData.name .. ")")
                                if IsControlJustReleased(0, 51) then -- E key (Context)
                                    TriggerServerEvent('cops_and_robbers:startCollectingContraband', dropId)
                                end
                                foundNearbyDrop = true
                                loopWait = activeCollectionWait -- Check more frequently once a prompt is shown or interaction starts
                                break
                            end
                        end
                    end
                    lastInteractionCheck = GetGameTimer()
                end
            else -- Player is currently collecting from a drop (isCollectingFromDrop is not nil)
                loopWait = activeCollectionWait -- Check more frequently when collecting for responsiveness
                local currentDropData = clientActiveContrabandDrops[isCollectingFromDrop]
                if currentDropData and currentDropData.location then
                    local distance = #(playerCoords - currentDropData.location)
                    if distance > 5.0 then -- Player moved too far
                        ShowNotification("~r~Contraband collection cancelled: Moved too far.")
                        -- TODO: Hide UI progress bar (e.g., SendNUIMessage({action = 'hideContrabandProgress'}))
                        -- Optional: Notify server about cancellation
                        -- TriggerServerEvent('cops_and_robbers:cancelCollectingContraband', isCollectingFromDrop)
                        isCollectingFromDrop = nil
                        collectionTimerEnd = 0
                    elseif GetGameTimer() >= collectionTimerEnd then
                        ShowNotification("~g~Collection complete! Verifying with server...")
                        -- TODO: Hide UI progress bar (e.g., SendNUIMessage({action = 'hideContrabandProgress'}))
                        TriggerServerEvent('cops_and_robbers:finishCollectingContraband', isCollectingFromDrop)
                        isCollectingFromDrop = nil -- Reset state, server will confirm success/failure
                        collectionTimerEnd = 0
                    else
                        -- Still collecting, update UI progress
                        -- local progress = (GetGameTimer() - (collectionTimerEnd - Config.ContrabandCollectionTime)) / Config.ContrabandCollectionTime
                        -- Example for simple text display: DisplayHelpText(string.format("Collecting... %d%%", math.floor(progress * 100)))
                        -- TODO: A proper progress bar via NUI would be better: SendNUIMessage({action = 'updateContrabandProgress', progress = progress})
                    end
                else
                    -- Drop data somehow became nil while collecting, reset state
                    isCollectingFromDrop = nil
                    collectionTimerEnd = 0
                end
            end
        end
        Citizen.Wait(loopWait)
    end
end)

-- =====================================
--        SAFE ZONE / RESTRICTED AREA / WANTED REDUCTION INTERACTION CLIENT LOGIC
-- =====================================
-- This thread periodically checks for Safe Zones, Restricted Areas, and nearby locations for Wanted Level Reduction.
Citizen.CreateThread(function()
    local checkInterval = 1000 -- Check every 1 second

    while true do
        Citizen.Wait(checkInterval)

        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) then
            Citizen.Wait(5000) -- Wait longer if player ped doesn't exist yet
            goto continue_main_interaction_loop
        end
        local playerCoords = GetEntityCoords(playerPed)

        -- Safe Zone Logic
        if Config.SafeZones and #Config.SafeZones > 0 then
            local foundSafeZoneThisCheck = false
            local enteredZoneName = ""
            local enteredZoneMessage = ""

            for _, zone in ipairs(Config.SafeZones) do
                if #(playerCoords - zone.location) < zone.radius then
                    foundSafeZoneThisCheck = true
                    enteredZoneName = zone.name
                    enteredZoneMessage = zone.message or "You have entered a Safe Zone."
                    break
                end
            end

            if foundSafeZoneThisCheck then
                if not isCurrentlyInSafeZone then
                    isCurrentlyInSafeZone = true
                    currentSafeZoneName = enteredZoneName
                    ShowNotification(enteredZoneMessage)
                    SetEntityInvincible(playerPed, true)
                    DisablePlayerFiring(PlayerId(), true)
                    SetPlayerCanDoDriveBy(PlayerId(), false)
                end
            else
                if isCurrentlyInSafeZone then
                    ShowNotification("~g~You have left " .. currentSafeZoneName .. ".")
                    isCurrentlyInSafeZone = false
                    currentSafeZoneName = ""
                    SetEntityInvincible(playerPed, false)
                    DisablePlayerFiring(PlayerId(), false)
                    SetPlayerCanDoDriveBy(PlayerId(), true)
                end
            end
        else -- No safe zones configured, ensure player is not stuck in safe zone state
            if isCurrentlyInSafeZone then
                isCurrentlyInSafeZone = false; currentSafeZoneName = ""; SetEntityInvincible(playerPed, false); DisablePlayerFiring(PlayerId(), false); SetPlayerCanDoDriveBy(PlayerId(), true); ShowNotification("~g~Safe zone status reset (zones removed).")
            end
        end

        -- Restricted Area Logic
        if Config.RestrictedAreas and #Config.RestrictedAreas > 0 then
            for _, area in ipairs(Config.RestrictedAreas) do
                if #(playerCoords - area.center) < area.radius then
                    if currentWantedStarsClient >= area.wantedThreshold then -- Check if player's wanted level meets threshold
                        ShowNotification(area.message)
                        -- Note: Actual NPC spawning for restricted areas is complex and would be server-driven based on this client potentially entering.
                        -- For now, client just gets a message. A TriggerServerEvent could be added here.
                    end
                    break
                end
            end
        end

        -- Active Wanted Level Reduction Interactions (only for Robbers or if player is wanted)
        if role == 'robber' or currentWantedStarsClient > 0 then -- Allow for any role if wanted, but typically Robbers might use this more.
            -- Corrupt Officials
            if Config.CorruptOfficials then
                for i, official in ipairs(Config.CorruptOfficials) do
                    if #(playerCoords - official.location) < 10.0 then -- Proximity to interact
                        if not corruptOfficialNPCs[i] or not DoesEntityExist(corruptOfficialNPCs[i]) then
                            local modelHash = GetHashKey(official.model)
                            RequestModel(modelHash)
                            local attempts = 0
                            while not HasModelLoaded(modelHash) and attempts < 50 do Citizen.Wait(50); attempts=attempts+1; end
                            if HasModelLoaded(modelHash) then
                                corruptOfficialNPCs[i] = CreatePed(4, modelHash, official.location.x, official.location.y, official.location.z - 1.0, GetRandomFloatInRange(0.0,360.0), false, true)
                                FreezeEntityPosition(corruptOfficialNPCs[i], true)
                                SetEntityInvincible(corruptOfficialNPCs[i], true)
                                SetBlockingOfNonTemporaryEvents(corruptOfficialNPCs[i], true)
                                SetModelAsNoLongerNeeded(modelHash)
                            end
                        end
                        if corruptOfficialNPCs[i] and DoesEntityExist(corruptOfficialNPCs[i]) then
                             DisplayHelpText(official.dialogue .. "\nPress ~INPUT_CONTEXT~ to bribe (" .. official.name .. ")")
                            if IsControlJustReleased(0, 51) then -- E key
                                TriggerServerEvent('cops_and_robbers:payOffOfficial', i)
                            end
                        end
                        break -- Process one official at a time
                    elseif corruptOfficialNPCs[i] and DoesEntityExist(corruptOfficialNPCs[i]) then
                        -- If player moved away from an official NPC that was spawned, delete them to save resources
                        DeleteEntity(corruptOfficialNPCs[i])
                        corruptOfficialNPCs[i] = nil
                    end
                end
            end

            -- Appearance Change Stores
            if Config.AppearanceChangeStores then
                for i, store in ipairs(Config.AppearanceChangeStores) do
                    if #(playerCoords - store.location) < 3.0 then -- Proximity to interact
                        DisplayHelpText("Press ~INPUT_CONTEXT~ to change appearance at " .. store.name .. " ($" .. store.cost .. ")")
                        if IsControlJustReleased(0, 51) then -- E key
                            TriggerServerEvent('cops_and_robbers:changeAppearance', i)
                        end
                        break -- Process one store at a time
                    end
                end
            end
        end
        ::continue_main_interaction_loop::
    end
end)

-----------------------------------------------------------
-- New Crime Type Detection (Client-Side)
-- This thread attempts to detect certain crimes locally and report them to the server.
-- Note: Client-side detection can be spoofed. Server should validate and apply consequences.
-----------------------------------------------------------
Citizen.CreateThread(function()
    local lastPlayerVehicle = 0 -- Store the entity handle of the last vehicle the player was in
    local lastVehicleDriver = 0 -- Store the entity handle of the driver of the last vehicle
    local lastAssaultReportTime = 0
    local assaultReportCooldown = 5000 -- ms, cooldown for reporting civilian assault to prevent spam

    while true do
        Citizen.Wait(1000) -- Check periodically

        local playerPed = PlayerPedId()
        -- Only run crime detection if player is present and has a role (e.g. not during role selection)
        -- Also, this example excludes cops from triggering these crimes for themselves. Adjust 'role' check as needed.
        if not DoesEntityExist(playerPed) or not role or role == 'cop' then
            Citizen.Wait(5000)
            goto continue_crime_detection_loop -- Using goto here for simplicity given the loop structure
        end

        -- Grand Theft Auto Detection (Simplified)
        -- Detects if player enters a vehicle last driven by a non-player human ped.
        local currentVehicle = GetVehiclePedIsIn(playerPed, false)
        if currentVehicle ~= 0 and currentVehicle ~= lastPlayerVehicle then
            local driver = GetPedInVehicleSeat(currentVehicle, -1) -- Get current driver of the vehicle
            if driver == playerPed then -- Player is now the driver of this new vehicle
                -- Check if the last known driver of this *specific vehicle* (if tracked) or *any previous vehicle the player was in* was an NPC.
                -- This logic primarily checks if the player just entered a vehicle that was previously occupied by an NPC.
                if DoesEntityExist(lastVehicleDriver) and lastVehicleDriver ~= playerPed and not IsPedAPlayer(lastVehicleDriver) and IsPedHuman(lastVehicleDriver) then
                    -- Additional check: Ensure player is actually trying to enter a seat, or has just entered.
                    -- GetSeatPedIsTryingToEnter(playerPed) is useful but might be too transient.
                    -- Check if the vehicle was locked might be an option too, but not all NPC cars are locked.
                    ShowNotification("~r~Grand Theft Auto!")
                    TriggerServerEvent('cops_and_robbers:reportCrime', 'grand_theft_auto', GetVehicleNumberPlateText(currentVehicle))
                end
            end
        end

        if currentVehicle ~= 0 then
            lastVehicleDriver = GetPedInVehicleSeat(currentVehicle, -1)
        else
            lastVehicleDriver = 0 -- Reset if player is not in a vehicle
        end
        lastPlayerVehicle = currentVehicle

        -- Assault Civilian Detection (Very Simplified)
        -- Detects if player is in melee combat with a non-player, non-cop ped.
        -- A robust system would use game damage events (requires server-side handling for accuracy) and proper faction/relationship checks.
        if IsPedInMeleeCombat(playerPed) then
            if (GetGameTimer() - lastAssaultReportTime) > assaultReportCooldown then
                local _, targetPed = GetPedMeleeTargetForPed(playerPed)
                if DoesEntityExist(targetPed) and not IsPedAPlayer(targetPed) and IsPedHuman(targetPed) then
                    local targetModel = GetEntityModel(targetPed)
                    -- Basic check to avoid counting cops/swat as civilians. More robust checks (e.g., relationship groups) might be needed.
                    -- Consider adding a list of "civilian" models or relationship groups if more precision is required.
                    if targetModel ~= GetHashKey("s_m_y_cop_01") and
                       targetModel ~= GetHashKey("s_f_y_cop_01") and
                       targetModel ~= GetHashKey("s_m_y_swat_01") and
                       GetPedRelationshipGroupHash(targetPed) ~= GetHashKey("COP") then
                        ShowNotification("~r~Civilian Assaulted!")
                        TriggerServerEvent('cops_and_robbers:reportCrime', 'assault_civilian')
                        lastAssaultReportTime = GetGameTimer()
                    end
                end
            end
        end
        ::continue_crime_detection_loop::
    end
end)

-----------------------------------------------------------
-- Receive item list from the server (Registered once)
RegisterNetEvent('cops_and_robbers:sendItemList')
AddEventHandler('cops_and_robbers:sendItemList', function(storeName, itemList)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openStore',
        storeName = storeName,
        items = itemList,
        -- Pass player data to NUI for client-side checks before purchase attempt
        playerLevel = playerData.level,
        playerRole = playerData.role,
        playerPerks = playerData.perks,
        playerMoney = playerCash -- or playerData.money if fully integrated
    })
end)

-- Notify cops of a bank robbery with GPS update and sound
RegisterNetEvent('cops_and_robbers:notifyBankRobbery')
AddEventHandler('cops_and_robbers:notifyBankRobbery', function(bankId, bankLocation, bankName)
    if role == 'cop' then
        ShowNotification("~r~Bank Robbery in Progress!~s~\nBank: " .. bankName)
        SetNewWaypoint(bankLocation.x, bankLocation.y)
        -- Optionally, play a sound or additional alert here
    end
end)

-- =====================================
--        SPIKE STRIP CLIENT EVENTS
-- =====================================

RegisterNetEvent('cops_and_robbers:renderSpikeStrip')
AddEventHandler('cops_and_robbers:renderSpikeStrip', function(stripId, location)
    if not HasModelLoaded(spikeStripModelHash) then
        RequestModel(spikeStripModelHash)
        while not HasModelLoaded(spikeStripModelHash) do
            Citizen.Wait(50)
        end
    end

    -- Ensure location is a vector3. Server might send table.
    local deployCoords = vector3(location.x, location.y, location.z)

    -- Adjust Z-coordinate to ground. Raycast down to find ground.
    local _, groundZ = GetGroundZFor_3dCoord(deployCoords.x, deployCoords.y, deployCoords.z + 1.0, false)
    local finalCoords = vector3(deployCoords.x, deployCoords.y, groundZ)

    local spikeProp = CreateObject(spikeStripModelHash, finalCoords.x, finalCoords.y, finalCoords.z, true, true, false) -- network, nophys, dynamic=false
    -- It might be better to use CreateObjectNoOffset for precise placement or adjust Z slightly higher to prevent clipping.
    -- Or use PlaceObjectOnGroundProperly(spikeProp) if needed, though this might alter X,Y.

    FreezeEntityPosition(spikeProp, true) -- Make it static
    SetEntityCollision(spikeProp, true, true) -- Enable collision

    currentSpikeStrips[stripId] = {
        id = stripId,
        obj = spikeProp,
        location = finalCoords -- Store the actual ground coords
    }
    -- print("Client: Rendered spike strip " .. stripId .. " at " .. json.encode(finalCoords))
end)

RegisterNetEvent('cops_and_robbers:removeSpikeStrip')
AddEventHandler('cops_and_robbers:removeSpikeStrip', function(stripId)
    if currentSpikeStrips[stripId] then
        local prop = currentSpikeStrips[stripId].obj
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
        currentSpikeStrips[stripId] = nil
        -- print("Client: Removed spike strip " .. stripId)
    else
        -- print("Client: Attempted to remove unknown spike strip " .. stripId)
    end
end)

RegisterNetEvent('cops_and_robbers:applySpikeEffectToVehicle')
AddEventHandler('cops_and_robbers:applySpikeEffectToVehicle', function(vehicleNetId)
    local vehicle = NetToVeh(vehicleNetId) -- Get vehicle from network ID
    if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
        -- Burst front tires. Can be more specific if needed.
        SetVehicleTyreBurst(vehicle, 0, true, 1000.0) -- Front left
        SetVehicleTyreBurst(vehicle, 1, true, 1000.0) -- Front right
        SetVehicleTyreBurst(vehicle, 2, true, 1000.0) -- Rear left (optional)
        SetVehicleTyreBurst(vehicle, 3, true, 1000.0) -- Rear right (optional)
        ShowNotification("~r~Your tires have been spiked!")
    end
end)

-- Handler for server instructing client to show the heist timer
RegisterNetEvent('cops_and_robbers:showHeistTimerUI')
AddEventHandler('cops_and_robbers:showHeistTimerUI', function(bankName, duration)
    SendNUIMessage({
        action = 'startHeistTimer',
        duration = duration,
        bankName = bankName
    })
end)

-- =====================================
-- ADMIN COMMAND CLIENT-SIDE HANDLERS
-- =====================================

-- Handler for being frozen/unfrozen by an admin
RegisterNetEvent('cops_and_robbers:toggleFreeze')
AddEventHandler('cops_and_robbers:toggleFreeze', function()
    local ped = PlayerPedId()
    local currentlyFrozen = IsEntityFrozen(ped)
    FreezeEntityPosition(ped, not currentlyFrozen)
    if not currentlyFrozen then
        ShowNotification("~r~An admin has frozen you.")
    else
        ShowNotification("~g~An admin has unfrozen you.")
    end
end)

-- Handler for being teleported to a player by an admin
RegisterNetEvent('cops_and_robbers:teleportToPlayer')
AddEventHandler('cops_and_robbers:teleportToPlayer', function(targetPlayerIdToTeleportTo)
    local targetPed = GetPlayerPed(targetPlayerIdToTeleportTo)
    if DoesEntityExist(targetPed) then
        local targetCoords = GetEntityCoords(targetPed)
        SetEntityCoords(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, true)
        ShowNotification("~b~You have been teleported by an admin.")
    else
        ShowNotification("~r~Target player for teleport not found or too far away.")
    end
end)

-- Handler for spectating a player (admin's client executes this)
-- IMPORTANT: The current spectate logic is extremely rudimentary and likely NON-FUNCTIONAL or buggy.
-- `SpectatePlayerPed` is not a standard FiveM native.
-- Proper spectate mode (NetworkSetInSpectatorMode or manual camera control) is complex and requires:
--   - Robust camera creation, manipulation, and destruction.
--   - Handling player controls (disabling own player's input, enabling spectator controls).
--   - Managing player visibility and collision states correctly.
--   - Ensuring smooth transitions and handling edge cases (target disconnects, etc.).
-- This section should be completely rewritten with a proper spectate implementation.
RegisterNetEvent('cops_and_robbers:spectatePlayer')
AddEventHandler('cops_and_robbers:spectatePlayer', function(playerToSpectateId)
    local ownPed = PlayerPedId()
    local targetPed = GetPlayerPed(playerToSpectateId)

    if not DoesEntityExist(targetPed) then
        ShowNotification("~r~Target player for spectate not found or no longer exists.")
        return
    end

    if NetworkIsInSpectatorMode() then
        -- Stop spectating
        ShowNotification("~g~Stopping spectate.")
        NetworkSetInSpectatorMode(false, ownPed) -- Return to own ped
        -- Restore player state (visibility, collision, freeze)
        SetEntityVisible(ownPed, true, false)
        SetEntityCollision(ownPed, true, true)
        FreezeEntityPosition(ownPed, false)
        -- Optional: Restore to a saved position if implemented
        ClearPedTasksImmediately(ownPed)
        RenderScriptCams(false, false, 0, true, true) -- Ensure scripted cams are off
    else
        -- Start spectating
        ShowNotification("~b~Spectating player ID: " .. playerToSpectateId .. ". Use command again to stop.")
        -- Save player state (optional, for more robust restore)
        -- local originalPosition = GetEntityCoords(ownPed)

        SetEntityVisible(ownPed, false, false)
        SetEntityCollision(ownPed, false, false)
        FreezeEntityPosition(ownPed, true)

        NetworkSetInSpectatorMode(true, targetPed)
    end
end)

-- Jail System: Send player to jail
RegisterNetEvent('cops_and_robbers:sendToJail')
AddEventHandler('cops_and_robbers:sendToJail', function(jailTime)
    SetEntityCoords(PlayerPedId(), Config.PrisonLocation.x, Config.PrisonLocation.y, Config.PrisonLocation.z, false, false, false, true)
    ShowNotification("~r~You have been sent to jail for " .. jailTime .. " seconds.")
    
    -- Implement jail time countdown and restrictions
    Citizen.CreateThread(function()
        local remainingTime = jailTime
        while remainingTime > 0 do
            Citizen.Wait(1000) -- Wait 1 second
            remainingTime = remainingTime - 1
            
            -- Restrict player actions while in jail
            DisableControlAction(0, 24, true) -- Disable attack
            DisableControlAction(0, 25, true) -- Disable aim
            DisableControlAction(0, 47, true) -- Disable weapon (G key)
            DisableControlAction(0, 58, true) -- Disable weapon (weapon wheel)
            -- Add more restrictions as needed
        end
        
        -- Release player from jail
        ShowNotification("~g~You have been released from jail.")
        local pData = playerData -- Use the global playerData
        if pData and pData.role then spawnPlayer(pData.role) else spawnPlayer("robber") end -- Fallback to robber spawn
    end)
end)

-- Purchase Confirmation
RegisterNetEvent('cops_and_robbers:purchaseConfirmed')
AddEventHandler('cops_and_robbers:purchaseConfirmed', function(itemId, quantity)
    quantity = quantity or 1
    -- Find item details
    local itemName = nil
    for _, item in ipairs(Config.Items) do
        if item.itemId == itemId then
            itemName = item.name
            break
        end
    end

    if itemName then
        ShowNotification('You purchased: ' .. quantity .. ' x ' .. itemName)
    else
        ShowNotification('Purchase successful.')
    end
end)

-- Purchase Failure
RegisterNetEvent('cops_and_robbers:purchaseFailed')
AddEventHandler('cops_and_robbers:purchaseFailed', function(reason)
    ShowNotification('Purchase failed: ' .. reason)
end)


-- Sell Confirmation
RegisterNetEvent('cops_and_robbers:sellConfirmed')
AddEventHandler('cops_and_robbers:sellConfirmed', function(itemId, quantity)
    quantity = quantity or 1
    -- Find item details
    local itemName = nil
    for _, item in ipairs(Config.Items) do
        if item.itemId == itemId then
            itemName = item.name
            break
        end
    end

    if itemName then
        ShowNotification('You sold: ' .. quantity .. ' x ' .. itemName)
    else
        ShowNotification('Sale successful.')
    end
end)

-- Sell Failure
RegisterNetEvent('cops_and_robbers:sellFailed')
AddEventHandler('cops_and_robbers:sellFailed', function(reason)
    ShowNotification('Sale failed: ' .. reason)
end)


-- Add Weapon
-- Note: playerWeapons and playerAmmo are client-side caches. Server is the source of truth.
-- These events are for immediate feedback. A full sync (like in receivePlayerData) handles definitive state.
RegisterNetEvent('cops_and_robbers:addWeapon')
AddEventHandler('cops_and_robbers:addWeapon', function(weaponName, ammoCount)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    if weaponHash ~= 0 and weaponHash ~= -1 then
        GiveWeaponToPed(playerPed, weaponHash, ammoCount or 0, false, false) -- Give with initial ammo
        playerWeapons[weaponName] = true
        playerAmmo[weaponName] = ammoCount or 0
        ShowNotification("~g~Weapon equipped: " .. (Config.WeaponNames[weaponName] or weaponName))
    else
        ShowNotification("~r~Invalid weapon specified: " .. tostring(weaponName))
    end
end)


-- Remove Weapon
RegisterNetEvent('cops_and_robbers:removeWeapon')
AddEventHandler('cops_and_robbers:removeWeapon', function(weaponName)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    if weaponHash ~= 0 and weaponHash ~= -1 then
        RemoveWeaponFromPed(playerPed, weaponHash)
        playerWeapons[weaponName] = nil
        playerAmmo[weaponName] = nil -- Clear ammo for this weapon
        ShowNotification("~y~Weapon removed: " .. (Config.WeaponNames[weaponName] or weaponName))
    else
        ShowNotification("~r~Invalid weapon specified for removal: " .. tostring(weaponName))
    end
end)


-- Add Ammo
RegisterNetEvent('cops_and_robbers:addAmmo')
AddEventHandler('cops_and_robbers:addAmmo', function(weaponName, ammoToAdd)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    if weaponHash ~= 0 and weaponHash ~= -1 then
        if HasPedGotWeapon(playerPed, weaponHash, false) then
            AddAmmoToPed(playerPed, weaponHash, ammoToAdd)
            playerAmmo[weaponName] = (playerAmmo[weaponName] or 0) + ammoToAdd
            ShowNotification(string.format("~g~Added %d ammo to %s.", ammoToAdd, (Config.WeaponNames[weaponName] or weaponName)))
        else
            ShowNotification("~y~You don't have the weapon (" .. (Config.WeaponNames[weaponName] or weaponName) .. ") for this ammo.")
        end
    else
        ShowNotification("~r~Invalid weapon specified for ammo: " .. tostring(weaponName))
    end
end)


-- Apply Armor
RegisterNetEvent('cops_and_robbers:applyArmor')
AddEventHandler('cops_and_robbers:applyArmor', function(armorType) -- armorType could be "item_vest" or similar
    local playerPed = PlayerPedId()
    local armorValue = 0
    local armorConfig = Config.Items[armorType] -- Assuming armorType is an item key like "light_armor_vest"

    if armorConfig and armorConfig.armorValue then
        armorValue = armorConfig.armorValue
    else -- Fallback for older system or direct values
        if armorType == "armor" then armorValue = 50
        elseif armorType == "heavy_armor" then armorValue = 100
        else ShowNotification("Invalid armor type: " .. tostring(armorType)); return
        end
    end

    local finalArmor = armorValue
    -- Apply perk if player has it
    if playerData and playerData.perks and playerData.perks.increased_armor_durability and playerData.armorModifier and playerData.armorModifier > 1.0 then
        finalArmor = math.floor(armorValue * playerData.armorModifier)
        ShowNotification(string.format("~g~Perk Active: Increased Armor Durability! (%.0f -> %.0f)", armorValue, finalArmor))
    end

    SetPedArmour(playerPed, finalArmor)
    ShowNotification(string.format("~g~Armor Applied: %s (~w~%d Armor)", (armorConfig and armorConfig.label or armorType), finalArmor))
end)


-- =====================================
--           NUI CALLBACKS
-- =====================================

-- NUI Callback for role selection
RegisterNUICallback('selectRole', function(data, cb)
    local selectedRole = data.role
    if selectedRole == 'cop' or selectedRole == 'robber' then
        TriggerServerEvent('cops_and_robbers:setPlayerRole', selectedRole)
        SetNuiFocus(false, false)
        cb('ok')
    else
        ShowNotification("Invalid role selected.")
        cb('error')
    end
end)

RegisterNUICallback('getPlayerInventory', function(data, cb)
    -- cb is the callback function to send data back to NUI.
    -- We need to store this cb or associate it with this request if multiple inventory requests can happen.
    -- For simplicity, assuming one outstanding request or that the server event response will be quick.
    -- A more robust system might use a request ID.

    local promise = exports.ox_lib:initiatePromise() -- Using ox_lib promise

    -- Listen for the server's response ONCE for this specific request
    local function handleInventoryResponse(inventoryData)
        RemoveEventHandler('cops_and_robbers:receivePlayerInventory', handleInventoryResponse) -- Clean up listener
        cb(inventoryData) -- Send data back to NUI
        promise:resolve()
    end
    AddEventHandler('cops_and_robbers:receivePlayerInventory', handleInventoryResponse)

    -- Request inventory from the server
    TriggerServerEvent('cops_and_robbers:requestPlayerInventory')

    -- Optional: Timeout for the promise if server doesn't respond
    SetTimeout(5000, function()
        if promise:getStatus() == 'pending' then
            RemoveEventHandler('cops_and_robbers:receivePlayerInventory', handleInventoryResponse)
            cb({ error = "Failed to get inventory: Timeout" })
            promise:reject("timeout")
            Log("getPlayerInventory NUI callback timed out waiting for server.", "warn")
        end
    end)
end)

-- =====================================
--        SPIKE STRIP DEPLOYMENT & COLLISION
-- =====================================

Citizen.CreateThread(function()
    local deployStripKey = (Config.Keybinds and Config.Keybinds.deploySpikeStrip) or 19 -- 19: INPUT_PREV_WEAPON (Home key)
    local collisionCheckInterval = 250 -- ms, how often to check for spike strip collisions. 0 is too frequent.
    local lastCollisionCheck = 0

    while true do
        local frameWait = 500 -- Default wait time for the loop if not actively checking collisions or inputs.

        if role == 'cop' then
            frameWait = 100 -- Check input more frequently if cop
            if IsControlJustPressed(0, deployStripKey) then
                local playerPed = PlayerPedId()
                -- Basic client-side inventory check placeholder (server must verify)
                -- if HasItemInClientInventory('spikestrip_item') then
                local forwardVector = GetEntityForwardVector(playerPed)
                -- Deploy slightly in front and attempt to place on ground using GetGroundZFor_3dCoord in the render event.
                local deployCoords = GetOffsetFromEntityInWorldCoords(playerPed, forwardVector.x * 2.5, forwardVector.y * 2.5, -0.95)

                ShowNotification("~b~Attempting to deploy spike strip...")
                TriggerServerEvent('cops_and_robbers:deploySpikeStrip', vector3(deployCoords.x, deployCoords.y, deployCoords.z))
                -- Optimistically remove item from client UI if applicable. Server is source of truth.
                -- RemoveItemFromClientInventory('spikestrip_item', 1)
                -- else
                --  ShowNotification("~r~You don't have any spike strips.")
                -- end
            end
        end

        -- Spike Strip Collision Check
        -- This simplified check runs periodically. Server should be the ultimate authority on collisions.
        -- More performant methods might involve server-side checks or custom collision events if available.
        if #(currentSpikeStrips) > 0 and (GetGameTimer() - lastCollisionCheck > collisionCheckInterval) then
            frameWait = math.min(frameWait, collisionCheckInterval) -- Ensure loop runs at collision check interval if strips exist
            lastCollisionCheck = GetGameTimer()

            local playerPed = PlayerPedId() -- Ensure playerPed is defined in this scope
            local playerVeh = GetVehiclePedIsIn(playerPed, false)

            if playerVeh ~= 0 and DoesEntityExist(playerVeh) then -- Player is in a vehicle
                local vehCoords = GetEntityCoords(playerVeh)
                for stripId, stripData in pairs(currentSpikeStrips) do
                    if stripData and stripData.obj and DoesEntityExist(stripData.obj) and stripData.location then
                        local distance = #(vehCoords - stripData.location)
                        -- Rough check based on distance. A more accurate check would involve bounding boxes or specific tire positions.
                        -- The value '2.5' is an approximation for interaction.
                        if distance < 3.0 then -- Increased slightly for better detection with simple distance
                            -- Consider adding a short client-side cooldown per strip to prevent spamming server for same strip
                            -- if not stripData.recentlyHit then
                            ShowNotification("~r~You ran over spikes!") -- Notify self
                            TriggerServerEvent('cops_and_robbers:vehicleHitSpikeStrip', stripId, VehToNet(playerVeh))
                            -- stripData.recentlyHit = true
                            -- SetTimeout(2000, function() if stripData then stripData.recentlyHit = false end end)
                            break -- Process one strip hit per check cycle for this vehicle
                            -- end
                        end
                    else
                        -- Clean up nil or invalid strip data if it somehow occurs
                        -- print("DEBUG: Invalid spike strip data for ID " .. tostring(stripId))
                        -- currentSpikeStrips[stripId] = nil -- Risky if server hasn't confirmed removal
                    end
                end
            end
        end
        Citizen.Wait(frameWait)
    end
end)


-- =====================================
--        SPEED RADAR DEPLOYMENT & USAGE
-- =====================================

Citizen.CreateThread(function()
    local isRadarActive = false
    local radarPosition = nil
    local radarHeading = nil
    local detectedSpeeders = {} -- Stores recently detected speeders to avoid spam: { [targetPlayerServerId .. vehiclePlate] = { data } }

    -- Helper function to calculate relative angle between radar's forward vector and a target position
    local function CalculateRelativeAngle(radarPos, radarHead, targetPos)
        if not radarPos or not targetPos then return 999 end -- Ensure positions are valid
        local angle = math.atan2(targetPos.y - radarPos.y, targetPos.x - radarPos.x) * (180 / math.pi)
        local relativeAngle = angle - (radarHead or 0)
        if relativeAngle < -180 then relativeAngle = relativeAngle + 360 end
        if relativeAngle > 180 then relativeAngle = relativeAngle - 360 end
        return relativeAngle
    end

    -- Helper function to clean up old entries from detectedSpeeders table
    local function CleanOldDetections(timeoutMs)
        local currentTime = GetGameTimer()
        for key, data in pairs(detectedSpeeders) do
            if currentTime - (data.timestamp or 0) > timeoutMs then
                detectedSpeeders[key] = nil
            end
        end
    end

    while true do
        local frameWait = 500 -- Default wait time
        if role == 'cop' then
            -- Use Config.Keybinds if available, otherwise fallback to hardcoded values
            local toggleRadarKey = (Config.Keybinds and Config.Keybinds.toggleSpeedRadar) or 17 -- 17: INPUT_CELLPHONE_SCROLL_BACKWARD (PageUp)
            local fineSpeederKey = (Config.Keybinds and Config.Keybinds.fineSpeeder) or 74       -- 74: INPUT_VEH_HEADLIGHT (H)
            local fineSpeederKeyName = (Config.Keybinds and Config.Keybinds.fineSpeederKeyName) or "H"

            if IsControlJustPressed(0, toggleRadarKey) then
                isRadarActive = not isRadarActive
                if isRadarActive then
                    local playerPed = PlayerPedId()
                    radarPosition = GetEntityCoords(playerPed)
                    radarHeading = GetEntityHeading(playerPed)
                    ShowNotification("~g~Speed radar activated. Point towards road.")
                    detectedSpeeders = {} -- Clear previous detections
                else
                    ShowNotification("~r~Speed radar deactivated.")
                end
            end

            if isRadarActive then
                frameWait = 250 -- Scan more frequently when active
                local playerPed = PlayerPedId() -- Own ped, for exclusion

                local vehicles = GetGamePool('CVehicle') -- Potentially performance intensive, consider alternative ways to get relevant vehicles
                for _, veh in ipairs(vehicles) do
                    if DoesEntityExist(veh) and IsEntityAVehicle(veh) and NetworkGetEntityIsNetworked(veh) then
                        local driver = GetPedInVehicleSeat(veh, -1)
                        if DoesEntityExist(driver) and IsPedAPlayer(driver) and driver ~= playerPed then
                            local targetPlayerNetId = NetworkGetPlayerIndexFromPed(driver)
                            local targetPlayerServerId = GetPlayerServerId(targetPlayerNetId)

                            local detectionKey = tostring(targetPlayerServerId) .. GetVehicleNumberPlateText(veh)
                            local cooldownTime = (Config.SpeedRadarCooldownPerVehicle or 30000)
                            if detectedSpeeders[detectionKey] and (GetGameTimer() - (detectedSpeeders[detectionKey].timestamp or 0) < cooldownTime) then
                                goto continue_vehicles_radar_loop -- Already detected this vehicle/player recently
                            end

                            local vehCoords = GetEntityCoords(veh)
                            if radarPosition then
                                local distanceToRadar = #(vehCoords - radarPosition)
                                local radarRange = (Config.SpeedRadarRange or 50.0)
                                local radarAngle = (Config.SpeedRadarAngle or 45.0)
                                local speedLimit = (Config.SpeedLimitKmh or 80.0)

                                if distanceToRadar < radarRange then
                                    local angleToRadar = CalculateRelativeAngle(radarPosition, radarHeading, vehCoords)
                                    if math.abs(angleToRadar) < radarAngle then
                                        local speedKmh = GetEntitySpeed(veh) * 3.6 -- m/s to km/h
                                        if speedKmh > speedLimit then
                                            local vehicleModel = GetEntityModel(veh)
                                            local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(vehicleModel)) -- Use GetLabelText for localization
                                            if vehicleName == "NULL" or vehicleName == "" then vehicleName = GetDisplayNameFromVehicleModel(vehicleModel) end -- Fallback if no label
                                            local targetPlayerName = GetPlayerName(targetPlayerNetId)
                                            ShowNotification(string.format("~y~Speeding: %s (%s) at %.0f km/h. Press %s to fine.", targetPlayerName, vehicleName, speedKmh, fineSpeederKeyName))

                                            detectedSpeeders[detectionKey] = {
                                                playerId = targetPlayerServerId,
                                                playerName = targetPlayerName,
                                                vehicleName = vehicleName,
                                                speed = speedKmh,
                                                timestamp = GetGameTimer()
                                            }
                                        end
                                    end
                                end
                            end
                        end
                    end
                    ::continue_vehicles_radar_loop::
                end

                if IsControlJustPressed(0, fineSpeederKey) then
                    local bestTargetKey = nil
                    local mostRecentTime = 0
                    for key, data in pairs(detectedSpeeders) do
                        if data.timestamp and data.timestamp > mostRecentTime then
                            local fineTargetPed = GetPlayerPed(GetPlayerFromServerId(data.playerId)) -- Check if target player ped still exists
                            if DoesEntityExist(fineTargetPed) then
                                mostRecentTime = data.timestamp
                                bestTargetKey = key
                            else
                                detectedSpeeders[key] = nil -- Clean up if player ped no longer exists
                            end
                        end
                    end

                    if bestTargetKey and detectedSpeeders[bestTargetKey] then
                        local speederData = detectedSpeeders[bestTargetKey]
                        TriggerServerEvent('cops_and_robbers:vehicleSpeeding', speederData.playerId, speederData.vehicleName, speederData.speed)
                        ShowNotification(string.format("~b~Fine issued to %s for speeding at %.0f km/h.", speederData.playerName, speederData.speed))
                        -- Mark as fined by making it seem older, but not too old to allow re-detection if they speed again soon.
                        detectedSpeeders[bestTargetKey].timestamp = GetGameTimer() - (cooldownTime - (Config.SpeedRadarFineGracePeriodMs or 5000))
                    else
                        ShowNotification("~y~No recent speeder targeted, or target no longer valid.")
                    end
                end
                CleanOldDetections(Config.SpeedRadarCleanupTime or 60000) -- Clean up very old entries
            end
        else
            if isRadarActive then -- If player changes role while radar is active
                isRadarActive = false
                ShowNotification("~r~Speed radar deactivated due to role change.")
            end
            frameWait = 2000 -- Check less often if not a cop
        end
        Citizen.Wait(frameWait)
    end
end)

--[[ -- Helper functions moved into the radar thread to keep them local.
function CalculateRelativeAngle(pos1, heading1, pos2)
    local angle = math.atan2(pos2.y - pos1.y, pos2.x - pos1.x) * (180 / math.pi)
    local relativeAngle = angle - heading1
    if relativeAngle < -180 then relativeAngle = relativeAngle + 360 end
    if relativeAngle > 180 then relativeAngle = relativeAngle - 360 end
    return relativeAngle
end

function CleanOldDetections(timeoutMs)
    local currentTime = GetGameTimer()
    for key, data in pairs(detectedSpeeders) do
        if currentTime - (data.timestamp or 0) > timeoutMs then -- Ensure data.timestamp exists
            detectedSpeeders[key] = nil
        end
    end
end
--]]

-- =====================================
--           STORE FUNCTIONS
-- =====================================

-- Function to open the store
local function openStore(storeName, storeType, vendorItems)
    TriggerServerEvent('cops_and_robbers:getItemList', storeType, vendorItems, storeName)
end

-- =====================================
--           STORE AND VENDOR INTERACTION
-- =====================================

-- Detect player near a store or vendor
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) -- Check every 0.5 seconds to optimize performance
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        -- Check proximity to Ammu-Nation stores (now stored as vector3)
        for _, store in ipairs(Config.AmmuNationStores) do
            local distance = #(playerCoords - store) -- Calculate distance using vector subtraction and magnitude
            if distance < 2.0 then
                DisplayHelpText('Press ~INPUT_CONTEXT~ to open Ammu-Nation')
                if IsControlJustPressed(0, 51) then  -- E key (Default: Context)
                    openStore('Ammu-Nation', 'AmmuNation', nil)
                end
            end
        end

        -- Check proximity to NPC vendors
        for _, vendor in ipairs(Config.NPCVendors) do
            local vendorCoords = vendor.location
            local distance = #(playerCoords - vendorCoords) -- Calculate distance
            if distance < 2.0 then
                DisplayHelpText('Press ~INPUT_CONTEXT~ to talk to ' .. vendor.name)
                if IsControlJustPressed(0, 51) then -- E key (Default: Context)
                    openStore(vendor.name, 'Vendor', vendor.items)
                end
            end
        end
    end
end)

-- =====================================
--           NPC VENDOR SPAWN
-- =====================================

-- Spawn NPC vendors in the world
Citizen.CreateThread(function()
    for _, vendor in ipairs(Config.NPCVendors) do
        local hash = GetHashKey(vendor.model)
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Citizen.Wait(100)
        end

        local npc = CreatePed(4, hash, vendor.location.x, vendor.location.y, vendor.location.z - 1.0, vendor.heading, false, true)
        SetEntityInvincible(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        FreezeEntityPosition(npc, true)
        -- Optionally, add more NPC configurations here (e.g., specific animations, relationships)
    end
end)

-- =====================================
--        ENHANCED ARREST (TACKLE/SUBDUE)
-- =====================================
local isSubduing = false
local isBeingSubdued = false

-- Cop initiates subdue
Citizen.CreateThread(function()
    while true do
        local frameWait = 500 -- Default wait, check less often if not a cop or already subduing
        if role == 'cop' and not isSubduing then
            frameWait = 0 -- Check every frame for input if cop and not subduing
            if IsControlJustPressed(0, (Config.Keybinds and Config.Keybinds.tackleSubdue) or 47) then -- INPUT_WEAPON_SPECIAL_TWO (G key placeholder) or from config
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local closestPlayerId = -1
                local closestDistance = -1

                -- Find nearest player. Server must validate if the target is actually a robber and can be tackled.
                for _, pId in ipairs(GetActivePlayers()) do
                    if pId ~= PlayerId() then -- Don't target self
                        local targetPed = GetPlayerPed(pId)
                        if DoesEntityExist(targetPed) then
                            local distance = #(playerCoords - GetEntityCoords(targetPed))
                            if closestDistance == -1 or distance < closestDistance then
                                closestDistance = distance
                                closestPlayerId = pId
                            end
                        end
                    end
                end

                local tackleDistance = (Config.TackleDistance or 2.0)
                if closestPlayerId ~= -1 and closestDistance <= tackleDistance then
                    local targetServerId = GetPlayerServerId(closestPlayerId)
                    if targetServerId ~= -1 then
                        ShowNotification("~b~Attempting to tackle...")
                        -- Example Animation (ensure anim dict is loaded):
                        -- RequestAnimDict("melee@unarmed@streamed_variations")
                        -- while not HasAnimDictLoaded("melee@unarmed@streamed_variations") do Citizen.Wait(50) end
                        -- TaskPlayAnim(playerPed, "melee@unarmed@streamed_variations", "plyr_takedown_front", 8.0, -8.0, -1, 0, 0, false, false, false)

                        TriggerServerEvent('cops_and_robbers:startSubdue', targetServerId)
                        isSubduing = true -- Prevent spamming tackle

                        SetTimeout((Config.SubdueTimeMs or 3000) + 500, function()
                            isSubduing = false
                            -- ClearPedTasks(playerPed) -- Optional: Stop animation if still playing and it's looping
                        end)
                    else
                        ShowNotification("~r~Could not get target server ID for tackle.")
                    end
                elseif closestPlayerId ~= -1 then
                    ShowNotification(string.format("~r~Target is too far to tackle (%.1fm). Required: %.1fm", closestDistance, tackleDistance))
                else
                    ShowNotification("~y~No player found nearby to tackle.")
                end
            end
        end
        Citizen.Wait(frameWait)
    end
end)

-- Robber receives subdue sequence
RegisterNetEvent('cops_and_robbers:beginSubdueSequence')
AddEventHandler('cops_and_robbers:beginSubdueSequence', function(copServerId)
    isBeingSubdued = true
    local playerPed = PlayerPedId()
    local copName = GetPlayerName(GetPlayerFromServerId(copServerId)) or "a Cop"
    ShowNotification("~r~You are being tackled by " .. copName .. "!")

    -- Example Animation (ensure anim dict is loaded):
    -- RequestAnimDict("combat@damage@writheid")
    -- while not HasAnimDictLoaded("combat@damage@writheid") do Citizen.Wait(50) end
    -- TaskPlayAnim(playerPed, "combat@damage@writheid", "writhe_loop", 8.0, -8.0, Config.SubdueTimeMs or 3000, 1, 0, false, false, false) -- Play animation for duration

    FreezeEntityPosition(playerPed, true) -- Freeze player
    -- Consider more granular control disabling if needed, e.g., DisableControlAction

    -- Server ultimately controls the arrest after SubdueTimeMs.
    -- This timeout is for client-side state reset.
    SetTimeout(Config.SubdueTimeMs or 3000, function()
        if isBeingSubdued then
            -- Unfreezing and task clearing should ideally be synced with server action (e.g., arrest, escape, cancel)
            -- For now, client resets its state. Server might send an explicit unfreeze event.
            isBeingSubdued = false
            ShowNotification("~g~Subdue period ended. Awaiting server action.")
            -- ClearPedTasks(playerPed) -- Stop animation if it was looping
            -- FreezeEntityPosition(playerPed, false) -- Avoid doing this unless server confirms release/failed arrest
        end
    end)

    -- Placeholder for an Escape Minigame:
    -- if Config.EnableTackleEscapeMinigame then
    --   StartTackleEscapeMinigame(function(success)
    --     if success and isBeingSubdued then
    --       TriggerServerEvent('cops_and_robbers:escapeSubdue', copServerId)
    --       isBeingSubdued = false
    --       FreezeEntityPosition(playerPed, false)
    --       ClearPedTasks(playerPed)
    --       ShowNotification("~g~You escaped!")
    --     end
    --   end)
    -- end
end)

RegisterNetEvent('cops_and_robbers:subdueCancelled') -- If cop moves too far, dies, or cancels subdue
AddEventHandler('cops_and_robbers:subdueCancelled', function()
    if isBeingSubdued then
        isBeingSubdued = false
        FreezeEntityPosition(PlayerPedId(), false)
        ShowNotification("~g~The cop moved away, you are no longer being subdued.")
    end
end)


-- =====================================
--           K9 UNIT (Simplified)
-- =====================================
-- local k9NetId = nil -- This was part of an older, flawed K9 sync logic. Kept for historical reference if needed.
local k9Ped = nil   -- Stores the local entity (ped handle) of the K9, spawned and managed by this client.

-- This thread handles K9 whistle input (spawn/dismiss) and attack command input.
-- It also contains basic follow logic for an active K9.
Citizen.CreateThread(function()
    local k9KeybindWait = 200 -- Check keybinds less frequently to avoid perf impact from IsControlJustPressed in tight loop.
    local k9FollowTaskWait = 1000 -- How often to re-evaluate follow task if K9 is idle.
    local lastFollowTaskTime = 0

    while true do
        Citizen.Wait(k9KeybindWait)
        if playerData.role == 'cop' then -- Use playerData.role
            -- K9 Spawn/Dismiss Keybind
            local toggleK9Key = (Config.Keybinds and Config.Keybinds.toggleK9) or 31 -- 31: INPUT_VEH_CIN_CAM (K)
            if IsControlJustPressed(0, toggleK9Key) then
                if k9Ped and DoesEntityExist(k9Ped) then
                    ShowNotification("~y~Dismissing K9 unit...")
                    TriggerServerEvent('cops_and_robbers:dismissK9')
                else
                    -- Client-side check for item (improved UX, server still validates)
                    local k9WhistleConfig = Config.Items["k9_whistle"]
                    if k9WhistleConfig and playerData.level >= (k9WhistleConfig.minLevelCop or 1) then
                        -- Basic check if player *could* have the item based on level. Actual inventory check is better.
                        ShowNotification("~b~Using K9 Whistle...")
                        TriggerServerEvent('cops_and_robbers:spawnK9') -- Server will check inventory and level again
                    else
                        ShowNotification(string.format("~r~K9 Whistle requires Level %d Cop.", (k9WhistleConfig and k9WhistleConfig.minLevelCop or 1)))
                    end
                end
            end

            -- K9 Attack Command Keybind
            local commandK9AttackKey = (Config.Keybinds and Config.Keybinds.commandK9Attack) or 38 -- 38: INPUT_CONTEXT (L)
            if k9Ped and DoesEntityExist(k9Ped) and IsControlJustPressed(0, commandK9AttackKey) then
                local playerPed = PlayerPedId()
                local searchRadius = (Config.K9AttackSearchRadius or 50.0)
                local closestTargetPed, dist = GetClosestPlayerPed(GetEntityCoords(playerPed), searchRadius, true)

                if closestTargetPed then
                    local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(closestTargetPed))
                    if targetServerId and targetServerId ~= -1 then
                        ShowNotification("~y~K9: Commanding attack on " .. GetPlayerName(NetworkGetPlayerIndexFromPed(closestTargetPed)) .. "!")
                        TriggerServerEvent('cops_and_robbers:commandK9', targetServerId, "attack")
                        TriggerServerEvent('cnr:k9EngagedTarget', targetServerId) -- Notify server K9 is engaging this target
                    else
                        ShowNotification("~y~K9: Could not identify target for attack.")
                    end
                else
                    ShowNotification("~y~K9: No target found nearby to command attack.")
                end
            end
        end

        -- Keep K9 following if it exists and no other urgent task (this part can be in a slightly longer interval loop)
        -- This is a simplified follow logic. A more advanced K9 would have better pathing, state handling, and obstacle avoidance.
        if k9Ped and DoesEntityExist(k9Ped) and IsPedOnFoot(PlayerPedId()) then
            if (GetGameTimer() - lastFollowTaskTime) > k9FollowTaskWait then
                local currentTaskStatus = GetActivityLevel(k9Ped) -- 0=idle/none, 1=alert/moving, 2=action/combat/fleeing
                -- Only re-issue follow task if K9 is not in combat/serious action and is too far.
                if currentTaskStatus < 2 then
                    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(k9Ped)) > Config.K9FollowDistance + 2.0 then -- Add buffer to prevent constant re-tasking
                        TaskFollowToOffsetOfEntity(k9Ped, PlayerPedId(), vector3(0.0, -Config.K9FollowDistance, 0.0), 1.5, -1, Config.K9FollowDistance - 1.0, true)
                    end
                end
                lastFollowTaskTime = GetGameTimer()
            end
        end
    end
end)

-- Handles authorization from server to spawn K9 locally.
RegisterNetEvent('cops_and_robbers:clientSpawnK9Authorized')
AddEventHandler('cops_and_robbers:clientSpawnK9Authorized', function()
    if k9Ped and DoesEntityExist(k9Ped) then
        ShowNotification("~y~Your K9 unit is already active.")
        return
    end

    local modelHash = GetHashKey('a_c_shepherd') -- K9 model
    RequestModel(modelHash)
    CreateThread(function() -- New thread for model loading to avoid blocking
        local attempts = 0
        while not HasModelLoaded(modelHash) and attempts < 100 do -- Max 10s wait
            Citizen.Wait(100)
            attempts = attempts + 1
        end

        if HasModelLoaded(modelHash) then
            local playerPed = PlayerPedId()
            local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, Config.K9FollowDistance * -1.0, 0.5) -- Spawn behind player, slightly up

            k9Ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z, GetEntityHeading(playerPed), false, true) -- Not networked for server, but make it mission
            SetModelAsNoLongerNeeded(modelHash)

            SetEntityAsMissionEntity(k9Ped, true, true) -- Prevent despawn by game engine
            SetPedAsCop(k9Ped, true) -- Optional: Makes K9 behave somewhat like a police ped (e.g., might react to crimes)
            SetPedRelationshipGroupHash(k9Ped, GetPedRelationshipGroupHash(playerPed)) -- Friendly to player and player's group
            SetBlockingOfNonTemporaryEvents(k9Ped, true)
            TaskFollowToOffsetOfEntity(k9Ped, playerPed, vector3(0.0, -Config.K9FollowDistance, 0.0), 1.5, -1, Config.K9FollowDistance - 1.0, true)

            ShowNotification("~g~Your K9 unit has arrived!")
        else
            ShowNotification("~r~Failed to spawn K9 unit: Model not found.")
            SetModelAsNoLongerNeeded(modelHash) -- Still call this if model failed to load after attempts
        end
    end)
end)

-- Handles server instruction to dismiss the client's K9.
RegisterNetEvent('cops_and_robbers:clientDismissK9')
AddEventHandler('cops_and_robbers:clientDismissK9', function()
    ShowNotification("~y~Your K9 unit has been dismissed.")
    if k9Ped and DoesEntityExist(k9Ped) then
        DeleteEntity(k9Ped)
    end
    k9Ped = nil
end)

-- Handles server relaying a command for the K9 (e.g., to attack a target).
RegisterNetEvent('cops_and_robbers:k9ProcessCommand')
AddEventHandler('cops_and_robbers:k9ProcessCommand', function(targetRobberServerId, commandType)
    if k9Ped and DoesEntityExist(k9Ped) then
        local targetRobberPed = GetPlayerPed(GetPlayerFromServerId(targetRobberServerId))
        if targetRobberPed and DoesEntityExist(targetRobberPed) then
            if commandType == "attack" then
                ClearPedTasks(k9Ped) -- Clear previous tasks before issuing combat
                TaskCombatPed(k9Ped, targetRobberPed, 0, 16) -- 0 = fight until target dead or task cleared, 16 = default behavior
            elseif commandType == "follow" then -- Example: command K9 to explicitly follow owner
                TaskFollowToOffsetOfEntity(k9Ped, PlayerPedId(), vector3(0.0, -Config.K9FollowDistance, 0.0), 1.5, -1, Config.K9FollowDistance - 1.0, true)
            end
        end
    end
end)

-- Helper function to get the closest player ped (excluding self if specified)
-- Note: This does NOT check for role. Role validation should be server-side.
-- @param coords vector3: The center point to search from.
-- @param radius float: The search radius.
-- @param excludeSelf boolean: Whether to exclude the current player from results.
-- @return ped, distance: The closest ped entity and distance, or nil, -1 if none found.
function GetClosestPlayerPed(coords, radius, excludeSelf)
    local closestPed, closestDist = nil, -1
    local selfPlayerId = PlayerId() -- Get current player's client ID

    for _, pId in ipairs(GetActivePlayers()) do -- Iterate over all active players
        if excludeSelf and pId == selfPlayerId then
            goto continue_k9_player_loop -- Skip self if excludeSelf is true
        end

        local targetPed = GetPlayerPed(pId) -- Get ped handle for the player
        if DoesEntityExist(targetPed) then
            local dist = #(coords - GetEntityCoords(targetPed)) -- Calculate distance
            if dist < radius then
                if not closestPed or dist < closestDist then -- If this is the first found or closer than previous
                    closestPed = targetPed
                    closestDist = dist
                end
            end
        end
        ::continue_k9_player_loop:: -- Label for goto statement
    end
    return closestPed, closestDist
end

-- Deprecated GetClosestRobberPed, as role checking should be server-side.
-- Players can use GetClosestPlayerPed and server validates if that player is a robber.
-- function GetClosestRobberPed(coords, radius) ... end


-- =====================================
--        STORE ROBBERY CLIENT LOGIC
-- =====================================
local currentStoreRobbery = nil -- { store = storeTable, duration = duration, startTime = GetGameTimer() }

-- Proximity check for robbable stores
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second
        if role == 'robber' then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local nearStore = false

            for i, store in ipairs(Config.RobbableStores) do
                local dist = #(playerCoords - store.location)
                if dist < store.radius + 5.0 then -- Show prompt if slightly outside interaction radius
                    nearStore = true
                    if dist < store.radius then -- Interaction radius
                        DisplayHelpText(string.format("Press ~INPUT_CONTEXT~ to rob %s.", store.name))
                        if IsControlJustPressed(0, 51) then -- E key (Context)
                            if not currentStoreRobbery then
                                TriggerServerEvent('cops_and_robbers:startStoreRobbery', i) -- Pass store index (1-based)
                            else
                                ShowNotification("~r~You are already in a robbery.")
                            end
                        end
                        break -- Show prompt for one store at a time
                    end
                end
            end
            -- if not nearStore and currentStoreRobbery then -- Handled by below thread
            --     -- If player moved away from any store while a robbery was active for them
            -- end
        end
    end
end)

RegisterNetEvent('cops_and_robbers:beginStoreRobberySequence')
AddEventHandler('cops_and_robbers:beginStoreRobberySequence', function(store, duration)
    ShowNotification(string.format("~y~Robbing %s! Stay in the area for %d seconds.", store.name, duration / 1000))
    currentStoreRobbery = {
        store = store,
        duration = duration,
        startTime = GetGameTimer()
    }
    -- TODO: Display timer on UI
end)

-- Thread to monitor robber's presence during a store robbery
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if currentStoreRobbery and role == 'robber' then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distToStore = #(playerCoords - currentStoreRobbery.store.location)
            local timeElapsed = GetGameTimer() - currentStoreRobbery.startTime

            if distToStore > currentStoreRobbery.store.radius + 2.0 then -- +2.0 buffer
                ShowNotification("~r~You fled the store! Robbery failed.")
                TriggerServerEvent('cops_and_robbers:storeRobberyUpdate', "fled")
                currentStoreRobbery = nil
                -- TODO: Hide timer UI
            elseif timeElapsed >= currentStoreRobbery.duration then
                -- Timer already completed client-side, server will confirm reward.
                -- Client doesn't need to send "completed", server timer handles success.
                -- However, good to clear local state.
                ShowNotification("~g~Robbery duration complete. Waiting for server confirmation.")
                currentStoreRobbery = nil
                -- TODO: Hide timer UI
            else
                -- Update UI timer if any
                local timeLeft = (currentStoreRobbery.duration - timeElapsed) / 1000
                -- TODO: SendNUIMessage({ action = 'updateStoreRobberyTimer', timeLeft = timeLeft })
                DisplayHelpText(string.format("Robbing %s... Time left: %ds", currentStoreRobbery.store.name, math.ceil(timeLeft)))
            end
        end
    end
end)


-- =====================================
--        ARMORED CAR HEIST CLIENT LOGIC
-- =====================================
local armoredCarBlip = nil
local armoredCarNetIdClient = nil
local armoredCarClientData = { lastHealth = 0 } -- Store last known health client-side

RegisterNetEvent('cops_and_robbers:armoredCarSpawned')
AddEventHandler('cops_and_robbers:armoredCarSpawned', function(vehicleNetId, initialCoords)
    ShowNotification("~y~An armored car is on the move!")
    armoredCarNetIdClient = vehicleNetId
    local vehicle = NetToVeh(vehicleNetId)

    if DoesEntityExist(vehicle) then
        if armoredCarBlip then RemoveBlip(armoredCarBlip) end
        armoredCarBlip = AddBlipForEntity(vehicle)
        SetBlipSprite(armoredCarBlip, 427) -- Example: Blip sprite for Armored Truck
        SetBlipColour(armoredCarBlip, 5)  -- Example: Yellow
        SetBlipAsShortRange(armoredCarBlip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Armored Car")
        EndTextCommandSetBlipName(armoredCarBlip)
        armoredCarClientData.lastHealth = GetEntityHealth(vehicle) -- Initialize health tracking
    else
        print("Armored car entity not found client-side yet for NetID: " .. vehicleNetId)
    end
end)

RegisterNetEvent('cops_and_robbers:armoredCarDestroyed')
AddEventHandler('cops_and_robbers:armoredCarDestroyed', function(vehicleNetId)
    ShowNotification("~g~The armored car has been successfully looted and destroyed!")
    if armoredCarBlip then
        RemoveBlip(armoredCarBlip)
        armoredCarBlip = nil
    end
    armoredCarNetIdClient = nil
    armoredCarClientData.lastHealth = 0 -- Reset health tracking
end)

-- Robber damaging armored car - Client-side damage detection and reporting
Citizen.CreateThread(function()
    local damageCheckInterval = 1000 -- Check health every 1 second
    while true do
        Citizen.Wait(damageCheckInterval)
        if role == 'robber' and armoredCarNetIdClient and NetworkDoesNetworkIdExist(armoredCarNetIdClient) then
            local carEntity = NetToVeh(armoredCarNetIdClient)
            if DoesEntityExist(carEntity) then
                local currentHealth = GetEntityHealth(carEntity)
                if armoredCarClientData.lastHealth == 0 then -- Handle case where it wasn't initialized properly
                    armoredCarClientData.lastHealth = GetMaxHealth(carEntity) -- Assume full health if not set
                end

                if currentHealth < armoredCarClientData.lastHealth then
                    local damageDone = armoredCarClientData.lastHealth - currentHealth
                    if damageDone > 0 then -- Only report actual damage
                        -- print("Armored Car: Detected damage: " .. damageDone .. ", Current Health: " .. currentHealth .. ", Last Health: " .. armoredCarClientData.lastHealth)
                        TriggerServerEvent('cops_and_robbers:damageArmoredCar', armoredCarNetIdClient, damageDone)
                    end
                end
                armoredCarClientData.lastHealth = currentHealth
            else
                -- Car entity no longer exists, maybe destroyed by other means or despawned
                armoredCarNetIdClient = nil
                armoredCarClientData.lastHealth = 0
            end
        end
    end
end)


-- =====================================
--        EMP DEVICE CLIENT LOGIC
-- =====================================

-- Robber: Activate EMP (Placeholder key: NumPad 0, or tie to item usage)
Citizen.CreateThread(function()
    while true do
        local frameWait = 500 -- Default wait
        if playerData.role == 'robber' then -- Use playerData.role
            frameWait = 100 -- Check input more frequently if robber
            local activateEMPKey = (Config.Keybinds and Config.Keybinds.activateEMP) or 121 -- 121: INPUT_SELECT_WEAPON_UNARMED (NumPad 0)
            if IsControlJustPressed(0, activateEMPKey) then
                -- Client-side check for item (improved UX, server still validates)
                local empDeviceConfig = Config.Items["emp_device"] -- Corrected itemId
                if empDeviceConfig and playerData.level >= (empDeviceConfig.minLevelRobber or 1) then
                    ShowNotification("~b~Activating EMP device...")
                    TriggerServerEvent('cops_and_robbers:activateEMP') -- Server checks inventory and level again
                else
                    ShowNotification(string.format("~r~Vehicle EMP Device requires Level %d Robber.", (empDeviceConfig and empDeviceConfig.minLevelRobber or 1)))
                end
            end
        end
        Citizen.Wait(frameWait)
    end
end)

-- Cop: Handle being EMPed by a robber
RegisterNetEvent('cops_and_robbers:vehicleEMPed')
AddEventHandler('cops_and_robbers:vehicleEMPed', function(vehicleNetIdToEMP, durationMs)
    local playerPed = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(playerPed, false)
    local targetVehicle = NetToVeh(vehicleNetIdToEMP)

    if DoesEntityExist(targetVehicle) and currentVehicle == targetVehicle then
        ShowNotification("~r~Your vehicle has been disabled by an EMP!")

        -- Disable engine
        SetVehicleEngineOn(targetVehicle, false, true, true) -- turnOff, instantly, noAutoTurnOnDuringDisable
        SetVehicleUndriveable(targetVehicle, true) -- Make it undriveable

        -- Visual/Audio effects (placeholder)
        -- Consider using custom screen effects or sounds if available
        -- For custom visual EMP effects, consider using NUI messages to trigger them on screen.
        -- PlaySoundFrontend(-1, "EMP_Blast", "DLC_AW_Weapon_Sounds", true) -- Ensure sound pack is loaded

        SetTimeout(durationMs, function()
            if DoesEntityExist(targetVehicle) then
                SetVehicleUndriveable(targetVehicle, false)
                -- Engine might need to be manually started by player if they didn't leave vehicle.
                -- Attempt to restart if player is still in the driver seat.
                if GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
                    SetVehicleEngineOn(targetVehicle, true, true, false)
                end
                ShowNotification("~g~Vehicle systems recovering from EMP.")
            end
        end)
    end
end)


-- =====================================
--        POWER GRID SABOTAGE CLIENT LOGIC
-- =====================================
local activePowerOutages = {} -- { [gridIndex] = true/false }

-- Proximity check for power grids
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second
        if playerData.role == 'robber' then -- Use playerData.role
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            for i, grid in ipairs(Config.PowerGrids) do
                if #(playerCoords - grid.location) < 10.0 then -- Interaction radius (e.g., 10m)
                    DisplayHelpText(string.format("Press ~INPUT_CONTEXT~ to sabotage %s.", grid.name))
                    if IsControlJustPressed(0, 51) then -- E key (Context)
                        local sabotageToolConfig = Config.Items["emp_device"] -- Corrected itemId
                        if sabotageToolConfig and playerData.level >= (sabotageToolConfig.minLevelRobber or 1) then
                             ShowNotification("~b~Attempting power grid sabotage...")
                             TriggerServerEvent('cops_and_robbers:sabotagePowerGrid', i) -- Pass grid index (1-based)
                             TriggerServerEvent('cops_and_robbers:reportCrime', 'power_grid_sabotaged_crime') -- Report the crime
                        else
                            ShowNotification(string.format("~r~Sabotaging power grid requires Level %d Robber and appropriate gear.", (sabotageToolConfig and sabotageToolConfig.minLevelRobber or 1)))
                        end
                    end
                    break
                end
            end
        end
    end
end)

RegisterNetEvent('cops_and_robbers:powerGridStateChanged')
AddEventHandler('cops_and_robbers:powerGridStateChanged', function(gridIndex, isOutage, duration)
    local grid = Config.PowerGrids[gridIndex]
    if not grid then return end

    activePowerOutages[gridIndex] = isOutage

    if isOutage then
        ShowNotification(string.format("~r~Power outage reported at %s!", grid.name))
        -- Simplified visual effect: Toggle artificial lights off/on.
        -- True regional blackouts are very complex and often require custom shaders or timecycle mods.
        -- This will just affect game's generic "artificial lights" state, may not be area-specific enough.
        -- For area-specific, one might try to manage street light entities within grid.radius.
        -- Note: SetArtificialLightsState(true) has a global effect. True localized blackouts are complex.
        SetArtificialLightsState(true) -- This native might turn off many lights globally.
                                      -- A better approach for localized effect is needed for full implementation.
        print("Simplified power outage effect activated for grid: " .. grid.name)
        -- TODO: Implement more localized blackout effect if possible, e.g., by finding nearby street light objects.
    else
        ShowNotification(string.format("~g~Power restored at %s.", grid.name))
        -- Check if any other grid is still out before turning lights back on globally
        local anyOutageActive = false
        for _, status in pairs(activePowerOutages) do
            if status then anyOutageActive = true; break end
        end
        if not anyOutageActive then
            SetArtificialLightsState(false) -- Restore lights if no other outages are active
            print("All power outages resolved. Global artificial lights restored.")
        else
            print("Power restored for grid: " .. grid.name .. ", but other outages may be active.")
        end
    end
end)


-- =====================================
--        ADMIN PANEL CLIENT LOGIC
-- =====================================
local isAdminPanelOpen = false
local currentBounties = {}
local isBountyBoardOpen = false

-- Keybind for Admin Panel (e.g., F10 - Keycode 57 for INPUT_REPLAY_STOPRECORDING)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Check every frame for these inputs

        -- Admin Panel Toggle
        local toggleAdminPanelKey = (Config.Keybinds and Config.Keybinds.toggleAdminPanel) or 289 -- F10 (INPUT_REPLAY_STOPRECORDING is actually 289, 57 is F6)
        if IsControlJustPressed(0, toggleAdminPanelKey) then
            if not isAdminPanelOpen then
                ShowNotification("~b~Requesting Admin Panel data...")
                TriggerServerEvent('cops_and_robbers:requestAdminDataForUI')
            else
                SendNUIMessage({ action = 'hideAdminPanel' })
                SetNuiFocus(false, false)
                isAdminPanelOpen = false
                ShowNotification("~y~Admin Panel closed.")
            end
        end

        -- Bounty Board Toggle (Example: F7 - INPUT_VEH_SELECT_NEXT_WEAPON is often 168)
        -- Ensure Config.Keybinds.toggleBountyBoard is defined in config.lua if used
        local toggleBountyBoardKey = (Config.Keybinds and Config.Keybinds.toggleBountyBoard) or 168
        if IsControlJustPressed(0, toggleBountyBoardKey) then
            if playerData.role == 'cop' then
                isBountyBoardOpen = not isBountyBoardOpen
                if isBountyBoardOpen then
                    SendNUIMessage({action = "showBountyBoard", bounties = currentBounties})
                    ShowNotification("~g~Bounty Board opened.")
                else
                    SendNUIMessage({action = "hideBountyBoard"})
                    ShowNotification("~y~Bounty Board closed.")
                end
                SetNuiFocus(isBountyBoardOpen, isBountyBoardOpen)
            else
                ShowNotification("~r~Only Cops can access the Bounty Board.")
            end
        end
    end
end)

RegisterNetEvent('cops_and_robbers:bountyListUpdate')
AddEventHandler('cops_and_robbers:bountyListUpdate', function(bountiesFromServer)
    currentBounties = bountiesFromServer
    if isBountyBoardOpen and playerData.role == 'cop' then
        SendNUIMessage({action="updateBountyList", bounties=currentBounties})
    end
    -- Log for debugging:
    -- local count = 0; for _ in pairs(currentBounties) do count = count + 1 end
    -- print("Client received bounty list update. Count: " .. count)
end)

RegisterNUICallback('closeBountyNUI', function(data, cb)
    isBountyBoardOpen = false
    SetNuiFocus(false, false)
    ShowNotification("~y~Bounty Board closed by NUI button.")
    cb('ok')
end)


RegisterNetEvent('cops_and_robbers:showAdminUI')
AddEventHandler('cops_and_robbers:showAdminUI', function(playerList, isAdminFlag)
    if not isAdminFlag then
        ShowNotification("~r~Admin Panel access denied by server.")
        isAdminPanelOpen = false -- Ensure state is consistent
        SetNuiFocus(false, false) -- Ensure NUI focus is released
        return
    end

    if not isAdminPanelOpen then -- If it was previously closed and now server confirms admin and sends data
        isAdminPanelOpen = true
        SendNUIMessage({
            action = 'showAdminPanel',
            players = playerList
        })
        SetNuiFocus(true, true) -- Set NUI focus only when panel is actually shown with admin rights
        ShowNotification("~g~Admin Panel opened.")
    elseif isAdminPanelOpen and playerList then -- If panel is already open, just refresh player list
         SendNUIMessage({
            action = 'refreshAdminPanelPlayers', -- Assuming JS handles this action to update list
            players = playerList
        })
        ShowNotification("~b~Admin Panel player list refreshed.")
    end
end)

RegisterNetEvent('cops_and_robbers:teleportToPlayerAdminUI')
AddEventHandler('cops_and_robbers:teleportToPlayerAdminUI', function(targetCoordsTable)
    local targetCoords = vector3(targetCoordsTable.x, targetCoordsTable.y, targetCoordsTable.z)
    SetEntityCoords(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, true)
    ShowNotification("~b~Teleported by Admin UI.")
end)


-- =====================================
--           PLAYER POSITION & WANTED LEVEL UPDATES
-- =====================================

-- Periodically send player position and current wanted level to the server
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.ClientPositionUpdateInterval or 5000) -- Update interval from config or default to 5 seconds

        local playerPed = PlayerPedId()
        if DoesEntityExist(playerPed) and playerData.role and playerData.role ~= "citizen" then -- Only send updates if player ped exists and has a meaningful role
            local playerPos = GetEntityCoords(playerPed)
            -- Send currentWantedStarsClient which is updated by cops_and_robbers:updateWantedDisplay
            TriggerServerEvent('cops_and_robbers:updatePosition', playerPos, currentWantedStarsClient)
        end
    end
end)
