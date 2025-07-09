// ui_optimizer.js
// Client-side UI performance optimization system
// Version: 1.2.0

// UI Optimization Manager
window.UIOptimizer = {
    // Component cache for lazy loading
    componentCache: new Map(),
    
    // DOM element pools for reuse
    elementPools: {
        inventorySlots: [],
        listItems: [],
        buttons: []
    },
    
    // Virtual scrolling state
    virtualScrollState: {
        itemHeight: 60,
        containerHeight: 400,
        scrollTop: 0,
        visibleStart: 0,
        visibleEnd: 0
    },
    
    // Performance metrics
    metrics: {
        domOperations: 0,
        cacheHits: 0,
        cacheMisses: 0,
        renderTime: 0,
        lastUpdate: Date.now()
    },
    
    // Debounced functions cache
    debouncedFunctions: new Map(),
    
    // ====================================================================
    // COMPONENT LAZY LOADING
    // ====================================================================
    
    /**
     * Lazy load a UI component
     * @param {string} componentId - Component identifier
     * @param {Function} createFunction - Function to create the component
     * @returns {HTMLElement} The component element
     */
    lazyLoadComponent(componentId, createFunction) {
        if (this.componentCache.has(componentId)) {
            this.metrics.cacheHits++;
            return this.componentCache.get(componentId);
        }
        
        this.metrics.cacheMisses++;
        const component = createFunction();
        this.componentCache.set(componentId, component);
        return component;
    },
    
    /**
     * Preload commonly used components
     */
    preloadComponents() {
        const componentsToPreload = [
            'store-menu',
            'inventory-container',
            'role-selection-menu',
            'admin-panel'
        ];
        
        componentsToPreload.forEach(componentId => {
            const element = document.getElementById(componentId);
            if (element) {
                this.componentCache.set(componentId, element);
            }
        });
        
        console.log('[UI_OPTIMIZER] Preloaded', componentsToPreload.length, 'components');
    },
    
    // ====================================================================
    // DOM ELEMENT POOLING
    // ====================================================================
    
    /**
     * Get an element from the pool or create a new one
     * @param {string} poolName - Pool name
     * @param {Function} createFunction - Function to create new element
     * @returns {HTMLElement} Pooled or new element
     */
    getPooledElement(poolName, createFunction) {
        const pool = this.elementPools[poolName];
        if (pool && pool.length > 0) {
            return pool.pop();
        }
        
        return createFunction();
    },
    
    /**
     * Return an element to the pool
     * @param {string} poolName - Pool name
     * @param {HTMLElement} element - Element to return
     */
    returnToPool(poolName, element) {
        if (!element) return;
        
        // Clean the element
        element.className = '';
        element.innerHTML = '';
        element.removeAttribute('style');
        
        // Remove event listeners
        const newElement = element.cloneNode(false);
        element.parentNode?.replaceChild(newElement, element);
        
        const pool = this.elementPools[poolName];
        if (pool && pool.length < 50) { // Limit pool size
            pool.push(newElement);
        }
    },
    
    /**
     * Create optimized inventory slot with pooling
     * @param {Object} item - Item data
     * @param {string} type - Slot type ('buy' or 'sell')
     * @returns {HTMLElement} Inventory slot element
     */
    createOptimizedInventorySlot(item, type) {
        const slot = this.getPooledElement('inventorySlots', () => {
            const div = document.createElement('div');
            div.className = 'inventory-slot';
            return div;
        });
        
        // Use document fragment for batch DOM operations
        const fragment = document.createDocumentFragment();
        
        // Icon container
        const iconContainer = document.createElement('div');
        iconContainer.className = 'item-icon-container';
        
        // Lazy load images
        if (item.image && item.image !== 'img/default.png') {
            const img = document.createElement('img');
            img.className = 'item-image';
            img.loading = 'lazy'; // Native lazy loading
            img.src = item.image;
            img.onerror = () => {
                img.style.display = 'none';
                const fallback = document.createElement('div');
                fallback.className = 'item-icon';
                fallback.textContent = this.getItemIcon(item.category, item.name);
                iconContainer.appendChild(fallback);
            };
            iconContainer.appendChild(img);
        } else {
            const icon = document.createElement('div');
            icon.className = 'item-icon';
            icon.textContent = this.getItemIcon(item.category, item.name);
            iconContainer.appendChild(icon);
        }
        
        // Quantity badge (if needed)
        if (item.count && item.count > 1) {
            const badge = document.createElement('div');
            badge.className = 'quantity-badge';
            badge.textContent = `x${item.count}`;
            iconContainer.appendChild(badge);
        }
        
        fragment.appendChild(iconContainer);
        
        // Item info
        const itemInfo = document.createElement('div');
        itemInfo.className = 'item-info';
        
        const itemName = document.createElement('div');
        itemName.className = 'item-name';
        itemName.textContent = item.name || item.itemId || 'Unknown Item';
        itemInfo.appendChild(itemName);
        
        const itemPrice = document.createElement('div');
        itemPrice.className = 'item-price';
        const priceValue = type === 'buy' ? (item.price || item.basePrice || 0) : (item.sellPrice || 0);
        itemPrice.textContent = `$${priceValue.toLocaleString()}`;
        itemInfo.appendChild(itemPrice);
        
        fragment.appendChild(itemInfo);
        
        // Action overlay (only for unlocked items)
        if (!item.locked) {
            const actionOverlay = document.createElement('div');
            actionOverlay.className = 'action-overlay';
            
            const quantityInput = document.createElement('input');
            quantityInput.type = 'number';
            quantityInput.min = '1';
            quantityInput.max = type === 'buy' ? '100' : (item.count?.toString() || '1');
            quantityInput.value = '1';
            actionOverlay.appendChild(quantityInput);
            
            const actionBtn = document.createElement('button');
            actionBtn.textContent = type === 'buy' ? 'Buy' : 'Sell';
            actionBtn.onclick = () => {
                const quantity = parseInt(quantityInput.value) || 1;
                this.handleItemAction(item.itemId, quantity, type);
            };
            actionOverlay.appendChild(actionBtn);
            
            fragment.appendChild(actionOverlay);
        }
        
        // Single DOM operation
        slot.appendChild(fragment);
        this.metrics.domOperations++;
        
        return slot;
    },
    
    // ====================================================================
    // VIRTUAL SCROLLING
    // ====================================================================
    
    /**
     * Initialize virtual scrolling for large lists
     * @param {HTMLElement} container - Container element
     * @param {Array} items - Items array
     * @param {Function} renderItem - Function to render each item
     */
    initVirtualScrolling(container, items, renderItem) {
        const state = this.virtualScrollState;
        const visibleCount = Math.ceil(state.containerHeight / state.itemHeight) + 2; // Buffer
        
        // Create virtual container
        const virtualContainer = document.createElement('div');
        virtualContainer.style.height = `${items.length * state.itemHeight}px`;
        virtualContainer.style.position = 'relative';
        
        const visibleContainer = document.createElement('div');
        visibleContainer.style.position = 'absolute';
        visibleContainer.style.top = '0';
        visibleContainer.style.width = '100%';
        
        virtualContainer.appendChild(visibleContainer);
        container.appendChild(virtualContainer);
        
        const updateVisibleItems = this.debounce(() => {
            const scrollTop = container.scrollTop;
            const visibleStart = Math.floor(scrollTop / state.itemHeight);
            const visibleEnd = Math.min(visibleStart + visibleCount, items.length);
            
            // Clear visible container
            visibleContainer.innerHTML = '';
            
            // Render visible items
            const fragment = document.createDocumentFragment();
            for (let i = visibleStart; i < visibleEnd; i++) {
                const item = renderItem(items[i], i);
                item.style.position = 'absolute';
                item.style.top = `${i * state.itemHeight}px`;
                item.style.height = `${state.itemHeight}px`;
                fragment.appendChild(item);
            }
            
            visibleContainer.appendChild(fragment);
            this.metrics.domOperations++;
        }, 16); // ~60fps
        
        container.addEventListener('scroll', updateVisibleItems);
        updateVisibleItems(); // Initial render
    },
    
    // ====================================================================
    // DEBOUNCING AND THROTTLING
    // ====================================================================
    
    /**
     * Debounce a function
     * @param {Function} func - Function to debounce
     * @param {number} wait - Wait time in milliseconds
     * @returns {Function} Debounced function
     */
    debounce(func, wait) {
        const key = func.toString() + wait;
        
        if (this.debouncedFunctions.has(key)) {
            return this.debouncedFunctions.get(key);
        }
        
        let timeout;
        const debounced = function(...args) {
            clearTimeout(timeout);
            timeout = setTimeout(() => func.apply(this, args), wait);
        };
        
        this.debouncedFunctions.set(key, debounced);
        return debounced;
    },
    
    /**
     * Throttle a function
     * @param {Function} func - Function to throttle
     * @param {number} limit - Time limit in milliseconds
     * @returns {Function} Throttled function
     */
    throttle(func, limit) {
        let inThrottle;
        return function(...args) {
            if (!inThrottle) {
                func.apply(this, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    },
    
    // ====================================================================
    // BATCH DOM OPERATIONS
    // ====================================================================
    
    /**
     * Batch DOM operations to reduce reflows
     * @param {Function} operations - Function containing DOM operations
     */
    batchDOMOperations(operations) {
        const startTime = performance.now();
        
        // Use requestAnimationFrame for optimal timing
        requestAnimationFrame(() => {
            operations();
            
            const endTime = performance.now();
            this.metrics.renderTime += endTime - startTime;
            this.metrics.domOperations++;
        });
    },
    
    /**
     * Optimized grid rendering with batching
     * @param {HTMLElement} container - Grid container
     * @param {Array} items - Items to render
     * @param {Function} createItem - Function to create item element
     */
    renderGridOptimized(container, items, createItem) {
        this.batchDOMOperations(() => {
            // Clear container efficiently
            container.innerHTML = '';
            
            // Use document fragment for batch insertion
            const fragment = document.createDocumentFragment();
            
            // Process items in chunks to avoid blocking
            const chunkSize = 20;
            let currentIndex = 0;
            
            const processChunk = () => {
                const endIndex = Math.min(currentIndex + chunkSize, items.length);
                
                for (let i = currentIndex; i < endIndex; i++) {
                    const itemElement = createItem(items[i]);
                    if (itemElement) {
                        fragment.appendChild(itemElement);
                    }
                }
                
                currentIndex = endIndex;
                
                if (currentIndex < items.length) {
                    // Process next chunk in next frame
                    requestAnimationFrame(processChunk);
                } else {
                    // Final insertion
                    container.appendChild(fragment);
                }
            };
            
            processChunk();
        });
    },
    
    // ====================================================================
    // UTILITY FUNCTIONS
    // ====================================================================
    
    /**
     * Get item icon based on category
     * @param {string} category - Item category
     * @param {string} name - Item name
     * @returns {string} Icon character
     */
    getItemIcon(category, name) {
        const iconMap = {
            'weapons': '🔫',
            'ammo': '📦',
            'armor': '🛡️',
            'tools': '🔧',
            'medical': '💊',
            'food': '🍔',
            'misc': '📄'
        };
        
        return iconMap[category] || iconMap['misc'];
    },
    
    /**
     * Handle item action with optimized feedback
     * @param {string} itemId - Item ID
     * @param {number} quantity - Quantity
     * @param {string} type - Action type
     */
    handleItemAction(itemId, quantity, type) {
        // Optimized feedback without blocking UI
        this.showOptimizedToast(`${type === 'buy' ? 'Buying' : 'Selling'} ${quantity}x ${itemId}...`, 'info');
        
        // Send to game
        fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/${type}Item`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ itemId, quantity })
        });
    },
    
    /**
     * Show optimized toast notification
     * @param {string} message - Message to show
     * @param {string} type - Toast type
     */
    showOptimizedToast(message, type) {
        const toast = this.getPooledElement('toasts', () => {
            const div = document.createElement('div');
            div.className = 'toast-notification';
            return div;
        });
        
        toast.textContent = message;
        toast.className = `toast-notification toast-${type}`;
        
        document.body.appendChild(toast);
        
        // Animate in
        requestAnimationFrame(() => {
            toast.classList.add('toast-show');
        });
        
        // Remove after delay
        setTimeout(() => {
            toast.classList.remove('toast-show');
            setTimeout(() => {
                document.body.removeChild(toast);
                this.returnToPool('toasts', toast);
            }, 300);
        }, 3000);
    },
    
    // ====================================================================
    // PERFORMANCE MONITORING
    // ====================================================================
    
    /**
     * Get performance metrics
     * @returns {Object} Performance metrics
     */
    getMetrics() {
        return {
            ...this.metrics,
            cacheHitRate: this.metrics.cacheHits / (this.metrics.cacheHits + this.metrics.cacheMisses) * 100,
            averageRenderTime: this.metrics.renderTime / this.metrics.domOperations,
            poolSizes: Object.keys(this.elementPools).reduce((acc, key) => {
                acc[key] = this.elementPools[key].length;
                return acc;
            }, {})
        };
    },
    
    /**
     * Log performance metrics
     */
    logMetrics() {
        const metrics = this.getMetrics();
        console.log('[UI_OPTIMIZER] Performance Metrics:', metrics);
    },
    
    // ====================================================================
    // INITIALIZATION
    // ====================================================================
    
    /**
     * Initialize UI optimizer
     */
    initialize() {
        console.log('[UI_OPTIMIZER] Initializing UI optimization system...');
        
        // Preload components
        this.preloadComponents();
        
        // Set up performance monitoring
        setInterval(() => {
            this.logMetrics();
        }, 60000); // Every minute
        
        // Clean up caches periodically
        setInterval(() => {
            this.cleanupCaches();
        }, 300000); // Every 5 minutes
        
        console.log('[UI_OPTIMIZER] UI optimization system initialized');
    },
    
    /**
     * Clean up caches to prevent memory leaks
     */
    cleanupCaches() {
        // Clear old debounced functions
        this.debouncedFunctions.clear();
        
        // Limit component cache size
        if (this.componentCache.size > 50) {
            const entries = Array.from(this.componentCache.entries());
            entries.slice(0, 25).forEach(([key]) => {
                this.componentCache.delete(key);
            });
        }
        
        // Limit pool sizes
        Object.keys(this.elementPools).forEach(poolName => {
            const pool = this.elementPools[poolName];
            if (pool.length > 25) {
                this.elementPools[poolName] = pool.slice(0, 25);
            }
        });
        
        console.log('[UI_OPTIMIZER] Cache cleanup completed');
    }
};

// ====================================================================
// PERFORMANCE TESTING
// ====================================================================

/**
 * Run UI performance test
 */
function runUIPerformanceTest() {
    console.log('[UI_OPTIMIZER] Running UI performance test...');
    
    const testStartTime = performance.now();
    const testItems = [];
    
    // Generate test data
    for (let i = 0; i < 1000; i++) {
        testItems.push({
            itemId: `test_item_${i}`,
            name: `Test Item ${i}`,
            category: ['weapons', 'ammo', 'armor', 'tools'][i % 4],
            price: Math.floor(Math.random() * 1000) + 100,
            image: 'img/default.png'
        });
    }
    
    // Test DOM operations
    const container = document.createElement('div');
    container.style.position = 'absolute';
    container.style.top = '-9999px';
    document.body.appendChild(container);
    
    const domStartTime = performance.now();
    
    // Test optimized rendering
    if (window.UIOptimizer) {
        window.UIOptimizer.renderGridOptimized(container, testItems, (item) => {
            return window.UIOptimizer.createOptimizedInventorySlot(item, 'buy');
        });
    }
    
    const domEndTime = performance.now();
    
    // Clean up
    document.body.removeChild(container);
    
    const testEndTime = performance.now();
    
    const results = {
        totalTestTime: testEndTime - testStartTime,
        domRenderTime: domEndTime - domStartTime,
        itemsRendered: testItems.length,
        averageTimePerItem: (domEndTime - domStartTime) / testItems.length,
        itemsPerSecond: testItems.length / ((domEndTime - domStartTime) / 1000),
        ...window.UIOptimizer.getMetrics()
    };
    
    console.log('[UI_OPTIMIZER] Performance test results:', results);
    
    // Send results to server
    fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/uiTestResults`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(results)
    });
    
    return results;
}

// Listen for performance test events
window.addEventListener('message', function(event) {
    if (event.data.action === 'performUITest') {
        runUIPerformanceTest();
    } else if (event.data.action === 'getUITestResults') {
        const metrics = window.UIOptimizer ? window.UIOptimizer.getMetrics() : {};
        fetch(`https://${window.cnrResourceName || 'cops-and-robbers'}/uiTestResults`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(metrics)
        });
    }
});

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        UIOptimizer.initialize();
    });
} else {
    UIOptimizer.initialize();
}