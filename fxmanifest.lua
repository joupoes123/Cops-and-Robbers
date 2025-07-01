fx_version 'cerulean'
game 'gta5'

name 'Cops and Robbers - Enhanced'
description 'An immersive Cops and Robbers game mode with advanced features and administrative control'
author 'The Axiom Collective'
version '1.2.0'

-- Define shared scripts, loaded first on both server and client.
shared_scripts {
    'config.lua'        -- Game mode configuration.
}

-- Define server-side scripts.
server_scripts {
    'safe_utils.lua',    -- Safe utility functions.
    'server.lua',       -- Core server logic.
    'admin.lua',         -- Admin commands and server-side admin functionalities.
    'inventory_server.lua',
    'character_editor_server.lua', -- Character editor server logic
    'progression_server.lua' -- Enhanced progression system server logic
}

-- Define client-side scripts.
client_scripts {
    'client.lua',        -- Core client logic and event handling.
    'inventory_client.lua',
    'character_editor_client.lua', -- Character editor client logic
    'progression_client.lua' -- Enhanced progression system client logic
}

-- Define the NUI page.
ui_page 'html/main_ui.html' -- Consolidated NUI page for role selection, store, admin panel, etc.

-- Define files to be included with the resource.
-- These files are accessible by the client and NUI.
files {
    'html/main_ui.html',     -- Main HTML file for the NUI.
    'html/styles.css',       -- CSS styles for the NUI.
    'html/scripts.js',       -- JavaScript for NUI interactions.
    'purchase_history.json', -- For dynamic pricing persistence (ensure write access for server).
    'player_data/*',         -- Wildcard for player save files (ensure server has write access to this conceptual path).
    'bans.json'
}

-- Declare resource dependencies.
dependencies {
}

export 'UpdateFullInventory'
export 'EquipInventoryWeapons'

-- Network events
server_export 'GetCharacterForRoleSelection'

-- Safe network events
server_events {
    'cnr:receiveCharacterForRole'
}
