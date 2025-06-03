fx_version 'cerulean'
game 'gta5'

name 'Cops and Robbers - Enhanced'
description 'An immersive Cops and Robbers game mode with advanced features and administrative control'
author 'Indominus'
version '2.0'

-- Define shared scripts, loaded first on both server and client.
shared_scripts {
    '@ox_lib/init.lua', -- ox_lib is used for various utilities (e.g., JSON handling, UI elements if any beyond custom NUI).
    'config.lua'        -- Game mode configuration.
}

-- Define server-side scripts.
server_scripts {
    'server.lua',       -- Core server logic.
    'admin.lua'         -- Admin commands and server-side admin functionalities.
}

-- Define client-side scripts.
client_scripts {
    'client.lua'        -- Core client logic and event handling.
}

-- Define the NUI page.
ui_page 'html/main_ui.html' -- Consolidated NUI page for role selection, store, admin panel, etc.

-- Define files to be included with the resource.
-- These files are accessible by the client and NUI.
files {
    'html/main_ui.html',     -- Main HTML file for the NUI.
    'html/styles.css',       -- CSS styles for the NUI.
    'html/scripts.js',       -- JavaScript for NUI interactions.
    'html/bounties.html',
    'html/bounties.css',
    'html/bounties.js',
    'purchase_history.json', -- For dynamic pricing persistence (ensure write access for server).
    'player_data/*',         -- Wildcard for player save files (ensure server has write access to this conceptual path).
    'bans.json'              -- For ban persistence (ensure write access for server).
    -- Note: ox_lib is included via shared_scripts and should be present as a separate resource dependency.
    -- Do not bundle ox_lib files directly here.
    -- Redundant/obsolete HTML files (e.g., store.html, role_selection.html, index.html) are assumed
    -- to be consolidated into main_ui.html.
}

-- Declare resource dependencies.
-- This ensures 'ox_lib' is started before this resource.
dependencies {
    'ox_lib'
}
