-- config.lua
-- Cops & Robbers FiveM Game Mode Configuration File
-- Version: 1.1 | Date: 2025-02-11
-- This file contains all the configuration settings for the game mode.
-- Make sure this file is loaded before any scripts that depend on Config.

-- Initialize Config table if not already initialized
Config = Config or {}


-- =========================
--        General Settings
-- =========================

Config.MaxPlayers     = 64
Config.HeistCooldown  = 600    -- seconds (10 minutes), Cooldown between major heists for a player or globally.
Config.HeistRadius    = 1000.0 -- meters, General radius for heist related activities or blips.
Config.DefaultStartMoney = 2500 -- Starting cash for new players.

-- Spawn locations based on roles
Config.SpawnPoints = {
    cop    = vector3(452.6, -980.0, 30.7),   -- Police station location (Mission Row PD)
    robber = vector3(2126.7, 4794.1, 41.1)   -- Example: Countryside airport location (Sandy Shores Airfield)
}

-- Jail Location (players are sent here when jailed)
Config.PrisonLocation = vector3(1651.0, 2570.0, 45.5) -- Bolingbroke Penitentiary (example)


-- =========================
--       Bank Vaults
-- =========================
-- Locations for potential bank heists.
Config.BankVaults = {
    { location = vector3(150.0, -1040.0, 29.0),   name = "Pacific Standard Bank",    id = 1 },
    { location = vector3(-1212.0, -330.0, 37.8),  name = "Fleeca Bank (Vinewood)",   id = 2 },
    { location = vector3(-2962.6, 482.9, 15.7),   name = "Fleeca Bank (Great Ocean)",id = 3 },
    { location = vector3(1175.0, 2706.8, 38.1),   name = "Fleeca Bank (Route 68)",   id = 4 },
    { location = vector3(-351.0, -49.0, 49.0),    name = "Blaine County Savings",    id = 5 },
}


-- =========================
-- Police and Civilian Vehicles
-- =========================
-- Lists of vehicle models used for various game mode mechanics.
Config.PoliceVehicles   = { "police", "police2", "police3", "fbi", "fbi2", "policet", "sheriff", "sheriff2" }
Config.CivilianVehicles = { "sultan", "futo", "blista", "banshee", "elegy2", "stratum", "issi2", "prairie" }


-- =========================
-- Experience and Leveling System (Legacy)
-- =========================
-- Legacy Config.Experience table removed.


-- =========================
--    Wanted Level System (Legacy/Simple)
-- =========================
-- Legacy Config.WantedLevels table removed.


-- =========================
--   Ammu-Nation Store Locations
-- =========================
-- These are coordinates for Ammu-Nation store interaction points.
Config.AmmuNationStores = {
    vector3(1692.41, 3758.22, 34.70),  -- Sandy Shores
    vector3(252.89, -49.25, 69.94),    -- Pillbox Hill, Downtown
    vector3(844.35, -1033.42, 28.19),  -- La Mesa / Cypress Flats
    vector3(-331.35, 6083.45, 31.45),  -- Paleto Bay
    vector3(-662.1, -935.3, 21.8),     -- Vespucci Canals / Pillbox South
    vector3(-1305.18, -393.48, 36.70), -- Morningwood
    vector3(2567.69, 294.38, 108.73),  -- Tataviam Mountains (Route 68)
    vector3(-1117.58, 2698.61, 18.55), -- Chumash
    vector3(811.19, -2157.67, 29.62),  -- Popular Street, South LS
    vector3(21.6, -1106.7, 29.8)       -- Pillbox Hill (alternate entrance)
}


-- =========================
--     NPC Vendor Configurations
-- =========================
-- Defines NPC vendors, their locations, models, and items they sell.
Config.NPCVendors = {
    {
        location = vector3(-1107.17, 4949.54, 218.65), -- Grapeseed, near airfield
        heading  = 140.0,
        model    = "s_m_y_dealer_01",
        name     = "Black Market Dealer",
        items    = { "weapon_knife", "weapon_switchblade", "weapon_microsmg", "ammo_smg", "lockpick", "mask", "c4", "drill" } -- Item IDs from Config.Items
    },
    {
        location = vector3(1961.48, 3740.69, 32.34),  -- Sandy Shores, near barber
        heading  = 300.0,
        model    = "g_m_y_mexgang_01",
        name     = "Gang Supplier",
        items    = { "weapon_pistol", "weapon_sawnoffshotgun", "ammo_shotgun", "armor", "bandana" } -- Changed weapon_pistol50 to weapon_pistol for consistency
    },
    -- Additional NPC vendors can be added here following the same structure.
}


-- =========================
--      Item Definitions (for Stores & NPC Vendors)
-- =========================
-- Defines items available for purchase, their prices, categories, and restrictions.
-- `itemId`: Must be a valid weapon hash (e.g., "weapon_pistol") or a custom item ID string.
-- `basePrice`: Default price of the item. Can be adjusted by dynamic economy.
-- `category`: Used for NUI store filtering (e.g., "Weapons", "Ammunition", "Utility").
-- `forCop`: If true, item is typically restricted to cops in general stores (server-side logic enforces).
-- `minLevelCop`, `minLevelRobber`: Minimum player level required for the respective role to purchase/use this item.
Config.Items = {
    -- Weapons
    { name = "Pistol",            itemId = "weapon_pistol",         basePrice = 500,  category = "Weapons" },
    { name = "Combat Pistol",     itemId = "weapon_combatpistol",   basePrice = 750,  category = "Weapons" },
    { name = "Heavy Pistol",      itemId = "weapon_heavypistol",    basePrice = 1000, category = "Weapons", minLevelCop = 5, minLevelRobber = 7 },
    { name = "SMG",               itemId = "weapon_smg",            basePrice = 1500, category = "Weapons" },
    { name = "Micro SMG",         itemId = "weapon_microsmg",       basePrice = 1250, category = "Weapons" },
    { name = "Assault Rifle",     itemId = "weapon_assaultrifle",   basePrice = 2500, category = "Weapons", minLevelCop = 8, minLevelRobber = 10 },
    { name = "Carbine Rifle",     itemId = "weapon_carbinerifle",   basePrice = 3000, category = "Weapons", forCop = true, minLevelCop = 4 },
    { name = "Sniper Rifle",      itemId = "weapon_sniperrifle",    basePrice = 5000, category = "Weapons", minLevelCop = 10, minLevelRobber = 10 },
    { name = "Pump Shotgun",      itemId = "weapon_pumpshotgun",    basePrice = 1200, category = "Weapons" },
    { name = "Sawed-Off Shotgun", itemId = "weapon_sawnoffshotgun", basePrice = 1000, category = "Weapons" },

    -- Melee Weapons
    { name = "Knife",             itemId = "weapon_knife",          basePrice = 100,  category = "Melee Weapons" },
    { name = "Bat",               itemId = "weapon_bat",            basePrice = 50,   category = "Melee Weapons" },
    { name = "Crowbar",           itemId = "weapon_crowbar",        basePrice = 75,   category = "Melee Weapons" },
    { name = "Switchblade",       itemId = "weapon_switchblade",    basePrice = 150,  category = "Melee Weapons" },
    { name = "Flashlight",        itemId = "weapon_flashlight",     basePrice = 100,  category = "Melee Weapons" }, -- Often considered a melee weapon too

    -- Ammunition (ammo_X corresponds to weapon type, not specific weapon model)
    { name = "Pistol Ammo",       itemId = "ammo_pistol",           basePrice = 50,   category = "Ammunition" }, -- For all pistols
    { name = "SMG Ammo",          itemId = "ammo_smg",              basePrice = 75,   category = "Ammunition" }, -- For all SMGs
    { name = "Rifle Ammo",        itemId = "ammo_rifle",            basePrice = 100,  category = "Ammunition" }, -- For all assault/carbine rifles
    { name = "Shotgun Ammo",      itemId = "ammo_shotgun",          basePrice = 60,   category = "Ammunition" }, -- For all shotguns
    { name = "Sniper Ammo",       itemId = "ammo_sniper",           basePrice = 200,  category = "Ammunition" }, -- For all sniper rifles

    -- Armor and Utility
    { name = "Body Armor",        itemId = "armor",                 basePrice = 500,  category = "Armor" },
    { name = "Heavy Armor",       itemId = "heavy_armor",           basePrice = 1000, category = "Armor", minLevelCop = 6, minLevelRobber = 8 },
    { name = "Medkit",            itemId = "medkit",                basePrice = 250,  category = "Utility" }, -- Custom item, server logic for effect
    { name = "First Aid Kit",     itemId = "firstaidkit",           basePrice = 100,  category = "Utility" }, -- Custom item, server logic for effect
    { name = "Lockpick",          itemId = "lockpick",              basePrice = 150,  category = "Utility" }, -- Custom item
    { name = "Advanced Lockpick", itemId = "adv_lockpick",          basePrice = 300,  category = "Utility", minLevelRobber = 4 },
    { name = "Parachute",         itemId = "gadget_parachute",      basePrice = 300,  category = "Utility" }, -- Built-in gadget
    { name = "Drill",             itemId = "drill",                 basePrice = 500,  category = "Utility", minLevelRobber = 3 },
    { name = "C4 Explosive",      itemId = "c4",                    basePrice = 2000, category = "Utility", minLevelRobber = 9 },

    -- Accessories (Primarily for role-play or appearance, server logic might give minor effects)
    { name = "Mask",              itemId = "mask",                  basePrice = 200,  category = "Accessories" },
    { name = "Gloves",            itemId = "gloves",                basePrice = 100,  category = "Accessories" },
    { name = "Hat",               itemId = "hat",                   basePrice = 150,  category = "Accessories" },
    { name = "Bandana",           itemId = "bandana",               basePrice = 80,   category = "Accessories" },
    { name = "Sunglasses",        itemId = "sunglasses",            basePrice = 120,  category = "Accessories" },

    -- Cop Gear (Restricted items for Cops)
    { name = "Spike Strip",       itemId = "spikestrip_item",       basePrice = 250,  category = "Cop Gear", forCop = true },
    { name = "Speed Radar Gun",   itemId = "speedradar_gun",        basePrice = 500,  category = "Cop Gear", forCop = true, minLevelCop = 2 },
    { name = "K9 Whistle",        itemId = "k9whistle",             basePrice = 1000, category = "Cop Gear", forCop = true, minLevelCop = 3 },

    -- Robber Gear (Restricted items for Robbers)
    { name = "EMP Device",        itemId = "emp_device",            basePrice = 2500, category = "Robber Gear", minLevelRobber = 5 }
}

-- =========================
-- Cop Feature Settings
-- =========================
Config.SpikeStripDuration     = 60000  -- milliseconds (60 seconds) until a spike strip automatically despawns.
Config.MaxDeployedSpikeStrips = 3      -- Max spike strips a cop can have deployed simultaneously (server-side check).

Config.SpeedLimitKmh          = 80.0   -- km/h for speed radar. Client uses this for display, server for fine logic. (Renamed from SpeedLimit for clarity)
Config.SpeedingFine           = 250    -- Amount of fine for speeding.

Config.TackleDistance         = 2.0    -- meters, max distance for a cop to initiate a tackle/subdue.
Config.SubdueTimeMs           = 3000   -- milliseconds, time it takes to complete a subdue action (before arrest is processed). (Renamed from SubdueTime for clarity)

Config.K9FollowDistance       = 3.0    -- meters, how far K9 will stay behind cop when following. (Adjusted from 5.0 for closer follow)
Config.K9AttackSearchRadius   = 50.0   -- meters, radius cop can command K9 to search for a target.
Config.K9AttackDistance       = 2.0    -- meters, how close K9 needs to be to initiate an attack (visual/gameplay feel).
Config.K9AssistWindowSeconds  = 30     -- seconds, time window after K9 engagement for an arrest to be considered K9 assisted.


-- =========================
-- Robber Feature Settings
-- =========================
Config.RobbableStores = { -- List of stores that can be robbed
    { name = "LTD Gasoline Grove St", location = vector3(100.0, -1700.0, 29.0), rewardMin = 3000, rewardMax = 6000, cooldown = 300, copsNeeded = 1, radius = 10.0, duration = 45000 },
    { name = "24/7 Strawberry",       location = vector3(25.0, -1340.0, 29.0),  rewardMin = 5000, rewardMax = 9000, cooldown = 400, copsNeeded = 2, radius = 10.0, duration = 60000 },
    -- Add more stores here: { name, location (vector3), rewardMin, rewardMax (cash), cooldown (seconds), copsNeeded (integer), radius (meters for interaction), duration (ms for robbing) }
}
-- Config.StoreRobberyDuration line removed by subtask

Config.ArmoredCar = {
    model          = "stockade",                       -- Vehicle model for the armored car.
    spawnPoint     = vector3(450.0, -1000.0, 28.0),    -- Example spawn point.
    route          = {                                 -- Example route points for NPC driver.
                       vector3(400.0, -1100.0, 28.0),
                       vector3(300.0, -1200.0, 28.0),
                       vector3(200.0, -1300.0, 28.0)
                     },
    rewardMin      = 15000,                            -- Minimum cash reward.
    rewardMax      = 25000,                            -- Maximum cash reward.
    health         = 2500,                             -- Health of the armored car (increased from 2000).
    despawnTime    = 10 * 60 * 1000,                   -- Time in ms before an unlooted armored car despawns (10 minutes).
    lootingTimeMs  = 10000                             -- Time in ms it takes to loot the armored car once stopped/destroyed.
}
Config.ArmoredCarHeistCooldown   = 1800  -- seconds (30 minutes) cooldown before another armored car can spawn.
Config.ArmoredCarHeistCopsNeeded = 3     -- Minimum number of cops online for the armored car event to start.

Config.EMPRadius                   = 15.0  -- meters, radius of effect for the EMP device.
Config.EMPDisableDurationMs        = 5000  -- milliseconds (5 seconds), how long vehicles are disabled by EMP. (Renamed for clarity)

Config.PowerGrids = { -- Locations of power grids that can be sabotaged
    { name = "Downtown Power Grid", location = vector3(-500.0, -500.0, 30.0), radius = 150.0, sabotageTimeMs = 10000 }, -- Radius is for client-side visual effects if any. SabotageTimeMs is time to interact.
    { name = "Port Power Station",  location = vector3(700.0, -1500.0, 25.0), radius = 200.0, sabotageTimeMs = 15000 },
    -- Add more power grids here: { name, location (vector3), radius (optional for effects), sabotageTimeMs (ms) }
}
Config.PowerOutageDurationMs       = 120000 -- milliseconds (2 minutes) how long a specific grid's power stays out. (Renamed for clarity)
Config.PowerGridSabotageCooldown   = 600    -- seconds (10 minutes) cooldown before the same grid can be sabotaged again.

-- =========================
-- Advanced Wanted System Settings
-- =========================
Config.WantedSettings = {
    baseIncreasePoints = 1,    -- Default points for minor infractions if not specified in crimes. (Renamed from baseIncrease)
    levels = {                 -- Defines star levels and UI labels based on accumulated wanted points.
        { stars = 1, threshold = 10,  uiLabel = "Wanted: ★☆☆☆☆", minPunishment = 60,  maxPunishment = 120 }, -- Punishment in seconds (jail time)
        { stars = 2, threshold = 30,  uiLabel = "Wanted: ★★☆☆☆", minPunishment = 120, maxPunishment = 240 },
        { stars = 3, threshold = 60,  uiLabel = "Wanted: ★★★☆☆", minPunishment = 240, maxPunishment = 480 },
        { stars = 4, threshold = 100, uiLabel = "Wanted: ★★★★☆", minPunishment = 480, maxPunishment = 720 },
        { stars = 5, threshold = 150, uiLabel = "Wanted: ★★★★★", minPunishment = 720, maxPunishment = 1000 }
    },
    crimes = {                 -- Points assigned for specific crimes. These keys are used in server.lua when calling IncreaseWantedPoints.
        -- Traffic Violations
        speeding                   = 1,    -- For receiving a speeding ticket.
        reckless_driving           = 2,    -- Example: driving on sidewalk, excessive near misses.
        hit_and_run_vehicle        = 3,    -- Hitting a vehicle and fleeing.
        hit_and_run_ped            = 5,    -- Hitting a pedestrian and fleeing.
        -- Property Crimes
        grand_theft_auto           = 5,    -- Stealing an occupied vehicle.
        store_robbery_small        = 5,    -- Example: For smaller, less risky store robberies.
        store_robbery_medium       = 10,   -- For general store robberies.
        armed_robbery_player       = 8,    -- Robbing another player at gunpoint (if implemented).
        -- Major Heists
        bank_heist_major           = 20,   -- For successful major bank heists.
        armored_car_heist          = 15,   -- For successful armored car heists.
        -- Violent Crimes
        assault_civilian           = 3,    -- Assaulting a civilian without killing.
        murder_civilian            = 10,   -- For killing a civilian.
        assault_cop                = 15,   -- For assaulting a police officer.
        murder_cop                 = 25,   -- For killing a police officer.
        -- Other
        resisting_arrest           = 5,    -- Fleeing from police after being told to stop.
        jailbreak_attempt          = 30,   -- Attempting to break someone out of jail.
        emp_used_on_police         = 8,    -- Using EMP that affects police vehicles.
        power_grid_sabotaged_crime = 8     -- Sabotaging power grid (distinct from XP action).
    },
    decayRatePoints      = 1,    -- Amount of wanted points to decay per interval. (Renamed from decayRate)
    decayIntervalMs      = 30000,-- Milliseconds (30 seconds) - how often the decay check runs. (Renamed from decayInterval)
    noCrimeCooldownMs    = 60000,-- Milliseconds (60 seconds) - time player must be "clean" (no new crimes committed) before decay starts. (Renamed from decayCooldown)
    copSightCooldownMs   = 30000,-- Milliseconds (30 seconds) - time player must be out of cop sight for decay to resume (if decay was paused due to cop sight). (Renamed from sightCooldown)
    copSightDistance     = 75.0  -- meters, how far a cop can "see" a wanted player to pause decay.
}


-- =========================
-- Wanted System: Granular Consequences
-- =========================
-- Defines NPC police response groups based on wanted level.
-- Each preset (e.g., [1] for 1-star) is an array of groups to spawn.
Config.WantedNPCPresets = {
    [1] = { -- 1 Star: Local patrol response
        { count = 1, pedModel = "s_m_y_cop_01", vehicle = "police", weapon = "weapon_pistol", accuracy = 10, armour = 25, sightDistance = 60.0, spawnGroup = "WANTED_LVL_1_PATROL" },
    },
    [2] = { -- 2 Stars: More patrol cars
        { count = 2, pedModel = "s_m_y_cop_01", vehicle = "police", weapon = "weapon_pistol", accuracy = 15, armour = 50, sightDistance = 70.0, spawnGroup = "WANTED_LVL_2_PATROL_A" },
        { count = 1, pedModel = "s_m_y_cop_01", vehicle = "police2", weapon = "weapon_combatpistol", accuracy = 20, armour = 50, sightDistance = 70.0, spawnGroup = "WANTED_LVL_2_PATROL_B" },
    },
    [3] = { -- 3 Stars: Stronger units, some SMGs
        { count = 2, pedModel = "s_m_y_cop_01", vehicle = "police3", weapon = "weapon_smg", accuracy = 25, armour = 75, sightDistance = 80.0, spawnGroup = "WANTED_LVL_3_SMG_UNITS" },
        { count = 2, pedModel = "s_f_y_cop_01", vehicle = "police", weapon = "weapon_pumpshotgun", accuracy = 20, armour = 75, sightDistance = 80.0, spawnGroup = "WANTED_LVL_3_SHOTGUN_UNITS" },
    },
    [4] = { -- 4 Stars: FIB/SWAT-like response, rifles
        { count = 2, pedModel = "s_m_y_swat_01", vehicle = "fbi", weapon = "weapon_carbinerifle", accuracy = 35, armour = 100, sightDistance = 90.0, spawnGroup = "WANTED_LVL_4_SWAT_A" },
        { count = 2, pedModel = "s_m_y_swat_01", vehicle = "fbi2", weapon = "weapon_assaultrifle", accuracy = 30, armour = 100, sightDistance = 90.0, spawnGroup = "WANTED_LVL_4_SWAT_B" },
        -- Example for helicopter, if desired (ensure model is valid and spawn logic handles air vehicles)
        -- { count = 1, pedModel = "s_m_y_pilot_01", helicopter = "polmav", weapon = "weapon_smg", accuracy = 20, spawnGroup = "WANTED_LVL_4_AIR_SUPPORT", helicopterChance = 0.3 }
    },
    [5] = { -- 5 Stars: Heavy response, multiple groups
        { count = 3, pedModel = "s_m_y_swat_01", vehicle = "fbi", weapon = "weapon_carbinerifle", accuracy = 40, armour = 100, sightDistance = 100.0, spawnGroup = "WANTED_LVL_5_HEAVY_SWAT_A" },
        { count = 3, pedModel = "s_m_y_swat_01", vehicle = "fbi2", weapon = "weapon_advancedrifle", accuracy = 35, armour = 100, sightDistance = 100.0, spawnGroup = "WANTED_LVL_5_HEAVY_SWAT_B" },
        { count = 2, pedModel = "s_m_y_cop_01", vehicle = "policet", weapon = "weapon_pumpshotgun", accuracy = 25, armour = 75, spawnGroup = "WANTED_LVL_5_RIOT_SUPPORT" },
        -- { count = 1, pedModel = "s_m_y_pilot_01", helicopter = "savage", weapon = "weapon_minigun", accuracy = 30, spawnGroup = "WANTED_LVL_5_ATTACK_HELI", helicopterChance = 0.5 }
    }
}
Config.MaxActiveNPCResponseGroups = 5 -- Set to a non-zero value

Config.RestrictedAreas = {
    { name = "Fort Zancudo", center = vector3(-2177.0, 3210.0, 32.0), radius = 750.0, wantedThreshold = 1, message = "~r~You are entering Fort Zancudo airspace! Turn back immediately or you will be engaged!", wantedPoints = 20 },
    { name = "Humane Labs",  center = vector3(3615.0, 3740.0, 28.0),  radius = 300.0, wantedThreshold = 2, message = "~y~Warning: Highly restricted area (Humane Labs). Increased security presence.", wantedPoints = 15 },
    { name = "Prison Grounds", center = Config.PrisonLocation, radius = 250.0, wantedThreshold = 0, message = "~o~You are on prison grounds. Loitering is discouraged.", wantedPoints = 5, ifNotRobber = true }, -- Example: give points if not a robber (e.g. cops shouldn't get points here)
    -- Add more areas: { name, center (vector3), radius (float), wantedThreshold (stars to trigger message/response), message (string), wantedPoints (points to add if entered), ifNotRobber (optional bool) }
}

-- =========================
-- Wanted System: Active Reduction Methods
-- =========================
Config.CorruptOfficials = {
    {
        name        = "Shady Contact at Docks",
        location    = vector3(480.0, -1905.0, 23.0),
        model       = "s_m_y_dealer_01",
        costPerStar = 5000,
        cooldownMs  = 30 * 60 * 1000, -- 30 minutes in milliseconds (Renamed from cooldown)
        dialogue    = "Psst... need to lower your heat? It'll cost you. $%s per star." -- %s will be replaced with cost
    },
    -- Add more officials: { name, location (vector3), model (string), costPerStar (int), cooldownMs (ms), dialogue (string) }
}

Config.AppearanceChangeStores = {
    {
        name                  = "Suburban Outfit Change",
        location              = vector3(-1195.0, -770.0, 17.0), -- Example Suburban Store
        cost                  = 500,
        wantedReductionPoints = 15,                             -- Reduce wanted points by this amount
        cooldownMs            = 15 * 60 * 1000                  -- 15 minutes in milliseconds (Renamed from cooldown)
    },
    -- Add more stores: { name, location (vector3), cost (int), wantedReductionPoints (int), cooldownMs (ms) }
}


-- =========================
-- Contraband Drop Settings
-- =========================
Config.ContrabandDropLocations = {   -- Possible locations for contraband drops (vector3)
    vector3(200.0, -2000.0, 20.0),   -- Example: Near the docks
    vector3(-1500.0, 800.0, 180.0),  -- Example: Remote mountain area
    vector3(2500.0, 3500.0, 30.0),   -- Example: Sandy Shores airfield
    vector3(100.0, 650.0, 200.0),    -- Example: Vinewood Hills
    vector3(1200.0, -300.0, 60.0)    -- Example: East Los Santos
}
Config.ContrabandItems = { -- Items that can be found in contraband drops. ModelHash is for the prop spawned.
    { name = "Gold Bars",          itemId = "goldbars",       value = 10000, modelHash = "prop_gold_bar",        weight = 10 },
    { name = "Illegal Arms Cache", itemId = "illegal_arms",   value = 7500,  modelHash = "prop_box_ammo04a",     weight = 20 },
    { name = "Drugs Package",      itemId = "drug_package",   value = 5000,  modelHash = "prop_cs_drug_pack_01", weight = 15 },
    { name = "Weapon Parts",       itemId = "weapon_parts",   value = 6000,  modelHash = "prop_gun_case_01",     weight = 25 }
    -- `weight` can be used for weighted random selection if desired.
}
Config.ContrabandDropIntervalMs   = 30 * 60 * 1000 -- milliseconds (30 minutes) (Renamed from ContrabandDropInterval)
Config.MaxActiveContrabandDrops   = 2              -- Max concurrent drops active on the map.
Config.ContrabandCollectionTimeMs = 5000           -- milliseconds (5 seconds to collect). (Renamed from ContrabandCollectionTime)


-- =========================
--        Safe Zones
-- =========================
-- Areas where combat is disabled and players might be invincible.
Config.SafeZones = {
    { name = "Mission Row PD Lobby",  location = vector3(427.0, -981.0, 30.7), radius = 15.0, message = "You have entered the Safe Zone: Mission Row Lobby." },
    { name = "Paleto Bay Sheriff Office", location = vector3(-448.0, 6010.0, 31.7), radius = 20.0, message = "Safe Zone: Paleto Sheriff Office." },
    { name = "Sandy Shores Hospital",   location = vector3(1837.0, 3672.9, 34.3), radius = 25.0, message = "You are in a Hospital Safe Zone." },
    { name = "Central LS Medical",    location = vector3(355.7, -596.3, 28.8), radius = 30.0, message = "Safe Zone: Central LS Medical Center." }
    -- Add more safe zones: { name (string), location (vector3), radius (float), message (string) }
}


-- =========================
-- Team Balancing Settings
-- =========================
Config.TeamBalanceSettings = {
    enabled             = true,  -- true to enable team balancing incentives, false to disable.
    threshold           = 2,     -- Minimum difference in online team member counts (e.g., 2 more cops than robbers) to trigger the incentive for robbers.
    incentiveCash       = 1000,  -- Amount of bonus cash given to a player for joining the underdog team.
    notificationMessage = "You received a bonus of $%s for joining the %s team to help with team balance!" -- Message sent to player. %s are for amount and team name.
}

-- =========================
--  Dynamic Economy Settings
-- =========================
-- Settings for adjusting item prices based on purchase history.
Config.DynamicEconomy = {
    enabled                = true,   -- Set to false to disable dynamic pricing and always use basePrice.
    popularityTimeframe    = 3 * 60 * 60, -- seconds (3 hours). How far back to look in purchase_history.json.
    priceIncreaseFactor    = 1.2,    -- Multiply basePrice by this for popular items (20% increase).
    priceDecreaseFactor    = 0.8,    -- Multiply basePrice by this for unpopular items (20% decrease).
    popularityThresholdHigh = 10,    -- Items purchased more than this many times in timeframe are "popular".
    popularityThresholdLow  = 2,     -- Items purchased less than this many times are "unpopular".
    sellPriceFactor        = 0.5     -- Players get this percentage of the item's current dynamic price when selling.
}


-- =========================
--   Additional Configurations & Admin Settings
-- =========================

-- List of banned player identifiers (e.g., steam IDs, license IDs).
-- These are loaded by server.lua at startup and merged with any bans stored in bans.json.
-- Format: ["identifier_string"] = { reason = "Reason for ban", timestamp = os.time(), admin = "AdminNameWhoBanned" }
Config.BannedPlayers = {
    -- Example:
    -- ["steam:110000112345678"] = { reason = "Cheating", timestamp = 1625078400, admin = "Server" },
    -- ["license:abcdefghijklmnop"] = { reason = "Harassment", timestamp = 1625078400, admin = "AdminName" },
}

-- Admin identifiers for privileged actions (e.g., using admin commands, accessing admin UI panel).
-- This table is the primary mechanism for granting admin rights.
-- Server-side checks should use player identifiers (e.g., GetPlayerIdentifiers(source)['steam'], GetPlayerIdentifiers(source)['license']).
Config.Admins = {
    -- Example: Populate with admin identifiers (steam:xxx, license:xxx, fivem:xxx, discord:xxx)
    -- ["steam:110000100000001"]   = true,
    -- ["license:yourlicenseidhere"] = true,
}


-- =========================
--      Heist Settings (General)
-- =========================
-- General settings applicable to various heists. Specific heists might have their own tables.
Config.HeistSettings = {
    globalCooldownMs = 15 * 60 * 1000, -- milliseconds (15 minutes) global cooldown between *any* major heist type.
    copsRequiredForMajorHeist = 3,     -- Minimum number of cops online to start a major heist (e.g., bank, armored car).
}

-- Example: Heist timer durations (can be overridden by specific heist configs)
Config.HeistTimers = {
    defaultHeistDurationSecs = 600, -- Default duration of a heist phase in seconds (10 minutes) if not specified.
}


-- =========================
--    Vehicle Spawn Settings
-- =========================
-- Locations where roles can spawn their vehicles.
Config.PoliceVehicleSpawns = {
    { location = vector3(450.0, -994.0, 25.7), heading = 270.0 }, -- Mission Row PD Garage side
    { location = vector3(465.0, -1016.0, 28.0), heading = 0.0 },   -- Mission Row PD Backlot
    -- Add more spawn points as needed
}

Config.RobberVehicleSpawns = { -- Example, might not be used if robbers acquire vehicles differently
    { location = vector3(2120.7, 4780.1, 40.0), heading = 180.0 }, -- Near Robber spawn
    -- Add more spawn points as needed
}

-- Added by integrity check subtask - Default/Fallback values
Config.MaxCops = 10 -- Example max cops
Config.PlayerCountSyncInterval = 30 -- Seconds, example
Config.PerkEffects = {
    IncreasedArmorDurabilityModifier = 1.25 -- Example: 25% more armor
}

-- =========================
-- Keybind Configuration (Client-Side Usage Primarily)
-- =========================
-- Define default control inputs for various actions.
-- These can be used by client-side RegisterKeyMapping if players are allowed to change them.
-- Otherwise, client scripts will use IsControlJustPressed with these defaults.
-- See FiveM native docs for control list: https://docs.fivem.net/docs/game-references/controls/
Config.Keybinds = {
    toggleSpeedRadar    = 17,  -- INPUT_CELLPHONE_SCROLL_BACKWARD (PageUp)
    fineSpeeder         = 74,  -- INPUT_VEH_HEADLIGHT (H)
    fineSpeederKeyName  = "H", -- Display name for the fine key
    deploySpikeStrip    = 19,  -- INPUT_PREV_WEAPON (Home) - Placeholder, consider a less common key
    tackleSubdue        = 47,  -- INPUT_WEAPON_SPECIAL_TWO (G) - Placeholder
    toggleK9            = 311, -- INPUT_VEH_CIN_CAM (K) - Placeholder, may conflict
    commandK9Attack     = 38,  -- INPUT_CONTEXT (E) - Placeholder, often used for general interaction
    activateEMP         = 121, -- INPUT_SELECT_WEAPON_UNARMED (Numpad 0) - Placeholder
    toggleAdminPanel    = 289  -- INPUT_REPLAY_STOPRECORDING (F10) - Placeholder
    -- Add other keybinds as needed
}


-- =========================
-- Player Leveling System (New & Detailed)
-- =========================
Config.LevelingSystemEnabled = true -- Master switch for this leveling system.

-- XP required to reach the NEXT level. Key is the CURRENT level. Value is XP needed to get from current_level to current_level+1.
Config.XPTable = {
    [1] = 100,  -- XP to reach Level 2 (from Lvl 1)
    [2] = 250,  -- XP to reach Level 3 (from Lvl 2)
    [3] = 500,  -- XP to reach Level 4
    [4] = 750,  -- XP to reach Level 5
    [5] = 1000, -- XP to reach Level 6
    [6] = 1300, -- XP to reach Level 7
    [7] = 1600, -- XP to reach Level 8
    [8] = 2000, -- XP to reach Level 9
    [9] = 2500  -- XP to reach Level 10
    -- Level 10 is max for these examples, so no entry for XPTable[10] to reach 11.
}
Config.MaxLevel = 10 -- Maximum attainable level in this system.

-- XP awarded for specific actions. Keys should be unique and descriptive, used in server-side AddXP calls.
Config.XPActionsRobber = {
    successful_store_robbery_medium = 20, -- XP for a standard store robbery.
    successful_armored_car_heist  = 50, -- XP for completing an armored car heist.
    successful_bank_heist_major   = 75, -- Placeholder XP for future major bank heists.
    contraband_collected          = 15, -- XP for collecting a contraband drop.
    emp_used_effectively          = 10, -- XP if EMP disables >0 cop cars (server logic determines "effectively").
    power_grid_sabotage_success   = 75  -- XP for successfully sabotaging a power grid. (Aligned with server.lua)
}
Config.XPActionsCop = {
    successful_arrest_low_wanted    = 15, -- Arresting a 1-star suspect
    successful_arrest_medium_wanted = 25, -- Arresting a 2 or 3-star suspect
    successful_arrest_high_wanted   = 40, -- Arresting a 4 or 5-star suspect
    subdue_arrest_bonus             = 10, -- Bonus XP for an arrest made after a successful manual subdue/tackle.
    k9_assist_arrest                = 10, -- K9 played a significant role in an arrest (server logic to determine).
    speeding_fine_issued            = 5,  -- Successfully issuing a speeding ticket.
    spike_strip_hit_assists_arrest  = 15  -- Spike strip deployed by this cop leads to arrest of target (server logic).
}

-- Defines what unlocks at each level for each role.
-- Structure: Config.LevelUnlocks[role][levelNumber] = { table of unlock definitions }
-- Unlock Definition Types:
--   - { type="item_access", itemId="item_id_from_Config.Items", message="Notification message for player." }
--   - { type="passive_perk", perkId="unique_perk_identifier", value=numeric_value_or_true, message="Notification message." } (Server handles perk logic)
--   - { type="vehicle_access", vehicleHash="vehicle_model_hash", name="Display Name", message="Notification message." } (Server handles access logic)
Config.LevelUnlocks = {
    robber = {
        [5] = {
            { type = "item_access", itemId = "emp_device", message = "EMP Device unlocked in Robber stores!" }
        },
        [10] = {
            { type = "passive_perk", perkId = "faster_contraband_collection", value = 0.8, message = "Perk: Contraband collection time reduced by 20%!" }
            -- Example: value = 0.8 means 80% of original time. Server needs to interpret this.
        }
        -- Example for future: [Level] = { {type="...", perkId/itemId="...", value=..., message="..."} , {type="...", ...} }
    },
    cop = {
        [3] = {
            { type = "item_access", itemId = "k9whistle", message = "K9 Whistle unlocked in Cop stores!" }
        },
        [7] = {
            { type = "vehicle_access", vehicleHash = "policeb", name = "Police Bike", message = "Police Bike unlocked for patrol!" }
        },
        [10] = {
            { type = "passive_perk", perkId = "extra_spike_strips", value = 1, message = "Perk: Carry +1 Spike Strip!" }
            -- Example: value = 1 means one additional strip. Server needs to manage this.
        }
    }
}

-- Weapon names mapping for display purposes (e.g., notifications, UI)
Config.WeaponNames = {
    ["weapon_pistol"] = "Pistol",
    ["weapon_combatpistol"] = "Combat Pistol",
    ["weapon_heavypistol"] = "Heavy Pistol",
    ["weapon_smg"] = "SMG",
    ["weapon_microsmg"] = "Micro SMG",
    ["weapon_assaultrifle"] = "Assault Rifle",
    ["weapon_carbinerifle"] = "Carbine Rifle",
    -- Add more as needed
}

-- =========================
--      Bounty Settings
-- =========================
Config.BountySettings = {
    enabled = true,
    wantedLevelThreshold = 4,  -- Min wanted stars to get a bounty.
    baseAmount = 5000,
    increasePerMinute = 100,   -- How much bounty increases per minute.
    maxBounty = 50000,
    claimMethod = "arrest",    -- Current options: "arrest". Could be "kill" if PvP is different.
    durationMinutes = 60,      -- How long a bounty stays active if player maintains wanted level (or is offline). Refreshed if wanted level drops then re-triggers.
    cooldownMinutes = 30       -- Cooldown on a player before a *new* bounty can be placed on them after one is claimed or expires.
}
