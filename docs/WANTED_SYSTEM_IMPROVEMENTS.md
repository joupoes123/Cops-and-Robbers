# Wanted Level System Improvements

## Overview
The wanted level system has been completely overhauled to fix critical issues and ensure it only applies to robbers, not cops. The system is now entirely server-side managed for consistency and security.

## Issues Fixed

### 1. **Client-Side Wanted System Removed**
- **Problem**: The old client-side wanted level detection system (lines 610-683 in client.lua) applied to ALL players regardless of role, causing cops to get wanted levels from speeding.
- **Solution**: Completely removed the conflicting client-side wanted level detection thread and replaced it with server-side only detection.

### 2. **Role-Specific Enforcement**
- **Problem**: No role checks in the wanted system - cops could get wanted levels.
- **Solution**: All crime detection now includes `IsPlayerRobber()` checks to ensure only robbers can get wanted levels.

### 3. **Server-Side Crime Detection**
- **Problem**: Inconsistent crime detection and dual systems causing conflicts.
- **Solution**: Implemented comprehensive server-side crime detection for:
  - **Speeding**: Monitors robber vehicle speeds and applies wanted levels after sustained speeding
  - **Hit-and-Run**: Detects vehicle damage while moving at speed
  - **Weapon Discharge**: Detects when robbers fire weapons in public
  - **Restricted Area Entry**: Monitors entry into Fort Zancudo, Humane Labs, etc.
  - **Assault/Murder**: Detects damage dealt to other players (cops vs civilians)

### 4. **Improved Data Management**
- **Problem**: No cleanup of tracking data when players disconnect.
- **Solution**: Added comprehensive cleanup in `playerDropped` handler for all tracking tables.

## New Features

### 1. **Enhanced Speeding Detection**
```lua
-- Server-side speeding detection for robbers only
- Tracks speeding state per player
- 5-second grace period before violation
- 10-second cooldown between violations
- Excludes aircraft and boats
- Configurable speed limit via Config.SpeedLimitMph
```

### 2. **Hit-and-Run Detection**
```lua
-- Monitors vehicle health changes while moving
- Detects significant damage (>50 health) while moving >20 mph
- 3-second cooldown to prevent spam
- Only applies to robbers in vehicles
```

### 3. **Weapon Discharge Monitoring**
```lua
-- Client-side detection, server-side processing
- Detects when players fire weapons
- Server checks if player is robber before applying wanted level
- 1-second cooldown to prevent spam
```

### 4. **Restricted Area System**
```lua
-- Monitors configured restricted areas
- Fort Zancudo, Humane Labs, Prison Grounds
- Shows warning messages
- Applies appropriate wanted points
- Respects ifNotRobber flag for area-specific rules
```

### 5. **Assault/Murder Detection**
```lua
-- Monitors player health changes
- Differentiates between assault and murder
- Higher penalties for attacking cops vs civilians
- Tracks damage source and weapon used
```

## Configuration

### Crime Points (config.lua)
All crimes are properly configured with appropriate point values:
```lua
speeding                   = 2,    -- Speeding violations
hit_and_run               = 5,    -- Vehicle collisions while fleeing
weapons_discharge         = 3,    -- Firing weapons in public
restricted_area_entry     = 12,   -- Entering restricted areas
assault_civilian          = 6,    -- Assaulting civilians
assault_cop              = 18,   -- Assaulting police officers
murder_civilian          = 15,   -- Killing civilians
murder_cop               = 30,   -- Killing police officers
```

### Restricted Areas (config.lua)
```lua
Config.RestrictedAreas = {
    { name = "Fort Zancudo", center = vector3(-2177.0, 3210.0, 32.0), radius = 400.0, wantedPoints = 40, minStars = 3 },
    { name = "Humane Labs", center = vector3(3615.0, 3740.0, 28.0), radius = 300.0, wantedPoints = 25, minStars = 2 },
    { name = "Prison Grounds", center = Config.PrisonLocation, radius = 200.0, wantedPoints = 15, minStars = 1, ifNotRobber = true }
}
```

## Testing

### Admin Test Command
```
/testwanted <crime_key>
```
- Admin-only command to test wanted level increases
- Must be used while playing as a robber
- Accepts any valid crime key from config

### Example Usage
```
/testwanted speeding
/testwanted weapons_discharge
/testwanted restricted_area_entry
```

## Technical Details

### Server-Side Threads
1. **Crime Detection Thread**: Runs every 1 second, monitors all active robbers for speeding and hit-and-run
2. **Restricted Area Thread**: Runs every 2 seconds, monitors robber positions against configured restricted areas
3. **Wanted Level Decay Thread**: Existing system, runs every 30 seconds for wanted level decay

### Event Handlers
1. **cnr:weaponFired**: Handles weapon discharge detection
2. **cnr:playerDamaged**: Handles assault/murder detection
3. **playerDropped**: Cleans up all tracking data

### Data Structures
```lua
playerSpeedingData[playerId] = {
    isCurrentlySpeeding = false,
    speedingStartTime = 0,
    lastSpeedingViolation = 0
}

playerVehicleData[playerId] = {
    lastVehicle = vehicle,
    lastVehicleHealth = health,
    lastCollisionCheck = time
}

playerRestrictedAreaData[playerId] = {
    ["Fort Zancudo"] = true,  -- Player has entered this area
    ["Humane Labs"] = false   -- Player has not entered this area
}
```

## Benefits

1. **Role Enforcement**: Only robbers can get wanted levels
2. **Server Authority**: All crime detection is server-side, preventing client-side manipulation
3. **Comprehensive Detection**: Multiple crime types are automatically detected
4. **Performance Optimized**: Efficient threading and data management
5. **Configurable**: All crime points and areas are easily configurable
6. **Clean Separation**: Clear distinction between cop and robber gameplay

## Compatibility

- Fully backward compatible with existing wanted level configurations
- Existing crime reporting systems (like cop commands) continue to work
- UI and notification systems remain unchanged
- All existing wanted level thresholds and star calculations preserved

## Additional Features Implemented

### 6. **Advanced Wanted Level Decay**
```lua
-- Cop sight detection system
- Pauses wanted level decay when cops are within 50 meters
- Configurable cop sight distance and cooldown
- Realistic "heat" system where criminals must avoid police to lose wanted level
```

### 7. **Role Change Protection**
```lua
-- Automatic wanted level clearing
- When switching from robber to cop, wanted level is immediately cleared
- Prevents cops from having wanted levels
- Updates all police blips and notifications
```

### 8. **Enhanced Event Synchronization**
```lua
-- Fixed missing client-side handlers
- Added cnr:wantedLevelSync event handler
- Proper synchronization between server and client
- Consistent UI updates across all systems
```

### 9. **GTA Native System Suppression**
```lua
-- Complete override of GTA's wanted system
- Suppresses native wanted levels for all players
- Prevents conflicts between systems
- Uses only custom wanted level implementation
```

## Commands

### Admin Commands
```
/testwanted <crime_key>
```
- Admin-only command to test wanted level increases
- Must be used while playing as a robber
- Accepts any valid crime key from config

### Cop Commands
```
/reportcrime <player_id> <crime_key>
```
- Cop-only command to report witnessed crimes
- Allows manual crime reporting for situations not automatically detected
- Validates target is a robber before applying wanted level

### Example Usage
```
/testwanted speeding
/testwanted weapons_discharge
/reportcrime 5 speeding
/reportcrime 12 assault_civilian
```

## Configuration Enhancements

### Cop Sight Detection
```lua
Config.WantedSettings = {
    copSightCooldownMs = 20000, -- 20 seconds out of sight before decay resumes
    copSightDistance = 50.0,    -- 50 meters detection range
    -- ... other settings
}
```

### Crime Detection Intervals
```lua
-- Server-side detection frequencies
Speeding Detection: Every 1 second
Restricted Areas: Every 2 seconds  
Wanted Level Decay: Every 30 seconds (configurable)
```

## Future Enhancements

Potential additions for future updates:
1. **Vehicle Theft Detection**: Monitor when robbers enter vehicles they don't own
2. **Property Damage**: Detect destruction of props and environment
3. **Trespassing**: Monitor entry into private properties
4. **Gang Territory**: Area-based crime multipliers
5. **Advanced AI Response**: Dynamic NPC police response based on wanted level
6. **Crime Witness System**: Civilians can report crimes they witness
7. **Undercover Cops**: Special cop mode that doesn't trigger cop sight detection