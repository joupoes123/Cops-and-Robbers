# Cops & Robbers - FiveM GTA V Roleplay Gamemode

**IMPORTANT NOTE:** This game mode, and the game mode GitHub repository, is still in development and therefore, not currently in a playable state. Please join the Discord community for updates on the full release. 

**Cops & Robbers** is an open-source gamemode for FiveM, designed to provide an immersive GTA V roleplay experience focused on the thrilling interaction between law enforcement and criminal elements. This project invites community contributions, encouraging developers to collaborate on creating dynamic gameplay with high-stakes chases, heists, and investigations.

---

## Table of Contents

- [Key Features](#key-features)
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

### Enhanced User Interface (UI)

- **NUI-Based Menus**: Interactive role selection menu and heist timers for an immersive experience.
- **HUD Elements**: Displays vital information such as heist details, wanted levels, and notifications.
- **Visual Feedback**: On-screen messages for level-ups, arrests, and other significant events.

### Additional Bank Locations

- **Variety of Heist Targets**: Multiple bank locations across the map offer diverse opportunities.
- **Variable Difficulty**: Different banks present unique challenges and rewards.

### Administrative Tools

- **Expanded Admin Commands**: Comprehensive commands for server management, including player moderation and resource control.
- **Real-Time Monitoring**: Spectate players, freeze/unfreeze actions, and teleport as needed.
- **Player Management**: Adjust player roles, cash balances, inventories, and more.

### Customizable Assets & Scripts

- **Modify Game Elements**: Tailor vehicles, weapons, uniforms, and abilities to fit your community's vision.
- **Seamless Integration**: Compatible with other popular FiveM mods and plugins for a versatile roleplay experience.

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

   - Ensure all necessary dependencies are installed (e.g., a database if required).

5. **Restart the Server**:

   - Restart or launch your server to initialize the resource.

---

## Configuration

Customize the gameplay experience by editing the configuration options in `config.lua`.

### General Settings

- **Max Players**: Set the maximum number of players (`Config.MaxPlayers`).
- **Heist Cooldown**: Adjust the cooldown time between heists (`Config.HeistCooldown`).
- **Spawn Locations**: Define spawn points for cops and robbers (`Config.CopSpawn`, `Config.RobberSpawn`).

### Bank Vaults

- **Heist Locations**: Configure multiple bank locations with coordinates, names, and IDs (`Config.BankVaults`).
- **Difficulty and Rewards**: Adjust security levels and rewards for each bank.

### Experience and Leveling

- **XP Requirements**: Define experience points needed for each level (`Config.Experience.Levels`).
- **Rewards**: Customize rewards for leveling up for both cops and robbers (`Config.Experience.Rewards`).

### Wanted Levels

- **Thresholds and Descriptions**: Set wanted level stages and their effects (`Config.WantedLevels`).
- **Action Impact**: Control how player actions influence their wanted level.

### Vehicles

- **Police Vehicles**: List available vehicles for cops (`Config.PoliceVehicles`).
- **Civilian Vehicles**: List available vehicles for robbers (`Config.CivilianVehicles`).

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
