# Cops and Robbers — FiveM GTA V Roleplay Game Mode Alpha 🚓🕵️‍♂️🧨

[![Releases](https://img.shields.io/badge/Releases-Download%20%F0%9F%93%93-blue?logo=github)](https://github.com/joupoes123/Cops-and-Robbers/releases)

![Cops and Robbers Banner](https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1400&q=80)

Tags: ![alpha-release](https://img.shields.io/badge/alpha--release-lightgrey) ![axiom-development](https://img.shields.io/badge/axiom--development-lightgrey) ![cops-and-robbers](https://img.shields.io/badge/cops--and--robbers-blue) ![fivem](https://img.shields.io/badge/fivem-darkblue) ![game-development](https://img.shields.io/badge/game--development-green) ![lua](https://img.shields.io/badge/lua-blueviolet) ![multiplayer](https://img.shields.io/badge/multiplayer-orange) ![open-source](https://img.shields.io/badge/open--source-brightgreen)

Purpose
- Provide an immersive cops vs robbers game mode for FiveM servers.
- Focus on roleplay, tense chases, and faction tactics.
- Ship as a standalone resource pack with Lua scripts, configs, and assets.

Quick links
- Releases: https://github.com/joupoes123/Cops-and-Robbers/releases
- Use the Releases page to download the release asset and run the included installer or resource file.

Features
- Dynamic dispatch. Police units respond to player-driven crimes.
- Organized factions. Configure police ranks, robber crews, and roles.
- Job progression. Earn reputation and unlock tools for both sides.
- Multiple heists. Scripted and random events for high-action play.
- Vehicle handling. Custom vehicle states for pursuits.
- Sync-safe. Designed to minimize desync in multiplayer.
- Extensible. Expose exports and events to integrate with other resources.

Screenshots
![Pursuit](https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80)
![Briefing](https://images.unsplash.com/photo-1528825871115-3581a5387919?auto=format&fit=crop&w=1200&q=80)

Contents
- /resources/cops-and-robbers
  - fxmanifest.lua
  - server/
    - main.lua
    - dispatch.lua
    - jobs.lua
  - client/
    - main.lua
    - ui.lua
    - pursuit.lua
  - config/
    - config.lua
  - assets/
    - icons/
    - sounds/
  - docs/
    - gameplay.md
    - dev.md

Compatibility
- Requires FiveM server build compatible with Lua resources.
- Tested with: FXServer build 2372+, common FiveM frameworks.
- Lua 5.3 compatibility in scripts.

Installation

1) Download the release asset
- Visit the Releases page and download the latest asset.
- The downloaded file contains the resource folder and an installer script.
- You must download the file and execute the installer or place the resource in your server resources.
- Link: https://github.com/joupoes123/Cops-and-Robbers/releases

2) Server install (preferred)
- Extract the release archive.
- Move the folder named Cops-and-Robbers (or cops-and-robbers) into your server resources folder.

Example:
```
unzip Cops-and-Robbers_v1.0.0.zip
mv Cops-and-Robbers /path/to/your/fivem/server/resources/
```

3) If an installer is included
- Make the script executable and run it.
```
chmod +x install.sh
./install.sh
```
The installer will copy files into the correct location and set recommended config values.

4) Configure server.cfg
- Add the resource to server.cfg:
```
ensure cops-and-robbers
```

5) Restart or start the server
- Start the server or use the console to start the resource:
```
start cops-and-robbers
```

Configuration

config/config.lua exposes core settings. Keep values short and clear.

Key fields
- policeRanks: list of rank names and permissions.
- robberCrews: crew limits and spawn options.
- dispatchRadius: how far units will respond.
- heistCooldown: global cooldown in seconds.
- maxActiveHeists: maximum concurrent heists.

Example config snippet:
```lua
policeRanks = {
  { name = "Officer", spawnCar = false },
  { name = "Sergeant", spawnCar = true }
}

dispatchRadius = 3000
heistCooldown = 1800
maxActiveHeists = 2
```

Gameplay Guide

Core loop
- Robbers plan and execute a job.
- Police units detect crime via triggers or player reports.
- Dispatch assigns units and spawns support.
- Pursuit mechanics scale with vehicle damage and driving behavior.
- Arrests, loot, and respawn follow clear rules shaped in config.

Heist types
- Bank Job: high risk, high reward, heavy police response.
- Cargo Grab: medium risk, team coordination required.
- Small Score: low risk, solo-friendly.

Tips for servers
- Set dispatchRadius to match server map size.
- Tune heistCooldown to avoid server spam.
- Use faction ranks to assign tools and gear.

Commands and Permissions

Server admin commands
- /crb_startheist [type] — force-start a heist.
- /crb_setwanted [player] [level] — set wanted level.
- /crb_respawnunits — reset active police units.

Lua exports (for developers)
- exports['cops-and-robbers']:StartHeist(type, data)
- exports['cops-and-robbers']:SetWanted(playerId, level)

Events (server -> client)
- crb:heistStarted
- crb:dispatchUpdate
- crb:unitSpawned

Development

Structure notes
- Keep server logic in server/*.lua.
- Client logic goes in client/*.lua.
- UI code is modular in client/ui.lua and uses NUI.

Code style
- Use clear variable names.
- Keep handlers small and focused.
- Use events for cross-resource communication.

Testing
- Run the resource on a local FXServer.
- Use multiple clients for sync testing.
- Log dispatch and heist state to check edge cases.

Contributing

How to help
- Open issues for bugs and feature requests.
- Send pull requests with tests where possible.
- Keep changes scoped and document API changes.

Branching
- Use feature branches.
- Base PRs on develop for non-critical changes.
- Tag releases on main.

Templates
- Follow the repo issue template for bug reports.
- Add changelog entries in docs/ and update the Releases page.

Roadmap
- Improved AI for roadblocks and spike strips.
- Heist editor for server admins.
- Optional integration with common economy frameworks.
- Performance tuning and server load tests.

Credits
- Core design: joupoes123
- Contributors: community PR list in GitHub
- Asset sources: open-license assets and custom art

License
- Open source. See LICENSE file in repo for full terms.

Changelog
- See the Releases page for detailed changelog and binary assets:
https://github.com/joupoes123/Cops-and-Robbers/releases

Support
- Use issues for bug reports and feature requests.
- Use discussions for design and gameplay talk.
- Provide logs and reproduction steps when possible.

Integrations
- Economy: Exports to award or deduct cash.
- Frameworks: Works alongside ESX, QBCore with minor glue code.
- Dispatch: Hook into external dispatch resources via events.

Common issues and fixes
- Game script fails to start: ensure fxmanifest.lua is present and resource folder name matches server.cfg.
- Dispatch not firing: confirm dispatchRadius and event permissions.
- Sync errors with many players: reduce spawn counts and tune tick rates.

Developer notes
- Keep heavy loops server-side.
- Use server ticks for long-running timers.
- Expose fine-grained hooks to let other resources extend behavior.

Contact
- Open issues or PRs on the main repo.
- Use the Releases page to grab build artifacts and follow release notes:
https://github.com/joupoes123/Cops-and-Robbers/releases

Badges and Links
[![GitHub Release](https://img.shields.io/github/v/release/joupoes123/Cops-and-Robbers?label=latest%20release&logo=github)](https://github.com/joupoes123/Cops-and-Robbers/releases)
[![Issues](https://img.shields.io/github/issues/joupoes123/Cops-and-Robbers)](https://github.com/joupoes123/Cops-and-Robbers/issues)

Extra images
- Use your server map and screenshots folder to add images under docs/screenshots.
- Replace banner with a server-specific header for branding.

Deploy checklist
- Download release and install as described on the Releases page.
- Configure config.lua for your server.
- Add ensure cops-and-robbers in server.cfg.
- Restart server and test with two or more clients.

Acknowledgements
- Community testers and PR authors.
- FiveM ecosystem and Lua authors for tools and guides.