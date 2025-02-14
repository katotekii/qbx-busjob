-- Variables
local QBCore = exports['qbx-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local route = 1
local max = #Config.NPCLocations.Locations
local busBlip = nil
local VehicleZone
local DeliverZone
local PickupZone

local NpcData = {
    Active = false,
    LastNpc = nil,
    LastDeliver = nil,
    Npc = nil,
    NpcBlip = nil,
    DeliveryBlip = nil,
    NpcTaken = false,
    NpcDelivered = false,
    CountDown = 180
}

local BusData = {
    Active = false,
}

-- Functions
local function resetNpcTask()
    NpcData = {
        Active = false,
        LastNpc = nil,
        LastDeliver = nil,
        Npc = nil,
        NpcBlip = nil,
        DeliveryBlip = nil,
        NpcTaken = false,
        NpcDelivered = false,
    }
end

local function removeBusBlip()
    if not busBlip then return end
    RemoveBlip(busBlip)
    busBlip = nil
end

local function removeNPCBlip()
    if NpcData.DeliveryBlip then
        RemoveBlip(NpcData.DeliveryBlip)
        NpcData.DeliveryBlip = nil
    end

    if NpcData.NpcBlip then
        RemoveBlip(NpcData.NpcBlip)
        NpcData.NpcBlip = nil
    end
end

local function updateBlip()
    if table.type(PlayerData) == 'empty' or (PlayerData.job.name ~= "bus" and busBlip) then
        removeBusBlip()
        return
    end

    local coords = Config.Location
    busBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(busBlip, 513)
    SetBlipDisplay(busBlip, 4)
    SetBlipScale(busBlip, 0.6)
    SetBlipAsShortRange(busBlip, true)
    SetBlipColour(busBlip, 49)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Lang:t('info.bus_depot'))
    EndTextCommandSetBlipName(busBlip)
end

local function isPlayerVehicleABus()
    if not cache.vehicle then return false end
    local veh = GetEntityModel(cache.vehicle)

    for i = 1, #Config.AllowedVehicles, 1 do
        if veh == Config.AllowedVehicles[i].model then
            return true
        end
    end

    if veh == `dynasty` then
        return true
    end

    return false
end

local function nextStop()
    route = route <= (max - 1) and route + 1 or 1
end

local function removePed(ped)
    SetTimeout(60000, function()
        DeletePed(ped)
    end)
end

local function GetDeliveryLocation()
    nextStop()
    removeNPCBlip()
    NpcData.DeliveryBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)
    SetBlipColour(NpcData.DeliveryBlip, 3)
    SetBlipRoute(NpcData.DeliveryBlip, true)
    SetBlipRouteColour(NpcData.DeliveryBlip, 3)
    NpcData.LastDeliver = route
    local inRange = false
    local shownTextUI = false
    DeliverZone = lib.zones.sphere({
        name = "qb_busjob_bus_deliver",
        coords = vec3(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z),
        radius = 5,
        debug = Config.Debug,
        onEnter = function()
            inRange = true
            if not shownTextUI then
                lib.showTextUI(Lang:t('info.busstop_text'))
                shownTextUI = true
            end
            CreateThread(function()
                repeat
                    Wait(0)
                    if IsControlJustPressed(0, 38) then
                        TaskLeaveVehicle(NpcData.Npc, cache.vehicle, 0)
                        SetEntityAsMissionEntity(NpcData.Npc, false, true)
                        SetEntityAsNoLongerNeeded(NpcData.Npc)
                        local targetCoords = Config.NPCLocations.Locations[NpcData.LastNpc]
                        TaskGoStraightToCoord(NpcData.Npc, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)
                        QBCore.Functions.Notify(Lang:t('success.dropped_off'), 'success')
                        removeNPCBlip()
                        removePed(NpcData.Npc)
                        resetNpcTask()
                        nextStop()
                        TriggerEvent('qb-busjob:client:DoBusNpc')
                        lib.hideTextUI()
                        shownTextUI = false
                        DeliverZone:remove()
                        DeliverZone = nil
                        break
                    end
                until not inRange
            end)
        end,
        onExit = function()
            lib.hideTextUI()
            shownTextUI = false
            inRange = false
        end
    })
end

local function busGarage()
    local vehicleMenu = {}
    for _, v in pairs(Config.AllowedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            title = Lang:t('info.bus'),
            event = "qb-busjob:client:TakeVehicle",
            args = v
        }
    end
    lib.registerContext({
        id = 'qb_busjob_open_garage_context_menu',
        title = Lang:t('menu.bus_header'),
        options = vehicleMenu
    })
    lib.showContext('qb_busjob_open_garage_context_menu')
end

local function updateZone()
    if VehicleZone then
        VehicleZone:remove()
        VehicleZone = nil
    end

    if table.type(PlayerData) == 'empty' or PlayerData.job.name ~= 'bus' then return end

    local inRange = false
    local shownTextUI = false
    VehicleZone = lib.zones.sphere({
        name = "qb_busjob_bus_main",
        coords = Config.Location.xyz,
        radius = 5,
        debug = Config.Debug,
        onEnter = function()
            local inVeh = isPlayerVehicleABus()
            inRange = true
            CreateThread(function()
                repeat
                    Wait(0)
                    if not inVeh then
                        if not shownTextUI then
                            lib.showTextUI(Lang:t('info.busstop_text'))
                            shownTextUI = true
                        end
                        if IsControlJustReleased(0, 38) then
                            busGarage()
                            lib.hideTextUI()
                            shownTextUI = false
                            break
                        end
                    else
                        if not shownTextUI then
                            lib.showTextUI(Lang:t('info.bus_stop_work'))
                            shownTextUI = true
                        end
                        if IsControlJustReleased(0, 38) then
                            if not NpcData.Active or NpcData.Active and not NpcData.NpcTaken then
                                if cache.vehicle then
                                    BusData.Active = false
                                    DeleteVehicle(cache.vehicle)
                                    removeNPCBlip()
                                    lib.hideTextUI()
                                    shownTextUI = false
                                    resetNpcTask()
                                    break
                                end
                            else
                                QBCore.Functions.Notify(Lang:t('error.drop_off_passengers'), 'error')
                            end
                        end
                    end
                until not inRange
            end)
        end,
        onExit = function()
            lib.hideTextUI()
            shownTextUI = false
            inRange = false
        end
    })
end

RegisterNetEvent("qb-busjob:client:TakeVehicle", function(data)
    if BusData.Active then
        QBCore.Functions.Notify(Lang:t('error.one_bus_active'), 'error')
        return
    end

    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        SetVehicleNumberPlateText(veh, Lang:t('info.bus_plate') .. tostring(math.random(1000, 9999)))
        SetVehicleFuelLevel(veh, 100.0)
        lib.hideContext()
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true, false)
    end, data.model, Config.Location, true)
    Wait(1000)
    TriggerEvent('qb-busjob:client:DoBusNpc')
end)

-- Events
AddEventHandler('onResourceStart', function(resourceName)
    -- handles script restarts
    if GetCurrentResourceName() ~= resourceName then return end

    updateBlip()
    updateZone()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    updateBlip()
    updateZone()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    updateBlip()
    updateZone()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    updateBlip()
    updateZone()
end)

RegisterNetEvent('qb-busjob:client:DoBusNpc', function()
    if not isPlayerVehicleABus() then
        QBCore.Functions.Notify(Lang:t('error.not_in_bus'), 'error')
        return
    end

    if not NpcData.Active then
        local Gender = math.random(1, #Config.NpcSkins)
        local PedSkin = math.random(1, #Config.NpcSkins[Gender])
        local model = joaat(Config.NpcSkins[Gender][PedSkin])
        lib.requestModel(model)
        NpcData.Npc = CreatePed(3, model, Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z - 0.98, Config.NPCLocations.Locations[route].w, false, true)
        PlaceObjectOnGroundProperly(NpcData.Npc)
        FreezeEntityPosition(NpcData.Npc, true)
        removeNPCBlip()
        QBCore.Functions.Notify(Lang:t('info.goto_busstop'), 'primary')
        NpcData.NpcBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)
        SetBlipColour(NpcData.NpcBlip, 3)
        SetBlipRoute(NpcData.NpcBlip, true)
        SetBlipRouteColour(NpcData.NpcBlip, 3)
        NpcData.LastNpc = route
        NpcData.Active = true
        local inRange = false
        local shownTextUI = false
        PickupZone = lib.zones.sphere({
            name = "qb_busjob_bus_pickup",
            coords = vec3(Config.NPCLocations.Locations[route].x,
            Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z),
            radius = 5,
            debug = Config.Debug,
            onEnter = function()
                inRange = true
                if not shownTextUI then
                    lib.showTextUI(Lang:t('info.busstop_text'))
                    shownTextUI = true
                end
                CreateThread(function()
                    repeat
                        Wait(0)
                        if IsControlJustPressed(0, 38) then
                            local maxSeats, freeSeat = GetVehicleModelNumberOfSeats(GetEntityModel(cache.vehicle))

                            for i = maxSeats - 1, 0, -1 do
                                if IsVehicleSeatFree(cache.vehicle, i) then
                                    freeSeat = i
                                    break
                                end
                            end

                            if not freeSeat then return end

                            ClearPedTasksImmediately(NpcData.Npc)
                            FreezeEntityPosition(NpcData.Npc, false)
                            TaskEnterVehicle(NpcData.Npc, cache.vehicle, -1, freeSeat, 1.0, 0)
                            QBCore.Functions.Notify(Lang:t('info.goto_busstop'), 'primary')
                            removeNPCBlip()
                            GetDeliveryLocation()
                            NpcData.NpcTaken = true
                            TriggerServerEvent('qb-busjob:server:NpcPay')
                            lib.hideTextUI()
                            shownTextUI = false
                            PickupZone:remove()
                            PickupZone = nil
                            break
                        end
                    until not inRange
                end)
            end,
            onExit = function()
                lib.hideTextUI()
                shownTextUI = false
                inRange = false
            end
        })
    else
        QBCore.Functions.Notify(Lang:t('error.already_driving_bus'), 'error')
    end
end)