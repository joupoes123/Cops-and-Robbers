-- ox_lib/modules/json/init.lua
-- Minimalistic JSON stub for compatibility.

local json_module = {}

-- Placeholder for json.encode
-- A real implementation would convert a Lua table into a JSON string.
function json_module.encode(data, options)
    if data == nil then
        return "null"
    end
    local type = type(data)
    if type == "string" then
        -- Basic string escaping (very incomplete for a real JSON encoder)
        return "\"" .. data:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r") .. "\""
    elseif type == "number" or type == "boolean" then
        return tostring(data)
    elseif type == "table" then
        -- Check if it's an array or object
        local is_array = true
        local count = 0
        for _ in pairs(data) do
            count = count + 1
        end
        if count > 0 then -- Only check for sequential keys if not empty
            for i = 1, count do
                if data[i] == nil then
                    is_array = false
                    break
                end
            end
        else -- Empty table, could be {} or []
           if options and options.empty_as_array then is_array = true else is_array = false end
           -- Lua `json.encode({}, { indent = true })` often results in `{\n}` but `json.encode({})` can be `{}`.
           -- `json.encode(#foo == 0 and {} or foo)` is a common pattern for arrays.
           -- For simplicity here, empty table will be an object unless `empty_as_array` is true.
        end


        local parts = {}
        if is_array then
            for i = 1, count do
                table.insert(parts, json_module.encode(data[i], options))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else -- Object
            for k, v in pairs(data) do
                table.insert(parts, json_module.encode(tostring(k), options) .. ":" .. json_module.encode(v, options))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        print("[ox_lib] json.encode: Unsupported data type: " .. type)
        return "null" -- Or throw error
    end
end

-- Placeholder for json.decode
-- A real implementation would parse a JSON string into a Lua table.
function json_module.decode(json_string)
    if type(json_string) ~= "string" then
        -- print("[ox_lib] json.decode: Input must be a string, got " .. type(json_string))
        return nil -- Or throw error
    end

    -- Very basic stubbing for expected structures.
    if json_string == "{}" or json_string == "{\n}" then return {} end
    if json_string == "[]" then return {} end -- Represent JSON array as empty table too for simplicity here.

    -- Example: if bans.json is expected to be `{"steam:xxx": {"reason": "test"}}`
    -- This basic stub won't parse it. It's just to prevent `require` errors.
    -- A slightly more advanced stub could look for specific patterns if needed for testing.
    -- For instance, if player data is `{"money":100}`, we could try to match that.
    -- print("[ox_lib] json.decode: Returning generic empty table for string: ", json_string)
    if json_string:match("^%s*{%s*%S*%s*}%s*$") then -- Crude check for some object-like string
        -- This is not a real parser. It's a placeholder.
        -- If specific test data is loaded, this would need to be smarter or a real parser used.
        if json_string:match("\"money\"") then
            return { money = 2500, inventory = {}, weapons = {} } -- Default player data like structure
        elseif json_string:match("\"reason\"") then
            return { ["steam:placeholder"] = { reason = "Stubbed Ban", timestamp = 0 } } -- Default ban like structure
        end
    end

    return {} -- Default to an empty table for any other JSON string.
end

return json_module
