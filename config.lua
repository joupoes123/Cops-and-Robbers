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

Config.MaxPlayers = 64
Config.HeistCooldown = 600  -- seconds (10 minutes)
Config.HeistRadius = 1000.0  -- meters

-- Spawn locations based on roles
Config.SpawnPoints = {
    cop = vector3(452.6, -980.0, 30.7),        -- Police station location (example)
    robber = vector3(2126.7, 4794.1, 41.1)     -- Countryside airport location (example)
}

-- Jail Location (players are sent here when jailed)
Config.PrisonLocation = vector3(1651.0, 2570.0, 45.5)  -- Prison coordinates (example)


-- =========================
--       Bank Vaults
-- =========================

Config.BankVaults = {
    { location = vector3(150.0, -1040.0, 29.0), name = "Pacific Standard Bank", id = 1 },
    { location = vector3(-1212.0, -330.0, 37.8), name = "Fleeca Bank", id = 2 },
    { location = vector3(-2962.6, 482.9, 15.7), name = "Great Ocean Highway Bank", id = 3 },
    { location = vector3(1175.0, 2706.8, 38.1), name = "Route 68 Bank", id = 4 },
}


-- =========================
-- Police and Civilian Vehicles
-- =========================

Config.PoliceVehicles = { 'police', 'police2', 'police3', 'fbi', 'fbi2' }
Config.CivilianVehicles = { 'sultan', 'futo', 'blista', 'banshee', 'elegy2' }


-- =========================
-- Experience and Leveling System
-- =========================

Config.Experience = {
    Levels = {
        { level = 1, exp = 0 },
        { level = 2, exp = 1000 },
        { level = 3, exp = 3000 },
        { level = 4, exp = 6000 },
        { level = 5, exp = 10000 },
    },
    Rewards = {
        ['robber'] = {
            [2] = { cash = 500, item = 'lockpick' },
            [3] = { cash = 1000, item = 'drill' },
            [4] = { cash = 2000, item = 'thermal_charge' },
            [5] = { cash = 5000, item = 'gold_bar' },
        },
        ['cop'] = {
            [2] = { cash = 500, item = 'taser' },
            [3] = { cash = 1000, item = 'stun_gun' },
            [4] = { cash = 2000, item = 'carbine_rifle' },
            [5] = { cash = 5000, item = 'swat_gear' },
        },
    },
}


-- =========================
--    Wanted Level System (Legacy/Simple)
-- =========================
-- Note: This simple wanted level system is mostly superseded by the advanced Config.WantedSettings below.
-- It might still be used for basic NPC police response or simple UI elements if not fully removed.
Config.WantedLevels = {
    [1] = { stars = 1, description = "Minor Offenses" },
    [2] = { stars = 2, description = "Felony" },
    [3] = { stars = 3, description = "Serious Crime" },
    [4] = { stars = 4, description = "High Alert" },
    [5] = { stars = 5, description = "Most Wanted" },
}

-- =========================
--   Ammu-Nation Store Locations
-- =========================

Config.AmmuNationStores = {
    vector3(1692.41, 3758.22, 34.70),
    vector3(252.89, -49.25, 69.94),
    vector3(844.35, -1033.42, 28.19),
    vector3(-331.35, 6083.45, 31.45),
    vector3(-662.1, -935.3, 21.8),
    vector3(-1305.18, -393.48, 36.70),
    vector3(2567.69, 294.38, 108.73),
    vector3(-1117.58, 2698.61, 18.55),
    vector3(811.19, -2157.67, 29.62),
}


-- =========================
--     NPC Vendor Configurations
-- =========================

Config.NPCVendors = {
    {
        location = vector3(-1107.17, 4949.54, 218.65),
        heading = 140.0,
        model = "s_m_y_dealer_01",
        name = "Black Market Dealer",
        items = {"weapon_knife", "weapon_switchblade", "weapon_microsmg", "ammo_smg", "lockpick", "mask", "c4", "drill"}
    },
    {
        location = vector3(1961.48, 3740.69, 32.34),
        heading = 300.0,
        model = "g_m_y_mexgang_01",
        name = "Gang Supplier",
        items = {"weapon_pistol50", "weapon_sawnoffshotgun", "ammo_shotgun", "armor", "bandana"}
    },
    -- Additional NPC vendors can be added here
}


-- =========================
--      Item Definitions (for Stores & NPC Vendors)
-- =========================
-- Defines items available for purchase, their prices, and categories.
-- 'forCop = true' restricts item visibility/purchase to players with the 'cop' role in stores.
-- 'category' is used for NUI store filtering.
Config.Items = {
    -- Weapons
    { name = "Pistol", itemId = "weapon_pistol", basePrice = 500, category = "Weapons" },
    { name = "Combat Pistol", itemId = "weapon_combatpistol", basePrice = 750, category = "Weapons" },
    { name = "Heavy Pistol", itemId = "weapon_heavypistol", basePrice = 1000, category = "Weapons" },
    { name = "SMG", itemId = "weapon_smg", basePrice = 1500, category = "Weapons" },
    { name = "Micro SMG", itemId = "weapon_microsmg", basePrice = 1250, category = "Weapons" },
    { name = "Assault Rifle", itemId = "weapon_assaultrifle", basePrice = 2500, category = "Weapons" },
    { name = "Carbine Rifle", itemId = "weapon_carbinerifle", basePrice = 3000, category = "Weapons" },
    { name = "Sniper Rifle", itemId = "weapon_sniperrifle", basePrice = 5000, category = "Weapons" },
    { name = "Pump Shotgun", itemId = "weapon_pumpshotgun", basePrice = 1200, category = "Weapons" },
    { name = "Sawed-Off Shotgun", itemId = "weapon_sawnoffshotgun", basePrice = 1000, category = "Weapons" },
    { name = "Knife", itemId = "weapon_knife", basePrice = 100, category = "Melee Weapons" },
    { name = "Bat", itemId = "weapon_bat", basePrice = 50, category = "Melee Weapons" },
    { name = "Crowbar", itemId = "weapon_crowbar", basePrice = 75, category = "Melee Weapons" },
    { name = "Switchblade", itemId = "weapon_switchblade", basePrice = 150, category = "Melee Weapons" },
    -- Ammunition
    { name = "Pistol Ammo", itemId = "ammo_pistol", basePrice = 50, category = "Ammunition" },
    { name = "SMG Ammo", itemId = "ammo_smg", basePrice = 75, category = "Ammunition" },
    { name = "Rifle Ammo", itemId = "ammo_rifle", basePrice = 100, category = "Ammunition" },
    { name = "Shotgun Ammo", itemId = "ammo_shotgun", basePrice = 60, category = "Ammunition" },
    { name = "Sniper Ammo", itemId = "ammo_sniper", basePrice = 200, category = "Ammunition" },
    -- Armor and Utility
    { name = "Body Armor", itemId = "armor", basePrice = 500, category = "Armor" },
    { name = "Heavy Armor", itemId = "heavy_armor", basePrice = 1000, category = "Armor" },
    { name = "Medkit", itemId = "medkit", basePrice = 250, category = "Utility" },
    { name = "First Aid Kit", itemId = "firstaidkit", basePrice = 100, category = "Utility" },
    { name = "Lockpick", itemId = "lockpick", basePrice = 150, category = "Utility" },
    { name = "Advanced Lockpick", itemId = "adv_lockpick", basePrice = 300, category = "Utility" },
    { name = "Flashlight", itemId = "weapon_flashlight", basePrice = 100, category = "Utility" },
    { name = "Parachute", itemId = "gadget_parachute", basePrice = 300, category = "Utility" },
    { name = "Drill", itemId = "drill", basePrice = 500, category = "Utility" },
    { name = "C4 Explosive", itemId = "c4", basePrice = 2000, category = "Utility" },
    -- Accessories
    { name = "Mask", itemId = "mask", basePrice = 200, category = "Accessories" },
    { name = "Gloves", itemId = "gloves", basePrice = 100, category = "Accessories" },
    { name = "Hat", itemId = "hat", basePrice = 150, category = "Accessories" },
    { name = "Bandana", itemId = "bandana", basePrice = 80, category = "Accessories" },
    { name = "Sunglasses", itemId = "sunglasses", basePrice = 120, category = "Accessories" },
    -- Add more items as needed

    -- Cop Gear
    { name = "Spike Strip", itemId = "spikestrip", basePrice = 750, category = "Cop Gear", forCop = true },
    { name = "Speed Radar", itemId = "speedradar", basePrice = 500, category = "Cop Gear", forCop = true },
    { name = "K9 Whistle", itemId = "k9whistle", basePrice = 1000, category = "Cop Gear", forCop = true },
    -- Robber Gear (examples, can be expanded)
    { name = "EMP Device", itemId = "empdevice", basePrice = 2500, category = "Robber Gear" }
}

-- =========================
-- Cop Feature Settings
-- =========================
Config.SpikeStripDuration = 60000           -- milliseconds (e.g., 60 seconds) until a spike strip automatically despawns.
Config.MaxDeployedSpikeStrips = 3            -- Max spike strips a cop can have deployed simultaneously.

Config.SpeedLimit = 80.0                     -- km/h (or mph if units are handled consistently on client) for speed radar.
Config.SpeedingFine = 250                    -- Amount of fine for speeding.

Config.TackleDistance = 2.0                  -- meters, max distance for a cop to initiate a tackle/subdue.
Config.SubdueTime = 3000                     -- milliseconds, time it takes to complete a subdue action (before arrest is processed).

Config.K9FollowDistance = 5.0                -- meters, how far K9 will stay behind cop when following.
Config.K9AttackDistance = 2.0                -- meters, how close K9 needs to be to initiate an attack (visual/gameplay feel).

-- =========================
-- Robber Feature Settings
-- =========================
Config.RobbableStores = { -- List of stores that can be robbed
    { name = "LTD Gasoline Grove St", location = vector3(100.0, -1700.0, 29.0), reward = 5000, cooldown = 300, copsNeeded = 1, radius = 10.0 },
    { name = "24/7 Strawberry", location = vector3(25.0, -1340.0, 29.0), reward = 7000, cooldown = 400, copsNeeded = 2, radius = 10.0 },
    -- Add more stores here: { name, location (vector3), reward (cash), cooldown (seconds), copsNeeded (integer), radius (meters for interaction) }
}
Config.StoreRobberyDuration = 60000          -- milliseconds (e.g., 60 seconds) a robber must stay in store to complete robbery.

Config.ArmoredCar = {
    model = "stockade",                      -- Vehicle model for the armored car.
    spawnPoint = vector3(450.0, -1000.0, 28.0), -- Example spawn point.
    route = {vector3(400.0, -1100.0, 28.0), vector3(300.0,-1200.0,28.0)}, -- Example route points for NPC driver.
    reward = 20000,                          -- Cash reward for successfully destroying/looting the armored car.
    health = 2000                            -- Health of the armored car.
}
Config.ArmoredCarHeistCooldown = 1800        -- seconds (e.g., 30 minutes) cooldown before another armored car can spawn.
Config.ArmoredCarHeistCopsNeeded = 3         -- Minimum number of cops online for the armored car event to start.

Config.EMPRadius = 15.0                        -- meters, radius of effect for the EMP device.
Config.EMPDisableDuration = 5000               -- milliseconds (e.g., 5 seconds), how long vehicles are disabled by EMP.

Config.PowerGrids = { -- Locations of power grids that can be sabotaged
    { name = "Downtown Power Box", location = vector3(-500.0, -500.0, 30.0), radius = 150.0 }, -- Radius is for client-side visual effects if any, not interaction.
    -- Add more power grids here: { name, location (vector3), radius (optional for effects) }
}
Config.PowerOutageDuration = 120000          -- milliseconds (e.g., 2 minutes) how long a specific grid's power stays out.
Config.PowerGridSabotageCooldown = 600       -- seconds (e.g., 10 minutes) cooldown before the same grid can be sabotaged again.

-- =========================
-- Advanced Wanted System Settings
-- =========================
Config.WantedSettings = {
    baseIncrease = 1, -- Default points for minor infractions if not specified in crimes (currently not used by specific crimes).
    levels = { -- Defines star levels and UI labels based on accumulated wanted points.
        {stars=1, threshold=10, uiLabel="Wanted: ★☆☆☆☆"},
        {stars=2, threshold=30, uiLabel="Wanted: ★★☆☆☆"},
        {stars=3, threshold=60, uiLabel="Wanted: ★★★☆☆"},
        {stars=4, threshold=100, uiLabel="Wanted: ★★★★☆"},
        {stars=5, threshold=150, uiLabel="Wanted: ★★★★★"}
    },
    crimes = { -- Points assigned for specific crimes. These keys are used in server.lua when calling IncreaseWantedPoints.
        speeding = 1,               -- For receiving a speeding ticket.
        store_robbery_small = 5,    -- Example: For smaller, less risky store robberies.
        store_robbery_medium = 10,  -- For general store robberies.
        bank_heist_major = 20,      -- For successful major bank heists.
        armored_car_heist = 15,     -- For successful armored car heists.
        assault_cop = 15,           -- For assaulting a police officer.
        murder_cop = 25,            -- For killing a police officer.
        murder_civilian = 10,       -- For killing a civilian.
        armed_robbery = 10          -- Generic armed robbery (e.g., player hold-ups if implemented).
    },
    decayRate = 1,                 -- Amount of wanted points to decay per interval.
    decayInterval = 30000,         -- Milliseconds (e.g., 30 seconds) - how often the decay check runs.
    decayCooldown = 60000,         -- Milliseconds (e.g., 60 seconds) - time player must be "clean" (no new crimes committed) before decay starts.
    sightCooldown = 30000          -- Milliseconds (e.g., 30 seconds) - time player must be out of cop sight for decay to resume (if decay was paused due to cop sight).
}

-- =========================
-- Contraband Drop Settings
-- =========================
Config.ContrabandDropLocations = { -- Possible locations for contraband drops
    vector3(200.0, -2000.0, 20.0),      -- Example: Near the docks
    vector3(-1500.0, 800.0, 180.0),     -- Example: Remote mountain area
    vector3(2500.0, 3500.0, 30.0),      -- Example: Sandy Shores airfield
    vector3(100.0, 650.0, 200.0)        -- Example: Vinewood Hills
}
Config.ContrabandItems = {
    {name="Gold Bars", itemId="goldbars", value=10000, modelHash = `prop_gold_bar`},
    {name="Illegal Arms Cache", itemId="illegal_arms", value=7500, modelHash = `prop_box_ammo04a`},
    {name="Drugs Package", itemId="drug_package", value=5000, modelHash = `prop_cs_drug_pack_01`},
    {name="Weapon Parts", itemId="weapon_parts", value=6000, modelHash = `prop_gun_case_01`}
}
Config.ContrabandDropInterval = 1800000 -- milliseconds (30 minutes)
Config.MaxActiveContrabandDrops = 2     -- Max concurrent drops
Config.ContrabandCollectionTime = 5000  -- milliseconds (5 seconds to collect)

-- =========================
--        Safe Zones
-- =========================
Config.SafeZones = {
    { name="Mission Row Police Station Lobby", location=vector3(427.0, -981.0, 30.7), radius=15.0, message="You have entered the Safe Zone: Mission Row Lobby."},
    { name="Paleto Bay Sheriff Office", location=vector3(-448.0, 6010.0, 31.7), radius=20.0, message="Safe Zone: Paleto Sheriff Office"},
    { name="Sandy Shores Hospital", location=vector3(1837.0, 3672.9, 34.3), radius=25.0, message="You are in a Hospital Safe Zone."},
    { name="Central Los Santos Medical Center", location=vector3(355.7, -596.3, 28.8), radius=30.0, message="Safe Zone: Central LS Medical Center"}
    -- Add more safe zones as needed
}

-- =========================
-- Team Balancing Settings
-- =========================
Config.TeamBalanceSettings = {
    enabled = true,                             -- true to enable team balancing incentives, false to disable.
    threshold = 2,                              -- Minimum difference in online team member counts to trigger the incentive.
    incentiveCash = 1000,                         -- Amount of bonus cash given to a player for joining the underdog team.
    notificationMessage = "You received a bonus of $%s for joining the %s team to help with team balance!" -- Message sent to player. %s are for amount and team name.
}

-- =========================
--  Dynamic Economy Settings
-- =========================

-- Timeframe for popularity tracking (in seconds)
Config.PopularityTimeframe = 3 * 60 * 60  -- 3 hours

-- Price adjustment factors
Config.PriceIncreaseFactor = 1.2          -- Increase price by 20% for popular items
Config.PriceDecreaseFactor = 0.8          -- Decrease price by 20% for less popular items

-- Thresholds for popularity
Config.PopularityThreshold = {
    high = 10,                            -- Items purchased more than 10 times are considered popular
    low = 2,                             -- Items purchased less than 2 times are considered less popular
}

-- Sell price factor (percentage of the item's dynamic price)
Config.SellPriceFactor = 0.5              -- Players get 50% of the item's price when selling


-- =========================
--   Additional Configurations & Admin Settings
-- =========================

-- List of banned player identifiers (e.g., Steam IDs)
-- These are loaded by server.lua and merged with bans.json
Config.BannedPlayers = {
    -- Example:
    -- ["steam:110000112345678"] = { reason = "Cheating", timestamp = 1625078400, admin = "Server" },
    -- ["license:abcdefghijk"] = { reason = "Harassment", timestamp = 1625078400, admin = "AdminName" },
}

-- Admin identifiers for privileged actions.
-- This table is the primary mechanism for granting admin rights for commands and UI access.
-- There is no separate Config.AdminUIMinimumRole; access is granted if player's identifier is in this list.
Config.Admins = {
    -- Example: Populate with admin identifiers (e.g., steam:xxx, license:xxx)
    -- ["steam:110000100000001"] = true,
    -- ["license:yourlicenseidhere"] = true,
}


-- =========================
--      Heist Settings
-- =========================

-- Heist timer durations
Config.HeistTimers = {
    heistDuration = 600,                   -- Duration of the heist in seconds (10 minutes)
}


-- =========================
--    Vehicle Spawn Settings
-- =========================

-- Police vehicle spawn points (using vector3 for location)
Config.PoliceVehicleSpawns = {
    { location = vector3(452.6, -980.0, 30.7), heading = 90.0 },
    -- Add more spawn points as needed
}

-- Civilian vehicle spawn points
Config.CivilianVehicleSpawns = {
    { location = vector3(2126.7, 4794.1, 41.1), heading = 180.0 },
    -- Add more spawn points as needed
}
