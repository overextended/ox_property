local propertyResources = {}
local properties = {}

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

local stashes = {}
local stashHook
local function resetStashHook()
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
end

local defaultOwner = nil
local defaultOwnerName
local defaultGroup = nil
local defaultGroupName
AddEventHandler('onResourceStart', function(resource)
    local count = GetNumResourceMetadata(resource, 'ox_property_data')
    if count < 1 then return end

    local data = {}
    for i = 0, count - 1 do
        local file = GetResourceMetadata(resource, 'ox_property_data', i)
        local func, err = load(LoadResourceFile(resource, file), file, 't')
        assert(func, err == nil or ('\n^1%s^7'):format(err))
        data[file:match('([%w_]+)%..+$')] = func()
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
    for k, v in pairs(data) do
        properties[k] = v

        local variables = existingProperties[k]
        if variables then
            variables.name = k
            variables.permissions = json.decode(variables.permissions)
        else
            variables = {
                name = k,
                permissions = {{}},
                owner = defaultOwner,
                ownerName = defaultOwnerName,
                group = defaultGroup,
                groupName = defaultGroupName
            }

            propertyInsert[#propertyInsert + 1] = {k, defaultOwner, defaultGroup}
        end

        GlobalState[('property.%s'):format(k)] = variables
        for key, value in pairs(variables) do
            v[key] = value
        end

        for i = 1, #v.components do
            local component = v.components[i]
            component.property = k
            component.componentId = i

            if component.type == 'stash' then
                local stashName = ('%s:%s'):format(k, i)
                stashes[stashName] = true

                exports.ox_inventory:RegisterStash(stashName, ('%s - %s'):format(v.label, component.name), component.slots or 50, component.maxWeight or 50000, not component.shared == true, nil, component.coords)
            end
        end
    end

    if next(propertyInsert) then
        MySQL.prepare('INSERT INTO ox_property (name, owner, `group`) VALUES (?, ?, ?)', propertyInsert)
    end

    resetStashHook()
end)

AddEventHandler('onResourceStop', function(resource)
    if not propertyResources[resource] then return end

    for i = 1, #propertyResources[resource] do
        properties[propertyResources[resource][i]] = nil
    end
    propertyResources[resource] = nil
end)

lib.callback.register('ox_property:getDisplayData', function(source, data)
    local component = properties[data.property].components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)
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
    end

    local playerPos = player.getCoords()
    local players = Ox.GetPlayers()
    for i = 1, #players do
        local nearbyPlayer = players[i]
        if nearbyPlayer.source ~= player.source and #(nearbyPlayer.getCoords() - playerPos) < 10 then
            displayData.nearbyPlayers[#displayData.nearbyPlayers + 1] = {
                name = nearbyPlayer.name,
                charid = nearbyPlayer.charid
            }
        end
    end

    return displayData
end)

RegisterServerEvent('ox_property:updatePermissions', function(data)
    local property = properties[data.property]
    local component = property.components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)
    local level = property.permissions[data.level] or {
        components = {},
        groups = {}
    }

    if data.level == 1 then
        data.permissions.components = nil
    end

    for k, v in pairs(data.permissions) do
        if k == 'players' then
            for key, value in pairs(v) do
                level[key] = value or nil
            end
        elseif k == 'everyone' then
            level.everyone = v or nil
        else
            for key, value in pairs(v) do
                level[k][key] = value ~= 0 and value or nil
            end
        end
    end
    property.permissions[data.level] = level

    MySQL.update('UPDATE ox_property SET permissions = ? WHERE name = ?', {json.encode(property.permissions), property.name})

    properties[property.name] = property
    GlobalState[('property.%s'):format(property.name)] = {
        name = property.name,
        permissions = property.permissions,
        owner = property.owner,
        ownerName = property.ownerName,
        group = property.group,
        groupName = property.groupName
    }

    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Permissions updated', type = 'success'})
end)

RegisterServerEvent('ox_property:deletePermissionLevel', function(data)
    local property = properties[data.property]
    local component = property.components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)
    if data.level == 1 then
        TriggerClientEvent('ox_lib:notify', player.source, {title = 'Action not possible for this permission level', type = 'error'})
        return
    end

    property.permissions[data.level] = nil

    MySQL.update('UPDATE ox_property SET permissions = ? WHERE name = ?', {json.encode(property.permissions), property.name})

    properties[property.name] = property
    GlobalState[('property.%s'):format(property.name)] = {
        name = property.name,
        permissions = property.permissions,
        owner = property.owner,
        ownerName = property.ownerName,
        group = property.group,
        groupName = property.groupName
    }

    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Permission Level Deleted', type = 'success'})
end)

RegisterServerEvent('ox_property:setPropertyValue', function(data)
    local property = properties[data.property]
    local component = property.components[data.componentId]

    local permitted = isPermitted(source, component)
    if not permitted or permitted > 1 then return end

    local player = Ox.GetPlayer(source)

    if data.owner then
        local owner = data.owner ~= 0 and data.owner or nil
        MySQL.update('UPDATE ox_property SET owner = ? WHERE name = ?', {owner, property.name})

        property.owner = owner
        property.ownerName = not owner and nil or MySQL.scalar.await('SELECT CONCAT(characters.firstname, " ", characters.lastname) FROM characters WHERE charid = ?', {owner})
    elseif data.group then
        local group = data.group ~= 0 and data.group or nil
        MySQL.update('UPDATE ox_property SET group = ? WHERE name = ?', {group, property.name})

        property.group = group
        property.groupName = not group and nil or GlobalState[('group.%s'):format(group)].label
    end

    properties[property.name] = property
    GlobalState[('property.%s'):format(property.name)] = {
        name = property.name,
        permissions = property.permissions,
        owner = property.owner,
        ownerName = property.ownerName,
        group = property.group,
        groupName = property.groupName
    }

    TriggerClientEvent('ox_lib:notify', player.source, {title = 'Property Value Set', type = 'success'})
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

    return vehicles, zoneVehicles
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

        MySQL.update.await('UPDATE vehicles SET stored = ?, data = ? WHERE plate = ?', {('%s:%s'):format(property.name, component.componentId), json.encode(vehicle.data), data.plate})
    else
        vehicle.set('display')
        vehicle.setStored(('%s:%s'):format(property.name, component.componentId), true)
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
