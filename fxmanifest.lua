fx_version 'cerulean'
game 'gta5'

name 'Cops and Robbers - Enhanced'
description 'An immersive Cops and Robbers game mode with advanced features and administrative control'
author 'Indominus'
version '2.0'

-- Define shared scripts, loaded first on both server and client.
shared_scripts {
    '@ox_lib/init.lua', -- Assuming ox_lib is used as per json.lua, though not explicitly stated for json
    'config.lua'
}

-- Define server-side scripts.
server_scripts {
    'server.lua',
    'admin.lua' -- admin.lua relies on server.lua for some event handling and Config.
}

-- Define client-side scripts.
client_scripts {
    'client.lua'
}

-- Define the NUI page.
ui_page 'html/main_ui.html'  -- Consolidated NUI page for role selection, store, etc.

-- Define files to be included with the resource.
files {
    'html/main_ui.html', -- NUI main page (if ui_page is not just an alias)
    'html/store.html', -- Specific HTML for store if not part of main_ui.html
    'html/role_selection.html', -- Specific HTML for role selection if not part of main_ui.html
    'html/index.html', -- Often a redirect or container, ensure it's needed if main_ui.html is the primary
    'html/styles.css',
    'html/scripts.js',
    'purchase_history.json', -- For dynamic pricing persistence
    'player_data/*',         -- Include all files in the player_data directory
    'bans.json'               -- For ban persistence
}
