// html/scripts.js

// Allowed origins: include your resource's NUI origin and any other trusted domains
const allowedOrigins = [
  "nui://cops-and-robbers", // Your resource's NUI origin
  "http://localhost:3000"   // For local development (if needed)
];

// Secure postMessage listener with origin validation
window.addEventListener('message', function(event) {
    // Validate the origin of the incoming message
    if (!allowedOrigins.includes(event.origin)) {
        console.warn(`Received message from untrusted origin: ${event.origin}`);
        return;
    }
  
    const data = event.data;
  
    switch (data.action) {
        case 'showRoleSelection':
            showRoleSelection();
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
        default:
            console.warn(`Unhandled NUI action: ${data.action}`);
    }
});

// -------------------------------------------------------------------
// Role Selection Functions
// -------------------------------------------------------------------

function showRoleSelection() {
    document.getElementById('role-selection').style.display = 'block';
    SetNuiFocus(true, true); // Set focus to the NUI
}

function hideRoleSelection() {
    document.getElementById('role-selection').style.display = 'none';
    SetNuiFocus(false, false); // Release NUI focus
}

// -------------------------------------------------------------------
// Store Functions
// -------------------------------------------------------------------

function openStoreMenu(storeName, storeItems) {
    document.getElementById('store-title').innerText = storeName || 'Store';
    window.items = storeItems || [];
    window.currentCategory = null;
    window.currentTab = 'buy';

    loadCategories();
    loadItems();

    document.getElementById('store-menu').style.display = 'block';
    SetNuiFocus(true, true); // Focus on NUI
}

function closeStoreMenu() {
    document.getElementById('store-menu').style.display = 'none';
    SetNuiFocus(false, false); // Release NUI focus
}

// -------------------------------------------------------------------
// Tab and Category Management
// -------------------------------------------------------------------

document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        // Update active tab button
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // Update current tab
        window.currentTab = btn.dataset.tab;

        // Show active tab content
        document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
        document.getElementById(`${window.currentTab}-section`).classList.add('active');

        // Load appropriate items based on the current tab
        if (window.currentTab === 'sell') {
            loadSellItems();
        } else {
            loadItems();
        }
    });
});

function loadCategories() {
    const categories = [...new Set(window.items.map(item => item.category))];
    const categoryList = document.getElementById('category-list');
    categoryList.innerHTML = '';

    // Create category buttons
    categories.forEach(category => {
        const btn = document.createElement('button');
        btn.className = 'category-btn';
        btn.innerText = category;
        btn.onclick = () => {
            window.currentCategory = category;
            // Highlight active category button
            document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            // Reload items based on selected category
            if (window.currentTab === 'buy') {
                loadItems();
            }
        };
        categoryList.appendChild(btn);
    });
}

function loadItems() {
    const itemList = document.getElementById('item-list');
    itemList.innerHTML = '';

    // Filter items based on the selected category (if any)
    const filteredItems = window.items.filter(item => !window.currentCategory || item.category === window.currentCategory);

    filteredItems.forEach(item => {
        const itemDiv = document.createElement('div');
        itemDiv.className = 'item';

        // Display item name
        const nameDiv = document.createElement('div');
        nameDiv.className = 'item-name';
        nameDiv.innerText = item.name;
        itemDiv.appendChild(nameDiv);

        // Display item price
        const priceDiv = document.createElement('div');
        priceDiv.className = 'item-price';
        priceDiv.innerText = '$' + item.price;
        itemDiv.appendChild(priceDiv);

        // Create quantity input
        const quantityInput = document.createElement('input');
        quantityInput.type = 'number';
        quantityInput.className = 'quantity-input';
        quantityInput.min = '1';
        quantityInput.max = '100';
        quantityInput.value = '1';
        itemDiv.appendChild(quantityInput);

        // Create Buy button
        const buyBtn = document.createElement('button');
        buyBtn.className = 'buy-btn';
        buyBtn.innerText = 'Buy';
        buyBtn.onclick = () => {
            const quantity = parseInt(quantityInput.value);
            if (isNaN(quantity) || quantity < 1 || quantity > 100) {
                alert('Invalid quantity.');
                return;
            }
            buyItem(item.itemId, quantity);
        };
        itemDiv.appendChild(buyBtn);

        itemList.appendChild(itemDiv);
    });
}

function loadSellItems() {
    fetch(`https://${GetParentResourceName()}/getPlayerInventory`, {
        method: 'POST'
    })
    .then(resp => resp.json())
    .then(data => {
        const sellSection = document.getElementById('sell-section');
        sellSection.innerHTML = '';

        data.items.forEach(item => {
            const itemDiv = document.createElement('div');
            itemDiv.className = 'item';

            // Display item name
            const nameDiv = document.createElement('div');
            nameDiv.className = 'item-name';
            nameDiv.innerText = item.name;
            itemDiv.appendChild(nameDiv);

            // Display item quantity
            const quantityDiv = document.createElement('div');
            quantityDiv.className = 'item-quantity';
            quantityDiv.innerText = 'x' + item.count;
            itemDiv.appendChild(quantityDiv);

            // Display sell price
            const priceDiv = document.createElement('div');
            priceDiv.className = 'item-price';
            priceDiv.innerText = '$' + item.sellPrice;
            itemDiv.appendChild(priceDiv);

            // Create quantity input for selling
            const quantityInput = document.createElement('input');
            quantityInput.type = 'number';
            quantityInput.className = 'quantity-input';
            quantityInput.min = '1';
            quantityInput.max = item.count;
            quantityInput.value = '1';
            itemDiv.appendChild(quantityInput);

            // Create Sell button
            const sellBtn = document.createElement('button');
            sellBtn.className = 'sell-btn';
            sellBtn.innerText = 'Sell';
            sellBtn.onclick = () => {
                const quantity = parseInt(quantityInput.value);
                if (isNaN(quantity) || quantity < 1 || quantity > item.count) {
                    alert('Invalid quantity.');
                    return;
                }
                sellItem(item.itemId, quantity);
            };
            itemDiv.appendChild(sellBtn);

            sellSection.appendChild(itemDiv);
        });
    })
    .catch(error => {
        console.error('Error fetching inventory:', error);
        alert('Failed to load inventory.');
    });
}

// -------------------------------------------------------------------
// Buy and Sell Functions
// -------------------------------------------------------------------

function buyItem(itemId, quantity) {
    fetch(`https://${GetParentResourceName()}/buyItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemId: itemId, quantity: quantity })
    })
    .then(resp => resp.json())
    .then(response => {
        if (response.status === 'success') {
            alert(`Successfully purchased ${quantity} x ${response.itemName}`);
            loadItems(); // Refresh the item list if needed
        } else {
            alert(`Purchase failed: ${response.message}`);
        }
    })
    .catch(error => {
        console.error('Error buying item:', error);
        alert('Failed to buy item.');
    });
}

function sellItem(itemId, quantity) {
    fetch(`https://${GetParentResourceName()}/sellItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemId: itemId, quantity: quantity })
    })
    .then(resp => resp.json())
    .then(response => {
        if (response.status === 'success') {
            alert(`Successfully sold ${quantity} x ${response.itemName}`);
            loadSellItems(); // Refresh sell items
        } else {
            alert(`Sell failed: ${response.message}`);
        }
    })
    .catch(error => {
        console.error('Error selling item:', error);
        alert('Failed to sell item.');
    });
}

// -------------------------------------------------------------------
// Role Selection and Initialization
// -------------------------------------------------------------------

function selectRole(selectedRole) {
    fetch(`https://${GetParentResourceName()}/selectRole`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: selectedRole })
    })
    .then(resp => resp.json())
    .then(response => {
        if (response.status === 'success') {
            alert(`Role set to ${response.role}`);
            hideRoleSelection();
            SpawnPlayer(response.role);
            role = response.role;
            // Notify about role-specific abilities
            if (role == 'cop') {
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
document.addEventListener('DOMContentLoaded', () => {
    const roleButtons = document.querySelectorAll('#role-selection button');
    roleButtons.forEach(button => {
        button.addEventListener('click', () => {
            const selectedRole = button.getAttribute('data-role');
            selectRole(selectedRole);
        });
    });
});

// -------------------------------------------------------------------
// Heist Timer Functionality
// -------------------------------------------------------------------

function startHeistTimer(duration, bankName) {
    const heistTimerEl = document.getElementById('heist-timer');
    heistTimerEl.style.display = 'block';
    const timerText = document.getElementById('timer-text');
    let remainingTime = duration;
    timerText.innerText = `Heist at ${bankName}: ${formatTime(remainingTime)}`;
    clearInterval(heistTimerInterval);
    heistTimerInterval = setInterval(function() {
        remainingTime--;
        if (remainingTime <= 0) {
            clearInterval(heistTimerInterval);
            heistTimerEl.style.display = 'none';
            return;
        }
        timerText.innerText = `Heist at ${bankName}: ${formatTime(remainingTime)}`;
    }, 1000);
}

function formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
}
