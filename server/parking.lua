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

---@param player OxPlayer
---@return string[]
local function getPlayerGroupsArray(player)
    local groupTable = player:getGroups()

    local groups = {}

    for group in pairs(groupTable) do
        groups[#groups + 1] = group
    end

    return groups
end

---@param player integer | OxPlayer
---@param data { property: string, componentId: integer, id?: integer, values: table<string, string> }
---@return boolean response, string msg
local function setVehicleValues(player, data)
    player = type(player) == 'number' and Ox.GetPlayer(player) or player --[[@as OxPlayer]]
    local vehicle = MySQL.single.await('SELECT JSON_VALUE(data, "$.label") AS `label`, `group`, `stored` FROM `vehicles` WHERE `id` = ? AND `owner` = ?', {data.id, player.charId})

    if not vehicle then
        return false, locale('vehicle_not_found')
    elseif vehicle.stored ~= ('%s:%s'):format(data.property, data.componentId) then
        return false, locale("component_mismatch")
    end

    for key, value in pairs(data.values) do
        if vehicle[key] ~= value then
            if key == 'label' then
                MySQL.update('UPDATE `vehicles` SET `data` = JSON_SET(`data`, "$.label", ?) WHERE `id` = ? AND `owner` = ?', {value ~= "" and value or nil, data.id, player.charId})
            elseif key == 'group' then
                MySQL.update('UPDATE `vehicles` SET `group` = ? WHERE `id` = ? AND `owner` = ?', {value, data.id, player.charId})
            end
        end
    end
    return true, locale("vehicle_updated")
end
exports('setVehicleValues', setVehicleValues)

---@param data { entity: integer, model: string, seats?: integer }
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
                if GetVehiclePedIsIn(passenger, false) == entity then
                    empty = false
                end
            end
        end

        Wait(300)
    end
end
exports('clearVehicleOfPassengers', clearVehicleOfPassengers)

---@param player integer | OxPlayer
---@param component OxPropertyComponent
---@param properties VehicleProperties
---@return boolean response, string msg
local function storeVehicle(player, component, properties)
    player = type(player) == 'number' and Ox.GetPlayer(player) or player --[[@as OxPlayer]]
    local vehicle = Ox.GetVehicle(GetVehiclePedIsIn(player.ped, false))
    if not vehicle then
        return false, locale("vehicle_not_found")
    elseif player.charId ~= vehicle.owner or (vehicle.group and not player.hasGroup(vehicle.group)) then
        return false, locale("not_vehicle_owner")
    end

    vehicle.data = vehicleData[vehicle.model]
    if not component.vehicles[vehicle.data.type] then
        return false, locale("vehicle_requirements_not_met")
    end

    clearVehicleOfPassengers({entity = vehicle.entity, seats = vehicle.data.seats})

    vehicle.set('properties', properties)
    vehicle.setStored(('%s:%s'):format(component.property, component.componentId), true)

    return true, locale("vehicle_stored")
end
exports('storeVehicle', storeVehicle)

---@param player integer | OxPlayer
---@param component OxPropertyComponent
---@param id integer
---@return boolean response, string msg
local function retrieveVehicle(player, component, id)
    player = type(player) == 'number' and Ox.GetPlayer(player) or player --[[@as OxPlayer]]
    local vehicle = MySQL.single.await('SELECT `model`, `stored` FROM `vehicles` WHERE `id` = ? AND (`owner` = ? OR `group` IN (?))', {id, player.charId, getPlayerGroupsArray(player)})
    if not vehicle then
        return false, locale("vehicle_not_found")
    elseif vehicle.stored ~= ('%s:%s'):format(component.property, component.componentId) then
        return false, locale("component_mismatch")
    end

    local spawn = lib.callback.await('ox_property:findClearSpawn', player.source)

    if not spawn then
        return false, locale("spawn_not_found")
    elseif not component.vehicles[vehicleData[vehicle.model].type] then
        return false, locale("vehicle_requirements_not_met")
    end

    Ox.CreateVehicle(id, spawn.coords, spawn.heading)

    return true, locale("vehicle_retrieved")
end
exports('retrieveVehicle', retrieveVehicle)

---@param player OxPlayer
---@param property OxPropertyObject
---@param component OxPropertyComponent
---@param id integer
---@return boolean response, string? msg
local function moveVehicle(player, property, component, id)
    local vehicles = Ox.GetVehicles()
    local vehicle, recover, db

    for i = 1, #vehicles do
        local veh = vehicles[i]
        if veh.id == id then
            if veh.stored == 'displayed' then
                return false, locale("vehicle_cannot_be_modified_while_displayed")
            end

            local seats = vehicleData[veh.model].seats
            for j = -1, seats - 1 do
                if GetPedInVehicleSeat(veh.entity, j) ~= 0 then
                    return false, locale("vehicle_in_use")
                end
            end

            vehicle = veh
            recover = true
            break
        end
    end

    if not vehicle then
        vehicle = MySQL.single.await('SELECT `model`, `stored` FROM `vehicles` WHERE `id` = ? AND (`owner` = ? OR `group` IN (?))', {id, player.charId, getPlayerGroupsArray(player)})

        if not vehicle then
            return false, locale("vehicle_not_found")
        elseif vehicle.stored == 'displayed' then
            return false, locale("vehicle_cannot_be_modified_while_displayed")
        end

        recover = not vehicle.stored or not vehicle.stored:find(':')
        db = true
    end

    local vehData = vehicleData[vehicle.model]
    if not vehData then
        return false, locale("model_not_found")
    elseif not component.vehicles[vehData.type] then
        return false, locale("vehicle_requirements_not_met")
    end

    if property.owner ~= player.charId then
        local response, msg = Transaction(player.source, (recover and '%s '..locale("recover") or '%s '..locale("move")):format(vehData.name), {
            amount = recover and 1000 or 500,
            from = {name = player.name, identifier = player.charId},
            to = {name = property.groupName or property.ownerName, identifier = property.group or property.owner}
        })

        if not response then
            return false, msg
        end
    end

    if db then
        MySQL.update.await('UPDATE vehicles SET `stored` = ? WHERE id = ?', {('%s:%s'):format(property.name, component.componentId), id})
    else
        vehicle.setStored(('%s:%s'):format(property.name, component.componentId), true)
    end

    return true, recover and locale("vehicle_recovered") or locale("vehicle_moved")
end

---@param source integer
---@param action string
---@param data { property: string, componentId: integer, properties?: VehicleProperties, id?: integer, values?: table<string, string> }
---@return boolean | { id: integer, plate: string, owner: integer, group: string, stored: string, model: string }[] response, string? msg
lib.callback.register('ox_property:parking', function(source, action, data)
    local player = Ox.GetPlayer(source) --[[@as OxPlayer]]
    local permitted, msg = IsPermitted(player, data.property, data.componentId, 'parking')

    if not permitted or permitted > 1 then
        return false, msg or locale("not_permitted")
    end

    if action == 'get_vehicles' then
        return MySQL.query.await('SELECT `id`, `plate`, `owner`, `group`, `stored`, `model`, JSON_VALUE(data, "$.label") AS `label` FROM `vehicles` WHERE `owner` = ? OR `group` IN (?)', {player.charId, getPlayerGroupsArray(player)})
    elseif action == 'set_vehicle_values' then
        return setVehicleValues(player, data)
    end

    local property = Properties[data.property]
    local component = property.components[data.componentId]
    if action == 'store_vehicle' then
        return storeVehicle(player, component, data.properties)
    elseif action == 'retrieve_vehicle' then
        return retrieveVehicle(player, component, data.id)
    elseif action == 'move_vehicle' then
        return moveVehicle(player, property, component, data.id)
    end

    return false, locale("invalid_action")
end)
