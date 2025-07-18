-- character_editor_server.lua
-- Server-side Character Editor System for Cops and Robbers
-- Handles character data persistence, validation, and role management

local playerCharacterData = {}

-- =========================
-- File I/O Functions
-- =========================

function LoadPlayerCharacters(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return {}
    end
    
    local fileName = "player_data/characters_" .. identifier:gsub(":", "_") .. ".json"
    
    -- Use FiveM's LoadResourceFile function
    local content = LoadResourceFile(GetCurrentResourceName(), fileName)
    
    if content then
        local success, data = pcall(json.decode, content)
        if success and data then
            return data
        else
            Log("[CNR_CHARACTER_EDITOR] Error: Failed to decode character data for player " .. GetPlayerName(playerId), Constants.LOG_LEVELS.ERROR)
        end
    end
    
    return {}
end

function SavePlayerCharacters(playerId, characterData)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        Log("[CNR_CHARACTER_EDITOR] Error: No identifier for player " .. tostring(playerId), Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    -- Get the resource path for proper file handling
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local playerDataDir = resourcePath .. "/player_data"
    
    -- Ensure player_data directory exists with proper path handling
    local success = pcall(function()
        -- Create directory using FiveM's built-in functions
        local dirExists = LoadResourceFile(GetCurrentResourceName(), "player_data/test.txt")
        if not dirExists then
            -- Try to create a test file to ensure directory exists
            SaveResourceFile(GetCurrentResourceName(), "player_data/.gitkeep", "# Directory placeholder", -1)
        end
    end)
    
    if not success then
        Log("[CNR_CHARACTER_EDITOR] Warning: Could not verify player_data directory", Constants.LOG_LEVELS.WARN)
    end
    
    local fileName = "player_data/characters_" .. identifier:gsub(":", "_") .. ".json"
    
    -- Try to encode the data first
    local jsonData
    local encodeSuccess = pcall(function()
        jsonData = json.encode(characterData, {indent = true})
    end)
    
    if not encodeSuccess or not jsonData then
        Log("[CNR_CHARACTER_EDITOR] Error: Failed to encode character data for " .. GetPlayerName(playerId), Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    -- Use FiveM's SaveResourceFile function for proper file handling
    local saveSuccess = pcall(function()
        SaveResourceFile(GetCurrentResourceName(), fileName, jsonData, -1)
    end)
    
    if not saveSuccess then
        Log("[CNR_CHARACTER_EDITOR] Error: Failed to save character data for player: " .. GetPlayerName(playerId), Constants.LOG_LEVELS.ERROR)
        return false
    end
    
    return true
end

-- =========================
-- Character Data Validation
-- =========================

function ValidateCharacterData(characterData, role)
    if not characterData or type(characterData) ~= "table" then
        return false, "Invalid character data"
    end
    
    -- Validate basic required fields
    local requiredFields = {"model", "face", "skin", "hair"}
    for _, field in ipairs(requiredFields) do
        if characterData[field] == nil then
            return false, "Missing required field: " .. field
        end
    end
    
    -- Ensure Config.CharacterEditor exists before validation
    if not Config.CharacterEditor or not Config.CharacterEditor.customization then
        Log("[CNR_CHARACTER_EDITOR] Warning: Config.CharacterEditor.customization not found, skipping detailed validation", Constants.LOG_LEVELS.WARN)
        return true, "Valid (basic validation only)"
    end
    
    -- Validate customization ranges
    local customization = Config.CharacterEditor.customization
    for feature, range in pairs(customization) do
        if characterData[feature] ~= nil then
            local value = characterData[feature]
            if type(value) == "number" then
                if value < range.min or value > range.max then
                    return false, "Invalid value for " .. feature .. ": " .. value
                end
            end
        end
    end
    
    -- Validate face features
    if characterData.faceFeatures then
        for feature, value in pairs(characterData.faceFeatures) do
            if customization[feature] then
                local range = customization[feature]
                if type(value) == "number" and value < range.min or value > range.max then
                    return false, "Invalid face feature value for " .. feature .. ": " .. value
                end
            end
        end
    end
    
    return true, "Valid"
end

function SanitizeCharacterData(characterData)
    local sanitized = {}
    
    -- Copy safe fields
    local safeFields = {
        "model", "face", "skin", "hair", "hairColor", "hairHighlight",
        "beard", "beardColor", "beardOpacity", "eyebrows", "eyebrowsColor", "eyebrowsOpacity",
        "eyeColor", "blush", "blushColor", "blushOpacity", "lipstick", "lipstickColor", "lipstickOpacity",
        "makeup", "makeupColor", "makeupOpacity", "ageing", "ageingOpacity", "complexion", "complexionOpacity",
        "sundamage", "sundamageOpacity", "freckles", "frecklesOpacity", "bodyBlemishes", "bodyBlemishesOpacity",
        "addBodyBlemishes", "addBodyBlemishesOpacity", "moles", "molesOpacity", "chesthair", "chesthairColor", "chesthairOpacity"
    }
    
    for _, field in ipairs(safeFields) do
        if characterData[field] ~= nil then
            sanitized[field] = characterData[field]
        end
    end
    
    -- Copy face features
    if characterData.faceFeatures and type(characterData.faceFeatures) == "table" then
        sanitized.faceFeatures = {}
        local safeFeatures = {
            "noseWidth", "noseHeight", "noseLength", "noseBridge", "noseTip", "noseShift",
            "browHeight", "browWidth", "cheekboneHeight", "cheekboneWidth", "cheeksWidth",
            "eyesOpening", "lipsThickness", "jawWidth", "jawHeight", "chinLength",
            "chinPosition", "chinWidth", "chinShape", "neckWidth"
        }
        
        for _, feature in ipairs(safeFeatures) do
            if characterData.faceFeatures[feature] ~= nil then
                sanitized.faceFeatures[feature] = characterData.faceFeatures[feature]
            end
        end
    end
    
    -- Copy components and props
    if characterData.components and type(characterData.components) == "table" then
        sanitized.components = {}
        for componentId, component in pairs(characterData.components) do
            if type(component) == "table" and component.drawable and component.texture then
                sanitized.components[componentId] = {
                    drawable = tonumber(component.drawable) or 0,
                    texture = tonumber(component.texture) or 0
                }
            end
        end
    end
    
    if characterData.props and type(characterData.props) == "table" then
        sanitized.props = {}
        for propId, prop in pairs(characterData.props) do
            if type(prop) == "table" and prop.drawable and prop.texture then
                sanitized.props[propId] = {
                    drawable = tonumber(prop.drawable) or -1,
                    texture = tonumber(prop.texture) or 0
                }
            end
        end
    end
    
    -- Copy tattoos
    if characterData.tattoos and type(characterData.tattoos) == "table" then
        sanitized.tattoos = {}
        for _, tattoo in ipairs(characterData.tattoos) do
            if type(tattoo) == "table" and tattoo.collection and tattoo.name then
                table.insert(sanitized.tattoos, {
                    collection = tostring(tattoo.collection),
                    name = tostring(tattoo.name)
                })
            end
        end
    end
    
    return sanitized
end

-- =========================
-- Character Management
-- =========================

function GetPlayerCharacterSlots(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return {}
    end
    
    if not playerCharacterData[identifier] then
        playerCharacterData[identifier] = LoadPlayerCharacters(playerId)
    end
    
    return playerCharacterData[identifier]
end

function SavePlayerCharacterSlot(playerId, characterKey, characterData, role)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return false, "Invalid player identifier"
    end
    
    -- Validate character data
    local isValid, errorMsg = ValidateCharacterData(characterData, role)
    if not isValid then
        return false, errorMsg
    end
    
    -- Sanitize character data
    local sanitizedData = SanitizeCharacterData(characterData)
    
    -- Load current character data
    if not playerCharacterData[identifier] then
        playerCharacterData[identifier] = LoadPlayerCharacters(playerId)
    end
    
    -- Save character data
    playerCharacterData[identifier][characterKey] = sanitizedData
    
    -- Persist to file
    local success = SavePlayerCharacters(playerId, playerCharacterData[identifier])
    if success then
        return true, "Character saved successfully"
    else
        return false, "Failed to save character data"
    end
end

function DeletePlayerCharacterSlot(playerId, characterKey)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return false, "Invalid player identifier"
    end
    
    if not playerCharacterData[identifier] then
        playerCharacterData[identifier] = LoadPlayerCharacters(playerId)
    end
    
    if playerCharacterData[identifier][characterKey] then
        playerCharacterData[identifier][characterKey] = nil
        
        local success = SavePlayerCharacters(playerId, playerCharacterData[identifier])
        if success then
            return true, "Character deleted successfully"
        else
            return false, "Failed to delete character data"
        end
    else
        return false, "Character not found"
    end
end

function ApplyCharacterToPlayer(playerId, characterKey)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        return false, "Invalid player identifier"
    end
    
    local characters = GetPlayerCharacterSlots(playerId)
    local characterData = characters[characterKey]
    
    if not characterData then
        return false, "Character not found"
    end
    
    -- Trigger client to apply character
    TriggerClientEvent('cnr:applyCharacterData', playerId, characterData)
    
    return true, "Character applied successfully"
end

-- =========================
-- Event Handlers
-- =========================

RegisterNetEvent('cnr:loadPlayerCharacters')
AddEventHandler('cnr:loadPlayerCharacters', function()
    local playerId = source
    local characters = GetPlayerCharacterSlots(playerId)
    TriggerClientEvent('cnr:loadedPlayerCharacters', playerId, characters)
end)

RegisterNetEvent('cnr:saveCharacterData')
AddEventHandler('cnr:saveCharacterData', function(characterKey, characterData)
    local playerId = source
    
    -- Extract role from character key
    local role = string.match(characterKey, "^(%w+)_")
    if not role or (role ~= "cop" and role ~= "robber") then
        Log(string.format("[CNR_CHARACTER_EDITOR] Invalid character key format: %s", characterKey), Constants.LOG_LEVELS.ERROR)
        return
    end
    
    local success, message = SavePlayerCharacterSlot(playerId, characterKey, characterData, role)
    
    if success then
        TriggerClientEvent('cnr:characterSaveResult', playerId, true, message)
    else
        TriggerClientEvent('cnr:characterSaveResult', playerId, false, message)
        Log(string.format("[CNR_CHARACTER_EDITOR] Failed to save character for player %s: %s", GetPlayerName(playerId), message), Constants.LOG_LEVELS.ERROR)
    end
end)

RegisterNetEvent('cnr:deleteCharacterData')
AddEventHandler('cnr:deleteCharacterData', function(characterKey)
    local playerId = source
    local success, message = DeletePlayerCharacterSlot(playerId, characterKey)
    
    if success then
        TriggerClientEvent('cnr:characterDeleteResult', playerId, true, message)
    else
        TriggerClientEvent('cnr:characterDeleteResult', playerId, false, message)
        Log(string.format("[CNR_CHARACTER_EDITOR] Failed to delete character for player %s: %s", GetPlayerName(playerId), message), Constants.LOG_LEVELS.ERROR)
    end
end)

RegisterNetEvent('cnr:applyCharacterToPlayer')
AddEventHandler('cnr:applyCharacterToPlayer', function(characterKey)
    local playerId = source
    local success, message = ApplyCharacterToPlayer(playerId, characterKey)
    
    if not success then
        Log(string.format("[CNR_CHARACTER_EDITOR] Failed to apply character for player %s: %s", GetPlayerName(playerId), message), Constants.LOG_LEVELS.ERROR)
    end
end)

RegisterNetEvent('cnr:getCharacterForRole')
AddEventHandler('cnr:getCharacterForRole', function(role, slot)
    local playerId = source
    local characterData = GetCharacterForRoleSelection(playerId, role, slot)
    TriggerClientEvent('cnr:receiveCharacterForRole', playerId, characterData)
end)

-- =========================
-- Integration with Role Selection
-- =========================

-- Function to get character data for role selection
function GetCharacterForRoleSelection(playerId, role, slot)
    local characters = GetPlayerCharacterSlots(playerId)
    local characterKey = role .. "_" .. (slot or 1)
    return characters[characterKey]
end

-- Function to check if player has created a character for a role
function HasCharacterForRole(playerId, role)
    local characters = GetPlayerCharacterSlots(playerId)
    local characterKey = role .. "_1"
    return characters[characterKey] ~= nil
end

-- Export functions for other scripts
exports('GetPlayerCharacterSlots', GetPlayerCharacterSlots)
exports('SavePlayerCharacterSlot', SavePlayerCharacterSlot)
exports('DeletePlayerCharacterSlot', DeletePlayerCharacterSlot)
exports('ApplyCharacterToPlayer', ApplyCharacterToPlayer)
exports('GetCharacterForRoleSelection', GetCharacterForRoleSelection)
exports('HasCharacterForRole', HasCharacterForRole)

