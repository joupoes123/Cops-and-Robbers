-- character_editor_client.lua
-- Comprehensive Character Editor System for Cops and Robbers
-- Handles all character customization, role-specific uniforms, and character management

local isInCharacterEditor = false
local currentCharacterData = {}
local originalPlayerData = {}
local editorCamera = nil
local currentCameraMode = "face"
local currentRole = nil
local currentCharacterSlot = 1
local playerCharacters = {}
local previewingUniform = false
local currentUniformPreset = nil

-- Character editor UI state
local editorUI = {
    currentCategory = "appearance",
    currentSubCategory = "face",
    isVisible = false
}

-- Initialize character editor
Citizen.CreateThread(function()
    -- Load player characters on resource start
    TriggerServerEvent('cnr:loadPlayerCharacters')
end)

-- =========================
-- Character Data Management
-- =========================

function GetDefaultCharacterData()
    local defaultData = {}
    for k, v in pairs(Config.CharacterEditor.defaultCharacter) do
        if type(v) == "table" then
            defaultData[k] = {}
            for k2, v2 in pairs(v) do
                defaultData[k][k2] = v2
            end
        else
            defaultData[k] = v
        end
    end
    return defaultData
end

function ApplyCharacterData(characterData, ped)
    if not characterData or not ped or not DoesEntityExist(ped) then
        return false
    end

    -- Set basic appearance
    SetPedHeadBlendData(ped, characterData.face or 0, characterData.face or 0, 0, 
                       characterData.skin or 0, characterData.skin or 0, 0, 
                       0.5, 0.5, 0.0, false)

    -- Set hair
    SetPedComponentVariation(ped, 2, characterData.hair or 0, 0, 0)
    SetPedHairColor(ped, characterData.hairColor or 0, characterData.hairHighlight or 0)

    -- Set facial features
    if characterData.faceFeatures then
        local features = {
            {0, characterData.faceFeatures.noseWidth or 0.0},
            {1, characterData.faceFeatures.noseHeight or 0.0},
            {2, characterData.faceFeatures.noseLength or 0.0},
            {3, characterData.faceFeatures.noseBridge or 0.0},
            {4, characterData.faceFeatures.noseTip or 0.0},
            {5, characterData.faceFeatures.noseShift or 0.0},
            {6, characterData.faceFeatures.browHeight or 0.0},
            {7, characterData.faceFeatures.browWidth or 0.0},
            {8, characterData.faceFeatures.cheekboneHeight or 0.0},
            {9, characterData.faceFeatures.cheekboneWidth or 0.0},
            {10, characterData.faceFeatures.cheeksWidth or 0.0},
            {11, characterData.faceFeatures.eyesOpening or 0.0},
            {12, characterData.faceFeatures.lipsThickness or 0.0},
            {13, characterData.faceFeatures.jawWidth or 0.0},
            {14, characterData.faceFeatures.jawHeight or 0.0},
            {15, characterData.faceFeatures.chinLength or 0.0},
            {16, characterData.faceFeatures.chinPosition or 0.0},
            {17, characterData.faceFeatures.chinWidth or 0.0},
            {18, characterData.faceFeatures.chinShape or 0.0},
            {19, characterData.faceFeatures.neckWidth or 0.0}
        }
        
        for _, feature in ipairs(features) do
            SetPedFaceFeature(ped, feature[1], feature[2])
        end
    end

    -- Set overlays (beard, eyebrows, makeup, etc.)
    local overlays = {
        {1, characterData.beard or -1, characterData.beardOpacity or 1.0, characterData.beardColor or 0, characterData.beardColor or 0},
        {2, characterData.eyebrows or -1, characterData.eyebrowsOpacity or 1.0, characterData.eyebrowsColor or 0, characterData.eyebrowsColor or 0},
        {5, characterData.blush or -1, characterData.blushOpacity or 0.0, characterData.blushColor or 0, characterData.blushColor or 0},
        {8, characterData.lipstick or -1, characterData.lipstickOpacity or 0.0, characterData.lipstickColor or 0, characterData.lipstickColor or 0},
        {4, characterData.makeup or -1, characterData.makeupOpacity or 0.0, characterData.makeupColor or 0, characterData.makeupColor or 0},
        {3, characterData.ageing or -1, characterData.ageingOpacity or 0.0, 0, 0},
        {6, characterData.complexion or -1, characterData.complexionOpacity or 0.0, 0, 0},
        {7, characterData.sundamage or -1, characterData.sundamageOpacity or 0.0, 0, 0},
        {9, characterData.freckles or -1, characterData.frecklesOpacity or 0.0, 0, 0},
        {0, characterData.bodyBlemishes or -1, characterData.bodyBlemishesOpacity or 0.0, 0, 0},
        {10, characterData.chesthair or -1, characterData.chesthairOpacity or 0.0, characterData.chesthairColor or 0, characterData.chesthairColor or 0},
        {11, characterData.addBodyBlemishes or -1, characterData.addBodyBlemishesOpacity or 0.0, 0, 0},
        {12, characterData.moles or -1, characterData.molesOpacity or 0.0, 0, 0}
    }

    for _, overlay in ipairs(overlays) do
        if overlay[2] ~= -1 then
            SetPedHeadOverlay(ped, overlay[1], overlay[2], overlay[3])
            if overlay[4] ~= 0 or overlay[5] ~= 0 then
                SetPedHeadOverlayColor(ped, overlay[1], 1, overlay[4], overlay[5])
            end
        else
            SetPedHeadOverlay(ped, overlay[1], 255, 0.0)
        end
    end

    -- Set eye color
    SetPedEyeColor(ped, characterData.eyeColor or 0)

    -- Apply components (clothing)
    if characterData.components then
        for componentId, component in pairs(characterData.components) do
            SetPedComponentVariation(ped, tonumber(componentId), component.drawable, component.texture, 0)
        end
    end

    -- Apply props (accessories)
    if characterData.props then
        for propId, prop in pairs(characterData.props) do
            if prop.drawable == -1 then
                ClearPedProp(ped, tonumber(propId))
            else
                SetPedPropIndex(ped, tonumber(propId), prop.drawable, prop.texture, true)
            end
        end
    end

    -- Apply tattoos
    if characterData.tattoos then
        ClearPedDecorations(ped)
        for _, tattoo in ipairs(characterData.tattoos) do
            AddPedDecorationFromHashes(ped, GetHashKey(tattoo.collection), GetHashKey(tattoo.name))
        end
    end

    return true
end

function GetCurrentCharacterData(ped)
    if not ped or not DoesEntityExist(ped) then
        return nil
    end

    local characterData = GetDefaultCharacterData()
    
    -- Get basic appearance (this is simplified - in a real implementation you'd need to extract all current values)
    -- For now, we'll use the current character data or defaults
    return currentCharacterData
end

-- =========================
-- Camera Management
-- =========================

function CreateEditorCamera(mode)
    if editorCamera then
        DestroyCam(editorCamera, false)
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    editorCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    
    if mode == "face" then
        SetCamCoord(editorCamera, coords.x + 0.5, coords.y + 0.5, coords.z + 0.6)
        PointCamAtPedBone(editorCamera, ped, 31086, 0.0, 0.0, 0.0, true)
    elseif mode == "body" then
        SetCamCoord(editorCamera, coords.x + 1.0, coords.y + 1.0, coords.z + 0.2)
        PointCamAtEntity(editorCamera, ped, 0.0, 0.0, 0.0, true)
    else -- full
        SetCamCoord(editorCamera, coords.x + 2.0, coords.y + 2.0, coords.z + 0.0)
        PointCamAtEntity(editorCamera, ped, 0.0, 0.0, -0.5, true)
    end

    SetCamActive(editorCamera, true)
    RenderScriptCams(true, true, 1000, true, true)
    currentCameraMode = mode
end

function DestroyCameraEditor()
    if editorCamera then
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(editorCamera, false)
        editorCamera = nil
    end
end

-- =========================
-- Character Editor Core Functions
-- =========================

function OpenCharacterEditor(role, characterSlot)
    if isInCharacterEditor then
        return
    end

    currentRole = role or "cop"
    currentCharacterSlot = characterSlot or 1
    
    -- Store original player data
    local ped = PlayerPedId()
    originalPlayerData = GetCurrentCharacterData(ped)
    
    -- Load character data for the slot
    local characterKey = currentRole .. "_" .. currentCharacterSlot
    if playerCharacters[characterKey] then
        currentCharacterData = playerCharacters[characterKey]
    else
        currentCharacterData = GetDefaultCharacterData()
        -- Set appropriate model based on role and gender preference
        currentCharacterData.model = "mp_m_freemode_01" -- Default male, can be changed in editor
    end

    -- Teleport to character editor location
    local editorPos = Config.CharacterEditor.editorLocation
    SetEntityCoords(ped, editorPos.x, editorPos.y, editorPos.z, false, false, false, true)
    SetEntityHeading(ped, 0.0)
    
    -- Apply current character data
    ApplyCharacterData(currentCharacterData, ped)
    
    -- Set up camera
    CreateEditorCamera("face")
    
    -- Freeze player
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    
    -- Show UI using main UI
    isInCharacterEditor = true
    editorUI.isVisible = true
    
    SetNuiFocus(true, true)
    
    -- Open character editor in main UI
    SendNUIMessage({
        action = 'openCharacterEditor',
        role = currentRole,
        characterSlot = currentCharacterSlot,
        characterData = currentCharacterData,
        uniformPresets = Config.CharacterEditor.uniformPresets[currentRole] or {},
        customizationRanges = Config.CharacterEditor.customization,
        playerCharacters = playerCharacters
    })
    
    print("[CNR_CHARACTER_EDITOR] Opened character editor for " .. currentRole .. " slot " .. currentCharacterSlot)
end

function CloseCharacterEditor(save)
    if not isInCharacterEditor then
        return
    end

    local ped = PlayerPedId()
    
    if save then
        -- Save current character data
        local characterKey = currentRole .. "_" .. currentCharacterSlot
        playerCharacters[characterKey] = currentCharacterData
        TriggerServerEvent('cnr:saveCharacterData', characterKey, currentCharacterData)
        ShowNotification("Character saved successfully!")
    else
        -- Restore original appearance
        if originalPlayerData then
            ApplyCharacterData(originalPlayerData, ped)
        end
        ShowNotification("Character editor closed without saving")
    end
    
    -- Cleanup
    DestroyCameraEditor()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    
    -- Return to spawn location
    if currentRole and Config.SpawnPoints[currentRole] then
        local spawnPoint = Config.SpawnPoints[currentRole]
        SetEntityCoords(ped, spawnPoint.x, spawnPoint.y, spawnPoint.z, false, false, false, true)
    end
    
    -- Hide UI
    isInCharacterEditor = false
    editorUI.isVisible = false
    previewingUniform = false
    currentUniformPreset = nil
    
    -- Close character editor
    SendNUIMessage({
        action = 'closeCharacterEditor'
    })
    
    SetNuiFocus(false, false)
    
    print("[CNR_CHARACTER_EDITOR] Closed character editor")
end

function UpdateCharacterFeature(category, feature, value)
    if not isInCharacterEditor then
        return
    end

    local ped = PlayerPedId()
    
    if category == "faceFeatures" then
        if not currentCharacterData.faceFeatures then
            currentCharacterData.faceFeatures = {}
        end
        currentCharacterData.faceFeatures[feature] = value
        
        -- Apply face feature immediately
        local featureMap = {
            noseWidth = 0, noseHeight = 1, noseLength = 2, noseBridge = 3, noseTip = 4, noseShift = 5,
            browHeight = 6, browWidth = 7, cheekboneHeight = 8, cheekboneWidth = 9, cheeksWidth = 10,
            eyesOpening = 11, lipsThickness = 12, jawWidth = 13, jawHeight = 14, chinLength = 15,
            chinPosition = 16, chinWidth = 17, chinShape = 18, neckWidth = 19
        }
        
        if featureMap[feature] then
            SetPedFaceFeature(ped, featureMap[feature], value)
        end
    else
        currentCharacterData[feature] = value
        
        -- Apply specific changes immediately
        if feature == "hair" then
            SetPedComponentVariation(ped, 2, value, 0, 0)
        elseif feature == "hairColor" then
            SetPedHairColor(ped, value, currentCharacterData.hairHighlight or 0)
        elseif feature == "hairHighlight" then
            SetPedHairColor(ped, currentCharacterData.hairColor or 0, value)
        elseif feature == "eyeColor" then
            SetPedEyeColor(ped, value)
        else
            -- For overlays and other complex features, reapply all character data
            ApplyCharacterData(currentCharacterData, ped)
        end
    end
end

function PreviewUniformPreset(presetIndex)
    if not isInCharacterEditor or not currentRole then
        return
    end

    local presets = Config.CharacterEditor.uniformPresets[currentRole]
    if not presets or not presets[presetIndex] then
        return
    end

    local preset = presets[presetIndex]
    local ped = PlayerPedId()
    
    -- Store current clothing if not already previewing
    if not previewingUniform then
        currentCharacterData.originalComponents = {}
        currentCharacterData.originalProps = {}
        
        for i = 0, 11 do
            currentCharacterData.originalComponents[i] = {
                drawable = GetPedDrawableVariation(ped, i),
                texture = GetPedTextureVariation(ped, i)
            }
        end
        
        for i = 0, 7 do
            if GetPedPropIndex(ped, i) ~= -1 then
                currentCharacterData.originalProps[i] = {
                    drawable = GetPedPropIndex(ped, i),
                    texture = GetPedPropTextureIndex(ped, i)
                }
            else
                currentCharacterData.originalProps[i] = { drawable = -1, texture = 0 }
            end
        end
    end
    
    -- Apply preset components
    if preset.components then
        for componentId, component in pairs(preset.components) do
            SetPedComponentVariation(ped, tonumber(componentId), component.drawable, component.texture, 0)
        end
    end
    
    -- Apply preset props
    if preset.props then
        for propId, prop in pairs(preset.props) do
            if prop.drawable == -1 then
                ClearPedProp(ped, tonumber(propId))
            else
                SetPedPropIndex(ped, tonumber(propId), prop.drawable, prop.texture, true)
            end
        end
    end
    
    previewingUniform = true
    currentUniformPreset = presetIndex
    
    ShowNotification("Previewing: " .. preset.name)
end

function ApplyUniformPreset(presetIndex)
    if not isInCharacterEditor or not currentRole then
        return
    end

    local presets = Config.CharacterEditor.uniformPresets[currentRole]
    if not presets or not presets[presetIndex] then
        return
    end

    local preset = presets[presetIndex]
    
    -- Save preset to character data
    currentCharacterData.components = {}
    currentCharacterData.props = {}
    
    if preset.components then
        for componentId, component in pairs(preset.components) do
            currentCharacterData.components[componentId] = {
                drawable = component.drawable,
                texture = component.texture
            }
        end
    end
    
    if preset.props then
        for propId, prop in pairs(preset.props) do
            currentCharacterData.props[propId] = {
                drawable = prop.drawable,
                texture = prop.texture
            }
        end
    end
    
    previewingUniform = false
    currentUniformPreset = nil
    
    ShowNotification("Applied uniform: " .. preset.name)
end

function CancelUniformPreview()
    if not previewingUniform or not isInCharacterEditor then
        return
    end

    local ped = PlayerPedId()
    
    -- Restore original clothing
    if currentCharacterData.originalComponents then
        for componentId, component in pairs(currentCharacterData.originalComponents) do
            SetPedComponentVariation(ped, tonumber(componentId), component.drawable, component.texture, 0)
        end
    end
    
    if currentCharacterData.originalProps then
        for propId, prop in pairs(currentCharacterData.originalProps) do
            if prop.drawable == -1 then
                ClearPedProp(ped, tonumber(propId))
            else
                SetPedPropIndex(ped, tonumber(propId), prop.drawable, prop.texture, true)
            end
        end
    end
    
    previewingUniform = false
    currentUniformPreset = nil
    
    ShowNotification("Uniform preview cancelled")
end

-- =========================
-- Event Handlers
-- =========================

RegisterNetEvent('cnr:openCharacterEditor')
AddEventHandler('cnr:openCharacterEditor', function(role, characterSlot)
    OpenCharacterEditor(role, characterSlot)
end)

RegisterNetEvent('cnr:loadedPlayerCharacters')
AddEventHandler('cnr:loadedPlayerCharacters', function(characters)
    playerCharacters = characters or {}
    print("[CNR_CHARACTER_EDITOR] Loaded player characters")
end)

RegisterNetEvent('cnr:applyCharacterData')
AddEventHandler('cnr:applyCharacterData', function(characterData)
    local ped = PlayerPedId()
    ApplyCharacterData(characterData, ped)
end)

-- =========================
-- NUI Callbacks
-- =========================

RegisterNUICallback('characterEditor_updateFeature', function(data, cb)
    if data.category and data.feature and data.value ~= nil then
        UpdateCharacterFeature(data.category, data.feature, data.value)
    end
    cb({success = true})
end)

RegisterNUICallback('characterEditor_previewUniform', function(data, cb)
    if data.presetIndex then
        PreviewUniformPreset(data.presetIndex)
    end
    cb({success = true})
end)

RegisterNUICallback('characterEditor_applyUniform', function(data, cb)
    if data.presetIndex then
        ApplyUniformPreset(data.presetIndex)
    end
    cb({success = true})
end)

RegisterNUICallback('characterEditor_cancelUniformPreview', function(data, cb)
    CancelUniformPreview()
    cb({success = true})
end)

RegisterNUICallback('characterEditor_changeCamera', function(data, cb)
    if data.mode then
        CreateEditorCamera(data.mode)
    end
    cb({success = true})
end)

RegisterNUICallback('characterEditor_rotateCharacter', function(data, cb)
    if data.direction then
        local ped = PlayerPedId()
        local currentHeading = GetEntityHeading(ped)
        local newHeading = currentHeading + (data.direction == "left" and -15 or 15)
        SetEntityHeading(ped, newHeading)
    end
    cb({success = true})
end)

RegisterNUICallback('characterEditor_switchGender', function(data, cb)
    if data.gender then
        local ped = PlayerPedId()
        local newModel = data.gender == "male" and "mp_m_freemode_01" or "mp_f_freemode_01"
        
        currentCharacterData.model = newModel
        
        -- Change player model
        RequestModel(GetHashKey(newModel))
        while not HasModelLoaded(GetHashKey(newModel)) do
            Citizen.Wait(0)
        end
        
        SetPlayerModel(PlayerId(), GetHashKey(newModel))
        SetModelAsNoLongerNeeded(GetHashKey(newModel))
        
        -- Reapply character data to new model
        Citizen.Wait(100)
        local newPed = PlayerPedId()
        ApplyCharacterData(currentCharacterData, newPed)
        
        -- Update camera
        CreateEditorCamera(currentCameraMode)
    end
    cb({success = true})
end)

RegisterNUICallback('characterEditor_save', function(data, cb)
    CloseCharacterEditor(true)
    cb({success = true})
end)

RegisterNUICallback('characterEditor_cancel', function(data, cb)
    CloseCharacterEditor(false)
    cb({success = true})
end)

RegisterNUICallback('characterEditor_loadCharacter', function(data, cb)
    if data.characterKey and playerCharacters[data.characterKey] then
        currentCharacterData = playerCharacters[data.characterKey]
        local ped = PlayerPedId()
        ApplyCharacterData(currentCharacterData, ped)
        ShowNotification("Character loaded")
    end
    cb({success = true})
end)

RegisterNUICallback('characterEditor_deleteCharacter', function(data, cb)
    if data.characterKey then
        playerCharacters[data.characterKey] = nil
        TriggerServerEvent('cnr:deleteCharacterData', data.characterKey)
        ShowNotification("Character deleted")
    end
    cb({success = true})
end)

RegisterNUICallback('openCharacterEditor', function(data, cb)
    if data.role and (data.role == "cop" or data.role == "robber") then
        OpenCharacterEditor(data.role, data.characterSlot or 1)
        cb({success = true})
    else
        cb({success = false, error = "Invalid role specified"})
    end
end)

-- =========================
-- Keybind Handler
-- =========================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if IsControlJustPressed(0, Config.Keybinds.openCharacterEditor) then
            if not isInCharacterEditor and role and (role == "cop" or role == "robber") then
                OpenCharacterEditor(role, 1)
            end
        end
        
        -- ESC key to close character editor
        if isInCharacterEditor and IsControlJustPressed(0, 322) then -- ESC key
            CloseCharacterEditor(false)
        end
    end
end)

-- =========================
-- Utility Functions
-- =========================

function ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
end

-- Export functions for other scripts
exports('OpenCharacterEditor', OpenCharacterEditor)
exports('ApplyCharacterData', ApplyCharacterData)
exports('GetCurrentCharacterData', GetCurrentCharacterData)

-- Test command for character editor
RegisterCommand('chareditor', function(source, args, rawCommand)
    local role = args[1] or "cop"
    local slot = tonumber(args[2]) or 1
    
    if role ~= "cop" and role ~= "robber" then
        ShowNotification("~r~Invalid role. Use 'cop' or 'robber'")
        return
    end
    
    if slot < 1 or slot > 2 then
        ShowNotification("~r~Invalid slot. Use 1 or 2")
        return
    end
    
    OpenCharacterEditor(role, slot)
end, false)

TriggerEvent('chat:addSuggestion', '/chareditor', 'Open character editor', {
    { name="role", help="Role (cop/robber)" },
    { name="slot", help="Character slot (1-2)" }
})