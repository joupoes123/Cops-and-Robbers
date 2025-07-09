-- client_consolidated.lua
-- Consolidated Client-Side System with Lazy Loading
-- Combines inventory, character editor, and progression systems
-- Version: 1.2.0

-- ====================================================================
-- CORE SYSTEM INITIALIZATION
-- ====================================================================

-- Module registry for lazy loading
local ClientModules = {
    inventory = nil,
    characterEditor = nil,
    progression = nil,
    loaded = {}
}

-- Component communication system
local ComponentBus = {
    events = {},
    subscribers = {}
}

-- Global state management
local ClientState = {
    playerData = nil,
    inventory = {},
    characterData = {},
    progressionData = {},
    uiStates = {
        inventory = false,
        characterEditor = false,
        progression = false
    }
}

-- ====================================================================
-- COMPONENT COMMUNICATION SYSTEM
-- ====================================================================

--- Register event listener for component communication
--- @param eventName string Event name
--- @param callback function Callback function
--- @param componentName string Component name
function ComponentBus.Subscribe(eventName, callback, componentName)
    if not ComponentBus.subscribers[eventName] then
        ComponentBus.subscribers[eventName] = {}
    end
    
    table.insert(ComponentBus.subscribers[eventName], {
        callback = callback,
        component = componentName
    })
end

--- Emit event to all subscribers
--- @param eventName string Event name
--- @param data any Event data
function ComponentBus.Emit(eventName, data)
    if ComponentBus.subscribers[eventName] then
        for _, subscriber in ipairs(ComponentBus.subscribers[eventName]) do
            if subscriber.callback then
                local success, error = pcall(subscriber.callback, data)
                if not success then
                    print(string.format("[CNR_CLIENT_CONSOLIDATED] Error in %s event handler for %s: %s", 
                        eventName, subscriber.component, error))
                end
            end
        end
    end
end

--- Unsubscribe from event
--- @param eventName string Event name
--- @param componentName string Component name
function ComponentBus.Unsubscribe(eventName, componentName)
    if ComponentBus.subscribers[eventName] then
        for i = #ComponentBus.subscribers[eventName], 1, -1 do
            if ComponentBus.subscribers[eventName][i].component == componentName then
                table.remove(ComponentBus.subscribers[eventName], i)
            end
        end
    end
end

-- ====================================================================
-- LAZY LOADING SYSTEM
-- ====================================================================

--- Load a client module on demand
--- @param moduleName string Module name (inventory, characterEditor, progression)
--- @return boolean Success status
function ClientModules.LoadModule(moduleName)
    if ClientModules.loaded[moduleName] then
        return true
    end
    
    print(string.format("[CNR_CLIENT_CONSOLIDATED] Loading module: %s", moduleName))
    
    local success = false
    
    if moduleName == "inventory" then
        success = ClientModules.LoadInventoryModule()
    elseif moduleName == "characterEditor" then
        success = ClientModules.LoadCharacterEditorModule()
    elseif moduleName == "progression" then
        success = ClientModules.LoadProgressionModule()
    else
        print(string.format("[CNR_CLIENT_CONSOLIDATED] Unknown module: %s", moduleName))
        return false
    end
    
    if success then
        ClientModules.loaded[moduleName] = true
        ComponentBus.Emit("moduleLoaded", {module = moduleName})
        print(string.format("[CNR_CLIENT_CONSOLIDATED] Module loaded successfully: %s", moduleName))
    else
        print(string.format("[CNR_CLIENT_CONSOLIDATED] Failed to load module: %s", moduleName))
    end
    
    return success
end

--- Check if module is loaded
--- @param moduleName string Module name
--- @return boolean Is loaded
function ClientModules.IsLoaded(moduleName)
    return ClientModules.loaded[moduleName] == true
end

--- Unload a module (for memory management)
--- @param moduleName string Module name
function ClientModules.UnloadModule(moduleName)
    if ClientModules.loaded[moduleName] then
        ClientModules.loaded[moduleName] = nil
        ClientModules[moduleName] = nil
        ComponentBus.Emit("moduleUnloaded", {module = moduleName})
        print(string.format("[CNR_CLIENT_CONSOLIDATED] Module unloaded: %s", moduleName))
    end
end

-- ====================================================================
-- INVENTORY MODULE (Lazy Loaded)
-- ====================================================================

function ClientModules.LoadInventoryModule()
    if ClientModules.inventory then return true end
    
    ClientModules.inventory = {
        isOpen = false,
        configItems = nil,
        equippedItems = {},
        
        -- Initialize inventory system
        Initialize = function(self)
            -- Request config items from server
            TriggerServerEvent('cnr:requestConfigItems')
            
            -- Subscribe to component events
            ComponentBus.Subscribe("playerDataUpdated", function(data)
                if data.inventory then
                    ClientState.inventory = data.inventory
                    self:UpdateUI()
                end
            end, "inventory")
            
            ComponentBus.Subscribe("uiToggleRequested", function(data)
                if data.component == "inventory" then
                    self:Toggle()
                end
            end, "inventory")
        end,
        
        -- Toggle inventory UI
        Toggle = function(self)
            self.isOpen = not self.isOpen
            ClientState.uiStates.inventory = self.isOpen
            
            if self.isOpen then
                self:Open()
            else
                self:Close()
            end
        end,
        
        -- Open inventory
        Open = function(self)
            -- Request fresh inventory data
            TriggerServerEvent('cnr:requestMyInventory')
            
            -- Send to NUI
            SendNUIMessage({
                action = "openInventory",
                inventory = ClientState.inventory,
                configItems = self.configItems,
                equippedItems = self.equippedItems
            })
            
            SetNuiFocus(true, true)
            ComponentBus.Emit("inventoryOpened", {})
        end,
        
        -- Close inventory
        Close = function(self)
            SendNUIMessage({action = "closeInventory"})
            SetNuiFocus(false, false)
            ComponentBus.Emit("inventoryClosed", {})
        end,
        
        -- Update inventory UI
        UpdateUI = function(self)
            if self.isOpen then
                SendNUIMessage({
                    action = "updateInventory",
                    inventory = ClientState.inventory,
                    equippedItems = self.equippedItems
                })
            end
        end,
        
        -- Use item
        UseItem = function(self, itemId)
            TriggerServerEvent('cnr:useItem', itemId)
        end,
        
        -- Drop item
        DropItem = function(self, itemId, quantity)
            TriggerServerEvent('cnr:dropItem', itemId, quantity)
        end
    }
    
    -- Initialize the module
    ClientModules.inventory:Initialize()
    
    return true
end

-- ====================================================================
-- CHARACTER EDITOR MODULE (Lazy Loaded)
-- ====================================================================

function ClientModules.LoadCharacterEditorModule()
    if ClientModules.characterEditor then return true end
    
    ClientModules.characterEditor = {
        isOpen = false,
        currentRole = nil,
        currentSlot = 1,
        characterData = {},
        camera = nil,
        
        -- Initialize character editor
        Initialize = function(self)
            -- Load player characters
            TriggerServerEvent('cnr:loadPlayerCharacters')
            
            -- Subscribe to component events
            ComponentBus.Subscribe("roleChanged", function(data)
                self.currentRole = data.role
            end, "characterEditor")
            
            ComponentBus.Subscribe("uiToggleRequested", function(data)
                if data.component == "characterEditor" then
                    self:Toggle()
                end
            end, "characterEditor")
        end,
        
        -- Toggle character editor
        Toggle = function(self)
            self.isOpen = not self.isOpen
            ClientState.uiStates.characterEditor = self.isOpen
            
            if self.isOpen then
                self:Open()
            else
                self:Close()
            end
        end,
        
        -- Open character editor
        Open = function(self)
            -- Setup camera
            self:SetupCamera()
            
            -- Send to NUI
            SendNUIMessage({
                action = "openCharacterEditor",
                characterData = self.characterData,
                currentRole = self.currentRole,
                currentSlot = self.currentSlot
            })
            
            SetNuiFocus(true, true)
            ComponentBus.Emit("characterEditorOpened", {})
        end,
        
        -- Close character editor
        Close = function(self)
            -- Cleanup camera
            self:CleanupCamera()
            
            SendNUIMessage({action = "closeCharacterEditor"})
            SetNuiFocus(false, false)
            ComponentBus.Emit("characterEditorClosed", {})
        end,
        
        -- Setup camera for character editing
        SetupCamera = function(self)
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            
            self.camera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            SetCamCoord(self.camera, coords.x + 2.0, coords.y + 2.0, coords.z + 1.0)
            PointCamAtEntity(self.camera, playerPed, 0.0, 0.0, 0.0, true)
            SetCamActive(self.camera, true)
            RenderScriptCams(true, true, 1000, true, true)
        end,
        
        -- Cleanup camera
        CleanupCamera = function(self)
            if self.camera then
                RenderScriptCams(false, true, 1000, true, true)
                DestroyCam(self.camera, false)
                self.camera = nil
            end
        end,
        
        -- Save character
        SaveCharacter = function(self, characterKey, characterData)
            TriggerServerEvent('cnr:saveCharacterData', characterKey, characterData)
        end,
        
        -- Delete character
        DeleteCharacter = function(self, characterKey)
            TriggerServerEvent('cnr:deleteCharacterData', characterKey)
        end,
        
        -- Apply character
        ApplyCharacter = function(self, characterKey)
            TriggerServerEvent('cnr:applyCharacterToPlayer', characterKey)
        end
    }
    
    -- Initialize the module
    ClientModules.characterEditor:Initialize()
    
    return true
end

-- ====================================================================
-- PROGRESSION MODULE (Lazy Loaded)
-- ====================================================================

function ClientModules.LoadProgressionModule()
    if ClientModules.progression then return true end
    
    ClientModules.progression = {
        isOpen = false,
        playerLevel = 1,
        playerXP = 0,
        challenges = {},
        abilities = {},
        
        -- Initialize progression system
        Initialize = function(self)
            -- Subscribe to component events
            ComponentBus.Subscribe("playerDataUpdated", function(data)
                if data.level then self.playerLevel = data.level end
                if data.xp then self.playerXP = data.xp end
                self:UpdateUI()
            end, "progression")
            
            ComponentBus.Subscribe("uiToggleRequested", function(data)
                if data.component == "progression" then
                    self:Toggle()
                end
            end, "progression")
        end,
        
        -- Toggle progression UI
        Toggle = function(self)
            self.isOpen = not self.isOpen
            ClientState.uiStates.progression = self.isOpen
            
            if self.isOpen then
                self:Open()
            else
                self:Close()
            end
        end,
        
        -- Open progression UI
        Open = function(self)
            SendNUIMessage({
                action = "openProgression",
                level = self.playerLevel,
                xp = self.playerXP,
                challenges = self.challenges,
                abilities = self.abilities
            })
            
            SetNuiFocus(true, true)
            ComponentBus.Emit("progressionOpened", {})
        end,
        
        -- Close progression UI
        Close = function(self)
            SendNUIMessage({action = "closeProgression"})
            SetNuiFocus(false, false)
            ComponentBus.Emit("progressionClosed", {})
        end,
        
        -- Update progression UI
        UpdateUI = function(self)
            if self.isOpen then
                SendNUIMessage({
                    action = "updateProgression",
                    level = self.playerLevel,
                    xp = self.playerXP,
                    challenges = self.challenges,
                    abilities = self.abilities
                })
            end
        end,
        
        -- Show XP gain notification
        ShowXPGain = function(self, amount)
            SendNUIMessage({
                action = "showXPGain",
                amount = amount
            })
        end,
        
        -- Show level up notification
        ShowLevelUp = function(self, newLevel)
            SendNUIMessage({
                action = "showLevelUp",
                level = newLevel
            })
        end
    }
    
    -- Initialize the module
    ClientModules.progression:Initialize()
    
    return true
end

-- ====================================================================
-- MAIN CLIENT SYSTEM
-- ====================================================================

--- Initialize the consolidated client system
function InitializeConsolidatedClient()
    print("[CNR_CLIENT_CONSOLIDATED] Initializing consolidated client system...")
    
    -- Setup component communication
    ComponentBus.Subscribe("moduleLoaded", function(data)
        print(string.format("[CNR_CLIENT_CONSOLIDATED] Module loaded: %s", data.module))
    end, "core")
    
    -- Setup key bindings for lazy loading
    RegisterKeyMapping('cnr_inventory', 'Toggle Inventory', 'keyboard', 'M')
    RegisterKeyMapping('cnr_character_editor', 'Toggle Character Editor', 'keyboard', 'F3')
    RegisterKeyMapping('cnr_progression', 'Toggle Progression', 'keyboard', 'P')
    
    print("[CNR_CLIENT_CONSOLIDATED] Consolidated client system initialized")
end

-- ====================================================================
-- COMMAND HANDLERS
-- ====================================================================

RegisterCommand('cnr_inventory', function()
    if not ClientModules.IsLoaded("inventory") then
        ClientModules.LoadModule("inventory")
    end
    ComponentBus.Emit("uiToggleRequested", {component = "inventory"})
end, false)

RegisterCommand('cnr_character_editor', function()
    if not ClientModules.IsLoaded("characterEditor") then
        ClientModules.LoadModule("characterEditor")
    end
    ComponentBus.Emit("uiToggleRequested", {component = "characterEditor"})
end, false)

RegisterCommand('cnr_progression', function()
    if not ClientModules.IsLoaded("progression") then
        ClientModules.LoadModule("progression")
    end
    ComponentBus.Emit("uiToggleRequested", {component = "progression"})
end, false)

-- ====================================================================
-- EVENT HANDLERS
-- ====================================================================

-- Player data updates
RegisterNetEvent('cnr:updatePlayerData')
AddEventHandler('cnr:updatePlayerData', function(playerData)
    ClientState.playerData = playerData
    ComponentBus.Emit("playerDataUpdated", playerData)
end)

-- Inventory sync
RegisterNetEvent('cnr:syncInventory')
AddEventHandler('cnr:syncInventory', function(inventory)
    ClientState.inventory = inventory
    ComponentBus.Emit("inventoryUpdated", {inventory = inventory})
end)

-- XP gained
RegisterNetEvent('cnr:xpGained')
AddEventHandler('cnr:xpGained', function(amount)
    if ClientModules.IsLoaded("progression") and ClientModules.progression then
        ClientModules.progression:ShowXPGain(amount)
    end
end)

-- Level up
RegisterNetEvent('cnr:levelUp')
AddEventHandler('cnr:levelUp', function(newLevel)
    if ClientModules.IsLoaded("progression") and ClientModules.progression then
        ClientModules.progression:ShowLevelUp(newLevel)
    end
end)

-- Character data events
RegisterNetEvent('cnr:loadedPlayerCharacters')
AddEventHandler('cnr:loadedPlayerCharacters', function(characters)
    ClientState.characterData = characters
    if ClientModules.IsLoaded("characterEditor") and ClientModules.characterEditor then
        ClientModules.characterEditor.characterData = characters
    end
end)

-- Config items received
RegisterNetEvent('cnr:receiveConfigItems')
AddEventHandler('cnr:receiveConfigItems', function(configItems)
    if ClientModules.IsLoaded("inventory") and ClientModules.inventory then
        ClientModules.inventory.configItems = configItems
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    local component = data.component
    if component == "inventory" and ClientModules.IsLoaded("inventory") then
        ClientModules.inventory:Close()
    elseif component == "characterEditor" and ClientModules.IsLoaded("characterEditor") then
        ClientModules.characterEditor:Close()
    elseif component == "progression" and ClientModules.IsLoaded("progression") then
        ClientModules.progression:Close()
    end
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    if ClientModules.IsLoaded("inventory") and ClientModules.inventory then
        ClientModules.inventory:UseItem(data.itemId)
    end
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    if ClientModules.IsLoaded("inventory") and ClientModules.inventory then
        ClientModules.inventory:DropItem(data.itemId, data.quantity)
    end
    cb('ok')
end)

RegisterNUICallback('saveCharacter', function(data, cb)
    if ClientModules.IsLoaded("characterEditor") and ClientModules.characterEditor then
        ClientModules.characterEditor:SaveCharacter(data.characterKey, data.characterData)
    end
    cb('ok')
end)

-- ====================================================================
-- INITIALIZATION
-- ====================================================================

-- Initialize when resource starts
Citizen.CreateThread(function()
    InitializeConsolidatedClient()
end)

-- Export functions for compatibility
exports('LoadModule', ClientModules.LoadModule)
exports('IsModuleLoaded', ClientModules.IsLoaded)
exports('EmitComponentEvent', ComponentBus.Emit)
exports('SubscribeToComponent', ComponentBus.Subscribe)

-- Global access for compatibility
_G.ClientModules = ClientModules
_G.ComponentBus = ComponentBus
_G.ClientState = ClientState