# Cops & Robbers - FiveM GTA V Roleplay Game Mode

**IMPORTANT NOTE:** This game mode has undergone significant refactoring to improve stability and make it standalone. While major issues have been addressed, it's still recommended to test thoroughly before deploying to a live production environment. Community contributions and feedback are welcome!

**Cops & Robbers** is an open-source game mode for FiveM, designed to provide an immersive GTA V roleplay experience focused on the thrilling interaction between law enforcement and criminal elements. This project invites community contributions, encouraging developers to collaborate on creating dynamic gameplay with high-stakes chases, heists, and investigations.

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

### Advanced Player Inventory System

- **Modern UI**: Features a sleek, category-based inventory interface accessible with the `I` key.
- **Item Management**: View, equip, use, and drop items with intuitive controls.
- **Categories**: Items are organized into Weapons, Medical, Tools, and Miscellaneous for easy navigation.
- **Real-time Updates**: Inventory syncs in real-time between client and server.
- **Item Effects**: Items have immediate effects when used (healing, armor, spike strips, etc.).

### Comprehensive Store System

- **Multiple Store Types**: 
  - **Gun Stores**: Purchase weapons and ammunition (Cop-only stores and civilian gun stores)
  - **Clothing Stores**: Buy and equip different clothing items
  - **Medical Stores**: Purchase healing items and medical supplies
  - **Tool Stores**: Buy specialized tools and equipment
- **Role-Specific Access**: Certain stores are restricted to specific roles (e.g., police equipment stores)
- **Interactive Interface**: Modern UI for browsing and purchasing items
- **Inventory Integration**: Purchased items are automatically added to player inventory

### Enhanced User Interface (UI)

- **NUI-Based Menus**: Interactive role selection, inventory, and store menus for an immersive experience.
- **Modern Design**: Clean, responsive interfaces with category-based navigation.
- **HUD Elements**: Displays vital information such as heist details, wanted levels, and notifications.
- **Visual Feedback**: On-screen messages for level-ups, arrests, purchases, and other significant events.

### Banking and Heist System

- **Multiple Bank Locations**: Various bank locations across the map offer diverse heist opportunities.
- **Variable Difficulty**: Different banks present unique challenges and rewards.
- **Heist Mechanics**: Coordinated bank robberies with timers and security responses.

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

### General Controls

- **F5**: Toggle role selection menu (choose between Cop and Robber)
- **I**: Open/close player inventory
- **E**: Interact with stores and other interactive elements
- **H**: Toggle HUD display
- **F6**: Open admin menu (admin only)

### Cop-Specific Controls

- **F1**: Access cop menu (spawn vehicles, equipment, etc.)
- **F3**: Arrest nearby robber (when close to a robber)
- **G**: Cuff/uncuff nearby player

### Robber-Specific Controls

- **F2**: Access robber menu (heist options, getaway vehicles, etc.)

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

1. **Inventory Not Opening**: 
   - Ensure the `I` key is not bound to another resource
   - Check server console for NUI errors
   - Verify `html/` folder exists with all UI files

2. **Store Interactions Not Working**:
   - Make sure you're standing close enough to store locations
   - Check if stores are properly configured in `config.lua`
   - Verify store coordinates are correct for your map

3. **Items Not Working**:
   - Check `Config.Items` in `config.lua` for proper item definitions
   - Ensure item effects are properly configured
   - Verify server-side inventory handlers are running

4. **Role Selection Issues**:
   - Press `F5` to access role selection menu
   - Ensure player data is being saved properly
   - Check for conflicts with other roleplay resources

5. **Performance Issues**:
   - Reduce the number of items in stores if experiencing lag
   - Check server console for errors
   - Ensure proper resource load order in `server.cfg`

### Getting Help

- Check the console for error messages
- Review the configuration in `config.lua`
- Test with minimal other resources to identify conflicts
- Join our Discord community for support

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
   - Provide a clear and detailed description of your changes.
   - Submit the pull request for review.

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
