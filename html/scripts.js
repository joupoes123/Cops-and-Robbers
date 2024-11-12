let heistTimerInterval;
let items = [];
let currentCategory = null;
let currentTab = 'buy';


window.addEventListener('message', function(event) {
    let data = event.data;
    if (data.action === 'openRoleMenu') {
        document.getElementById('role-selection').style.display = 'block';
    } else if (data.action === 'startHeistTimer') {
        startHeistTimer(data.duration, data.bankName);
    }
});

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'openStore') {
        document.getElementById('store-title').innerText = data.storeName || 'Store';
        items = data.items;
        loadCategories();
        loadItems();
        document.getElementById('store-menu').style.display = 'block';
    } else if (data.action === 'closeStore') {
        document.getElementById('store-menu').style.display = 'none';
    }
});

document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentTab = btn.dataset.tab;
        document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
        document.getElementById(`${currentTab}-section`).classList.add('active');
        if (currentTab === 'sell') {
            loadSellItems();
        } else {
            loadItems();
        }
    });
});

function loadCategories() {
    const categories = [...new Set(items.map(item => item.category))];
    const categoryList = document.getElementById('category-list');
    categoryList.innerHTML = '';

    categories.forEach(category => {
        const btn = document.createElement('button');
        btn.className = 'category-btn';
        btn.innerText = category;
        btn.onclick = () => {
            currentCategory = category;
            document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            if (currentTab === 'buy') {
                loadItems();
            }
        };
        categoryList.appendChild(btn);
    });
}

function loadItems() {
    const itemList = document.getElementById('item-list');
    itemList.innerHTML = '';

    items.filter(item => !currentCategory || item.category === currentCategory)
        .forEach(item => {
            const itemDiv = document.createElement('div');
            itemDiv.className = 'item';

            const nameDiv = document.createElement('div');
            nameDiv.className = 'item-name';
            nameDiv.innerText = item.name;

            const priceDiv = document.createElement('div');
            priceDiv.className = 'item-price';
            priceDiv.innerText = '$' + item.price;

            // Quantity input
            const quantityInput = document.createElement('input');
            quantityInput.type = 'number';
            quantityInput.className = 'quantity-input';
            quantityInput.min = '1';
            quantityInput.max = '100';
            quantityInput.value = '1';

            const buyBtn = document.createElement('button');
            buyBtn.className = 'buy-btn';
            buyBtn.innerText = 'Buy';
            buyBtn.onclick = () => {
                const quantity = parseInt(quantityInput.value);
                if (isNaN(quantity) || quantity < 1 || quantity > 100) {
                    alert('Invalid quantity.');
                    return;
                }
                fetch(`https://${GetParentResourceName()}/buyItem`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ itemId: item.itemId, quantity: quantity })
                });
            };

            itemDiv.appendChild(nameDiv);
            itemDiv.appendChild(priceDiv);
            itemDiv.appendChild(quantityInput);
            itemDiv.appendChild(buyBtn);

            itemList.appendChild(itemDiv);
        });
}

function loadSellItems() {
    fetch(`https://${GetParentResourceName()}/getPlayerInventory`, {
        method: 'POST'
    }).then(resp => resp.json()).then(data => {
        const sellSection = document.getElementById('sell-section');
        sellSection.innerHTML = '';
        data.items.forEach(item => {
            const itemDiv = document.createElement('div');
            itemDiv.className = 'item';

            const nameDiv = document.createElement('div');
            nameDiv.className = 'item-name';
            nameDiv.innerText = item.name;

            const quantityDiv = document.createElement('div');
            quantityDiv.className = 'item-quantity';
            quantityDiv.innerText = 'x' + item.count;

            const priceDiv = document.createElement('div');
            priceDiv.className = 'item-price';
            priceDiv.innerText = '$' + item.sellPrice;

            // Quantity input
            const quantityInput = document.createElement('input');
            quantityInput.type = 'number';
            quantityInput.className = 'quantity-input';
            quantityInput.min = '1';
            quantityInput.max = item.count;
            quantityInput.value = '1';

            const sellBtn = document.createElement('button');
            sellBtn.className = 'sell-btn';
            sellBtn.innerText = 'Sell';
            sellBtn.onclick = () => {
                const quantity = parseInt(quantityInput.value);
                if (isNaN(quantity) || quantity < 1 || quantity > item.count) {
                    alert('Invalid quantity.');
                    return;
                }
                fetch(`https://${GetParentResourceName()}/sellItem`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ itemId: item.itemId, quantity: quantity })
                });
            };

            itemDiv.appendChild(nameDiv);
            itemDiv.appendChild(quantityDiv);
            itemDiv.appendChild(priceDiv);
            itemDiv.appendChild(quantityInput);
            itemDiv.appendChild(sellBtn);

            sellSection.appendChild(itemDiv);
        });
    });
}

document.getElementById('close-btn').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/closeStore`, {
        method: 'POST'
    });
});

function selectRole(role) {
    fetch(`https://${GetParentResourceName()}/selectRole`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ role: role })
    });
    document.getElementById('role-selection').style.display = 'none';
}

function startHeistTimer(duration, bankName) {
    document.getElementById('heist-timer').style.display = 'block';
    let timerText = document.getElementById('timer-text');
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

function formatTime(seconds) {
    let mins = Math.floor(seconds / 60);
    let secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
}
