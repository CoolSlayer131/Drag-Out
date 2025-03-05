local function debugPrint(msg)
    if Config.debug then
        print(msg)
    end
end

local function playAnimation(ped, dict, anim, duration)
    if not dict or dict == "" then return end

    RequestAnimDict(dict)
    local startTime = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - startTime > 5000 then 
            debugPrint("^1[ERROR] Animation dictionary failed to load:", dict)
            return 
        end
        Wait(10)
    end

    debugPrint("^2[DEBUG] Playing animation:", anim, "from dict:", dict) -- Debugging output
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, 49, 0, false, false, false)
    Wait(duration) -- Ensure animation plays fully
end

local function isHoldingBaton(weapon)
    for _, v in ipairs(Config.weapons) do
        GetCurrentPedWeapon(PlayerPedId()) -- Ensure weapon is updated
        if v == weapon then
            return true
        end
    end
    return false
end

-- Window bones mapping
local boneToDoorIndex = {
    ["window_lf"] = 0,  -- Driver Front Window
    ["window_rf"] = 1,  -- Passenger Front Window
    ["window_lr"] = 2,  -- Driver Rear Window
    ["window_rr"] = 3   -- Passenger Rear Window
}


local function canInteractWithWindow(entity, bone)
    local doorIndex = boneToDoorIndex[bone]
    return doorIndex and IsVehicleWindowIntact(entity, doorIndex)
end

local function canDragPlayerOut(entity, bone)
    local boneName = boneToDoorIndex[tostring(bone)]
    
    debugPrint("^3[DEBUG] Bone received:", bone, "Mapped Bone Name:", boneName)

    if not boneName then return false end

    local doorIndex = boneToDoorIndex[bone] or nil
    debugPrint("^3[DEBUG] Door Index Mapped:", doorIndex)

    local driver = GetPedInVehicleSeat(entity, -1)
    debugPrint("^3[DEBUG] Driver Ped:", driver, "Window Intact:", IsVehicleWindowIntact(entity, doorIndex))

    return doorIndex ~= nil and driver ~= 0 and not IsVehicleWindowIntact(entity, doorIndex)
end


local function breakCarWindow(vehicle, bone)
    local weapon = GetCurrentPedWeapon(PlayerPedId())
    local doorIndex = boneToDoorIndex[bone]
    if not doorIndex then
        TriggerEvent("chat:addMessage", {args = {"^1[ERROR] No valid window found!"}})
        return
    end

    if vehicle and isHoldingBaton(weapon) then
        local Ped = PlayerPedId()
        ClearPedTasksImmediately(Ped) -- Clears any running animations
        Wait(50)
        playAnimation(Ped, "melee@unarmed@streamed_variations", "heavy_punch_c_var_1", 1000)
        Wait(0)


        -- **Break the window on the local client immediately**
        SmashVehicleWindow(vehicle, doorIndex)

        -- **Sync with all players**
        TriggerServerEvent('DragOut:breakWindow', NetworkGetNetworkIdFromEntity(vehicle), doorIndex)
    else
        TriggerEvent("chat:addMessage", {args = {"^1[ERROR] You need a baton to break the window!"}})
    end
end

local function dragDriverOut(vehicle, bone)
    local doorIndex = boneToDoorIndex[bone]

    if not doorIndex then
        TriggerEvent("chat:addMessage", {args = {"^1[ERROR] No valid door found!"}})
        return
    end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    
    if driver ~= 0 and not IsPedAPlayer(driver) then
        -- Force NPC out immediately
        TaskLeaveVehicle(driver, vehicle, 0)
        Wait(500) -- Give some time to exit
        ClearPedTasksImmediately(driver) -- Ensure AI stops any animations/tasks
        return
    end

    -- If it's a player, follow normal process
    if not IsVehicleWindowIntact(vehicle, doorIndex) then
        local ped = PlayerPedId()
        TaskEnterVehicle(ped, vehicle, 5000, doorIndex, 2.0, 8, 0)

        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 1000 do
            if IsPedInVehicle(ped, vehicle, false) then
                ClearPedTasksImmediately(ped)
                return
            end
            Wait(100)
        end
    else
        TriggerEvent("chat:addMessage", {args = {"^1[ERROR] You need to break the window first!"}})
    end
end


CreateThread(function()
    while not exports.ox_target do Wait(500) end

    local windows = {
        { name = "window_lf", label = "Break Driver Window" },
        { name = "window_rf", label = "Break Passenger Window" },
        { name = "window_lr", label = "Break Rear Driver Window" },
        { name = "window_rr", label = "Break Rear Passenger Window" }
    }

    -- Add each window interaction separately
    for _, window in ipairs(windows) do
        exports.ox_target:addGlobalVehicle({
            name = "break_window_" .. window.name,
            icon = "fas fa-hammer",
            label = window.label,
            bones = { window.name },
            distance = 2.0,
            canInteract = function(entity)
                return canInteractWithWindow(entity, window.name)
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
        bones = { "window_lf", "window_rf", "window_lr", "window_rr" }, -- Add valid window bones
        distance = 2.0,
        canInteract = function(entity, bone)
            print("Entity:", entity, "Bone:", bone) -- Debugging output
            return canDragPlayerOut(entity, bone)
        end,
        onSelect = function(data)
            print("Dragging driver out, Bone:", data.bone) -- Debugging output
            if data.bone then
                dragDriverOut(data.entity, data.bone)
            else
                TriggerEvent("chat:addMessage", {args = {"^1[ERROR] No valid bone detected!"}})
            end
        end
    })
    
    
end)

-- **Fix: Make sure the window break syncs for ALL players**
RegisterNetEvent('DragOut:syncBreakWindow')
AddEventHandler('DragOut:syncBreakWindow', function(vehicleNetId, doorIndex)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if DoesEntityExist(vehicle) then
        SmashVehicleWindow(vehicle, doorIndex)
    end
end)

if Config.debug then
    RegisterCommand("animtest", function()
        local ped = PlayerPedId()
        playAnimation(ped, "melee@unarmed@streamed_core_fps", "running_punch_no_target", 3000)
    end, false)
end