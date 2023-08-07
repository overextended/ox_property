local vehicleNames = setmetatable({}, {
	__index = function(self, index)
		local data = Ox.GetVehicleData(index)

		if data then
			self[index] = data.name
			return data.name
		end
	end
})

---@param data { component: OxPropertyComponent, componentOnly: boolean, vehicles: { id: integer, plate: string, stored: string, model: string, currentComponent: boolean }[] }
local function vehicleList(data)
    local options = {}

    for i = 1, #data.vehicles do
        local vehicle = data.vehicles[i]
        vehicle.name = vehicleNames[vehicle.model]

        local location = 'Unknown'
        local stored = vehicle.stored and vehicle.stored:find(':')

        if stored then
            if data.componentOnly or vehicle.currentComponent then
                location = 'Right here'
            else
                local propertyName, componentId = string.strsplit(':', vehicle.stored)
                local property = Properties[propertyName]

                if property then
                    location = ('%s:%s'):format(property.label, componentId)
                end
            end
        end

        local action = location == 'Right here' and 'Retrieve' or stored and 'Move' or 'Recover'

        options[('%s - %s'):format(vehicle.name, vehicle.plate)] = {
            metadata = {
                ['Action'] = action,
                ['Location'] = location
            },
            onSelect = function(args)
                if args.action == 'Retrieve' then
                    local response, msg = lib.callback.await('ox_property:parking', 100, 'retrieve_vehicle', {
                        property = data.component.property,
                        componentId = data.component.componentId,
                        id = args.id
                    })

                    if msg then
                        lib.notify({title = msg, type = response and 'success' or 'error'})
                    end
                else
                    local response, msg = lib.callback.await('ox_property:parking', 100, 'move_vehicle', {
                        property = data.component.property,
                        componentId = data.component.componentId,
                        id = args.id
                    })

                    if msg then
                        lib.notify({title = msg, type = response and 'success' or 'error'})
                    end
                end
            end,
            args = {
                id = vehicle.id,
                action = action
            }
        }
    end

    lib.registerContext({
        id = 'vehicle_list',
        title = data.componentOnly and ('%s - %s - Vehicles'):format(Properties[data.component.property].label, data.component.name) or 'All Vehicles',
        menu = 'component_menu',
        options = options
    })

    lib.showContext('vehicle_list')
end

RegisterComponentAction('parking', function(component)
    local options = {}
    local vehicles, msg = lib.callback.await('ox_property:parking', 100, 'get_vehicles', {
        property = component.property,
        componentId = component.componentId
    })

    if msg then
        lib.notify({title = msg, type = vehicles and 'success' or 'error'})
    end
    if not vehicles then return end

    if cache.seat == -1 then
        options[#options + 1] = {
            title = 'Store Vehicle',
            onSelect = function()
                if cache.seat == -1 then
                    local response, msg = lib.callback.await('ox_property:parking', 100, 'store_vehicle', {
                        property = component.property,
                        componentId = component.componentId,
                        properties = lib.getVehicleProperties(cache.vehicle)
                    })

                    if msg then
                        lib.notify({title = msg, type = response and 'success' or 'error'})
                    end
                else
                    lib.notify({title = "You are not in the driver's seat", type = 'error'})
                end
            end
        }
    end

    local len = #vehicles
    local componentVehicles = {}
    local currentComponent = ('%s:%s'):format(component.property, component.componentId)
    for i = 1, len do
        local vehicle = vehicles[i]
        if vehicle.stored == currentComponent then
            componentVehicles[#componentVehicles + 1] = vehicle
            vehicle.currentComponent = true
        end
    end

    options[#options + 1] = {
        title = 'Open Location',
        description = 'View your vehicles at this location',
        metadata = {['Vehicles'] = #componentVehicles},
        onSelect = #componentVehicles > 0 and vehicleList,
        args = {
            component = component,
            vehicles = componentVehicles,
            componentOnly = true
        }
    }

    options[#options + 1] = {
        title = 'All Vehicles',
        description = 'View all your vehicles',
        metadata = {['Vehicles'] = len},
        onSelect = len > 0 and vehicleList,
        args = {
            component = component,
            vehicles = vehicles
        }
    }

    return {options = options}, 'contextMenu'
end, {'All access'})

RegisterMenu('vehicle_list', 'contextMenu')

---@param point vector3
---@param entities integer[]
---@return boolean
local function isPointClear(point, entities)
    for i = 1, #entities do
        local entity = entities[i]
        if #(point - entity) < 2.5 then
            return false
        end
    end
    return true
end

---@param spawns vector4[]
---@param entities integer[]
---@return boolean | { coords: vector3, heading: number, slot: integer, rotate: boolean }
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

    return false
end

lib.callback.register('ox_property:findClearSpawn', function()
    if not CurrentZone then
        return false
    end

    local component = Properties[CurrentZone.property].components[CurrentZone.componentId]
    if not component.spawns then
        return false
    end

    local entities = {}
    local pool = {table.unpack(GetGamePool('CPed')), table.unpack(GetGamePool('CVehicle'))}
    local len = #pool

    for i = 1, len do
        local entity = pool[i]
        local entityCoords = GetEntityCoords(entity)
        if CurrentZone:contains(entityCoords) then
            entities[#entities + 1] = entityCoords
        end
    end

    return findClearSpawn(component.spawns, entities)
end)
