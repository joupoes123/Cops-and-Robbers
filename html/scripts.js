// html/scripts.js

// Global Variables
let heistTimerInterval;
let items = [];
let currentCategory = null;
let currentTab = 'buy';

// Initialize NUI
window.addEventListener('message', function(event) {
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

// Function to display the role selection menu
function showRoleSelection() {
    document.getElementById('role-selection').style.display = 'block';
    SetNuiFocus(true, true); // Focus on NUI
}

// Function to hide the role selection menu
function hideRoleSelection() {
    document.getElementById('role-selection').style.display = 'none';
    SetNuiFocus(false, false); // Release NUI focus
}

// Function to open the store menu
function openStoreMenu(storeName, storeItems) {
    document.getElementById('store-title').innerText = storeName || 'Store';
    items = storeItems || [];
    currentCategory = null;
    currentTab = 'buy';

    loadCategories();
    loadItems();

    document.getElementById('store-menu').style.display = 'block';
    SetNuiFocus(true, true); // Focus on NUI
}

// Function to close the store menu
function closeStoreMenu() {
    document.getElementById('store-menu').style.display = 'none';
    SetNuiFocus(false, false); // Release NUI focus
}

// Event Listeners for Tab Buttons (Buy/Sell)
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        // Update active tab button
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // Update current tab
        currentTab = btn.dataset.tab;

        // Show active tab content
        document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
        document.getElementById(`${currentTab}-section`).classList.add('active');

        // Load appropriate items
        if (currentTab === 'sell') {
            loadSellItems();
        } else {
            loadItems();
        }
    });
});

// Function to load item categories for the store
function loadCategories() {
    const categories = [...new Set(items.map(item => item.category))];
    const categoryList = document.getElementById('category-list');
    categoryList.innerHTML = '';

    // Create category buttons
    categories.forEach(category => {
        const btn = document.createElement('button');
        btn.className = 'category-btn';
        btn.innerText = category;
        btn.onclick = () => {
            currentCategory = category;
            // Highlight active category button
            document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            // Load items based on selected category
            if (currentTab === 'buy') {
                loadItems();
            }
        };
        categoryList.appendChild(btn);
    });
}

// Function to load items for the "Buy" tab
function loadItems() {
    const itemList = document.getElementById('item-list');
    itemList.innerHTML = '';

    // Filter items based on selected category
    const filteredItems = items.filter(item => !currentCategory || item.category === currentCategory);

    // Populate item list
    filteredItems.forEach(item => {
        const itemDiv = document.createElement('div');
        itemDiv.className = 'item';

        // Item Name
        const nameDiv = document.createElement('div');
        nameDiv.className = 'item-name';
        nameDiv.innerText = item.name;
        itemDiv.appendChild(nameDiv);

        // Item Price
        const priceDiv = document.createElement('div');
        priceDiv.className = 'item-price';
        priceDiv.innerText = '$' + item.price;
        itemDiv.appendChild(priceDiv);

        // Quantity Input
        const quantityInput = document.createElement('input');
        quantityInput.type = 'number';
        quantityInput.className = 'quantity-input';
        quantityInput.min = '1';
        quantityInput.max = '100';
        quantityInput.value = '1';
        itemDiv.appendChild(quantityInput);

        // Buy Button
        const buyBtn = document.createElement('button');
        buyBtn.className = 'buy-btn';
        buyBtn.innerText = 'Buy';
        buyBtn.onclick = () => {
            const quantity = parseInt(quantityInput.value);
            if (isNaN(quantity) || quantity < 1 || quantity > 100) {
                alert('Invalid quantity.');
                return;
            }
            // Send NUI callback to buy item
            buyItem(item.itemId, quantity);
        };
        itemDiv.appendChild(buyBtn);

        itemList.appendChild(itemDiv);
    });
}

// Function to load items for the "Sell" tab
function loadSellItems() {
    // Fetch player's inventory from the server
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

            // Item Name
            const nameDiv = document.createElement('div');
            nameDiv.className = 'item-name';
            nameDiv.innerText = item.name;
            itemDiv.appendChild(nameDiv);

            // Item Quantity
            const quantityDiv = document.createElement('div');
            quantityDiv.className = 'item-quantity';
            quantityDiv.innerText = 'x' + item.count;
            itemDiv.appendChild(quantityDiv);

            // Sell Price
            const priceDiv = document.createElement('div');
            priceDiv.className = 'item-price';
            priceDiv.innerText = '$' + item.sellPrice;
            itemDiv.appendChild(priceDiv);

            // Quantity Input
            const quantityInput = document.createElement('input');
            quantityInput.type = 'number';
            quantityInput.className = 'quantity-input';
            quantityInput.min = '1';
            quantityInput.max = item.count;
            quantityInput.value = '1';
            itemDiv.appendChild(quantityInput);

            // Sell Button
            const sellBtn = document.createElement('button');
            sellBtn.className = 'sell-btn';
            sellBtn.innerText = 'Sell';
            sellBtn.onclick = () => {
                const quantity = parseInt(quantityInput.value);
                if (isNaN(quantity) || quantity < 1 || quantity > item.count) {
                    alert('Invalid quantity.');
                    return;
                }
                // Send NUI callback to sell item
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

// Function to handle buying an item
function buyItem(itemId, quantity) {
    // Send NUI callback to the server to buy the item
    fetch(`https://${GetParentResourceName()}/buyItem`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ itemId: itemId, quantity: quantity })
    })
    .then(resp => resp.json())
    .then(response => {
        if (response.status === 'success') {
            alert(`Successfully purchased ${quantity} x ${response.itemName}`);
            // Optionally, refresh the store or inventory
            loadItems();
        } else {
            alert(`Purchase failed: ${response.message}`);
        }
    })
    .catch(error => {
        console.error('Error buying item:', error);
        alert('Failed to buy item.');
    });
}

// Function to handle selling an item
function sellItem(itemId, quantity) {
    // Send NUI callback to the server to sell the item
    fetch(`https://${GetParentResourceName()}/sellItem`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ itemId: itemId, quantity: quantity })
    })
    .then(resp => resp.json())
    .then(response => {
        if (response.status === 'success') {
            alert(`Successfully sold ${quantity} x ${response.itemName}`);
            // Optionally, refresh the store or inventory
            loadSellItems();
        } else {
            alert(`Sell failed: ${response.message}`);
        }
    })
    .catch(error => {
        console.error('Error selling item:', error);
        alert('Failed to sell item.');
    });
}

// Function to handle role selection
function selectRole(role) {
    // Send NUI callback to the server to set the player's role
    fetch(`https://${GetParentResourceName()}/selectRole`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ role: role })
    })
    .then(resp => resp.json())
    .then(response => {
        if (response.status === 'success') {
            alert(`Role set to ${response.role}`);
            hideRoleSelection();
            // Optionally, open the store menu after role selection
            // openStoreMenu('Store', response.storeItems);
        } else {
            alert(`Role selection failed: ${response.message}`);
        }
    })
    .catch(error => {
        console.error('Error selecting role:', error);
        alert('Failed to select role.');
    });
}

// Event Listeners for Role Selection Buttons
// Instead of relying on specific IDs, bind events to all buttons inside the role-selection container.
document.addEventListener('DOMContentLoaded', () => {
    const roleButtons = document.querySelectorAll('#role-selection button');
    roleButtons.forEach(button => {
        button.addEventListener('click', () => {
            const selectedRole = button.getAttribute('data-role');
            selectRole(selectedRole);
        });
    });
});

// Function to start the heist timer
function startHeistTimer(duration, bankName) {
    document.getElementById('heist-timer').style.display = 'block';
    const timerText = document.getElementById('timer-text');
    let remainingTime = duration;
    timerText.innerText = `Heist at ${bankName}: ${formatTime(remainingTime)}`;

    clearInterval(heistTimerInterval);
    heistTimerInterval = setInterval(function() {
        remainingTime--;
        if (remainingTime <= 0) {
            clearInterval(heistTimerInterval);
            document.getElementById('heist-timer').style.display = 'none';
            return;
        }
        timerText.innerText = `Heist at ${bankName}: ${formatTime(remainingTime)}`;
    }, 1000);
}

// Helper Function to Format Time (MM:SS)
function formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
}
