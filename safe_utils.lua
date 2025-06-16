-- Helper: Safe wrapper for FiveM's GetPlayerName native
function SafeGetPlayerName(playerId)
    if not playerId then return nil end
    local idNum = tonumber(playerId)
    if not idNum then return nil end
    local success, name = pcall(function() return GetPlayerName(tostring(idNum)) end)
    if success and name and type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end
