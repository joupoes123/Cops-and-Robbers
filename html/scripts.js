// html/scripts.js
// Handles NUI interactions for Cops and Robbers game mode.

// At the top of html/scripts.js
const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'cops-and-robbers';

// =================================================================---
// NUI Message Handling & Security
// =================================================================---

// Allowed origins: include your resource's NUI origin and any other trusted domains.
const allowedOrigins = [
    `nui://${resourceName}`, // Use the global resourceName
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
        // Admin Panel show action (moved from bottom to keep switch statement cleaner)
        case 'showAdminPanel':
            showAdminPanel(data.players); // data.players should be sent by client.lua
            break;
        default:
            console.warn(`Unhandled NUI action: ${data.action}`);
    }
});

// =================================================================---
// NUI Focus Helper Function
// =================================================================---
async function fetchSetNuiFocus(hasFocus, hasCursor) {
    try {
        await fetch(`https://$\{resourceName}/cnr:setNuiFocus`, { // Corrected event name
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ hasFocus: hasFocus, hasCursor: hasCursor })
        });
    } catch (error) {
        console.error('Error calling cnr:setNuiFocus:', error);
    }
}

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
        if (typeof nextLvlXp === 'number' && nextLvlXp > 0 && xp < nextLvlXp) { // Check xp < nextLvlXp for normal progression
            percentage = (xp / nextLvlXp) * 100;
        } else if (typeof nextLvlXp !== 'number' || xp >= nextLvlXp) { // Handles "Max" or if current XP is passed as nextLvlXp for max level
            percentage = 100; // At max level or if current XP meets/exceeds requirement (e.g. "Max" or already at cap for display)
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
        fetchSetNuiFocus(true, true); // MODIFIED
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
        fetchSetNuiFocus(false, false); // MODIFIED
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
        fetchSetNuiFocus(true, true); // MODIFIED
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
        fetchSetNuiFocus(false, false); // MODIFIED
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

    sellListContainer.innerHTML = '<p style="text-align: center;">Loading inventory...</p>'; // Loading indicator

    fetch(`https://$\{resourceName}/getPlayerInventory`, { // Use resourceName
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    })
    .then(resp => {
        if (!resp.ok) {
            return resp.json().then(err => Promise.reject(err)).catch(() => Promise.reject({ message: `Failed to load inventory (HTTP ${resp.status})` }));
        }
        return resp.json();
    })
    .then(nuiInventory => {
        sellListContainer.innerHTML = '';

        const sellableItemsArray = Object.values(nuiInventory);

        if (!sellableItemsArray || sellableItemsArray.length === 0) {
            sellListContainer.innerHTML = '<p style="text-align: center;">Your inventory is empty.</p>';
            return;
        }

        const fragment = document.createDocumentFragment();
        sellableItemsArray.forEach(inventoryItem => {
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
    itemDiv.dataset.itemId = item.itemId;

    const nameDiv = document.createElement('div');
    nameDiv.className = 'item-name';
    nameDiv.textContent = item.name;
    itemDiv.appendChild(nameDiv);

    if (type === 'sell' && item.count !== undefined) {
        const quantityDiv = document.createElement('div');
        quantityDiv.className = 'item-quantity';
        quantityDiv.textContent = `x${item.count}`;
        itemDiv.appendChild(quantityDiv);
    }

    const priceDiv = document.createElement('div');
    priceDiv.className = 'item-price';
    priceDiv.textContent = `$${(type === 'buy' ? item.price : item.sellPrice)}`;
    itemDiv.appendChild(priceDiv);

    const quantityInput = document.createElement('input');
    quantityInput.type = 'number';
    quantityInput.className = 'quantity-input';
    quantityInput.min = '1';
    quantityInput.max = (type === 'buy') ? '100' : (item.count ? item.count.toString() : '1');
    quantityInput.value = '1';
    itemDiv.appendChild(quantityInput);

    const actionBtn = document.createElement('button');
    actionBtn.className = (type === 'buy') ? 'buy-btn' : 'sell-btn';
    actionBtn.textContent = (type === 'buy') ? 'Buy' : 'Sell';
    actionBtn.dataset.action = type;
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
        const resp = await fetch(`https://$\{resourceName}/${endpoint}`, { // Use resourceName
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ itemId: itemId, quantity: quantity })
        });

        const response = await resp.json();

        if (!resp.ok) {
            throw new Error(response.message || `HTTP error ${resp.status}`);
        }

        if (response.status === 'success') {
            alert(`Successfully ${actionType === 'buy' ? 'purchased' : 'sold'} ${quantity} x ${response.itemName || itemId}`);
            if (actionType === 'buy') {
                // Player cash should be updated by server via 'updateMoney' NUI event.
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

    if (!itemDiv) return;

    const itemId = itemDiv.dataset.itemId;
    const actionType = target.dataset.action;

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
    fetch(`https://$\{resourceName}/selectRole`, { // Use resourceName
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: selectedRole })
    })
    .then(resp => resp.json())
    .then(response => {
        if (response.status === 'success') {
            alert(`Role set to ${response.role}`);
            hideRoleSelection();
            // Client.lua now handles actual role setting and spawning.
        } else {
            alert(`Role selection failed: ${response.message}`);
        }
    })
    .catch(error => {
        console.error('Error selecting role:', error);
        alert('Failed to select role.');
    });
}

document.addEventListener('DOMContentLoaded', () => {
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
        const legacyRoleButtons = document.querySelectorAll('.menu button[data-role]');
        legacyRoleButtons.forEach(button => {
            button.addEventListener('click', () => {
                const selectedRole = button.getAttribute('data-role');
                selectRole(selectedRole);
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

                if (target.classList.contains('admin-kick-btn')) {
                    if (confirm(`Kick player ID ${targetId}?`)) {
                        fetch(`https://$\{resourceName}/adminKickPlayer`, { // Use resourceName
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ targetId: targetId })
                        }).then(resp => resp.json()).then(res => {
                            alert(res.message || (res.status === 'ok' ? 'Kicked.' : 'Failed.'));
                        });
                    }
                } else if (target.classList.contains('admin-ban-btn')) {
                    currentAdminTargetPlayerId = targetId;
                    const banReasonContainer = document.getElementById('admin-ban-reason-container');
                    if (banReasonContainer) banReasonContainer.classList.remove('hidden');
                    const banReasonInput = document.getElementById('admin-ban-reason');
                    if (banReasonInput) banReasonInput.focus();
                } else if (target.classList.contains('admin-teleport-btn')) {
                    if (confirm(`Teleport to player ID ${targetId}?`)) {
                         fetch(`https://$\{resourceName}/teleportToPlayerAdminUI`, { // Use resourceName
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ targetId: targetId })
                        }).then(resp => resp.json()).then(res => {
                            alert(res.message || (res.status === 'ok' ? 'Teleporting.' : 'Failed.'));
                            hideAdminPanel();
                        });
                    }
                }
            }
        });
    }

    const adminConfirmBanBtn = document.getElementById('admin-confirm-ban-btn');
    if (adminConfirmBanBtn) {
        adminConfirmBanBtn.addEventListener('click', function() {
            if (currentAdminTargetPlayerId) {
                const reasonInput = document.getElementById('admin-ban-reason');
                const reason = reasonInput ? reasonInput.value.trim() : "Banned by Admin via UI.";
                fetch(`https://$\{resourceName}/adminBanPlayer`, { // Use resourceName
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ targetId: currentAdminTargetPlayerId, reason: reason })
                }).then(resp => resp.json()).then(res => {
                    alert(res.message || (res.status === 'ok' ? 'Banned.' : 'Failed.'));
                    hideAdminPanel();
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
            currentAdminTargetPlayerId = null;
        });
    }

    const adminCloseBtn = document.getElementById('admin-close-btn');
    if (adminCloseBtn) {
        adminCloseBtn.addEventListener('click', hideAdminPanel);
    }

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
                loadSellItems();
            } else {
                loadItems();
            }
        });
    });
});

// -------------------------------------------------------------------
// Heist Timer Functionality
// -------------------------------------------------------------------

let heistTimerInterval = null;

function startHeistTimer(duration, bankName) {
    const heistTimerEl = document.getElementById('heist-timer');
    if (!heistTimerEl) {
        console.warn('#heist-timer element not found. Cannot display timer.');
        return;
    }
    heistTimerEl.style.display = 'block';

    const timerTextEl = document.getElementById('timer-text');
    if (!timerTextEl) {
        console.warn('#timer-text element not found. Cannot display timer text.');
        heistTimerEl.style.display = 'none';
        return;
    }

    let remainingTime = duration;
    timerTextEl.textContent = `Heist at ${bankName}: ${formatTime(remainingTime)}`;

    if (heistTimerInterval) {
        clearInterval(heistTimerInterval);
    }

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

// =================================================================---
// Admin Panel Functions
// =================================================================---
let currentAdminTargetPlayerId = null;

function showAdminPanel(playerList) {
    const adminPanel = document.getElementById('admin-panel');
    const playerListBody = document.getElementById('admin-player-list-body');

    if (!adminPanel || !playerListBody) {
        console.error("Admin panel elements not found.");
        return;
    }

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
    fetchSetNuiFocus(true, true); // MODIFIED
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
    const banReasonInput = document.getElementById('admin-ban-reason'); // Ensure this ID exists or is correct
    if (banReasonInput) banReasonInput.value = ''; // Clear reason input
    currentAdminTargetPlayerId = null;
    fetchSetNuiFocus(false, false); // MODIFIED
}

// Removed duplicated updateXPDisplayElements and message listener for admin panel as it's handled by the main one.
// Also ensured all fetch calls use https://${resourceName}/...
// Corrected xp bar logic slightly.
// Moved admin panel's 'showAdminPanel' case to the main message listener.
