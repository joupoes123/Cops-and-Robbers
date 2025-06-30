-- progression_client.lua
-- Enhanced Experience and Leveling System Client-Side
-- Handles UI updates, notifications, and client-side progression features

-- =========================
-- Global Variables
-- =========================
local playerAbilities = {} -- Store unlocked abilities
local currentChallenges = {} -- Store current challenge data
local activeSeasonalEvent = nil -- Current seasonal event
local prestigeInfo = nil -- Player prestige information

-- UI State
local progressionUIVisible = false
local lastXPGain = 0
local xpGainTimer = 0

-- =========================
-- Utility Functions
-- =========================

-- Enhanced logging function
local function LogProgressionClient(message, level)
    level = level or "info"
    if Config and Config.DebugLogging then
        print(string.format("[CNR_PROGRESSION_CLIENT] [%s] %s", string.upper(level), message))
    end
end

-- Show enhanced notification
local function ShowProgressionNotification(message, type, duration)
    type = type or "info"
    duration = duration or 5000
    
    -- Send to NUI for modern notification
    SendNUIMessage({
        action = "showProgressionNotification",
        message = message,
        type = type,
        duration = duration
    })
    
    -- Fallback to game notification
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(false, false)
end

-- Calculate XP for next level (client-side version)
function CalculateXpForNextLevelClient(currentLevel, role)
    if not Config or not Config.LevelingSystemEnabled or currentLevel >= (Config.MaxLevel or 50) then 
        return 0 
    end
    
    return (Config.XPTable and Config.XPTable[currentLevel]) or 1000
end

-- =========================
-- Enhanced XP Display System
-- =========================

-- Update XP display with enhanced animations
function UpdateXPDisplayElements(xp, level, nextLvlXp, xpGained)
    xpGained = xpGained or 0
    
    -- Store values for UI
    currentXP = xp or 0
    currentLevel = level or 1
    currentNextLvlXP = nextLvlXp or 100
    lastXPGain = xpGained
    
    -- Calculate progress percentage
    local totalXPForCurrentLevel = 0
    if Config and Config.XPTable then
        for i = 1, currentLevel - 1 do
            totalXPForCurrentLevel = totalXPForCurrentLevel + (Config.XPTable[i] or 1000)
        end
    end
    
    local xpInCurrentLevel = currentXP - totalXPForCurrentLevel
    local progressPercent = (xpInCurrentLevel / currentNextLvlXP) * 100
    
    -- Send enhanced data to NUI
    SendNUIMessage({
        action = "updateProgressionDisplay",
        data = {
            currentXP = currentXP,
            currentLevel = currentLevel,
            xpForNextLevel = currentNextLvlXP,
            xpGained = xpGained,
            progressPercent = progressPercent,
            xpInCurrentLevel = xpInCurrentLevel,
            prestigeInfo = prestigeInfo,
            seasonalEvent = activeSeasonalEvent
        }
    })
    
    -- Show XP gain animation if there was XP gained
    if xpGained > 0 then
        ShowXPGainAnimation(xpGained)
        xpGainTimer = GetGameTimer() + 3000 -- Show for 3 seconds
    end
    
    LogProgressionClient(string.format("Updated XP display: Level %d, XP %d/%d (+%d)", 
        currentLevel, xpInCurrentLevel, currentNextLvlXP, xpGained))
end

-- Show XP gain animation
function ShowXPGainAnimation(amount)
    SendNUIMessage({
        action = "showXPGainAnimation",
        amount = amount,
        timestamp = GetGameTimer()
    })
    
    -- Play sound effect
    PlaySoundFrontend(-1, "RANK_UP", "HUD_AWARDS", true)
end

-- =========================
-- Level Up Effects
-- =========================

-- Play level up effects
function PlayLevelUpEffects(newLevel)
    -- Screen effect
    SetTransitionTimecycleModifier("MP_Celeb_Win", 2.0)
    
    -- Sound effects
    PlaySoundFrontend(-1, "RANK_UP", "HUD_AWARDS", true)
    Wait(500)
    PlaySoundFrontend(-1, "MEDAL_UP", "HUD_AWARDS", true)
    
    -- Particle effects around player
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    RequestNamedPtfxAsset("scr_indep_fireworks")
    while not HasNamedPtfxAssetLoaded("scr_indep_fireworks") do
        Wait(1)
    end
    
    -- Create firework effect
    UseParticleFxAssetNextCall("scr_indep_fireworks")
    StartParticleFxNonLoopedAtCoord("scr_indep_fireworks_burst_spawn", 
        playerCoords.x, playerCoords.y, playerCoords.z + 2.0, 
        0.0, 0.0, 0.0, 1.0, false, false, false)
    
    -- Show level up UI
    SendNUIMessage({
        action = "showLevelUpAnimation",
        newLevel = newLevel,
        timestamp = GetGameTimer()
    })
    
    -- Clear screen effect after delay
    CreateThread(function()
        Wait(3000)
        ClearTimecycleModifier()
    end)
    
    LogProgressionClient(string.format("Played level up effects for level %d", newLevel))
end

-- =========================
-- Unlock Notifications
-- =========================

-- Show unlock notification
function ShowUnlockNotification(unlock, level)
    local iconMap = {
        item_access = "🔓",
        vehicle_access = "🚗",
        ability = "⚡",
        passive_perk = "🌟",
        cash_reward = "💰"
    }
    
    local icon = iconMap[unlock.type] or "🎉"
    local title = string.format("%s Level %d Unlock!", icon, level)
    
    SendNUIMessage({
        action = "showUnlockNotification",
        unlock = {
            type = unlock.type,
            title = title,
            message = unlock.message,
            icon = icon,
            level = level
        }
    })
    
    -- Play unlock sound
    PlaySoundFrontend(-1, "MEDAL_UP", "HUD_AWARDS", true)
    
    LogProgressionClient(string.format("Showed unlock notification: %s (Level %d)", unlock.type, level))
end

-- =========================
-- Ability System
-- =========================

-- Unlock new ability
function UnlockAbility(abilityId, abilityName)
    playerAbilities[abilityId] = {
        name = abilityName,
        unlocked = true,
        cooldown = 0
    }
    
    SendNUIMessage({
        action = "abilityUnlocked",
        ability = {
            id = abilityId,
            name = abilityName
        }
    })
    
    ShowProgressionNotification(string.format("⚡ New Ability Unlocked: %s", abilityName), "ability", 7000)
    
    LogProgressionClient(string.format("Unlocked ability: %s (%s)", abilityName, abilityId))
end

-- Use ability
function UseAbility(abilityId)
    local ability = playerAbilities[abilityId]
    if not ability or not ability.unlocked then
        ShowProgressionNotification("❌ Ability not unlocked!", "error")
        return false
    end
    
    if ability.cooldown > GetGameTimer() then
        local remainingTime = math.ceil((ability.cooldown - GetGameTimer()) / 1000)
        ShowProgressionNotification(string.format("⏱️ Ability on cooldown: %d seconds", remainingTime), "warning")
        return false
    end
    
    -- Trigger server-side ability logic
    TriggerServerEvent('cnr:useAbility', abilityId)
    
    -- Set cooldown (different for each ability)
    local cooldownTime = GetAbilityCooldown(abilityId)
    ability.cooldown = GetGameTimer() + cooldownTime
    
    SendNUIMessage({
        action = "abilityUsed",
        abilityId = abilityId,
        cooldown = cooldownTime
    })
    
    LogProgressionClient(string.format("Used ability: %s", abilityId))
    return true
end

-- Get ability cooldown time
function GetAbilityCooldown(abilityId)
    local cooldowns = {
        smoke_bomb = 60000,      -- 1 minute
        adrenaline_rush = 120000, -- 2 minutes
        ghost_mode = 300000,     -- 5 minutes
        master_escape = 600000,  -- 10 minutes
        backup_call = 180000,    -- 3 minutes
        tactical_scan = 90000,   -- 1.5 minutes
        crowd_control = 240000,  -- 4 minutes
        detective_mode = 300000  -- 5 minutes
    }
    
    return cooldowns[abilityId] or 60000 -- Default 1 minute
end

-- =========================
-- Challenge System UI
-- =========================

-- Update challenge progress
function UpdateChallengeProgress(challengeId, challengeData)
    currentChallenges[challengeId] = challengeData
    
    SendNUIMessage({
        action = "updateChallengeProgress",
        challengeId = challengeId,
        challengeData = challengeData
    })
    
    -- Show progress notification if significant progress
    local progressPercent = (challengeData.progress / challengeData.target) * 100
    if progressPercent >= 50 and progressPercent < 100 then
        ShowProgressionNotification(string.format("🏆 Challenge Progress: %d/%d", challengeData.progress, challengeData.target), "info", 3000)
    end
end

-- Challenge completed
function ChallengeCompleted(challengeId, challengeData)
    SendNUIMessage({
        action = "challengeCompleted",
        challengeId = challengeId,
        challengeData = challengeData
    })
    
    -- Play completion effects
    PlaySoundFrontend(-1, "MEDAL_UP", "HUD_AWARDS", true)
    
    -- Screen flash effect
    SetFlash(0, 0, 500, 500, 100)
end

-- =========================
-- Prestige System UI
-- =========================

-- Prestige completed
function PrestigeCompleted(prestigeLevel, prestigeReward)
    prestigeInfo = {
        level = prestigeLevel,
        title = prestigeReward.title,
        xpMultiplier = prestigeReward.xpMultiplier
    }
    
    SendNUIMessage({
        action = "prestigeCompleted",
        prestigeLevel = prestigeLevel,
        prestigeReward = prestigeReward
    })
    
    -- Epic prestige effects
    SetTransitionTimecycleModifier("MP_Celeb_Win", 5.0)
    PlaySoundFrontend(-1, "MEDAL_UP", "HUD_AWARDS", true)
    
    -- Multiple particle effects
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    CreateThread(function()
        for i = 1, 5 do
            Wait(500)
            RequestNamedPtfxAsset("scr_indep_fireworks")
            while not HasNamedPtfxAssetLoaded("scr_indep_fireworks") do
                Wait(1)
            end
            
            UseParticleFxAssetNextCall("scr_indep_fireworks")
            StartParticleFxNonLoopedAtCoord("scr_indep_fireworks_burst_spawn", 
                playerCoords.x + math.random(-3, 3), 
                playerCoords.y + math.random(-3, 3), 
                playerCoords.z + math.random(1, 4), 
                0.0, 0.0, 0.0, 1.5, false, false, false)
        end
        
        Wait(3000)
        ClearTimecycleModifier()
    end)
    
    LogProgressionClient(string.format("Prestige completed: Level %d (%s)", prestigeLevel, prestigeReward.title))
end

-- =========================
-- Seasonal Events
-- =========================

-- Seasonal event started
function SeasonalEventStarted(eventData)
    activeSeasonalEvent = eventData
    
    SendNUIMessage({
        action = "seasonalEventStarted",
        eventData = eventData
    })
    
    ShowProgressionNotification(string.format("🎉 %s: %s", eventData.name, eventData.description), "event", 10000)
    
    LogProgressionClient(string.format("Seasonal event started: %s", eventData.name))
end

-- Seasonal event ended
function SeasonalEventEnded(eventName)
    activeSeasonalEvent = nil
    
    SendNUIMessage({
        action = "seasonalEventEnded",
        eventName = eventName
    })
    
    ShowProgressionNotification(string.format("📅 Event Ended: %s", eventName), "info", 5000)
    
    LogProgressionClient(string.format("Seasonal event ended: %s", eventName))
end

-- =========================
-- Progression Menu
-- =========================

-- Toggle progression menu
function ToggleProgressionMenu()
    progressionUIVisible = not progressionUIVisible
    
    SendNUIMessage({
        action = "toggleProgressionMenu",
        visible = progressionUIVisible,
        playerData = {
            level = currentLevel,
            xp = currentXP,
            xpForNext = currentNextLvlXP,
            prestigeInfo = prestigeInfo,
            abilities = playerAbilities,
            challenges = currentChallenges,
            seasonalEvent = activeSeasonalEvent
        }
    })
    
    SetNuiFocus(progressionUIVisible, progressionUIVisible)
end

-- =========================
-- Key Bindings
-- =========================

-- Register key mappings
RegisterKeyMapping('progression_menu', 'Open Progression Menu', 'keyboard', 'P')
RegisterKeyMapping('use_ability_1', 'Use Ability 1', 'keyboard', 'Z')
RegisterKeyMapping('use_ability_2', 'Use Ability 2', 'keyboard', 'X')

-- Command handlers
RegisterCommand('progression_menu', function()
    ToggleProgressionMenu()
end, false)

RegisterCommand('use_ability_1', function()
    -- Use first available ability
    for abilityId, ability in pairs(playerAbilities) do
        if ability.unlocked then
            UseAbility(abilityId)
            break
        end
    end
end, false)

RegisterCommand('use_ability_2', function()
    -- Use second available ability
    local count = 0
    for abilityId, ability in pairs(playerAbilities) do
        if ability.unlocked then
            count = count + 1
            if count == 2 then
                UseAbility(abilityId)
                break
            end
        end
    end
end, false)

-- =========================
-- Event Handlers
-- =========================

-- XP gained
RegisterNetEvent('cnr:xpGained')
AddEventHandler('cnr:xpGained', function(amount, reason)
    UpdateXPDisplayElements(currentXP + amount, currentLevel, currentNextLvlXP, amount)
    
    if reason then
        ShowProgressionNotification(string.format("+%d XP (%s)", amount, reason), "xp", 3000)
    end
end)

-- Level up
RegisterNetEvent('cnr:levelUp')
AddEventHandler('cnr:levelUp', function(newLevel, newTotalXp)
    local oldLevel = currentLevel
    currentLevel = newLevel
    currentXP = newTotalXp
    
    PlayLevelUpEffects(newLevel)
    ShowProgressionNotification(string.format("🎉 LEVEL UP! You reached Level %d!", newLevel), "levelup", 7000)
end)

-- Play level up effects
RegisterNetEvent('cnr:playLevelUpEffects')
AddEventHandler('cnr:playLevelUpEffects', function(newLevel)
    PlayLevelUpEffects(newLevel)
end)

-- Show unlock notification
RegisterNetEvent('cnr:showUnlockNotification')
AddEventHandler('cnr:showUnlockNotification', function(unlock, level)
    ShowUnlockNotification(unlock, level)
end)

-- Unlock ability
RegisterNetEvent('cnr:unlockAbility')
AddEventHandler('cnr:unlockAbility', function(abilityId, abilityName)
    UnlockAbility(abilityId, abilityName)
end)

-- Update challenge progress
RegisterNetEvent('cnr:updateChallengeProgress')
AddEventHandler('cnr:updateChallengeProgress', function(challengeId, challengeData)
    UpdateChallengeProgress(challengeId, challengeData)
end)

-- Challenge completed
RegisterNetEvent('cnr:challengeCompleted')
AddEventHandler('cnr:challengeCompleted', function(challengeId, challengeData)
    ChallengeCompleted(challengeId, challengeData)
end)

-- Prestige completed
RegisterNetEvent('cnr:prestigeComplete')
AddEventHandler('cnr:prestigeComplete', function(prestigeLevel, prestigeReward)
    PrestigeCompleted(prestigeLevel, prestigeReward)
end)

-- Seasonal event started
RegisterNetEvent('cnr:seasonalEventStarted')
AddEventHandler('cnr:seasonalEventStarted', function(eventData)
    SeasonalEventStarted(eventData)
end)

-- Seasonal event ended
RegisterNetEvent('cnr:seasonalEventEnded')
AddEventHandler('cnr:seasonalEventEnded', function(eventName)
    SeasonalEventEnded(eventName)
end)

-- =========================
-- NUI Callbacks
-- =========================

-- Handle NUI callbacks
RegisterNUICallback('closeProgressionMenu', function(data, cb)
    progressionUIVisible = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('useAbility', function(data, cb)
    if data.abilityId then
        UseAbility(data.abilityId)
    end
    cb('ok')
end)

RegisterNUICallback('requestPrestige', function(data, cb)
    TriggerServerEvent('cnr:requestPrestige')
    cb('ok')
end)

-- =========================
-- Initialization
-- =========================

CreateThread(function()
    -- Wait for game to load
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    
    -- Initialize progression system
    LogProgressionClient("Enhanced Progression System (Client) loaded successfully")
    
    -- Request initial data from server
    TriggerServerEvent('cnr:requestProgressionData')
end)

-- Periodic UI updates
CreateThread(function()
    while true do
        Wait(1000)
        
        -- Update ability cooldowns
        for abilityId, ability in pairs(playerAbilities) do
            if ability.cooldown > GetGameTimer() then
                SendNUIMessage({
                    action = "updateAbilityCooldown",
                    abilityId = abilityId,
                    remaining = ability.cooldown - GetGameTimer()
                })
            end
        end
        
        -- Hide XP gain display after timer
        if xpGainTimer > 0 and GetGameTimer() > xpGainTimer then
            xpGainTimer = 0
            SendNUIMessage({
                action = "hideXPGainDisplay"
            })
        end
    end
end)