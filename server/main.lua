local QBCore = exports['qbx-core']:GetCoreObject()

local function isPlayerNearBus(src)
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    for _, v in pairs(Config.NPCLocations.Locations) do
        local dist = #(coords - vec3(v.x, v.y, v.z))
        if dist < 20 then
            return true
        end
    end
    return false
end

RegisterNetEvent('qb-busjob:server:NpcPay', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= "bus" or not isPlayerNearBus(src) then return DropPlayer(src, 'Attempting to exploit') end

    local payment = math.random(15, 25)
    if math.random(1, 100) < Config.BonusChance then
        payment += math.random(10, 20)
    end
    Player.Functions.AddMoney('cash', payment)
end)
