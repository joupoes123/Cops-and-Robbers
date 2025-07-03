# Cops and Robbers - Testing Guide

## Version: 1.2.0

This guide provides comprehensive testing procedures to validate the refactored systems and ensure everything is working correctly.

---

## 🧪 Pre-Testing Setup

### 1. Backup Original Data
```bash
# Create backup of existing player data
cp -r player_data/ player_data_backup/
cp bans.json bans_backup.json
cp purchase_history.json purchase_history_backup.json
```

### 2. Server Console Commands for Testing

Add these commands to your server console for testing:

```lua
-- Test system status
/cnr_status

-- Test player data integrity
/cnr_validate_player [player_id]

-- Test performance metrics
/cnr_performance

-- Test security validation
/cnr_test_security [player_id]
```

---

## 🔒 Security Testing

### 1. Rate Limiting Tests

**Test Rapid Purchase Attempts:**
```lua
-- This should be blocked after the rate limit
for i = 1, 25 do
    TriggerServerEvent('cops_and_robbers:buyItem', 'weapon_pistol', 1)
end
```

**Expected Result:** After 20 purchases per minute, additional attempts should be blocked with rate limiting message.

### 2. Input Validation Tests

**Test Invalid Quantities:**
```lua
-- These should all be rejected
TriggerServerEvent('cops_and_robbers:buyItem', 'weapon_pistol', -1)     -- Negative quantity
TriggerServerEvent('cops_and_robbers:buyItem', 'weapon_pistol', 0)      -- Zero quantity
TriggerServerEvent('cops_and_robbers:buyItem', 'weapon_pistol', 9999)   -- Excessive quantity
TriggerServerEvent('cops_and_robbers:buyItem', 'invalid_item', 1)       -- Invalid item
```

**Expected Result:** All attempts should be rejected with appropriate error messages.

### 3. Role Validation Tests

**Test Role-Restricted Items:**
```lua
-- As a robber, try to buy cop-only items
TriggerServerEvent('cops_and_robbers:buyItem', 'weapon_stungun', 1)
```

**Expected Result:** Purchase should be rejected with role restriction message.

### 4. Duplication Prevention Tests

**Test Rapid Inventory Operations:**
```lua
-- Rapid fire the same purchase (should be prevented by transaction system)
for i = 1, 10 do
    TriggerServerEvent('cops_and_robbers:buyItem', 'weapon_pistol', 1)
    TriggerServerEvent('cops_and_robbers:sellItem', 'weapon_pistol', 1)
end
```

**Expected Result:** Only one transaction should process at a time, preventing duplication.

---

## ⚡ Performance Testing

### 1. Memory Usage Monitoring

**Check Memory Growth:**
```lua
-- Monitor memory usage over time
/cnr_performance
-- Wait 5 minutes
/cnr_performance
-- Memory usage should be stable, not continuously growing
```

### 2. Loop Performance Testing

**Check Optimized Loops:**
```lua
-- All loops should automatically adjust their intervals based on server load
-- Monitor console for performance warnings
```

### 3. Event Batching Testing

**Test Event Batching:**
```lua
-- Generate multiple events rapidly
for i = 1, 100 do
    TriggerClientEvent('test_event', -1, {data = i})
end
-- Events should be batched and sent efficiently
```

---

## 💾 Data Persistence Testing

### 1. Save/Load Integrity

**Test Player Data Persistence:**
```lua
-- 1. Join server, buy items, earn money
-- 2. Disconnect
-- 3. Reconnect
-- 4. Verify all data is preserved
```

### 2. Backup System Testing

**Test Backup Creation:**
```lua
-- Check that backups are created automatically
-- Look for backup files in the backups/ directory
```

### 3. Data Migration Testing

**Test Version Migration:**
```lua
-- Simulate old data format and verify migration works
-- Check console for migration messages
```

---

## 🎮 Gameplay Testing

### 1. Purchase/Sale System

**Test Normal Operations:**
```lua
-- 1. Buy various items as different roles
-- 2. Sell items back to stores
-- 3. Verify money calculations are correct
-- 4. Check inventory updates properly
```

### 2. Role System Testing

**Test Role Changes:**
```lua
-- 1. Change from civilian to cop
-- 2. Verify role-specific items become available
-- 3. Change to robber
-- 4. Verify cop items are no longer available
```

### 3. Inventory System Testing

**Test Inventory Operations:**
```lua
-- 1. Fill inventory to capacity
-- 2. Try to add more items (should be rejected)
-- 3. Use/drop items
-- 4. Verify inventory syncs properly
```

---

## 🔧 System Integration Testing

### 1. Module Loading

**Check All Modules Load:**
```lua
-- Check console for initialization messages:
-- [CNR_VALIDATION] Validation System initialized
-- [CNR_DATA_MANAGER] Data Manager initialized
-- [CNR_SECURE_INVENTORY] Secure Inventory System initialized
-- [CNR_SECURE_TRANSACTIONS] Secure Transactions System initialized
-- [CNR_PLAYER_MANAGER] Player Manager initialized
-- [CNR_PERFORMANCE] Performance Optimizer initialized
-- [CNR_INTEGRATION] System initialization completed
```

### 2. Legacy Compatibility

**Test Legacy Function Calls:**
```lua
-- These should still work but use new secure systems
AddItemToPlayerInventory(playerId, 'weapon_pistol', 1)
RemoveItemFromPlayerInventory(playerId, 'weapon_pistol', 1)
AddPlayerMoney(playerId, 1000)
RemovePlayerMoney(playerId, 500)
```

---

## 📊 Monitoring and Logging

### 1. Performance Metrics

**Check Performance Stats:**
```lua
-- Look for these log entries every 10 minutes:
-- [CNR_PERFORMANCE] Stats - Memory: XXXkB, Threads: X, Loops: X, Batches: X
-- [CNR_DATA_MANAGER] Stats - Total: X, Failed: X, Success Rate: XX%
-- [CNR_SECURE_INVENTORY] Stats - Operations: X, Failed: X, Duplicates: X
-- [CNR_SECURE_TRANSACTIONS] Stats - Total: X, Success: X, Failed: X
-- [CNR_PLAYER_MANAGER] Stats - Loads: X, Saves: X
```

### 2. Error Monitoring

**Check for Errors:**
```lua
-- Monitor console for any error messages
-- All errors should be properly logged with context
-- No critical errors should occur during normal operation
```

---

## 🚨 Stress Testing

### 1. High Player Load

**Test with Multiple Players:**
```lua
-- Have 10+ players simultaneously:
-- 1. Buying/selling items
-- 2. Changing roles
-- 3. Moving around the map
-- 4. Using inventory
-- Monitor performance and stability
```

### 2. Rapid Operations

**Test Rapid Fire Operations:**
```lua
-- Have players rapidly:
-- 1. Open/close inventory
-- 2. Buy/sell items
-- 3. Change roles
-- System should handle gracefully without crashes
```

---

## ✅ Success Criteria

### Security:
- [ ] Rate limiting prevents spam attacks
- [ ] Input validation rejects invalid data
- [ ] Role restrictions are enforced
- [ ] No item duplication possible
- [ ] No money manipulation possible

### Performance:
- [ ] Memory usage remains stable
- [ ] No performance warnings under normal load
- [ ] Event batching reduces network traffic
- [ ] Optimized loops adapt to server load

### Data Persistence:
- [ ] Player data saves/loads correctly
- [ ] Backups are created automatically
- [ ] Data migration works properly
- [ ] No data corruption occurs

### Integration:
- [ ] All modules load successfully
- [ ] Legacy functions work with new systems
- [ ] No conflicts between old and new code
- [ ] Smooth transition for existing players

---

## 🐛 Troubleshooting

### Common Issues:

**Module Loading Errors:**
```lua
-- Check script loading order in fxmanifest.lua
-- Ensure all dependencies are loaded first
```

**Performance Issues:**
```lua
-- Check performance metrics
-- Look for memory leaks or excessive loop execution times
-- Verify optimized loops are working correctly
```

**Data Issues:**
```lua
-- Check backup files exist
-- Verify data migration completed
-- Look for data validation errors
```

**Security Issues:**
```lua
-- Verify validation system is active
-- Check rate limiting is working
-- Ensure transaction system prevents exploits
```

---

## 📝 Test Results Template

```
=== CNR REFACTORING TEST RESULTS ===
Date: ___________
Tester: ___________
Server Version: 1.2.0

SECURITY TESTS:
[ ] Rate Limiting: PASS/FAIL
[ ] Input Validation: PASS/FAIL  
[ ] Role Restrictions: PASS/FAIL
[ ] Duplication Prevention: PASS/FAIL

PERFORMANCE TESTS:
[ ] Memory Stability: PASS/FAIL
[ ] Loop Optimization: PASS/FAIL
[ ] Event Batching: PASS/FAIL

DATA PERSISTENCE TESTS:
[ ] Save/Load Integrity: PASS/FAIL
[ ] Backup System: PASS/FAIL
[ ] Data Migration: PASS/FAIL

INTEGRATION TESTS:
[ ] Module Loading: PASS/FAIL
[ ] Legacy Compatibility: PASS/FAIL
[ ] System Integration: PASS/FAIL

OVERALL RESULT: PASS/FAIL

NOTES:
_________________________________
_________________________________
_________________________________
```

---

## 🔄 Rollback Procedure

If issues are found during testing:

1. **Stop the server**
2. **Restore backups:**
   ```bash
   cp -r player_data_backup/ player_data/
   cp bans_backup.json bans.json
   cp purchase_history_backup.json purchase_history.json
   ```
3. **Revert to original scripts** (if needed)
4. **Restart server**
5. **Report issues** for investigation

---

## 📞 Support

For issues or questions regarding the refactored systems:

1. Check the console logs for detailed error messages
2. Review the REFACTORING_SUMMARY.md for implementation details
3. Use the built-in monitoring and statistics systems
4. Test in a development environment before production deployment

Remember: Always test thoroughly in a development environment before deploying to production!