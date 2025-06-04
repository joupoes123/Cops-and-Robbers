// html/scripts.js
// Handles NUI interactions for Cops and Robbers game mode.

// =================================================================---
// NUI Message Handling & Security
// =================================================================---

// Allowed origins: include your resource's NUI origin and any other trusted domains.
const allowedOrigins = [
    `nui://${typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'cops-and-robbers'}`, // Dynamically set resource name
    "http://localhost:3000",   // Example for local development, remove if not used.
    "nui://game" // Added to trust messages from this origin
];

// Secure postMessage listener with strict origin validation.
window.addEventListener('message', function(event) {
    // Validate the origin of the incoming message.
    if (!allowedOrigins.includes(event.origin)) {
        // It's crucial to ignore messages from untrusted origins.
        console.warn(`Security: Received message from untrusted origin: ${event.origin}. Ignoring.`);
        return;
    }
  
    const data = event.data; // The payload from the Lua script.
  
    // Route actions based on the 'action' property in the message data.
    switch (data.action) {
        case 'showRoleSelection':
            showRoleSelection();
            break;
        case 'updateMoney':
            updateCashDisplay(data.cash);
            break;
        case 'showStoreMenu':
            openStoreMenu(data.storeName, data.items);
            break;
        case 'closeStore':
            closeStoreMenu();
            break;
        case 'startHeistTimer':
            startHeistTimer(data.duration, data.bankName);
            break;
        case 'updateXPBar': // New case for XP Bar
            updateXPDisplayElements(data.currentXP, data.currentLevel, data.xpForNextLevel);
            break;
        case 'refreshSellListIfNeeded':
            // Only refresh if store is open and sell tab is active
            const storeMenu = document.getElementById('store-menu');
            if (storeMenu && storeMenu.style.display === 'block' && window.currentTab === 'sell') {
                console.log("Refreshing sell list due to inventory update:", data.inventory);
                // The data.inventory here is the raw pData.inventory format from server.
                // We need to transform it to the array format expected by createItemElement.
                const sellableItems = [];
                for (const itemId in data.inventory) {
                    const item = data.inventory[itemId];
                    // Find basePrice from window.items (buyable items list) to calculate sellPrice
                    // This assumes window.items is populated when store opens.
                    // A better way would be for server to send sellPrice directly.
                    // The server.lua change in step 4 now sends sellPrice.
                    sellableItems.push({
                        itemId: itemId,
                        name: item.name,
                        count: item.count,
                        category: item.category, // Optional, if NUI needs it
                        sellPrice: item.sellPrice // Assuming server now sends this (as per server.lua change)
                    });
                }
                const sellListContainer = document.getElementById('sell-section');
                if (sellListContainer) {
                    sellListContainer.innerHTML = ''; // Clear
                    if (sellableItems.length === 0) {
                        sellListContainer.innerHTML = '<p style="text-align: center;">Your inventory is empty.</p>';
                    } else {
                        const fragment = document.createDocumentFragment();
                        sellableItems.forEach(invItem => {
                            fragment.appendChild(createItemElement(invItem, 'sell'));
                        });
                        sellListContainer.appendChild(fragment);
                    }
                }
            }
            break;
        default:
            console.warn(`Unhandled NUI action: ${data.action}`);
    }
});

// =================================================================---
// XP Level Display Functions
// =================================================================---
/**
 * Updates the XP bar and level display elements in the NUI.
 * @param {number} xp - Current XP of the player.
 * @param {number} level - Current level of the player.
 * @param {number|string} nextLvlXp - XP needed for the next level segment, or a string like "Max" or current XP if max level.
 */
function updateXPDisplayElements(xp, level, nextLvlXp) {
    const levelTextElement = document.getElementById('level-text');
    const xpTextElement = document.getElementById('xp-text');
    const xpBarFillElement = document.getElementById('xp-bar-fill');
    const xpLevelContainer = document.getElementById('xp-level-container');

    if (xpLevelContainer) {
        xpLevelContainer.style.display = 'flex'; // Make sure it's visible
    }

    if (levelTextElement) {
        levelTextElement.textContent = "LVL " + level;
    }
    if (xpTextElement) {
        xpTextElement.textContent = xp + " / " + nextLvlXp + " XP";
    }
    if (xpBarFillElement) {
        let percentage = 0;
        if (typeof nextLvlXp === 'number' && nextLvlXp > 0) {
            percentage = (xp / nextLvlXp) * 100;
        } else if (xp >= nextLvlXp) { // Handles "Max" or if current XP is passed as nextLvlXp for max level
            percentage = 100;
        }
        percentage = Math.max(0, Math.min(100, percentage)); // Clamp between 0 and 100
        xpBarFillElement.style.width = percentage + '%';
    }
}

/**
 * Updates the cash display element in the NUI.
 * @param {number} currentCash - The player's current cash amount.
 */
function updateCashDisplay(currentCash) {
    const cashDisplayElement = document.getElementById('cash-display');
    if (cashDisplayElement) {
        cashDisplayElement.textContent = '$' + (currentCash !== undefined ? currentCash.toLocaleString() : '0'); // Format with commas
        cashDisplayElement.style.display = 'block'; // Make it visible
    } else {
        console.error("Cash display element 'cash-display' not found in HTML.");
    }
}

// =================================================================---
// UI Visibility Functions (Role Selection & Store)
// =================================================================---

/**
 * Shows the role selection UI.
 * Manages NUI focus.
 */
function showRoleSelection() {
    const roleSelectionUI = document.getElementById('role-selection');
    if (roleSelectionUI) {
        roleSelectionUI.style.display = 'block';
        // SetNuiFocus is a FiveM NUI function to control mouse cursor and input focus.
        // (true, true) means NUI is focused, and cursor is visible.
        SetNuiFocus(true, true);
    } else {
        console.error("Role selection UI element not found.");
    }
}

/**
 * Hides the role selection UI.
 * Manages NUI focus.
 */
function hideRoleSelection() {
    const roleSelectionUI = document.getElementById('role-selection');
    if (roleSelectionUI) {
        roleSelectionUI.style.display = 'none';
        // (false, false) means NUI is not focused, and cursor is hidden (game regains control).
        SetNuiFocus(false, false);
    }
}

/**
 * Opens the store menu UI.
 * @param {string} storeName - The name of the store to display.
 * @param {Array} storeItems - Array of item objects to populate the store.
 */
function openStoreMenu(storeName, storeItems) {
    const storeMenuUI = document.getElementById('store-menu');
    const storeTitleEl = document.getElementById('store-title');

    if (storeMenuUI && storeTitleEl) {
        storeTitleEl.textContent = storeName || 'Store'; // Use textContent for safety
        // Store items globally for easy access by rendering functions. Consider a more encapsulated state if complexity grows.
        window.items = storeItems || [];
        window.currentCategory = null; // Reset category selection
        window.currentTab = 'buy'; // Default to 'buy' tab

        loadCategories(); // Populate category filters
        loadItems();      // Load items for the 'buy' tab initially

        storeMenuUI.style.display = 'block';
        SetNuiFocus(true, true);
    } else {
        console.error("Store menu UI or title element not found.");
    }
}

/**
 * Closes the store menu UI.
 * Manages NUI focus.
 */
function closeStoreMenu() {
    const storeMenuUI = document.getElementById('store-menu');
    if (storeMenuUI) {
        storeMenuUI.style.display = 'none';
        SetNuiFocus(false, false);
    }
}

// =================================================================---
// Store: Tab and Category Management
// =================================================================---

// Setup event listeners for tab buttons (Buy/Sell)
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        // Update active visual state for tab buttons
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active')); // Remove active class from all
        btn.classList.add('active'); // Add to clicked one

        window.currentTab = btn.dataset.tab; // Update global state for current tab

        // Show corresponding tab content area
        document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
        const activeTabContent = document.getElementById(`${window.currentTab}-section`);
        if (activeTabContent) {
            activeTabContent.classList.add('active');
        }

        // Load items for the newly active tab
        if (window.currentTab === 'sell') {
            loadSellItems(); // Fetch and display player's inventory for selling
        } else {
            loadItems(); // Display items available for purchase
        }
    });
});

/**
 * Populates the category filter buttons based on available items.
 */
function loadCategories() {
    const categoryList = document.getElementById('category-list');
    if (!categoryList) return;

    // Deduplicate categories from the global item list.
    const categories = [...new Set(window.items.map(item => item.category))];
    categoryList.innerHTML = ''; // Clear existing categories

    categories.forEach(category => {
        const btn = document.createElement('button');
        btn.className = 'category-btn';
        btn.textContent = category; // Use textContent
        btn.onclick = () => {
            window.currentCategory = category; // Update global state for category filter
            // Update active visual state for category buttons
            document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            // Reload items based on the selected category, only if on the 'buy' tab.
            // The 'sell' tab loads all sellable items irrespective of buy categories.
            if (window.currentTab === 'buy') {
                loadItems();
            }
        };
        categoryList.appendChild(btn);
    });
}

/**
 * Loads and displays items for the 'buy' tab, filtered by category.
 */
function loadItems() {
    const itemList = document.getElementById('item-list'); // Assumes this is the container in the 'buy' tab
    if (!itemList) return;

    itemList.innerHTML = ''; // Clear previous items

    // Filter items based on the globally selected category (if any).
    const filteredItems = window.items.filter(item => !window.currentCategory || item.category === window.currentCategory);

    if (filteredItems.length === 0) {
        itemList.innerHTML = '<p style="text-align: center;">No items in this category.</p>';
        return;
    }

    const fragment = document.createDocumentFragment(); // Use DocumentFragment for performance
    filteredItems.forEach(item => {
        fragment.appendChild(createItemElement(item, 'buy'));
    });
    itemList.appendChild(fragment);
}

/**
 * Fetches player inventory and displays items for the 'sell' tab.
 */
function loadSellItems() {
    const sellListContainer = document.getElementById('sell-section'); // This is the tab panel for selling
    if (!sellListContainer) return;

    // It's good practice to have a dedicated sub-container for the list itself to clear/populate
    // For now, assuming sellListContainer itself will hold the items or a direct child.
    // If structure is <div id="sell-section"><div class="item-list-content">...</div></div>, adjust querySelector.
    sellListContainer.innerHTML = '<p style="text-align: center;">Loading inventory...</p>'; // Loading indicator

    fetch(`https://cops-and-robbers/getPlayerInventory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}) // Empty body for GET-like behavior if required by server
    })
    .then(resp => {
        if (!resp.ok) {
            // Attempt to parse error from server, else use HTTP status
            return resp.json().then(err => Promise.reject(err)).catch(() => Promise.reject({ message: `Failed to load inventory (HTTP ${resp.status})` }));
        }
        return resp.json();
    })
    .then(nuiInventory => { // nuiInventory is the object {itemId: {details...}}
        sellListContainer.innerHTML = ''; // Clear loading indicator / previous items

        const sellableItemsArray = Object.values(nuiInventory); // Convert object to array

        if (!sellableItemsArray || sellableItemsArray.length === 0) {
            sellListContainer.innerHTML = '<p style="text-align: center;">Your inventory is empty.</p>';
            return;
        }

        const fragment = document.createDocumentFragment();
        sellableItemsArray.forEach(inventoryItem => { // inventoryItem: {itemId, name, count, sellPrice, ...}
            fragment.appendChild(createItemElement(inventoryItem, 'sell'));
        });
        sellListContainer.appendChild(fragment);
    })
    .catch(error => {
        console.error('Error fetching player inventory:', error.message || error);
        sellListContainer.innerHTML = `<p style="text-align: center; color: red;">Error loading inventory: ${error.message || 'Unknown error'}</p>`;
    });
}

/**
 * Creates and returns an HTML element for an item.
 * @param {object} item - The item object (properties depend on type).
 * @param {string} type - 'buy' or 'sell'.
 * @returns {HTMLElement} The created item div.
 */
function createItemElement(item, type = 'buy') {
    const itemDiv = document.createElement('div');
    itemDiv.className = 'item';
    itemDiv.dataset.itemId = item.itemId; // Store itemId on the element for easy access in event handlers.

    // Item Name
    const nameDiv = document.createElement('div');
    nameDiv.className = 'item-name';
    nameDiv.textContent = item.name;
    itemDiv.appendChild(nameDiv);

    // Item Quantity (for sellable items)
    if (type === 'sell' && item.count !== undefined) {
        const quantityDiv = document.createElement('div');
        quantityDiv.className = 'item-quantity';
        quantityDiv.textContent = `x${item.count}`; // e.g., "x10"
        itemDiv.appendChild(quantityDiv);
    }

    // Item Price
    const priceDiv = document.createElement('div');
    priceDiv.className = 'item-price';
    // Use item.price for buying, item.sellPrice for selling
    priceDiv.textContent = `$${(type === 'buy' ? item.price : item.sellPrice)}`;
    itemDiv.appendChild(priceDiv);

    // Quantity Input
    const quantityInput = document.createElement('input');
    quantityInput.type = 'number';
    quantityInput.className = 'quantity-input';
    quantityInput.min = '1';
    // Max for buying is arbitrary (e.g., 100), for selling it's the item count.
    quantityInput.max = (type === 'buy') ? '100' : (item.count ? item.count.toString() : '1');
    quantityInput.value = '1';
    itemDiv.appendChild(quantityInput);

    // Action Button (Buy or Sell)
    const actionBtn = document.createElement('button');
    actionBtn.className = (type === 'buy') ? 'buy-btn' : 'sell-btn';
    actionBtn.textContent = (type === 'buy') ? 'Buy' : 'Sell';
    actionBtn.dataset.action = type; // Store action type for the event delegate.
    itemDiv.appendChild(actionBtn);

    return itemDiv;
}

// =================================================================---
// Store: Item Interaction (Buy/Sell)
// =================================================================---

/**
 * Handles the fetch request for buying or selling an item.
 * @param {string} itemId - The ID of the item.
 * @param {number} quantity - The quantity to buy/sell.
 * @param {string} actionType - 'buy' or 'sell'.
 */
async function handleItemAction(itemId, quantity, actionType) {
    const endpoint = actionType === 'buy' ? 'buyItem' : 'sellItem';
    try {
        const resp = await fetch(`https://cops-and-robbers/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ itemId: itemId, quantity: quantity })
        });

        const response = await resp.json(); // Try to parse JSON regardless of resp.ok for server error messages

        if (!resp.ok) {
            // Use server's error message if available, otherwise default
            throw new Error(response.message || `HTTP error ${resp.status}`);
        }

        if (response.status === 'success') {
            // Use a less intrusive notification system if available
            // For now, using alert for simplicity as in original code
            alert(`Successfully ${actionType === 'buy' ? 'purchased' : 'sold'} ${quantity} x ${response.itemName || itemId}`);
            if (actionType === 'buy') {
                // Potentially refresh buy list or update player balance display
                // loadItems(); // Refreshing might be too broad, consider more targeted updates
            } else {
                loadSellItems(); // Refresh sell list as inventory changes
            }
        } else {
            alert(`${actionType === 'buy' ? 'Purchase' : 'Sell'} failed: ${response.message || 'Unknown error'}`);
        }
    } catch (error) {
        console.error(`Error ${actionType}ing item:`, error.message || error);
        alert(`Failed to ${actionType} item: ${error.message || 'Check console for details.'}`);
    }
}


// Event delegation for item lists
document.addEventListener('click', function(event) {
    const target = event.target;
    const itemDiv = target.closest('.item');

    if (!itemDiv) return; // Click was not inside an .item element

    const itemId = itemDiv.dataset.itemId;
    const actionType = target.dataset.action; // 'buy' or 'sell'

    if (itemId && (actionType === 'buy' || actionType === 'sell')) {
        const quantityInput = itemDiv.querySelector('.quantity-input');
        if (!quantityInput) {
            console.error('Quantity input not found for item:', itemId);
            return;
        }
        const quantity = parseInt(quantityInput.value);
        const maxQuantity = parseInt(quantityInput.max);

        if (isNaN(quantity) || quantity < 1 || quantity > maxQuantity) {
            alert(`Invalid quantity. Must be between 1 and ${maxQuantity}.`);
            return;
        }
        handleItemAction(itemId, quantity, actionType);
    }
});


// -------------------------------------------------------------------
// Role Selection and Initialization
// -------------------------------------------------------------------

function selectRole(selectedRole) {
    fetch(`https://cops-and-robbers/selectRole`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: selectedRole })
    })
    .then(resp => resp.json())
    .then(response => {
        if (response.status === 'success') {
            alert(`Role set to ${response.role}`);
            hideRoleSelection();
            // SpawnPlayer(response.role); -- Removed by subtask, client.lua handles this
            // role = response.role; -- Removed by subtask, client.lua handles this
            // Notify about role-specific abilities
            if (response.role == 'cop') {
                ShowNotification("Cop abilities loaded: Advanced equipment, vehicles, and backup available.");
            } else if (role == 'robber') {
                ShowNotification("Robber abilities loaded: Heist tools, getaway vehicles, and stealth strategies enabled.");
            }
        } else {
            alert(`Role selection failed: ${response.message}`);
        }
    })
    .catch(error => {
        console.error('Error selecting role:', error);
        alert('Failed to select role.');
    });
}

// Bind event listeners to role selection buttons on DOMContentLoaded
// This targets buttons within the #role-selection section in main_ui.html
// and also the buttons in the standalone role_selection.html if it's used.
document.addEventListener('DOMContentLoaded', () => {
    // Delegate to a common ancestor if #role-selection is dynamically added,
    // but direct binding is fine if it's always present in the loaded HTML.
    const roleSelectionContainer = document.getElementById('role-selection');
    if (roleSelectionContainer) {
        roleSelectionContainer.addEventListener('click', function(event) {
            const button = event.target.closest('button[data-role]');
            if (button) {
                const selectedRole = button.getAttribute('data-role');
                selectRole(selectedRole);
            }
        });
    } else {
        // Fallback for html/index.html structure if it's still in use and different
        const legacyRoleButtons = document.querySelectorAll('.menu button[data-role]');
        legacyRoleButtons.forEach(button => {
            button.addEventListener('click', () => {
                const selectedRole = button.getAttribute('data-role');
                selectRole(selectedRole);
            });
        });
    }

    // Initialize the store item list (buy tab) if store-menu is present
    // This ensures items are loaded if the store is the default view or shown initially.
    // However, openStoreMenu is typically called by an NUI event.
    // If #item-list exists and is part of the buy section visible by default:
    // if (document.getElementById('store-menu') && document.getElementById('item-list') && window.currentTab === 'buy') {
    //     loadItems(); // This might require window.items to be populated by an earlier NUI message.
    // }

    // Initial state for XP bar - assuming it might be hidden by default via CSS or needs an initial call
    // updateXPDisplayElements(0, 1, Config.XPTable[2] || 100); // Example initial call, needs Config access or default
    // Better to have client.lua send initial state upon player load.

    // Admin Panel event listeners (MOVED HERE)
    const adminPlayerListBody = document.getElementById('admin-player-list-body');
    if (adminPlayerListBody) {
        adminPlayerListBody.addEventListener('click', function(event) {
            const target = event.target;
            if (target.classList.contains('admin-action-btn')) {
                const targetId = target.dataset.targetId;
                if (!targetId) return;

                if (target.classList.contains('admin-kick-btn')) {
                    if (confirm(`Kick player ID ${targetId}?`)) {
                        fetch(`https://cops-and-robbers/adminKickPlayer`, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ targetId: targetId })
                        }).then(resp => resp.json()).then(res => {
                            alert(res.message || (res.status === 'ok' ? 'Kicked.' : 'Failed.'));
                        });
                    }
                } else if (target.classList.contains('admin-ban-btn')) {
                    currentAdminTargetPlayerId = targetId; // currentAdminTargetPlayerId needs to be accessible
                    const banReasonContainer = document.getElementById('admin-ban-reason-container');
                    if (banReasonContainer) banReasonContainer.classList.remove('hidden');
                    const banReasonInput = document.getElementById('admin-ban-reason');
                    if (banReasonInput) banReasonInput.focus();
                } else if (target.classList.contains('admin-teleport-btn')) {
                    if (confirm(`Teleport to player ID ${targetId}?`)) {
                         fetch(`https://cops-and-robbers/teleportToPlayerAdminUI`, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ targetId: targetId })
                        }).then(resp => resp.json()).then(res => {
                            alert(res.message || (res.status === 'ok' ? 'Teleporting.' : 'Failed.'));
                            hideAdminPanel(); // hideAdminPanel function needs to be accessible
                        });
                    }
                }
            }
        });
    }

    const adminConfirmBanBtn = document.getElementById('admin-confirm-ban-btn');
    if (adminConfirmBanBtn) {
        adminConfirmBanBtn.addEventListener('click', function() {
            if (currentAdminTargetPlayerId) { // currentAdminTargetPlayerId needs to be accessible
                const reasonInput = document.getElementById('admin-ban-reason');
                const reason = reasonInput ? reasonInput.value.trim() : "Banned by Admin via UI.";
                fetch(`https://cops-and-robbers/adminBanPlayer`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ targetId: currentAdminTargetPlayerId, reason: reason })
                }).then(resp => resp.json()).then(res => {
                    alert(res.message || (res.status === 'ok' ? 'Banned.' : 'Failed.'));
                    hideAdminPanel(); // hideAdminPanel function needs to be accessible
                });
            }
        });
    }

    const adminCancelBanBtn = document.getElementById('admin-cancel-ban-btn');
    if (adminCancelBanBtn) {
        adminCancelBanBtn.addEventListener('click', function() {
            const banReasonContainer = document.getElementById('admin-ban-reason-container');
            if (banReasonContainer) banReasonContainer.classList.add('hidden');
            const banReasonInput = document.getElementById('admin-ban-reason');
            if (banReasonInput) banReasonInput.value = '';
            currentAdminTargetPlayerId = null; // currentAdminTargetPlayerId needs to be accessible
        });
    }

    const adminCloseBtn = document.getElementById('admin-close-btn');
    if (adminCloseBtn) {
        adminCloseBtn.addEventListener('click', hideAdminPanel); // hideAdminPanel needs to be accessible
    }

    // Tab button event listeners moved inside DOMContentLoaded
    const tabButtons = document.querySelectorAll('.tab-btn');
    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            window.currentTab = btn.dataset.tab;
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            const activeTabContent = document.getElementById(`${window.currentTab}-section`);
            if (activeTabContent) {
                activeTabContent.classList.add('active');
            }
            if (window.currentTab === 'sell') {
                loadSellItems(); // loadSellItems needs to be accessible
            } else {
                loadItems(); // loadItems needs to be accessible
            }
        });
    });
});

// -------------------------------------------------------------------
// Heist Timer Functionality
// -------------------------------------------------------------------

// Global variable for heist timer interval to clear it if a new timer starts
let heistTimerInterval = null;

function startHeistTimer(duration, bankName) {
    const heistTimerEl = document.getElementById('heist-timer'); // Assumes this element exists in the active HTML
    if (!heistTimerEl) {
        console.warn('#heist-timer element not found. Cannot display timer.');
        return;
    }
    heistTimerEl.style.display = 'block';

    const timerTextEl = document.getElementById('timer-text'); // Assumes this element exists
    if (!timerTextEl) {
        console.warn('#timer-text element not found. Cannot display timer text.');
        heistTimerEl.style.display = 'none'; // Hide timer if text element is missing
        return;
    }

    let remainingTime = duration;
    timerTextEl.textContent = `Heist at ${bankName}: ${formatTime(remainingTime)}`; // Use textContent

    if (heistTimerInterval) {
        clearInterval(heistTimerInterval); // Clear any existing timer
    }

    heistTimerInterval = setInterval(function() {
        remainingTime--;
        if (remainingTime <= 0) {
            clearInterval(heistTimerInterval);
            heistTimerInterval = null; // Reset interval variable
            heistTimerEl.style.display = 'none';
            // Optionally, send a message back to Lua that timer ended
            // fetch(`https://cops-and-robbers/heistTimerEnded`, { method: 'POST' });
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

// =================================================================---
// Admin Panel Functions
// =================================================================---
let currentAdminTargetPlayerId = null; // Store target player ID for ban confirmation

function showAdminPanel(playerList) {
    const adminPanel = document.getElementById('admin-panel');
    const playerListBody = document.getElementById('admin-player-list-body');

    if (!adminPanel || !playerListBody) {
        console.error("Admin panel elements not found.");
        return;
    }

    playerListBody.innerHTML = ''; // Clear existing list

    if (playerList && playerList.length > 0) {
        playerList.forEach(player => {
            const row = playerListBody.insertRow();
            row.insertCell().textContent = player.name;
            row.insertCell().textContent = player.serverId;
            row.insertCell().textContent = player.role;
            row.insertCell().textContent = '$' + (player.cash || 0);

            const actionsCell = row.insertCell();

            const kickBtn = document.createElement('button');
            kickBtn.textContent = 'Kick';
            kickBtn.className = 'admin-action-btn admin-kick-btn';
            kickBtn.dataset.targetId = player.serverId;
            actionsCell.appendChild(kickBtn);

            const banBtn = document.createElement('button');
            banBtn.textContent = 'Ban';
            banBtn.className = 'admin-action-btn admin-ban-btn';
            banBtn.dataset.targetId = player.serverId;
            actionsCell.appendChild(banBtn);

            const teleportBtn = document.createElement('button');
            teleportBtn.textContent = 'TP to';
            teleportBtn.className = 'admin-action-btn admin-teleport-btn';
            teleportBtn.dataset.targetId = player.serverId;
            actionsCell.appendChild(teleportBtn);
        });
    } else {
        playerListBody.innerHTML = '<tr><td colspan="5" style="text-align:center;">No players online or data unavailable.</td></tr>';
    }

    adminPanel.classList.remove('hidden');
    SetNuiFocus(true, true);
}

function hideAdminPanel() {
    const adminPanel = document.getElementById('admin-panel');
    if (adminPanel) {
        adminPanel.classList.add('hidden');
    }
    const banReasonContainer = document.getElementById('admin-ban-reason-container');
    if (banReasonContainer) {
        banReasonContainer.classList.add('hidden');
    }
    document.getElementById('admin-ban-reason').value = ''; // Clear reason input
    currentAdminTargetPlayerId = null;
    SetNuiFocus(false, false);
}

// Update message listener for admin panel
window.addEventListener('message', function(event) {
    // Origin validation is already at the top
    if (!allowedOrigins.includes(event.origin)) return;

    const data = event.data;

    switch (data.action) {
        // ... existing cases ...
        case 'showAdminPanel': // New action from client.lua
            showAdminPanel(data.players);
            break;
        // case 'updateXPBar': // This is duplicated, remove one instance
        //    updateXPDisplayElements(data.currentXP, data.currentLevel, data.xpForNextLevel);
        //    break;
    }
});

/**
 * Updates the XP bar and level display elements in the NUI.
 * @param {number} xp - Current XP of the player.
 * @param {number} level - Current level of the player.
 * @param {number|string} nextLvlXp - XP needed for the next level segment, or a string like "Max" or current XP if max level.
 */
function updateXPDisplayElements(xp, level, nextLvlXp) {
    const levelTextEl = document.getElementById('level-text');
    const xpTextEl = document.getElementById('xp-text');
    const xpBarFillEl = document.getElementById('xp-bar-fill');
    const xpLevelContainerEl = document.getElementById('xp-level-container');

    if (levelTextEl && xpTextEl && xpBarFillEl && xpLevelContainerEl) {
        levelTextEl.textContent = "LVL " + level;
        xpTextEl.textContent = xp + " / " + nextLvlXp + " XP";

        let xpPercentage = 0;
        // If nextLvlXp is "Max" (or similar string) or if current XP is already the "next level" value (at max level)
        if (typeof nextLvlXp !== 'number' || xp >= nextLvlXp) {
            if (level >= (window.ConfigMaxLevel || 10) ) { // Assuming ConfigMaxLevel might be exposed or use a default
                 percentage = 100; // At max level, bar is full
            } else if (typeof nextLvlXp === 'number' && nextLvlXp > 0) { // If nextLvlXp is a number (e.g. current XP when maxed)
                 percentage = (xp / nextLvlXp) * 100;
            } else { // Fallback if nextLvlXp is not a number and not max level (e.g. "Error" string)
                percentage = 0;
            }
        } else if (nextLvlXp > 0) {
            percentage = (xp / nextLvlXp) * 100;
        }

        xpBarFillEl.style.width = Math.max(0, Math.min(100, percentage)) + '%'; // Clamp between 0-100
        xpLevelContainerEl.style.display = 'flex'; // Make it visible
    } else {
        console.error("One or more XP display elements not found in HTML.");
    }
}
