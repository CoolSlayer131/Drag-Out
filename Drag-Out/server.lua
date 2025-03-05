local function hasPermission(source)
    local hasPerm = IsPlayerAceAllowed(source, Config.ClockedOn)
    print(("[DEBUG] Player %s permission check: %s"):format(source, tostring(hasPerm))) -- Ensure boolean is string-safe
    return hasPerm
end

RegisterNetEvent('DragOut:breakWindow', function(vehicleNetId, doorIndex)
    local playerId = source -- Fix shadowing issue (avoid reusing `source` inside the function)

    if not hasPermission(playerId) then
        TriggerClientEvent("chat:addMessage", playerId, { args = { "^1[ERROR]^7 You don’t have permission to break windows!" } })
        print(("^1[ERROR] Player %s attempted to break a window without permission.^7"):format(playerId))
        return
    end

    if not vehicleNetId or not doorIndex or type(doorIndex) ~= "number" or doorIndex < 0 or doorIndex > 3 then
        print(("^1[ERROR] Invalid parameters received in DragOut:breakWindow (Player: %s)^7"):format(playerId))
        return
    end

    -- Sync breaking window with all clients
    TriggerClientEvent('DragOut:syncBreakWindow', -1, vehicleNetId, doorIndex)
    print(("^2[LOG]^7 Player %s broke window %d on vehicle %d."):format(playerId, doorIndex, vehicleNetId))
end)

RegisterNetEvent('DragOut:dragDriverOut', function(vehicleNetId, driverNetId)
    local playerId = source -- Fix shadowing issue

    if not hasPermission(playerId) then
        TriggerClientEvent("chat:addMessage", playerId, { args = { "^1[ERROR]^7 You don’t have permission to drag drivers out!" } })
        print(("^1[ERROR] Player %s attempted to drag a driver out without permission.^7"):format(playerId))
        return
    end

    if not vehicleNetId or not driverNetId or type(driverNetId) ~= "number" then
        print(("^1[ERROR] Invalid parameters received in DragOut:dragDriverOut (Player: %s)^7"):format(playerId))
        return
    end

    -- Sync dragging the driver out with all clients
    TriggerClientEvent('DragOut:syncDragDriverOut', -1, vehicleNetId, driverNetId)
    print(("^2[LOG]^7 Player %s dragged out driver %d from vehicle %d."):format(playerId, driverNetId, vehicleNetId))
end)
