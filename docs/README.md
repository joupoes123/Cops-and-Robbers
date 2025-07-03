# Cops & Robbers - FiveM GTA V Roleplay Game Mode

**IMPORTANT NOTE:** This game mode has undergone massive expansion and enhancement with the addition of comprehensive progression systems, advanced character customization, bounty mechanics, and numerous quality-of-life improvements. Version 1.2.0 represents a major milestone with 50-level progression, prestige system, challenge mechanics, seasonal events, and a complete character editor. The resource is production-ready with extensive testing and modular architecture for easy customization.

**Cops & Robbers** is an open-source game mode for FiveM, designed to provide an immersive GTA V roleplay experience focused on the thrilling interaction between law enforcement and criminal elements. This project invites community contributions, encouraging developers to collaborate on creating dynamic gameplay with high-stakes chases, heists, and investigations.

---

## Recent Updates & Major Features (July 2025)

### 🎯 Enhanced Progression System
- **50-Level Progression**: Comprehensive leveling system with role-specific rewards
- **Prestige System**: 10 prestige levels with exclusive titles and XP multipliers
- **Special Abilities**: Unlockable abilities like Smoke Bomb, Adrenaline Rush, Backup Call, and SWAT Tactics
- **Passive Perks**: Role-specific bonuses including faster lockpicking, improved arrests, and equipment discounts
- **Challenge System**: Daily and weekly challenges with bonus XP and cash rewards
- **Seasonal Events**: Limited-time events with double XP multipliers (Crime Wave, Law & Order, Double Trouble)
- **Progression Menu**: Press P to access comprehensive progression tracking and statistics

### 🎨 Advanced Character Editor System
- **Comprehensive Customization**: Full character appearance editor with face features, hair, makeup, and clothing
- **Role-Specific Uniforms**: Pre-designed uniforms for different police ranks and criminal styles
- **Multiple Character Slots**: Save and manage multiple character appearances
- **Real-time Preview**: Live preview of changes with advanced camera system
- **Uniform Presets**: Quick-select uniforms including Police Officer, SWAT, Detective, Street Criminal, and Heist Outfit
- **Character Editor Access**: Press F3 to open the character editor

### 🏆 Advanced Bounty System
- **Dynamic Bounty Placement**: Automatic bounties on high-wanted criminals
- **Bounty Board**: Interactive bounty tracking system for law enforcement
- **Escalating Rewards**: Higher bounties for more dangerous criminals
- **Cooldown System**: Prevents bounty spam with intelligent cooldown mechanics
- **Bounty Hunting**: Cops can claim bounties for successful arrests

### 🌍 Expanded World Features
- **Robber Hideouts**: Multiple safe house locations across the map
- **Heist Locations**: Diverse heist opportunities including banks, jewelry stores, and convenience stores
- **Contraband Dealers**: Black market vendors with exclusive criminal equipment
- **Enhanced Store System**: Multiple store types with role-specific access and fixed transaction system

### 🚔 Advanced Police Systems
- **K9 Unit System**: Deploy police dogs for tracking and apprehension
- **Speed Radar Gun**: Real-time speed detection with automatic fine system
- **Advanced Equipment**: Tactical gear, riot vehicles, and helicopter access
- **SWAT Operations**: High-level tactical abilities and equipment
- **Evidence Collection**: Crime scene investigation mechanics

### 🔫 Enhanced Criminal Activities
- **Advanced Heist Tools**: EMP devices, thermite, C4 explosives, and hacking equipment
- **Power Grid Sabotage**: Large-scale infrastructure disruption
- **Armored Car Heists**: High-risk, high-reward criminal operations
- **Contraband System**: Smuggling operations with collection points
- **Criminal Network**: Black market access with level-based discounts

### 💻 Major Store System Overhaul
- **Fixed Buy/Sell Errors**: Resolved `SyntaxError: Unexpected end of JSON input` when purchasing or selling items
- **Implemented Missing NUI Callbacks**: Added `buyItem`, `sellItem`, and `getPlayerInventory` NUI callbacks
- **Enhanced Server Response System**: Server now sends proper JSON responses to NUI operations
- **Real-time Money Updates**: Player cash is immediately updated in UI after transactions
- **Success/Error Notifications**: Added toast notifications for transaction results
- **Auto-Refresh Inventory**: Sell tab automatically refreshes after successful transactions

### 🎮 Enhanced User Interface
- **Modern Progression UI**: Circular progress bars, animated notifications, and level-up celebrations
- **Improved Store Interfaces**: Fixed money/level display and responsive design
- **Character Editor UI**: Intuitive category-based customization interface
- **Bounty Board Interface**: Interactive bounty tracking and management
- **Enhanced HUD Elements**: Real-time XP tracking, ability cooldowns, and event notifications

### 🔧 Backend Improvements
- **Enhanced Error Handling**: Added comprehensive error checking throughout the codebase
- **Debug Logging System**: Extensive logging for client-server communication
- **Data Validation**: Improved validation for player data and inventory operations
- **Performance Optimization**: Optimized NUI communication and data processing
- **Modular Architecture**: Separated systems for better maintainability and extensibility

---

## Table of Contents

- [Key Features](#key-features)
- [Controls](#controls)
- [Progression System Overview](#progression-system-overview)
- [Character Customization](#character-customization)
- [Advanced Systems](#advanced-systems)
- [Installation](#installation)
- [Configuration](#configuration)
- [Development Branch Structure](#development-branch-structure)
- [Contributing](#contributing)
- [License](#license)

---

## Key Features

### Flexible Role System

- **Dynamic Role Selection**: Players can choose their role as **Cop** or **Robber** upon joining, enhancing engagement and player agency.
- **Role-Specific Abilities**:
  - **Cops**: Access to advanced equipment, vehicles, backup options, K9 units, and tactical abilities.
  - **Robbers**: Utilize heist tools, getaway vehicles, EMP devices, and criminal network connections.

### Enhanced Progression System

- **50-Level Progression**: Comprehensive leveling system with exponential XP requirements and meaningful rewards
- **Prestige System**: 10 prestige levels with exclusive titles, XP multipliers, and substantial cash rewards
- **Role-Specific XP Sources**: 
  - **Robbers**: Store robberies, bank heists, contraband collection, successful escapes, lockpicking, hacking
  - **Cops**: Arrests, speeding tickets, K9 assists, spike strip deployments, evidence collection
- **Level-Based Unlocks**: Weapons, vehicles, abilities, perks, and cash rewards at every level
- **Special Abilities**: Unlockable powers like Smoke Bomb, Adrenaline Rush, Backup Call, SWAT Tactics
- **Passive Perks**: Permanent bonuses including faster actions, equipment discounts, and enhanced capabilities

### Advanced Character Customization

- **Comprehensive Character Editor**: Full appearance customization with face features, hair, makeup, and clothing
- **Role-Specific Uniforms**: Pre-designed outfits for Police Officer, SWAT, Detective, Street Criminal, Heist Professional
- **Multiple Character Slots**: Save and manage different character appearances
- **Real-time Preview**: Live preview system with advanced camera controls
- **Persistent Customization**: Character appearances saved across sessions

### Challenge and Event System

- **Daily Challenges**: Role-specific objectives that reset every 24 hours with XP and cash rewards
- **Weekly Challenges**: Long-term goals with substantial rewards for completion
- **Seasonal Events**: Limited-time events with special bonuses (Crime Wave, Law & Order, Double Trouble)
- **Progress Tracking**: Visual indicators and notifications for challenge completion

### Advanced Bounty System

- **Dynamic Bounty Placement**: Automatic bounties on high-wanted criminals based on threat level
- **Interactive Bounty Board**: Cops can view, track, and claim bounties through dedicated interface
- **Escalating Rewards**: Higher bounties for more dangerous criminals with longer wanted histories
- **Bounty Hunting Mechanics**: Specialized rewards and XP for successful bounty captures

### Wanted Level System

- **Dynamic Wanted Levels**: Robbers accumulate wanted levels based on their actions, affecting NPC and player responses.
- **Escalating Challenges**: Higher wanted levels result in more aggressive law enforcement tactics.
- **Strategic Gameplay**: Manage your wanted level to balance risk and reward.
- **Bounty Integration**: High wanted levels trigger automatic bounty placement

### Jail System

- **Arrest Mechanics**: Cops can arrest robbers, sending them to jail for a set duration.
- **Jail Time Restrictions**: Limited capabilities while jailed, with a countdown until release.
- **Reintegration**: Released robbers have their wanted levels reset and can rejoin the action.

### Comprehensive Store System

- **Multiple Store Types**: 
  - **Gun Stores**: Purchase weapons and ammunition (Cop-only stores and civilian gun stores)
  - **Clothing Stores**: Buy and equip different clothing items
  - **Medical Stores**: Purchase healing items and medical supplies
  - **Tool Stores**: Buy specialized tools and equipment
- **Role-Specific Access**: Certain stores are restricted to specific roles (e.g., police equipment stores)
- **Interactive Interface**: Modern UI for browsing and purchasing items with fixed Buy/Sell functionality
- **Real-time Inventory Updates**: Purchased items are automatically added to player inventory
- **Fixed Transaction System**: Resolved all buy/sell errors and implemented proper server-client communication
- **Enhanced Money Display**: Accurate real-time money and level display in store interfaces
- **Toast Notifications**: Success/error messages for all store transactions
- **Auto-Refresh**: Store tabs automatically refresh after successful operations

### Enhanced Player Inventory System

- **Modern UI**: Features a sleek, category-based inventory interface accessible with the `M` key
- **Item Management**: View, equip, use, and drop items with intuitive controls
- **Categories**: Items are organized into Weapons, Medical, Tools, and Miscellaneous for easy navigation
- **Real-time Updates**: Inventory syncs in real-time between client and server
- **Item Effects**: Items have immediate effects when used (healing, armor, spike strips, etc.)
- **Fixed Sell Functionality**: Resolved array conversion errors and improved sell tab reliability
- **Debug System**: Comprehensive error tracking and logging for troubleshooting

### Enhanced User Interface (UI)

- **NUI-Based Menus**: Interactive role selection, inventory, store, character editor, and progression menus
- **Modern Design**: Clean, responsive interfaces with category-based navigation and smooth animations
- **Advanced HUD Elements**: Real-time XP tracking, ability cooldowns, seasonal event indicators, and progression bars
- **Visual Feedback**: Animated notifications for level-ups, unlocks, challenge completion, and achievements
- **Progression Menu**: Comprehensive interface (Press P) with overview, unlocks, abilities, challenges, and prestige tabs
- **Character Editor Interface**: Intuitive customization system with real-time preview and category organization
- **Bounty Board**: Interactive law enforcement interface for tracking and claiming bounties

### Banking and Heist System

- **Multiple Bank Locations**: Various bank locations across the map offer diverse heist opportunities.
- **Variable Difficulty**: Different banks present unique challenges and rewards.
- **Heist Mechanics**: Coordinated bank robberies with timers and security responses.

### Speed Radar System

- **Real-Time Speed Detection**: Police officers can use speed radar guns to measure vehicle speeds in real-time
- **Visual HUD Interface**: Color-coded speed display showing target speed, speed limit, and distance
- **Automatic Speeding Detection**: System automatically detects when vehicles exceed the 50 MPH speed limit
- **Progressive Fine System**: Base fines of $250 with additional penalties for excessive speeding
- **Equipment Requirements**: Requires Speed Radar Gun (available to Level 2+ cops for $500)
- **Officer Compensation**: Cops receive 50% commission on issued fines plus XP rewards
- **Range-Based Detection**: Effective up to 150 meters with precise raycast targeting

### Advanced Police Systems

- **K9 Unit System**: Deploy police dogs for tracking, detection, and suspect apprehension
- **Speed Radar Technology**: Real-time vehicle speed detection with automatic fine calculation
- **Tactical Equipment**: Access to riot gear, SWAT vehicles, helicopters, and specialized weapons
- **Evidence Collection**: Crime scene investigation mechanics with XP rewards
- **Backup Coordination**: Call for immediate backup assistance through special abilities
- **Advanced Arrest Mechanics**: Enhanced arrest system with subduing bonuses and K9 assistance

### Enhanced Criminal Operations

- **Advanced Heist Tools**: EMP devices, thermite charges, C4 explosives, and electronic hacking equipment
- **Power Grid Sabotage**: Large-scale infrastructure disruption for strategic advantages
- **Armored Car Heists**: High-risk operations with substantial rewards
- **Contraband Network**: Smuggling operations with collection points and black market access
- **Criminal Hideouts**: Safe house locations across the map for planning and regrouping
- **Stealth Mechanics**: Advanced evasion techniques and detection avoidance systems

### World Expansion Features

- **Multiple Heist Locations**: Banks, jewelry stores, convenience stores, and armored car routes
- **Robber Hideouts**: Strategic safe house locations including Sandy Shores, Desert, and Vespucci hideouts
- **Contraband Dealers**: Black market vendors with exclusive criminal equipment and weapons
- **Enhanced Store Network**: Expanded store system with role-specific access and specialized equipment

### Administrative Tools

- **Expanded Admin Commands**: Comprehensive commands for server management, including player moderation and resource control
- **Real-Time Monitoring**: Freeze/unfreeze actions, teleport, and advanced player management
- **Player Management**: Adjust player roles, cash balances, experience, inventory items, and progression data
- **Ban System**: Persistent ban management with JSON storage
- **Progression Management**: Admin commands for XP adjustment, level setting, and event management
- **Event Control**: Start and manage seasonal events with server-wide effects

### Customizable Assets & Scripts

- **Modify Game Elements**: Tailor vehicles, weapons, uniforms, and abilities to fit your community's vision.
- **Standalone Design**: Designed as a standalone resource. While integration with other mods is possible, core functionality does not rely on external frameworks like ESX or QBCore.
- **Safe Utilities**: Built-in utilities for secure data handling and player management.

---

## Controls

**Quick Reference**: M: Open Inventory | E: Interact | LEFT ALT: Police Radar | H: Fine Driver | G: Deploy Spikes | K: Toggle K9 | F1: EMP Device | F2: Admin Panel | F3: Character Editor | P: Progression Menu

### General Controls

- **F5**: Toggle role selection menu (choose between Cop and Robber)
- **M**: Open/close player inventory
- **E**: Interact with stores and other interactive elements
- **H**: Toggle HUD display
- **F6**: Open admin menu (admin only)
- **F3**: Open character editor
- **P**: Open progression menu (levels, challenges, abilities)
- **Z**: Use special ability slot 1 (when unlocked)
- **X**: Use special ability slot 2 (when unlocked)

### Cop-Specific Controls

- **F1**: Access cop menu (spawn vehicles, equipment, etc.)
- **F2**: Admin panel (admin only)
- **F7**: Toggle bounty board
- **G**: Deploy spike strips / Cuff/uncuff nearby player
- **K**: Toggle K9 unit
- **E**: Command K9 attack (when K9 is active)
- **LEFT ALT**: Toggle speed radar (requires Speed Radar Gun)
- **H**: Issue speeding fine (when speeding detected)
- **PageUp**: Alternative speed radar toggle
- **Home**: Alternative spike strip deployment

### Robber-Specific Controls

- **F2**: Access robber menu (heist options, getaway vehicles, etc.)
- **F1**: Activate EMP Device (when equipped)
- **Numpad 0**: Alternative EMP activation
- **E**: Tackle/subdue (interaction key)

### Progression System Controls

- **P**: Open progression menu
- **Z**: Activate special ability 1 (role-specific abilities like Smoke Bomb, Backup Call)
- **X**: Activate special ability 2 (advanced abilities unlocked at higher levels)

### Character Editor Controls

- **F3**: Open character editor
- **Mouse**: Navigate categories and adjust sliders
- **Left Click**: Select options and confirm changes
- **Right Click**: Reset to default (in some contexts)
- **ESC**: Exit character editor

### Inventory Controls

- **Left Click**: Select item
- **Right Click**: Use/equip item
- **Drop Button**: Drop selected item
- **Category Tabs**: Navigate between Weapons, Medical, Tools, and Miscellaneous items

### Store Controls

- **Left Click**: Select item to purchase
- **Purchase Button**: Buy selected item
- **Category Navigation**: Browse different item categories
- **Close Button (X)**: Exit store interface

### Bounty System Controls (Cops)

- **F7**: Toggle bounty board
- **Left Click**: Select bounty target
- **Track Button**: Set waypoint to bounty location

---

## Progression System Overview

The Enhanced Progression System is the heart of the Cops and Robbers experience, providing meaningful advancement and rewards for both roles.

### Core Progression Features

- **50 Levels of Progression**: Each level requires increasing XP and unlocks valuable rewards
- **Role-Specific XP Sources**: Different activities reward XP based on your chosen role
- **Comprehensive Unlocks**: Each level provides items, abilities, perks, vehicles, or cash rewards
- **Special Abilities**: Unlock powerful abilities like Smoke Bomb, Adrenaline Rush, Backup Call, and SWAT Tactics
- **Passive Perks**: Permanent bonuses that enhance your gameplay experience

### Prestige System

- **10 Prestige Levels**: Extended progression for dedicated players
- **Exclusive Titles**: From "Veteran" to "Supreme" with increasing prestige
- **XP Multipliers**: Boost your progression speed with each prestige level
- **Substantial Rewards**: Cash bonuses ranging from $100,000 to $5,000,000

### Challenge System

- **Daily Challenges**: Reset every 24 hours with role-specific objectives
- **Weekly Challenges**: Long-term goals with substantial rewards
- **Progress Tracking**: Visual indicators and completion notifications
- **Bonus Rewards**: Extra XP and cash for completing challenges

### Seasonal Events

- **Crime Wave**: Double XP for all robber activities
- **Law & Order**: Double XP for all police activities  
- **Double Trouble**: Double XP for everyone during special events

*For detailed progression information, see [PROGRESSION_SYSTEM.md](PROGRESSION_SYSTEM.md)*

---

## Character Customization

The Advanced Character Editor provides comprehensive customization options for creating unique characters.

### Character Editor Features

- **Full Appearance Customization**: Face features, hair, makeup, clothing, and accessories
- **Real-time Preview**: See changes instantly with advanced camera system
- **Multiple Character Slots**: Save different character appearances for various situations
- **Role-Specific Uniforms**: Quick-select presets for different roles and ranks

### Available Customization Options

#### Appearance Categories
- **Face Features**: Nose, eyebrows, cheeks, eyes, lips, jaw, and chin adjustments
- **Hair & Styling**: Multiple hairstyles with color and highlight options
- **Makeup & Details**: Blush, lipstick, makeup, aging, complexion, and freckles
- **Body Features**: Chest hair, body blemishes, moles, and other details

#### Uniform Presets

**Police Uniforms:**
- **Police Officer**: Standard patrol uniform with badge and equipment
- **SWAT Officer**: Tactical response gear with helmet and armor
- **Detective**: Plain clothes professional attire

**Criminal Outfits:**
- **Street Criminal**: Casual street wear for blending in
- **Heist Outfit**: Professional criminal attire for major operations
- **Casual Civilian**: Blend in with the general population

### Character Editor Access

- **Press F3** to open the character editor from anywhere in the game
- **Interior Location**: Safe editing environment without interruption
- **Save System**: Persistent character data across sessions

---

## Advanced Systems

### Bounty System

The dynamic bounty system creates additional objectives for law enforcement and consequences for criminal activity.

#### How Bounties Work
- **Automatic Placement**: Bounties are automatically placed on criminals with 2+ wanted stars
- **Escalating Rewards**: Higher wanted levels result in larger bounties
- **Time Limits**: Bounties expire after 30 minutes if not claimed
- **Cooldown System**: Prevents bounty spam with intelligent cooldowns

#### Bounty Board Interface
- **F7 Key**: Opens the bounty board for law enforcement
- **Target Information**: View criminal details, wanted level, and last known location
- **Tracking System**: Set waypoints to bounty locations
- **Claim Rewards**: Receive payment and XP for successful captures

### K9 Unit System

Police officers can deploy K9 units for enhanced law enforcement capabilities.

#### K9 Features
- **K Key**: Toggle K9 unit deployment
- **Tracking Abilities**: K9 units can track suspects and detect contraband
- **Attack Commands**: Direct K9 attacks on suspects (E key when active)
- **Arrest Assistance**: K9 assists provide bonus XP for arrests

### Advanced Criminal Tools

Robbers have access to sophisticated equipment for complex operations.

#### High-Tech Equipment
- **EMP Devices**: Disable police vehicles and electronics
- **Thermite Charges**: Breach reinforced doors and safes
- **C4 Explosives**: Demolition charges for major heists
- **Hacking Devices**: Bypass electronic security systems
- **Advanced Lockpicks**: Faster and more reliable lock bypassing

#### Criminal Network
- **Black Market Access**: Exclusive vendors with restricted items
- **Contraband System**: Smuggling operations with collection points
- **Hideout Network**: Safe houses across the map for planning and regrouping

---

## Feature Overview

### Complete Feature Matrix

| Feature Category | Features | Status |
|-----------------|----------|---------|
| **Progression System** | 50-Level Progression, Prestige System, Special Abilities, Passive Perks | ✅ Complete |
| **Character System** | Advanced Character Editor, Multiple Slots, Uniform Presets | ✅ Complete |
| **Challenge System** | Daily/Weekly Challenges, Seasonal Events, Progress Tracking | ✅ Complete |
| **Bounty System** | Dynamic Bounties, Bounty Board, Escalating Rewards | ✅ Complete |
| **Police Systems** | K9 Units, Speed Radar, SWAT Operations, Evidence Collection | ✅ Complete |
| **Criminal Systems** | Advanced Heists, EMP Devices, Power Grid Sabotage, Contraband | ✅ Complete |
| **Store System** | Multiple Store Types, Fixed Transactions, Real-time Updates | ✅ Complete |
| **Inventory System** | Category-based UI, Item Effects, Sell Functionality | ✅ Complete |
| **World Features** | Hideouts, Heist Locations, Contraband Dealers | ✅ Complete |
| **UI/UX** | Modern Interfaces, Animations, Real-time Feedback | ✅ Complete |
| **Admin Tools** | Comprehensive Commands, Event Management, Player Control | ✅ Complete |
| **Performance** | Optimized Code, Error Handling, Debug Systems | ✅ Complete |

### Role-Specific Features

#### 👮 Police Officer Features
- **Equipment Access**: Weapons, vehicles, tactical gear unlocked by level
- **K9 Unit System**: Deploy police dogs for tracking and apprehension
- **Speed Radar Gun**: Real-time speed detection with automatic fines
- **Bounty Hunting**: Track and capture wanted criminals for rewards
- **Special Abilities**: Backup Call, Tactical Scan, SWAT Tactics, Detective Mode
- **Progression Rewards**: Police vehicles, helicopters, tanks, and federal authority
- **Evidence Collection**: Crime scene investigation with XP rewards

#### 🔫 Criminal Features  
- **Advanced Heist Tools**: EMP devices, thermite, C4, hacking equipment
- **Criminal Network**: Black market access with level-based discounts
- **Power Grid Sabotage**: Large-scale infrastructure disruption
- **Special Abilities**: Smoke Bomb, Adrenaline Rush, Ghost Mode, Master Escape
- **Hideout System**: Safe houses across the map for planning operations
- **Contraband Operations**: Smuggling with collection points and dealers
- **Progression Rewards**: Advanced weapons, criminal empire access, legendary status

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **FiveM Build** | 2372+ | 2944+ |
| **Server RAM** | 1GB | 2GB+ |
| **Storage** | 50MB | 100MB |
| **Players** | 1-32 | 32-64 |
| **Dependencies** | None | None |

---

## Installation

1. **Clone or Download the Repository**:

   ```bash
   git clone https://github.com/Indom-hub/Cops-and-Robbers.git
   ```

2. **Add the Resource to Your Server**:

   - Copy the `Cops-and-Robbers` folder to your server’s `resources` directory.

3. **Update the `server.cfg`**:

   - Add the following line to your `server.cfg` file:

     ```
     start Cops-and-Robbers
     ```

4. **Install Dependencies**:

   - **Standalone**: This resource is completely standalone and does not require external dependencies like `ox_inventory`, `ox_lib`, or specific frameworks (ESX/QBCore)
   - **FiveM Requirements**: Ensure your FiveM server is running the latest version (recommended: build 2944 or higher)
   - **Server Resources**: Minimum 2GB RAM recommended for optimal performance with all features
   - **Database**: No external database required - uses JSON file storage for persistence

5. **Restart the Server**:

   - Restart or launch your server to initialize the resource.

### Quick Start Guide

Once installed, here's how to get started:

1. **Join the Server**: Connect to your FiveM server
2. **Select Role**: Press F5 to choose between Cop or Robber
3. **Character Creation**: Press F3 to customize your character appearance
4. **Learn Controls**: Review the controls section above for key bindings
5. **Start Playing**: Begin earning XP through role-specific activities
6. **Check Progress**: Press P to view your progression, challenges, and abilities
7. **Explore Features**: Visit stores, try heists, or patrol as a cop

### First Steps by Role

#### As a Police Officer:
1. Spawn at the police station
2. Purchase basic equipment from the police armory
3. Start patrolling and issuing speeding tickets (H key with radar gun)
4. Look for criminal activity and make arrests
5. Unlock K9 units and advanced equipment as you level up

#### As a Robber:
1. Spawn at your designated location
2. Start with small store robberies to earn money and XP
3. Purchase better equipment from black market dealers
4. Plan larger heists as you unlock advanced tools
5. Use hideouts to plan operations and avoid police

### File Structure

```
Cops-and-Robbers/
├── fxmanifest.lua              # Resource manifest
├── config.lua                  # Main configuration file (enhanced with new systems)
├── server.lua                  # Core server logic
├── client.lua                  # Core client logic
├── admin.lua                   # Administrative commands
├── inventory_server.lua        # Server-side inventory system
├── inventory_client.lua        # Client-side inventory system
├── progression_server.lua      # Enhanced progression system server logic
├── progression_client.lua      # Enhanced progression system client logic
├── character_editor_server.lua # Character editor server logic
├── character_editor_client.lua # Character editor client logic
├── safe_utils.lua              # Security utilities
├── bans.json                   # Ban storage
├── purchase_history.json       # Purchase tracking
├── html/
│   ├── main_ui.html           # Main UI interface (enhanced with new systems)
│   ├── styles.css             # UI styling (updated with progression and character editor)
│   └── scripts.js             # UI JavaScript logic (enhanced functionality)
├── player_data/               # Player data storage (includes character and progression data)
└── docs/                      # Documentation
    ├── README.md              # This comprehensive guide
    ├── PROGRESSION_SYSTEM.md  # Detailed progression system documentation
    ├── CNR_Guide.md           # Complete gameplay guide
    ├── CONTRIBUTING.md        # Contribution guidelines
    ├── CODE_OF_CONDUCT.md     # Community guidelines
    ├── SECURITY.md            # Security information
    └── LICENSE                # License information
```

---

## Configuration

Customize the gameplay experience by editing the configuration options in `config.lua`.

### General Settings

- **Max Players**: Set the maximum number of players (`Config.MaxPlayers`)
- **Heist Cooldown**: Adjust the cooldown time between heists (`Config.HeistCooldown`)
- **Spawn Locations**: Define spawn points for cops, robbers, and citizens (`Config.SpawnPoints`)
- **Debug Logging**: Enable detailed logging for troubleshooting (`Config.DebugLogging`)
- **Starting Money**: Configure default cash for new players (`Config.DefaultStartMoney`)

### Enhanced Progression System

- **XP Table**: Customize XP requirements for each level (1-50) in `Config.XPTable`
- **Max Level**: Set the maximum attainable level (`Config.MaxLevel`)
- **Role-Specific XP**: Configure XP rewards for different actions in `Config.XPActionsCop` and `Config.XPActionsRobber`
- **Level Unlocks**: Define rewards, items, abilities, and perks for each level in `Config.LevelUnlocks`

### Prestige System

- **Prestige Configuration**: Enable/disable prestige system (`Config.PrestigeSystem.enabled`)
- **Max Prestige Levels**: Set maximum prestige levels (`Config.PrestigeSystem.maxPrestige`)
- **Prestige Requirements**: Level required to prestige (`Config.PrestigeSystem.levelRequiredForPrestige`)
- **Prestige Rewards**: Configure cash rewards, titles, and XP multipliers for each prestige level

### Challenge System

- **Daily Challenges**: Configure role-specific daily objectives in `Config.ChallengeSystem.dailyChallenges`
- **Weekly Challenges**: Set up long-term challenges in `Config.ChallengeSystem.weeklyChallenges`
- **Challenge Rewards**: Customize XP and cash rewards for challenge completion
- **Challenge Targets**: Adjust completion requirements for different challenge types

### Seasonal Events

- **Event Configuration**: Enable/disable seasonal events (`Config.SeasonalEvents.enabled`)
- **Event Types**: Configure different events (Crime Wave, Law & Order, Double Trouble)
- **Event Duration**: Set how long events last in seconds
- **Event Effects**: Configure XP multipliers and role-specific bonuses

### Character Editor System

- **Editor Location**: Set the character editor interior location (`Config.CharacterEditor.editorLocation`)
- **Default Character**: Configure default appearance settings (`Config.CharacterEditor.defaultCharacter`)
- **Uniform Presets**: Define role-specific uniform presets for quick selection
- **Customization Options**: Configure available face features, clothing, and appearance options

### Inventory System

- **Items Configuration**: All items are defined in `Config.Items` with properties like:
  - **Type**: Category (weapon, medical, tool, misc)
  - **Label**: Display name
  - **Description**: Item description
  - **Price**: Store price
  - **Level Requirement**: Minimum level to purchase
  - **Effect**: What happens when used
  - **Consumable**: Whether item is consumed on use
- **Starting Items**: Configure default items for new players in `Config.StartingItems`

### Store System

- **Store Locations**: Define store coordinates and types in `Config.Stores`
- **Store Categories**: Configure what items each store type sells
- **Role Restrictions**: Set which roles can access specific stores
- **NPC Vendors**: Configure black market dealers and their locations (`Config.NPCVendors`)
- **Store Types Available**:
  - `gunstore`: Weapon and ammunition sales
  - `clothing`: Clothing and uniform items
  - `medical`: Healing items and medical supplies
  - `tools`: Equipment and specialized tools
  - `police_armory`: Restricted police equipment

### World Locations

- **Bank Vaults**: Configure multiple bank locations with coordinates, names, and IDs (`Config.BankVaults`)
- **Robber Hideouts**: Set safe house locations (`Config.RobberHideouts`)
- **Heist Locations**: Define various heist opportunities (`Config.HeistLocations`)
- **Contraband Dealers**: Configure black market vendor locations (`Config.ContrabandDealers`)

### Bounty System

- **Bounty Settings**: Configure bounty mechanics in `Config.BountySettings`
- **Wanted Level Threshold**: Minimum wanted level to trigger bounties
- **Bounty Amounts**: Base amount and multipliers for bounty calculations
- **Bounty Duration**: How long bounties remain active
- **Cooldown System**: Prevent bounty spam with intelligent cooldowns

### Speed Radar System

- **Speed Limit**: Configure the speed limit in MPH (`Config.SpeedLimitMph` - default: 50 MPH)
- **Fine Amount**: Set the base fine amount for speeding violations (`Config.SpeedingFine` - default: $250)
- **Keybinds**: Customize radar toggle and fine issuance keys in `Config.Keybinds`
- **XP Rewards**: Configure XP rewards for issuing speeding tickets
- **Equipment**: Speed Radar Gun availability and pricing configured in `Config.Items`

### Keybind Configuration

- **Custom Keybinds**: All keybinds are configurable in `Config.Keybinds`
- **Control Mapping**: Use FiveM control IDs for precise key mapping
- **Role-Specific Keys**: Separate keybinds for cop and robber specific actions
- **Special Abilities**: Configure keys for progression system abilities

### Wanted Level System

- **Dynamic Wanted Levels**: Configure how wanted levels are gained and lost
- **Escalation Mechanics**: Set thresholds for increased law enforcement response
- **Wanted Level Effects**: Configure NPC and player behavior based on wanted status
- **Corruption System**: Allow players to reduce wanted levels through bribery

### Administrative Commands

The game mode includes comprehensive admin commands for server management:

#### Player Management Commands
- `/give_xp <player_id> <amount> [reason]` - Award XP to players
- `/set_level <player_id> <level>` - Directly set player levels
- `/give_money <player_id> <amount>` - Give money to players
- `/set_role <player_id> <role>` - Change player roles
- `/reset_player <player_id>` - Reset player progression data

#### Event Management Commands
- `/start_event <event_name>` - Start seasonal events
- `/stop_event` - End current seasonal event
- `/event_status` - Check active event information

#### Server Management Commands
- `/freeze <player_id>` - Freeze/unfreeze players
- `/teleport <player_id> [target_player]` - Teleport players
- `/ban <player_id> <reason>` - Ban players with persistent storage
- `/unban <player_id>` - Remove player bans

#### Progression Management
- `/prestige <player_id>` - Force prestige a player
- `/reset_challenges <player_id>` - Reset daily/weekly challenges
- `/unlock_ability <player_id> <ability_id>` - Unlock specific abilities

### Debug and Development

- **Debug Logging**: Enable comprehensive logging with `Config.DebugLogging = true`
- **Console Commands**: Various debug commands for testing and troubleshooting
- **Error Handling**: Robust error handling with detailed error messages
- **Performance Monitoring**: Built-in performance tracking for optimization

---

## Advanced Gameplay Mechanics

### Heist System

The enhanced heist system provides multiple types of criminal activities with varying difficulty and rewards.

#### Bank Heists
- **Multiple Locations**: Pacific Standard, Fleeca Banks, and Blaine County Savings
- **Variable Difficulty**: Different security levels and police response times
- **Team Coordination**: Multi-player heist mechanics for complex operations
- **Advanced Tools Required**: Thermite, hacking devices, and drilling equipment

#### Store Robberies
- **Convenience Stores**: Quick, low-risk operations for starting criminals
- **Jewelry Stores**: High-value targets with increased security
- **Ammu-Nation Heists**: Weapon store robberies with specialized equipment
- **Escalating Difficulty**: Security increases based on recent criminal activity

#### Armored Car Heists
- **Mobile Targets**: Intercept armored vehicles during transport
- **High Rewards**: Substantial cash payouts for successful operations
- **Advanced Planning**: Requires coordination and specialized equipment
- **Police Response**: Immediate and aggressive law enforcement reaction

### Law Enforcement Operations

#### Patrol Mechanics
- **Patrol Routes**: Defined patrol areas with XP rewards for completion
- **Random Events**: Dynamic crime scenes and emergency calls
- **Traffic Enforcement**: Speed radar operations and traffic stops
- **Community Policing**: Interaction with civilian NPCs and players

#### Investigation System
- **Crime Scene Analysis**: Collect evidence at robbery and heist locations
- **Suspect Tracking**: Use K9 units and forensic evidence to track criminals
- **Witness Interviews**: Gather information from NPC witnesses
- **Case Building**: Accumulate evidence for enhanced arrest rewards

#### Tactical Operations
- **SWAT Deployment**: High-level tactical response for major crimes
- **Helicopter Support**: Air units for pursuit and surveillance
- **Roadblock Setup**: Coordinate multi-unit operations
- **Siege Mechanics**: Surround and apprehend barricaded suspects

### Economic System

#### Dynamic Pricing
- **Market Fluctuation**: Item prices change based on supply and demand
- **Criminal Activity Impact**: High crime rates affect store prices
- **Seasonal Adjustments**: Special pricing during events
- **Level-Based Discounts**: Higher levels unlock better prices

#### Money Management
- **Multiple Income Sources**: Legitimate and illegitimate earning methods
- **Investment Opportunities**: Long-term financial planning options
- **Risk vs. Reward**: Higher-risk activities provide better payouts
- **Economic Balance**: Carefully tuned economy to maintain gameplay balance

---

## Technical Implementation

### Performance Optimization

- **Efficient Resource Usage**: Optimized scripts for minimal server impact
- **Smart Caching**: Reduced database queries through intelligent caching
- **Asynchronous Operations**: Non-blocking operations for smooth gameplay
- **Memory Management**: Proper cleanup and garbage collection

### Security Features

- **Anti-Cheat Integration**: Built-in protection against common exploits
- **Input Validation**: Comprehensive validation of all user inputs
- **Rate Limiting**: Protection against spam and abuse
- **Secure Data Storage**: Encrypted storage of sensitive player data

### Modular Architecture

- **Separated Systems**: Independent modules for easy maintenance
- **Plugin Support**: Framework for adding custom extensions
- **Configuration Flexibility**: Extensive customization options
- **API Exports**: Functions available for other resources

### Database Integration

- **Player Data Persistence**: Comprehensive player data storage
- **Character Profiles**: Multiple character support per player
- **Progression Tracking**: Detailed statistics and achievement tracking
- **Backup Systems**: Automated data backup and recovery

---

## Community Features

### Social Systems

- **Crew Formation**: Players can form criminal organizations or police units
- **Reputation System**: Build reputation within your chosen role
- **Leaderboards**: Compete for top positions in various categories
- **Achievement System**: Unlock achievements for special accomplishments

### Communication Tools

- **Role-Specific Chat**: Separate communication channels for cops and robbers
- **Radio Systems**: Realistic radio communication for law enforcement
- **Anonymous Tips**: Citizens can report criminal activity
- **Broadcast System**: Server-wide announcements and alerts

### Event System

- **Scheduled Events**: Regular community events with special rewards
- **Tournament Mode**: Competitive gameplay with brackets and prizes
- **Special Operations**: Large-scale coordinated missions
- **Community Challenges**: Server-wide objectives requiring cooperation

---

## Troubleshooting and Support

### Common Issues

#### Performance Issues
- **Low FPS**: Reduce visual settings and check for conflicting resources
- **Server Lag**: Monitor server performance and optimize configuration
- **Memory Leaks**: Restart resource periodically if experiencing issues

#### Gameplay Issues
- **XP Not Updating**: Check server console for errors and restart resource
- **UI Not Responding**: Clear browser cache and restart FiveM
- **Character Editor Problems**: Ensure proper permissions and resource loading

#### Configuration Issues
- **Items Not Unlocking**: Verify level requirements and configuration syntax
- **Store Problems**: Check store locations and item configurations
- **Keybind Conflicts**: Review keybind assignments for conflicts

### Debug Tools

- **Console Commands**: Use debug commands to troubleshoot issues
- **Log Analysis**: Review server and client logs for error patterns
- **Performance Monitoring**: Track resource usage and optimization opportunities
- **Community Support**: Active community forums and Discord support

### Getting Help

- **Documentation**: Comprehensive guides and API documentation
- **Community Forums**: Active community with helpful members
- **Issue Reporting**: GitHub issue tracker for bug reports and feature requests
- **Developer Support**: Direct contact with development team for critical issues

---

## Future Development

### Planned Features

#### Short-term Roadmap
- **Gang System**: Organized criminal groups with territories
- **Property System**: Purchasable properties and businesses
- **Vehicle Customization**: Enhanced vehicle modification system
- **Weather Integration**: Dynamic weather affecting gameplay

#### Long-term Vision
- **Multi-Server Support**: Cross-server progression and events
- **Mobile App Integration**: Companion app for progression tracking
- **VR Support**: Virtual reality compatibility for immersive gameplay
- **AI Enhancement**: Advanced NPC behavior and interactions

### Community Contributions

- **Open Source Development**: Community-driven feature development
- **Plugin Ecosystem**: Third-party extensions and modifications
- **Translation Support**: Multi-language support for global communities
- **Content Creation**: Community-created maps, missions, and events

---

## Version History & Changelog

### Version 1.2.0 (July 2025) - Major Feature Release
**🎯 Enhanced Progression System**
- Added 50-level progression system with role-specific rewards
- Implemented 10-level prestige system with exclusive titles and multipliers
- Created comprehensive challenge system with daily and weekly objectives
- Added seasonal events with server-wide XP bonuses

**🎨 Advanced Character Editor**
- Complete character customization system with real-time preview
- Multiple character slots for different appearances
- Role-specific uniform presets for quick selection
- Advanced camera system for detailed character editing

**🏆 Bounty System**
- Dynamic bounty placement on high-wanted criminals
- Interactive bounty board for law enforcement
- Escalating rewards based on criminal threat level
- Intelligent cooldown system to prevent abuse

**🚔 Enhanced Police Systems**
- K9 unit deployment with tracking and attack capabilities
- Speed radar gun with real-time detection and automatic fines
- Advanced tactical equipment and vehicle unlocks
- Evidence collection system with XP rewards

**🔫 Advanced Criminal Operations**
- EMP devices for disabling police electronics
- Power grid sabotage for large-scale disruption
- Enhanced heist tools including thermite and C4
- Contraband network with smuggling operations

**💻 Technical Improvements**
- Complete store system overhaul with fixed transactions
- Enhanced UI with modern animations and real-time feedback
- Comprehensive error handling and debug systems
- Modular architecture for better maintainability

### Version 1.1.0 (June 2025) - Stability & Bug Fixes
- Fixed major store system errors and transaction issues
- Resolved inventory management problems
- Enhanced UI consistency and responsiveness
- Improved server-client communication
- Added comprehensive debug logging

### Version 1.0.0 (Initial Release)
- Basic cops and robbers gameplay
- Simple progression system
- Store and inventory mechanics
- Admin tools and commands
- Standalone resource architecture

---

## Contributing

We welcome contributions from the community! Here's how you can help improve Cops and Robbers:

### Ways to Contribute

1. **Bug Reports**: Report issues through GitHub Issues with detailed information
2. **Feature Requests**: Suggest new features or improvements
3. **Code Contributions**: Submit pull requests with bug fixes or new features
4. **Documentation**: Help improve guides, tutorials, and API documentation
5. **Testing**: Test new features and provide feedback
6. **Community Support**: Help other users in forums and Discord

### Development Guidelines

- **Code Style**: Follow existing code conventions and formatting
- **Testing**: Test all changes thoroughly before submitting
- **Documentation**: Update documentation for any new features
- **Compatibility**: Ensure changes maintain backward compatibility
- **Performance**: Consider performance impact of all modifications

### Getting Started with Development

1. Fork the repository on GitHub
2. Clone your fork locally
3. Create a feature branch for your changes
4. Make your modifications and test thoroughly
5. Submit a pull request with detailed description

For detailed contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Key License Points

- **Free to Use**: Use for personal and commercial servers
- **Modification Allowed**: Customize and modify as needed
- **Distribution**: Share with proper attribution
- **No Warranty**: Provided as-is without warranty

### Attribution

When using or modifying this resource, please maintain attribution to the original authors and contributors.

---

## Support & Community

### Getting Help

- **Documentation**: Start with this README and the docs/ folder
- **GitHub Issues**: Report bugs and request features
- **Community Forums**: Connect with other users and developers
- **Discord Server**: Real-time chat and support

### Community Resources

- **GitHub Repository**: https://github.com/Indom-hub/Cops-and-Robbers
- **Documentation**: Complete guides in the docs/ folder
- **Video Tutorials**: Community-created setup and gameplay guides
- **Server Showcases**: See the gamemode in action on various servers

### Acknowledgments

Special thanks to:
- **The Axiom Collective**: Original development team
- **FiveM Community**: Platform and development resources
- **Contributors**: All community members who have contributed code, testing, and feedback
- **Server Operators**: Admins who have tested and provided valuable feedback

---

*Cops and Robbers v1.2.0 - The ultimate FiveM law enforcement vs. criminal roleplay experience*

---

### Planned Updates (Version 1.2.1)
- Advanced heist mechanics
- Enhanced role progression system
- Improved anti-cheat measures
- Performance optimizations
- Mobile-responsive UI improvements

---

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](https://github.com/Indom-hub/Cops-and-Robbers/blob/main/LICENSE) file for details.

---

**Let the chase begin!**

---

## Additional Resources

- **[Wiki Documentation](https://github.com/Indom-hub/Cops-and-Robbers/wiki)**: Detailed guides and information.
- **[Issue Tracker](https://github.com/Indom-hub/Cops-and-Robbers/issues)**: Report bugs or suggest features.
- **[Discord Community](https://discord.gg/Kw5ndrWXfT)**: Join our community for support and discussion.
- **[Axiom Development Forum](https://forum.axiomrp.dev/)**: Detailed docs, guides, and support information.
