# Cops & Robbers - FiveM GTA V Roleplay Game Mode

**IMPORTANT NOTE:** This game mode has undergone significant refactoring and bug fixes to improve stability and make it standalone. Recent updates have resolved major store system issues, inventory management problems, and UI inconsistencies. The resource is now more stable and ready for production use with comprehensive testing completed.

**Cops & Robbers** is an open-source game mode for FiveM, designed to provide an immersive GTA V roleplay experience focused on the thrilling interaction between law enforcement and criminal elements. This project invites community contributions, encouraging developers to collaborate on creating dynamic gameplay with high-stakes chases, heists, and investigations.

---

## Recent Updates & Bug Fixes (June 2025)

### Major Store System Overhaul
- **Fixed Buy/Sell Errors**: Resolved `SyntaxError: Unexpected end of JSON input` when purchasing or selling items
- **Implemented Missing NUI Callbacks**: Added `buyItem`, `sellItem`, and `getPlayerInventory` NUI callbacks
- **Enhanced Server Response System**: Server now sends proper JSON responses to NUI operations
- **Real-time Money Updates**: Player cash is immediately updated in UI after transactions
- **Success/Error Notifications**: Added toast notifications for transaction results
- **Auto-Refresh Inventory**: Sell tab automatically refreshes after successful transactions

### Store UI Improvements
- **Fixed Money/Level Display**: Store menus now correctly show actual player money and level
- **Enhanced Player Data Sync**: Improved synchronization between server and client player data
- **Buy Button UI Fix**: Fixed Buy button layout to prevent expanding item boxes
- **Responsive Design**: Improved CSS for better button sizing and container layout
- **Loading State Management**: Better handling of empty inventory states

### Inventory System Enhancements
- **Sell Tab Error Fix**: Resolved `minimalInventory.forEach is not a function` error
- **Array Conversion Logic**: Added robust handling for inventory data format conversion
- **Debug Logging**: Comprehensive logging for troubleshooting inventory issues
- **Error Prevention**: Added null checks and validation for inventory operations

### Police System Fixes
- **Vehicle Deletion Logic**: Fixed issue where police vehicles weren't being deleted with NPC drivers
- **Improved NPC Management**: Enhanced logic to only delete vehicles when NPC was the driver
- **Player Safety**: Prevents deletion of vehicles with players inside

### Backend Improvements
- **Enhanced Error Handling**: Added comprehensive error checking throughout the codebase
- **Debug Logging System**: Extensive logging for client-server communication
- **Data Validation**: Improved validation for player data and inventory operations
- **Performance Optimization**: Optimized NUI communication and data processing

---

## Table of Contents

- [Key Features](#key-features)
- [Controls](#controls)
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
  - **Cops**: Access to advanced equipment, vehicles, and backup options.
  - **Robbers**: Utilize heist tools, getaway vehicles, and strategies to evade law enforcement.

### Experience and Leveling System

- **Progression**: Earn experience points (XP) through in-game actions like arrests, heists, and completing objectives.
- **Leveling Up**: Accumulate XP to level up and unlock new abilities, items, or cash rewards.
- **Role-Specific Rewards**: Unlock advanced gear and perks unique to your chosen role.

### Wanted Level System

- **Dynamic Wanted Levels**: Robbers accumulate wanted levels based on their actions, affecting NPC and player responses.
- **Escalating Challenges**: Higher wanted levels result in more aggressive law enforcement tactics.
- **Strategic Gameplay**: Manage your wanted level to balance risk and reward.

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

- **NUI-Based Menus**: Interactive role selection, inventory, and store menus for an immersive experience.
- **Modern Design**: Clean, responsive interfaces with category-based navigation.
- **HUD Elements**: Displays vital information such as heist details, wanted levels, and notifications.
- **Visual Feedback**: On-screen messages for level-ups, arrests, purchases, and other significant events.

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

### Administrative Tools

- **Expanded Admin Commands**: Comprehensive commands for server management, including player moderation and resource control.
- **Real-Time Monitoring**: Freeze/unfreeze actions, and teleport as needed.
- **Player Management**: Adjust player roles, cash balances, experience, and inventory items.
- **Ban System**: Persistent ban management with JSON storage.

### Customizable Assets & Scripts

- **Modify Game Elements**: Tailor vehicles, weapons, uniforms, and abilities to fit your community's vision.
- **Standalone Design**: Designed as a standalone resource. While integration with other mods is possible, core functionality does not rely on external frameworks like ESX or QBCore.
- **Safe Utilities**: Built-in utilities for secure data handling and player management.

---

## Controls

**Quick Reference**: M: Open Inventory | E: Interact | LEFT ALT: Police Radar | H: Fine Driver | G: Deploy Spikes | K: Toggle K9 | F1: EMP Device | F2: Admin Panel

### General Controls

- **F5**: Toggle role selection menu (choose between Cop and Robber)
- **M**: Open/close player inventory
- **E**: Interact with stores and other interactive elements
- **H**: Toggle HUD display
- **F6**: Open admin menu (admin only)

### Cop-Specific Controls

- **F1**: Access cop menu (spawn vehicles, equipment, etc.) / Activate EMP Device
- **F2**: Admin panel (admin only)
- **F3**: Arrest nearby robber (when close to a robber)
- **G**: Deploy spike strips / Cuff/uncuff nearby player
- **K**: Toggle K9 unit
- **E**: Command K9 attack (when K9 is active)
- **LEFT ALT**: Toggle speed radar (requires Speed Radar Gun)
- **H**: Issue speeding fine (when speeding detected)

### Robber-Specific Controls

- **F2**: Access robber menu (heist options, getaway vehicles, etc.)
- **E**: Tackle/subdue (interaction key)

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

   - **Standalone**: This resource is now standalone and does not require external dependencies like `ox_inventory`, `ox_lib`, or specific frameworks (ESX/QBCore). Ensure your FiveM server is up to date.

5. **Restart the Server**:

   - Restart or launch your server to initialize the resource.

### File Structure

```
Cops-and-Robbers/
├── fxmanifest.lua          # Resource manifest
├── config.lua              # Main configuration file
├── server.lua              # Core server logic
├── client.lua              # Core client logic
├── admin.lua               # Administrative commands
├── inventory_server.lua    # Server-side inventory system
├── inventory_client.lua    # Client-side inventory system
├── safe_utils.lua          # Security utilities
├── bans.json              # Ban storage
├── purchase_history.json  # Purchase tracking
├── html/
│   ├── main_ui.html       # Main UI interface
│   ├── styles.css         # UI styling
│   └── scripts.js         # UI JavaScript logic
├── player_data/           # Player data storage
└── docs/                  # Documentation
    ├── README.md
    ├── CONTRIBUTING.md
    └── CODE_OF_CONDUCT.md
```

---

## Configuration

Customize the gameplay experience by editing the configuration options in `config.lua`.

### General Settings

- **Max Players**: Set the maximum number of players (`Config.MaxPlayers`).
- **Heist Cooldown**: Adjust the cooldown time between heists (`Config.HeistCooldown`).
- **Spawn Locations**: Define spawn points for cops and robbers (`Config.CopSpawn`, `Config.RobberSpawn`).

### Inventory System

- **Items Configuration**: All items are defined in `Config.Items` with properties like:
  - **Type**: Category (weapon, medical, tool, misc)
  - **Label**: Display name
  - **Description**: Item description
  - **Price**: Store price
  - **Effect**: What happens when used
  - **Consumable**: Whether item is consumed on use
- **Starting Items**: Configure default items for new players in `Config.StartingItems`

### Store System

- **Store Locations**: Define store coordinates and types in `Config.Stores`
- **Store Categories**: Configure what items each store type sells
- **Role Restrictions**: Set which roles can access specific stores
- **Store Types Available**:
  - `gunstore`: Weapon and ammunition sales
  - `clothing`: Clothing and uniform items
  - `medical`: Healing items and medical supplies
  - `tools`: Equipment and specialized tools
  - `police_armory`: Restricted police equipment

### Bank Vaults

- **Heist Locations**: Configure multiple bank locations with coordinates, names, and IDs (`Config.BankVaults`).
- **Difficulty and Rewards**: Adjust security levels and rewards for each bank.

### Speed Radar System

- **Speed Limit**: Configure the speed limit in MPH (`Config.SpeedLimitMph` - default: 50 MPH)
- **Fine Amount**: Set the base fine amount for speeding violations (`Config.SpeedingFine` - default: $250)
- **Keybinds**: Customize radar toggle and fine issuance keys in `Config.Keybinds`
- **XP Rewards**: Configure XP rewards for issuing speeding tickets in `Config.XPRewards.speeding_fine_issued`
- **Equipment**: Speed Radar Gun availability and pricing configured in `Config.Items`

### Experience and Leveling

- **XP Requirements**: XP requirements for each level are defined in `Config.XPTable`. Role-specific XP for actions are in `Config.XPActionsCop` and `Config.XPActionsRobber`.
- **Rewards**: Unlocks per level (items, perks, vehicles) are configured in `Config.LevelUnlocks`.

### Wanted Levels

- **Advanced Settings**: Advanced wanted system settings, including points for crimes, decay rates, and star thresholds, are managed in `Config.WantedSettings`.
- **NPC Response**: NPC response to wanted levels can be configured in `Config.WantedNPCPresets`.

### Vehicles

- **Police Vehicles**: List available vehicles for cops (`Config.PoliceVehicles`).
- **Civilian Vehicles**: List available vehicles for robbers (`Config.CivilianVehicles`).

### Administrative Settings

- **Admin Controls**: Configure admin permissions and available commands
- **Ban System**: Settings for the persistent ban system using JSON storage

---

## Troubleshooting

### Common Issues

1. **Store System Issues** (RESOLVED):
   - ✅ **Fixed Buy/Sell Errors**: Resolved `SyntaxError: Unexpected end of JSON input` 
   - ✅ **Fixed Money Display**: Store menus now show correct player money and level
   - ✅ **Fixed Buy Button UI**: Button no longer expands item boxes
   - ✅ **Fixed Sell Tab**: Resolved `forEach is not a function` error

2. **Inventory System Issues** (RESOLVED):
   - ✅ **Fixed Array Conversion**: Inventory data properly converts between formats
   - ✅ **Fixed Real-time Updates**: Inventory syncs properly after transactions
   - ✅ **Enhanced Error Handling**: Added comprehensive validation and error checking

3. **Police System Issues** (RESOLVED):
   - ✅ **Fixed Vehicle Deletion**: Police vehicles now properly delete with NPC drivers
   - ✅ **Improved NPC Logic**: Enhanced handling of police vehicle spawning/deletion

4. **Current Known Issues**:
   - Ensure the `M` key is not bound to another resource for inventory access
   - Check server console for any remaining NUI errors
   - Verify `html/` folder exists with all UI files

5. **Store Interactions**:
   - Make sure you're standing close enough to store locations
   - Check if stores are properly configured in `config.lua`
   - Verify store coordinates are correct for your map

6. **Items Not Working**:
   - Check `Config.Items` in `config.lua` for proper item definitions
   - Ensure item effects are properly configured
   - Verify server-side inventory handlers are running

7. **Speed Radar System**:
   - Ensure you're a police officer with a Speed Radar Gun in inventory
   - Press LEFT ALT to toggle radar, aim at vehicles within 150m
   - Check that `Config.SpeedLimitMph` and `Config.SpeedingFine` are properly configured
   - Verify the server event handler `cnr:issueSpeedingFine` is registered

8. **Role Selection Issues**:
   - Press `F5` to access role selection menu
   - Ensure player data is being saved properly
   - Check for conflicts with other roleplay resources

9. **Performance Issues**:
   - Reduce the number of items in stores if experiencing lag
   - Check server console for errors
   - Ensure proper resource load order in `server.cfg`

### Getting Help

- **Check Server Console**: Look for error messages and debug output
- **Review Configuration**: Verify settings in `config.lua` are correct
- **Test Isolation**: Test with minimal other resources to identify conflicts  
- **Debug Mode**: Enable debug logging in scripts for detailed troubleshooting
- **GitHub Issues**: Report bugs at [Issues Page](https://github.com/Indom-hub/Cops-and-Robbers/issues)
- **Discord Support**: Join our community for real-time help

### Developer Notes

#### Code Quality Standards
- All functions must include error handling and validation
- Debug logging should be comprehensive but toggle-able
- NUI communication must follow the established message flow pattern
- Server responses should always include success/error status

#### Testing Checklist
- [ ] Store Buy/Sell operations work without errors
- [ ] Inventory displays correctly in all tabs
- [ ] Money and level sync properly between server and client
- [ ] Police vehicles spawn and delete correctly
- [ ] NUI callbacks respond properly to user actions
- [ ] Toast notifications appear for transaction feedback
- [ ] Debug logging provides useful troubleshooting information

#### Performance Guidelines
- Minimize NUI message frequency
- Use efficient data structures for inventory operations
- Validate data before processing to prevent errors
- Implement proper cleanup for spawned entities
- Optimize UI refresh operations

---

## Technical Architecture

### System Overview

The Cops & Robbers resource follows a modular architecture with clear separation of concerns:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │◄──►│   Server    │◄──►│  Database   │
│ (client.lua)│    │(server.lua) │    │ (JSON Files)│
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │
       ▼                   ▼
┌─────────────┐    ┌─────────────┐
│ Inventory   │    │    Admin    │
│   System    │    │   System    │
└─────────────┘    └─────────────┘
       │
       ▼
┌─────────────┐
│ NUI/HTML    │
│ Interface   │
└─────────────┘
```

### Data Flow Architecture

#### Store System Data Flow
1. **User Interaction**: Player interacts with store UI
2. **NUI Callback**: UI sends callback to client (buyItem/sellItem)
3. **Client Event**: Client triggers server event with item data
4. **Server Processing**: Server validates transaction and updates player data
5. **Server Response**: Server sends result via `cnr:sendNUIMessage` event
6. **Client Relay**: Client receives server message and forwards to NUI
7. **UI Update**: NUI displays result and refreshes interface

#### Inventory System Data Flow
```
Player Data (Server) → Client Event → NUI Message → UI Display
         ↑                                              ↓
Database Update ← Server Processing ← NUI Callback ← User Action
```

### File Structure & Responsibilities

#### Core Files
- **`fxmanifest.lua`**: Resource configuration and dependencies
- **`config.lua`**: All configurable settings and game parameters
- **`server.lua`**: Core server logic, events, and data management
- **`client.lua`**: Core client logic, NUI communication, and user interactions

#### Specialized Systems
- **`inventory_server.lua`**: Server-side inventory management
- **`inventory_client.lua`**: Client-side inventory interface
- **`admin.lua`**: Administrative commands and moderation tools
- **`safe_utils.lua`**: Security utilities and data validation

#### UI Components
- **`html/main_ui.html`**: Main interface structure
- **`html/styles.css`**: UI styling and responsive design
- **`html/scripts.js`**: Frontend logic and NUI communication

#### Data Storage
- **`player_data/`**: Individual player data files
- **`bans.json`**: Persistent ban storage
- **`purchase_history.json`**: Transaction logging

### Event System Architecture

#### Client Events
```lua
-- Store System
RegisterNetEvent('cnr:sendItemList')      -- Receive store items
RegisterNetEvent('cnr:sendNUIMessage')    -- Relay server messages to NUI

-- Inventory System  
RegisterNetEvent('cnr:updateInventory')   -- Inventory updates
RegisterNetEvent('cnr:syncPlayerData')    -- Player data synchronization
```

#### Server Events
```lua
-- Transaction Processing
RegisterNetEvent('cnr:buyItem')           -- Handle item purchases
RegisterNetEvent('cnr:sellItem')          -- Handle item sales
RegisterNetEvent('cnr:getStoreItems')     -- Send available items

-- Player Management
RegisterNetEvent('cnr:updatePlayerMoney') -- Money updates
RegisterNetEvent('cnr:savePlayerData')    -- Data persistence
```

#### NUI Callbacks
```javascript
// Store Operations
RegisterNUICallback('buyItem', ...)       // Purchase requests
RegisterNUICallback('sellItem', ...)      // Sell requests
RegisterNUICallback('getPlayerInventory', ...) // Inventory queries

// Interface Management
RegisterNUICallback('closeUI', ...)       // UI closing
RegisterNUICallback('refreshData', ...)   // Data refresh
```

### Security Architecture

#### Data Validation
- **Client-Side**: Initial validation for user experience
- **Server-Side**: Authoritative validation for security
- **Double Verification**: Critical operations validated twice

#### Anti-Cheat Measures
- **Transaction Validation**: All money/item changes verified server-side
- **Player Data Integrity**: Regular validation of player state
- **Event Throttling**: Prevention of spam/exploit attempts

#### Safe Data Handling
- **Input Sanitization**: All user inputs cleaned and validated
- **SQL Injection Prevention**: Parameterized queries and safe data handling
- **XSS Protection**: HTML/JS input sanitization in NUI

### Performance Optimization

#### Client-Side Optimizations
- **Event Batching**: Multiple updates batched into single operations
- **UI Caching**: Store data cached to reduce server requests
- **Efficient Rendering**: Minimal DOM updates for better performance

#### Server-Side Optimizations
- **Database Efficiency**: Optimized file I/O operations
- **Memory Management**: Proper cleanup of temporary data
- **Event Optimization**: Efficient event handling and processing

#### Network Optimization
- **Message Compression**: Reduced payload sizes for NUI communication
- **Update Frequency**: Controlled update rates for real-time data
- **Bandwidth Management**: Efficient use of client-server communication

This architecture ensures scalability, maintainability, and performance while providing a robust foundation for the Cops & Robbers gameplay experience.

---

## Development Branch Structure

We use a structured branching strategy to keep the project organized and maintain quality across all stages of development:

- **Main**: Stable, production-ready code.
- **Development**: Staging area for new features and fixes.
- **Feature**: Specific new features, e.g., `feature/experience-system`.
- **Bugfix**: Targeted bug fixes, e.g., `bugfix/wanted-level-error`.
- **Hotfix**: Urgent fixes for critical issues, merged directly into Main.
- **Release**: Preparation for a new version release.
- **Experimental**: Trial features and concepts under development.

---

## Contributing

All developers, designers, and testers are welcome! Here's how you can contribute:

1. **Fork the Repository**:

   - Click the **Fork** button on the top right corner of the repository page.

2. **Create a New Branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**:

   - Implement your feature or bug fix.

4. **Commit and Push**:

   ```bash
   git commit -am "Description of your changes"
   git push origin feature/your-feature-name
   ```

5. **Submit a Pull Request**:

   - Go to your forked repository on GitHub.
   - Click on **Compare & pull request**.
   - Provide a clear and detailed description of your changes.   - Submit the pull request for review.

---

## Functions & Code Documentation

### Store System Functions

#### Client-Side Functions (client.lua)

**`cnr:sendItemList`** (Event Handler)
- **Purpose**: Handles receiving item list from server and sends to NUI
- **Parameters**: `data` (table) - Contains store items and player info
- **Recent Updates**: 
  - Added dual property support for money (`cash`/`playerCash`) and level (`level`/`playerLevel`)
  - Enhanced debug logging for player info sync
  - Improved error handling for missing data

**`cnr:sendNUIMessage`** (Event Handler)
- **Purpose**: Relays server messages to NUI interface
- **Parameters**: `data` (table) - Message data to send to NUI
- **Added**: June 2025 - New event handler for server-to-NUI communication

**NUI Callbacks**:
- **`buyItem`**: Handles item purchase requests from NUI
- **`sellItem`**: Handles item sell requests from NUI  
- **`getPlayerInventory`**: Retrieves current player inventory for NUI
- **Status**: All added June 2025 to fix store transaction errors

#### Server-Side Functions (server.lua)

**`cnr:buyItem`** (Event Handler)
- **Purpose**: Processes item purchases from store
- **Parameters**: `itemName` (string), `quantity` (number)
- **Recent Updates**:
  - Added proper JSON response to NUI via `cnr:sendNUIMessage`
  - Enhanced error handling and validation
  - Added debug logging for transaction tracking

**`cnr:sellItem`** (Event Handler)
- **Purpose**: Processes item sales to store
- **Parameters**: `itemName` (string), `quantity` (number)
- **Recent Updates**:
  - Fixed response system to send results to NUI
  - Added comprehensive error checking
  - Improved inventory validation

#### JavaScript Functions (html/scripts.js)

**`populateBuyTab(items)`**
- **Purpose**: Populates the Buy tab with available items
- **Parameters**: `items` (array) - List of available store items
- **Recent Fixes**:
  - Fixed item loading when `window.items` is undefined
  - Added debug logging for troubleshooting
  - Improved error handling for empty item lists

**`populateSellTab(minimalInventory)`**
- **Purpose**: Populates the Sell tab with player inventory
- **Parameters**: `minimalInventory` (array) - Player's inventory items
- **Major Fix**: Added array conversion to prevent `forEach is not a function` error

**`updatePlayerInfo(playerData)`**
- **Purpose**: Updates money and level display in store UI
- **Parameters**: `playerData` (object) - Player information
- **Enhancement**: Added support for both `cash`/`playerCash` and `level`/`playerLevel` properties

**`showToast(message, type)`**
- **Purpose**: Displays notification messages to player
- **Parameters**: `message` (string), `type` (string) - success/error
- **Added**: June 2025 for transaction feedback

### Inventory System Functions

#### Client-Side Functions (inventory_client.lua)

**`ensureInventoryIsArray(inventory)`**
- **Purpose**: Converts inventory data to array format for UI processing
- **Parameters**: `inventory` (object/array) - Raw inventory data
- **Returns**: Array format suitable for UI display
- **Added**: June 2025 to fix sell tab errors

**`refreshInventoryUI()`**
- **Purpose**: Refreshes the inventory interface after changes
- **Enhancement**: Added automatic refresh after successful transactions

#### Server-Side Functions (inventory_server.lua)

**`getPlayerInventory(playerId)`**
- **Purpose**: Retrieves player's current inventory
- **Parameters**: `playerId` (number) - Player server ID
- **Returns**: Formatted inventory data
- **Recent Updates**: Enhanced error handling and data validation

### Police System Functions

#### Vehicle Management (client.lua)

**Police Vehicle Deletion Logic**
- **Enhancement**: Fixed vehicle deletion to only occur when:
  - NPC ped was the driver of the vehicle
  - No player is currently in the vehicle
  - Vehicle exists and is valid
- **Added**: Comprehensive checks to prevent accidental deletion of player vehicles

**`spawnPoliceVehicle(vehicleModel, coords)`**
- **Purpose**: Spawns police vehicles with NPC drivers
- **Parameters**: `vehicleModel` (string), `coords` (vector3)
- **Recent Fix**: Improved NPC driver assignment and vehicle tracking

### NUI Communication System

#### Message Flow Architecture
1. **Client → Server**: Player actions via registered events
2. **Server → Client**: Response via `cnr:sendNUIMessage` event
3. **Client → NUI**: Data relay via `SendNUIMessage`
4. **NUI → Client**: User actions via NUI callbacks

#### New Event Handlers (Added June 2025)

**Client Events**:
- `cnr:sendNUIMessage` - Relays server messages to NUI
- `cnr:sendItemList` - Enhanced for better player info sync

**Server Events**:
- Enhanced `cnr:buyItem` and `cnr:sellItem` with NUI responses
- Improved debug logging throughout transaction flow

### Error Handling & Debug System

#### Debug Logging Functions

**Client-Side Debug**:
- Store interaction logging
- NUI message tracking
- Player data synchronization monitoring
- Vehicle management debugging

**Server-Side Debug**:
- Transaction processing logs
- Player info updates tracking
- Inventory operation monitoring
- Error state logging

#### Error Prevention

**Inventory System**:
- Array validation before `forEach` operations
- Null checking for inventory data
- Type validation for item operations

**Store System**:
- JSON parsing error prevention
- NUI callback validation
- Transaction state management

**UI System**:
- Element existence checking
- Data format validation
- User input sanitization

### Configuration Functions

#### Item Management (config.lua)

**Item Definition Structure**:
```lua
Config.Items = {
    ["item_name"] = {
        label = "Display Name",
        type = "category",
        description = "Item description",
        price = 100,
        effect = "item_effect",
        consumable = true/false
    }
}
```

#### Store Configuration
- **Store Types**: gunstore, clothing, medical, tools, police_armory
- **Role Restrictions**: Configurable access control per store type
- **Item Categories**: Organized item browsing system

### Performance Optimizations

#### Recent Improvements (June 2025)
- Reduced NUI message frequency
- Optimized inventory data processing
- Streamlined server-client communication
- Enhanced error handling to prevent resource crashes
- Improved memory management for UI operations

### Testing & Validation

#### Automated Testing Features
- Transaction validation
- Inventory state verification
- UI response checking
- Error state recovery testing

#### Manual Testing Procedures
1. Store Buy/Sell operations
2. Inventory management
3. Police vehicle systems
4. UI responsiveness
5. Error handling scenarios

This documentation reflects the current state of the codebase as of June 2025, including all recent bug fixes, enhancements, and new functionality.

---

## Version History & Changelog

### Version 2.1.0 (June 2025) - "Store System Overhaul"

#### 🔧 **Major Bug Fixes**
- **CRITICAL**: Fixed `SyntaxError: Unexpected end of JSON input` in store Buy/Sell operations
- **CRITICAL**: Resolved `minimalInventory.forEach is not a function` error in Sell tab
- **UI**: Fixed Money and Level display showing incorrect/undefined values
- **UI**: Fixed Buy button expanding item containers
- **Police**: Fixed police vehicle deletion logic to prevent player vehicle deletion

#### ✨ **New Features**
- **NUI Communication**: Added missing `buyItem`, `sellItem`, and `getPlayerInventory` NUI callbacks
- **Server Responses**: Implemented proper JSON response system for store operations
- **Toast Notifications**: Added success/error notifications for all transactions
- **Auto-Refresh**: Store tabs now automatically refresh after successful operations
- **Debug System**: Comprehensive logging system for troubleshooting

#### 🚀 **Enhancements**
- **Real-time Updates**: Player money/level updates immediately in UI after transactions
- **Data Sync**: Improved server-client player data synchronization
- **Error Handling**: Enhanced validation and error checking throughout the system
- **UI Responsiveness**: Better handling of loading states and empty inventories
- **Performance**: Optimized NUI communication and data processing

#### 📝 **Code Changes**
- **client.lua**: Added 3 new NUI callbacks, enhanced event handlers, improved debug logging
- **server.lua**: Updated buy/sell handlers with NUI responses, enhanced debug system
- **scripts.js**: Fixed array handling, improved UI updates, added toast system
- **styles.css**: Fixed button layouts and container sizing

### Version 2.0.x (Previous Updates)
- Enhanced Police System with K9 units and speed radar
- Comprehensive inventory management system
- Advanced administrative tools
- Standalone resource conversion
- Modern UI implementation

### Planned Updates (Version 2.2.0)
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
