-- config.lua

-- General Settings
Config = {}

Config.MaxPlayers = 64
Config.HeistCooldown = 600 -- seconds
Config.HeistRadius = 1000.0
Config.CopSpawn = vector3(452.6, -980.0, 30.7)
Config.RobberSpawn = vector3(2126.7, 4794.1, 41.1)

-- Bank Vaults
Config.BankVaults = {
    { location = vector3(150.0, -1040.0, 29.0), name = "Pacific Standard Bank", id = 1 },
    { location = vector3(-1212.0, -330.0, 37.8), name = "Fleeca Bank", id = 2 },
    { location = vector3(-2962.6, 482.9, 15.7), name = "Great Ocean Highway Bank", id = 3 },
    { location = vector3(1175.0, 2706.8, 38.1), name = "Route 68 Bank", id = 4 },
}

-- Police and Civilian Vehicles
Config.PoliceVehicles = { 'police', 'police2', 'police3', 'fbi', 'fbi2' }
Config.CivilianVehicles = { 'sultan', 'futo', 'blista', 'banshee', 'elegy2' }

-- Experience and Leveling System
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

-- Wanted Level System
Config.WantedLevels = {
    [1] = { stars = 1, description = "Minor Offenses" },
    [2] = { stars = 2, description = "Felony" },
    [3] = { stars = 3, description = "Serious Crime" },
    [4] = { stars = 4, description = "High Alert" },
    [5] = { stars = 5, description = "Most Wanted" },
}
