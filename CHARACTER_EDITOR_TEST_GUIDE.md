# Character Editor - Testing Guide

## Issues Fixed in This Update

### ✅ 1. Preview Screen Behind Menu
**Problem**: Character preview was rendering behind the UI menu
**Solution**: 
- Made character editor background transparent
- Adjusted z-index values
- Changed layout to sidebar design
- Character should now be visible on the left, UI controls on the right

### ✅ 2. Mission Row PD Darkness
**Problem**: `SetArtificialLightsState(true)` was making interiors dark
**Solution**: 
- Removed global lighting changes
- Used ped-specific lighting only
- Added proper cleanup when closing editor
- Mission Row PD should now have normal lighting

### ✅ 3. Character Saving Issues
**Problem**: Server validation was failing, characters not saving
**Solution**:
- Added all required character data fields with defaults
- Improved server-side error reporting
- Added client-side save result handling
- Enhanced character data validation

### ✅ 4. Multiple NUI Message Handlers
**Problem**: Conflicting message handlers causing "Unhandled NUI action" errors
**Solution**:
- Consolidated all character editor actions into main message handler
- Removed duplicate event listeners
- Fixed message routing conflicts

## Testing Steps

### 1. Basic Functionality Test
```
1. Join server as Cop or Robber
2. Press F3 to open character editor
3. Verify character is visible on screen (not behind menu)
4. Verify UI controls appear on the right side
5. Check F8 console for any errors
```

### 2. Character Preview Test
```
1. Open character editor (F3)
2. Use arrow keys to switch camera views:
   - LEFT ARROW: Face view
   - RIGHT ARROW: Body view  
   - UP ARROW: Full body view
3. Verify character is clearly visible in all views
4. Make changes to face/hair/etc and verify they appear immediately
```

### 3. Character Saving Test
```
1. Open character editor
2. Make several changes (face, hair, skin, etc.)
3. Click Save button
4. Check for success message (should be green)
5. Close and reopen editor
6. Verify changes were saved and applied
7. Try saving to slot 2 as well
```

### 4. Lighting Test
```
1. Go inside Mission Row PD
2. Verify interior is properly lit (not dark/dim)
3. Open character editor while inside
4. Close character editor
5. Verify PD lighting returns to normal
```

### 5. Emergency Exit Test
```
1. Open character editor
2. Test all exit methods:
   - ESC key (normal close)
   - Ctrl+F3 (safety close)
   - BACKSPACE (emergency exit)
   - /closechareditor command
   - /fixui command
3. Verify each method properly closes editor and restores control
```

## Expected Results

### Character Preview
- ✅ Character should be visible on the left side of screen
- ✅ UI controls should be on the right side
- ✅ Background should be transparent showing the game world
- ✅ Camera should smoothly switch between face/body/full views

### Character Saving
- ✅ Save button should show "Saving character..." message
- ✅ Success should show green "Character saved successfully" message
- ✅ Failure should show red error message with specific reason
- ✅ Saved characters should persist between sessions

### Lighting
- ✅ Mission Row PD should have normal interior lighting
- ✅ No dark/dim areas inside buildings
- ✅ Character editor should not affect world lighting

### Console Messages
- ✅ No "Unhandled NUI action" errors
- ✅ No "Failed to save character" errors (unless data is actually invalid)
- ✅ Clear success/failure messages for all operations

## Troubleshooting

### If Character Still Not Visible
1. Check F8 console for camera creation messages
2. Try different camera views with arrow keys
3. Use `/testchareditor` to verify UI elements exist
4. Check if character editor element has proper CSS

### If Saving Still Fails
1. Check server console for specific validation errors
2. Verify all required character data fields are present
3. Check file permissions for player_data directory
4. Look for character save result messages in F8 console

### If Lighting Issues Persist
1. Restart the resource: `/restart cops-and-robbers`
2. Check if other scripts are affecting lighting
3. Verify `SetArtificialLightsState(false)` is being called on cleanup

### If UI Conflicts Continue
1. Check for multiple message handlers in F8 console
2. Verify only one character editor instance is running
3. Clear browser cache if using NUI devtools

## Commands for Testing

```
/chareditor cop 1          # Manually open character editor for cop slot 1
/chareditor robber 2       # Manually open character editor for robber slot 2
/testchareditor           # Test if character editor UI elements exist
/closechareditor          # Force close character editor
/fixui                    # Fix stuck UI/mouse cursor
```

## File Changes Made

### Client-Side (`character_editor_client.lua`)
- Fixed camera system with proper positioning and lighting
- Removed safety timeout, added Ctrl+F3 safety close
- Enhanced character data validation and saving
- Added server save result handling
- Improved error handling and logging

### UI-Side (`html/scripts.js`)
- Consolidated message handlers to prevent conflicts
- Enhanced error reporting and feedback
- Improved character editor opening/closing logic

### Styling (`html/styles.css`)
- Made character editor background transparent
- Adjusted z-index for proper layering
- Added sidebar layout for better UX

### Server-Side (`character_editor_server.lua`)
- Enhanced character data validation
- Improved error reporting
- Better file handling and persistence

All changes maintain backward compatibility and include comprehensive error handling.