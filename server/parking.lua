local vehicleData = setmetatable({}, {
	__index = function(self, index)
		local data = Ox.GetVehicleData(index)

		if data then
			data = {
				name = data.name,
				type = data.type,
				seats = data.seats,
			}

			self[index] = data
			return data
		end
	end
})

local function clearVehicleOfPassengers(data)
    local entity, model, seats in data
    seats = seats or vehicleData[model].seats

    local passengers = {}
    for i = -1, seats - 1 do
        local ped = GetPedInVehicleSeat(entity, i)
        if ped ~= 0 then
            passengers[#passengers + 1] = ped
            TaskLeaveVehicle(ped, entity, 0)
        end
    end

    if next(passengers) then
        local empty
        while not empty do
            Wait(100)
            empty = true
            for i = 1, #passengers do
                local passenger = passengers[i]
                if GetVehiclePedIsIn(passenger) == entity then
                    empty = false
                end
            end
        end

        Wait(300)
    end
end
exports('clearVehicleOfPassengers', clearVehicleOfPassengers)

local function storeVehicle(player, component, data)
    player = type(player) == 'number' and Ox.GetPlayer(player) or player
    local vehicle = Ox.GetVehicle(GetVehiclePedIsIn(player.ped, false))
    if not vehicle then
        return false, 'vehicle_store_failed'
    elseif player.charid ~= vehicle.owner then
        return false, 'not_vehicle_owner'
    end

    vehicle.data = vehicleData[vehicle.model]
    if not component.vehicles[vehicle.data.type] then
        return false, 'vehicle_requirements_not_met'
    end

    clearVehicleOfPassengers({entity = vehicle.entity, seats = vehicle.data.seats})

    vehicle.set('properties', data.properties)
    vehicle.set('display')
    vehicle.setStored(('%s:%s'):format(component.property, component.componentId), true)

    TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, 'store')

    return true, 'vehicle_stored'
end
exports('storeVehicle', storeVehicle)

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
    if not spawn or not component.vehicles[vehicleData[vehicle.model].type] then
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
            local seats = vehicleData[veh.model].seats
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

    local vehData = vehicleData[vehicle.model]
    if not vehData or not component.vehicles[vehData.type] then
        return false, recover and 'vehicle_recover_failed' or 'vehicle_move_failed'
    end

    if property.owner ~= player.charid then
        local response, msg = Transaction(player.source, (recover and '%s Recovery' or '%s Move'):format(vehData.name), {
            amount = recover and 1000 or 500,
            from = {name = player.name, identifier = player.charid},
            to = {name = property.groupName or property.ownerName, identifier = property.group or property.owner}
        })

        if not response then
            return false, msg
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
    local permitted, msg = IsPermitted(player, data.property, data.componentId, 'parking')

    if not permitted or permitted > 1 then
        return false, msg or 'not_permitted'
    end

    if action == 'get_vehicles' then
        return MySQL.query.await('SELECT * FROM vehicles WHERE owner = ?', {player.charid})
    end

    local property = Properties[data.property]
    local component = property.components[data.componentId]
    if action == 'store_vehicle' then
        return storeVehicle(player, component, data)
    elseif action == 'retrieve_vehicle' then
        return retrieveVehicle(player, component, data)
    elseif action == 'move_vehicle' then
        return moveVehicle(player, property, component, data)
    end
end)
