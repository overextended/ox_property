local propertyResources = {}
local properties = {}

exports('getPropertyData', function(property, componentId)
    return componentId and properties[property].components[componentId] or properties[property]
end)

local zones = {}

local function isPermitted(player, propertyName, componentId, noError)
    player = type(player) == 'number' and Ox.GetPlayer(player) or player
    local property = properties[propertyName]
    local component = property.components[componentId]

    local zone = zones[propertyName][componentId]
    local coords = player.getCoords()
    if zone and not zone:contains(coords) then
        if not noError then
            TriggerClientEvent('ox_lib:notify', player.source, {title = 'Component Mismatch', type = 'error'})
        end
        return false
    elseif not zone and #(component.point - coords) > 1 then
        if not noError then
            TriggerClientEvent('ox_lib:notify', player.source, {title = 'Component Mismatch', type = 'error'})
        end
        return false
    end

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
        if not isPermitted(payload.source, property, tonumber(componentId), true) then
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

    propertyResources[resource] = {}
    local data = {}
    for i = 0, count - 1 do
        local file = GetResourceMetadata(resource, 'ox_property_data', i)
        local func, err = load(LoadResourceFile(resource, file), ('@@%s%s'):format(resource, file), 't', Shared.DATA_ENVIRONMENT)
        assert(func, err == nil or ('\n^1%s^7'):format(err))
        local propertyName = file:match('([%w_]+)%..+$')
        data[propertyName] = func()

        propertyResources[resource][#propertyResources[resource] + 1] = propertyName
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

        zones[k] = {}
        for i = 1, #v.components do
            local component = v.components[i]
            component.property = k
            component.componentId = i

            if not component.point then
                zones[k][i] = lib.zones[component.points and 'poly' or component.box and 'box' or component.sphere and 'sphere']({
                    points = component.points,
                    thickness = component.thickness,
                    coords = component.box or component.sphere,
                    rotation = component.rotation,
                    size = component.size or vec3(2),
                    radius = component.radius
                })
            end

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

local function getManagementData(player)
    local data = {
        groups = MySQL.query.await('SELECT name, label, grades FROM ox_groups'),
        nearbyPlayers = {
            {
                name = player.name,
                charid = player.charid
            }
        }
    }

    for i = 1, #data.groups do
        local group = data.groups[i]
        group.grades = json.decode(group.grades)
    end

    local playerPos = player.getCoords()
    local players = Ox.GetPlayers()
    for i = 1, #players do
        local nearbyPlayer = players[i]
        if nearbyPlayer.source ~= player.source and #(nearbyPlayer.getCoords() - playerPos) < 10 then
            data.nearbyPlayers[#data.nearbyPlayers + 1] = {
                name = nearbyPlayer.name,
                charid = nearbyPlayer.charid
            }
        end
    end

    return true, false, data
end

local function updateProperty(property)
    properties[property.name] = property
    GlobalState[('property.%s'):format(property.name)] = {
        name = property.name,
        permissions = property.permissions,
        owner = property.owner,
        ownerName = property.ownerName,
        group = property.group,
        groupName = property.groupName
    }
end

local function updatePermissionLevel(property, data)
    local level = property.permissions[data.level] or {}

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
                level[k] = level[k] or {}
                level[k][key] = value ~= 0 and value or nil
            end
        end
    end
    property.permissions[data.level] = level

    MySQL.update('UPDATE ox_property SET permissions = ? WHERE name = ?', {json.encode(property.permissions), property.name})

    updateProperty(property)

    return true, 'permission_level_updated'
end

local function deletePermissionLevel(property, level)
    if level == 1 then
        return false, 'action_not_allowed'
    end

    property.permissions[level] = nil

    MySQL.update('UPDATE ox_property SET permissions = ? WHERE name = ?', {json.encode(property.permissions), property.name})

    updateProperty(property)

    return true, 'permission_level_deleted'
end

local function setPropertyValue(property, data)
    if data.owner then
        local owner = data.owner ~= 0 and data.owner or nil
        MySQL.update('UPDATE ox_property SET owner = ? WHERE name = ?', {owner, property.name})

        property.owner = owner
        property.ownerName = owner and MySQL.scalar.await('SELECT CONCAT(characters.firstname, " ", characters.lastname) FROM characters WHERE charid = ?', {owner}) or nil
    elseif data.group then
        local group = data.group ~= 0 and data.group or nil
        MySQL.update('UPDATE ox_property SET `group` = ? WHERE name = ?', {group, property.name})

        property.group = group
        property.groupName = group and GlobalState[('group.%s'):format(group)].label or nil
    end

    updateProperty(property)

    return true, 'property_value_set'
end

lib.callback.register('ox_property:management', function(source, action, data)
    local permitted = isPermitted(source, data.property, data.componentId)

    if not permitted or permitted > 1 then
        return false, 'not_permitted'
    end

    if action == 'get_data' then
        return getManagementData(Ox.GetPlayer(source))
    end

    local property = properties[data.property]
    if action == 'update_permission' then
        return updatePermissionLevel(property, data)
    elseif action == 'delete_permission' then
        return deletePermissionLevel(property, data.level)
    elseif action == 'set_value' then
        return setPropertyValue(property, data)
    end
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

local function storeVehicle(player, component, data)
    local vehicle = Ox.GetVehicle(GetVehiclePedIsIn(player.ped, false))
    if not vehicle then
        return false, 'vehicle_store_failed'
    end

    vehicle.data = Ox.GetVehicleData(vehicle.model)
    if player.charid ~= vehicle.owner or not component.vehicles[vehicle.data.type] then
        return false, 'vehicle_store_failed'
    end

    clearVehicleOfPassengers(vehicle)

    vehicle.set('properties', data.properties)
    vehicle.set('display')
    vehicle.setStored(('%s:%s'):format(component.property, component.componentId), true)

    TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, 'store')

    return true, 'vehicle_stored'
end

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

local function retrieveVehicle(player, component, data)
    local vehicle = MySQL.single.await('SELECT id, plate, model, stored FROM vehicles WHERE plate = ? AND owner = ?', {data.plate, player.charid})
    if not vehicle or vehicle.stored ~= ('%s:%s'):format(component.property, component.componentId) then
        return false, 'vehicle_retrieve_failed'
    end

    local spawn = findClearSpawn(component.spawns, data.entities)
    if not spawn or not component.vehicles[Ox.GetVehicleData(vehicle.model).type] then
        return false, 'vehicle_retrieve_failed'
    end

    Ox.CreateVehicle(vehicle.id, spawn.coords, spawn.heading)

    TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, 'retrieve')

    return true, 'vehicle_retrieved'
end

local function moveVehicle(player, property, component, data)
    local vehicles = Ox.GetVehicles(true)
    local vehicle, recover, db

    for i = 1, #vehicles do
        local veh = vehicles[i]
        if veh.plate == data.plate then
            local seats = Ox.GetVehicleData(veh.model).seats
            for j = -1, seats - 1 do
                if GetPedInVehicleSeat(veh.entity, j) ~= 0 then
                    return false, 'vehicle_recover_failed'
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
            return false, 'vehicle_not_found'
        end

        recover = not vehicle.stored or not vehicle.stored:find(':')
        db = true
    end

    local vehicleData = Ox.GetVehicleData(vehicle.model)
    if not vehicleData or not component.vehicles[vehicleData.type] then
        return false, recover and 'vehicle_recover_failed' or 'vehicle_move_failed'
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

    TriggerEvent('ox_property:vehicleStateChange', data.plate, recover and 'recover' or 'move')

    return true, recover and 'vehicle_recovered' or 'vehicle_moved'
end

lib.callback.register('ox_property:parking', function(source, action, data)
    local player = Ox.GetPlayer(source)
    local permitted = isPermitted(player, data.property, data.componentId)

    if not permitted or permitted > 1 then
        return false, 'not_permitted'
    end

    if action == 'get_vehicles' then
        return true, false, MySQL.query.await('SELECT * FROM vehicles WHERE owner = ?', {player.charid})
    end

    local property = properties[data.property]
    local component = property.components[data.componentId]
    if action == 'store_vehicle' then
        return storeVehicle(player, component, data)
    elseif action == 'retrieve_vehicle' then
        return retrieveVehicle(player, component, data)
    elseif action == 'move_vehicle' then
        return moveVehicle(player, property, component, data)
    end
end)

local ox_appearance = exports.ox_appearance

lib.callback.register('ox_property:wardrobe', function(source, action, data)
    local permitted = isPermitted(source, data.property, data.componentId)

    if not permitted or permitted > 1 then
        return false, 'not_permitted'
    end

    if action == 'get_outfits' then
        return true, false, {
            personalOutfits = ox_appearance:outfitNames(Ox.GetPlayer(source).charid),
            componentOutfits = ox_appearance:outfitNames(('%s:%s'):format(data.property, data.componentId))
        }
    elseif action == 'save_outfit' then
        ox_appearance:saveOutfit(('%s:%s'):format(data.property, data.componentId), data.appearance, data.slot, data.outfitNames)

        return true, 'outfit_saved'
    elseif action == 'apply_outfit' then
        TriggerClientEvent('ox_property:applyOutfit', source, ox_appearance:loadOutfit(('%s:%s'):format(data.property, data.componentId), data.slot) or {})

        return true, 'outfit_applied'
    end
end)
