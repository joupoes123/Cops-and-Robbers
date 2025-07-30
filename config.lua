-- config.lua
-- Cops & Robbers FiveM Game Mode Configuration File
-- Version: 1.2.0 | Date: June 17, 2025
-- This file contains all the configuration settings for the game mode.
-- Make sure this file is loaded before any scripts that depend on Config.

-- Initialize Config table if not already initialized
Config = Config or {}


-- =========================
--        General Settings
-- =========================

Config.DebugLogging   = false -- Set to true to enable detailed server console logging (may cause spam)
Config.DebugLevel = "none" -- Options: none, error, warn, info, debug
Config.LoggingEnabled = true
Config.JSDebugLogging = false -- Control JavaScript console.log statements
Config.MaxPlayers     = 64
Config.HeistCooldown  = 600    -- seconds (10 minutes), Cooldown between major heists for a player or globally.
Config.HeistRadius    = 1000.0 -- meters, General radius for heist related activities or blips.
Config.DefaultStartMoney = 5000 -- Starting cash for new players.

-- Spawn locations based on roles
Config.SpawnPoints = {
    cop    = vector3(452.6, -980.0, 30.7),   -- Police station location (Mission Row PD)
    robber = vector3(2126.7, 4794.1, 41.1),  -- Example: Countryside airport location (Sandy Shores Airfield)
    citizen = vector3(-260.0, -970.0, 31.2) -- Legion Square
}

-- Jail Location (players are sent here when jailed)
Config.PrisonLocation = vector3(1651.0, 2570.0, 45.5)

-- Jail Uniform Model
Config.JailUniformModel = "a_m_m_prisoner_01"


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
        location = vector4(1005.76, 88.40, 90.24, 270.24), -- Mirror Park area - accessible city location
        model    = "s_m_y_dealer_01",
        name     = "Black Market Dealer",
        items    = {
            -- Advanced Robber Equipment
            "weapon_knife",
            "weapon_switchblade",
            "weapon_microsmg",
            "weapon_smg",
            "weapon_assaultrifle",
            "weapon_sniperrifle",
            "weapon_emplauncher",
            "weapon_stickybomb",

            -- NEW HIGH-END WEAPONS
            "weapon_compactrifle",
            "weapon_bullpuprifle",
            "weapon_advancedrifle",
            "weapon_specialcarbine",
            "weapon_machinegun",
            "weapon_combatmg_mk2",
            "weapon_minigun",
            "weapon_grenade",
            "weapon_rpg",
            "weapon_grenadelauncher",
            "weapon_hominglauncher",
            "weapon_firework",
            "weapon_railgun",
            "weapon_autoshotgun",
            "weapon_bullpupshotgun",
            "weapon_dbshotgun",
            "weapon_musket",
            "weapon_heavysniper",
            "weapon_heavysniper_mk2",
            "weapon_marksmanrifle",
            "weapon_marksmanrifle_mk2",

            -- AMMUNITION
            "ammo_smg",
            "ammo_rifle",
            "ammo_sniper",
            "ammo_explosive",
            "ammo_minigun",

            -- HEIST EQUIPMENT
            "lockpick",
            "adv_lockpick",
            "hacking_device",
            "drill",
            "thermite",
            "c4",
            "mask",
            "heavy_armor"
        }
    },
    {
        location = vector4(1961.48, 3740.69, 32.34, 300.0),  -- Sandy Shores, near barber
        model    = "g_m_y_mexgang_01",
        name     = "Gang Supplier",
        items    = {
            -- Basic Robber Equipment
            "weapon_pistol",
            "weapon_bat",
            "weapon_crowbar",
            "weapon_sawnoffshotgun",

            -- NEW MID-TIER WEAPONS
            "weapon_vintagepistol",
            "weapon_snspistol",
            "weapon_heavypistol",
            "weapon_machinepistol",
            "weapon_minismg",
            "weapon_pumpshotgun",
            "weapon_bullpupshotgun",
            "weapon_assaultshotgun",
            "weapon_compactrifle",
            "weapon_gusenberg",
            "weapon_dagger",
            "weapon_hatchet",
            "weapon_machete",
            "weapon_katana",
            "weapon_wrench",
            "weapon_hammer",
            "weapon_poolcue",

            -- AMMUNITION
            "ammo_pistol",
            "ammo_shotgun",
            "ammo_smg",

            -- BASIC EQUIPMENT
            "armor",
            "lockpick",
            "bandana",
            "mask",
            "gloves"
        }
    },
    {
        location = vector4(451.39, -974.42, 30.69, 125.60),
        model    = "s_m_y_cop_01",
        name     = "Cop Store",
        items    = {
            -- Level 1 Equipment (Starting Gear)
            "weapon_stungun",
            "weapon_pistol",
            "weapon_nightstick",
            "weapon_flashlight",
            "weapon_fireextinguisher",

            -- Level 2 Equipment
            "weapon_pumpshotgun",
            "weapon_combatpistol",
            "weapon_flaregun",
            "weapon_flare",
            "weapon_doubleaction",

            -- Level 3 Equipment
            "weapon_pistol_mk2",
            "k9whistle",
            "weapon_smokegrenade",
            "weapon_combatshotgun",

            -- Level 4 Equipment
            "weapon_carbinerifle",
            "weapon_revolver_mk2",
            "weapon_stunrod",

            -- Level 10 Equipment
            "weapon_appistol",
            "weapon_heavyshotgun",
            "weapon_assaultshotgun",
            "weapon_specialcarbine_mk2",
            "weapon_combatmg",

            -- Level 15 Equipment
            "weapon_sniperrifle",
            "weapon_bzgas",

            -- Level 20 Equipment
            "weapon_snowball",

            -- Ammunition
            "ammo_pistol",
            "ammo_shotgun",
            "ammo_rifle",
            "ammo_sniper",

            -- Armor & Utility
            "armor",
            "heavy_armor",
            "firstaidkit",
            "medkit",

            -- Cop Gear
            "spikestrip_item",
            "speedradar_gun"
        }
    }
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
-- `icon`: Optional icon path or emoji for UI display. Falls back to category-based icons if not specified.
Config.Items = {
    -- Weapons
    { name = "Pistol",                itemId = "weapon_pistol",           basePrice = 500,  category = "Weapons", minLevelCop = 1, icon = "🔫" },
    { name = "Combat Pistol",         itemId = "weapon_combatpistol",     basePrice = 750,  category = "Weapons", minLevelCop = 2, icon = "🔫" },
    { name = "Pistol Mk II",          itemId = "weapon_pistol_mk2",       basePrice = 800,  category = "Weapons", minLevelCop = 3, forCop = true, icon = "🔫" },
    { name = "AP Pistol",             itemId = "weapon_appistol",         basePrice = 1200, category = "Weapons", minLevelCop = 10, forCop = true, icon = "🔫" },
    { name = "Heavy Pistol",          itemId = "weapon_heavypistol",      basePrice = 1000, category = "Weapons", minLevelCop = 5, minLevelRobber = 7, icon = "🔫" },
    { name = "Double-Action Revolver", itemId = "weapon_doubleaction",     basePrice = 900,  category = "Weapons", minLevelCop = 2, icon = "🔫" },
    { name = "Heavy Revolver Mk II",  itemId = "weapon_revolver_mk2",     basePrice = 1500, category = "Weapons", minLevelCop = 4, forCop = true, icon = "🔫" },

    { name = "SMG",                   itemId = "weapon_smg",              basePrice = 1500, category = "Weapons", minLevelRobber = 5, icon = "💥" },
    { name = "Micro SMG",             itemId = "weapon_microsmg",         basePrice = 1250, category = "Weapons", minLevelRobber = 4, icon = "💥" },
    { name = "Assault Rifle",         itemId = "weapon_assaultrifle",     basePrice = 2500, category = "Weapons", minLevelCop = 8, minLevelRobber = 10, icon = "🔫" },
    { name = "Carbine Rifle",         itemId = "weapon_carbinerifle",     basePrice = 3000, category = "Weapons", forCop = true, minLevelCop = 4, icon = "🔫" },
    { name = "Special Carbine Mk II", itemId = "weapon_specialcarbine_mk2", basePrice = 4000, category = "Weapons", forCop = true, minLevelCop = 10, icon = "🔫" },
    { name = "Combat MG",             itemId = "weapon_combatmg",         basePrice = 5500, category = "Weapons", forCop = true, minLevelCop = 10, icon = "💥" },
    { name = "Sniper Rifle",          itemId = "weapon_sniperrifle",      basePrice = 5000, category = "Weapons", minLevelCop = 15, minLevelRobber = 15, icon = "🎯" },

    -- NEW HIGH-END WEAPONS (Black Market)
    { name = "Compact Rifle",         itemId = "weapon_compactrifle",     basePrice = 2800, category = "Weapons", minLevelRobber = 8, icon = "🔫" },
    { name = "Bullpup Rifle",         itemId = "weapon_bullpuprifle",     basePrice = 3200, category = "Weapons", minLevelRobber = 10, icon = "🔫" },
    { name = "Advanced Rifle",        itemId = "weapon_advancedrifle",    basePrice = 3500, category = "Weapons", minLevelRobber = 12, icon = "🔫" },
    { name = "Special Carbine",       itemId = "weapon_specialcarbine",   basePrice = 3800, category = "Weapons", minLevelRobber = 12, icon = "🔫" },
    { name = "Machine Gun",           itemId = "weapon_machinegun",       basePrice = 6000, category = "Weapons", minLevelRobber = 18, icon = "💥" },
    { name = "Combat MG Mk II",       itemId = "weapon_combatmg_mk2",     basePrice = 7000, category = "Weapons", minLevelRobber = 20, icon = "💥" },
    { name = "Minigun",               itemId = "weapon_minigun",          basePrice = 15000, category = "Weapons", minLevelRobber = 20, icon = "💥" },
    { name = "Heavy Sniper",          itemId = "weapon_heavysniper",      basePrice = 7500, category = "Weapons", minLevelRobber = 18, icon = "🎯" },
    { name = "Heavy Sniper Mk II",    itemId = "weapon_heavysniper_mk2",  basePrice = 10000, category = "Weapons", minLevelRobber = 20, icon = "🎯" },
    { name = "Marksman Rifle",        itemId = "weapon_marksmanrifle",    basePrice = 6500, category = "Weapons", minLevelRobber = 16, icon = "🎯" },
    { name = "Marksman Rifle Mk II",  itemId = "weapon_marksmanrifle_mk2", basePrice = 8500, category = "Weapons", minLevelRobber = 18, icon = "🎯" },
    { name = "Auto Shotgun",          itemId = "weapon_autoshotgun",      basePrice = 3500, category = "Weapons", minLevelRobber = 12, icon = "💥" },
    { name = "Bullpup Shotgun",       itemId = "weapon_bullpupshotgun",   basePrice = 2200, category = "Weapons", minLevelRobber = 6, icon = "💥" },
    { name = "Double Barrel Shotgun", itemId = "weapon_dbshotgun",        basePrice = 2800, category = "Weapons", minLevelRobber = 8, icon = "💥" },
    { name = "Musket",                itemId = "weapon_musket",           basePrice = 4000, category = "Weapons", minLevelRobber = 10, icon = "🎯" },

    -- EXPLOSIVE WEAPONS
    { name = "Grenade",               itemId = "weapon_grenade",          basePrice = 1500, category = "Explosives", minLevelRobber = 10, icon = "💣" },
    { name = "RPG",                   itemId = "weapon_rpg",              basePrice = 25000, category = "Explosives", minLevelRobber = 20, icon = "🚀" },
    { name = "Grenade Launcher",      itemId = "weapon_grenadelauncher",  basePrice = 18000, category = "Explosives", minLevelRobber = 18, icon = "💥" },
    { name = "Homing Launcher",       itemId = "weapon_hominglauncher",   basePrice = 30000, category = "Explosives", minLevelRobber = 20, icon = "🎯" },
    { name = "Firework Launcher",     itemId = "weapon_firework",         basePrice = 5000, category = "Explosives", minLevelRobber = 12, icon = "🎇" },
    { name = "Railgun",               itemId = "weapon_railgun",          basePrice = 50000, category = "Explosives", minLevelRobber = 20, icon = "⚡" },

    -- NEW MID-TIER WEAPONS (Gang Supplier)
    { name = "Vintage Pistol",        itemId = "weapon_vintagepistol",    basePrice = 600, category = "Weapons", minLevelRobber = 2, icon = "🔫" },
    { name = "SNS Pistol",            itemId = "weapon_snspistol",        basePrice = 400, category = "Weapons", minLevelRobber = 1, icon = "🔫" },
    { name = "Machine Pistol",        itemId = "weapon_machinepistol",    basePrice = 1100, category = "Weapons", minLevelRobber = 4, icon = "💥" },
    { name = "Mini SMG",              itemId = "weapon_minismg",          basePrice = 1300, category = "Weapons", minLevelRobber = 5, icon = "💥" },
    { name = "Gusenberg Sweeper",     itemId = "weapon_gusenberg",        basePrice = 2000, category = "Weapons", minLevelRobber = 8, icon = "💥" },

    { name = "Pump Shotgun",          itemId = "weapon_pumpshotgun",      basePrice = 1200, category = "Weapons", minLevelCop = 2, icon = "💥" },
    { name = "Combat Shotgun",        itemId = "weapon_combatshotgun",    basePrice = 1800, category = "Weapons", minLevelCop = 3, forCop = true, icon = "💥" },
    { name = "Heavy Shotgun",         itemId = "weapon_heavyshotgun",     basePrice = 2500, category = "Weapons", minLevelCop = 10, forCop = true, icon = "💥" },
    { name = "Assault Shotgun",       itemId = "weapon_assaultshotgun",   basePrice = 3000, category = "Weapons", minLevelCop = 10, forCop = true, icon = "💥" },
    { name = "Sawed-Off Shotgun",     itemId = "weapon_sawnoffshotgun",   basePrice = 1000, category = "Weapons", minLevelRobber = 3, icon = "💥" },

    { name = "Flare Gun",             itemId = "weapon_flaregun",         basePrice = 400,  category = "Weapons", minLevelCop = 2, forCop = true, icon = "🎇" },
    { name = "Compact EMP Launcher",  itemId = "weapon_emplauncher",      basePrice = 8000, category = "Weapons", minLevelRobber = 8, icon = "⚡" },
    { name = "Snowball Launcher",     itemId = "weapon_snowball",         basePrice = 1,    category = "Weapons", minLevelCop = 20, forCop = true, icon = "❄️" },

    -- Melee Weapons
    { name = "Knife",                 itemId = "weapon_knife",            basePrice = 100,  category = "Melee Weapons", minLevelRobber = 1, icon = "🗡️" },
    { name = "Bat",                   itemId = "weapon_bat",              basePrice = 50,   category = "Melee Weapons", minLevelRobber = 1, icon = "🏏" },
    { name = "Crowbar",               itemId = "weapon_crowbar",          basePrice = 75,   category = "Melee Weapons", minLevelRobber = 2, icon = "🔧" },
    { name = "Switchblade",           itemId = "weapon_switchblade",      basePrice = 150,  category = "Melee Weapons", minLevelRobber = 3, icon = "🗡️" },
    { name = "Nightstick",            itemId = "weapon_nightstick",       basePrice = 200,  category = "Melee Weapons", minLevelCop = 1, forCop = true, icon = "🥖" },
    { name = "Flashlight",            itemId = "weapon_flashlight",       basePrice = 100,  category = "Melee Weapons", minLevelCop = 1, icon = "🔦" },
    { name = "Stun Gun",              itemId = "weapon_stungun",          basePrice = 600,  category = "Melee Weapons", minLevelCop = 1, forCop = true, icon = "⚡" },
    { name = "The Shocker",           itemId = "weapon_stunrod",          basePrice = 800,  category = "Melee Weapons", minLevelCop = 4, forCop = true, icon = "⚡" },

    -- NEW MELEE WEAPONS (Gang Supplier)
    { name = "Dagger",                itemId = "weapon_dagger",           basePrice = 120,  category = "Melee Weapons", minLevelRobber = 2, icon = "🗡️" },
    { name = "Hatchet",               itemId = "weapon_hatchet",          basePrice = 200,  category = "Melee Weapons", minLevelRobber = 3, icon = "🪓" },
    { name = "Machete",               itemId = "weapon_machete",          basePrice = 250,  category = "Melee Weapons", minLevelRobber = 4, icon = "🔪" },
    { name = "Katana",                itemId = "weapon_katana",           basePrice = 500,  category = "Melee Weapons", minLevelRobber = 6, icon = "⚔️" },
    { name = "Wrench",                itemId = "weapon_wrench",           basePrice = 80,   category = "Melee Weapons", minLevelRobber = 1, icon = "🔧" },
    { name = "Hammer",                itemId = "weapon_hammer",           basePrice = 90,   category = "Melee Weapons", minLevelRobber = 2, icon = "🔨" },
    { name = "Pool Cue",              itemId = "weapon_poolcue",          basePrice = 60,   category = "Melee Weapons", minLevelRobber = 1, icon = "🎱" },

    -- Ammunition (ammo_X corresponds to weapon type, not specific weapon model)
    { name = "Pistol Ammo",       itemId = "ammo_pistol",           basePrice = 50,   category = "Ammunition", weaponLink = "weapon_pistol", ammoAmount = 12, icon = "📦" },
    { name = "SMG Ammo",          itemId = "ammo_smg",              basePrice = 75,   category = "Ammunition", weaponLink = "weapon_smg", ammoAmount = 30, icon = "📦" },
    { name = "Rifle Ammo",        itemId = "ammo_rifle",            basePrice = 100,  category = "Ammunition", weaponLink = "weapon_carbinerifle", ammoAmount = 30, icon = "📦" },
    { name = "Shotgun Ammo",      itemId = "ammo_shotgun",          basePrice = 60,   category = "Ammunition", weaponLink = "weapon_pumpshotgun", ammoAmount = 8, icon = "📦" },
    { name = "Sniper Ammo",       itemId = "ammo_sniper",           basePrice = 200,  category = "Ammunition", weaponLink = "weapon_sniperrifle", ammoAmount = 5, icon = "📦" },

    -- NEW AMMUNITION TYPES
    { name = "Explosive Ammo",    itemId = "ammo_explosive",        basePrice = 500,  category = "Ammunition", weaponLink = "weapon_rpg", ammoAmount = 3, icon = "💥" },
    { name = "Minigun Ammo",      itemId = "ammo_minigun",          basePrice = 300,  category = "Ammunition", weaponLink = "weapon_minigun", ammoAmount = 100, icon = "📦" },

    -- Armor and Utility
    { name = "Body Armor",           itemId = "armor",                   basePrice = 500,  category = "Armor", icon = "🛡️" },
    { name = "Heavy Armor",          itemId = "heavy_armor",             basePrice = 1000, category = "Armor", minLevelCop = 6, minLevelRobber = 8, icon = "🛡️" },
    { name = "Fire Extinguisher",    itemId = "weapon_fireextinguisher", basePrice = 300,  category = "Utility", minLevelCop = 1, forCop = true, icon = "🧯" },
    { name = "Flare",                itemId = "weapon_flare",            basePrice = 25,   category = "Utility", minLevelCop = 2, forCop = true, icon = "🎇" },
    { name = "Tear Gas",             itemId = "weapon_smokegrenade",     basePrice = 500,  category = "Utility", minLevelCop = 3, forCop = true, icon = "💨" },
    { name = "BZ Gas",               itemId = "weapon_bzgas",            basePrice = 800,  category = "Utility", minLevelCop = 15, forCop = true, icon = "☁️" },
    { name = "Medkit",               itemId = "medkit",                  basePrice = 250,  category = "Utility", icon = "🩹" },
    { name = "First Aid Kit",        itemId = "firstaidkit",             basePrice = 100,  category = "Utility", icon = "❤️" },
    { name = "Lockpick",             itemId = "lockpick",                basePrice = 150,  category = "Utility", minLevelRobber = 1, icon = "🗝️" },
    { name = "Advanced Lockpick",    itemId = "adv_lockpick",            basePrice = 300,  category = "Utility", minLevelRobber = 4, icon = "🔐" },
    { name = "Hacking Device",       itemId = "hacking_device",          basePrice = 800,  category = "Utility", minLevelRobber = 6, icon = "💻" },
    { name = "Parachute",            itemId = "gadget_parachute",        basePrice = 300,  category = "Utility", icon = "🪂" },
    { name = "Drill",                itemId = "drill",                   basePrice = 500,  category = "Utility", minLevelRobber = 3, icon = "🔧" },
    { name = "Thermite",             itemId = "thermite",                basePrice = 1500, category = "Utility", minLevelRobber = 8, icon = "🧨" },
    { name = "C4 Explosive",         itemId = "c4",                      basePrice = 2000, category = "Utility", minLevelRobber = 12, icon = "💣" },
    { name = "Sticky Bomb",          itemId = "weapon_stickybomb",       basePrice = 2500, category = "Utility", minLevelRobber = 15, icon = "💣" },

    -- Accessories (Primarily for role-play or appearance, server logic might give minor effects)
    { name = "Mask",              itemId = "mask",                  basePrice = 200,  category = "Accessories", icon = "🎭" },
    { name = "Gloves",            itemId = "gloves",                basePrice = 100,  category = "Accessories", icon = "🧤" },
    { name = "Hat",               itemId = "hat",                   basePrice = 150,  category = "Accessories", icon = "🧢" },
    { name = "Bandana",           itemId = "bandana",               basePrice = 80,   category = "Accessories", icon = "🧣" },
    { name = "Sunglasses",        itemId = "sunglasses",            basePrice = 120,  category = "Accessories", icon = "🕶️" },

    -- Cop Gear (Restricted items for Cops)
    { name = "Spike Strip",       itemId = "spikestrip_item",       basePrice = 250,  category = "Cop Gear", forCop = true, icon = "⚡" },
    { name = "Speed Radar Gun",   itemId = "speedradar_gun",        basePrice = 500,  category = "Cop Gear", forCop = true, minLevelCop = 2, icon = "📡" },
    { name = "K9 Whistle",        itemId = "k9whistle",             basePrice = 1000, category = "Cop Gear", forCop = true, minLevelCop = 3, icon = "🐕" }
}

-- =========================
-- Default Weapon Ammo Configuration
-- =========================
-- Default ammo amounts when weapons are equipped
Config.DefaultWeaponAmmo = {
    ["weapon_pistol"] = 12,
    ["weapon_combatpistol"] = 12,
    ["weapon_pistol_mk2"] = 12,
    ["weapon_appistol"] = 18,
    ["weapon_heavypistol"] = 18,
    ["weapon_doubleaction"] = 6,
    ["weapon_revolver_mk2"] = 6,
    ["weapon_vintagepistol"] = 7,
    ["weapon_snspistol"] = 6,
    ["weapon_machinepistol"] = 12,
    ["weapon_smg"] = 30,
    ["weapon_microsmg"] = 16,
    ["weapon_minismg"] = 20,
    ["weapon_assaultrifle"] = 30,
    ["weapon_carbinerifle"] = 30,
    ["weapon_specialcarbine"] = 30,
    ["weapon_specialcarbine_mk2"] = 30,
    ["weapon_bullpuprifle"] = 30,
    ["weapon_compactrifle"] = 30,
    ["weapon_advancedrifle"] = 30,
    ["weapon_combatmg"] = 100,
    ["weapon_combatmg_mk2"] = 100,
    ["weapon_machinegun"] = 50,
    ["weapon_minigun"] = 500,
    ["weapon_gusenberg"] = 50,
    ["weapon_pumpshotgun"] = 8,
    ["weapon_sawnoffshotgun"] = 8,
    ["weapon_bullpupshotgun"] = 14,
    ["weapon_assaultshotgun"] = 8,
    ["weapon_musket"] = 1,
    ["weapon_heavyshotgun"] = 6,
    ["weapon_dbshotgun"] = 2,
    ["weapon_autoshotgun"] = 10,
    ["weapon_combatshotgun"] = 8,
    ["weapon_sniperrifle"] = 10,
    ["weapon_heavysniper"] = 6,
    ["weapon_heavysniper_mk2"] = 6,
    ["weapon_marksmanrifle"] = 8,
    ["weapon_marksmanrifle_mk2"] = 8,
    ["weapon_rpg"] = 1,
    ["weapon_grenadelauncher"] = 10,
    ["weapon_hominglauncher"] = 1,
    ["weapon_firework"] = 20,
    ["weapon_railgun"] = 1,
    ["weapon_emplauncher"] = 20,
    ["weapon_flaregun"] = 25,
    ["weapon_stungun"] = 1,
    ["weapon_bzgas"] = 25,
    ["weapon_smokegrenade"] = 25,
    ["weapon_grenade"] = 25,
    ["weapon_stickybomb"] = 25,
    ["weapon_flare"] = 25
}

-- =========================
-- Cop Feature Settings
-- =========================
Config.SpikeStripDuration     = 120000  -- milliseconds (120 seconds) until a spike strip automatically despawns.
Config.MaxDeployedSpikeStrips = 3      -- Max spike strips a cop can have deployed simultaneously (server-side check).

Config.SpeedLimitMph          = 50.0   -- mph for speed radar. Client uses this for display, server for fine logic. (Changed from KmH to MPH)
Config.SpeedingFine           = 250    -- Amount of fine for speeding.

Config.TackleDistance         = 2.0    -- meters, max distance for a cop to initiate a tackle/subdue.
Config.SubdueTimeMs           = 3000   -- milliseconds, time it takes to complete a subdue action (before arrest is processed). (Renamed from SubdueTime for clarity)

Config.K9FollowDistance       = 4.0    -- meters, how far K9 will stay behind cop when following. (Adjusted from 5.0 for closer follow)
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
    enableNPCResponse = false, -- MASTER SWITCH: Set to true to enable NPC police response, false to disable.
    baseIncreasePoints = 1,    -- Default points for minor infractions if not specified in crimes.
    levels = {                 -- Defines star levels and UI labels based on accumulated wanted points.
        { stars = 1, threshold = 10,  uiLabel = "Wanted: ★☆☆☆☆", minPunishment = 60,  maxPunishment = 120 },
        { stars = 2, threshold = 25,  uiLabel = "Wanted: ★★☆☆☆", minPunishment = 120, maxPunishment = 240 },
        { stars = 3, threshold = 45,  uiLabel = "Wanted: ★★★☆☆", minPunishment = 240, maxPunishment = 480 },
        { stars = 4, threshold = 70, uiLabel = "Wanted: ★★★★☆", minPunishment = 480, maxPunishment = 720 },
        { stars = 5, threshold = 100, uiLabel = "Wanted: ★★★★★", minPunishment = 720, maxPunishment = 1000 }
    },
    crimes = {                 -- Points assigned for specific crimes. These keys are used in server.lua when calling IncreaseWantedPoints.
        -- Traffic Violations
        speeding                   = 2,    -- For receiving a speeding ticket.
        reckless_driving           = 3,    -- Example: driving on sidewalk, excessive near misses.
        hit_and_run_vehicle        = 5,    -- Hitting a vehicle and fleeing.
        hit_and_run_ped            = 8,    -- Hitting a pedestrian and fleeing.
        hit_and_run_civilian       = 8,    -- Hitting a civilian pedestrian and fleeing.
        hit_and_run_cop            = 15,   -- Hitting a police officer and fleeing.
        hit_and_run                = 5,    -- General hit and run incident
        -- Property Crimes
        grand_theft_auto           = 8,    -- Stealing an occupied vehicle.
        store_robbery_small        = 6,    -- Example: For smaller, less risky store robberies.
        store_robbery_medium       = 10,   -- For general store robberies.
        armed_robbery_player       = 10,   -- Robbing another player at gunpoint (if implemented).
        -- Major Heists
        bank_heist_major           = 25,   -- For successful major bank heists.
        armored_car_heist          = 20,   -- For successful armored car heists.
        -- Violent Crimes
        assault_civilian           = 6,    -- Assaulting a civilian without killing.
        murder_civilian            = 15,   -- For killing a civilian.
        civilian_murder            = 15,   -- Alternative name for killing a civilian.
        assault_cop                = 18,   -- For assaulting a police officer.
        murder_cop                 = 30,   -- For killing a police officer.
        cop_murder                 = 30,   -- Alternative name for killing a police officer.
        -- Other
        resisting_arrest           = 8,    -- Fleeing from police after being told to stop.
        jailbreak_attempt          = 35,   -- Attempting to break someone out of jail.
        emp_used_on_police         = 10,   -- Using EMP that affects police vehicles.
        power_grid_sabotaged_crime = 10,   -- Sabotaging power grid (distinct from XP action).
        restricted_area_entry      = 12,   -- Entering restricted areas like Fort Zancudo.
        -- Additional crimes that were missing
        weapons_discharge          = 3,    -- Firing a weapon in public
        assault                    = 6,    -- General assault (non-specific)
        trespassing                = 2,    -- Entering private property
        vandalism                  = 1,    -- Damaging property
        shoplifting                = 2     -- Stealing from shops without armed robbery
    },
    decayRatePoints      = 1,    -- Amount of wanted points to decay per interval.
    decayIntervalMs      = 20000,-- Milliseconds (20 seconds) - how often the decay check runs.
    noCrimeCooldownMs    = 40000,-- Milliseconds (40 seconds) - time player must be "clean" before decay starts.
    copSightCooldownMs   = 20000,-- Milliseconds (20 seconds) - time player must be out of cop sight for decay to resume.
    copSightDistance     = 50.0  -- meters, how far a cop can "see" a wanted player to pause decay.
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
    { name = "Fort Zancudo", center = vector3(-2177.0, 3210.0, 32.0), radius = 400.0, wantedThreshold = 1, message = "~r~You are entering Fort Zancudo airspace! Turn back immediately or you will be engaged!", wantedPoints = 40, minStars = 3 },
    { name = "Humane Labs",  center = vector3(3615.0, 3740.0, 28.0),  radius = 300.0, wantedThreshold = 2, message = "~y~Warning: Highly restricted area (Humane Labs). Increased security presence.", wantedPoints = 25, minStars = 2 },
    { name = "Prison Grounds", center = Config.PrisonLocation, radius = 200.0, wantedThreshold = 0, message = "~o~You are on prison grounds. Loitering is discouraged.", wantedPoints = 15, minStars = 1, ifNotRobber = true }, -- Example: give points if not a robber (e.g. cops shouldn't get points here)
    -- Add more areas: { name, center (vector3), radius (float), wantedThreshold (stars to trigger message/response), message (string), wantedPoints (points to add if entered), minStars (minimum stars to enforce), ifNotRobber (optional bool) }
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
    ["license:a423132e944ec34bdb1bfd1c545ed18b10e975c1"] = true, -- Added for testing
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

Config.RobberVehicleSpawns = { -- Vehicles spawned for robbers near their spawn point
    { location = vector4(2146.61, 4800.74, 41.06, 66.12), model = "sultan" }, -- Fast sedan near Robber spawn
    { location = vector4(2141.76, 4822.40, 41.27, 138.15), model = "futo" },   -- Drift car
    { location = vector4(2111.02, 4768.53, 40.51, 103.25), model = "elegy2" }, -- Sports car
    { location = vector4(2059.25, 4796.49, 40.65, 202.34), model = "banshee" }, -- Additional sports car
    -- Add more spawn points as needed
}

-- Added by integrity check subtask - Default/Fallback values
Config.MaxCops = 10 -- Example max cops
Config.PlayerCountSyncInterval = 30 -- Seconds, example
Config.PerkEffects = {
    IncreasedArmorDurabilityModifier = 1.25 -- Example: 25% more armor
}

-- =========================
--     Character Editor Configuration
-- =========================
-- Comprehensive character customization system with role-specific features
Config.CharacterEditor = {
    -- Character slot configuration
    maxCharactersPerRole = 2,  -- 1 main + 1 alternate per role
    enableAlternateCharacters = true,
    
    -- Customization categories and their ranges
    customization = {
        -- Basic appearance
        face = { min = 0, max = 45 },
        skin = { min = 0, max = 45 },
        
        -- Facial features (0.0 to 1.0 range)
        noseWidth = { min = -1.0, max = 1.0 },
        noseHeight = { min = -1.0, max = 1.0 },
        noseLength = { min = -1.0, max = 1.0 },
        noseBridge = { min = -1.0, max = 1.0 },
        noseTip = { min = -1.0, max = 1.0 },
        noseShift = { min = -1.0, max = 1.0 },
        
        browHeight = { min = -1.0, max = 1.0 },
        browWidth = { min = -1.0, max = 1.0 },
        
        cheekboneHeight = { min = -1.0, max = 1.0 },
        cheekboneWidth = { min = -1.0, max = 1.0 },
        cheeksWidth = { min = -1.0, max = 1.0 },
        
        eyesOpening = { min = -1.0, max = 1.0 },
        
        lipsThickness = { min = -1.0, max = 1.0 },
        
        jawWidth = { min = -1.0, max = 1.0 },
        jawHeight = { min = -1.0, max = 1.0 },
        chinLength = { min = -1.0, max = 1.0 },
        chinPosition = { min = -1.0, max = 1.0 },
        chinWidth = { min = -1.0, max = 1.0 },
        chinShape = { min = -1.0, max = 1.0 },
        
        neckWidth = { min = -1.0, max = 1.0 },
        
        -- Hair and colors
        hair = { min = 0, max = 76 },
        hairColor = { min = 0, max = 63 },
        hairHighlight = { min = 0, max = 63 },
        
        -- Facial hair
        beard = { min = -1, max = 28 },
        beardColor = { min = 0, max = 63 },
        beardOpacity = { min = 0.0, max = 1.0 },
        
        -- Eyebrows
        eyebrows = { min = -1, max = 33 },
        eyebrowsColor = { min = 0, max = 63 },
        eyebrowsOpacity = { min = 0.0, max = 1.0 },
        
        -- Eyes
        eyeColor = { min = 0, max = 31 },
        
        -- Makeup
        blush = { min = -1, max = 6 },
        blushColor = { min = 0, max = 63 },
        blushOpacity = { min = 0.0, max = 1.0 },
        
        lipstick = { min = -1, max = 9 },
        lipstickColor = { min = 0, max = 63 },
        lipstickOpacity = { min = 0.0, max = 1.0 },
        
        makeup = { min = -1, max = 74 },
        makeupColor = { min = 0, max = 63 },
        makeupOpacity = { min = 0.0, max = 1.0 },
        
        -- Body features
        bodyBlemishes = { min = -1, max = 23 },
        bodyBlemishesOpacity = { min = 0.0, max = 1.0 },
        
        addBodyBlemishes = { min = -1, max = 11 },
        addBodyBlemishesOpacity = { min = 0.0, max = 1.0 },
        
        -- Complexion
        complexion = { min = -1, max = 11 },
        complexionOpacity = { min = 0.0, max = 1.0 },
        
        sundamage = { min = -1, max = 10 },
        sundamageOpacity = { min = 0.0, max = 1.0 },
        
        freckles = { min = -1, max = 17 },
        frecklesOpacity = { min = 0.0, max = 1.0 },
        
        -- Aging
        ageing = { min = -1, max = 14 },
        ageingOpacity = { min = 0.0, max = 1.0 },
        
        -- Moles
        moles = { min = -1, max = 17 },
        molesOpacity = { min = 0.0, max = 1.0 },
        
        -- Chest hair
        chesthair = { min = -1, max = 16 },
        chesthairColor = { min = 0, max = 63 },
        chesthairOpacity = { min = 0.0, max = 1.0 }
    },
    
    -- Role-specific uniform presets
    uniformPresets = {
        cop = {
            {
                name = "Patrol Officer",
                description = "Standard patrol uniform",
                components = {
                    [1] = { drawable = 0, texture = 0 },   -- Mask
                    [3] = { drawable = 0, texture = 0 },   -- Arms/Torso
                    [4] = { drawable = 35, texture = 0 },  -- Legs
                    [5] = { drawable = 0, texture = 0 },   -- Bag
                    [6] = { drawable = 25, texture = 0 },  -- Shoes
                    [7] = { drawable = 0, texture = 0 },   -- Accessories
                    [8] = { drawable = 58, texture = 0 },  -- Undershirt
                    [9] = { drawable = 0, texture = 0 },   -- Body Armor
                    [10] = { drawable = 0, texture = 0 },  -- Decals
                    [11] = { drawable = 55, texture = 0 }  -- Tops
                },
                props = {
                    [0] = { drawable = 46, texture = 0 },  -- Hat
                    [1] = { drawable = 7, texture = 0 },   -- Glasses
                    [2] = { drawable = -1, texture = 0 },  -- Ear
                    [6] = { drawable = -1, texture = 0 },  -- Watch
                    [7] = { drawable = -1, texture = 0 }   -- Bracelet
                }
            },
            {
                name = "SWAT Officer",
                description = "Tactical response uniform",
                components = {
                    [1] = { drawable = 0, texture = 0 },   -- Mask (no mask for better visibility)
                    [3] = { drawable = 0, texture = 0 },   -- Arms/Torso
                    [4] = { drawable = 31, texture = 0 },  -- Legs (tactical pants)
                    [5] = { drawable = 0, texture = 0 },   -- Bag
                    [6] = { drawable = 25, texture = 0 },  -- Shoes (tactical boots)
                    [7] = { drawable = 0, texture = 0 },   -- Accessories
                    [8] = { drawable = 15, texture = 0 },  -- Undershirt (black)
                    [9] = { drawable = 15, texture = 0 },  -- Body Armor (tactical vest)
                    [10] = { drawable = 0, texture = 0 },  -- Decals
                    [11] = { drawable = 53, texture = 0 }  -- Tops (tactical shirt)
                },
                props = {
                    [0] = { drawable = 125, texture = 0 }, -- Tactical helmet
                    [1] = { drawable = 15, texture = 0 },  -- Tactical glasses
                    [2] = { drawable = -1, texture = 0 },  -- Ear
                    [6] = { drawable = -1, texture = 0 },  -- Watch
                    [7] = { drawable = -1, texture = 0 }   -- Bracelet
                }
            },
            {
                name = "Detective",
                description = "Plain clothes detective",
                components = {
                    [1] = { drawable = 0, texture = 0 },   -- Mask
                    [3] = { drawable = 0, texture = 0 },   -- Arms/Torso
                    [4] = { drawable = 24, texture = 0 },  -- Legs
                    [5] = { drawable = 0, texture = 0 },   -- Bag
                    [6] = { drawable = 10, texture = 0 },  -- Shoes
                    [7] = { drawable = 0, texture = 0 },   -- Accessories
                    [8] = { drawable = 31, texture = 0 },  -- Undershirt
                    [9] = { drawable = 0, texture = 0 },   -- Body Armor
                    [10] = { drawable = 0, texture = 0 },  -- Decals
                    [11] = { drawable = 28, texture = 0 }  -- Tops
                },
                props = {
                    [0] = { drawable = -1, texture = 0 },  -- Hat
                    [1] = { drawable = 4, texture = 0 },   -- Glasses
                    [2] = { drawable = -1, texture = 0 },  -- Ear
                    [6] = { drawable = -1, texture = 0 },  -- Watch
                    [7] = { drawable = -1, texture = 0 }   -- Bracelet
                }
            }
        },
        robber = {
            {
                name = "Street Criminal",
                description = "Casual street wear",
                components = {
                    [1] = { drawable = 0, texture = 0 },   -- Mask
                    [3] = { drawable = 0, texture = 0 },   -- Arms/Torso
                    [4] = { drawable = 1, texture = 0 },   -- Legs
                    [5] = { drawable = 0, texture = 0 },   -- Bag
                    [6] = { drawable = 1, texture = 0 },   -- Shoes
                    [7] = { drawable = 0, texture = 0 },   -- Accessories
                    [8] = { drawable = 15, texture = 0 },  -- Undershirt
                    [9] = { drawable = 0, texture = 0 },   -- Body Armor
                    [10] = { drawable = 0, texture = 0 },  -- Decals
                    [11] = { drawable = 4, texture = 0 }   -- Tops
                },
                props = {
                    [0] = { drawable = 18, texture = 0 },  -- Hat
                    [1] = { drawable = -1, texture = 0 },  -- Glasses
                    [2] = { drawable = -1, texture = 0 },  -- Ear
                    [6] = { drawable = -1, texture = 0 },  -- Watch
                    [7] = { drawable = -1, texture = 0 }   -- Bracelet
                }
            },
            {
                name = "Heist Outfit",
                description = "Professional criminal attire",
                components = {
                    [1] = { drawable = 0, texture = 0 },   -- Mask
                    [3] = { drawable = 0, texture = 0 },   -- Arms/Torso
                    [4] = { drawable = 24, texture = 0 },  -- Legs
                    [5] = { drawable = 0, texture = 0 },   -- Bag
                    [6] = { drawable = 10, texture = 0 },  -- Shoes
                    [7] = { drawable = 0, texture = 0 },   -- Accessories
                    [8] = { drawable = 31, texture = 0 },  -- Undershirt
                    [9] = { drawable = 0, texture = 0 },   -- Body Armor
                    [10] = { drawable = 0, texture = 0 },  -- Decals
                    [11] = { drawable = 32, texture = 0 }  -- Tops
                },
                props = {
                    [0] = { drawable = -1, texture = 0 },  -- Hat
                    [1] = { drawable = 5, texture = 0 },   -- Glasses
                    [2] = { drawable = -1, texture = 0 },  -- Ear
                    [6] = { drawable = -1, texture = 0 },  -- Watch
                    [7] = { drawable = -1, texture = 0 }   -- Bracelet
                }
            },
            {
                name = "Casual Civilian",
                description = "Blend in with civilians",
                components = {
                    [1] = { drawable = 0, texture = 0 },   -- Mask
                    [3] = { drawable = 0, texture = 0 },   -- Arms/Torso
                    [4] = { drawable = 0, texture = 0 },   -- Legs
                    [5] = { drawable = 0, texture = 0 },   -- Bag
                    [6] = { drawable = 4, texture = 0 },   -- Shoes
                    [7] = { drawable = 0, texture = 0 },   -- Accessories
                    [8] = { drawable = 15, texture = 0 },  -- Undershirt
                    [9] = { drawable = 0, texture = 0 },   -- Body Armor
                    [10] = { drawable = 0, texture = 0 },  -- Decals
                    [11] = { drawable = 0, texture = 0 }   -- Tops
                },
                props = {
                    [0] = { drawable = -1, texture = 0 },  -- Hat
                    [1] = { drawable = -1, texture = 0 },  -- Glasses
                    [2] = { drawable = -1, texture = 0 },  -- Ear
                    [6] = { drawable = -1, texture = 0 },  -- Watch
                    [7] = { drawable = -1, texture = 0 }   -- Bracelet
                }
            }
        }
    },
    
    -- Character editor location (interior)
    editorLocation = vector3(402.8664, -996.4108, -100.0001),
    
    -- Default character data
    defaultCharacter = {
        model = "mp_m_freemode_01", -- Will be set based on gender
        face = 0,
        skin = 0,
        hair = 0,
        hairColor = 0,
        hairHighlight = 0,
        beard = -1,
        beardColor = 0,
        beardOpacity = 1.0,
        eyebrows = -1,
        eyebrowsColor = 0,
        eyebrowsOpacity = 1.0,
        eyeColor = 0,
        blush = -1,
        blushColor = 0,
        blushOpacity = 0.0,
        lipstick = -1,
        lipstickColor = 0,
        lipstickOpacity = 0.0,
        makeup = -1,
        makeupColor = 0,
        makeupOpacity = 0.0,
        ageing = -1,
        ageingOpacity = 0.0,
        complexion = -1,
        complexionOpacity = 0.0,
        sundamage = -1,
        sundamageOpacity = 0.0,
        freckles = -1,
        frecklesOpacity = 0.0,
        bodyBlemishes = -1,
        bodyBlemishesOpacity = 0.0,
        addBodyBlemishes = -1,
        addBodyBlemishesOpacity = 0.0,
        moles = -1,
        molesOpacity = 0.0,
        chesthair = -1,
        chesthairColor = 0,
        chesthairOpacity = 0.0,
        faceFeatures = {
            noseWidth = 0.0,
            noseHeight = 0.0,
            noseLength = 0.0,
            noseBridge = 0.0,
            noseTip = 0.0,
            noseShift = 0.0,
            browHeight = 0.0,
            browWidth = 0.0,
            cheekboneHeight = 0.0,
            cheekboneWidth = 0.0,
            cheeksWidth = 0.0,
            eyesOpening = 0.0,
            lipsThickness = 0.0,
            jawWidth = 0.0,
            jawHeight = 0.0,
            chinLength = 0.0,
            chinPosition = 0.0,
            chinWidth = 0.0,
            chinShape = 0.0,
            neckWidth = 0.0
        },
        components = {
            [1] = { drawable = 0, texture = 0 },   -- Mask
            [3] = { drawable = 15, texture = 0 },  -- Arms/Torso
            [4] = { drawable = 0, texture = 0 },   -- Legs
            [5] = { drawable = 0, texture = 0 },   -- Bag
            [6] = { drawable = 1, texture = 0 },   -- Shoes
            [7] = { drawable = 0, texture = 0 },   -- Accessories
            [8] = { drawable = 15, texture = 0 },  -- Undershirt
            [9] = { drawable = 0, texture = 0 },   -- Body Armor
            [10] = { drawable = 0, texture = 0 },  -- Decals
            [11] = { drawable = 0, texture = 0 }   -- Tops
        },
        props = {
            [0] = { drawable = -1, texture = 0 },  -- Hat
            [1] = { drawable = -1, texture = 0 },  -- Glasses
            [2] = { drawable = -1, texture = 0 },  -- Ear
            [6] = { drawable = -1, texture = 0 },  -- Watch
            [7] = { drawable = -1, texture = 0 }   -- Bracelet
        },
        tattoos = {}
    }
}

-- =========================
--     Keybind Configuration
-- =========================
-- All keybinds use FiveM control IDs. Reference: https://docs.fivem.net/docs/game-references/controls/
-- These can be customized by server administrators.
-- Note: Some keys may conflict with other resources - test thoroughly.

-- Keybind Layout Summary:
-- M: Open Inventory | E: Interact | LEFT ALT: Police Radar | H: Fine Driver
-- G: Deploy Spikes | K: Toggle K9 | F1: EMP Device | F2: Admin Panel | F3: Character Editor

-- See FiveM native docs for control list: https://docs.fivem.net/docs/game-references/controls/
Config.Keybinds = {
    toggleSpeedRadar    = 19,  -- INPUT_CHARACTER_WHEEL (LEFT ALT) - Better for police radar
    fineSpeeder         = 74,  -- INPUT_VEH_HEADLIGHT (H) - Correct
    fineSpeederKeyName  = "H", -- Display name for the fine key
    deploySpikeStrip    = 47,  -- INPUT_DETONATE (G) - Better for spike strips
    tackleSubdue        = 38,  -- INPUT_PICKUP (E) - Standard interaction key  
    toggleK9            = 311, -- INPUT_REPLAY_SHOWHOTKEY (K) - Correct for K key
    commandK9Attack     = 51,  -- INPUT_CONTEXT (E) - Alternative context action
    activateEMP         = 288, -- INPUT_REPLAY_START_STOP_RECORDING (F1) - Better key for EMP
    toggleAdminPanel    = 289, -- INPUT_REPLAY_START_STOP_RECORDING_SECONDARY (F2) - Admin panel
    openCharacterEditor = 170, -- INPUT_REPLAY_RECORD (F3) - Character editor
    openInventory       = 244  -- INPUT_INTERACTION_MENU (M) - Standard for inventory/menus
    -- Add other keybinds as needed
}


-- =========================
-- Enhanced Player Leveling System
-- =========================
Config.LevelingSystemEnabled = true -- Master switch for this leveling system.

-- XP required to reach the NEXT level. Key is the CURRENT level. Value is XP needed to get from current_level to current_level+1.
Config.XPTable = {
    [1] = 100,   -- XP to reach Level 2 (from Lvl 1)
    [2] = 200,   -- XP to reach Level 3 (from Lvl 2)
    [3] = 350,   -- XP to reach Level 4
    [4] = 500,   -- XP to reach Level 5
    [5] = 700,   -- XP to reach Level 6
    [6] = 900,   -- XP to reach Level 7
    [7] = 1150,  -- XP to reach Level 8
    [8] = 1400,  -- XP to reach Level 9
    [9] = 1700,  -- XP to reach Level 10
    [10] = 2000, -- XP to reach Level 11
    [11] = 2350, -- XP to reach Level 12
    [12] = 2700, -- XP to reach Level 13
    [13] = 3100, -- XP to reach Level 14
    [14] = 3500, -- XP to reach Level 15
    [15] = 4000, -- XP to reach Level 16
    [16] = 4500, -- XP to reach Level 17
    [17] = 5100, -- XP to reach Level 18
    [18] = 5700, -- XP to reach Level 19
    [19] = 6400, -- XP to reach Level 20
    [20] = 7200, -- XP to reach Level 21
    [21] = 8000, -- XP to reach Level 22
    [22] = 8900, -- XP to reach Level 23
    [23] = 9800, -- XP to reach Level 24
    [24] = 10800, -- XP to reach Level 25
    [25] = 12000, -- XP to reach Level 26
    [26] = 13200, -- XP to reach Level 27
    [27] = 14500, -- XP to reach Level 28
    [28] = 15900, -- XP to reach Level 29
    [29] = 17400, -- XP to reach Level 30
    [30] = 19000, -- XP to reach Level 31
    [31] = 20700, -- XP to reach Level 32
    [32] = 22500, -- XP to reach Level 33
    [33] = 24400, -- XP to reach Level 34
    [34] = 26400, -- XP to reach Level 35
    [35] = 28500, -- XP to reach Level 36
    [36] = 30700, -- XP to reach Level 37
    [37] = 33000, -- XP to reach Level 38
    [38] = 35400, -- XP to reach Level 39
    [39] = 37900, -- XP to reach Level 40
    [40] = 40500, -- XP to reach Level 41
    [41] = 43200, -- XP to reach Level 42
    [42] = 46000, -- XP to reach Level 43
    [43] = 48900, -- XP to reach Level 44
    [44] = 51900, -- XP to reach Level 45
    [45] = 55000, -- XP to reach Level 46
    [46] = 58200, -- XP to reach Level 47
    [47] = 61500, -- XP to reach Level 48
    [48] = 64900, -- XP to reach Level 49
    [49] = 68400  -- XP to reach Level 50
    -- Level 50 is max level for initial progression
}
Config.MaxLevel = 50 -- Maximum attainable level in this system.

-- Prestige System Configuration
Config.PrestigeSystem = {
    enabled = true,
    maxPrestige = 10,
    levelRequiredForPrestige = 50, -- Must reach max level to prestige
    prestigeRewards = {
        [1] = { cash = 100000, title = "Veteran", xpMultiplier = 1.1 },
        [2] = { cash = 200000, title = "Elite", xpMultiplier = 1.2 },
        [3] = { cash = 350000, title = "Master", xpMultiplier = 1.3 },
        [4] = { cash = 500000, title = "Legend", xpMultiplier = 1.4 },
        [5] = { cash = 750000, title = "Mythic", xpMultiplier = 1.5 },
        [6] = { cash = 1000000, title = "Immortal", xpMultiplier = 1.6 },
        [7] = { cash = 1500000, title = "Transcendent", xpMultiplier = 1.7 },
        [8] = { cash = 2000000, title = "Godlike", xpMultiplier = 1.8 },
        [9] = { cash = 3000000, title = "Omnipotent", xpMultiplier = 1.9 },
        [10] = { cash = 5000000, title = "Supreme", xpMultiplier = 2.0 }
    }
}

-- XP awarded for specific actions. Keys should be unique and descriptive, used in server-side AddXP calls.
Config.XPActionsRobber = {
    successful_store_robbery_small   = 15, -- XP for a small store robbery.
    successful_store_robbery_medium  = 25, -- XP for a standard store robbery.
    successful_store_robbery_large   = 35, -- XP for a large store robbery.
    successful_armored_car_heist     = 60, -- XP for completing an armored car heist.
    successful_bank_heist_minor      = 50, -- XP for minor bank heist.
    successful_bank_heist_major      = 100, -- XP for major bank heists.
    contraband_collected             = 20, -- XP for collecting a contraband drop.
    emp_used_effectively             = 15, -- XP if EMP disables >0 cop cars.
    power_grid_sabotage_success      = 75, -- XP for successfully sabotaging a power grid.
    escape_from_cops_high_wanted     = 30, -- XP for escaping with 4+ wanted stars.
    escape_from_cops_medium_wanted   = 20, -- XP for escaping with 2-3 wanted stars.
    lockpick_success                 = 5,  -- XP for successful lockpicking.
    hacking_success                  = 10, -- XP for successful hacking.
    thermite_success                 = 25  -- XP for successful thermite use.
}
Config.XPActionsCop = {
    successful_arrest_low_wanted     = 20, -- Arresting a 1-star suspect (increased from 15)
    successful_arrest_medium_wanted  = 35, -- Arresting a 2 or 3-star suspect (increased from 25)
    successful_arrest_high_wanted    = 50, -- Arresting a 4 or 5-star suspect (increased from 40)
    subdue_arrest_bonus              = 15, -- Bonus XP for arrest after manual subdue (increased from 10)
    k9_assist_arrest                 = 15, -- K9 played a significant role in arrest (increased from 10)
    speeding_fine_issued             = 8,  -- Successfully issuing a speeding ticket (increased from 5)
    spike_strip_hit_assists_arrest   = 20, -- Spike strip deployed leads to arrest (increased from 15)
    contraband_seizure               = 25, -- XP for seizing contraband.
    vehicle_impound                  = 10, -- XP for impounding criminal vehicles.
    evidence_collection              = 15  -- XP for collecting evidence at crime scenes.
}

-- =========================
-- Enhanced Progression System
-- =========================

-- Comprehensive Level Rewards and Unlocks
-- Structure: Config.LevelUnlocks[role][levelNumber] = { table of unlock definitions }
-- Unlock Definition Types:
--   - { type="item_access", itemId="item_id_from_Config.Items", message="Notification message for player." }
--   - { type="passive_perk", perkId="unique_perk_identifier", value=numeric_value_or_true, message="Notification message." }
--   - { type="vehicle_access", vehicleHash="vehicle_model_hash", name="Display Name", message="Notification message." }
--   - { type="cash_reward", amount=number, message="Cash reward message." }
--   - { type="ability", abilityId="unique_ability_id", name="Ability Name", message="Ability unlock message." }
Config.LevelUnlocks = {
    robber = {
        [2] = {
            { type = "item_access", itemId = "crowbar", message = "🔧 Crowbar unlocked for breaking and entering!" },
            { type = "item_access", itemId = "weapon_vintagepistol", message = "🔫 Vintage Pistol unlocked!" },
            { type = "cash_reward", amount = 2500, message = "💰 Level 2 Bonus: $2,500!" }
        },
        [3] = {
            { type = "item_access", itemId = "drill", message = "🔧 Drill unlocked for advanced heists!" },
            { type = "item_access", itemId = "weapon_sawnoffshotgun", message = "💥 Sawed-Off Shotgun unlocked!" },
            { type = "passive_perk", perkId = "faster_lockpicking", value = 0.9, message = "⚡ Perk: Lockpicking 10% faster!" }
        },
        [4] = {
            { type = "item_access", itemId = "adv_lockpick", message = "🔐 Advanced Lockpick unlocked!" },
            { type = "item_access", itemId = "weapon_microsmg", message = "💥 Micro SMG unlocked!" },
            { type = "cash_reward", amount = 5000, message = "💰 Level 4 Bonus: $5,000!" }
        },
        [5] = {
            { type = "item_access", itemId = "weapon_smg", message = "💥 SMG unlocked in black market!" },
            { type = "passive_perk", perkId = "stealth_bonus", value = 1.2, message = "👤 Perk: 20% harder to detect during heists!" },
            { type = "ability", abilityId = "smoke_bomb", name = "Smoke Bomb", message = "💨 Ability: Smoke Bomb for quick escapes!" }
        },
        [6] = {
            { type = "item_access", itemId = "hacking_device", message = "💻 Hacking Device unlocked!" },
            { type = "item_access", itemId = "weapon_katana", message = "⚔️ Katana unlocked!" },
            { type = "cash_reward", amount = 7500, message = "💰 Level 6 Bonus: $7,500!" }
        },
        [8] = {
            { type = "item_access", itemId = "weapon_emplauncher", message = "⚡ EMP Launcher unlocked!" },
            { type = "item_access", itemId = "thermite", message = "🧨 Thermite unlocked!" },
            { type = "passive_perk", perkId = "heist_planning", value = 1.15, message = "📋 Perk: 15% faster heist preparation!" }
        },
        [10] = {
            { type = "item_access", itemId = "weapon_assaultrifle", message = "🔫 Assault Rifle unlocked!" },
            { type = "item_access", itemId = "weapon_compactrifle", message = "🔫 Compact Rifle unlocked!" },
            { type = "cash_reward", amount = 15000, message = "💰 Level 10 Bonus: $15,000!" },
            { type = "ability", abilityId = "adrenaline_rush", name = "Adrenaline Rush", message = "⚡ Ability: Temporary speed boost during escapes!" }
        },
        [12] = {
            { type = "item_access", itemId = "c4", message = "💣 C4 Explosive unlocked!" },
            { type = "item_access", itemId = "weapon_bullpuprifle", message = "🔫 Bullpup Rifle unlocked!" },
            { type = "passive_perk", perkId = "master_thief", value = 1.25, message = "💎 Perk: 25% bonus heist payouts!" }
        },
        [15] = {
            { type = "item_access", itemId = "weapon_sniperrifle", message = "🎯 Sniper Rifle unlocked!" },
            { type = "item_access", itemId = "weapon_stickybomb", message = "💣 Sticky Bomb unlocked!" },
            { type = "cash_reward", amount = 25000, message = "💰 Level 15 Bonus: $25,000!" },
            { type = "ability", abilityId = "ghost_mode", name = "Ghost Mode", message = "👻 Ability: Temporary invisibility to security systems!" }
        },
        [18] = {
            { type = "item_access", itemId = "weapon_heavysniper", message = "🎯 Heavy Sniper unlocked!" },
            { type = "item_access", itemId = "weapon_machinegun", message = "💥 Machine Gun unlocked!" },
            { type = "passive_perk", perkId = "criminal_network", value = 1.3, message = "🌐 Perk: 30% discount on black market items!" }
        },
        [20] = {
            { type = "item_access", itemId = "weapon_minigun", message = "💥 Minigun unlocked!" },
            { type = "item_access", itemId = "weapon_rpg", message = "🚀 RPG unlocked!" },
            { type = "cash_reward", amount = 50000, message = "💰 Level 20 Bonus: $50,000!" },
            { type = "ability", abilityId = "master_escape", name = "Master Escape", message = "🏃 Ability: Instantly lose 2 wanted stars!" }
        },
        [25] = {
            { type = "item_access", itemId = "weapon_hominglauncher", message = "🎯 Homing Launcher unlocked!" },
            { type = "passive_perk", perkId = "crime_lord", value = 1.5, message = "👑 Perk: Crime Lord - 50% bonus XP and payouts!" },
            { type = "cash_reward", amount = 100000, message = "💰 Level 25 Bonus: $100,000!" }
        },
        [30] = {
            { type = "item_access", itemId = "weapon_railgun", message = "⚡ Railgun unlocked!" },
            { type = "ability", abilityId = "criminal_empire", name = "Criminal Empire", message = "🏰 Ability: Access to exclusive criminal operations!" },
            { type = "cash_reward", amount = 200000, message = "💰 Level 30 Bonus: $200,000!" }
        },
        [35] = {
            { type = "passive_perk", perkId = "untouchable", value = 2.0, message = "🛡️ Perk: Untouchable - Double health and armor!" },
            { type = "cash_reward", amount = 350000, message = "💰 Level 35 Bonus: $350,000!" }
        },
        [40] = {
            { type = "ability", abilityId = "heist_mastermind", name = "Heist Mastermind", message = "🧠 Ability: Plan and execute legendary heists!" },
            { type = "cash_reward", amount = 500000, message = "💰 Level 40 Bonus: $500,000!" }
        },
        [45] = {
            { type = "passive_perk", perkId = "legendary_criminal", value = 3.0, message = "⭐ Perk: Legendary Criminal - Triple XP and payouts!" },
            { type = "cash_reward", amount = 750000, message = "💰 Level 45 Bonus: $750,000!" }
        },
        [50] = {
            { type = "ability", abilityId = "criminal_overlord", name = "Criminal Overlord", message = "👑 MAX LEVEL: Criminal Overlord - Ultimate criminal authority!" },
            { type = "cash_reward", amount = 1000000, message = "💰 MAX LEVEL BONUS: $1,000,000!" },
            { type = "passive_perk", perkId = "prestige_ready", value = true, message = "🌟 Ready for Prestige!" }
        }
    },
    cop = {
        [2] = {
            { type = "item_access", itemId = "weapon_pumpshotgun", message = "💥 Pump Shotgun unlocked!" },
            { type = "item_access", itemId = "weapon_combatpistol", message = "🔫 Combat Pistol unlocked!" },
            { type = "cash_reward", amount = 2500, message = "💰 Level 2 Bonus: $2,500!" }
        },
        [3] = {
            { type = "item_access", itemId = "k9whistle", message = "🐕 K9 Whistle unlocked!" },
            { type = "item_access", itemId = "weapon_pistol_mk2", message = "🔫 Pistol Mk II unlocked!" },
            { type = "passive_perk", perkId = "improved_arrest", value = 1.1, message = "⚡ Perk: 10% faster arrests!" }
        },
        [4] = {
            { type = "item_access", itemId = "weapon_carbinerifle", message = "🔫 Carbine Rifle unlocked!" },
            { type = "item_access", itemId = "weapon_stunrod", message = "⚡ Stun Rod unlocked!" },
            { type = "cash_reward", amount = 5000, message = "💰 Level 4 Bonus: $5,000!" }
        },
        [5] = {
            { type = "vehicle_access", vehicleHash = "policeb", name = "Police Bike", message = "🏍️ Police Bike unlocked!" },
            { type = "passive_perk", perkId = "improved_taser", value = 1.5, message = "⚡ Perk: Taser range increased 50%!" },
            { type = "ability", abilityId = "backup_call", name = "Backup Call", message = "📻 Ability: Call for immediate backup!" }
        },
        [6] = {
            { type = "item_access", itemId = "heavy_armor", message = "🛡️ Heavy Armor unlocked!" },
            { type = "item_access", itemId = "weapon_combatshotgun", message = "💥 Combat Shotgun unlocked!" },
            { type = "cash_reward", amount = 7500, message = "💰 Level 6 Bonus: $7,500!" }
        },
        [8] = {
            { type = "vehicle_access", vehicleHash = "policet", name = "Police Transport", message = "🚐 Police Transport unlocked!" },
            { type = "passive_perk", perkId = "extra_equipment", value = 2, message = "🎒 Perk: Carry +2 spike strips!" },
            { type = "ability", abilityId = "tactical_scan", name = "Tactical Scan", message = "🔍 Ability: Scan area for criminals!" }
        },
        [10] = {
            { type = "item_access", itemId = "weapon_appistol", message = "🔫 AP Pistol unlocked!" },
            { type = "item_access", itemId = "weapon_combatmg", message = "💥 Combat MG unlocked!" },
            { type = "cash_reward", amount = 15000, message = "💰 Level 10 Bonus: $15,000!" },
            { type = "passive_perk", perkId = "arrest_bonus", value = 1.25, message = "⭐ Perk: 25% bonus XP from arrests!" }
        },
        [12] = {
            { type = "vehicle_access", vehicleHash = "riot", name = "Riot Van", message = "🚐 Riot Van unlocked!" },
            { type = "item_access", itemId = "weapon_heavyshotgun", message = "💥 Heavy Shotgun unlocked!" },
            { type = "ability", abilityId = "crowd_control", name = "Crowd Control", message = "👮 Ability: Advanced crowd control tactics!" }
        },
        [15] = {
            { type = "item_access", itemId = "weapon_sniperrifle", message = "🎯 Sniper Rifle unlocked!" },
            { type = "item_access", itemId = "weapon_bzgas", message = "☁️ BZ Gas unlocked!" },
            { type = "cash_reward", amount = 25000, message = "💰 Level 15 Bonus: $25,000!" },
            { type = "passive_perk", perkId = "tactical_specialist", value = 0.75, message = "💰 Perk: 25% discount on equipment!" }
        },
        [18] = {
            { type = "vehicle_access", vehicleHash = "polmav", name = "Police Maverick", message = "🚁 Police Helicopter unlocked!" },
            { type = "passive_perk", perkId = "air_support", value = true, message = "🚁 Perk: Air support coordination!" },
            { type = "ability", abilityId = "swat_tactics", name = "SWAT Tactics", message = "🎯 Ability: Advanced tactical operations!" }
        },
        [20] = {
            { type = "item_access", itemId = "weapon_specialcarbine_mk2", message = "🔫 Special Carbine Mk II unlocked!" },
            { type = "cash_reward", amount = 50000, message = "💰 Level 20 Bonus: $50,000!" },
            { type = "ability", abilityId = "detective_mode", name = "Detective Mode", message = "🔍 Ability: Enhanced investigation skills!" }
        },
        [25] = {
            { type = "vehicle_access", vehicleHash = "rhino", name = "Rhino Tank", message = "🛡️ Rhino Tank unlocked!" },
            { type = "passive_perk", perkId = "law_enforcement_veteran", value = 1.5, message = "⭐ Perk: Veteran - 50% bonus XP!" },
            { type = "cash_reward", amount = 100000, message = "💰 Level 25 Bonus: $100,000!" }
        },
        [30] = {
            { type = "ability", abilityId = "federal_authority", name = "Federal Authority", message = "🏛️ Ability: Federal law enforcement powers!" },
            { type = "cash_reward", amount = 200000, message = "💰 Level 30 Bonus: $200,000!" }
        },
        [35] = {
            { type = "passive_perk", perkId = "police_chief", value = 2.0, message = "👮‍♂️ Perk: Police Chief - Double authority!" },
            { type = "cash_reward", amount = 350000, message = "💰 Level 35 Bonus: $350,000!" }
        },
        [40] = {
            { type = "ability", abilityId = "commissioner", name = "Commissioner", message = "🏛️ Ability: Police Commissioner authority!" },
            { type = "cash_reward", amount = 500000, message = "💰 Level 40 Bonus: $500,000!" }
        },
        [45] = {
            { type = "passive_perk", perkId = "legendary_officer", value = 3.0, message = "⭐ Perk: Legendary Officer - Triple XP!" },
            { type = "cash_reward", amount = 750000, message = "💰 Level 45 Bonus: $750,000!" }
        },
        [50] = {
            { type = "ability", abilityId = "supreme_commander", name = "Supreme Commander", message = "👑 MAX LEVEL: Supreme Law Enforcement Commander!" },
            { type = "cash_reward", amount = 1000000, message = "💰 MAX LEVEL BONUS: $1,000,000!" },
            { type = "passive_perk", perkId = "prestige_ready", value = true, message = "🌟 Ready for Prestige!" }
        }
    }
}

-- Challenge System Configuration
Config.ChallengeSystem = {
    enabled = true,
    dailyChallenges = {
        robber = {
            { id = "daily_heists", name = "Master Thief", description = "Complete 3 successful heists", target = 3, xpReward = 150, cashReward = 10000 },
            { id = "daily_escapes", name = "Escape Artist", description = "Escape from police 5 times", target = 5, xpReward = 100, cashReward = 7500 },
            { id = "daily_lockpicks", name = "Lock Master", description = "Successfully lockpick 10 times", target = 10, xpReward = 75, cashReward = 5000 }
        },
        cop = {
            { id = "daily_arrests", name = "Law Enforcer", description = "Make 5 successful arrests", target = 5, xpReward = 150, cashReward = 10000 },
            { id = "daily_tickets", name = "Traffic Control", description = "Issue 10 speeding tickets", target = 10, xpReward = 100, cashReward = 7500 },
            { id = "daily_patrols", name = "Patrol Officer", description = "Complete 3 patrol routes", target = 3, xpReward = 75, cashReward = 5000 }
        }
    },
    weeklyChallenges = {
        robber = {
            { id = "weekly_bank_heist", name = "Bank Robber", description = "Complete a major bank heist", target = 1, xpReward = 500, cashReward = 50000 },
            { id = "weekly_contraband", name = "Smuggler", description = "Collect 5 contraband drops", target = 5, xpReward = 300, cashReward = 25000 }
        },
        cop = {
            { id = "weekly_high_value", name = "Bounty Hunter", description = "Arrest a 5-star wanted criminal", target = 1, xpReward = 500, cashReward = 50000 },
            { id = "weekly_equipment", name = "Tactical Expert", description = "Use advanced equipment 20 times", target = 20, xpReward = 300, cashReward = 25000 }
        }
    }
}

-- Seasonal Events Configuration
Config.SeasonalEvents = {
    enabled = true,
    events = {
        {
            name = "Crime Wave",
            description = "Double XP for all criminal activities",
            duration = 7 * 24 * 60 * 60, -- 7 days in seconds
            effects = { xpMultiplier = 2.0, role = "robber" }
        },
        {
            name = "Law & Order",
            description = "Double XP for all police activities",
            duration = 7 * 24 * 60 * 60, -- 7 days in seconds
            effects = { xpMultiplier = 2.0, role = "cop" }
        },
        {
            name = "Double Trouble",
            description = "Double XP for everyone!",
            duration = 3 * 24 * 60 * 60, -- 3 days in seconds
            effects = { xpMultiplier = 2.0, role = "all" }
        }
    }
}

-- =========================
--      Robber Hideouts
-- =========================
-- Locations for robber hideouts and safe houses
Config.RobberHideouts = {
    { x = 1536.63, y = 3582.91, z = 38.73, name = "Sandy Shores Hideout" },
    { x = -14.21, y = -1442.61, z = 31.10, name = "South LS Hideout" },
    { x = 1943.45, y = 3150.58, z = 46.78, name = "Desert Hideout" },
    { x = -1165.45, y = -1565.98, z = 4.37, name = "Vespucci Hideout" },
    { x = 139.53, y = 6366.54, z = 31.53, name = "Paleto Bay Hideout" },
}

-- =========================
--      Heist Locations
-- =========================
-- Locations for different types of heists
Config.HeistLocations = {
    { x = 254.11, y = 225.14, z = 101.87, type = "bank", name = "Pacific Standard Bank" },
    { x = 147.24, y = -1045.28, z = 29.37, type = "bank", name = "Pacific Standard Bank (Downtown)" },
    { x = -1210.85, y = -336.43, z = 37.78, type = "bank", name = "Fleeca Bank (Vinewood)" },
    { x = -2956.54, y = 481.01, z = 15.69, type = "bank", name = "Fleeca Bank (Great Ocean)" },
    { x = -104.87, y = 6477.83, z = 31.62, type = "bank", name = "Fleeca Bank (Paleto Bay)" },
    { x = -622.25, y = -229.95, z = 38.05, type = "jewelry", name = "Vangelico Jewelry Store" },
    { x = 1659.24, y = 4851.48, z = 41.99, type = "store", name = "Grapeseed Convenience Store" },
    { x = 2549.39, y = 384.83, z = 108.62, type = "store", name = "Highway Convenience Store" },
}

-- =========================
--    Contraband Dealers
-- =========================
-- Locations for contraband dealers where robbers can buy special items
Config.ContrabandDealers = {
    { x = 812.61, y = -285.70, z = 66.46, heading = 96.74, name = "Downtown Dealer" },
    { x = 728.01, y = 4170.95, z = 40.71, heading = 329.96, name = "Northern Dealer" },
    { x = -1337.25, y = -1277.94, z = 4.87, heading = 110.23, name = "Beach Dealer" },
}

-- =========================
--        Bounty Settings
-- =========================
Config.BountySettings = {
    enabled = true,           -- Enable/disable bounty system
    wantedLevelThreshold = 2, -- Minimum wanted level (stars) to trigger a bounty
    baseAmount = 1000,        -- Base bounty amount
    multiplier = 1.5,         -- Multiplier per wanted level above threshold
    maxAmount = 10000,        -- Maximum bounty that can be placed
    maxBounty = 10000,        -- Maximum bounty that can be accumulated
    duration = 30,            -- Minutes that a bounty remains active
    durationMinutes = 30,     -- Duration in minutes (alternative reference)
    cooldownMinutes = 10,     -- Cooldown before another bounty can be placed on the same player
    increasePerMinute = 100,  -- Amount bounty increases per minute
    claimMethod = "arrest"    -- How bounties are claimed ("arrest" or other methods)
}

-- =========================
--      Banking System
-- =========================

-- ATM Locations across the map
Config.ATMLocations = {
    -- Downtown Los Santos
    { pos = vector3(296.1, -896.1, 29.2), heading = 340.0, model = "prop_atm_01" },
    { pos = vector3(147.4, -1035.8, 29.3), heading = 340.0, model = "prop_atm_02" }, -- Near Pacific Standard
    { pos = vector3(-301.3, -829.3, 32.4), heading = 167.0, model = "prop_atm_01" },
    { pos = vector3(-821.6, -1081.9, 11.1), heading = 122.0, model = "prop_atm_02" },
    { pos = vector3(-1091.5, -2408.9, 13.9), heading = 315.0, model = "prop_atm_01" },
    
    -- Vinewood & Hills
    { pos = vector3(-1205.8, -325.5, 37.8), heading = 26.0, model = "prop_atm_02" }, -- Near Vinewood Fleeca
    { pos = vector3(-618.2, -708.8, 30.0), heading = 181.0, model = "prop_atm_01" },
    { pos = vector3(-57.6, -92.6, 57.8), heading = 68.0, model = "prop_atm_02" },
    
    -- Vespucci & Beach
    { pos = vector3(-2975.1, 380.1, 15.0), heading = 86.0, model = "prop_atm_01" }, -- Near Great Ocean Fleeca
    { pos = vector3(-1827.0, 784.5, 138.3), heading = 130.0, model = "prop_atm_02" },
    { pos = vector3(-3241.1, 997.5, 12.6), heading = 354.0, model = "prop_atm_01" },
    
    -- Sandy Shores & Desert
    { pos = vector3(1686.8, 4815.9, 42.0), heading = 8.0, model = "prop_atm_02" },
    { pos = vector3(1735.2, 6410.5, 35.0), heading = 242.0, model = "prop_atm_01" },
    { pos = vector3(1171.5, 2702.5, 38.2), heading = 178.0, model = "prop_atm_02" }, -- Near Route 68 Fleeca
    
    -- Paleto Bay
    { pos = vector3(-112.2, 6467.8, 31.6), heading = 134.0, model = "prop_atm_01" }, -- Near Paleto Fleeca
    { pos = vector3(-386.7, 6046.1, 31.5), heading = 224.0, model = "prop_atm_02" },
    
    -- Grapeseed & East Coast
    { pos = vector3(1138.2, -468.9, 66.7), heading = 75.0, model = "prop_atm_01" },
    { pos = vector3(2564.4, 2584.5, 38.1), heading = 8.0, model = "prop_atm_02" },
}

-- Bank Teller Locations (for complex transactions)
Config.BankTellers = {
    {
        pos = vector3(150.3, -1040.5, 29.4),
        heading = 340.0,
        model = "cs_bankman",
        name = "Pacific Standard Bank",
        services = {"loans", "investments", "accounts", "transfers"}
    },
    {
        pos = vector3(-1212.5, -331.2, 37.8),
        heading = 26.0,
        model = "cs_bankman",
        name = "Fleeca Bank Vinewood",
        services = {"accounts", "transfers", "basic_loans"}
    },
    {
        pos = vector3(-2962.2, 482.2, 15.7),
        heading = 1.0,
        model = "cs_bankman",
        name = "Fleeca Bank Great Ocean",
        services = {"accounts", "transfers", "basic_loans"}
    },
    {
        pos = vector3(1175.3, 2706.2, 38.1),
        heading = 178.0,
        model = "cs_bankman",
        name = "Fleeca Bank Route 68",
        services = {"accounts", "transfers", "basic_loans"}
    },
    {
        pos = vector3(-102.5, 6477.2, 31.6),
        heading = 45.0,
        model = "cs_bankman",
        name = "Blaine County Savings",
        services = {"accounts", "transfers", "basic_loans"}
    }
}

-- Banking Settings
Config.Banking = {
    startingBalance = 5000,          -- Starting bank balance for new players
    dailyWithdrawalLimit = 50000,    -- Daily ATM withdrawal limit
    transferFee = 50,                -- Fee for bank transfers between players
    interestRate = 0.001,            -- Daily interest rate (0.1%)
    interestMinBalance = 10000,      -- Minimum balance to earn interest
    loanInterestRate = 0.005,        -- Daily loan interest rate (0.5%)
    maxLoanAmount = 100000,          -- Maximum loan amount
    loanRequiredLevel = 5,           -- Required level to get loans
    loanCollateralRate = 0.5,        -- Collateral required (50% of loan value in cash)
    atmHackTime = 30000,             -- Time to hack ATM (30 seconds)
    atmHackReward = {2000, 8000},    -- Min/max ATM hack reward
    atmHackCooldown = 300000,        -- ATM hack cooldown per ATM (5 minutes)
}

-- Investment Options
Config.Investments = {
    {
        id = "property_development",
        name = "Property Development Fund",
        description = "Invest in Los Santos real estate development",
        minInvestment = 25000,
        expectedReturn = 0.08, -- 8% return over investment period
        riskLevel = "medium",
        duration = 72, -- hours
        requiredLevel = 10
    },
    {
        id = "tech_startup",
        name = "Tech Startup Portfolio",
        description = "High-risk, high-reward technology investments",
        minInvestment = 50000,
        expectedReturn = 0.15, -- 15% return potential
        riskLevel = "high",
        duration = 48,
        requiredLevel = 15
    },
    {
        id = "government_bonds",
        name = "Government Bonds",
        description = "Safe, low-yield government securities",
        minInvestment = 10000,
        expectedReturn = 0.03, -- 3% return
        riskLevel = "low",
        duration = 168, -- 1 week
        requiredLevel = 5
    },
    {
        id = "business_loan_fund",
        name = "Business Loan Fund",
        description = "Provide funding to other players' businesses",
        minInvestment = 75000,
        expectedReturn = 0.12, -- 12% return
        riskLevel = "medium",
        duration = 96,
        requiredLevel = 20
    }
}

-- =========================
--    Enhanced Heist System
-- =========================

-- Heist Planning Locations (where crews can plan heists)
Config.HeistPlanningLocations = {
    {
        pos = vector3(1395.2, 1141.9, 114.3),
        heading = 0.0,
        name = "Vinewood Hills Safehouse",
        interior = "apa_v_mp_h_08_a", -- High-end apartment interior
        access = "robber"
    },
    {
        pos = vector3(-1165.4, -1566.0, 4.4),
        heading = 125.0,
        name = "Vespucci Warehouse",
        interior = "imp_impexp_interior_01_a", -- Warehouse interior
        access = "robber"
    },
    {
        pos = vector3(2121.4, 4784.2, 40.9),
        heading = 294.0,
        name = "Sandy Shores Airfield Hangar",
        interior = null, -- Open area
        access = "robber"
    }
}

-- Enhanced Heist Locations with multi-stage configurations
Config.EnhancedHeists = {
    -- Major Bank Heists (require crew)
    {
        id = "pacific_standard_vault",
        name = "Pacific Standard Bank Vault",
        type = "major_bank",
        location = vector3(255.0, 225.0, 102.0),
        requiredCrew = 4,
        maxReward = 500000,
        minReward = 200000,
        difficulty = "expert",
        duration = 900, -- 15 minutes
        cooldown = 7200, -- 2 hours
        requiredLevel = 25,
        stages = {
            {stage = "reconnaissance", duration = 300, description = "Scout security patterns"},
            {stage = "disable_security", duration = 180, description = "Hack security systems"},
            {stage = "breach_vault", duration = 240, description = "Drill through vault door"},
            {stage = "extract_money", duration = 120, description = "Load cash and escape"},
            {stage = "escape", duration = 60, description = "Evade police response"}
        },
        equipment = {"thermite", "drill", "hacking_device", "emp_device", "heavy_armor"},
        security = {
            guards = 8,
            cameras = 12,
            alarms = 3,
            vaultDoor = "reinforced_steel",
            responseTime = 60 -- seconds before cops arrive
        }
    },
    
    -- Casino Heist
    {
        id = "diamond_casino_vault",
        name = "Diamond Casino & Resort Vault",
        type = "casino",
        location = vector3(1089.9, 206.1, -49.0),
        requiredCrew = 3,
        maxReward = 750000,
        minReward = 300000,
        difficulty = "expert",
        duration = 1200, -- 20 minutes
        cooldown = 10800, -- 3 hours
        requiredLevel = 30,
        stages = {
            {stage = "infiltration", duration = 300, description = "Enter casino undetected"},
            {stage = "security_bypass", duration = 240, description = "Bypass casino security"},
            {stage = "vault_access", duration = 360, description = "Access vault systems"},
            {stage = "heist_execution", duration = 240, description = "Execute the heist"},
            {stage = "escape", duration = 60, description = "Escape with the loot"}
        },
        equipment = {"keycard", "hacking_device", "drill", "disguise", "smoke_grenade"},
        security = {
            guards = 15,
            cameras = 25,
            alarms = 5,
            vaultDoor = "biometric_lock",
            responseTime = 45
        }
    },
    
    -- Jewelry Store Heists (medium crew)
    {
        id = "vangelico_jewelry",
        name = "Vangelico Jewelry Store",
        type = "jewelry",
        location = vector3(-622.3, -230.0, 38.1),
        requiredCrew = 2,
        maxReward = 150000,
        minReward = 75000,
        difficulty = "intermediate",
        duration = 300, -- 5 minutes
        cooldown = 1800, -- 30 minutes
        requiredLevel = 15,
        stages = {
            {stage = "break_in", duration = 60, description = "Break display cases"},
            {stage = "grab_jewelry", duration = 180, description = "Collect jewelry"},
            {stage = "escape", duration = 60, description = "Escape before police arrive"}
        },
        equipment = {"crowbar", "bag", "mask"},
        security = {
            guards = 2,
            cameras = 8,
            alarms = 2,
            responseTime = 120
        }
    },
    
    -- Solo Heists
    {
        id = "fleeca_bank_solo",
        name = "Fleeca Bank (Solo Operation)",
        type = "small_bank",
        location = vector3(-1212.0, -330.0, 37.8),
        requiredCrew = 1,
        maxReward = 50000,
        minReward = 25000,
        difficulty = "intermediate",
        duration = 240, -- 4 minutes
        cooldown = 900, -- 15 minutes
        requiredLevel = 10,
        stages = {
            {stage = "intimidate", duration = 60, description = "Control the situation"},
            {stage = "access_vault", duration = 120, description = "Get to the vault"},
            {stage = "escape", duration = 60, description = "Escape with cash"}
        },
        equipment = {"weapon", "mask", "bag"},
        security = {
            guards = 1,
            cameras = 4,
            alarms = 1,
            responseTime = 180
        }
    },
    
    -- New Heist Types
    {
        id = "luxury_car_dealership",
        name = "Premium Deluxe Motorsport",
        type = "vehicle_theft",
        location = vector3(-56.0, -1097.0, 26.4),
        requiredCrew = 2,
        maxReward = 200000, -- Vehicle values
        minReward = 100000,
        difficulty = "intermediate",
        duration = 420, -- 7 minutes
        cooldown = 2700, -- 45 minutes
        requiredLevel = 18,
        stages = {
            {stage = "disable_security", duration = 120, description = "Disable security systems"},
            {stage = "steal_vehicles", duration = 240, description = "Steal high-end vehicles"},
            {stage = "escape", duration = 60, description = "Escape with stolen cars"}
        },
        equipment = {"hacking_device", "lockpick", "emp_device"},
        security = {
            guards = 3,
            cameras = 6,
            alarms = 2,
            responseTime = 150
        }
    },
    
    {
        id = "cargo_ship",
        name = "Cargo Ship Heist",
        type = "maritime",
        location = vector3(-163.0, -2365.7, 5.0),
        requiredCrew = 3,
        maxReward = 350000,
        minReward = 175000,
        difficulty = "hard",
        duration = 600, -- 10 minutes
        cooldown = 3600, -- 1 hour
        requiredLevel = 22,
        stages = {
            {stage = "board_ship", duration = 120, description = "Board the cargo ship"},
            {stage = "locate_cargo", duration = 180, description = "Find valuable containers"},
            {stage = "extract_goods", duration = 240, description = "Extract valuable cargo"},
            {stage = "escape", duration = 60, description = "Escape by sea or air"}
        },
        equipment = {"cutting_torch", "boat", "heavy_armor", "bag"},
        security = {
            guards = 6,
            cameras = 8,
            alarms = 2,
            responseTime = 240 -- Coast Guard response
        }
    },
    
    {
        id = "government_facility",
        name = "Government Data Facility",
        type = "infiltration",
        location = vector3(2490.0, -383.0, 94.0),
        requiredCrew = 4,
        maxReward = 400000,
        minReward = 200000,
        difficulty = "expert",
        duration = 900, -- 15 minutes
        cooldown = 14400, -- 4 hours
        requiredLevel = 35,
        stages = {
            {stage = "infiltrate", duration = 240, description = "Infiltrate the facility"},
            {stage = "hack_systems", duration = 300, description = "Hack government databases"},
            {stage = "extract_data", duration = 180, description = "Download classified data"},
            {stage = "destroy_evidence", duration = 120, description = "Cover your tracks"},
            {stage = "escape", duration = 60, description = "Escape government pursuit"}
        },
        equipment = {"keycard", "advanced_hacking_device", "emp_device", "thermite", "stealth_suit"},
        security = {
            guards = 12,
            cameras = 20,
            alarms = 6,
            responseTime = 30 -- Fast government response
        }
    }
}

-- Heist Equipment Shop (Special vendor for heist gear)
Config.HeistEquipment = {
    location = vector4(707.2, -966.3, 30.4, 271.5),
    model = "g_m_m_chigoon_02",
    name = "Equipment Specialist",
    requiredLevel = 8,
    items = {
        -- Basic Equipment
        {id = "lockpick", price = 500, name = "Lockpick", description = "Basic lock bypassing tool"},
        {id = "crowbar", price = 300, name = "Crowbar", description = "Break glass and doors"},
        {id = "bag", price = 200, name = "Duffel Bag", description = "Carry stolen goods"},
        {id = "mask", price = 150, name = "Face Mask", description = "Hide your identity"},
        
        -- Advanced Equipment
        {id = "drill", price = 2500, name = "Diamond Drill", description = "Drill through vault doors", requiredLevel = 15},
        {id = "thermite", price = 5000, name = "Thermite Charge", description = "Burn through reinforced barriers", requiredLevel = 20},
        {id = "hacking_device", price = 3500, name = "Hacking Device", description = "Bypass electronic security", requiredLevel = 12},
        {id = "emp_device", price = 7500, name = "EMP Device", description = "Disable electronics", requiredLevel = 25},
        
        -- Specialized Gear
        {id = "keycard", price = 1000, name = "Cloned Keycard", description = "Access restricted areas", requiredLevel = 18},
        {id = "disguise", price = 800, name = "Security Disguise", description = "Blend in with staff", requiredLevel = 16},
        {id = "stealth_suit", price = 15000, name = "Stealth Suit", description = "Reduce detection chance", requiredLevel = 30},
        {id = "smoke_grenade", price = 1200, name = "Smoke Grenade", description = "Create cover for escape", requiredLevel = 14},
        {id = "cutting_torch", price = 4000, name = "Cutting Torch", description = "Cut through metal barriers", requiredLevel = 22},
        {id = "boat", price = 25000, name = "Escape Boat", description = "Waterway escape vehicle", requiredLevel = 20},
        {id = "heavy_armor", price = 10000, name = "Heavy Armor", description = "Maximum protection", requiredLevel = 28}
    }
}

-- Crew Roles and Specializations
Config.CrewRoles = {
    {
        id = "mastermind",
        name = "Mastermind",
        description = "Plans the heist and coordinates the crew",
        bonuses = {
            planning_speed = 1.25,
            crew_coordination = 1.15,
            escape_routes = 2
        },
        requiredLevel = 20
    },
    {
        id = "hacker",
        name = "Hacker",
        description = "Specializes in electronic security bypass",
        bonuses = {
            hacking_speed = 1.5,
            camera_disable = 1.3,
            alarm_delay = 2.0
        },
        requiredLevel = 15
    },
    {
        id = "demolitions",
        name = "Demolitions Expert",
        description = "Handles explosives and breaching",
        bonuses = {
            thermite_efficiency = 1.4,
            drill_speed = 1.3,
            explosive_damage = 1.2
        },
        requiredLevel = 18
    },
    {
        id = "driver",
        name = "Getaway Driver",
        description = "Provides escape vehicles and routes",
        bonuses = {
            vehicle_handling = 1.3,
            pursuit_evasion = 1.4,
            escape_time = 0.8
        },
        requiredLevel = 12
    },
    {
        id = "muscle",
        name = "Muscle",
        description = "Provides security and crowd control",
        bonuses = {
            intimidation = 1.5,
            guard_takedown = 1.3,
            civilian_control = 1.4
        },
        requiredLevel = 10
    },
    {
        id = "infiltrator",
        name = "Infiltrator",
        description = "Specializes in stealth and reconnaissance",
        bonuses = {
            stealth_detection = 0.7,
            lockpicking_speed = 1.4,
            reconnaissance = 1.6
        },
        requiredLevel = 16
    }
}

-- =========================
--    Missing Config Properties
-- =========================

-- Speed limit for wanted system
Config.SpeedLimitMph = 60.0

-- Keybind configurations
Config.Keybinds = {
    openInventory = 244,      -- M Key (INPUT_INTERACTION_MENU)
    toggleAdminPanel = 289,   -- F2 Key
    openStore = 38,           -- E Key (INPUT_CONTEXT)
    openCharacterEditor = 167 -- F6 Key
}

-- Contraband dealer locations
Config.ContrabandDealers = {
    {
        location = vector4(1005.76, 88.40, 90.24, 270.24),
        model = "s_m_y_dealer_01",
        name = "Black Market Dealer",
        blipSprite = 378,
        blipColor = 1,
        items = {
            "weapon_knife",
            "weapon_switchblade",
            "weapon_microsmg",
            "lockpick",
            "mask"
        }
    }
}

-- Wanted system settings
Config.WantedSettings = {
    levels = {
        { stars = 1, description = "Minor Crime", bounty = 1000 },
        { stars = 2, description = "Moderate Crime", bounty = 2500 },
        { stars = 3, description = "Serious Crime", bounty = 5000 },
        { stars = 4, description = "Major Crime", bounty = 10000 },
        { stars = 5, description = "Most Wanted", bounty = 25000 }
    }
}

-- Character editor configuration
Config.CharacterEditor = {
    defaultCharacter = {
        model = "mp_m_freemode_01",
        face = 0,
        skin = 0,
        hair = 0,
        hairColor = 0,
        eyeColor = 0,
        beard = 0,
        beardColor = 0,
        eyebrows = 0,
        eyebrowsColor = 0,
        makeup = 0,
        lipstick = 0,
        tattoos = {}
    }
}

-- Leveling system configuration
Config.LevelingSystemEnabled = true
Config.MaxLevel = 50
Config.XPTable = {
    [1] = 1000,   [2] = 1200,   [3] = 1400,   [4] = 1600,   [5] = 1800,
    [6] = 2000,   [7] = 2200,   [8] = 2400,   [9] = 2600,   [10] = 2800,
    [11] = 3000,  [12] = 3200,  [13] = 3400,  [14] = 3600,  [15] = 3800,
    [16] = 4000,  [17] = 4200,  [18] = 4400,  [19] = 4600,  [20] = 4800,
    [21] = 5000,  [22] = 5200,  [23] = 5400,  [24] = 5600,  [25] = 5800,
    [26] = 6000,  [27] = 6200,  [28] = 6400,  [29] = 6600,  [30] = 6800,
    [31] = 7000,  [32] = 7200,  [33] = 7400,  [34] = 7600,  [35] = 7800,
    [36] = 8000,  [37] = 8200,  [38] = 8400,  [39] = 8600,  [40] = 8800,
    [41] = 9000,  [42] = 9200,  [43] = 9400,  [44] = 9600,  [45] = 9800,
    [46] = 10000, [47] = 10200, [48] = 10400, [49] = 10600, [50] = 10800
}

-- Heist locations (basic configuration)
Config.HeistLocations = {
    {
        location = vector3(150.0, -1040.0, 29.0),
        name = "Pacific Standard Bank",
        type = "bank",
        difficulty = "hard",
        reward = {min = 50000, max = 150000}
    },
    {
        location = vector3(-1212.0, -330.0, 37.8),
        name = "Fleeca Bank (Vinewood)",
        type = "bank",
        difficulty = "medium",
        reward = {min = 25000, max = 75000}
    }
}

-- Robber hideout locations
Config.RobberHideouts = {
    {
        location = vector3(1395.2, 1141.9, 114.3),
        name = "Vinewood Hills Safehouse",
        blipSprite = 40,
        blipColor = 1,
        services = {"weapon_storage", "vehicle_storage", "planning"}
    },
    {
        location = vector3(-1165.4, -1566.0, 4.4),
        name = "Vespucci Warehouse",
        blipSprite = 40,
        blipColor = 1,
        services = {"weapon_storage", "vehicle_storage"}
    }
}

-- Bank teller locations
Config.BankTellers = {
    {
        location = vector4(150.0, -1040.0, 29.0, 340.0),
        model = "cs_bankman",
        name = "Pacific Standard Teller",
        services = {"accounts", "transfers", "loans"}
    },
    {
        location = vector4(-1212.0, -330.0, 37.8, 26.0),
        model = "cs_bankman",
        name = "Fleeca Bank Teller",
        services = {"accounts", "transfers"}
    }
}
