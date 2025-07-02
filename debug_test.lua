-- Debug test file to verify resource loading
print("[CNR_DEBUG_TEST] Debug test file loaded - Resource is loading new code!")

-- Test if IsPlayerAdmin function exists
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    if IsPlayerAdmin then
        print("[CNR_DEBUG_TEST] IsPlayerAdmin function is accessible!")
    else
        print("[CNR_DEBUG_TEST] ERROR: IsPlayerAdmin function is NOT accessible!")
    end
end)