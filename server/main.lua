local sharedConfig = require 'config.shared'

local maxJobsPerPlayer = GetConvarInt('qbx:max_jobs_per_player', 1)

local function getClosestHall(pedCoords)
    local distance = #(pedCoords - sharedConfig.cityhalls[1].coords)
    local closest = 1
    for i = 1, #sharedConfig.cityhalls do
        local hall = sharedConfig.cityhalls[i]
        local dist = #(pedCoords - hall.coords)
        if dist < distance then
            distance = dist
            closest = i
        end
    end
    return closest
end

local function distanceCheck(source, job)
    local ped = GetPlayerPed(source)
    local pedCoords = GetEntityCoords(ped)
    local closestCityhall = getClosestHall(pedCoords)
    local cityhallCoords = sharedConfig.cityhalls[closestCityhall].coords
    if #(pedCoords - cityhallCoords) >= 20.0 or not sharedConfig.employment.jobs[job] then
        return false
    end
    return true
end

lib.callback.register('qbx_cityhall:server:requestId', function(source, item, hall)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local itemType = sharedConfig.cityhalls[hall].licenses[item]

    if itemType.item ~= 'id_card' and itemType.item ~= 'driver_license' and itemType.item ~= 'weaponlicense' then
        return exports.qbx_core:Notify(source, locale('error.invalid_type'), 'error')
    end

    if not player.Functions.RemoveMoney('cash', itemType.cost) then
        return exports.qbx_core:Notify(source, locale('error.not_enough_money'), 'error')
    end

    --exports.qbx_idcard:CreateMetaLicense(source, itemType.item)
    exports['um-idcard']:CreateMetaLicense(source, itemType.item)
    exports.qbx_core:Notify(source, locale('success.item_recieved') .. itemType.label, 'success')
end)

lib.callback.register('qbx_cityhall:server:applyJob', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not distanceCheck(source, job) then return end

    if qbx.table.size(player.PlayerData.jobs) >= maxJobsPerPlayer then
        exports.qbx_core:Notify(source, 'You cannot have more than '..maxJobsPerPlayer..' jobs!', 'error')
        return
    end

    exports.qbx_core:AddPlayerToJob(player.PlayerData.citizenid, job, 0)
    exports.qbx_core:Notify(source, locale('success.new_job'), 'success')
end)

lib.callback.register('qbx_cityhall:server:leaveJob', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not distanceCheck(source, job) then return end

    exports.qbx_core:RemovePlayerFromJob(player.PlayerData.citizenid, job)
    exports.qbx_core:Notify(source, locale('success.left_job'), 'success')
end)

RegisterNetEvent('qbx_cityhall:server:changeid', function(type, changes)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    local closestCityhall = getClosestHall(playerCoords)
    local cityhallCoords = sharedConfig.cityhalls[closestCityhall].coords

    if not player or #(playerCoords - cityhallCoords) > 5 then return end

    if player.Functions.RemoveMoney('cash', sharedConfig.idChanges[type].costs) then
        if type == 'birthdate' then
            changes = math.floor(changes / 1000)
            changes = os.date('%Y-%m-%d', changes)
        end
        local charinfo = player.PlayerData.charinfo
        charinfo[type] = changes
        exports.qbx_core:Notify(src, locale('success.changed_id'), 'success')
        DropPlayer(src, 'Wait 20 seconds until data is saved. Dont forget to replace your id and drivers license!')
        Wait(10000)
        MySQL.update.await('UPDATE players SET charinfo = ? WHERE citizenid = ?', { json.encode(charinfo), player.PlayerData.citizenid })
    end
end)

