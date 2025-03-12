local function hasPermission(source)
    local hasPerm = IsPlayerAceAllowed(source, Config.ClockedOn)
    if Config.debug == true then print(("[DEBUG] Player %s permission check: %s"):format(source, tostring(hasPerm))) end -- Ensure boolean is string-safe
    return hasPerm
end

RegisterNetEvent('DragOut:breakWindow', function(vehicleNetId, doorIndex)
    local playerId = source -- Fix shadowing issue (avoid reusing `source` inside the function)

    if not hasPermission(playerId) then
        TriggerClientEvent("chat:addMessage", playerId, { args = { "^1[ERROR]^7 You don’t have permission to break windows!" } })
        if Config.debug == true then print(("^1[ERROR] Player %s attempted to break a window without permission.^7"):format(playerId)) end
        return
    end

    if not vehicleNetId or not doorIndex or type(doorIndex) ~= "number" or doorIndex < 0 or doorIndex > 3 then
        print(("^1[ERROR] Invalid parameters received in DragOut:breakWindow (Player: %s)^7"):format(playerId))
        return
    end

    -- Sync breaking window with all clients
    TriggerClientEvent('DragOut:syncBreakWindow', -1, vehicleNetId, doorIndex)
    if Config.debug == true then print(("^2[LOG]^7 Player %s broke window %d on vehicle %d."):format(playerId, doorIndex, vehicleNetId)) end
end)
