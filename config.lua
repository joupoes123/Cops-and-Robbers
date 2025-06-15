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

Config.DebugLogging   = false -- Set to true to enable detailed server console logging (may cause spam)
Config.MaxPlayers     = 64
Config.HeistCooldown  = 600    -- seconds (10 minutes), Cooldown between major heists for a player or globally.
Config.HeistRadius    = 1000.0 -- meters, General radius for heist related activities or blips.
Config.DefaultStartMoney = 2500 -- Starting cash for new players.

-- Spawn locations based on roles
Config.SpawnPoints = {
    cop    = vector3(452.6, -980.0, 30.7),   -- Police station location (Mission Row PD)
    robber = vector3(2126.7, 4794.1, 41.1),  -- Example: Countryside airport location (Sandy Shores Airfield)
    citizen = vector3(-260.0, -970.0, 31.2) -- Legion Square
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
        location = vector3(1000.32, 0.68, 78.30), -- Behind Diamond Casino in alley - accessible city location
        heading  = 265.0,
        model    = "s_m_y_dealer_01",
        name     = "Black Market Dealer",        items    = { 
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
    {        location = vector3(1961.48, 3740.69, 32.34),  -- Sandy Shores, near barber
        heading  = 300.0,
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
        location = vector3(451.39, -974.42, 30.69),
        heading  = 125.60,
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
    { name = "Sticky Bomb",          itemId = "weapon_stickybomb",       basePrice = 2500, category = "Utility", minLevelRobber = 15, icon = "💣" },    -- Accessories (Primarily for role-play or appearance, server logic might give minor effects)
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
    enableNPCResponse = false, -- MASTER SWITCH: Set to true to enable NPC police response, false to disable.
    baseIncreasePoints = 2,    -- Default points for minor infractions if not specified in crimes. (Increased from 1)
    levels = {                 -- Defines star levels and UI labels based on accumulated wanted points.
        { stars = 1, threshold = 15,  uiLabel = "Wanted: ★☆☆☆☆", minPunishment = 60,  maxPunishment = 120 }, -- Increased from 10
        { stars = 2, threshold = 40,  uiLabel = "Wanted: ★★☆☆☆", minPunishment = 120, maxPunishment = 240 }, -- Increased from 30
        { stars = 3, threshold = 80,  uiLabel = "Wanted: ★★★☆☆", minPunishment = 240, maxPunishment = 480 }, -- Increased from 60
        { stars = 4, threshold = 130, uiLabel = "Wanted: ★★★★☆", minPunishment = 480, maxPunishment = 720 }, -- Increased from 100
        { stars = 5, threshold = 200, uiLabel = "Wanted: ★★★★★", minPunishment = 720, maxPunishment = 1000 }  -- Increased from 150
    },
    crimes = {                 -- Points assigned for specific crimes. These keys are used in server.lua when calling IncreaseWantedPoints.        -- Traffic Violations (increased values)
        speeding                   = 3,    -- For receiving a speeding ticket. (increased from 1)
        reckless_driving           = 5,    -- Example: driving on sidewalk, excessive near misses. (increased from 2)
        hit_and_run_vehicle        = 8,    -- Hitting a vehicle and fleeing. (increased from 3)
        hit_and_run_ped            = 12,   -- Hitting a pedestrian and fleeing. (increased from 5)
        hit_and_run_civilian       = 12,   -- Hitting a civilian pedestrian and fleeing.
        hit_and_run_cop            = 25,   -- Hitting a police officer and fleeing.
        -- Property Crimes (increased values)
        grand_theft_auto           = 10,   -- Stealing an occupied vehicle. (increased from 5)
        store_robbery_small        = 8,    -- Example: For smaller, less risky store robberies. (increased from 5)
        store_robbery_medium       = 15,   -- For general store robberies. (increased from 10)
        armed_robbery_player       = 12,   -- Robbing another player at gunpoint (if implemented). (increased from 8)
        -- Major Heists (increased values)
        bank_heist_major           = 35,   -- For successful major bank heists. (increased from 20)
        armored_car_heist          = 25,   -- For successful armored car heists. (increased from 15)
        -- Violent Crimes (increased values)
        assault_civilian           = 8,    -- Assaulting a civilian without killing. (increased from 3)
        murder_civilian            = 20,   -- For killing a civilian. (increased from 10)
        civilian_murder            = 20,   -- Alternative name for killing a civilian.
        assault_cop                = 25,   -- For assaulting a police officer. (increased from 15)
        murder_cop                 = 40,   -- For killing a police officer. (increased from 25)
        cop_murder                 = 40,   -- Alternative name for killing a police officer.
        -- Other (increased values)
        resisting_arrest           = 10,   -- Fleeing from police after being told to stop. (increased from 5)
        jailbreak_attempt          = 50,   -- Attempting to break someone out of jail. (increased from 30)        emp_used_on_police         = 15,   -- Using EMP that affects police vehicles. (increased from 8)
        power_grid_sabotaged_crime = 15,   -- Sabotaging power grid (distinct from XP action). (increased from 8)
        restricted_area_entry      = 15    -- Entering restricted areas like Fort Zancudo. (increased from 6)
    },
    decayRatePoints      = 1,    -- Amount of wanted points to decay per interval.
    decayIntervalMs      = 25000,-- Milliseconds (25 seconds) - how often the decay check runs. (decreased from 45000)
    noCrimeCooldownMs    = 60000,-- Milliseconds (60 seconds) - time player must be "clean" before decay starts. (decreased from 120000)
    copSightCooldownMs   = 30000,-- Milliseconds (30 seconds) - time player must be out of cop sight for decay to resume.
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
    { location = vector3(2120.7, 4780.1, 40.0), heading = 180.0, model = "sultan" }, -- Fast sedan near Robber spawn
    { location = vector3(2125.2, 4785.3, 40.0), heading = 200.0, model = "futo" },   -- Drift car
    { location = vector3(2115.1, 4775.8, 40.0), heading = 160.0, model = "elegy2" }, -- Sports car
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
    [1] = 75,   -- XP to reach Level 2 (from Lvl 1)
    [2] = 150,  -- XP to reach Level 3 (from Lvl 2)
    [3] = 300,  -- XP to reach Level 4
    [4] = 450,  -- XP to reach Level 5
    [5] = 600,  -- XP to reach Level 6
    [6] = 750,  -- XP to reach Level 7
    [7] = 900,  -- XP to reach Level 8
    [8] = 1050, -- XP to reach Level 9
    [9] = 1200, -- XP to reach Level 10
    [10] = 1350, -- XP to reach Level 11
    [11] = 1500, -- XP to reach Level 12
    [12] = 1650, -- XP to reach Level 13
    [13] = 1800, -- XP to reach Level 14
    [14] = 1950, -- XP to reach Level 15
    [15] = 2100, -- XP to reach Level 16
    [16] = 2250, -- XP to reach Level 17
    [17] = 2400, -- XP to reach Level 18
    [18] = 2550, -- XP to reach Level 19
    [19] = 2700  -- XP to reach Level 20
    -- Level 20 is max level
}
Config.MaxLevel = 20 -- Maximum attainable level in this system.

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

-- Defines what unlocks at each level for each role.
-- Structure: Config.LevelUnlocks[role][levelNumber] = { table of unlock definitions }
-- Unlock Definition Types:
--   - { type="item_access", itemId="item_id_from_Config.Items", message="Notification message for player." }
--   - { type="passive_perk", perkId="unique_perk_identifier", value=numeric_value_or_true, message="Notification message." } (Server handles perk logic)
--   - { type="vehicle_access", vehicleHash="vehicle_model_hash", name="Display Name", message="Notification message." } (Server handles access logic)
Config.LevelUnlocks = {
    robber = {
        [2] = {
            { type = "item_access", itemId = "crowbar", message = "Crowbar unlocked for breaking and entering!" },
            { type = "item_access", itemId = "weapon_microsmg", message = "Micro SMG unlocked in black market!" }
        },
        [3] = {
            { type = "item_access", itemId = "drill", message = "Drill unlocked for advanced heists!" },
            { type = "item_access", itemId = "weapon_sawnoffshotgun", message = "Sawed-Off Shotgun unlocked!" }
        },
        [4] = {
            { type = "item_access", itemId = "adv_lockpick", message = "Advanced Lockpick unlocked!" },
            { type = "item_access", itemId = "weapon_microsmg", message = "Micro SMG fully unlocked!" }
        },
        [5] = {
            { type = "item_access", itemId = "weapon_smg", message = "SMG unlocked in black market!" },
            { type = "passive_perk", perkId = "faster_lockpicking", value = 0.85, message = "Perk: Lockpicking 15% faster!" }
        },
        [6] = {
            { type = "item_access", itemId = "hacking_device", message = "Hacking Device unlocked for electronic systems!" }
        },
        [8] = {
            { type = "item_access", itemId = "weapon_emplauncher", message = "Compact EMP Launcher unlocked!" },
            { type = "item_access", itemId = "thermite", message = "Thermite unlocked for vault breaching!" }
        },
        [10] = {
            { type = "item_access", itemId = "weapon_assaultrifle", message = "Assault Rifle unlocked!" },
            { type = "passive_perk", perkId = "faster_contraband_collection", value = 0.8, message = "Perk: Contraband collection time reduced by 20%!" }
        },
        [12] = {
            { type = "item_access", itemId = "c4", message = "C4 Explosive unlocked for major heists!" }
        },
        [15] = {
            { type = "item_access", itemId = "weapon_sniperrifle", message = "Sniper Rifle unlocked!" },
            { type = "item_access", itemId = "weapon_stickybomb", message = "Sticky Bomb unlocked!" }
        },
        [18] = {
            { type = "passive_perk", perkId = "master_criminal", value = true, message = "Perk: Master Criminal - 25% bonus heist payouts!" }
        },
        [20] = {
            { type = "passive_perk", perkId = "criminal_mastermind", value = true, message = "MAX LEVEL: Criminal Mastermind - Ultimate heist bonuses!" }
        }
    },
    cop = {
        -- Level 1 unlocks are baseline equipment (handled by minLevelCop = 1 in Config.Items)
        [2] = {
            { type = "item_access", itemId = "weapon_pumpshotgun", message = "Pump Shotgun unlocked for patrol duty!" },
            { type = "item_access", itemId = "weapon_combatpistol", message = "Combat Pistol unlocked!" },
            { type = "item_access", itemId = "weapon_flaregun", message = "Flare Gun unlocked for emergencies!" }
        },
        [3] = {
            { type = "item_access", itemId = "k9whistle", message = "K9 Whistle unlocked - Call for K9 support!" },
            { type = "item_access", itemId = "weapon_pistol_mk2", message = "Pistol Mk II unlocked!" },
            { type = "item_access", itemId = "weapon_combatshotgun", message = "Combat Shotgun unlocked!" }
        },
        [4] = {
            { type = "item_access", itemId = "weapon_carbinerifle", message = "Carbine Rifle unlocked for serious threats!" },
            { type = "item_access", itemId = "weapon_stunrod", message = "The Shocker (Stun Rod) unlocked!" }
        },
        [5] = {
            { type = "vehicle_access", vehicleHash = "policeb", name = "Police Bike", message = "Police Bike unlocked for patrol!" },
            { type = "passive_perk", perkId = "improved_taser", value = 1.5, message = "Perk: Taser range increased by 50%!" }
        },
        [6] = {
            { type = "item_access", itemId = "heavy_armor", message = "Heavy Armor unlocked for high-risk operations!" }
        },
        [7] = {
            { type = "vehicle_access", vehicleHash = "policet", name = "Police Transport", message = "Police Transport unlocked!" },
            { type = "passive_perk", perkId = "extra_spike_strips", value = 1, message = "Perk: Carry +1 Spike Strip!" }
        },
        [8] = {
            { type = "vehicle_access", vehicleHash = "polmav", name = "Police Maverick", message = "Police Helicopter unlocked!" }
        },
        [10] = {
            { type = "item_access", itemId = "weapon_appistol", message = "AP Pistol unlocked!" },
            { type = "item_access", itemId = "weapon_heavyshotgun", message = "Heavy Shotgun unlocked!" },
            { type = "item_access", itemId = "weapon_combatmg", message = "Combat MG unlocked for extreme threats!" },
            { type = "passive_perk", perkId = "arrest_bonus", value = 1.25, message = "Perk: 25% bonus XP from arrests!" }
        },
        [12] = {
            { type = "vehicle_access", vehicleHash = "riot", name = "Riot Van", message = "Riot Van unlocked for crowd control!" }
        },
        [15] = {
            { type = "item_access", itemId = "weapon_sniperrifle", message = "Sniper Rifle unlocked for tactical operations!" },
            { type = "item_access", itemId = "weapon_bzgas", message = "BZ Gas unlocked for crowd control!" },
            { type = "passive_perk", perkId = "tactical_specialist", value = true, message = "Perk: Tactical Specialist - Reduced equipment costs!" }
        },
        [18] = {
            { type = "vehicle_access", vehicleHash = "rhino", name = "Rhino Tank", message = "Rhino Tank unlocked for extreme situations!" },
            { type = "passive_perk", perkId = "law_enforcement_veteran", value = true, message = "Perk: Law Enforcement Veteran - Enhanced authority!" }
        },
        [20] = {
            { type = "item_access", itemId = "weapon_snowball", message = "Snowball Launcher unlocked - For... morale purposes!" },
            { type = "passive_perk", perkId = "police_chief", value = true, message = "MAX LEVEL: Police Chief - Ultimate law enforcement authority!" }
        }
    }
}

-- Weapon names mapping for display purposes (e.g., notifications, UI)
Config.WeaponNames = {
    -- Pistols
    ["weapon_pistol"] = "Pistol",
    ["weapon_combatpistol"] = "Combat Pistol",
    ["weapon_appistol"] = "AP Pistol",
    ["weapon_pistol_mk2"] = "Pistol Mk II",
    ["weapon_heavypistol"] = "Heavy Pistol",
    ["weapon_doubleaction"] = "Double-Action Revolver",
    ["weapon_revolver_mk2"] = "Heavy Revolver Mk II",
    ["weapon_vintagepistol"] = "Vintage Pistol",
    ["weapon_snspistol"] = "SNS Pistol",
    ["weapon_machinepistol"] = "Machine Pistol",
    
    -- SMGs & Rifles
    ["weapon_smg"] = "SMG",
    ["weapon_microsmg"] = "Micro SMG",
    ["weapon_assaultrifle"] = "Assault Rifle",
    ["weapon_carbinerifle"] = "Carbine Rifle",
    ["weapon_specialcarbine_mk2"] = "Special Carbine Mk II",
    ["weapon_combatmg"] = "Combat MG",
    ["weapon_sniperrifle"] = "Sniper Rifle",
    ["weapon_heavysniper"] = "Heavy Sniper",
    ["weapon_heavysniper_mk2"] = "Heavy Sniper Mk II",
    ["weapon_marksmanrifle"] = "Marksman Rifle",
    ["weapon_marksmanrifle_mk2"] = "Marksman Rifle Mk II",
    ["weapon_compactrifle"] = "Compact Rifle",
    ["weapon_bullpuprifle"] = "Bullpup Rifle",
    ["weapon_advancedrifle"] = "Advanced Rifle",
    ["weapon_specialcarbine"] = "Special Carbine",
    ["weapon_machinegun"] = "Machine Gun",
    ["weapon_combatmg_mk2"] = "Combat MG Mk II",
    ["weapon_minigun"] = "Minigun",
    ["weapon_minismg"] = "Mini SMG",
    ["weapon_gusenberg"] = "Gusenberg Sweeper",
    
    -- Shotguns
    ["weapon_pumpshotgun"] = "Pump Shotgun",
    ["weapon_combatshotgun"] = "Combat Shotgun",
    ["weapon_heavyshotgun"] = "Heavy Shotgun",
    ["weapon_assaultshotgun"] = "Assault Shotgun",
    ["weapon_sawnoffshotgun"] = "Sawed-Off Shotgun",
    ["weapon_bullpupshotgun"] = "Bullpup Shotgun",
    ["weapon_autoshotgun"] = "Auto Shotgun",
    ["weapon_dbshotgun"] = "Double Barrel Shotgun",
    ["weapon_musket"] = "Musket",
    
    -- Melee Weapons
    ["weapon_knife"] = "Knife",
    ["weapon_bat"] = "Baseball Bat",
    ["weapon_crowbar"] = "Crowbar",
    ["weapon_switchblade"] = "Switchblade",
    ["weapon_nightstick"] = "Nightstick",
    ["weapon_flashlight"] = "Flashlight",
    ["weapon_stungun"] = "Stun Gun",
    ["weapon_stunrod"] = "The Shocker",
    ["weapon_dagger"] = "Dagger",
    ["weapon_hatchet"] = "Hatchet",
    ["weapon_machete"] = "Machete",
    ["weapon_katana"] = "Katana",
    ["weapon_wrench"] = "Wrench",
    ["weapon_hammer"] = "Hammer",
    ["weapon_poolcue"] = "Pool Cue",
    
    -- Special Weapons
    ["weapon_flaregun"] = "Flare Gun",
    ["weapon_fireextinguisher"] = "Fire Extinguisher",
    ["weapon_emplauncher"] = "Compact EMP Launcher",
    ["weapon_snowball"] = "Snowball Launcher",
    ["weapon_stickybomb"] = "Sticky Bomb",
    ["weapon_grenade"] = "Grenade",
    ["weapon_rpg"] = "RPG",
    ["weapon_grenadelauncher"] = "Grenade Launcher",
    ["weapon_hominglauncher"] = "Homing Launcher",
    ["weapon_firework"] = "Firework Launcher",
    ["weapon_railgun"] = "Railgun",
    
    -- Throwables
    ["weapon_flare"] = "Flare",
    ["weapon_smokegrenade"] = "Tear Gas",
    ["weapon_bzgas"] = "BZ Gas"
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
