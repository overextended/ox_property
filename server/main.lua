local defaultOwner = nil
local defaultOwnerName = nil
local defaultGroup = nil
local defaultGroupName = nil
local properties = {}
local stashes = {}
local stashHook

local function isPermitted(playerId, component, noError)
    local player = Ox.GetPlayer(playerId)
    local property = properties[component.property]

    if player.charid == property.owner then
        return 1
    end

    if property.group and player.getGroup(property.group) == #GlobalState[('group.%s'):format(property.group)].grades then
        return 1
    end

    if next(property.permissions) then
        for i = 1, #property.permissions do
            local level = property.permissions[i]
            local access = i == 1 and 1 or level.components[component.componentId]
            if access and (level.everyone or level[player.charid] or player.hasGroup(level.groups)) then
                return access
            end
        end
    end

    if not noError then
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Permission Denied', type = 'error'})
    end
    return false
end
exports('isPermitted', isPermitted)

local function loadResourceDataFiles()
    local resource = GetInvokingResource() or cache.resource
    local system = os.getenv('OS')
    local command = system and system:match('Windows') and 'dir "%s/" /b' or 'ls "%s/"'
    local path = GetResourcePath(resource)
    local dir = io.popen(command:format(path:gsub('//', '/') .. '/data'))

    local lines = {}
    if dir then
        for line in dir:lines() do
            lines[#lines + 1] = line:gsub('%.lua', '')
        end
        dir:close()
    end

    local files = {}
    for i = 1, #lines do
        local file = lines[i]
        local func, err = load(LoadResourceFile(resource, ('data/%s.lua'):format(file)), file, 't')
        assert(func, err == nil or ('\n^1%s^7'):format(err))
        files[file] = func()
    end

    defaultOwnerName = defaultOwnerName or defaultOwner and MySQL.scalar.await('SELECT CONCAT(characters.firstname, " ", characters.lastname) FROM characters WHERE charid = ?', {defaultOwner})
    defaultGroupName = defaultGroupName or defaultGroup and MySQL.scalar.await('SELECT label FROM ox_groups WHERE name = ?', {defaultGroup})

    local result = MySQL.query.await('SELECT ox_property.*, CONCAT(characters.firstname, " ", characters.lastname) AS ownerName, ox_groups.label as ownerLabel FROM ox_property LEFT JOIN characters ON ox_property.owner = characters.charid LEFT JOIN ox_groups ON ox_property.group = ox_groups.name')

    local existingProperties = {}
    for i = 1, #result do
        local property = result[i]
        existingProperties[property.name] = property
    end

    local propertyInsert = {}
    for k, v in pairs(files) do
        local existingProperty = existingProperties[k]

        if existingProperty then
            v.owner = existingProperty.owner
            v.ownerName = existingProperty.ownerName
            v.permissions = existingProperty.permissions
            v.group = existingProperty.group
            v.groupName = existingProperty.groupName
        else
            v.owner = defaultOwner
            v.ownerName = defaultOwnerName
            v.permissions = {{}}
            v.group = defaultGroup
            v.groupName = defaultGroupName

            propertyInsert[#propertyInsert + 1] = {k, defaultOwner, defaultGroup}
        end

        for i = 1, #v.components do
            local component = v.components[i]
            component.property = k

            if component.type == 'stash' then
                local stashName = ('%s:%s'):format(k, i)
                stashes[stashName] = true

                exports.ox_inventory:RegisterStash(stashName, ('%s - %s'):format(v.label, component.name), component.slots or 50, component.maxWeight or 50000, not component.shared == true, nil, component.coords)
            end
        end

        properties[k] = v
    end
    GlobalState['Properties'] = properties

    local stashesArray = {}
    for stash in pairs(stashes) do
        stashesArray[#stashesArray + 1] = stash
    end

    if stashHook then
        exports.ox_inventory:removeHooks(stashHook)
    end

    stashHook = exports.ox_inventory:registerHook('openInventory', function(payload)
        local property, componentId = string.strsplit(':', payload.inventoryId)
        if not isPermitted(payload.source, properties[property].components[tonumber(componentId)], true) then
            return false
        end
    end, {
        inventoryFilter = stashesArray
    })

    if next(propertyInsert) then
        MySQL.prepare('INSERT INTO ox_property (name, owner, `group`) VALUES (?, ?, ?)', propertyInsert)
    end
end
exports('loadDataFiles', loadResourceDataFiles)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    loadResourceDataFiles()
end)

lib.callback.register('ox_property:getDisplayData', function(source, data)
    local player = Ox.GetPlayer(source)
    local zone = properties[data.property].components[data.zoneId]

    if not isPermitted(player, zone, true) then return end

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

        if zone.owner == group.name then
            displayData.owner = group.label
        end
    end

    for i = 1, #data.players do
        local nearbyPlayer = Ox.GetPlayer(GetPlayerServerId(data.players[i].id))
        displayData.nearbyPlayers[#displayData.nearbyPlayers + 1] = {
            name = nearbyPlayer.name,
            charid = nearbyPlayer.charid
        }

        if not zone.owner and tonumber(zone.owner) == nearbyPlayer.charid then
            displayData.owner = nearbyPlayer.name
        end
    end

    if not displayData.owner then
        if not zone.owner then
            displayData.owner = 'None'
        elseif tonumber(zone.owner) then
            if tonumber(zone.owner) == player.charid then
                displayData.owner = player.name
            else
                local names = MySQL.single.await('SELECT firstname, lastname FROM characters WHERE charid = ?', {zone.owner})
                displayData.owner = names and ('%s %s'):format(names.firstname, names.lastname)
            end
        end
    end

    return displayData
end)

RegisterServerEvent('ox_property:updatePermitted', function(data)
    local player = Ox.GetPlayer(source)
    local property = properties[data.property]
    local zone = property.zones[data.zoneId]

    if not isPermitted(player, zone, true) then return end
    if not next(data.change) then return end

    if data.componentType and data.componentId then
        local component = property[data.componentType][data.componentId]

        if data.change.groups then
            for k, v in pairs(data.change.groups) do
                component.groups[k] = tonumber(v) ~= 0 and tonumber(v) or nil
            end

            MySQL.update('UPDATE ox_property SET groups = ? WHERE property = ? AND type = ? AND id = ?', {json.encode(component.groups), data.property, data.componentType, data.componentId})
        end

        if data.change.public ~= nil then
            component.public = data.change.public

            MySQL.update('UPDATE ox_property SET public = ? WHERE property = ? AND type = ? AND id = ?', {component.public, data.property, data.componentType, data.componentId})
        end
    else
        if data.change.owner then
            zone.owner = data.change.owner
        end

        if data.change.groups then
            for k, v in pairs(data.change.groups) do
                zone.groups[k] = tonumber(v) ~= 0 and tonumber(v) or nil
            end
        end

        for i = 1, #property.stashes do
            property.stashes[i].owner = zone.owner
            property.stashes[i].groups = zone.groups
        end

        for i = 1, #property.zones do
            property.zones[i].owner = zone.owner
            property.zones[i].groups = zone.groups
        end

        MySQL.update('UPDATE ox_property SET owner = ?, groups = ? WHERE property = ?', {zone.owner, json.encode(zone.groups), data.property})
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

    if not isPermitted(player, zone, true) then return end

    for i = 1, #property.stashes do
        property.stashes[i].owner = zone.owner
        property.stashes[i].groups = {}
        property.stashes[i].public = false
    end

    for i = 1, #property.zones do
        property.zones[i].owner = zone.owner
        property.zones[i].groups = {}
        property.zones[i].public = false
    end

    MySQL.update('UPDATE ox_property SET owner = ?, groups = {}, public = false WHERE property = ?', {zone.owner, data.property})

    property.refresh = true
    properties[data.property] = property
    GlobalState['Properties'] = properties

    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Permissions reset', type = 'success'})
end)

lib.callback.register('ox_property:getVehicleList', function(source, data)
    local component = properties[data.property].components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)

    local vehicles = data.propertyOnly and MySQL.query.await('SELECT * FROM vehicles WHERE stored LIKE ? AND owner = ?', {('%s%%'):format(component.property), player.charid}) or MySQL.query.await('SELECT * FROM vehicles WHERE owner = ?', {player.charid})

    local vehicleModels = {}
    local zoneVehicles = {}
    local componentIdentifier = ('%s:%s'):format(component.property, component.componentId)
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        vehicleModels[#vehicleModels + 1] = vehicle.model

        if vehicle.stored == componentIdentifier then
            zoneVehicles[#zoneVehicles + 1] = vehicle
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
    local component = properties[data.property].components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)
    local vehicle = Ox.GetVehicle(GetVehiclePedIsIn(GetPlayerPed(player.source), false))
    if not vehicle then
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to store', type = 'error'})
        return
    end

    vehicle.data = Ox.GetVehicleData(vehicle.model)

    if player.charid == vehicle.owner and component.vehicles[vehicle.data.type] then
        clearVehicleOfPassengers(vehicle)

        vehicle.set('properties', data.properties)
        vehicle.set('display')
        vehicle.setStored(('%s:%s'):format(component.property, component.componentId), true)

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
    local component = properties[data.property].components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)
    local vehicle = MySQL.single.await('SELECT id, plate, model, stored FROM vehicles WHERE plate = ? AND owner = ?', {data.plate, player.charid})

    if not vehicle or vehicle.stored ~= ('%s:%s'):format(component.property, component.componentId) then
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle is not stored', type = 'error'})
        return
    end

    local spawn = findClearSpawn(component.spawns, data.entities)

    if spawn and component.vehicles[Ox.GetVehicleData(vehicle.model).type] then
        Ox.CreateVehicle(vehicle.id, spawn.coords, spawn.heading)

        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle retrieved', type = 'success'})
        TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, 'retrieve')
    else
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to retrieve', type = 'error'})
    end
end)

RegisterServerEvent('ox_property:moveVehicle', function(data)
    local property = properties[data.property]
    local component = property.components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)
    local vehicles = Ox.GetVehicles(true)
    local vehicle, recover, db

    for i = 1, #vehicles do
        local veh = vehicles[i]
        if veh.plate == data.plate then
            local seats = Ox.GetVehicleData(veh.model).seats
            for j = -1, seats - 1 do
                if GetPedInVehicleSeat(veh.entity, j) ~= 0 then
                    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to recover', type = 'error'})
                    return
                end
            end

            vehicle = veh
            recover = true
            break
        end
    end

    if not vehicle then
        vehicle = MySQL.single.await('SELECT model, data, stored FROM vehicles WHERE plate = ? AND owner = ?', {data.plate, player.charid})

        if not vehicle then
            TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle not found', type = 'error'})
            return
        end

        recover = not vehicle.stored or not vehicle.stored:find(':')
        db = true
    end

    local vehicleData = Ox.GetVehicleData(vehicle.model)
    if not vehicleData or not component.vehicles[vehicleData.type] then
        TriggerClientEvent('ox_lib:notify', player.source, {title = recover and 'Vehicle failed to recover' or 'Vehicle failed to move', type = 'error'})
        return
    end

    if property.owner ~= player.charid and (property.owner or property.group)then
        local amount = recover and 1000 or 500
        local message = (recover and '%s Recovery' or '%s Move'):format(vehicleData.name)

        if exports.pefcl:getDefaultAccountBalance(player.source).data >= amount then
            exports.pefcl:removeBankBalance(player.source, {amount = amount, message = message})

            exports.pefcl:addBankBalanceByIdentifier(player.source, {
                identifier = property.group or property.owner,
                amount = amount,
                message = message
            })
        else
            exports.pefcl:createInvoice(player.source, {
                to = player.name,
                toIdentifier = player.charid,
                from = property.groupName or property.ownerName,
                fromIdentifier = property.group or property.owner,
                amount = amount,
                message = message
            })
        end
    end

    if db then
        vehicle.data = json.decode(vehicle.data) or {}
        vehicle.data.display = nil

        MySQL.update.await('UPDATE vehicles SET stored = ?, data = ? WHERE plate = ?', {('%s:%s'):format(component.property, component.componentId), json.encode(vehicle.data), data.plate})
    else
        vehicle.set('display')
        vehicle.setStored(('%s:%s'):format(component.property, component.componentId), true)
    end

    TriggerClientEvent('ox_lib:notify', player.source, {title = recover and 'Vehicle recovered' or 'Vehicle moved', type = 'success'})
    TriggerEvent('ox_property:vehicleStateChange', data.plate, recover and 'recover' or 'move')
end)

local ox_appearance = exports.ox_appearance
lib.callback.register('ox_property:getOutfits', function(source, data)
    local component = properties[data.property].components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)
    return ox_appearance:outfitNames(player.charid) or {}, ox_appearance:outfitNames(('%s:%s'):format(component.property, component.componentId)) or {}
end)

RegisterNetEvent('ox_property:saveOutfit', function(data, appearance)
    local component = properties[data.property].components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    ox_appearance:saveOutfit(('%s:%s'):format(component.property, component.componentId), appearance, data.slot, data.outfitNames)
end)

RegisterNetEvent('ox_property:applyOutfit', function(data)
    local component = properties[data.property].components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    TriggerClientEvent('ox_property:applyOutfit', source, ox_appearance:loadOutfit(('%s:%s'):format(component.property, component.componentId), data.slot) or {})
end)
