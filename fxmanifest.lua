fx_version 'cerulean'
game 'gta5'

name 'Cops and Robbers - Enhanced'
description 'An immersive Cops and Robbers game mode with advanced features and administrative control'
author 'Indominus'
version '2.0'

shared_scripts {
    'config.lua'
}

server_scripts {
    'server.lua',
    'admin.lua'
}

client_scripts {
    'client.lua'
}

ui_page 'html/main_ui.html'  -- Consolidated NUI page

files {
    'html/store.html',
    'html/role_selection.html',
    'html/index.html',
    'html/styles.css',
    'html/scripts.js',
    'purchase_history.json',
    'player_data/*',  -- Include the player_data directory
    'bans.json'
}
