local loadedAnimDicts = {}

local function debugPrint(msg, ...)
    if Config.debug then
        print(string.format(msg, ...))
    end
end

local function loadAnimDict(dict)
    if loadedAnimDicts[dict] then return true end
    
    RequestAnimDict(dict)
    local startTime = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - startTime > 5000 then 
            debugPrint("^1[ERROR] Animation dictionary failed to load: %s", dict)
            return false
        end
        Wait(10)
    end
    loadedAnimDicts[dict] = true
    return true
end

local function playAnimation(ped, dict, anim, duration)
    if not dict or dict == "" or not loadAnimDict(dict) then return end
    debugPrint("^2[DEBUG] Playing animation: %s from dict: %s", anim, dict)
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, 49, 0, false, false, false)
    Wait(duration)
end

local function isHoldingBaton()
    local ped = PlayerPedId()
    local _, currentWeapon = GetCurrentPedWeapon(ped, true)
    for _, weapon in ipairs(Config.weapons) do
        if currentWeapon == GetHashKey(weapon) then
            debugPrint("^2[DEBUG] Player is holding a baton.")
            return true
        end
    end
    debugPrint("^2[DEBUG] Player is NOT holding a baton.")
    return false
end

local function isWindowBroken(vehicle, windowIndex)
    debugPrint("^2[DEBUG] Checking if window %d is broken: %s", windowIndex, tostring(broken))
    return not IsVehicleWindowIntact(vehicle, windowIndex)
end

local function canDragPlayerOut(vehicle)
    local driver = GetPedInVehicleSeat(vehicle, -1)
    debugPrint("^2[DEBUG] Can drag driver out: %s", tostring(canDrag))
    return driver ~= 0 and isWindowBroken(vehicle, 0)
end

local boneToDoorIndex = {
    ["window_lf"] = 0,  -- Driver Front Window
    ["window_rf"] = 1,  -- Passenger Front Window
    ["window_lr"] = 2,  -- Driver Rear Window
    ["window_rr"] = 3   -- Passenger Rear Window
}

local function dragDriverOut(vehicle)
    debugPrint("^2[DEBUG] Attempting to drag driver out.")
    if not canDragPlayerOut(vehicle) then
        debugPrint("^1[ERROR] Cannot drag driver out. Window must be broken.")
        if Config.useNotify then
            TriggerEvent('okokNotify:Alert', -1, "Error", "You need to break a window first!", 3000, 'info', Config.notifaudio)
        else
            TriggerEvent("chat:addMessage", {args = {"^1[ERROR] You need to break a window first!"}})
        end
        return
    end

    local ped = PlayerPedId()
    debugPrint("^2[DEBUG] Tasking player to enter vehicle to drag driver out.")
    TaskEnterVehicle(ped, vehicle, 5000, 0, 1.0, 8, 0)
    Wait(2700) -- Allow time to pull player out, but not get in vehicle
    debugPrint("^2[DEBUG] Clearing player tasks to prevent full entry into vehicle.")
    ClearPedTasksImmediately(ped)
end

local function breakCarWindow(vehicle, bone)
    local weapon = GetCurrentPedWeapon(PlayerPedId())
    local windowIndex = boneToDoorIndex[bone]
    debugPrint("^2[DEBUG] Attempting to break window: %s", bone)
    if not windowIndex then
        debugPrint("^1[ERROR] Invalid window bone: %s", bone)
        if Config.useNotify then
            TriggerEvent('okokNotify:Alert', -1, "Error", "No valid window found!", 3000, 'error', Config.notifaudio)
        else
            TriggerEvent("chat:addMessage", {args = {"^1[ERROR] No valid window found!"}})
        end
        return
    end

    if vehicle and isHoldingBaton(weapon) then
        local playerPed = PlayerPedId()
        local coords = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, bone))
        debugPrint("^2[DEBUG] Moving to window position to break.")
        TaskGoStraightToCoord(playerPed, coords.x, coords.y, coords.z, 1.0, -1, 0.0, 0.0)
        Wait(1500) -- Allow time to move to position
        TaskTurnPedToFaceEntity(playerPed, vehicle, 500)
        Wait(500) -- Ensure facing the window before breaking

        debugPrint("^2[DEBUG] Playing animation to break window.")
        ClearPedTasksImmediately(playerPed)
        Wait(50)
        playAnimation(playerPed, "melee@unarmed@streamed_variations", "heavy_punch_c_var_1", 1000)
        Wait(0)

        -- **Break the window on the local client immediately**
        debugPrint("^2[DEBUG] Breaking window on client and syncing with server.")
        SmashVehicleWindow(vehicle, windowIndex)

        -- **Sync with all players**
        TriggerServerEvent('DragOut:breakWindow', NetworkGetNetworkIdFromEntity(vehicle), windowIndex)
    else
        debugPrint("^1[ERROR] Cannot break window. Baton required.")
        if Config.useNotify then
            TriggerEvent('okokNotify:Alert', -1, "Error", "You need a baton to break the window!", 3000, 'error', Config.notifaudio)
        else
            TriggerEvent("chat:addMessage", {args = {"^1[ERROR] You need a baton to break the window!"}})
        end
    end
end


local windows = {
    { name = "window_lf", label = "Break Driver Window" },
    { name = "window_rf", label = "Break Passenger Window" },
    { name = "window_lr", label = "Break Rear Driver Window" },
    { name = "window_rr", label = "Break Rear Passenger Window" }
}

CreateThread(function()
    while not exports.ox_target do Wait(500) end

    for _, window in ipairs(windows) do
        exports.ox_target:addGlobalVehicle({
            name = "break_window_" .. window.name,
            icon = "fas fa-hammer",
            label = window.label,
            bones = { window.name },
            distance = 2.0,
            canInteract = function(entity)
                return not isWindowBroken(entity, boneToDoorIndex[window.name])
            end,
            onSelect = function(data)
                breakCarWindow(data.entity, window.name)
            end
        })
    end

    exports.ox_target:addGlobalVehicle({
        name = "drag_driver_out",
        icon = "fas fa-user-slash",
        label = "Drag Driver Out",
        distance = 2.0,
        canInteract = function(entity)
            return canDragPlayerOut(entity)
        end,
        onSelect = function(data)
            dragDriverOut(data.entity)
        end
    })
end)

RegisterNetEvent('DragOut:syncBreakWindow')
AddEventHandler('DragOut:syncBreakWindow', function(vehicleNetId, doorIndex)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    debugPrint("^2[DEBUG] Received sync event for breaking window %d on vehicle %d", doorIndex, vehicleNetId)
    if DoesEntityExist(vehicle) then
        SmashVehicleWindow(vehicle, doorIndex)
    end
end)

if Config.debug then
    RegisterCommand("animtest", function()
        local ped = PlayerPedId()
        debugPrint("^2[DEBUG] Running animation test command.")
        playAnimation(ped, "melee@unarmed@streamed_core_fps", "running_punch_no_target", 3000)
    end, false)
end
