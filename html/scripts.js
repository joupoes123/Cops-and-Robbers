// html/scripts.js
// Handles NUI interactions for Cops and Robbers game mode.

window.cnrResourceName = 'cops-and-robbers'; // Default fallback, updated by Lua
let fullItemConfig = null; // Will store Config.Items

// Inventory state variables
let isInventoryOpen = false;
let currentInventoryData = null;
let currentEquippedItems = null;

// Jail Timer UI elements
const jailTimerContainer = document.getElementById('jail-timer-container');
const jailTimeRemainingElement = document.getElementById('jail-time-remaining');

// ====================================================================
// NUI Message Handling & Security
// ====================================================================
const allowedOrigins = [
    `nui://cops-and-robbers`,
    "http://localhost:3000", // For local development if applicable
    "nui://game" // General game NUI origin
];

window.addEventListener('message', function(event) {
    const currentResourceOrigin = `nui://${window.cnrResourceName || 'cops-and-robbers'}`;
    if (!allowedOrigins.includes(event.origin) && event.origin !== currentResourceOrigin) {
        console.warn(`Security: Received message from untrusted origin: ${event.origin}. Expected: ${currentResourceOrigin} or predefined. Ignoring.`);
        return;
    }
  
    const data = event.data;
  
    switch (data.action) {
        case 'showRoleSelection':
            if (data.resourceName) {
                window.cnrResourceName = data.resourceName;
                if (!allowedOrigins.includes(`nui://${window.cnrResourceName}`)) {
                    allowedOrigins.push(`nui://${window.cnrResourceName}`);
                }
            }
            showRoleSelection();
            break;        case 'updateMoney':
            // Update cash display dynamically when money changes
            if (typeof data.cash === 'number') {
                const playerCashEl = document.getElementById('player-cash-amount');
                if (playerCashEl) {
                    playerCashEl.textContent = `$${data.cash.toLocaleString()}`;
                    console.log('[CNR_NUI_DEBUG] updateMoney - Updated cash display to:', `$${data.cash.toLocaleString()}`);
                }
                
                // Show cash notification if cash changed and store is open
                const storeMenuElement = document.getElementById('store-menu');
                if (storeMenuElement && storeMenuElement.style.display === 'block' && previousCash !== null && previousCash !== data.cash) {
                    console.log('[CNR_NUI_DEBUG] Cash changed from', previousCash, 'to', data.cash);
                    showCashNotification(data.cash, previousCash);
                }
                
                // Update stored values
                previousCash = data.cash;
                if (window.playerInfo) {
                    window.playerInfo.cash = data.cash;
                }
            }
            break;case 'showStoreMenu':        case 'openStore':
            if (data.resourceName) {
                window.cnrResourceName = data.resourceName;
                const currentResourceOriginDynamic = `nui://${window.cnrResourceName}`;
                if (!allowedOrigins.includes(currentResourceOriginDynamic)) {
                    allowedOrigins.push(currentResourceOriginDynamic);
                }
            }
            openStoreMenu(data.storeName, data.items, data.playerInfo);
            break;        case 'updateStoreData':
            console.log('[CNR_NUI] Received updateStoreData with', data.items ? data.items.length : 0, 'items');
            if (data.items && data.items.length > 0) {
                // Update the current store data
                window.items = data.items; // Fix: Set window.items so loadGridItems() can access it
                window.currentStoreItems = data.items;
                window.playerInfo = data.playerInfo; // Fix: Set window.playerInfo for level checks
                window.currentPlayerInfo = data.playerInfo;
                console.log('[CNR_NUI_DEBUG] Updated window.items with', data.items.length, 'items');
                console.log('[CNR_NUI_DEBUG] Sample item IDs:', data.items.slice(0, 3).map(item => item.itemId).join(','));
                console.log('[CNR_NUI_DEBUG] Current tab before refresh:', window.currentTab);
                // Refresh the currently displayed tab
                if (window.currentTab === 'buy') {
                    console.log('[CNR_NUI_DEBUG] Calling loadGridItems() for Buy tab refresh');
                    loadGridItems(); // Fix: Call without parameters
                } else if (window.currentTab === 'sell') {
                    console.log('[CNR_NUI_DEBUG] Calling loadSellItems() for Sell tab refresh');
                    loadSellItems();
                }
            } else {
                console.warn('[CNR_NUI] updateStoreData called with no items or empty items array');
            }
            break;
        case 'buyResult':
            if (data.success) {
                showToast(data.message || 'Purchase successful!', 'success');
                // Refresh the sell tab in case new items were added to inventory
                if (window.currentTab === 'sell') {
                    loadSellItems();
                }
            } else {
                showToast(data.message || 'Purchase failed!', 'error');
            }
            break;
        case 'sellResult':
            if (data.success) {
                showToast(data.message || 'Sale successful!', 'success');
                // Refresh the sell tab to update inventory
                if (window.currentTab === 'sell') {
                    loadSellItems();
                }
            } else {
                showToast(data.message || 'Sale failed!', 'error');
            }
            break;
        case 'closeStore':
            closeStoreMenu();
            break;
        case 'startHeistTimer':
            startHeistTimer(data.duration, data.bankName);
            break;        case 'updateXPBar':
            updateXPDisplayElements(data.currentXP, data.currentLevel, data.xpForNextLevel, data.xpGained);
            break;
        case 'refreshSellListIfNeeded':
            // console.log("[CNR_NUI] Received refreshSellListIfNeeded. Calling loadSellItems().");
            const storeMenu = document.getElementById('store-menu');
            if (storeMenu && storeMenu.style.display === 'block' && window.currentTab === 'sell') {
                loadSellItems();
            }
            break;
        case 'showAdminPanel':
            if (data.resourceName) {
                window.cnrResourceName = data.resourceName;
                 if (!allowedOrigins.includes(`nui://${window.cnrResourceName}`)) {
                    allowedOrigins.push(`nui://${window.cnrResourceName}`);
                }
            }
            showAdminPanel(data.players);
            break;        case 'showBountyBoard':
            if (data.resourceName) {
                window.cnrResourceName = data.resourceName;
                if (!allowedOrigins.includes(`nui://${window.cnrResourceName}`)) {
                    allowedOrigins.push(`nui://${window.cnrResourceName}`);
                }
            }
            if (typeof showBountyBoardUI === 'function') showBountyBoardUI(data.bounties);
            break;
        case 'hideBountyBoard':
             if (typeof hideBountyBoardUI === 'function') hideBountyBoardUI();
            break;
        case 'updateBountyList':
             if (typeof updateBountyListUI === 'function') updateBountyListUI(data.bounties);
            break;        case 'showBountyList':
            showBountyList(data.bounties || []);
            break;
        case 'updateSpeedometer':
            updateSpeedometer(data.speed);
            break;
        case 'toggleSpeedometer':
            toggleSpeedometer(data.show);
            break;
        case 'hideRoleSelection':
            const roleMenu = document.getElementById('roleSelectionMenu');
            if (roleMenu) roleMenu.style.display = 'none';            break;
        case 'roleSelectionFailed':
            showToast(data.error || 'Failed to select role. Please try again.', 'error', 4000);
            showRoleSelection();
            break;
        case 'storeFullItemConfig':
            if (data.itemConfig) {
                window.fullItemConfig = data.itemConfig;
                console.log('[CNR_NUI] Stored full item config. Item count:', window.fullItemConfig ? Object.keys(window.fullItemConfig).length : 0);
                
                // Fix any missing item images by setting default images
                for (const itemId in window.fullItemConfig) {
                    if (window.fullItemConfig.hasOwnProperty(itemId)) {
                        const item = window.fullItemConfig[itemId];
                        
                        // Check if image is missing or invalid
                        if (!item.image || item.image.includes('404') || item.image === 'img/default.png') {
                            // Set default image based on category
                            switch (item.category) {
                                case 'weapons':
                                    item.image = 'img/items/weapon_pistol.png';
                                    break;
                                case 'ammo':
                                    item.image = 'img/items/ammo.png';
                                    break;
                                case 'armor':
                                    item.image = 'img/items/armor.png';
                                    break;
                                case 'tools':
                                    item.image = 'img/items/tool.png';
                                    break;
                                default:
                                    item.image = 'img/items/default.png';
                                    break;
                            }
                            console.log(`[CNR_NUI] Fixed missing image for item ${itemId}`);
                        }
                    }
                }
                
                // Refresh the store if it's open
                const storeMenuElement = document.getElementById('store-menu');
                if (storeMenuElement && storeMenuElement.style.display === 'block') {
                    if (window.currentTab === 'buy') {
                        loadGridItems();
                    } else if (window.currentTab === 'sell') {
                        loadSellItems();
                    }
                }
            }
            break;        case 'refreshInventory':
            // Refresh the sell tab if it's currently active
            const storeMenuElement = document.getElementById('store-menu');
            if (storeMenuElement && storeMenuElement.style.display === 'block' && window.currentTab === 'sell') {
                loadSellItems();
            }
            break;        case 'showWantedNotification':
            showWantedNotification(data.stars, data.points, data.level);
            break;        case 'hideWantedNotification':
            hideWantedNotification();
            break;
        case 'openInventory':
        case 'closeInventory':
        case 'updateInventory':
        case 'updateEquippedItems':
            handleInventoryMessage(data);
            break;
        case 'showRobberMenu':
            showRobberMenu();
            break;
        // Jail Timer UI Logic
        case 'showJailTimer':
            if (jailTimerContainer && jailTimeRemainingElement) {
                jailTimeRemainingElement.textContent = formatJailTime(data.initialTime || 0);
                jailTimerContainer.classList.remove('hidden');
                console.log("Jail timer UI shown with initial time:", data.initialTime);
            } else {
                console.error("Jail timer elements not found in HTML.");
            }
            break;
        case 'updateJailTimer':
            if (jailTimerContainer && jailTimeRemainingElement && !jailTimerContainer.classList.contains('hidden')) {
                jailTimeRemainingElement.textContent = formatJailTime(data.time || 0);
            }
            break;
        case 'hideJailTimer':
            if (jailTimerContainer) {
                jailTimerContainer.classList.add('hidden');
                console.log("Jail timer UI hidden.");
            }
            break;
        case 'openCharacterEditor':
            openCharacterEditor(data);
            break;
        case 'closeCharacterEditor':
            closeCharacterEditor();
            break;
        case 'updateCharacterSlot':
            updateCharacterSlot(data.characterKey, data.characterData);
            break;
        case 'testCharacterEditor':
            console.log('[CNR_CHARACTER_EDITOR] Test message received');
            const testEditor = document.getElementById('character-editor');
            if (testEditor) {
                console.log('[CNR_CHARACTER_EDITOR] Character editor element found');
                fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_test_result`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ 
                        success: true, 
                        message: 'Character editor element exists',
                        elementFound: true
                    })
                });
            } else {
                console.error('[CNR_CHARACTER_EDITOR] Character editor element NOT found');
                fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_test_result`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ 
                        success: false, 
                        message: 'Character editor element missing',
                        elementFound: false
                    })
                });
            }
            break;
        default:
            console.warn(`Unhandled NUI action: ${data.action}`);
    }
});

// Helper function to format seconds into MM:SS
function formatJailTime(totalSeconds) {
    if (isNaN(totalSeconds) || totalSeconds < 0) {
        totalSeconds = 0;
    }
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

// NUI Focus Helper Function (remains unchanged)
async function fetchSetNuiFocus(hasFocus, hasCursor) {
    try {
        const resName = window.cnrResourceName || 'cops-and-robbers';
        await fetch(`https://${resName}/setNuiFocus`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ hasFocus: hasFocus, hasCursor: hasCursor })
        });
    } catch (error) {
        const resNameForError = window.cnrResourceName || 'cops-and-robbers';
        console.error(`Error calling setNuiFocus NUI callback (URL attempted: https://${resNameForError}/setNuiFocus):`, error);
    }
}

// Enhanced XP Display with Animation and Auto-Hide
let xpDisplayTimeout;
let currentXP = 0;
let currentLevel = 1;
let currentNextLvlXP = 100;

function updateXPDisplayElements(xp, level, nextLvlXp, xpGained = null) {
    const levelTextElement = document.getElementById('level-text');
    const xpTextElement = document.getElementById('xp-text');
    const xpBarFillElement = document.getElementById('xp-bar-fill');
    const xpLevelContainer = document.getElementById('xp-level-container');
    const xpGainIndicator = document.getElementById('xp-gain-indicator');

    // Store previous values to detect changes
    const previousXP = currentXP;
    const previousLevel = currentLevel;
    
    // Update current values
    currentXP = xp;
    currentLevel = level;
    currentNextLvlXP = nextLvlXp;

    // Calculate XP gained if not provided
    if (xpGained === null && previousXP !== 0) {
        xpGained = currentXP - previousXP;
    }    // Only show XP bar if there's actual XP gain or level change
    const shouldShow = xpGained !== null && (xpGained > 0 || previousLevel !== currentLevel);
    
    if (!shouldShow) {
        console.log('[CNR_NUI] No XP change detected, not showing XP bar');
        return;
    }

    // Show XP bar with slide-in animation
    if (xpLevelContainer) {
        xpLevelContainer.style.display = 'flex';
        xpLevelContainer.classList.remove('hide');
        xpLevelContainer.classList.add('show');
        console.log('[CNR_NUI] Showing XP bar with animation');
    }

    // Update level text with animation if level changed
    if (levelTextElement) {
        if (level !== previousLevel && previousLevel !== 0) {
            // Level up animation
            levelTextElement.style.transition = 'transform 0.5s ease-out, color 0.5s ease-out';
            levelTextElement.style.transform = 'scale(1.2)';
            levelTextElement.style.color = '#4CAF50';
            setTimeout(() => {
                levelTextElement.style.transform = 'scale(1)';
                levelTextElement.style.color = '#e94560';
            }, 500);
            console.log(`[CNR_NUI] Level up animation: ${previousLevel} -> ${level}`);
        }
        levelTextElement.textContent = "LVL " + level;
    }

    // Update XP text
    if (xpTextElement) {
        xpTextElement.textContent = xp + " / " + nextLvlXp + " XP";
    }

    // Animate XP bar fill
    if (xpBarFillElement) {
        let percentage = 0;
        if (typeof nextLvlXp === 'number' && nextLvlXp > 0 && xp < nextLvlXp) {
            percentage = (xp / nextLvlXp) * 100;
        } else if (typeof nextLvlXp !== 'number' || xp >= nextLvlXp) {
            percentage = 100;
        }
        
        // Smooth animation to new percentage
        setTimeout(() => {
            xpBarFillElement.style.width = Math.max(0, Math.min(100, percentage)) + '%';
            console.log(`[CNR_NUI] XP bar animated to ${percentage.toFixed(1)}%`);
        }, 200);
    }

    // Show XP gain indicator if XP was gained
    if (xpGained && xpGained > 0 && xpGainIndicator) {
        xpGainIndicator.textContent = `+${xpGained} XP`;
        xpGainIndicator.style.display = 'block';
        xpGainIndicator.classList.remove('show');
        // Force reflow to restart animation
        xpGainIndicator.offsetHeight;
        xpGainIndicator.classList.add('show');
        
        console.log(`[CNR_NUI] Showing +${xpGained} XP indicator`);
        
        // Remove animation class after animation completes
        setTimeout(() => {
            xpGainIndicator.classList.remove('show');
            xpGainIndicator.style.display = 'none';
        }, 3000);
    }

    // Clear existing timeout
    if (xpDisplayTimeout) {
        clearTimeout(xpDisplayTimeout);
    }

    // Set new timeout to hide XP bar after 10 seconds
    xpDisplayTimeout = setTimeout(() => {
        if (xpLevelContainer) {
            xpLevelContainer.classList.remove('show');
            xpLevelContainer.classList.add('hide');
            
            console.log('[CNR_NUI] Hiding XP bar after 10 seconds');
            
            // Actually hide the element after animation
            setTimeout(() => {
                if (xpLevelContainer.classList.contains('hide')) {
                    xpLevelContainer.style.display = 'none';
                    xpLevelContainer.classList.remove('hide');
                }
            }, 500);
        }
    }, 10000);
}

function showToast(message, type = 'info', duration = 3000) {
    const toast = document.getElementById('toast');
    if (!toast) return;
    toast.textContent = message;
    toast.className = 'toast-notification';
    if (type === 'success') toast.classList.add('success');
    else if (type === 'error') toast.classList.add('error');

    toast.style.display = 'block';
    const fadeOutDelay = duration - 500;
    toast.style.animation = `fadeInNotification 0.5s ease-out, fadeOutNotification 0.5s ease-in ${fadeOutDelay > 0 ? fadeOutDelay : 0}ms forwards`;

    setTimeout(() => {
        toast.style.display = 'none';
        toast.style.animation = '';    }, duration);
}

function showRoleSelection() {
    const roleSelectionUI = document.getElementById('role-selection');
    if (roleSelectionUI) {
        roleSelectionUI.classList.remove('hidden');
        roleSelectionUI.style.display = '';
        document.body.style.backgroundColor = '';
        fetchSetNuiFocus(true, true);
    }
}
function hideRoleSelection() {
    console.log('[CNR_NUI_ROLE] hideRoleSelection called.');
    const roleSelectionUI = document.getElementById('role-selection');
    if (roleSelectionUI) {
        // Force blur on any active NUI element
        if (document.activeElement && typeof document.activeElement.blur === 'function') {
            document.activeElement.blur();
            console.log('[CNR_NUI_ROLE] Blurred active NUI element.');
        }

        roleSelectionUI.classList.add('hidden');
        roleSelectionUI.style.display = 'none'; 
        roleSelectionUI.style.visibility = 'hidden'; // Explicitly set visibility
        console.log('[CNR_NUI_ROLE] roleSelectionUI display set to none and visibility to hidden. Current display:', roleSelectionUI.style.display, 'Visibility:', roleSelectionUI.style.visibility);

        document.body.style.backgroundColor = 'transparent';

        // Temporarily comment out the NUI-side focus call to rely on Lua's SetNuiFocus
        // console.log('[CNR_NUI_ROLE] Attempting fetchSetNuiFocus(false, false) from hideRoleSelection...');
        // fetchSetNuiFocus(false, false);
        // console.log('[CNR_NUI_ROLE] fetchSetNuiFocus(false, false) call from hideRoleSelection TEMPORARILY DISABLED.');
        console.log('[CNR_NUI_ROLE] NUI part of hideRoleSelection complete. Lua (SetNuiFocus) should now take full effect.');

    } else {
        console.error('[CNR_NUI_ROLE] role-selection UI element not found in hideRoleSelection.');
    }
}
function openStoreMenu(storeName, storeItems, playerInfo) {
    console.log('[CNR_NUI_DEBUG] openStoreMenu called with:', { storeName, storeItems, playerInfo });
    
    const storeMenuUI = document.getElementById('store-menu');
    const storeTitleEl = document.getElementById('store-title');
    const playerCashEl = document.getElementById('player-cash-amount');
    const playerLevelEl = document.getElementById('player-level-text');
    
    if (storeMenuUI && storeTitleEl) {
        storeTitleEl.textContent = storeName || 'Store';
        window.items = storeItems || [];
        window.playerInfo = playerInfo || { level: 1, role: "citizen", cash: 0 };
        
        console.log('[CNR_NUI_DEBUG] playerInfo received:', window.playerInfo);
        
        // Handle both property name formats (cash/playerCash, level/playerLevel)
        const newCash = window.playerInfo.cash || window.playerInfo.playerCash || 0;
        const newLevel = window.playerInfo.level || window.playerInfo.playerLevel || 1;
        
        console.log('[CNR_NUI_DEBUG] cash value:', newCash);
        console.log('[CNR_NUI_DEBUG] level value:', newLevel);
        
        // Update player info display and check for cash changes
        if (playerCashEl) {
            playerCashEl.textContent = `$${newCash.toLocaleString()}`;
            console.log('[CNR_NUI_DEBUG] Updated cash display to:', `$${newCash.toLocaleString()}`);
        }
        if (playerLevelEl) playerLevelEl.textContent = `Level ${newLevel}`;
          // Show cash notification if cash changed (only when store is opened)
        if (previousCash !== null && previousCash !== newCash) {
            console.log('[CNR_NUI_DEBUG] Cash changed in store from', previousCash, 'to', newCash);
            showCashNotification(newCash, previousCash);
        }
        previousCash = newCash;
        
        window.currentCategory = null;
        window.currentTab = 'buy';
        loadCategories();
        loadGridItems();
        storeMenuUI.style.display = 'block';
        storeMenuUI.classList.remove('hidden');
        fetchSetNuiFocus(true, true);
    }
}
function closeStoreMenu() {
    const storeMenuUI = document.getElementById('store-menu');
    if (storeMenuUI) {
        storeMenuUI.classList.add('hidden');
        storeMenuUI.style.display = '';
        
        // Notify Lua client that store is closing
        const resName = window.cnrResourceName || 'cops-and-robbers';
        fetch(`https://${resName}/closeStore`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        }).catch(error => {
            console.error('Error calling closeStore callback:', error);
        });
        
        fetchSetNuiFocus(false, false);
    }
}

// Store Tab and Category Management
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        window.currentTab = btn.dataset.tab;
        document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
        const activeTabContent = document.getElementById(`${window.currentTab}-section`);
        if (activeTabContent) activeTabContent.classList.add('active');
        if (window.currentTab === 'sell') loadSellGridItems();
        else loadGridItems();
    });
});

function loadCategories() {
    const categoryList = document.getElementById('category-list');
    if (!categoryList) return;
    const categories = [...new Set((window.items || []).map(item => item.category))];
    categoryList.innerHTML = '';
    
    const allBtn = document.createElement('button');
    allBtn.className = 'category-btn active';
    allBtn.textContent = 'All';
    allBtn.onclick = () => {
        window.currentCategory = null;
        document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
        allBtn.classList.add('active');
        if (window.currentTab === 'buy') loadGridItems();
    };
    categoryList.appendChild(allBtn);
    
    categories.forEach(category => {
        const btn = document.createElement('button');
        btn.className = 'category-btn';
        btn.textContent = category;
        btn.onclick = () => {
            window.currentCategory = category;
            document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            if (window.currentTab === 'buy') loadGridItems();
        };
        categoryList.appendChild(btn);
    });
}

// New Grid-Based Item Loading
function loadGridItems() {
    const gridContainer = document.getElementById('inventory-grid');
    if (!gridContainer) {
        console.error('[CNR_NUI_DEBUG] inventory-grid element not found!');
        return;
    }
    
    // Clear existing items
    gridContainer.innerHTML = '';
      console.log('[CNR_NUI_DEBUG] loadGridItems called. Items count:', window.items ? window.items.length : 0);
    console.log('[CNR_NUI_DEBUG] currentCategory:', window.currentCategory);
    console.log('[CNR_NUI_DEBUG] currentTab:', window.currentTab);
    console.log('[CNR_NUI_DEBUG] Sample items:', window.items ? window.items.slice(0, 3).map(item => ({id: item.itemId, name: item.name})) : 'No items');
    
    // If items is an object rather than an array, convert it to an array
    let itemsArray = window.items || [];
    if (!Array.isArray(itemsArray) && typeof itemsArray === 'object') {
        itemsArray = Object.keys(itemsArray).map(key => itemsArray[key]);
    }
    
    // Filter by category if one is selected
    if (window.currentCategory) {
        itemsArray = itemsArray.filter(item => item.category === window.currentCategory);
        console.log('[CNR_NUI_DEBUG] Filtered items by category', window.currentCategory, ':', itemsArray.length);
    }
    
    if (itemsArray.length === 0) {
        console.log('[CNR_NUI_DEBUG] No items to render, showing empty message');
        gridContainer.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.6); padding: 40px;">No items available.</div>';
        return;
    }
    
    // Create document fragment for better performance
    const fragment = document.createDocumentFragment();
    
    // Make sure each item has required properties
    itemsArray.forEach((item, index) => {
        if (!item) {
            console.error('[CNR_NUI_DEBUG] Null item at index', index);
            return;
        }
        
        // Ensure the item has an itemId
        if (!item.itemId) {
            console.error('[CNR_NUI_DEBUG] Item missing itemId at index', index, item);
            return;
        }
        
        // Add a name if missing
        if (!item.name) {
            item.name = item.itemId;
        }
        
        console.log('[CNR_NUI_DEBUG] Creating slot for item:', item.itemId, item.name);
        const slot = createInventorySlot(item, 'buy');
        if (slot) {
            fragment.appendChild(slot);
            console.log('[CNR_NUI_DEBUG] Successfully created slot for:', item.itemId);
        } else {
            console.error('[CNR_NUI_DEBUG] Failed to create slot for:', item.itemId);
        }
    });
    
    gridContainer.appendChild(fragment);
    console.log('[CNR_NUI_DEBUG] Rendered', itemsArray.length, 'items to grid');
    console.log('[CNR_NUI_DEBUG] Grid container children count:', gridContainer.children.length);
}

function loadSellGridItems() {
    const sellGrid = document.getElementById('sell-inventory-grid');
    if (!sellGrid) {
        console.error('[CNR_NUI] sell-inventory-grid element not found!');
        return;
    }
    
    console.log('[CNR_NUI] Loading sell grid items...');
    
    // Show loading state
    sellGrid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.6); padding: 40px;">Loading inventory...</div>';
    
    // Fetch player inventory from server
    const resName = window.cnrResourceName || 'cops-and-robbers';
    console.log('[CNR_NUI] Fetching inventory from resource:', resName);
    
    fetch(`https://${resName}/getPlayerInventory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(response => {
        console.log('[CNR_NUI] Received response from getPlayerInventory:', response.status);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        return response.json();    }).then(data => {
        console.log('[CNR_NUI] Inventory data received:', data);
        sellGrid.innerHTML = '';
        let minimalInventory = data.inventory || []; // Server returns { inventory: [...] }
        
        // Convert object to array if necessary (for backward compatibility)
        if (typeof minimalInventory === 'object' && !Array.isArray(minimalInventory)) {
            console.log('[CNR_NUI] Converting inventory object to array format');
            const inventoryArray = [];
            for (const [itemId, itemData] of Object.entries(minimalInventory)) {
                if (itemData && itemData.count > 0) {
                    inventoryArray.push({
                        itemId: itemId,
                        count: itemData.count
                    });
                }
            }
            minimalInventory = inventoryArray;
        }
        
        if (!window.fullItemConfig) {
            console.error('[CNR_NUI] fullItemConfig not available. Cannot reconstruct sell list details.');
            console.log('[CNR_NUI] fullItemConfig is:', window.fullItemConfig);
            sellGrid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.6); padding: 40px;">Error: Item configuration not loaded. Please try reopening the store.</div>';
            return;
        }
        
        console.log('[CNR_NUI] Processing', Array.isArray(minimalInventory) ? minimalInventory.length : 'unknown', 'inventory items');
        console.log('[CNR_NUI] fullItemConfig type:', typeof window.fullItemConfig, 'has items:', window.fullItemConfig ? Object.keys(window.fullItemConfig).length : 0);
        
        if (!minimalInventory || !Array.isArray(minimalInventory) || minimalInventory.length === 0) {
            sellGrid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.6); padding: 40px;">Your inventory is empty.</div>';
            return;
        }
        
        const fragment = document.createDocumentFragment();
        let itemsProcessed = 0;
        
        minimalInventory.forEach(minItem => {
            if (minItem && minItem.count > 0) {
                // Look up full item details from config
                let itemDetails = null;
                
                if (Array.isArray(window.fullItemConfig)) {
                    // If fullItemConfig is an array
                    itemDetails = window.fullItemConfig.find(configItem => configItem.itemId === minItem.itemId);
                } else if (typeof window.fullItemConfig === 'object' && window.fullItemConfig !== null) {
                    // If fullItemConfig is an object
                    itemDetails = window.fullItemConfig[minItem.itemId];
                }
                
                if (itemDetails) {
                    // Calculate sell price (50% of base price by default)
                    let sellPrice = Math.floor((itemDetails.price || itemDetails.basePrice || 0) * 0.5);
                    
                    // Apply dynamic economy if available
                    if (window.cnrDynamicEconomySettings && window.cnrDynamicEconomySettings.enabled && typeof window.cnrDynamicEconomySettings.sellPriceFactor === 'number') {
                        sellPrice = Math.floor((itemDetails.price || itemDetails.basePrice || 0) * window.cnrDynamicEconomySettings.sellPriceFactor);
                    }
                    
                    const richItem = {
                        itemId: minItem.itemId,
                        name: itemDetails.name || minItem.itemId,
                        count: minItem.count,
                        category: itemDetails.category || 'Miscellaneous',
                        sellPrice: sellPrice,
                        image: itemDetails.image || null
                    };
                    
                    const slotElement = createInventorySlot(richItem, 'sell');
                    if (slotElement) {
                        fragment.appendChild(slotElement);
                        itemsProcessed++;
                    }
                } else {
                    console.warn(`[CNR_NUI] ItemId ${minItem.itemId} from inventory not found in fullItemConfig. Creating fallback display.`);
                    // Create a fallback display for the item
                    const fallbackItem = {
                        itemId: minItem.itemId,
                        name: minItem.itemId,
                        count: minItem.count,
                        category: 'Unknown',
                        sellPrice: 0
                    };
                    fragment.appendChild(createInventorySlot(fallbackItem, 'sell'));
                    itemsProcessed++;
                }
            }
        });
        
        console.log('[CNR_NUI] Created', itemsProcessed, 'sell item slots');
        sellGrid.appendChild(fragment);
        
        if (itemsProcessed === 0) {
            sellGrid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.6); padding: 40px;">No sellable items in inventory.</div>';
        }
    }).catch(error => {
        console.error('[CNR_NUI] Error loading sell inventory:', error);
        sellGrid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.8); padding: 40px;">Error loading inventory. Please try again.<br><small>Error: ' + error.message + '</small></div>';
    });
}

// Legacy Support Functions (for backward compatibility)
function loadItems() {
    console.log('[CNR_NUI] loadItems() called - redirecting to loadGridItems()');
    loadGridItems();
}

function loadSellItems() {
    console.log('[CNR_NUI] loadSellItems() called - redirecting to loadSellGridItems()');
    loadSellGridItems();
}

// Legacy createItemElement function for backward compatibility
function createItemElement(item, type = 'buy') {
    console.log('[CNR_NUI] createItemElement() called - redirecting to createInventorySlot()');
    return createInventorySlot(item, type);
}

// Modern Grid-Based Inventory Slot Creation
function createInventorySlot(item, type = 'buy') {
    console.log('[CNR_NUI_DEBUG] createInventorySlot called for:', item.itemId, 'type:', type, 'item data:', JSON.stringify(item));
    
    if (!item || !item.itemId) {
        console.error('[CNR_NUI_ERROR] Invalid item data provided to createInventorySlot:', item);
        return null;
    }
    
    const slot = document.createElement('div');
    slot.className = 'inventory-slot';
    slot.dataset.itemId = item.itemId;
    
    // Check if item is level-locked for buy tab
    let isLocked = false;
    let lockReason = '';
    
    if (type === 'buy' && window.playerInfo) {
        const playerLevel = window.playerInfo.level || 1;
        const playerRole = window.playerInfo.role || 'citizen';
        
        if (playerRole === 'cop' && item.minLevelCop && playerLevel < item.minLevelCop) {
            isLocked = true;
            lockReason = `Level ${item.minLevelCop}`;
        } else if (playerRole === 'robber' && item.minLevelRobber && playerLevel < item.minLevelRobber) {
            isLocked = true;
            lockReason = `Level ${item.minLevelRobber}`;
        }
    }
    
    if (isLocked) {
        slot.classList.add('locked');
    }
    
    // Item Icon Container
    const iconContainer = document.createElement('div');
    iconContainer.className = 'item-icon-container';
    
    // Check if item has a valid image
    if (item.image && typeof item.image === 'string' && !item.image.includes('404')) {
        const imgElement = document.createElement('img');
        imgElement.src = item.image;
        imgElement.className = 'item-image';
        imgElement.alt = item.name || item.itemId;
        imgElement.onerror = function() {
            console.log(`[CNR_NUI] Image load error for ${item.itemId}, using fallback`);
            this.style.display = 'none';
            const fallbackIcon = document.createElement('div');
            fallbackIcon.className = 'item-icon';
            fallbackIcon.textContent = getItemIcon(item.category, item.name);
            this.parentNode.appendChild(fallbackIcon);
        };
        iconContainer.appendChild(imgElement);
    } else {
        const itemIcon = document.createElement('div');
        itemIcon.className = 'item-icon';
        itemIcon.textContent = item.icon || getItemIcon(item.category || 'Unknown', item.name || item.itemId || 'Unknown');
        iconContainer.appendChild(itemIcon);
    }
      // Add level requirement badge if locked
    if (isLocked) {
        const levelBadge = document.createElement('div');
        levelBadge.className = 'level-requirement';
        levelBadge.textContent = lockReason;
        iconContainer.appendChild(levelBadge);
    }
    
    // Add quantity badge for sell items
    if (type === 'sell' && item.count !== undefined && item.count > 1) {
        const quantityBadge = document.createElement('div');
        quantityBadge.className = 'quantity-badge';
        quantityBadge.textContent = `x${item.count}`;
        iconContainer.appendChild(quantityBadge);
    }
    
    slot.appendChild(iconContainer);
    
    // Item Info
    const itemInfo = document.createElement('div');
    itemInfo.className = 'item-info';
    
    const itemName = document.createElement('div');
    itemName.className = 'item-name';
    itemName.textContent = item.name || item.itemId || 'Unknown Item';
    itemInfo.appendChild(itemName);
    
    const itemPrice = document.createElement('div');
    itemPrice.className = 'item-price';
    const priceValue = type === 'buy' ? (item.price || item.basePrice || 0) : (item.sellPrice || 0);
    itemPrice.textContent = `$${priceValue ? priceValue.toLocaleString() : '0'}`;
    itemInfo.appendChild(itemPrice);
    
    slot.appendChild(itemInfo);
    
    // Action Overlay (only show on hover for unlocked items)
    if (!isLocked) {
        const actionOverlay = document.createElement('div');
        actionOverlay.className = 'action-overlay';
        
        const quantityInput = document.createElement('input');
        quantityInput.type = 'number';
        quantityInput.className = 'quantity-input';
        quantityInput.min = '1';
        quantityInput.max = (type === 'buy') ? '100' : (item.count ? item.count.toString() : '1');
        quantityInput.value = '1';
        actionOverlay.appendChild(quantityInput);
        
        const actionBtn = document.createElement('button');
        actionBtn.className = 'action-btn';
        actionBtn.textContent = type === 'buy' ? 'Buy' : 'Sell';
        actionBtn.onclick = (e) => {
            e.stopPropagation();
            const quantity = parseInt(quantityInput.value) || 1;
            handleItemAction(item.itemId, quantity, type);
        };
        actionOverlay.appendChild(actionBtn);
        
        slot.appendChild(actionOverlay);
    }
    
    console.log('[CNR_NUI_DEBUG] Successfully created slot for:', item.itemId);
    return slot;
}

// Get appropriate icon for item based on category and name
function getItemIcon(category, itemName) {
    const icons = {
        'Weapons': {
            'Pistol': '🔫',
            'SMG': '💥',
            'Assault Rifle': '🔫',
            'Sniper': '🎯',
            'Shotgun': '💥',
            'Heavy Weapon': '💥',
            'Melee': '🗡️',
            'Thrown': '💣'
        },
        'Equipment': {
            'Armor': '🛡️',
            'Parachute': '🪂',
            'Health': '❤️',
            'Radio': '📻'
        },
        'Vehicles': {
            'Car': '🚗',
            'Motorcycle': '🏍️',
            'Boat': '🚤',
            'Aircraft': '✈️'
        },
        'Tools': {
            'Lockpick': '🗝️',
            'Drill': '🔧',
            'Hacking': '💻',
            'Explosive': '💣'
        }
    };
    
    // Try to find specific item first
    if (icons[category] && icons[category][itemName]) {
        return icons[category][itemName];
    }
    
    // Fallback to category icons
    const categoryIcons = {
        'Weapons': '🔫',
        'Equipment': '🎒',
        'Vehicles': '🚗',
        'Tools': '🔧',
        'Consumables': '💊',
        'Ammo': '📦'    };
    
    return categoryIcons[category] || '📦';
}

// MODIFIED handleItemAction function
async function handleItemAction(itemId, quantity, actionType) {
    const endpoint = actionType === 'buy' ? 'buyItem' : 'sellItem';
    const resName = window.cnrResourceName || 'cops-and-robbers';
    const url = `https://${resName}/${endpoint}`;

    try {
        const rawResponse = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ itemId: itemId, quantity: quantity })
        });

        const jsonData = await rawResponse.json(); // jsonData is what cb({ success: ... }) sends

        if (!rawResponse.ok) { // HTTP error (e.g. 500, 404)
            throw new Error(jsonData.error || jsonData.message || `HTTP error ${rawResponse.status}`);
        }

        if (jsonData.success) {
            showToast(`Successfully ${actionType === 'buy' ? 'purchased' : 'sold'} item.`, 'success');
            if (actionType === 'sell') {
                loadSellItems(); // Refresh sell list immediately
            }
            // Server-driven refresh via 'refreshSellListIfNeeded' NUI message will handle other cases.
        } else {
            showToast(`${actionType === 'buy' ? 'Purchase' : 'Sell'} failed.`, 'error');
        }

    } catch (error) {
        console.error(`[CNR_NUI_FETCH] Error ${actionType}ing item (URL: ${url}):`, error);
        showToast(`Request to ${actionType} item failed: ${error.message || 'Check F8 console.'}`, 'error');
    }
}

// Cash notification system
let previousCash = null;

function showCashNotification(newCash, oldCash = null) {
    const difference = oldCash !== null ? newCash - oldCash : 0;
    
    if (difference === 0) return;
    
    const notification = document.createElement('div');
    notification.className = 'cash-notification';
    notification.innerHTML = `
        <div class="cash-amount">${difference > 0 ? '+' : ''}$${Math.abs(difference)}</div>
        <div class="cash-total">Total: $${newCash}</div>
    `;
    
    document.body.appendChild(notification);
    
    // Trigger animation
    setTimeout(() => {
        notification.classList.add('show');
    }, 10);
    
    // Remove after animation
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, 3000);
}

// ====================================================================
// Wanted Level Notification Functions
// ====================================================================

let wantedNotificationTimeout = null;
let lastKnownStars = 0; // Track previous star level to only show notifications on changes

function showWantedNotification(stars, points, levelLabel) {
    // Only show notification if stars have actually changed
    if (stars !== lastKnownStars) {
        console.log('[CNR_NUI] Showing wanted notification - Stars changed from', lastKnownStars, 'to', stars, 'Points:', points, 'Level:', levelLabel);
        lastKnownStars = stars; // Update tracked stars
        
        const notification = document.getElementById('wanted-notification');
        if (!notification) {
            console.error('[CNR_NUI] Wanted notification element not found');
            return;
        }

        // Clear any existing timeout
        if (wantedNotificationTimeout) {
            clearTimeout(wantedNotificationTimeout);
            wantedNotificationTimeout = null;
        }

        // Update notification content
        const wantedIcon = notification.querySelector('.wanted-icon');
        const wantedLevelEl = notification.querySelector('.wanted-level');
        const wantedPointsEl = notification.querySelector('.wanted-points');

        if (wantedIcon) wantedIcon.textContent = '⭐';
        if (wantedLevelEl) {
            wantedLevelEl.textContent = levelLabel || generateStarDisplay(stars);
        }
        if (wantedPointsEl) {
            wantedPointsEl.textContent = `${points} Points`;
        }

        // Remove existing level classes and add new one
        notification.className = 'wanted-notification';
        if (stars > 0) {
            notification.classList.add(`level-${Math.min(stars, 5)}`);        }

        // Show notification
        notification.style.display = 'block';
        notification.style.opacity = '1';

        // Auto-hide after 15 seconds (instead of 3)
        wantedNotificationTimeout = setTimeout(() => {
            hideWantedNotification();
        }, 15000); // Increased from 3000ms to 15000ms
    } else {
        // Stars haven't changed, just update the internal tracking
        console.log('[CNR_NUI] Wanted level sync (no star change) - Stars:', stars, 'Points:', points);
    }
}

function hideWantedNotification() {
    const notification = document.getElementById('wanted-notification');
    if (!notification) return;

    // Reset star tracking when notification is hidden (wanted level cleared)
    lastKnownStars = 0;

    // Clear timeout if it exists
    if (wantedNotificationTimeout) {
        clearTimeout(wantedNotificationTimeout);
        wantedNotificationTimeout = null;
    }

    // Add removing animation class
    notification.classList.add('removing');
    
    // Hide after animation completes
    setTimeout(() => {
        notification.classList.add('hidden');
        notification.classList.remove('removing');
    }, 300);
}

function generateStarDisplay(stars) {
    if (stars <= 0) return '';
    const maxStars = 5;
    let display = '';
    for (let i = 1; i <= maxStars; i++) {
        display += i <= stars ? '★' : '☆';
    }
    return display;
}

// Event listeners and other functions (DOMContentLoaded, selectRole, Escape key, Heist Timer, Admin Panel, Bounty Board) remain unchanged from the previous version.
// ... (assuming the rest of the file content from the last read_files output is here)
document.addEventListener('click', function(event) {
    const target = event.target;
    const itemDiv = target.closest('.item');
    if (!itemDiv) return;
    
    // Check if this is a locked item
    if (itemDiv.classList.contains('locked-item') && target.dataset.action === 'buy') {
        showToast('This item is locked. You need a higher level to purchase it.', 'error');
        return;
    }
    
    const itemId = itemDiv.dataset.itemId;
    const actionType = target.dataset.action;
    if (itemId && (actionType === 'buy' || actionType === 'sell')) {
        const quantityInput = itemDiv.querySelector('.quantity-input');
        if (!quantityInput) { console.error('Quantity input not found for item:', itemId); return; }
        const quantity = parseInt(quantityInput.value);
        const maxQuantity = parseInt(quantityInput.max);
        if (isNaN(quantity) || quantity < 1 || quantity > maxQuantity) {
            console.warn(`[CNR_NUI_INPUT_VALIDATION] Invalid quantity input: ${quantity}. Max allowed: ${maxQuantity}. ItemId: ${itemId}`);
            return;
        }
        handleItemAction(itemId, quantity, actionType);
    }
});

function selectRole(selectedRole) {
    const resName = window.cnrResourceName || 'cops-and-robbers';
    const fetchURL = `https://${resName}/selectRole`;
    fetch(fetchURL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: selectedRole })
    })
    .then(resp => {
        if (!resp.ok) {
            return resp.text().then(text => {
                throw new Error(`HTTP error ${resp.status} (${resp.statusText}): ${text}`);
            }).catch(() => {
                 throw new Error(`HTTP error ${resp.status} (${resp.statusText})`);
            });
        }
        return resp.json();
    })
    .then(response => { // This 'response' is the data from the NUI callback cb({success=true}) in client.lua
        console.log('[CNR_NUI_ROLE] selectRole NUI callback response from Lua:', response);
        // The original script called another function: handleRoleSelectionResponse(response)
        // Let's assume that function is still there or integrate its logic.
        // For logging, we want to see if hideRoleSelection is called.
        // Original handleRoleSelectionResponse:
        // function handleRoleSelectionResponse(response) {
        //   console.log("Response from selectRole NUI callback:", response);
        //   if (response && response.success) {
        //     hideRoleSelection();
        //   } else if (response && response.error) { ... } else { ... }
        // }
        // Directly integrate for clarity or ensure handleRoleSelection is called:
        if (response && response.success) {
            console.log('[CNR_NUI_ROLE] selectRole successful according to Lua. Calling hideRoleSelection().');
            hideRoleSelection();
        } else if (response && response.error) {
            console.error("[CNR_NUI_ROLE] Role selection failed via NUI callback: " + response.error);
            showToast(response.error, 'error'); // Keep toast for user feedback
        } else {
            console.error("[CNR_NUI_ROLE] Role selection failed: Unexpected server response from NUI callback", response);
            showToast("Unexpected server response", 'error'); // Keep toast
        }
    })
    .catch(error => {
        const resNameForError = window.cnrResourceName || 'cops-and-robbers';
        console.error(`Error in selectRole NUI callback (URL attempted: https://${resNameForError}/selectRole):`, error);
        showToast(`Failed to select role: ${error.message || 'See F8 console.'}`, 'error');
    });
}

document.addEventListener('DOMContentLoaded', () => {
    const roleSelectionContainer = document.getElementById('role-selection');
    if (roleSelectionContainer) {
        roleSelectionContainer.addEventListener('click', function(event) {
            const button = event.target.closest('button[data-role]');
            if (button) {
                const role = button.getAttribute('data-role');
                
                // Check if it's a role selection or character editor button
                if (button.classList.contains('role-editor-btn') || button.id.includes('editor')) {
                    // Open character editor
                    fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/openCharacterEditor`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ role: role, characterSlot: 1 })
                    }).then(resp => resp.json()).then(response => {
                        console.log('[CNR_CHARACTER_EDITOR] Character editor request response:', response);
                        if (response.success) {
                            hideRoleSelection();
                        }
                    }).catch(error => {
                        console.error('[CNR_CHARACTER_EDITOR] Error opening character editor:', error);
                    });
                } else {
                    // Regular role selection
                    selectRole(role);
                }
            }
        });
    } else {
        document.querySelectorAll('.menu button[data-role]').forEach(button => {
            button.addEventListener('click', () => {
                const role = button.getAttribute('data-role');
                if (button.classList.contains('role-editor-btn') || button.id.includes('editor')) {
                    // Open character editor
                    fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/openCharacterEditor`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ role: role, characterSlot: 1 })
                    }).then(resp => resp.json()).then(response => {
                        console.log('[CNR_CHARACTER_EDITOR] Character editor request response:', response);
                        if (response.success) {
                            hideRoleSelection();
                        }
                    }).catch(error => {
                        console.error('[CNR_CHARACTER_EDITOR] Error opening character editor:', error);
                    });
                } else {
                    selectRole(role);
                }
            });
        });
    }

    const adminPlayerListBody = document.getElementById('admin-player-list-body');
    if (adminPlayerListBody) {
        adminPlayerListBody.addEventListener('click', function(event) {
            const target = event.target;
            if (target.classList.contains('admin-action-btn')) {
                const targetId = target.dataset.targetId;
                if (!targetId) return;
                const resName = window.cnrResourceName || 'cops-and-robbers';
                if (target.classList.contains('admin-kick-btn')) {
                    if (confirm(`Kick player ID ${targetId}?`)) {
                        fetch(`https://${resName}/adminKickPlayer`, {
                            method: 'POST', headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ targetId: targetId })
                        }).then(resp => resp.json()).then(res => console.log('[CNR_NUI_ADMIN] Kick response:', res.message || (res.success ? 'Kicked.' : 'Failed.')));
                    }
                } else if (target.classList.contains('admin-ban-btn')) {
                    currentAdminTargetPlayerId = targetId;
                    document.getElementById('admin-ban-reason-container')?.classList.remove('hidden');
                    document.getElementById('admin-ban-reason')?.focus();
                } else if (target.classList.contains('admin-teleport-btn')) {
                    if (confirm(`Teleport to player ID ${targetId}?`)) {
                         fetch(`https://${resName}/teleportToPlayerAdminUI`, {
                            method: 'POST', headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ targetId: targetId })
                        }).then(resp => resp.json()).then(res => {
                            console.log('[CNR_NUI_ADMIN] Teleport response:', res.message || (res.success ? 'Teleporting.' : 'Failed.'));
                            hideAdminPanel();
                        });
                    }
                }
            }
        });
    }

    document.getElementById('admin-confirm-ban-btn')?.addEventListener('click', function() {
        if (currentAdminTargetPlayerId) {
            const reasonInput = document.getElementById('admin-ban-reason');
            const reason = reasonInput ? reasonInput.value.trim() : "Banned by Admin via UI.";
            const resName = window.cnrResourceName || 'cops-and-robbers';
            fetch(`https://${resName}/adminBanPlayer`, {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ targetId: currentAdminTargetPlayerId, reason: reason })
            }).then(resp => resp.json()).then(res => {
                console.log('[CNR_NUI_ADMIN] Ban response:', res.message || (res.success ? 'Banned.' : 'Failed.'));
                hideAdminPanel();
            });
        }
    });

    document.getElementById('admin-cancel-ban-btn')?.addEventListener('click', function() {
        document.getElementById('admin-ban-reason-container')?.classList.add('hidden');
        const banReasonInput = document.getElementById('admin-ban-reason');
        if (banReasonInput) banReasonInput.value = '';
        currentAdminTargetPlayerId = null;
    });

    document.getElementById('admin-close-btn')?.addEventListener('click', hideAdminPanel);
    const storeCloseButton = document.getElementById('close-btn');
    if (storeCloseButton) storeCloseButton.addEventListener('click', closeStoreMenu);
    const bountyCloseButton = document.getElementById('bounty-close-btn');
    if (bountyCloseButton) bountyCloseButton.addEventListener('click', hideBountyBoardUI);
});

window.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' || event.keyCode === 27) {
        const storeMenu = document.getElementById('store-menu');
        const adminPanel = document.getElementById('admin-panel');
        const bountyBoardPanel = document.getElementById('bounty-board');
        if (storeMenu && storeMenu.style.display === 'block') closeStoreMenu();
        else if (adminPanel && adminPanel.style.display !== 'none' && !adminPanel.classList.contains('hidden')) hideAdminPanel();
        else if (bountyBoardPanel && bountyBoardPanel.style.display !== 'none' && !bountyBoardPanel.classList.contains('hidden')) hideBountyBoardUI();
    }
});

// Global escape key listener for inventory
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && isInventoryOpen) {
        closeInventoryUI();
    }
});

let heistTimerInterval = null;
function startHeistTimer(duration, bankName) {
    const heistTimerEl = document.getElementById('heist-timer');
    if (!heistTimerEl) return;
    heistTimerEl.style.display = 'block';
    const timerTextEl = document.getElementById('timer-text');
    if (!timerTextEl) { heistTimerEl.style.display = 'none'; return; }
    let remainingTime = duration;
    timerTextEl.textContent = `Heist at ${bankName}: ${formatTime(remainingTime)}`;
    if (heistTimerInterval) clearInterval(heistTimerInterval);
    heistTimerInterval = setInterval(function() {
        remainingTime--;
        if (remainingTime <= 0) {
            clearInterval(heistTimerInterval);
            heistTimerInterval = null;
            heistTimerEl.style.display = 'none';
            return;
        }
        timerTextEl.textContent = `Heist at ${bankName}: ${formatTime(remainingTime)}`;
    }, 1000);
}

function formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
}

let currentAdminTargetPlayerId = null;
function showAdminPanel(playerList) {
    const adminPanel = document.getElementById('admin-panel');
    const playerListBody = document.getElementById('admin-player-list-body');
    if (!adminPanel || !playerListBody) return;
    playerListBody.innerHTML = '';
    if (playerList && playerList.length > 0) {
        playerList.forEach(player => {
            const row = playerListBody.insertRow();
            row.insertCell().textContent = player.name;
            row.insertCell().textContent = player.serverId;
            row.insertCell().textContent = player.role;
            row.insertCell().textContent = '$' + (player.cash || 0);
            const actionsCell = row.insertCell();
            const kickBtn = document.createElement('button');
            kickBtn.innerHTML = '<span class="icon">👢</span>Kick'; kickBtn.className = 'admin-action-btn admin-kick-btn';
            kickBtn.dataset.targetId = player.serverId; actionsCell.appendChild(kickBtn);
            const banBtn = document.createElement('button');
            banBtn.innerHTML = '<span class="icon">🚫</span>Ban'; banBtn.className = 'admin-action-btn admin-ban-btn';
            banBtn.dataset.targetId = player.serverId; actionsCell.appendChild(banBtn);
            const teleportBtn = document.createElement('button');
            teleportBtn.innerHTML = '<span class="icon">➡️</span>TP to'; teleportBtn.className = 'admin-action-btn admin-teleport-btn';
            teleportBtn.dataset.targetId = player.serverId; actionsCell.appendChild(teleportBtn);
        });
    } else {
        playerListBody.innerHTML = '<tr><td colspan="5" style="text-align:center;">No players online or data unavailable.</td></tr>';
    }
    adminPanel.classList.remove('hidden');
    fetchSetNuiFocus(true, true);
}

function hideAdminPanel() {
    const adminPanel = document.getElementById('admin-panel');
    if (adminPanel) adminPanel.classList.add('hidden');
    const banReasonContainer = document.getElementById('admin-ban-reason-container');
    if (banReasonContainer) banReasonContainer.classList.add('hidden');
    const banReasonInput = document.getElementById('admin-ban-reason');
    if (banReasonInput) banReasonInput.value = '';
    currentAdminTargetPlayerId = null;
    fetchSetNuiFocus(false, false);
}

function showBountyBoardUI(bounties) {
    const bountyBoardElement = document.getElementById('bounty-board');
    if (bountyBoardElement) {
        bountyBoardElement.style.display = 'block';
        updateBountyListUI(bounties);
        fetchSetNuiFocus(true, true);
    }
}

function hideBountyBoardUI() {
    const bountyBoardElement = document.getElementById('bounty-board');
    if (bountyBoardElement) {
        bountyBoardElement.style.display = 'none';
        fetchSetNuiFocus(false, false);
    }
}

function updateBountyListUI(bounties) {
    const bountyListUL = document.getElementById('bounty-list');
    if (bountyListUL) {
        bountyListUL.innerHTML = '';
        if (Object.keys(bounties).length === 0) {
            const noBountiesLi = document.createElement('li');
            noBountiesLi.className = 'no-bounties';
            noBountiesLi.textContent = 'No active bounties.';
            bountyListUL.appendChild(noBountiesLi);
            return;
        }
        for (const targetId in bounties) {
            const data = bounties[targetId];
            const li = document.createElement('li');
            const avatarDiv = document.createElement('div');
            avatarDiv.className = 'bounty-target-avatar';
            const nameInitial = data.name ? data.name.charAt(0).toUpperCase() : '?';
            avatarDiv.textContent = nameInitial;
            li.appendChild(avatarDiv);
            const textContainer = document.createElement('div');
            textContainer.className = 'bounty-text-content';
            let amountClass = 'bounty-amount-low';
            if (data.amount > 50000) amountClass = 'bounty-amount-high';
            else if (data.amount > 10000) amountClass = 'bounty-amount-medium';
            const formatNumber = (num) => num.toLocaleString();
            const bountyAmountHTML = `<span class="${amountClass}">$${formatNumber(data.amount || 0)}</span>`;
            const targetInfo = document.createElement('div');
            targetInfo.textContent = `Target: ${data.name || 'Unknown'} (ID: ${targetId})`;
            const rewardInfo = document.createElement('div');
            rewardInfo.innerHTML = `Reward: ${bountyAmountHTML}`;
            textContainer.appendChild(targetInfo);
            textContainer.appendChild(rewardInfo);
            li.appendChild(textContainer);
            bountyListUL.appendChild(li);
            li.classList.add('new-item-animation');
            setTimeout(() => {
                li.classList.remove('new-item-animation');
            }, 300);
        }
    }
}

function safeSetTableByPlayerId(tbl, playerId, value) {
    if (tbl && typeof tbl === 'object' && playerId !== undefined && playerId !== null && (typeof playerId === 'string' || typeof playerId === 'number')) {
        tbl[playerId] = value;
        return true;
    }
    return false;
}

function safeGetTableByPlayerId(tbl, playerId) {
    if (tbl && typeof tbl === 'object' && playerId !== undefined && playerId !== null && (typeof playerId === 'string' || typeof playerId === 'number')) {
        return tbl[playerId];
    }
    return undefined;
}

// ====================================================================
// Player Inventory System
// ====================================================================

let currentInventoryTab = 'all';
let selectedInventoryItem = null;
let playerInventoryData = {};
let equippedItems = new Set();

// Initialize inventory system
function initInventorySystem() {
    console.log('[CNR_INVENTORY] Initializing inventory system...');
    
    // Add event listeners
    const inventoryCloseBtn = document.getElementById('inventory-close-btn');
    if (inventoryCloseBtn) {
        inventoryCloseBtn.addEventListener('click', closeInventoryMenu);
    }
    
    // Add action button listeners
    const equipBtn = document.getElementById('equip-item-btn');
    const useBtn = document.getElementById('use-item-btn');
    const dropBtn = document.getElementById('drop-item-btn');
    
    if (equipBtn) equipBtn.addEventListener('click', equipSelectedItem);
    if (useBtn) useBtn.addEventListener('click', useSelectedItem);
    if (dropBtn) dropBtn.addEventListener('click', dropSelectedItem);
    
    console.log('[CNR_INVENTORY] Inventory system initialized');
}

// Show inventory menu
function showInventoryMenu() {
    console.log('[CNR_INVENTORY] Opening inventory menu...');
    
    const inventoryMenu = document.getElementById('inventory-menu');
    if (inventoryMenu) {
        inventoryMenu.style.display = 'block';
        inventoryMenu.classList.add('show');
        
        // Update player info
        updateInventoryPlayerInfo();
        
        // Request current inventory from server
        requestPlayerInventoryForUI();
        
        // Set focus
        fetchSetNuiFocus(true, true);
        
        console.log('[CNR_INVENTORY] Inventory menu opened');
    }
}

// Close inventory menu
function closeInventoryMenu() {
    console.log('[CNR_INVENTORY] Closing inventory menu...');
    
    const inventoryMenu = document.getElementById('inventory-menu');
    if (inventoryMenu) {
        inventoryMenu.style.display = 'none';
        inventoryMenu.classList.remove('show');
        
        // Clear selection
        clearItemSelection();
        
        // Release focus
        fetchSetNuiFocus(false, false);
        
        console.log('[CNR_INVENTORY] Inventory menu closed');
    }
}

function closeInventoryUI() {
    if (!isInventoryOpen) return;
    
    isInventoryOpen = false;
    console.log('[CNR_INVENTORY] Closing inventory UI');
    
    const inventoryMenu = document.getElementById('inventory-menu');
    if (inventoryMenu) {
        inventoryMenu.style.display = 'none';
        inventoryMenu.classList.add('hidden');
        document.body.classList.remove('inventory-open');
    }
    
    // Remove NUI focus
    fetchSetNuiFocus(false, false);
    
    // Send close message to Lua
    fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/closeInventory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(error => {
        console.error('[CNR_INVENTORY] Failed to send close message:', error);
    });
}

// Update player info in inventory
function updateInventoryPlayerInfo() {
    const cashElement = document.getElementById('inventory-player-cash-amount');
    const levelElement = document.getElementById('inventory-player-level-text');
    
    if (cashElement && window.playerInfo && window.playerInfo.cash !== undefined) {
        cashElement.textContent = `$${window.playerInfo.cash.toLocaleString()}`;
    }
    
    if (levelElement && window.playerInfo && window.playerInfo.level !== undefined) {
        levelElement.textContent = `Level ${window.playerInfo.level}`;
    }
}

// Request player inventory from server
async function requestPlayerInventoryForUI() {
    try {
        const response = await fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/getPlayerInventoryForUI`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        });
        
        const result = await response.json();
        if (result && result.success) {
            playerInventoryData = result.inventory || {};
            renderInventoryGrid();
            renderEquippedItems();
            renderCategoryFilter();
        } else {
            console.error('[CNR_INVENTORY] Failed to get inventory:', result.error);
            showToast('Failed to load inventory', 'error', 3000);
        }
    } catch (error) {
        console.error('[CNR_INVENTORY] Error requesting inventory:', error);
        showToast('Error loading inventory', 'error', 3000);
    }
}

// Create inventory UI elements if they don't exist
function createInventoryUI() {
    // Check if inventory menu already exists
    const existingInventory = document.getElementById('inventory-menu');
    if (existingInventory) {
        console.log('[CNR_INVENTORY] Inventory UI already exists, setting up event listeners');
        
        // Add close button event listener if not already added
        const closeBtn = document.getElementById('inventory-close-btn');
        if (closeBtn && !closeBtn.hasEventListener) {
            closeBtn.addEventListener('click', closeInventoryUI);
            closeBtn.hasEventListener = true;
        }
        
        return;
    }
    
    console.log('[CNR_INVENTORY] Creating inventory UI');
    
    // Create the main inventory container
    const inventoryMenu = document.createElement('div');
    inventoryMenu.id = 'inventory-menu';
    inventoryMenu.className = 'inventory-container';
    inventoryMenu.style.display = 'none';
    
    inventoryMenu.innerHTML = `
        <div class="inventory-panel">
            <div class="inventory-header">
                <h2>Inventory</h2>
                <button id="inventory-close-btn" class="close-btn">×</button>
            </div>
            <div class="inventory-content">
                <div class="inventory-player-info">
                    <div class="player-stats">
                        <span id="inventory-player-cash-amount">$0</span>
                        <span id="inventory-player-level-text">Level 1</span>
                    </div>
                </div>
                <div class="inventory-categories">
                    <div id="inventory-category-list" class="category-buttons">
                        <button class="category-btn active" data-category="all">All</button>
                    </div>
                </div>
                <div class="inventory-grid" id="inventory-grid">
                    <!-- Inventory items will be populated here -->
                </div>
                <div class="equipped-items" id="equipped-items">
                    <h3>Equipped Items</h3>
                    <div id="equipped-items-container">
                        <!-- Equipped items will be populated here -->
                    </div>
                </div>
            </div>
        </div>
    `;
    
    document.body.appendChild(inventoryMenu);
    
    // Add close button event listener
    const closeBtn = document.getElementById('inventory-close-btn');
    if (closeBtn) {
        closeBtn.addEventListener('click', closeInventoryUI);
        closeBtn.hasEventListener = true;
    }
}

// Update inventory UI with new inventory data
function updateInventoryUI(inventory) {
    console.log('[CNR_INVENTORY] Updating inventory UI', inventory);
    
    currentInventoryData = inventory || {};
    
    // Update player info
    updateInventoryPlayerInfo();
    
    // Render inventory grid
    renderInventoryGrid();
}

// Update equipped items UI
function updateEquippedItemsUI(equippedItems) {
    console.log('[CNR_INVENTORY] Updating equipped items UI', equippedItems);
    
    currentEquippedItems = equippedItems || {};
    
    // Render equipped items
    renderEquippedItems();
}

// Render category filter buttons
function renderCategoryFilter() {
    const categoryList = document.getElementById('inventory-category-list');
    if (!categoryList) return;
    
    // Get unique categories from inventory
    const categories = new Set(['all']);
    
    if (fullItemConfig && Array.isArray(fullItemConfig)) {
        Object.values(playerInventoryData).forEach(item => {
            if (item.category) {
                categories.add(item.category);
            }
        });
    }
    
    categoryList.innerHTML = '';
    
    categories.forEach(category => {
        const btn = document.createElement('button');
        btn.className = 'category-btn';
        btn.textContent = category === 'all' ? 'All' : category;
        btn.dataset.category = category;
        
        if (category === currentInventoryTab) {
            btn.classList.add('active');
        }
        
        btn.addEventListener('click', () => {
            currentInventoryTab = category;
            renderInventoryGrid();
            
            // Update active button
            document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        });
        
        categoryList.appendChild(btn);
    });
}

// Render inventory grid
function renderInventoryGrid() {
    const grid = document.getElementById('player-inventory-grid');
    if (!grid) return;
    
    grid.innerHTML = '';
    
    // Filter items based on current tab
    const filteredItems = Object.entries(playerInventoryData).filter(([itemId, itemData]) => {
        if (currentInventoryTab === 'all') return true;
        return itemData.category === currentInventoryTab;
    });
    
    if (filteredItems.length === 0) {
        const emptyState = document.createElement('div');
        emptyState.className = 'inventory-empty';
        emptyState.innerHTML = `
            <span class="empty-icon">📦</span>
            <div>No items in ${currentInventoryTab === 'all' ? 'inventory' : currentInventoryTab}</div>
        `;
        grid.appendChild(emptyState);
        return;
    }
    
    filteredItems.forEach(([itemId, itemData]) => {
        const itemElement = createInventoryItemElement(itemId, itemData);
        grid.appendChild(itemElement);
    });
}

// Create inventory item element
function createInventoryItemElement(itemId, itemData) {
    const item = document.createElement('div');
    item.className = 'inventory-item';
    item.dataset.itemId = itemId;
    
    // Check if item is equipped
    if (equippedItems.has(itemId)) {
        item.classList.add('equipped');
    }
    
    // Get item icon
    const icon = getItemIcon(itemData);
    
    item.innerHTML = `
        <span class="item-icon">${icon}</span>
        <div class="item-name">${itemData.name || itemId}</div>
        <div class="item-count">x${itemData.count || 0}</div>
    `;
    
    // Add click event
    item.addEventListener('click', () => selectInventoryItem(itemId, itemData, item));
    
    return item;
}

// Select inventory item
function selectInventoryItem(itemId, itemData, element) {
    // Clear previous selection
    document.querySelectorAll('.inventory-item').forEach(item => {
        item.classList.remove('selected');
    });
    
    // Select new item
    element.classList.add('selected');
    selectedInventoryItem = { itemId, itemData };
    
    // Show item actions panel
    showItemActionsPanel(itemId, itemData);
}

// Show item actions panel
function showItemActionsPanel(itemId, itemData) {
    const panel = document.getElementById('item-actions-panel');
    const nameEl = document.getElementById('selected-item-name');
    const descEl = document.getElementById('selected-item-description');
    const countEl = document.getElementById('selected-item-count');
    
    if (!panel || !nameEl || !descEl || !countEl) return;
    
    nameEl.textContent = itemData.name || itemId;
    descEl.textContent = getItemDescription(itemData);
    countEl.textContent = `Count: ${itemData.count || 0}`;
    
    // Update button states
    updateActionButtonStates(itemId, itemData);
    
    panel.classList.remove('hidden');
}

// Get item description
function getItemDescription(itemData) {
    const descriptions = {
        'Weapons': 'Combat weapon that can be equipped and used',
        'Melee Weapons': 'Close-range weapon for combat',
        'Ammunition': 'Ammunition for weapons',
        'Armor': 'Protective gear to reduce damage',
        'Utility': 'Useful item with special functions',
        'Explosives': 'Explosive device for combat',
        'Accessories': 'Cosmetic or minor functional item',
        'Cop Gear': 'Law enforcement equipment'
    };
    
    return descriptions[itemData.category] || 'Inventory item';
}

// Update action button states
function updateActionButtonStates(itemId, itemData) {
    const equipBtn = document.getElementById('equip-item-btn');
    const useBtn = document.getElementById('use-item-btn');
    const dropBtn = document.getElementById('drop-item-btn');
    
    if (!equipBtn || !useBtn || !dropBtn) return;
    
    const isEquipped = equippedItems.has(itemId);
    const canEquip = canItemBeEquipped(itemData);
    const canUse = canItemBeUsed(itemData);
    
    // Equip button
    equipBtn.disabled = !canEquip;
    equipBtn.textContent = isEquipped ? '🔓 Unequip' : '⚡ Equip';
    
    // Use button
    useBtn.disabled = !canUse;
    
    // Drop button
    dropBtn.disabled = false; // Can always drop items
}

// Check if item can be equipped
function canItemBeEquipped(itemData) {
    const equipableCategories = ['Weapons', 'Melee Weapons', 'Armor', 'Cop Gear', 'Utility'];
    return equipableCategories.includes(itemData.category);
}

// Check if item can be used
function canItemBeUsed(itemData) {
    const usableCategories = ['Utility', 'Armor'];
    const usableItems = ['medkit', 'firstaidkit', 'armor', 'heavy_armor', 'spikestrip_item'];
    
    return usableCategories.includes(itemData.category) || usableItems.includes(itemData.itemId);
}

// Clear item selection
function clearItemSelection() {
    document.querySelectorAll('.inventory-item').forEach(item => {
        item.classList.remove('selected');
    });
    
    selectedInventoryItem = null;
    
    const panel = document.getElementById('item-actions-panel');
    if (panel) {
        panel.classList.add('hidden');
    }
}

// Equip/unequip selected item
async function equipSelectedItem() {
    if (!selectedInventoryItem) return;
    
    const { itemId, itemData } = selectedInventoryItem;
    const isEquipped = equippedItems.has(itemId);
    
    try {
        const response = await fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/equipInventoryItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                itemId: itemId,
                equip: !isEquipped
            })
        });
        
        const result = await response.json();
        if (result && result.success) {
            if (isEquipped) {
                equippedItems.delete(itemId);
                showToast(`Unequipped ${itemData.name}`, 'success', 2000);
            } else {
                equippedItems.add(itemId);
                showToast(`Equipped ${itemData.name}`, 'success', 2000);
            }
            
            // Update UI
            renderInventoryGrid();
            renderEquippedItems();
            updateActionButtonStates(itemId, itemData);
        } else {
            showToast(result.error || 'Failed to equip item', 'error', 3000);
        }
    } catch (error) {
        console.error('[CNR_INVENTORY] Error equipping item:', error);
        showToast('Error equipping item', 'error', 3000);
    }
}

// Use selected item
async function useSelectedItem() {
    if (!selectedInventoryItem) return;
    
    const { itemId, itemData } = selectedInventoryItem;
    
    try {
        const response = await fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/useInventoryItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                itemId: itemId
            })
        });
        
        const result = await response.json();
        if (result && result.success) {
            showToast(`Used ${itemData.name}`, 'success', 2000);
            
            // Refresh inventory if item was consumed
            if (result.consumed) {
                requestPlayerInventoryForUI();
                clearItemSelection();
            }
        } else {
            showToast(result.error || 'Failed to use item', 'error', 3000);
        }
    } catch (error) {
        console.error('[CNR_INVENTORY] Error using item:', error);
        showToast('Error using item', 'error', 3000);
    }
}

// Drop selected item
async function dropSelectedItem() {
    if (!selectedInventoryItem) return;
    
    const { itemId, itemData } = selectedInventoryItem;
    
    // Confirm drop
    const confirmed = confirm(`Are you sure you want to drop ${itemData.name}?`);
    if (!confirmed) return;
    
    try {
        const response = await fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/dropInventoryItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                itemId: itemId,
                quantity: 1
            })
        });
        
        const result = await response.json();
        if (result && result.success) {
            showToast(`Dropped ${itemData.name}`, 'success', 2000);
            requestPlayerInventoryForUI();
            clearItemSelection();
        } else {
            showToast(result.error || 'Failed to drop item', 'error', 3000);
        }
    } catch (error) {
        console.error('[CNR_INVENTORY] Error dropping item:', error);
        showToast('Error dropping item', 'error', 3000);
    }
}

// Render equipped items panel
function renderEquippedItems() {
    const container = document.getElementById('equipped-items');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (equippedItems.size === 0) {
        const emptyState = document.createElement('div');
        emptyState.className = 'equipped-empty';
        emptyState.innerHTML = '<div style="text-align: center; color: #7f8c8d; font-size: 12px;">No items equipped</div>';
        container.appendChild(emptyState);
        return;
    }
    
    equippedItems.forEach(itemId => {
        const itemData = playerInventoryData[itemId];
        if (!itemData) return;
        
        const equippedItem = document.createElement('div');
        equippedItem.className = 'equipped-item';
        
        const icon = getItemIcon(itemData);
        
        equippedItem.innerHTML = `
            <span class="item-icon">${icon}</span>
            <div class="item-details">
                <div class="item-name">${itemData.name || itemId}</div>
                <div class="item-count">x${itemData.count || 0}</div>
            </div>
        `;
        
        container.appendChild(equippedItem);
    });
}

// Handle NUI messages for inventory
function handleInventoryMessage(data) {
    switch (data.action) {
        case 'openInventory':
            openInventoryUI(data);
            break;
        case 'closeInventory':
            closeInventoryUI();
            break;
        case 'updateInventory':
            updateInventoryUI(data.inventory);
            break;
        case 'updateEquippedItems':
            updateEquippedItemsUI(data.equippedItems);
            break;
    }
}

function openInventoryUI(data) {
    if (isInventoryOpen) return;
    
    isInventoryOpen = true;
    console.log('[CNR_INVENTORY] Opening inventory UI');
    
    // Set up inventory UI (this will handle both existing and new UI creation)
    createInventoryUI();
    
    // Show the inventory
    const inventoryContainer = document.getElementById('inventory-menu');
    if (inventoryContainer) {
        inventoryContainer.style.display = 'block';
        inventoryContainer.classList.remove('hidden');
        document.body.classList.add('inventory-open');
        
        // Set NUI focus
        fetchSetNuiFocus(true, true);
    }
    
    // Request initial inventory data
    fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/getPlayerInventoryForUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(response => response.json())
    .then(result => {
        if (result.success) {
            updateInventoryUI(result.inventory);
            updateEquippedItemsUI(result.equippedItems);
        }
    }).catch(error => {
        console.error('[CNR_INVENTORY] Failed to load inventory:', error);
    });
}

// ==============================================
// Robber Menu Functions
// ==============================================
let isRobberMenuOpen = false;

function showRobberMenu() {
    console.log('[CNR_ROBBER_MENU] Opening robber menu');
    
    // Display the menu
    const robberMenu = document.getElementById('robber-menu');
    if (robberMenu) {
        robberMenu.classList.remove('hidden');
        document.body.classList.add('menu-open');
        isRobberMenuOpen = true;
        
        // Set up event listeners if they don't exist yet
        setupRobberMenuListeners();
    } else {
        console.error('[CNR_ROBBER_MENU] Could not find robber-menu element in the DOM');
    }
}

function hideRobberMenu() {
    console.log('[CNR_ROBBER_MENU] Closing robber menu');
    
    const robberMenu = document.getElementById('robber-menu');
    if (robberMenu) {
        robberMenu.classList.add('hidden');
        document.body.classList.remove('menu-open');
        isRobberMenuOpen = false;
    }
    
    // Reset NUI focus
    fetchSetNuiFocus(false, false);
}

function setupRobberMenuListeners() {
    // Close button
    const closeBtn = document.getElementById('robber-menu-close-btn');
    if (closeBtn) {
        closeBtn.addEventListener('click', function() {
            hideRobberMenu();
        });
    }
    
    // Start heist button
    const startHeistBtn = document.getElementById('start-heist-btn');
    if (startHeistBtn) {
        startHeistBtn.addEventListener('click', function() {
            console.log('[CNR_ROBBER_MENU] Start heist button clicked');
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/startHeist`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            }).catch(error => console.error('[CNR_ROBBER_MENU] Error triggering heist:', error));
            hideRobberMenu();
        });
    }
    
    // View bounties button
    const viewBountiesBtn = document.getElementById('view-bounties-btn');
    if (viewBountiesBtn) {
        viewBountiesBtn.addEventListener('click', function() {
            console.log('[CNR_ROBBER_MENU] View bounties button clicked');
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/viewBounties`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            }).catch(error => console.error('[CNR_ROBBER_MENU] Error viewing bounties:', error));
            hideRobberMenu();
        });
    }
    
    // Find hideout button
    const findHideoutBtn = document.getElementById('find-hideout-btn');
    if (findHideoutBtn) {
        findHideoutBtn.addEventListener('click', function() {
            console.log('[CNR_ROBBER_MENU] Find hideout button clicked');
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/findHideout`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            }).catch(error => console.error('[CNR_ROBBER_MENU] Error finding hideout:', error));
            hideRobberMenu();
        });
    }
    
    // Buy contraband button
    const buyContrabandBtn = document.getElementById('buy-contraband-btn');
    if (buyContrabandBtn) {
        buyContrabandBtn.addEventListener('click', function() {
            console.log('[CNR_ROBBER_MENU] Buy contraband button clicked');
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/buyContraband`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})            }).catch(error => console.error('[CNR_ROBBER_MENU] Error buying contraband:', error));
            hideRobberMenu();
        });
    }
}

// ====================================================================
// Bounty List Functionality
// ====================================================================

/**
 * Shows the bounty list UI with provided bounty data
 * @param {Array} bounties - Array of bounty objects with player info
 */
function showBountyList(bounties) {
    console.log('[CNR_UI] Showing bounty list with', bounties.length, 'bounties');
    
    const container = document.getElementById('bounty-list-container');
    const list = document.getElementById('bounty-list');
    
    // Clear existing items
    list.innerHTML = '';
    
    if (bounties.length === 0) {
        list.innerHTML = '<div class="bounty-item"><div class="bounty-info"><span class="bounty-name">No wanted criminals at this time</span></div></div>';
    } else {
        // Sort bounties by wanted level/reward (highest first)
        bounties.sort((a, b) => (b.wantedLevel || 0) - (a.wantedLevel || 0));
        
        bounties.forEach(bounty => {
            const bountyItem = document.createElement('div');
            bountyItem.className = 'bounty-item';
            
            // Calculate reward based on wanted level (if not provided)
            const reward = bounty.reward || (bounty.wantedLevel * 500);
            
            // Create wanted level display (stars based on level)
            const starsHTML = '⭐'.repeat(Math.min(bounty.wantedLevel || 0, 5));
            
            bountyItem.innerHTML = `
                <div class="bounty-info">
                    <span class="bounty-name">${bounty.name || 'Unknown Criminal'}</span>
                    <span class="bounty-wanted-level">${starsHTML} Wanted Level: ${bounty.wantedLevel || 0}</span>
                </div>
                <div class="bounty-reward">$${reward.toLocaleString()}</div>
            `;
            
            list.appendChild(bountyItem);
        });
    }
    
    // Show the container
    container.classList.remove('hidden');
    
    // Set up close button
    const closeBtn = document.getElementById('close-bounty-list-btn');
    if (closeBtn) {
        closeBtn.onclick = hideBountyList;
    }
    
    // Set NUI focus
    fetchSetNuiFocus(true, true);
}

/**
 * Hides the bounty list UI
 */
function hideBountyList() {
    console.log('[CNR_UI] Hiding bounty list');
    const container = document.getElementById('bounty-list-container');
    container.classList.add('hidden');
    
    // Release NUI focus
    fetchSetNuiFocus(false, false);
}

// ====================================================================
// Speedometer Functionality
// ====================================================================

/**
 * Updates the speedometer display with the current speed
 * @param {number} speed - Current speed in MPH
 */
function updateSpeedometer(speed) {
    const speedValueEl = document.getElementById('speed-value');
    if (speedValueEl) {
        speedValueEl.textContent = Math.round(speed);
    }
}

/**
 * Shows or hides the speedometer based on whether player is in an appropriate vehicle
 * @param {boolean} show - Whether to show the speedometer
 */
function toggleSpeedometer(show) {
    const speedometerEl = document.getElementById('speedometer');
    if (speedometerEl) {
        if (show) {
            speedometerEl.classList.remove('hidden');
        } else {
            speedometerEl.classList.add('hidden');
        }
    }
}

// Initialize speedometer update when the script loads
document.addEventListener('DOMContentLoaded', function() {
    // We'll receive speed updates from client.lua, no need to poll here
    
    // Set up the close button for bounty list if it exists
    const closeBountyBtn = document.getElementById('close-bounty-list-btn');
    if (closeBountyBtn) {
        closeBountyBtn.addEventListener('click', hideBountyList);
    }
    
    // Initialize character editor
    initializeCharacterEditor();
});

// ====================================================================
// Character Editor Functions
// ====================================================================

let characterEditorData = {
    isOpen: false,
    currentRole: null,
    currentSlot: 1,
    characterData: {},
    uniformPresets: [],
    selectedUniformPreset: null,
    selectedCharacterSlot: null
};

function initializeCharacterEditor() {
    // Camera controls
    document.querySelectorAll('.camera-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.camera-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            
            const mode = this.getAttribute('data-mode');
            fetchSetNuiFocus(true, true);
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_changeCamera`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ mode: mode })
            });
        });
    });

    // Character rotation
    document.querySelectorAll('.rotate-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const direction = this.getAttribute('data-direction');
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_rotateCharacter`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ direction: direction })
            });
        });
    });

    // Gender selection
    document.querySelectorAll('.gender-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.gender-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            
            const gender = this.getAttribute('data-gender');
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_switchGender`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ gender: gender })
            });
        });
    });

    // Customization tabs
    document.querySelectorAll('.customization-tabs .tab-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const category = this.getAttribute('data-category');
            switchCustomizationTab(category);
        });
    });

    // Customization sliders
    document.querySelectorAll('.customization-slider').forEach(slider => {
        slider.addEventListener('input', function() {
            const feature = this.getAttribute('data-feature');
            const category = this.getAttribute('data-category') || 'basic';
            const value = parseFloat(this.value);
            
            // Update slider value display
            const valueDisplay = this.parentElement.querySelector('.slider-value');
            if (valueDisplay) {
                valueDisplay.textContent = this.step && this.step.includes('.') ? value.toFixed(1) : value.toString();
            }
            
            // Send update to client
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_updateFeature`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ category: category, feature: feature, value: value })
            });
        });
    });

    // Uniform controls
    const previewUniformBtn = document.getElementById('preview-uniform-btn');
    const applyUniformBtn = document.getElementById('apply-uniform-btn');
    const cancelUniformBtn = document.getElementById('cancel-uniform-btn');

    if (previewUniformBtn) {
        previewUniformBtn.addEventListener('click', function() {
            if (characterEditorData.selectedUniformPreset !== null) {
                fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_previewUniform`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ presetIndex: characterEditorData.selectedUniformPreset })
                });
                
                applyUniformBtn.disabled = false;
                cancelUniformBtn.disabled = false;
            }
        });
    }

    if (applyUniformBtn) {
        applyUniformBtn.addEventListener('click', function() {
            if (characterEditorData.selectedUniformPreset !== null) {
                fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_applyUniform`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ presetIndex: characterEditorData.selectedUniformPreset })
                });
                
                this.disabled = true;
                cancelUniformBtn.disabled = true;
            }
        });
    }

    if (cancelUniformBtn) {
        cancelUniformBtn.addEventListener('click', function() {
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_cancelUniformPreview`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
            
            applyUniformBtn.disabled = true;
            this.disabled = true;
        });
    }

    // Character management controls
    const loadCharacterBtn = document.getElementById('load-character-btn');
    const deleteCharacterBtn = document.getElementById('delete-character-btn');

    if (loadCharacterBtn) {
        loadCharacterBtn.addEventListener('click', function() {
            if (characterEditorData.selectedCharacterSlot) {
                fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_loadCharacter`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ characterKey: characterEditorData.selectedCharacterSlot })
                });
            }
        });
    }

    if (deleteCharacterBtn) {
        deleteCharacterBtn.addEventListener('click', function() {
            if (characterEditorData.selectedCharacterSlot && confirm('Are you sure you want to delete this character?')) {
                fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_deleteCharacter`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ characterKey: characterEditorData.selectedCharacterSlot })
                });
                
                // Refresh character slots
                updateCharacterSlots();
            }
        });
    }

    // Main action buttons
    const saveBtn = document.getElementById('character-editor-save-btn');
    const cancelBtn = document.getElementById('character-editor-cancel-btn');
    const closeBtn = document.getElementById('character-editor-close-btn');

    if (saveBtn) {
        saveBtn.addEventListener('click', function() {
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_save`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        });
    }

    if (cancelBtn) {
        cancelBtn.addEventListener('click', function() {
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_cancel`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        });
    }

    if (closeBtn) {
        closeBtn.addEventListener('click', function() {
            fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_cancel`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        });
    }
}

function switchCustomizationTab(category) {
    // Update tab buttons
    document.querySelectorAll('.customization-tabs .tab-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.getAttribute('data-category') === category) {
            btn.classList.add('active');
        }
    });

    // Update tab content
    document.querySelectorAll('.customization-tab').forEach(tab => {
        tab.classList.remove('active');
    });

    const targetTab = document.getElementById(category + '-tab');
    if (targetTab) {
        targetTab.classList.add('active');
    }
}

function openCharacterEditor(data) {
    console.log('[CNR_CHARACTER_EDITOR] Opening character editor with data:', data);
    
    // Check if character editor element exists
    const characterEditor = document.getElementById('character-editor');
    if (!characterEditor) {
        console.error('[CNR_CHARACTER_EDITOR] Character editor element not found in DOM');
        // Send error back to client
        fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_error`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Character editor element not found' })
        });
        return;
    }
    
    try {
        characterEditorData.isOpen = true;
        characterEditorData.currentRole = data.role;
        characterEditorData.currentSlot = data.characterSlot;
        characterEditorData.characterData = data.characterData;
        characterEditorData.uniformPresets = data.uniformPresets;

        // Update UI elements
        const roleElement = document.getElementById('character-editor-role');
        const slotElement = document.getElementById('character-editor-slot');
        
        if (roleElement) roleElement.textContent = data.role.charAt(0).toUpperCase() + data.role.slice(1);
        if (slotElement) slotElement.textContent = `Slot ${data.characterSlot}`;

        // Populate uniform presets
        updateUniformPresets();
        
        // Populate character slots
        updateCharacterSlots();
        
        // Update sliders with current character data
        updateSlidersFromCharacterData();

        // Show the character editor
        characterEditor.classList.remove('hidden');
        
        // Ensure the editor is visible
        characterEditor.style.display = 'flex';
        characterEditor.style.visibility = 'visible';
        characterEditor.style.opacity = '1';

        console.log('[CNR_CHARACTER_EDITOR] Successfully opened character editor for', data.role, 'slot', data.characterSlot);
        
        // Send success confirmation back to client
        fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_opened`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ success: true })
        });
        
    } catch (error) {
        console.error('[CNR_CHARACTER_EDITOR] Error opening character editor:', error);
        // Send error back to client
        fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_error`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: error.message })
        });
    }
}

function closeCharacterEditor() {
    console.log('[CNR_CHARACTER_EDITOR] Closing character editor');
    
    try {
        characterEditorData.isOpen = false;
        
        const characterEditor = document.getElementById('character-editor');
        if (characterEditor) {
            characterEditor.classList.add('hidden');
            characterEditor.style.display = 'none';
        }

        // Send close confirmation to client
        fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/characterEditor_closed`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ success: true })
        });

        console.log('[CNR_CHARACTER_EDITOR] Successfully closed character editor');
        
    } catch (error) {
        console.error('[CNR_CHARACTER_EDITOR] Error closing character editor:', error);
    }
}

function updateCharacterSlot(characterKey, characterData) {
    console.log('[CNR_CHARACTER_EDITOR] Updating character slot:', characterKey);
    
    try {
        // Update the character slots display in role selection
        const roleSelectionUI = document.getElementById('role-selection-ui');
        if (roleSelectionUI) {
            // Find character slot elements and update them
            const slotElements = roleSelectionUI.querySelectorAll(`[data-character-key="${characterKey}"]`);
            slotElements.forEach(element => {
                element.classList.remove('empty');
                element.classList.add('filled');
                
                // Update slot display text if it exists
                const slotText = element.querySelector('.slot-status');
                if (slotText) {
                    slotText.textContent = 'Character Created';
                }
            });
        }
        
        console.log('[CNR_CHARACTER_EDITOR] Successfully updated character slot UI');
    } catch (error) {
        console.error('[CNR_CHARACTER_EDITOR] Error updating character slot:', error);
    }
}

function updateUniformPresets() {
    const presetList = document.getElementById('uniform-preset-list');
    if (!presetList || !characterEditorData.uniformPresets) return;

    presetList.innerHTML = '';

    characterEditorData.uniformPresets.forEach((preset, index) => {
        const presetElement = document.createElement('div');
        presetElement.className = 'preset-item';
        presetElement.innerHTML = `
            <h4>${preset.name}</h4>
            <p>${preset.description}</p>
        `;

        presetElement.addEventListener('click', function() {
            // Remove selection from other presets
            document.querySelectorAll('.preset-item').forEach(item => {
                item.classList.remove('selected');
            });
            
            // Select this preset
            this.classList.add('selected');
            characterEditorData.selectedUniformPreset = index;
            
            // Enable preview button
            const previewBtn = document.getElementById('preview-uniform-btn');
            if (previewBtn) previewBtn.disabled = false;
        });

        presetList.appendChild(presetElement);
    });
}

function updateCharacterSlots() {
    const slotList = document.getElementById('character-slot-list');
    if (!slotList) return;

    slotList.innerHTML = '';

    // Create slots for current role
    for (let i = 1; i <= 2; i++) {
        const slotKey = `${characterEditorData.currentRole}_${i}`;
        const hasCharacter = characterEditorData.playerCharacters && characterEditorData.playerCharacters[slotKey];
        
        const slotElement = document.createElement('div');
        slotElement.className = `character-slot ${hasCharacter ? '' : 'empty'}`;
        slotElement.innerHTML = `
            <h4>Slot ${i}</h4>
            <p>${hasCharacter ? 'Character Created' : 'Empty Slot'}</p>
        `;

        if (hasCharacter) {
            slotElement.addEventListener('click', function() {
                // Remove selection from other slots
                document.querySelectorAll('.character-slot').forEach(slot => {
                    slot.classList.remove('selected');
                });
                
                // Select this slot
                this.classList.add('selected');
                characterEditorData.selectedCharacterSlot = slotKey;
                
                // Enable character management buttons
                const loadBtn = document.getElementById('load-character-btn');
                const deleteBtn = document.getElementById('delete-character-btn');
                if (loadBtn) loadBtn.disabled = false;
                if (deleteBtn) deleteBtn.disabled = false;
            });
        }

        slotList.appendChild(slotElement);
    }
}

function updateSlidersFromCharacterData() {
    const characterData = characterEditorData.characterData;
    if (!characterData) return;

    // Update basic appearance sliders
    const basicFeatures = ['face', 'skin', 'hair', 'hairColor', 'hairHighlight', 'eyeColor', 'beard', 'beardColor', 'eyebrows', 'eyebrowsColor'];
    
    basicFeatures.forEach(feature => {
        const slider = document.getElementById(feature.replace(/([A-Z])/g, '-$1').toLowerCase() + '-slider');
        if (slider && characterData[feature] !== undefined) {
            slider.value = characterData[feature];
            
            const valueDisplay = slider.parentElement.querySelector('.slider-value');
            if (valueDisplay) {
                valueDisplay.textContent = characterData[feature].toString();
            }
        }
    });

    // Update facial feature sliders
    if (characterData.faceFeatures) {
        Object.keys(characterData.faceFeatures).forEach(feature => {
            const slider = document.getElementById(feature.replace(/([A-Z])/g, '-$1').toLowerCase() + '-slider');
            if (slider) {
                slider.value = characterData.faceFeatures[feature];
                
                const valueDisplay = slider.parentElement.querySelector('.slider-value');
                if (valueDisplay) {
                    valueDisplay.textContent = characterData.faceFeatures[feature].toFixed(1);
                }
            }
        });
    }
}

// Character Editor Frame Management
function createCharacterEditorFrame() {
    // Remove existing frame if it exists
    const existingFrame = document.getElementById('character-editor-frame');
    if (existingFrame) {
        existingFrame.remove();
    }
    
    // Create iframe for character editor
    const iframe = document.createElement('iframe');
    iframe.id = 'character-editor-frame';
    iframe.src = 'character_editor.html';
    iframe.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        border: none;
        z-index: 2000;
        background: rgba(0, 0, 0, 0.95);
    `;
    
    document.body.appendChild(iframe);
    
    // Forward messages to the iframe
    iframe.onload = function() {
        // Send character editor data to iframe
        if (window.pendingCharacterEditorData) {
            iframe.contentWindow.postMessage({
                action: 'openCharacterEditor',
                ...window.pendingCharacterEditorData
            }, '*');
            window.pendingCharacterEditorData = null;
        }
    };
    
    return iframe;
}

function removeCharacterEditorFrame() {
    const frame = document.getElementById('character-editor-frame');
    if (frame) {
        frame.remove();
    }
}

// Character editor frame handling (keep only frame-specific handlers)
function handleCharacterEditorFrameMessage(data) {
    switch (data.action) {
        case 'openCharacterEditorFrame':
            // Store data for iframe
            window.pendingCharacterEditorData = data;
            createCharacterEditorFrame();
            // Hide main UI
            document.body.style.display = 'none';
            break;
        case 'closeCharacterEditorFrame':
            removeCharacterEditorFrame();
            // Show main UI
            document.body.style.display = 'block';
            break;
        case 'hideMainUI':
            document.body.style.display = 'none';
            break;
        case 'showMainUI':
            document.body.style.display = 'block';
            break;
    }
}

// Handle messages from character editor iframe
window.addEventListener('message', function(event) {
    // Forward character editor messages to FiveM client
    if (event.data && event.data.action && event.data.action.startsWith('characterEditor_')) {
        fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/${event.data.action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(event.data)
        });
    }
});

// ====================================================================
// Enhanced Character Editor Class
// ====================================================================

class EnhancedCharacterEditor {
    constructor() {
        this.isOpen = false;
        this.currentRole = null;
        this.currentSlot = 1;
        this.characterData = {};
        this.uniformPresets = [];
        this.characterSlots = {};
        this.selectedUniformPreset = null;
        this.selectedCharacterSlot = null;
        this.resourceName = window.cnrResourceName || 'cops-and-robbers';
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.setupSliderHandlers();
        console.log('[CNR_CHARACTER_EDITOR] Enhanced Character Editor initialized');
    }

    setupEventListeners() {
        // Close button
        const closeBtn = document.getElementById('close-editor-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                this.closeEditor(false);
            });
        }

        // Camera controls
        document.querySelectorAll('.camera-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.switchCamera(e.target.dataset.camera);
            });
        });

        // Rotation controls
        document.querySelectorAll('.rotate-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.rotateCharacter(e.target.dataset.direction);
            });
        });

        // Gender controls
        document.querySelectorAll('.gender-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.switchGender(e.target.dataset.gender);
            });
        });

        // Tab navigation
        document.querySelectorAll('.tab-button').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.switchTab(e.target.dataset.tab);
            });
        });

        // Uniform actions
        const previewUniformBtn = document.getElementById('preview-uniform-btn');
        const applyUniformBtn = document.getElementById('apply-uniform-btn');
        const cancelPreviewBtn = document.getElementById('cancel-preview-btn');

        if (previewUniformBtn) {
            previewUniformBtn.addEventListener('click', () => {
                this.previewUniform();
            });
        }

        if (applyUniformBtn) {
            applyUniformBtn.addEventListener('click', () => {
                this.applyUniform();
            });
        }

        if (cancelPreviewBtn) {
            cancelPreviewBtn.addEventListener('click', () => {
                this.cancelUniformPreview();
            });
        }

        // Character actions
        const loadCharacterBtn = document.getElementById('load-character-btn');
        const deleteCharacterBtn = document.getElementById('delete-character-btn');
        const createNewBtn = document.getElementById('create-new-btn');

        if (loadCharacterBtn) {
            loadCharacterBtn.addEventListener('click', () => {
                this.loadCharacter();
            });
        }

        if (deleteCharacterBtn) {
            deleteCharacterBtn.addEventListener('click', () => {
                this.deleteCharacter();
            });
        }

        if (createNewBtn) {
            createNewBtn.addEventListener('click', () => {
                this.createNewCharacter();
            });
        }

        // Footer actions
        const saveCharacterBtn = document.getElementById('save-character-btn');
        const cancelEditorBtn = document.getElementById('cancel-editor-btn');
        const resetCharacterBtn = document.getElementById('reset-character-btn');

        if (saveCharacterBtn) {
            saveCharacterBtn.addEventListener('click', () => {
                this.saveCharacter();
            });
        }

        if (cancelEditorBtn) {
            cancelEditorBtn.addEventListener('click', () => {
                this.closeEditor(false);
            });
        }

        if (resetCharacterBtn) {
            resetCharacterBtn.addEventListener('click', () => {
                this.resetCharacter();
            });
        }

        // ESC key to close
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen) {
                this.closeEditor(false);
            }
        });
    }

    setupSliderHandlers() {
        // Handle all sliders in the enhanced character editor
        document.querySelectorAll('#character-editor-container .slider').forEach(slider => {
            slider.addEventListener('input', (e) => {
                this.handleSliderChange(e.target);
            });
        });
    }

    handleSliderChange(slider) {
        const feature = slider.dataset.feature;
        const category = slider.dataset.category || 'basic';
        const component = slider.dataset.component;
        const type = slider.dataset.type;
        const parent = slider.dataset.parent;
        
        let value = parseFloat(slider.value);
        
        // Update value display
        const valueDisplay = slider.parentElement.querySelector('.value-display');
        if (valueDisplay) {
            if (slider.min === '-1' && value === -1) {
                valueDisplay.textContent = 'None';
            } else if (slider.max === '100' && (feature && (feature.includes('Opacity') || feature.includes('opacity')))) {
                valueDisplay.textContent = value + '%';
            } else if (slider.step && slider.step.includes('.')) {
                valueDisplay.textContent = value.toFixed(1);
            } else {
                valueDisplay.textContent = value.toString();
            }
        }

        // Convert percentage values for face features
        if (category === 'faceFeatures') {
            value = value / 100; // Convert to -1.0 to 1.0 range
        }

        // Convert percentage values for opacity
        if (feature && feature.toLowerCase().includes('opacity')) {
            value = value / 100; // Convert to 0.0 to 1.0 range
        }

        // Send update to client
        if (component && type) {
            // Clothing component
            this.sendNUIMessage('characterEditor_updateComponent', {
                component: parseInt(component),
                type: type,
                value: parseInt(value)
            });
        } else {
            // Character feature
            this.sendNUIMessage('characterEditor_updateFeature', {
                category: category,
                feature: feature,
                value: value,
                parent: parent
            });
        }
    }

    switchCamera(mode) {
        // Update active button
        document.querySelectorAll('.camera-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        const activeBtn = document.querySelector(`[data-camera="${mode}"]`);
        if (activeBtn) {
            activeBtn.classList.add('active');
        }

        // Send to client
        this.sendNUIMessage('characterEditor_changeCamera', { mode: mode });
    }

    rotateCharacter(direction) {
        this.sendNUIMessage('characterEditor_rotateCharacter', { direction: direction });
    }

    switchGender(gender) {
        // Update active button
        document.querySelectorAll('.gender-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        const activeBtn = document.querySelector(`[data-gender="${gender}"]`);
        if (activeBtn) {
            activeBtn.classList.add('active');
        }

        // Send to client
        this.sendNUIMessage('characterEditor_switchGender', { gender: gender });
    }

    switchTab(tabName) {
        // Update active tab button
        document.querySelectorAll('.tab-button').forEach(btn => {
            btn.classList.remove('active');
        });
        const activeBtn = document.querySelector(`[data-tab="${tabName}"]`);
        if (activeBtn) {
            activeBtn.classList.add('active');
        }

        // Update active tab panel
        document.querySelectorAll('.tab-panel').forEach(panel => {
            panel.classList.remove('active');
        });
        const targetTab = document.getElementById(`${tabName}-tab`);
        if (targetTab) {
            targetTab.classList.add('active');
        }
    }

    populateUniformPresets() {
        const container = document.getElementById('uniform-presets-container');
        if (!container) return;
        
        container.innerHTML = '';

        if (!this.uniformPresets || this.uniformPresets.length === 0) {
            container.innerHTML = '<p class="info-text">No uniform presets available for this role.</p>';
            return;
        }

        this.uniformPresets.forEach((preset, index) => {
            const presetElement = document.createElement('div');
            presetElement.className = 'uniform-preset';
            presetElement.innerHTML = `
                <h4>${preset.name}</h4>
                <p>${preset.description}</p>
            `;

            presetElement.addEventListener('click', () => {
                this.selectUniformPreset(index);
            });

            container.appendChild(presetElement);
        });
    }

    selectUniformPreset(index) {
        // Remove previous selection
        document.querySelectorAll('.uniform-preset').forEach(preset => {
            preset.classList.remove('selected');
        });

        // Select new preset
        const presets = document.querySelectorAll('.uniform-preset');
        if (presets[index]) {
            presets[index].classList.add('selected');
        }
        this.selectedUniformPreset = index;

        // Enable preview button
        const previewBtn = document.getElementById('preview-uniform-btn');
        if (previewBtn) {
            previewBtn.disabled = false;
        }
    }

    previewUniform() {
        if (this.selectedUniformPreset === null) return;

        console.log('[CNR_CHARACTER_EDITOR] Previewing uniform at JS index:', this.selectedUniformPreset);
        this.sendNUIMessage('characterEditor_previewUniform', {
            presetIndex: this.selectedUniformPreset
        });

        // Enable apply and cancel buttons
        const applyBtn = document.getElementById('apply-uniform-btn');
        const cancelBtn = document.getElementById('cancel-preview-btn');
        if (applyBtn) applyBtn.disabled = false;
        if (cancelBtn) cancelBtn.disabled = false;
    }

    applyUniform() {
        if (this.selectedUniformPreset === null) return;

        this.sendNUIMessage('characterEditor_applyUniform', {
            presetIndex: this.selectedUniformPreset
        });

        // Disable buttons
        const applyBtn = document.getElementById('apply-uniform-btn');
        const cancelBtn = document.getElementById('cancel-preview-btn');
        if (applyBtn) applyBtn.disabled = true;
        if (cancelBtn) cancelBtn.disabled = true;
    }

    cancelUniformPreview() {
        this.sendNUIMessage('characterEditor_cancelUniformPreview', {});

        // Disable buttons
        const applyBtn = document.getElementById('apply-uniform-btn');
        const cancelBtn = document.getElementById('cancel-preview-btn');
        if (applyBtn) applyBtn.disabled = true;
        if (cancelBtn) cancelBtn.disabled = true;
    }

    populateCharacterSlots() {
        const container = document.getElementById('character-slots-container');
        if (!container) return;
        
        container.innerHTML = '';

        // Create slots for current role (1 main + 1 alternate)
        for (let i = 1; i <= 2; i++) {
            const slotKey = `${this.currentRole}_${i}`;
            const hasCharacter = this.characterSlots[slotKey];
            
            const slotElement = document.createElement('div');
            slotElement.className = `character-slot ${hasCharacter ? '' : 'empty'}`;
            slotElement.innerHTML = `
                <h4>Slot ${i}</h4>
                <p>${hasCharacter ? 'Character Created' : 'Empty Slot'}</p>
                ${i === 1 ? '<small>Main Character</small>' : '<small>Alternate Character</small>'}
            `;

            if (hasCharacter) {
                slotElement.addEventListener('click', () => {
                    this.selectCharacterSlot(slotKey, slotElement);
                });
            }

            container.appendChild(slotElement);
        }
    }

    selectCharacterSlot(slotKey, element) {
        // Remove previous selection
        document.querySelectorAll('.character-slot').forEach(slot => {
            slot.classList.remove('selected');
        });

        // Select new slot
        element.classList.add('selected');
        this.selectedCharacterSlot = slotKey;

        // Enable character management buttons
        const loadBtn = document.getElementById('load-character-btn');
        const deleteBtn = document.getElementById('delete-character-btn');
        if (loadBtn) loadBtn.disabled = false;
        if (deleteBtn) deleteBtn.disabled = false;
    }

    loadCharacter() {
        if (!this.selectedCharacterSlot) return;

        this.sendNUIMessage('characterEditor_loadCharacter', {
            characterKey: this.selectedCharacterSlot
        });
    }

    deleteCharacter() {
        if (!this.selectedCharacterSlot) return;

        if (confirm('Are you sure you want to delete this character? This action cannot be undone.')) {
            this.sendNUIMessage('characterEditor_deleteCharacter', {
                characterKey: this.selectedCharacterSlot
            });

            // Refresh character slots
            this.populateCharacterSlots();
            
            // Disable buttons
            const loadBtn = document.getElementById('load-character-btn');
            const deleteBtn = document.getElementById('delete-character-btn');
            if (loadBtn) loadBtn.disabled = true;
            if (deleteBtn) deleteBtn.disabled = true;
            this.selectedCharacterSlot = null;
        }
    }

    createNewCharacter() {
        // Reset to default character
        this.resetCharacter();
    }

    saveCharacter() {
        this.sendNUIMessage('characterEditor_save', {});
    }

    resetCharacter() {
        if (confirm('Are you sure you want to reset the character to default? All current changes will be lost.')) {
            this.sendNUIMessage('characterEditor_reset', {});
            
            // Reset all sliders to default values
            this.resetSlidersToDefault();
        }
    }

    resetSlidersToDefault() {
        document.querySelectorAll('#character-editor-container .slider').forEach(slider => {
            const feature = slider.dataset.feature;
            
            // Set default values based on feature type
            if (feature && (feature.includes('beard') || feature.includes('eyebrows') || feature.includes('makeup') || 
                           feature.includes('blush') || feature.includes('lipstick') || feature.includes('ageing') ||
                           feature.includes('complexion') || feature.includes('sundamage') || feature.includes('freckles') ||
                           feature.includes('moles') || feature.includes('chesthair') || feature.includes('bodyBlemishes'))) {
                slider.value = -1;
            } else if (feature && feature.toLowerCase().includes('opacity')) {
                slider.value = slider.dataset.feature === 'beardOpacity' || slider.dataset.feature === 'eyebrowsOpacity' ? 100 : 0;
            } else if (slider.dataset.category === 'faceFeatures') {
                slider.value = 0;
            } else {
                slider.value = 0;
            }
            
            // Update value display
            const valueDisplay = slider.parentElement.querySelector('.value-display');
            if (valueDisplay) {
                if (slider.value == -1) {
                    valueDisplay.textContent = 'None';
                } else if (feature && feature.toLowerCase().includes('opacity')) {
                    valueDisplay.textContent = slider.value + '%';
                } else {
                    valueDisplay.textContent = slider.value;
                }
            }
        });
    }

    closeEditor(save = false) {
        this.isOpen = false;
        const container = document.getElementById('character-editor-container');
        if (container) {
            container.classList.add('hidden');
        }
        
        this.sendNUIMessage(save ? 'characterEditor_save' : 'characterEditor_cancel', {});
    }

    openEditor(data) {
        this.isOpen = true;
        this.currentRole = data.role;
        this.currentSlot = data.characterSlot || 1;
        this.characterData = data.characterData || {};
        this.uniformPresets = data.uniformPresets || [];
        this.characterSlots = data.playerCharacters || {};

        // Update UI
        const roleElement = document.getElementById('current-role');
        const slotElement = document.getElementById('current-slot');
        if (roleElement) roleElement.textContent = this.currentRole.charAt(0).toUpperCase() + this.currentRole.slice(1);
        if (slotElement) slotElement.textContent = `Slot ${this.currentSlot}`;

        // Populate uniform presets and character slots
        this.populateUniformPresets();
        this.populateCharacterSlots();

        // Update sliders with current character data
        this.updateSlidersFromCharacterData();

        // Show editor
        const container = document.getElementById('character-editor-container');
        if (container) {
            container.classList.remove('hidden');
        }

        console.log('[CNR_CHARACTER_EDITOR] Opened enhanced character editor for', this.currentRole, 'slot', this.currentSlot);
    }

    updateSlidersFromCharacterData() {
        if (!this.characterData) return;

        // Update basic appearance sliders
        const basicFeatures = ['hair', 'hairColor', 'hairHighlight', 'eyeColor', 'beard', 'beardColor', 'beardOpacity',
                              'eyebrows', 'eyebrowsColor', 'eyebrowsOpacity', 'makeup', 'makeupColor', 'makeupOpacity',
                              'blush', 'blushColor', 'blushOpacity', 'lipstick', 'lipstickColor', 'lipstickOpacity'];
        
        basicFeatures.forEach(feature => {
            const slider = document.querySelector(`#character-editor-container [data-feature="${feature}"]`);
            if (slider && this.characterData[feature] !== undefined) {
                let value = this.characterData[feature];
                
                // Convert opacity values to percentage
                if (feature.toLowerCase().includes('opacity')) {
                    value = Math.round(value * 100);
                }
                
                slider.value = value;
                
                const valueDisplay = slider.parentElement.querySelector('.value-display');
                if (valueDisplay) {
                    if (value === -1) {
                        valueDisplay.textContent = 'None';
                    } else if (feature.toLowerCase().includes('opacity')) {
                        valueDisplay.textContent = value + '%';
                    } else {
                        valueDisplay.textContent = value.toString();
                    }
                }
            }
        });

        // Update facial feature sliders
        if (this.characterData.faceFeatures) {
            Object.keys(this.characterData.faceFeatures).forEach(feature => {
                const slider = document.querySelector(`#character-editor-container [data-feature="${feature}"]`);
                if (slider) {
                    const value = Math.round(this.characterData.faceFeatures[feature] * 100); // Convert to percentage
                    slider.value = value;
                    
                    const valueDisplay = slider.parentElement.querySelector('.value-display');
                    if (valueDisplay) {
                        valueDisplay.textContent = value.toString();
                    }
                }
            });
        }
    }

    sendNUIMessage(action, data) {
        fetch(`https://${this.resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).catch(error => {
            console.error('[CNR_CHARACTER_EDITOR] Error sending NUI message:', error);
        });
    }
}

// Initialize enhanced character editor when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    if (!window.enhancedCharacterEditor) {
        window.enhancedCharacterEditor = new EnhancedCharacterEditor();
    }
});

// Enhanced character editor integration (removed duplicate handler to prevent conflicts)

// ==========================================================================
// ENHANCED PROGRESSION SYSTEM JAVASCRIPT
// ==========================================================================

class ProgressionSystem {
    constructor() {
        this.currentPlayerData = {
            level: 1,
            xp: 0,
            xpForNext: 100,
            prestigeLevel: 0,
            prestigeTitle: "Rookie",
            abilities: {},
            challenges: {},
            seasonalEvent: null
        };
        
        this.notifications = [];
        this.animationQueue = [];
        this.isProgressionMenuOpen = false;
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.setupProgressionMenu();
        this.setupAbilityBar();
        this.initializeUI();
        
        console.log('[CNR_PROGRESSION] Enhanced Progression System initialized');
    }
    
    setupEventListeners() {
        // Progression menu toggle
        document.addEventListener('keydown', (e) => {
            if (e.key === 'p' || e.key === 'P') {
                if (!this.isProgressionMenuOpen) {
                    this.toggleProgressionMenu();
                }
            }
            
            // Ability hotkeys
            if (e.key === 'z' || e.key === 'Z') {
                this.useAbility(1);
            }
            if (e.key === 'x' || e.key === 'X') {
                this.useAbility(2);
            }
        });
        
        // Close progression menu
        const closeBtn = document.getElementById('close-progression-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                this.toggleProgressionMenu();
            });
        }
        
        // Progression tabs
        const tabs = document.querySelectorAll('.progression-tab');
        tabs.forEach(tab => {
            tab.addEventListener('click', () => {
                this.switchProgressionTab(tab.dataset.tab);
            });
        });
        
        // Prestige button
        const prestigeBtn = document.getElementById('prestige-btn');
        if (prestigeBtn) {
            prestigeBtn.addEventListener('click', () => {
                this.requestPrestige();
            });
        }
        
        // Close event banner
        const closeEventBtn = document.getElementById('close-event-banner');
        if (closeEventBtn) {
            closeEventBtn.addEventListener('click', () => {
                this.hideSeasonalEventBanner();
            });
        }
    }
    
    setupProgressionMenu() {
        // Initialize tab content
        this.switchProgressionTab('overview');
    }
    
    setupAbilityBar() {
        const abilitySlots = document.querySelectorAll('.ability-slot');
        abilitySlots.forEach((slot, index) => {
            slot.addEventListener('click', () => {
                this.useAbility(index + 1);
            });
        });
    }
    
    initializeUI() {
        this.updateXPDisplay();
        this.updateProgressionOverview();
    }
    
    // ==========================================================================
    // XP AND LEVEL SYSTEM
    // ==========================================================================
    
    updateProgressionDisplay(data) {
        this.currentPlayerData = { ...this.currentPlayerData, ...data };
        this.updateXPDisplay();
        this.updateProgressionOverview();
        
        // Update prestige indicator
        const prestigeIndicator = document.getElementById('prestige-indicator');
        if (prestigeIndicator) {
            if (data.prestigeInfo && data.prestigeInfo.level > 0) {
                prestigeIndicator.textContent = `★${data.prestigeInfo.level}`;
                prestigeIndicator.classList.remove('hidden');
            } else {
                prestigeIndicator.classList.add('hidden');
            }
        }
        
        // Update seasonal event indicator
        if (data.seasonalEvent) {
            this.showSeasonalEventIndicator(data.seasonalEvent);
        }
    }
    
    updateXPDisplay() {
        const data = this.currentPlayerData;
        
        // Update level text
        const levelText = document.getElementById('level-text');
        if (levelText) {
            levelText.textContent = data.level || 1;
        }
        
        // Update XP text
        const xpText = document.getElementById('xp-text');
        if (xpText) {
            const currentXPInLevel = data.xpInCurrentLevel || 0;
            const xpForNext = data.xpForNextLevel || 100;
            xpText.textContent = `${currentXPInLevel} / ${xpForNext} XP`;
        }
        
        // Update progress bar
        const xpBarFill = document.getElementById('xp-bar-fill');
        if (xpBarFill) {
            const progressPercent = data.progressPercent || 0;
            xpBarFill.style.width = `${Math.min(progressPercent, 100)}%`;
        }
        
        // Update XP gain indicator
        if (data.xpGained && data.xpGained > 0) {
            this.showXPGainIndicator(data.xpGained);
        }
    }
    
    showXPGainIndicator(amount) {
        const indicator = document.getElementById('xp-gain-indicator');
        if (indicator) {
            indicator.textContent = `+${amount}`;
            indicator.classList.remove('hidden');
            
            setTimeout(() => {
                indicator.classList.add('hidden');
            }, 2000);
        }
    }
    
    showXPGainAnimation(amount, reason) {
        const animation = document.getElementById('xp-gain-animation');
        const amountEl = document.getElementById('xp-gain-amount');
        const reasonEl = document.getElementById('xp-gain-reason');
        
        if (animation && amountEl && reasonEl) {
            amountEl.textContent = `+${amount} XP`;
            reasonEl.textContent = reason || 'Action';
            
            animation.classList.remove('hidden');
            animation.classList.add('show');
            
            setTimeout(() => {
                animation.classList.remove('show');
                setTimeout(() => {
                    animation.classList.add('hidden');
                }, 300);
            }, 2000);
        }
    }
    
    showLevelUpAnimation(newLevel) {
        const animation = document.getElementById('level-up-animation');
        const levelText = document.getElementById('level-up-text');
        
        if (animation && levelText) {
            levelText.textContent = `You reached Level ${newLevel}!`;
            
            animation.classList.remove('hidden');
            animation.classList.add('show');
            
            // Play sound effect (if available)
            this.playSound('levelup');
            
            setTimeout(() => {
                animation.classList.remove('show');
                setTimeout(() => {
                    animation.classList.add('hidden');
                }, 500);
            }, 3000);
        }
    }
    
    // ==========================================================================
    // UNLOCK SYSTEM
    // ==========================================================================
    
    showUnlockNotification(unlock, level) {
        const notification = document.getElementById('unlock-notification');
        const iconEl = document.getElementById('unlock-icon-element');
        const titleEl = document.getElementById('unlock-title');
        const messageEl = document.getElementById('unlock-message');
        
        if (notification && iconEl && titleEl && messageEl) {
            // Set icon based on unlock type
            const iconMap = {
                'item_access': 'fas fa-unlock',
                'vehicle_access': 'fas fa-car',
                'ability': 'fas fa-magic',
                'passive_perk': 'fas fa-star',
                'cash_reward': 'fas fa-dollar-sign'
            };
            
            iconEl.className = iconMap[unlock.type] || 'fas fa-unlock';
            titleEl.textContent = `Level ${level} Unlock!`;
            messageEl.textContent = unlock.message;
            
            notification.classList.remove('hidden');
            notification.classList.add('show');
            
            setTimeout(() => {
                notification.classList.remove('show');
                setTimeout(() => {
                    notification.classList.add('hidden');
                }, 300);
            }, 5000);
        }
    }
    
    // ==========================================================================
    // PROGRESSION MENU
    // ==========================================================================
    
    toggleProgressionMenu() {
        const menu = document.getElementById('progression-menu');
        if (menu) {
            this.isProgressionMenuOpen = !this.isProgressionMenuOpen;
            
            if (this.isProgressionMenuOpen) {
                menu.classList.add('show');
                this.updateProgressionMenuContent();
                // Enable cursor for interaction
                this.setNuiFocus(true, true);
            } else {
                menu.classList.remove('show');
                // Disable cursor
                this.setNuiFocus(false, false);
            }
        }
    }
    
    switchProgressionTab(tabName) {
        // Update tab buttons
        const tabs = document.querySelectorAll('.progression-tab');
        tabs.forEach(tab => {
            if (tab.dataset.tab === tabName) {
                tab.classList.add('active');
            } else {
                tab.classList.remove('active');
            }
        });
        
        // Update tab content
        const contents = document.querySelectorAll('.progression-tab-content');
        contents.forEach(content => {
            if (content.id === `${tabName}-tab`) {
                content.classList.add('active');
            } else {
                content.classList.remove('active');
            }
        });
        
        // Load tab-specific content
        switch (tabName) {
            case 'overview':
                this.updateProgressionOverview();
                break;
            case 'unlocks':
                this.updateUnlocksTab();
                break;
            case 'abilities':
                this.updateAbilitiesTab();
                break;
            case 'challenges':
                this.updateChallengesTab();
                break;
            case 'prestige':
                this.updatePrestigeTab();
                break;
        }
    }
    
    updateProgressionMenuContent() {
        this.updateProgressionOverview();
        this.updateUnlocksTab();
        this.updateAbilitiesTab();
        this.updateChallengesTab();
        this.updatePrestigeTab();
    }
    
    updateProgressionOverview() {
        const data = this.currentPlayerData;
        
        // Update stats
        const levelEl = document.getElementById('overview-level');
        const totalXpEl = document.getElementById('overview-total-xp');
        const xpNeededEl = document.getElementById('overview-xp-needed');
        const prestigeEl = document.getElementById('overview-prestige');
        
        if (levelEl) levelEl.textContent = data.level || 1;
        if (totalXpEl) totalXpEl.textContent = (data.xp || 0).toLocaleString();
        if (xpNeededEl) xpNeededEl.textContent = (data.xpForNext || 100).toLocaleString();
        if (prestigeEl) prestigeEl.textContent = data.prestigeLevel || 0;
        
        // Update circular progress
        const progressPercent = data.progressPercent || 0;
        const progressRing = document.getElementById('progress-ring-fill');
        const progressText = document.getElementById('progress-percentage');
        
        if (progressRing) {
            const circumference = 2 * Math.PI * 52; // radius = 52
            const strokeDasharray = (progressPercent / 100) * circumference;
            progressRing.style.strokeDasharray = `${strokeDasharray} ${circumference}`;
        }
        
        if (progressText) {
            progressText.textContent = `${Math.round(progressPercent)}%`;
        }
    }
    
    updateUnlocksTab() {
        const container = document.getElementById('unlock-tree-content');
        if (!container) return;
        
        // This would be populated with actual unlock data from the server
        container.innerHTML = '<p style="color: var(--text-secondary); text-align: center;">Unlock tree will be populated with your progression data.</p>';
    }
    
    updateAbilitiesTab() {
        const container = document.getElementById('abilities-grid');
        if (!container) return;
        
        const abilities = this.currentPlayerData.abilities || {};
        container.innerHTML = '';
        
        // Example abilities (would come from server data)
        const exampleAbilities = [
            { id: 'smoke_bomb', name: 'Smoke Bomb', description: 'Create a smoke screen for quick escapes', unlocked: false, cooldown: 0 },
            { id: 'adrenaline_rush', name: 'Adrenaline Rush', description: 'Temporary speed boost during escapes', unlocked: false, cooldown: 0 }
        ];
        
        exampleAbilities.forEach(ability => {
            const abilityCard = document.createElement('div');
            abilityCard.className = `ability-card ${ability.unlocked ? 'unlocked' : 'locked'} ${ability.cooldown > 0 ? 'on-cooldown' : ''}`;
            
            abilityCard.innerHTML = `
                <div class="ability-icon-large">
                    <i class="fas fa-magic"></i>
                </div>
                <div class="ability-name">${ability.name}</div>
                <div class="ability-description">${ability.description}</div>
                ${ability.cooldown > 0 ? `<div class="ability-cooldown-text">Cooldown: ${Math.ceil(ability.cooldown / 1000)}s</div>` : ''}
            `;
            
            if (ability.unlocked && ability.cooldown === 0) {
                abilityCard.addEventListener('click', () => {
                    this.triggerAbility(ability.id);
                });
            }
            
            container.appendChild(abilityCard);
        });
    }
    
    updateChallengesTab() {
        const dailyContainer = document.getElementById('daily-challenges');
        const weeklyContainer = document.getElementById('weekly-challenges');
        
        if (dailyContainer) {
            dailyContainer.innerHTML = '<p style="color: var(--text-secondary); text-align: center;">Daily challenges will be populated here.</p>';
        }
        
        if (weeklyContainer) {
            weeklyContainer.innerHTML = '<p style="color: var(--text-secondary); text-align: center;">Weekly challenges will be populated here.</p>';
        }
    }
    
    updatePrestigeTab() {
        const data = this.currentPlayerData;
        
        // Update current prestige
        const prestigeLevelEl = document.getElementById('current-prestige-level');
        const prestigeTitleEl = document.getElementById('current-prestige-title');
        const currentLevelEl = document.getElementById('prestige-current-level');
        const prestigeBtn = document.getElementById('prestige-btn');
        
        if (prestigeLevelEl) prestigeLevelEl.textContent = data.prestigeLevel || 0;
        if (prestigeTitleEl) prestigeTitleEl.textContent = data.prestigeTitle || 'Rookie';
        if (currentLevelEl) currentLevelEl.textContent = data.level || 1;
        
        // Update prestige button state
        if (prestigeBtn) {
            const canPrestige = (data.level || 1) >= 50; // Max level requirement
            if (canPrestige) {
                prestigeBtn.classList.remove('disabled');
            } else {
                prestigeBtn.classList.add('disabled');
            }
        }
        
        // Update next prestige rewards
        const rewardsContainer = document.getElementById('next-prestige-rewards');
        if (rewardsContainer) {
            const nextPrestigeLevel = (data.prestigeLevel || 0) + 1;
            rewardsContainer.innerHTML = `
                <div class="reward-item">
                    <i class="fas fa-dollar-sign reward-icon"></i>
                    <span class="reward-text">Cash Bonus: $${(nextPrestigeLevel * 100000).toLocaleString()}</span>
                </div>
                <div class="reward-item">
                    <i class="fas fa-crown reward-icon"></i>
                    <span class="reward-text">Title: Prestige ${nextPrestigeLevel}</span>
                </div>
                <div class="reward-item">
                    <i class="fas fa-chart-line reward-icon"></i>
                    <span class="reward-text">XP Multiplier: ${1 + (nextPrestigeLevel * 0.1)}x</span>
                </div>
            `;
        }
    }
    
    // ==========================================================================
    // ABILITY SYSTEM
    // ==========================================================================
    
    useAbility(slotNumber) {
        const slot = document.querySelector(`.ability-slot[data-slot="${slotNumber}"]`);
        if (!slot) return;
        
        // Check if ability is available and not on cooldown
        const cooldownOverlay = slot.querySelector('.cooldown-overlay');
        if (cooldownOverlay && cooldownOverlay.style.transform !== 'scaleY(0)') {
            this.showNotification('Ability is on cooldown!', 'warning');
            return;
        }
        
        // Trigger ability on server
        this.sendNuiMessage('useAbility', { slot: slotNumber });
        
        // Start cooldown animation
        this.startAbilityCooldown(slotNumber, 60000); // 60 second cooldown
    }
    
    triggerAbility(abilityId) {
        this.sendNuiMessage('triggerAbility', { abilityId: abilityId });
    }
    
    startAbilityCooldown(slotNumber, duration) {
        const slot = document.querySelector(`.ability-slot[data-slot="${slotNumber}"]`);
        if (!slot) return;
        
        const cooldownOverlay = slot.querySelector('.cooldown-overlay');
        const cooldownText = slot.querySelector('.cooldown-text');
        
        if (cooldownOverlay && cooldownText) {
            cooldownOverlay.style.transform = 'scaleY(1)';
            
            let remaining = duration;
            const interval = setInterval(() => {
                remaining -= 100;
                const progress = 1 - (remaining / duration);
                cooldownOverlay.style.transform = `scaleY(${1 - progress})`;
                
                if (remaining <= 0) {
                    clearInterval(interval);
                    cooldownOverlay.style.transform = 'scaleY(0)';
                }
            }, 100);
        }
    }
    
    // ==========================================================================
    // CHALLENGE SYSTEM
    // ==========================================================================
    
    updateChallengeProgress(challengeId, challengeData) {
        // Update challenge in current data
        if (!this.currentPlayerData.challenges) {
            this.currentPlayerData.challenges = {};
        }
        this.currentPlayerData.challenges[challengeId] = challengeData;
        
        // Show progress notification
        const progressPercent = (challengeData.progress / challengeData.target) * 100;
        if (progressPercent >= 25 && progressPercent < 100) {
            this.showChallengeProgressNotification(challengeId, challengeData);
        }
        
        // Update challenges tab if open
        if (this.isProgressionMenuOpen) {
            this.updateChallengesTab();
        }
    }
    
    showChallengeProgressNotification(challengeId, challengeData) {
        const notification = document.getElementById('challenge-progress-notification');
        const nameEl = document.getElementById('challenge-name');
        const progressFill = document.getElementById('challenge-progress-fill');
        const progressText = document.getElementById('challenge-progress-text');
        
        if (notification && nameEl && progressFill && progressText) {
            nameEl.textContent = challengeData.name || 'Challenge';
            progressText.textContent = `${challengeData.progress}/${challengeData.target}`;
            
            const progressPercent = (challengeData.progress / challengeData.target) * 100;
            progressFill.style.width = `${progressPercent}%`;
            
            notification.classList.remove('hidden');
            notification.classList.add('show');
            
            setTimeout(() => {
                notification.classList.remove('show');
                setTimeout(() => {
                    notification.classList.add('hidden');
                }, 300);
            }, 3000);
        }
    }
    
    challengeCompleted(challengeId, challengeData) {
        this.showNotification(`🏆 Challenge Completed: ${challengeData.name || 'Challenge'}!`, 'success');
        this.playSound('challenge_complete');
    }
    
    // ==========================================================================
    // PRESTIGE SYSTEM
    // ==========================================================================
    
    requestPrestige() {
        const data = this.currentPlayerData;
        if ((data.level || 1) < 50) {
            this.showNotification('You must reach level 50 to prestige!', 'warning');
            return;
        }
        
        // Show confirmation dialog
        if (confirm('Are you sure you want to prestige? This will reset your level to 1 but grant powerful bonuses!')) {
            this.sendNuiMessage('requestPrestige', {});
        }
    }
    
    prestigeCompleted(prestigeLevel, prestigeReward) {
        this.showPrestigeAnimation(prestigeLevel, prestigeReward);
        this.currentPlayerData.prestigeLevel = prestigeLevel;
        this.currentPlayerData.prestigeTitle = prestigeReward.title;
        this.updateProgressionDisplay(this.currentPlayerData);
    }
    
    showPrestigeAnimation(prestigeLevel, prestigeReward) {
        const animation = document.getElementById('prestige-animation');
        const prestigeText = document.getElementById('prestige-text');
        
        if (animation && prestigeText) {
            prestigeText.textContent = `You achieved ${prestigeReward.title} (Prestige ${prestigeLevel})!`;
            
            animation.classList.remove('hidden');
            animation.classList.add('show');
            
            this.playSound('prestige');
            
            setTimeout(() => {
                animation.classList.remove('show');
                setTimeout(() => {
                    animation.classList.add('hidden');
                }, 500);
            }, 4000);
        }
    }
    
    // ==========================================================================
    // SEASONAL EVENTS
    // ==========================================================================
    
    showSeasonalEventIndicator(eventData) {
        const indicator = document.getElementById('seasonal-event-indicator');
        const textEl = document.getElementById('seasonal-event-text');
        
        if (indicator && textEl) {
            textEl.textContent = eventData.name;
            indicator.classList.remove('hidden');
        }
        
        this.showSeasonalEventBanner(eventData);
    }
    
    showSeasonalEventBanner(eventData) {
        const banner = document.getElementById('seasonal-event-banner');
        const nameEl = document.getElementById('event-name');
        const descEl = document.getElementById('event-description');
        
        if (banner && nameEl && descEl) {
            nameEl.textContent = eventData.name;
            descEl.textContent = eventData.description;
            
            banner.classList.remove('hidden');
            
            // Auto-hide after 10 seconds
            setTimeout(() => {
                this.hideSeasonalEventBanner();
            }, 10000);
        }
    }
    
    hideSeasonalEventBanner() {
        const banner = document.getElementById('seasonal-event-banner');
        if (banner) {
            banner.classList.add('hidden');
        }
    }
    
    seasonalEventEnded(eventName) {
        const indicator = document.getElementById('seasonal-event-indicator');
        if (indicator) {
            indicator.classList.add('hidden');
        }
        
        this.showNotification(`📅 Event Ended: ${eventName}`, 'info');
    }
    
    // ==========================================================================
    // NOTIFICATION SYSTEM
    // ==========================================================================
    
    showProgressionNotification(message, type, duration = 5000) {
        const container = document.getElementById('notification-container');
        if (!container) return;
        
        const notification = document.createElement('div');
        notification.className = `progression-notification ${type}`;
        
        const iconMap = {
            'xp': 'fas fa-plus-circle',
            'levelup': 'fas fa-trophy',
            'ability': 'fas fa-magic',
            'event': 'fas fa-calendar-star',
            'success': 'fas fa-check-circle',
            'warning': 'fas fa-exclamation-triangle',
            'error': 'fas fa-times-circle',
            'info': 'fas fa-info-circle'
        };
        
        notification.innerHTML = `
            <div class="notification-content">
                <i class="${iconMap[type] || 'fas fa-info-circle'} notification-icon"></i>
                <span class="notification-text">${message}</span>
            </div>
        `;
        
        container.appendChild(notification);
        
        // Animate in
        setTimeout(() => {
            notification.classList.add('show');
        }, 100);
        
        // Remove after duration
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        }, duration);
    }
    
    showNotification(message, type = 'info', duration = 5000) {
        this.showProgressionNotification(message, type, duration);
    }
    
    // ==========================================================================
    // UTILITY FUNCTIONS
    // ==========================================================================
    
    playSound(soundType) {
        // This would trigger sound effects in the game
        this.sendNuiMessage('playSound', { soundType: soundType });
    }
    
    setNuiFocus(hasFocus, hasCursor) {
        this.sendNuiMessage('setNuiFocus', { hasFocus: hasFocus, hasCursor: hasCursor });
    }
    
    sendNuiMessage(action, data = {}) {
        fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).catch(error => {
            console.error(`[CNR_PROGRESSION] Error sending NUI message ${action}:`, error);
        });
    }
}

// Initialize the progression system
let progressionSystem = null;

// Enhanced message handling for progression system
const originalMessageHandler = window.addEventListener;
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (!progressionSystem) {
        progressionSystem = new ProgressionSystem();
    }
    
    // Handle progression-specific messages
    switch (data.action) {
        case 'updateProgressionDisplay':
            progressionSystem.updateProgressionDisplay(data.data);
            break;
            
        case 'showXPGainAnimation':
            progressionSystem.showXPGainAnimation(data.amount, data.reason);
            break;
            
        case 'showLevelUpAnimation':
            progressionSystem.showLevelUpAnimation(data.newLevel);
            break;
            
        case 'showUnlockNotification':
            progressionSystem.showUnlockNotification(data.unlock, data.level);
            break;
            
        case 'abilityUnlocked':
            progressionSystem.showNotification(`⚡ New Ability: ${data.ability.name}`, 'ability');
            break;
            
        case 'abilityUsed':
            progressionSystem.startAbilityCooldown(data.slot || 1, data.cooldown || 60000);
            break;
            
        case 'updateChallengeProgress':
            progressionSystem.updateChallengeProgress(data.challengeId, data.challengeData);
            break;
            
        case 'challengeCompleted':
            progressionSystem.challengeCompleted(data.challengeId, data.challengeData);
            break;
            
        case 'prestigeCompleted':
            progressionSystem.prestigeCompleted(data.prestigeLevel, data.prestigeReward);
            break;
            
        case 'seasonalEventStarted':
            progressionSystem.showSeasonalEventIndicator(data.eventData);
            break;
            
        case 'seasonalEventEnded':
            progressionSystem.seasonalEventEnded(data.eventName);
            break;
            
        case 'showProgressionNotification':
            progressionSystem.showProgressionNotification(data.message, data.type, data.duration);
            break;
    }
});

// Initialize progression system when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    if (!progressionSystem) {
        progressionSystem = new ProgressionSystem();
    }
});

console.log('[CNR_PROGRESSION] Enhanced Progression System JavaScript loaded');
