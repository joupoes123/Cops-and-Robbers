-- ox_lib/init.lua
ox_lib = {}

-- Function to require modules within ox_lib
function ox_lib.require(moduleName)
    local path = ('ox_lib.modules.%s.init'):format(moduleName:gsub('/', '.'))
    -- In a real FiveM environment, you might use loadfile or other mechanisms
    -- For this environment, we'll assume 'require' can path correctly if files are structured.
    -- This is a simplified loader.
    local success, module = pcall(require, path)
    if success then
        return module
    else
        print(('[ox_lib] Failed to load module %s: %s'):format(moduleName, module)) -- 'module' is error message here
        -- Fallback for environments where nested require might not work as expected with pcall
        -- or for very simple stubbing.
        if moduleName == 'json' then
            print('[ox_lib] Attempting to return basic JSON stub directly for module: ' .. moduleName)
            return {
                encode = function(tbl) return "{\"stubbed_encode\":true}" end,
                decode = function(str) return {stubbed_decode = true} end
            }
        end
        return nil
    end
end

-- Pre-load or make available common modules like json
-- This ensures that scripts doing `require('json')` can find it if ox_lib is set up as the provider.
if not json then -- Check if 'json' is already globally available (e.g. by another resource or built-in)
    -- Attempt to load json module via ox_lib's system
    local ox_json_module = ox_lib.require('json')
    if ox_json_module then
        json = ox_json_module -- Make it globally available as 'json'
        -- print('[ox_lib] JSON module loaded via ox_lib.require and assigned globally.')
    else
        print('[ox_lib] Warning: JSON module failed to load via ox_lib.require. json.* functions might not be available.')
    end
end

return ox_lib
