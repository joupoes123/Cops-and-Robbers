# Cops and Robbers Comprehensive Guide

Welcome to the Cops and Robbers (CnR) game mode! This guide provides a comprehensive overview of all key bindings, features, and how-to instructions to help you navigate and succeed in the world of law enforcement and criminal enterprise.

## Table of Contents
*   [Core Gameplay Mechanics](#core-gameplay-mechanics)
    *   [Roles](#roles)
    *   [Spawning](#spawning)
    *   [User Interface (UI)](#user-interface-ui)
*   [General Player Actions & Keybinds](#general-player-actions--keybinds)
    *   [Common Interaction Key](#common-interaction-key)
    *   [Default Keybinds](#default-keybinds)
    *   [NUI Menus](#nui-menus)
*   [Features for Cops](#features-for-cops)
    *   [Objective (Cop)](#objective)
    *   [Arresting Suspects](#arresting-suspects)
    *   [Cop-Specific Tools & Abilities](#cop-specific-tools--abilities)
    *   [Backup Options](#backup-options)
*   [Features for Robbers](#features-for-robbers)
    *   [Objective (Robber)](#objective-1)
    *   [Wanted System](#wanted-system)
    *   [Criminal Activities](#criminal-activities)
    *   [Robber Equipment & Vehicles](#robber-equipment--vehicles)
    *   [Evasion Strategies](#evasion-strategies)
*   [Shared Systems & Features](#shared-systems--features)
    *   [Jail System](#jail-system)
    *   [Experience (XP) and Leveling System](#experience-xp-and-leveling-system)
    *   [Perks](#perks)
    *   [Economy & Stores](#economy--stores)
    *   [Safe Zones](#safe-zones)
    *   [Team Balancing](#team-balancing)
    *   [Bounty System (General Mechanics)](#bounty-system-general-mechanics)
*   [Administrative Features (For Server Admins)](#administrative-features-for-server-admins)
*   [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)

## Core Gameplay Mechanics

### Roles
In Cops and Robbers, you can choose to play as one of three distinct roles:

*   **Cop:** Uphold the law, respond to crimes, and arrest criminals. Cops have access to specialized equipment and work together to maintain order.
*   **Robber:** Live a life of crime by robbing stores, banks, armored cars, or engaging in other illicit activities. Robbers aim to make money and evade capture.
*   **Citizen:** A neutral role. Citizens typically do not actively participate in the Cops vs. Robbers conflict but can witness events and may become targets or interact in unique ways (though specific citizen-focused features are minimal in this version).

You will typically select your role through a menu that appears when you first join the server or after you spawn.

### Spawning
Once you've selected your role, you will spawn at a designated location for your team:
*   **Cops:** Usually spawn at a Police Station (e.g., Mission Row PD).
*   **Robbers:** Spawn at a location suitable for criminal activities (e.g., Sandy Shores Airfield).
*   **Citizens:** Spawn at a general public location (e.g., Legion Square).

*(Refer to `Config.SpawnPoints` in `config.lua` for specific default locations).*

### User Interface (UI)
The game mode features a custom user interface to keep you informed:
*   **Money Display:** Shows your current cash.
*   **XP Bar:** Displays your current experience points and level.
*   **Wanted Level Display:** Shows your current wanted status as a robber.
*   **Notifications:** Provides updates on in-game events, actions, and rewards.
*   **NUI Menus:** Various actions like role selection, store purchases, and accessing the admin panel or bounty board are handled through NUI (pop-up) menus.

## General Player Actions & Keybinds

Many actions in Cops and Robbers are performed using specific keys or through interaction prompts.

### Common Interaction Key
*   **`E` Key (INPUT_CONTEXT):** This is the primary key for interacting with the world. You'll use `E` to:
    *   Open store menus (Ammu-Nations, NPC Vendors).
    *   Start robbing a store.
    *   Collect contraband from drops.
    *   Interact with corrupt officials to reduce wanted level.
    *   Use appearance change stores.
    *   Start sabotaging a power grid.
    *   Potentially initiate bank heists (at bank locations).
    *   As a Cop, command your K9 to attack a targeted suspect (when K9 is active).

    Keep an eye out for on-screen prompts indicating when you can press `E` to perform an action.

### Default Keybinds
Below is a list of default keybinds for various actions. Some of these might be configurable through server settings or FiveM's keybinding menu if the server administrator has enabled it via `RegisterKeyMapping`. The names in parentheses (e.g., `INPUT_CELLPHONE_SCROLL_BACKWARD`) are the internal FiveM control names.

*   **Toggle Speed Radar (Cop):** `PageUp` (`INPUT_CELLPHONE_SCROLL_BACKWARD` - Default: `17`)
    *   *Defined in `Config.Keybinds.toggleSpeedRadar`.*
*   **Fine Speeder (Cop):** `H` (`INPUT_VEH_HEADLIGHT` - Default: `74`)
    *   *Defined in `Config.Keybinds.fineSpeeder`.*
*   **Deploy Spike Strip (Cop):** `Home` (`INPUT_PREV_WEAPON` - Default: `19`)
    *   *Defined in `Config.Keybinds.deploySpikeStrip`.*
*   **Tackle/Subdue (Cop):** `G` (`INPUT_WEAPON_SPECIAL_TWO` - Default: `47`)
    *   *Defined in `Config.Keybinds.tackleSubdue`.*
*   **Toggle K9 Unit (Cop):** `K` (`INPUT_VEH_CIN_CAM` - Default: `311`)
    *   *Defined in `Config.Keybinds.toggleK9`.*
*   **Command K9 Attack (Cop):** `E` (`INPUT_CONTEXT` - Default: `38` but generally `51` for context actions)
    *   *`Config.Keybinds.commandK9Attack` suggests `E`, which aligns with the general interaction key.*
*   **Activate EMP Device (Robber):** `Numpad 0` (`INPUT_SELECT_WEAPON_UNARMED` - Default: `121`)
    *   *Defined in `Config.Keybinds.activateEMP`.*
*   **Toggle Admin Panel (Admin):** `F10` (`INPUT_REPLAY_STOPRECORDING` - Default: `289`)
    *   *Defined in `Config.Keybinds.toggleAdminPanel`.*
*   **Toggle Bounty Board (Cop):** `F7` (`INPUT_REPLAY_RECORD` - Default: `168`)
    *   *Defined in `Config.Keybinds.toggleBountyBoard` (Note: `client.lua` mentions control `168` which is `INPUT_PHONE`). Check your specific server setup if F7 doesn't work.*

*Note: If a keybind from `Config.Keybinds` is not working, it might be overridden by another script or not correctly registered. The number values are the internal control IDs used by FiveM.*

### NUI Menus
Several features are accessed through pop-up menus (NUI):
*   **Role Selection:** Appears on join/spawn.
*   **Stores:** When you press `E` at a store, a menu opens to browse and buy items.
*   **Inventory:** Accessed via NUI, potentially through a command or integrated into other menus.
*   **Admin Panel:** Toggled with its keybind.
*   **Bounty Board:** Toggled with its keybind.

## Features for Cops

As a Cop, your primary goal is to uphold the law, arrest criminals, and respond to ongoing crimes.

### Objective
*   Patrol the city and surrounding areas.
*   Respond to dispatch calls for crimes in progress (store robberies, bank heists, etc.).
*   Arrest wanted Robbers.
*   Issue fines for infractions like speeding.
*   Utilize special police equipment and K9 units to apprehend suspects.

### Arresting Suspects
*   When a Robber has a wanted level, Cops can arrest them.
*   **Subdue/Tackle:** Before arresting, you might need to subdue a suspect.
    *   **Key:** `G` (or as per `Config.Keybinds.tackleSubdue`).
    *   Get close to a Robber and press the key to attempt a tackle. If successful, the Robber will be temporarily immobilized, allowing for an arrest.
*   **Arrest:** Once a suspect is subdued or compliant, you can arrest them (the exact mechanism might involve an interaction prompt or occur automatically after subduing a wanted player).
*   Jailed Robbers are sent to prison for a duration based on their wanted level at the time of arrest.
*   Cops earn XP for successful arrests, with more XP awarded for higher wanted levels.

### Cop-Specific Tools & Abilities

*   **Spike Strips:**
    *   **Key to Deploy:** `Home` (or as per `Config.Keybinds.deploySpikeStrip`).
    *   **Purpose:** Deploys a strip of spikes on the road to puncture the tires of fleeing vehicles.
    *   **Usage:** You must have a "Spike Strip" item in your inventory (purchasable from the Cop Store).
    *   **Limits:** Cops can deploy a maximum number of spike strips simultaneously (`Config.MaxDeployedSpikeStrips`). This limit can be increased with the "Extra Spike Strips" perk. Deployed strips despawn automatically after a set duration (`Config.SpikeStripDuration`).
    *   **XP Bonus:** Successfully using a spike strip that leads to an arrest can grant bonus XP.

*   **Speed Radar & Fining:**
    *   **Key to Toggle Radar:** `PageUp` (or as per `Config.Keybinds.toggleSpeedRadar`).
    *   **Key to Fine Speeder:** `H` (or as per `Config.Keybinds.fineSpeeder`).
    *   **Purpose:** Allows Cops to detect vehicles exceeding the speed limit (`Config.SpeedLimitKmh`).
    *   **Usage:** Activate the radar. When a speeding vehicle is detected, a notification will appear. Press the fine key to issue a fine (`Config.SpeedingFine`) to the driver.
    *   **XP Bonus:** Successfully issuing a speeding ticket awards XP.

*   **K9 Unit:**
    *   **Key to Call/Dismiss K9:** `K` (or as per `Config.Keybinds.toggleK9`).
    *   **Key to Command Attack:** `E` (INPUT_CONTEXT, while K9 is active and aiming at a suspect).
    *   **Purpose:** A loyal police dog that can help track and attack suspects.
    *   **Requirements:**
        *   Must be a certain Cop level (defined by `Config.Items.k9whistle.minLevelCop`).
        *   Must possess a "K9 Whistle" item (purchasable from the Cop Store).
    *   **Usage:** Use the toggle key to call your K9. Once active, aim at a Robber and press the command key to order an attack. The K9 will follow you when not attacking.
    *   **XP Bonus:** An arrest assisted by your K9 can grant bonus XP.

*   **Bounty Board:**
    *   **Key to Toggle:** `F7` (or `INPUT_REPLAY_RECORD` / `Config.Keybinds.toggleBountyBoard`).
    *   **Purpose:** Opens a NUI menu displaying active bounties placed on highly wanted Robbers. This helps Cops identify high-value targets.
    *   **Access:** Only Cops can access the Bounty Board.

*   **Equipment from Cop Store:**
    *   Cops have access to a dedicated "Cop Store" NPC vendor (`Config.NPCVendors` where `name = "Cop Store"`).
    *   Here, Cops can purchase exclusive items such as:
        *   Taser (`weapon_stungun`)
        *   Police-issue firearms (Pistols, Shotguns, Carbine Rifle)
        *   Body Armor
        *   First Aid Kits/Medkits
        *   Spike Strips (`spikestrip_item`)
        *   Speed Radar Gun (`speedradar_gun`)
        *   K9 Whistle (`k9whistle`)
    *   Access to some items may be restricted by Cop level (defined in `Config.Items` `minLevelCop`).

### Backup Options
*   While not a specific key, Cops are encouraged to work together. Alert other Cops to ongoing situations and coordinate responses.
*   The system automatically alerts all online Cops to major crimes like bank robberies.

## Features for Robbers

As a Robber, your aim is to accumulate wealth and power through illicit activities while evading law enforcement.

### Objective
*   Commit crimes to earn money and Experience Points (XP).
*   Evade arrest by Cops.
*   Manage your wanted level strategically.
*   Utilize special tools and tactics to aid in heists and escapes.

### Wanted System
*   **Gaining Wanted Level:** Committing crimes increases your wanted level (represented by stars and points). Crimes that increase wanted level include:
    *   Speeding (if caught by a Cop's radar and results in a chase/further infraction)
    *   Reckless Driving
    *   Grand Theft Auto (especially of occupied vehicles)
    *   Store Robberies
    *   Armored Car Heists
    *   Bank Heists
    *   Assaulting/Murdering Civilians or Cops
    *   Resisting Arrest
    *   Using an EMP device that affects police vehicles
    *   Sabotaging a Power Grid
    *   *(Refer to `Config.WantedSettings.crimes` for a detailed list of crimes and points.)*
*   **Effects of Wanted Level:**
    *   Higher wanted levels attract more intense police attention (human Cops will be more actively looking for you).
    *   If `Config.WantedSettings.enableNPCResponse` is true on the server, NPC police units may also pursue you with increasing aggression at higher wanted levels.
    *   A bounty may be placed on your head if your wanted level reaches the threshold defined in `Config.BountySettings.wantedLevelThreshold`.
*   **Losing Wanted Level:**
    *   **Decay:** Your wanted points will slowly decay over time if you avoid committing new crimes and stay out of sight of Cops (`Config.WantedSettings.decayRatePoints`, `decayIntervalMs`, `noCrimeCooldownMs`).
    *   **Corrupt Officials:** Find "Shady Contacts" at locations defined in `Config.CorruptOfficials`. Interact with them (`E` key) to pay a fee (`costPerStar`) to reduce your wanted level. There's a cooldown for using this service.
    *   **Appearance Change Stores:** Visit locations from `Config.AppearanceChangeStores` (e.g., clothing stores). Interact (`E` key) to pay a fee (`cost`) and reduce your wanted points. This also has a cooldown.
    *   **Getting Arrested:** Being arrested and jailed will reset your wanted level upon release.

### Criminal Activities

*   **Store Robberies:**
    *   **How to Initiate:** Approach a robbable store (locations from `Config.RobbableStores`) and press `E` (INPUT_CONTEXT) when prompted.
    *   **Process:** You'll need to remain inside the store for a certain duration (`duration` in `Config.RobbableStores`). Cops will be alerted.
    *   **Rewards:** Successful robberies award cash (between `rewardMin` and `rewardMax`) and XP (`Config.XPActionsRobber.successful_store_robbery_medium`).
    *   **Cooldown:** There's a cooldown (`cooldown` in `Config.RobbableStores`) before the same store can be robbed again. Requires a minimum number of Cops online (`copsNeeded`).

*   **Armored Car Heists:**
    *   **Appearance:** These are dynamic events. An alert is sent out when an armored car (`Config.ArmoredCar.model`) spawns. It will have a blip on the map.
    *   **How to Engage:** Damage the armored car until its health is depleted.
    *   **Looting:** Once stopped/destroyed, you'll need to interact for a short period (`Config.ArmoredCar.lootingTimeMs`) to get the cash.
    *   **Rewards:** Cash (between `Config.ArmoredCar.rewardMin` and `Config.ArmoredCar.rewardMax`) and XP (`Config.XPActionsRobber.successful_armored_car_heist`).
    *   **Conditions:** Requires a minimum number of Cops online (`Config.ArmoredCarHeistCopsNeeded`) and has a global cooldown (`Config.ArmoredCarHeistCooldown`).

*   **Bank Heists:**
    *   **Locations:** Banks available for heists are listed in `Config.BankVaults`.
    *   **How to Initiate:** *(Assumed)* Approach a bank vault location and interact using the `E` key (INPUT_CONTEXT) or a similar prompt. *(The exact mechanism for starting bank heists is not explicitly detailed in the reviewed client/server files but typically involves an interaction at the location).*
    *   **Process:** Once started, a timer (`Config.HeistTimers.defaultHeistDurationSecs` or bank-specific) will likely begin. Cops will be alerted with the bank's location.
    *   **Rewards:** Successful heists award cash and significant XP (`Config.XPActionsRobber.successful_bank_heist_major`).
    *   **Conditions:** Requires a minimum number of Cops online (`Config.HeistSettings.copsRequiredForMajorHeist`) and is subject to a global heist cooldown (`Config.HeistSettings.globalCooldownMs`).

*   **Contraband Drops:**
    *   **Appearance:** These are dynamic events. A notification appears when a contraband drop is available, and it will be marked with a blip on the map.
    *   **How to Collect:** Go to the blip location. You'll see a prop (`Config.ContrabandItems.modelHash`). Interact with `E` (INPUT_CONTEXT) for a short duration (`Config.ContrabandCollectionTimeMs`) to collect it. This time can be reduced by the "Faster Contraband Collection" perk.
    *   **Rewards:** Contains valuable items or cash (`Config.ContrabandItems.value`) and XP (`Config.XPActionsRobber.contraband_collected`).
    *   **Limits:** A maximum number of drops can be active at once (`Config.MaxActiveContrabandDrops`). There's an interval between new drops (`Config.ContrabandDropIntervalMs`).

*   **EMP Device:**
    *   **Key to Activate:** `Numpad 0` (or as per `Config.Keybinds.activateEMP`).
    *   **Purpose:** Disables nearby vehicles (both player and NPC) for a short duration (`Config.EMPDisableDurationMs`) within a specific radius (`Config.EMPRadius`). Very useful for escapes.
    *   **Requirements:**
        *   Must be a certain Robber level (defined by `Config.Items.emp_device.minLevelRobber`).
        *   Must possess an "EMP Device" item (purchasable from Robber-affiliated stores).
    *   **Consequences:** Using an EMP that affects police vehicles will increase your wanted level (`Config.WantedSettings.crimes.emp_used_on_police`).

*   **Power Grid Sabotage:**
    *   **Locations:** Specific power grids are defined in `Config.PowerGrids`.
    *   **How to Initiate:** Approach a power grid and interact with `E` (INPUT_CONTEXT). This takes time (`sabotageTimeMs`).
    *   **Effect:** Causes a temporary power outage in the area (`Config.PowerOutageDurationMs`), potentially disabling lights or other systems.
    *   **Rewards:** Awards XP (`Config.XPActionsRobber.power_grid_sabotage_success`).
    *   **Consequences:** Increases your wanted level (`Config.WantedSettings.crimes.power_grid_sabotaged_crime`).
    *   **Cooldown:** A specific grid has a cooldown (`Config.PowerGridSabotageCooldown`) before it can be sabotaged again.
    *   **Requirements:** May require a certain Robber level and/or specific gear (e.g., an item that enables sabotage, implicitly the EMP or similar high-tech item might be considered the tool if not specified). The client-side check refers to `Config.Items["emp_device"]` for level check.

### Robber Equipment & Vehicles
*   Robbers can purchase weapons, tools, and accessories from non-Cop affiliated NPC Vendors (e.g., "Black Market Dealer", "Gang Supplier" in `Config.NPCVendors`).
*   Access to some items may be restricted by Robber level (`minLevelRobber` in `Config.Items`).
*   Robbers typically acquire vehicles by stealing them or purchasing them through general vehicle shops if available on the server (the script itself doesn't provide a Robber-specific vehicle store, but `Config.CivilianVehicles` lists some common ones).

### Evasion Strategies
*   Besides using EMPs and knowledge of wanted level reduction methods:
    *   **Laying Low:** Avoiding Cops and further criminal activity can allow your wanted level to decay.
    *   **Changing Vehicles:** Frequently changing stolen vehicles can make you harder to track.
    *   **Masks/Appearance:** While the script has items like "Mask" (`Config.Items`), the primary wanted reduction via appearance is through the dedicated "Appearance Change Stores." Wearing a mask might offer roleplay benefits or minor advantages if server customizes it.

## Shared Systems & Features

These systems and features are integral to the Cops and Robbers experience and affect all players or the interaction between roles.

### Jail System
*   **Getting Jailed:** If a Robber is arrested by a Cop, they are sent to jail (location defined in `Config.PrisonLocation`).
*   **Jail Time:** The duration of the jail sentence depends on the Robber's wanted level at the time of arrest. A base jail time is modified by the number of stars.
*   **Restrictions:** While in jail, your actions are heavily restricted (e.g., movement limitations, inability to use weapons or items).
*   **Release:** You are automatically released when your jail timer expires. Upon release, your wanted level is cleared, and you will spawn back at your role's designated spawn point.

### Experience (XP) and Leveling System
*   **Earning XP:** Both Cops and Robbers earn Experience Points (XP) by performing role-specific actions.
    *   **Cops XP Actions (`Config.XPActionsCop`):**
        *   Successful arrests (more XP for higher wanted levels).
        *   Bonus XP for arrests assisted by K9 or after a manual subdue/tackle.
        *   Issuing speeding tickets.
        *   Spike strip hits that lead to an arrest.
    *   **Robbers XP Actions (`Config.XPActionsRobber`):**
        *   Successful store robberies.
        *   Successful armored car heists.
        *   Successful major bank heists.
        *   Collecting contraband drops.
        *   Effective EMP use (e.g., disabling Cop cars).
        *   Successful power grid sabotage.
*   **Leveling Up:** Accumulating enough XP will cause you to level up. The XP required for each level is defined in `Config.XPTable`. The maximum attainable level is `Config.MaxLevel`.
*   **Unlocks:** Leveling up can unlock access to:
    *   **New Items:** Specific weapons, gear, or tools become available for purchase in role-specific stores (defined in `Config.LevelUnlocks` under `item_access`).
    *   **Passive Perks:** Automatic bonuses or enhancements (defined in `Config.LevelUnlocks` under `passive_perk`).
    *   **New Vehicles:** Access to new vehicles for your role (defined in `Config.LevelUnlocks` under `vehicle_access`).
*   **Notifications:** The game will notify you when you gain XP and when you level up. Your XP bar in the UI tracks your progress to the next level.

### Perks
Perks are passive abilities or bonuses unlocked by reaching certain levels in your respective role. These are applied automatically.
*   **Known Cop Perks:**
    *   **Increased Armor Durability (`increased_armor_durability`):** Your body armor lasts longer (modifier from `Config.PerkEffects.IncreasedArmorDurabilityModifier` or `Config.LevelUnlocks`).
    *   **Extra Spike Strips (`extra_spike_strips`):** Allows you to carry and deploy more spike strips simultaneously (value from `Config.LevelUnlocks`).
*   **Known Robber Perks:**
    *   **Faster Contraband Collection (`faster_contraband_collection`):** Reduces the time it takes to collect contraband drops (modifier from `Config.LevelUnlocks`).
*   *(Other perks might be defined in `Config.LevelUnlocks` for your specific server setup.)*

### Economy & Stores
*   **Currency:** The primary currency is cash, displayed on your UI.
*   **NPC Vendors & Ammu-Nation:**
    *   **Access:** Approach a store or vendor location and press `E` (INPUT_CONTEXT) to open the NUI purchase menu.
    *   **Ammu-Nation Stores (`Config.AmmuNationStores`):** Sell a general variety of weapons and ammunition.
    *   **NPC Vendors (`Config.NPCVendors`):**
        *   **Cop Store:** Sells police-specific equipment.
        *   **Black Market Dealer / Gang Supplier:** Sell Robber-specific tools, weapons, and illicit goods.
    *   **Item Availability:** Access to certain items can be restricted by your role and current level.
*   **Dynamic Pricing (`Config.DynamicEconomy`):**
    *   If enabled on the server, the prices of items can change dynamically based on their purchase popularity over a period (`popularityTimeframe`).
    *   Popular items may become more expensive (`priceIncreaseFactor`), while unpopular items may become cheaper (`priceDecreaseFactor`).
*   **Selling Items:** You can sell items from your inventory at stores. The sell price is typically a percentage (`sellPriceFactor`) of the item's current market value.
*   **Inventory:**
    *   Your items are managed in an integrated inventory system.
    *   The inventory can be accessed via NUI, usually when interacting with stores or potentially through a dedicated key/command if configured.

### Safe Zones
*   **Locations:** Defined in `Config.SafeZones` (e.g., Mission Row PD Lobby, hospitals).
*   **Effects:** When inside a safe zone:
    *   You are typically invincible (cannot take damage).
    *   Firing weapons is disabled.
    *   Combat is generally prevented.
*   **Notifications:** You'll receive a message when entering or leaving a safe zone.

### Team Balancing
*   **Incentives (`Config.TeamBalanceSettings`):** If enabled, the system may offer a cash bonus (`incentiveCash`) to players who join the team with fewer members (e.g., if there are significantly more Cops than Robbers, joining the Robber team might give you a bonus).
*   **Purpose:** To encourage more balanced teams for better gameplay.

### Bounty System (General Mechanics)
*   **Placement:** If a Robber reaches a high wanted level (`Config.BountySettings.wantedLevelThreshold`), a bounty is automatically placed on them.
*   **Amount:** The bounty starts at a base amount (`Config.BountySettings.baseAmount`) and can increase over time (`increasePerMinute`) up to a maximum (`maxBounty`) as long as the Robber remains wanted and active.
*   **Claiming (Cops):** Cops can claim the bounty on a Robber by arresting them (`Config.BountySettings.claimMethod = "arrest"`). The arresting Cop receives the bounty amount as cash.
*   **Duration & Cooldown:** Bounties stay active for a set duration (`durationMinutes`). If a bounty is claimed or expires, there's a cooldown (`cooldownMinutes`) before a new bounty can be placed on the same player.
*   **Visibility:** Cops can view active bounties via the Bounty Board. All players are usually notified when a bounty is placed or claimed.

## Administrative Features (For Server Admins)

Server administrators have access to tools to help manage the game and players.

*   **Admin Panel:**
    *   **Key to Toggle:** `F10` (or as per `Config.Keybinds.toggleAdminPanel`).
    *   **Purpose:** Provides a NUI interface for admins to manage players (e.g., view player lists, potentially kick, ban, teleport, or other actions). Access is restricted to players whose identifiers are listed in `Config.Admins`.
*   **Moderation Tools:**
    *   Admins can typically **freeze** or **unfreeze** players.
    *   Admins can often **teleport** themselves to players or teleport players to specific locations.
    *   **Banning:** Admins can ban players from the server. Bans are recorded in `bans.json` and can be based on identifiers like Steam ID or license.
*   **Chat Commands:** While not explicitly listed in the reviewed files, servers may have additional chat-based admin commands for various functions like setting roles, giving XP, or managing server settings. Consult your server administrator for details on available commands.

*(Note: Access to these features is strictly limited to authorized administrators.)*

## Frequently Asked Questions (FAQ)

**Q: How do I choose my role?**
A: When you first join the server or after spawning, a menu should appear allowing you to select between Cop, Robber, or Citizen roles.

**Q: How do I make money as a Cop?**
A: Cops primarily earn money by:
*   Successfully arresting wanted Robbers (you may receive a portion of their impounded cash or a direct reward).
*   Claiming bounties on Robbers by arresting them.

**Q: How do I make money as a Robber?**
A: Robbers have several ways to make money:
*   Successfully robbing stores.
*   Completing armored car heists.
*   Successfully completing bank heists.
*   Collecting valuable items from contraband drops.

**Q: What happens when I get arrested?**
A: If you are a Robber and get arrested by a Cop, you will be sent to jail for a period determined by your wanted level. Your wanted level will be cleared upon release. While in jail, your actions are restricted.

**Q: How can I reduce my wanted level as a Robber?**
A: You can reduce your wanted level by:
*   Avoiding new crimes and Cops, allowing it to decay over time.
*   Paying a "Shady Contact" (Corrupt Official) to clear your stars.
*   Using an "Appearance Change Store" to lower your wanted points.
*   Getting arrested will clear your wanted level upon release from jail.

**Q: How do I get better weapons/gear?**
A: Better weapons and gear are obtained by:
*   **Leveling Up:** Gaining XP in your role (Cop or Robber) will unlock access to more advanced items.
*   **Purchasing from Stores:**
    *   Cops can buy police-specific equipment from the "Cop Store."
    *   Robbers can buy weapons and tools from "Black Market Dealers" or "Gang Suppliers."
    *   Ammu-Nations sell a general selection of firearms.
    *   Access to items in stores is often restricted by your current level and role.

**Q: What are perks and how do I get them?**
A: Perks are passive bonuses that enhance your abilities. They are automatically unlocked and applied when you reach specific levels in your chosen role (Cop or Robber). Examples include Cops getting more durable armor or carrying more spike strips, and Robbers collecting contraband faster.

**Q: How do I start a bank heist?**
A: To start a bank heist (as a Robber), you typically need to go to one of the bank locations listed in `Config.BankVaults`. It's assumed you would then interact with a specific point at the bank (likely using the `E` key or a similar on-screen prompt) to begin the heist. Make sure enough Cops are online as per server requirements.

**Q: My vehicle got EMP'd, what do I do?**
A: If your vehicle is hit by an EMP, its engine will be disabled, and it will become undriveable for a short period (usually around 5 seconds, as per `Config.EMPDisableDurationMs`). You'll have to wait for the effect to wear off before you can drive it again.

**Q: Why can't I buy a specific item from a store?**
A: There are several reasons why you might not be able to buy an item:
*   **Not Enough Money:** You don't have enough cash.
*   **Level Restriction:** The item may require a higher level in your current role (Cop or Robber).
*   **Role Restriction:** Some items are exclusive to Cops (e.g., K9 Whistle, certain police weapons) or Robbers.
*   **Store Stock/Type:** The specific store you are at might not sell that item. Check different vendors.

---

*A Note on Server Variations: This guide is based on the general structure and configuration files of the Cops and Robbers resource. Specific servers may have customized settings, additional rules, or modified features. Always check for server-specific information or announcements provided by the server administrators.*

*The mechanism for initiating Bank Heists is assumed to be an interaction at the bank locations, as specific client-side initiation code for this was not explicitly detailed in the reviewed core script files. Please verify on your specific server.*

We hope this guide helps you enjoy your time playing Cops and Robbers!
