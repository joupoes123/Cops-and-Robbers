// html/scripts.js
// Handles NUI interactions for Cops and Robbers game mode.

window.cnrResourceName = 'cops-and-robbers'; // Default fallback, updated by Lua
let fullItemConfig = null; // Will store Config.Items

// Inventory state variables
let isInventoryOpen = false;
let currentInventoryData = null;
let currentEquippedItems = null;

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
        default:
            console.warn(`Unhandled NUI action: ${data.action}`);
    }
});

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
            if (button) selectRole(button.getAttribute('data-role'));
        });
    } else {
        document.querySelectorAll('.menu button[data-role]').forEach(button => {
            button.addEventListener('click', () => selectRole(button.getAttribute('data-role')));
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
});
