// html/scripts.js
// Handles NUI interactions for Cops and Robbers game mode.

window.cnrResourceName = 'cops-and-robbers'; // Default fallback, updated by Lua
let fullItemConfig = null; // Will store Config.Items

// =================================================================---
// NUI Message Handling & Security
// =================================================================---
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
            // Legacy case: Just store the cash value, don't show notification
            // The new store UI handles cash display directly from playerInfo
            if (typeof data.cash === 'number') {
                previousCash = data.cash;
                console.log('[CNR_NUI_DEBUG] updateMoney legacy handler - cash stored:', data.cash);
            }
            break;case 'showStoreMenu':
        case 'openStore':
            if (data.resourceName) {
                window.cnrResourceName = data.resourceName;
                const currentResourceOriginDynamic = `nui://${window.cnrResourceName}`;
                if (!allowedOrigins.includes(currentResourceOriginDynamic)) {
                    allowedOrigins.push(currentResourceOriginDynamic);
                }
            }
            openStoreMenu(data.storeName, data.items, data.playerInfo);
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
            break;
        case 'showBountyBoard':
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
            break;
        case 'hideRoleSelection':
            const roleMenu = document.getElementById('roleSelectionMenu');
            if (roleMenu) roleMenu.style.display = 'none';
            break;
        case 'roleSelectionFailed':
            showToast(data.error || 'Failed to select role. Please try again.', 'error', 4000);
            showRoleSelection();
            break;        case 'storeFullItemConfig':
            if (data.itemConfig) {
                fullItemConfig = data.itemConfig;
                console.log('[CNR_NUI] Stored full item config. Item count:', fullItemConfig ? Object.keys(fullItemConfig).length : 0);
            }
            break;        case 'refreshInventory':
            // Refresh the sell tab if it's currently active
            const storeMenuElement = document.getElementById('store-menu');
            if (storeMenuElement && storeMenuElement.style.display === 'block' && window.currentTab === 'sell') {
                loadSellItems();
            }
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
        console.log('[CNR_NUI_DEBUG] cash value:', window.playerInfo.cash);
        
        // Update player info display and check for cash changes
        const newCash = window.playerInfo.cash || 0;
        if (playerCashEl) {
            playerCashEl.textContent = `$${newCash.toLocaleString()}`;
            console.log('[CNR_NUI_DEBUG] Updated cash display to:', `$${newCash.toLocaleString()}`);
        }
        if (playerLevelEl) playerLevelEl.textContent = `Level ${window.playerInfo.level || 1}`;
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
    if (!gridContainer) return;
    
    // Clear existing items
    gridContainer.innerHTML = '';
    
    // Add debug info for scrollbar testing
    console.log('[CNR_NUI_DEBUG] loadGridItems called. Items count:', window.items ? window.items.length : 0);
    
    // Force minimum content for scrollbar testing
    const minItemsForScroll = 20;
    let itemsToRender = window.items || [];
    
    // If not enough items, duplicate some to test scrollbar
    if (itemsToRender.length < minItemsForScroll) {
        const duplicatedItems = [];
        for (let i = 0; i < minItemsForScroll; i++) {
            if (itemsToRender.length > 0) {
                duplicatedItems.push({...itemsToRender[i % itemsToRender.length], id: `${itemsToRender[i % itemsToRender.length].id}_dup_${i}`});
            }
        }
        itemsToRender = duplicatedItems;
        console.log('[CNR_NUI_DEBUG] Duplicated items for scrollbar testing. New count:', itemsToRender.length);
    }

    // ...existing code...
}

function loadSellGridItems() {
    const sellGrid = document.getElementById('sell-inventory-grid');
    if (!sellGrid) return;
    
    // Fetch player inventory from server
    const resName = window.cnrResourceName || 'cops-and-robbers';
    fetch(`https://${resName}/getPlayerInventory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(response => response.json())    .then(data => {
        sellGrid.innerHTML = '';
        const minimalInventory = data.inventory || []; // Server returns { inventory: [...] }
        
        if (!fullItemConfig) {
            console.error('[CNR_NUI] fullItemConfig not available. Cannot reconstruct sell list details.');
            sellGrid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.6); padding: 40px;">Error: Item configuration not loaded.</div>';
            return;
        }
        
        if (!minimalInventory || minimalInventory.length === 0) {
            sellGrid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.6); padding: 40px;">Your inventory is empty.</div>';
            return;
        }
        
        const fragment = document.createDocumentFragment();
        minimalInventory.forEach(minItem => {
            if (minItem.count > 0) {
                // Look up full item details from config
                let itemDetails = null;
                if (Array.isArray(fullItemConfig)) {
                    // If fullItemConfig is an array
                    itemDetails = fullItemConfig.find(configItem => configItem.itemId === minItem.itemId);
                } else {
                    // If fullItemConfig is an object
                    itemDetails = fullItemConfig[minItem.itemId];
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
                        name: itemDetails.name,
                        count: minItem.count,
                        category: itemDetails.category,
                        sellPrice: sellPrice
                    };
                    
                    fragment.appendChild(createInventorySlot(richItem, 'sell'));
                } else {
                    console.warn(`[CNR_NUI] ItemId ${minItem.itemId} from inventory not found in fullItemConfig. Skipping.`);
                }
            }
        });
        sellGrid.appendChild(fragment);
    }).catch(error => {
        console.error('Error loading sell inventory:', error);
        sellGrid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: rgba(255,255,255,0.6); padding: 40px;">Error loading inventory.</div>';
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
    
    const itemIcon = document.createElement('div');
    itemIcon.className = 'item-icon';
    itemIcon.textContent = item.icon || getItemIcon(item.category, item.name);
    
    iconContainer.appendChild(itemIcon);
    
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
    itemName.textContent = item.name;
    itemInfo.appendChild(itemName);
    
    const itemPrice = document.createElement('div');
    itemPrice.className = 'item-price';
    itemPrice.textContent = `$${(type === 'buy' ? item.price : item.sellPrice)}`;
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
