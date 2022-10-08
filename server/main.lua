local defaultPermissions = {}
local properties = {}

local function loadResourceDataFiles(property)
    local sets = {}
    if property then
        sets[1] = {[property] = properties[property]}
    else
        local resource = GetInvokingResource() or cache.resource
        local system = os.getenv('OS')
        local command = system and system:match('Windows') and 'dir "%s/" /b' or 'ls "%s/"'
        local path = GetResourcePath(resource)
        local dir = io.popen(command:format(path:gsub('//', '/') .. '/data'))

        local files = {}
        if dir then
            for line in dir:lines() do
                local file = line:gsub('%.lua', '')
                files[#files + 1] = file
            end
            dir:close()
        end

        for i = 1, #files do
            local file = files[i]
            local func, err = load(LoadResourceFile(resource, 'data/' .. file .. '.lua'), file, 't')
            assert(func, err == nil or '\n^1' .. err .. '^7')
            sets[i] = func()
        end
    end

    local propertyInsert = {}
    for i = 1, #sets do
        local propertySet = sets[i]
        for k, v in pairs(propertySet) do
            local savedData = MySQL.query.await('SELECT * FROM ox_property WHERE property = ?', {k})
            if next(savedData) then
                for j = 1, #savedData do
                    local component = savedData[j]
                    v[component.type == 'stash' and 'stashes' or 'zones'][component.id].permitted = json.decode(component.permitted)
                end
            else
                if v.stashes then
                    for j = 1, #v.stashes do
                        v.stashes[j].permitted = v.stashes[j].permitted or defaultPermissions
                        propertyInsert[#propertyInsert + 1] = {k, 'stash', j, json.encode(v.stashes[j].permitted)}
                    end
                end

                if v.zones then
                    for j = 1, #v.zones do
                        v.zones[j].permitted = v.zones[j].permitted or defaultPermissions
                        propertyInsert[#propertyInsert + 1] = {k, 'zone', j, json.encode(v.zones[j].permitted)}
                    end
                end
            end

            if v.stashes then
                for j = 1, #v.stashes do
                    local stash = v.stashes[j]
                    stash.stashId = j
                    local owner = stash.permitted.owner == 'true' or tostring(not (stash.permitted.groups and next(stash.permitted.groups)) and tonumber(stash.permitted.owner))

                    exports.ox_inventory:RegisterStash(('%s:%s'):format(k, j), ('%s - %s'):format(k, stash.name), stash.slots or 50, stash.maxWeight or 50000, owner, stash.permitted.groups, stash.coords)
                end
            end

            properties[k] = v
        end
    end
    GlobalState['Properties'] = properties

    if next(propertyInsert) then
        MySQL.prepare('INSERT INTO ox_property (property, type, id, permitted) VALUES (?, ?, ?, ?)', propertyInsert)
    end
end
exports('loadDataFiles', loadResourceDataFiles)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    loadResourceDataFiles()
end)

local function isPermitted(player, zone)
    if not next(zone.permitted) then return true end

    player = Ox.GetPlayer(player.source)
    if zone.permitted.groups and player.hasGroup(zone.permitted.groups) then return true end

    if zone.permitted.owner == player.charid then return true end

    local groupOwner = GlobalState[('group.%s'):format(zone.permitted.owner)]
    if groupOwner and player.hasGroup({[groupOwner.name] = #groupOwner.grades}) then return true end

    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Permission Denied', type = 'error'})
    return false
end
exports('isPermitted', isPermitted)

lib.callback.register('ox_property:getDisplayData', function(source, data)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    local displayData = {
        groups = MySQL.query.await('SELECT name, label, grades FROM ox_groups'),
        nearbyPlayers = {
            {
                name = player.name,
                charid = player.charid
            }
        }
    }

    for i = 1, #displayData.groups do
        local group = displayData.groups[i]
        group.grades = json.decode(group.grades)
        if zone.permitted.owner == group.name then
            displayData.owner = group.label
        end
    end

    for i = 1, #data.players do
        local nearbyPlayer = Ox.GetPlayer(GetPlayerServerId(data.players[i].id))
        displayData.nearbyPlayers[#displayData.nearbyPlayers + 1] = {
            name = nearbyPlayer.name,
            charid = nearbyPlayer.charid
        }
        if not zone.permitted.owner and tonumber(zone.permitted.owner) == nearbyPlayer.charid then
            displayData.owner = nearbyPlayer.name
        end
    end

    if not displayData.owner then
        if not zone.permitted.owner then
            displayData.owner = 'None'
        elseif tonumber(zone.permitted.owner) then
            if tonumber(zone.permitted.owner) == player.charid then
                displayData.owner = player.name
            else
                local names = MySQL.single.await('SELECT firstname, lastname FROM characters WHERE charid = ?', {zone.permitted.owner})
                displayData.owner = ('%s %s'):format(names.firstname, names.lastname)
            end
        end
    end

    return displayData
end)

RegisterServerEvent('ox_property:updatePermitted', function(data)
    local player = Ox.GetPlayer(source)
    local property = properties[data.property]
    local zone = property.zones[data.zoneId]

    if not isPermitted(player, zone) then return end
    if not next(data.change) then return end

    if data.componentType and data.componentId then
        local component = property[data.componentType][data.componentId]

        if data.change.groups then
            for k, v in pairs(data.change.groups) do
                component.permitted.groups = component.permitted.groups or {}
                component.permitted.groups[k] = tonumber(v) ~= 0 and tonumber(v) or nil
            end
        end

        MySQL.update('UPDATE ox_property SET permitted = ? WHERE property = ? AND type = ? AND id = ?', {json.encode(component.permitted.owner), data.property, data.componentType, data.componentId})
    else
        local permitted = zone.permitted

        if data.change.owner then
            permitted.owner = tonumber(data.change.owner) or data.change.owner
        end

        if data.change.groups then
            for k, v in pairs(data.change.groups) do
                permitted.groups = permitted.groups or {}
                permitted.groups[k] = tonumber(v) ~= 0 and tonumber(v) or nil
            end
        end

        for i = 1, #property.stashes do
            property.stashes[i].permitted = permitted
        end

        for i = 1, #property.zones do
            property.zones[i].permitted = permitted
        end

        MySQL.update('UPDATE ox_property SET permitted = ? WHERE property = ?', {json.encode(permitted), data.property})
    end

    property.refresh = true
    properties[data.property] = property
    GlobalState['Properties'] = properties

    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Permissions updated', type = 'success'})
end)

RegisterServerEvent('ox_property:resetPermitted', function(data)
    local player = Ox.GetPlayer(source)
    local property = properties[data.property]
    local zone = property.zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    local owner = zone.permitted.owner

    for i = 1, #property.stashes do
        property.stashes[i].permitted = {owner = owner}
    end

    for i = 1, #property.zones do
        property.zones[i].permitted = {owner = owner}
    end

    MySQL.update('UPDATE ox_property SET permitted = ? WHERE property = ?', {json.encode({owner = owner}), data.property})

    property.refresh = true
    properties[data.property] = property
    GlobalState['Properties'] = properties

    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Permissions reset', type = 'success'})
end)

lib.callback.register('ox_property:getVehicleList', function(source, data)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    local vehicles = data.propertyOnly and MySQL.query.await('SELECT * FROM vehicles WHERE stored LIKE ? AND owner = ?', {('%s%%'):format(data.property), player.charid}) or MySQL.query.await('SELECT * FROM vehicles WHERE owner = ?', {player.charid})

    local vehicleModels = {}
    local zoneVehicles = {}
    if data.property and data.zoneId then
        local zone = ('%s:%s'):format(data.property, data.zoneId)
        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            vehicleModels[#vehicleModels + 1] = vehicle.model

            if vehicle.stored == zone then
                zoneVehicles[#zoneVehicles + 1] = vehicle
            end
        end
    end

    return vehicles, zoneVehicles, Ox.GetVehicleData(vehicleModels)
end)

local function clearVehicleOfPassengers(vehicle)
    local passengers = {}
    for i = -1, vehicle.data.seats - 1 do
        local ped = GetPedInVehicleSeat(vehicle.entity, i)
        if ped ~= 0 then
            passengers[#passengers + 1] = ped
            TaskLeaveVehicle(ped, vehicle.entity, 0)
        end
    end

    if next(passengers) then
        local empty
        while not empty do
            Wait(100)
            empty = true
            for i = 1, #passengers do
                local passenger = passengers[i]
                if GetVehiclePedIsIn(passenger) == vehicle.entity then
                    empty = false
                end
            end
        end

        Wait(300)
    end
end
exports('clearVehicleOfPassengers', clearVehicleOfPassengers)

RegisterServerEvent('ox_property:storeVehicle', function(data)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    local vehicle = Ox.GetVehicle(GetVehiclePedIsIn(GetPlayerPed(player.source), false))
    if not vehicle then
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to store', type = 'error'})
        return
    end

    vehicle.data = Ox.GetVehicleData(vehicle.model)

    if player.charid == vehicle.owner and zone.vehicles[vehicle.data.type] then
        clearVehicleOfPassengers(vehicle)

        vehicle.set('properties', data.properties)
        vehicle.set('display')
        vehicle.setStored(('%s:%s'):format(data.property, data.zoneId), true)

        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle stored', type = 'success'})
        TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, 'store')
    else
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to store', type = 'error'})
    end
end)

local function isPointClear(point, entities)
    for i = 1, #entities do
        local entity = entities[i]
        if #(point - entity) < 2.5 then
            return false
        end
    end
    return true
end

local function findClearSpawn(spawns, entities)
    local len = #spawns
    while next(spawns) do
        local i = math.random(len)
        local spawn = spawns[i]
        if spawn and isPointClear(spawn.xyz, entities) then
            local rotate = math.random(2) - 1
            return {
                coords = spawn.xyz,
                heading = spawn.w + rotate * 180,
                slot = i,
                rotate = rotate == 1
            }
        else
            spawns[i] = nil
        end
    end
end
exports('findClearSpawn', findClearSpawn)

RegisterServerEvent('ox_property:retrieveVehicle', function(data)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    local vehicle = MySQL.single.await('SELECT id, plate, model, stored FROM vehicles WHERE plate = ? AND owner = ?', {data.plate, player.charid})

    if not vehicle or vehicle.stored ~= ('%s:%s'):format(data.property, data.zoneId) then
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle is not stored', type = 'error'})
        return
    end

    local spawn = findClearSpawn(zone.spawns, data.entities)

    if spawn and zone.vehicles[Ox.GetVehicleData(vehicle.model).type] then
        Ox.CreateVehicle(vehicle.id, spawn.coords, spawn.heading)

        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle retrieved', type = 'success'})
        TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, 'retrieve')
    else
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to retrieve', type = 'error'})
    end
end)

RegisterServerEvent('ox_property:moveVehicle', function(data)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    local vehicles = Ox.GetVehicles(true)
    local vehicle, recover, db

    for i = 1, #vehicles do
        if vehicles[i].plate == data.plate then
            local seats = Ox.GetVehicleData(vehicles[i].model).seats
            for j = -1, seats - 1 do
                if GetPedInVehicleSeat(vehicles[i].entity, j) ~= 0 then
                    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to recover', type = 'error'})
                    return
                end
            end

            vehicle = vehicles[i]
            recover = true
            break
        end
    end

    if not vehicle then
        vehicle = MySQL.single.await('SELECT plate, model, data, stored FROM vehicles WHERE plate = ? AND owner = ?', {data.plate, player.charid})

        if not vehicle then
            TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle not found', type = 'error'})
            return
        end
        recover = vehicle.stored and not vehicle.stored:find(':')
        db = true
    end


    local balance = exports.pefcl:getDefaultAccountBalance(player.source).data
    local amount = recover and 1000 or 500

    local owner = GlobalState[('group.%s'):format(zone.permitted.owner)]
    local from
    if owner then
        from = owner.label
    else
        owner = MySQL.single.await('SELECT firstname, lastname FROM characters WHERE charid = ?', {zone.permitted.owner or player.charid})
        from = ('%s %s'):format(owner.firstname, owner.lastname)
    end

    local vehicleData = Ox.GetVehicleData(vehicle.model)
    local message = recover and '%s Recovery' or '%s Move'
    message = message:format(vehicleData.name)

    if not zone.vehicles[vehicleData.type] then
        TriggerClientEvent('ox_lib:notify', player.source, {title = recover and 'Vehicle failed to recover' or 'Vehicle failed to move', type = 'error'})
        return
    end

    if zone.permitted.owner ~= player.charid then
        if balance >= amount then
            exports.pefcl:removeBankBalance(player.source, {amount = amount, message = message})
        else
            exports.pefcl:createInvoice(player.source, {
                to = player.name,
                toIdentifier = player.charid,
                from = from,
                fromIdentifier = zone.permitted.owner or player.charid,
                amount = amount,
                message = message
            })
        end
    end

    if db then
        vehicle.data = json.decode(vehicle.data)
        vehicle.data.display = nil

        MySQL.update.await('UPDATE vehicles SET stored = ?, data = ? WHERE plate = ?', {('%s:%s'):format(data.property, data.zoneId), json.encode(vehicle.data), vehicle.plate})
    else
        vehicle.set('display')
        vehicle.setStored(('%s:%s'):format(data.property, data.zoneId), true)
    end

    TriggerClientEvent('ox_lib:notify', player.source, {title = recover and 'Vehicle recovered' or 'Vehicle moved', type = 'success'})
    TriggerEvent('ox_property:vehicleStateChange', data.plate, recover and 'recover' or 'move')
end)

local ox_appearance = exports.ox_appearance
lib.callback.register('ox_property:getOutfits', function(source, data)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    return ox_appearance:outfitNames(player.charid) or {}, ox_appearance:outfitNames(('%s:%s'):format(data.property, data.zoneId)) or {}
end)

RegisterNetEvent('ox_property:saveOutfit', function(data, appearance)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    ox_appearance:saveOutfit(('%s:%s'):format(data.property, data.zoneId), appearance, data.slot, data.outfitNames)
end)

RegisterNetEvent('ox_property:applyOutfit', function(data)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].zones[data.zoneId]

    if not isPermitted(player, zone) then return end

    TriggerClientEvent('ox_property:applyOutfit', source, ox_appearance:loadOutfit(('%s:%s'):format(data.property, data.zoneId), data.slot) or {})
end)
