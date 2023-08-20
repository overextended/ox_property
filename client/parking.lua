local vehicleNames = setmetatable({}, {
	__index = function(self, index)
		local data = Ox.GetVehicleData(index)

		if data then
			self[index] = data.name
			return data.name
		end
	end
})

---@param data { component: OxPropertyComponent, vehicle: { id: integer, plate: string, owner: integer, group: string, stored: string, model: string, name: string, action: string, location: string, label: string } }
local function manageVehicle(data)
    local options = {
        {
            title = ('%s - %s'):format(data.vehicle.name, data.vehicle.plate),
            metadata = {
                ['Group'] = data.vehicle.group and GlobalState[('group.%s'):format(data.vehicle.group)].label,
                ['Location'] = data.vehicle.location
            }
        },
        {
            title = 'Update Values',
            disabled = data.vehicle.owner ~= player.charid,
            onSelect = function(args)
                local groupTable = player.groups
                local groups = {{value = 'none', label = 'None'}}

                for group in pairs(groupTable) do
                    groups[#groups + 1] = { value = group, label = GlobalState[('group.%s'):format(group)].label}
                end

                local options = {
                    {
                        type = 'input',
                        label = 'Label',
                        default = data.vehicle.label
                    },
                    {
                        type = 'select',
                        label = 'Group',
                        default = data.vehicle.group,
                        options = groups
                    }
                }

                local input = lib.inputDialog('Update Vehicle Values', options)

                if input then
                    if not data.vehicle.label and input[1] == "" then input[1] = nil end

                    for k, v in pairs(input) do
                        if options[k].default == v then
                            input[k] = nil
                        end
                    end

                    if next(input) then
                        local response, msg = lib.callback.await('ox_property:parking', 100, 'set_vehicle_values', {
                            property = data.component.property,
                            componentId = data.component.componentId,
                            id = data.vehicle.id,
                            values = {label = input[1], group = input[2]}
                        })

                        if msg then
                            lib.notify({title = msg, type = response and 'success' or 'error'})
                        end
                    end
                end
            end,
        },
        {
            title = 'Retrieve',
            onSelect = function(args)
                local response, msg = lib.callback.await('ox_property:parking', 100, 'retrieve_vehicle', {
                    property = data.component.property,
                    componentId = data.component.componentId,
                    id = data.vehicle.id
                })

                if msg then
                    lib.notify({title = msg, type = response and 'success' or 'error'})
                end
            end,
        },
    }

    lib.registerContext({
        id = 'manage_vehicle',
        title = 'Manage Vehicle',
        menu = 'vehicle_list',
        options = options
    })

    lib.showContext('manage_vehicle')
end

---@param data { component: OxPropertyComponent, componentOnly: boolean?, vehicles: { id: integer, plate: string, owner: integer, group: string, stored: string, model: string, name: string, action: string, location: string, label: string }[] }
local function vehicleList(data)
    local options = {}

    for i = 1, #data.vehicles do
        local vehicle = data.vehicles[i]

        options[('%s - %s'):format(vehicle.name, vehicle.plate)] = {
            metadata = {
                ['Action'] = vehicle.action,
                ['Group'] = vehicle.group and GlobalState[('group.%s'):format(vehicle.group)].label,
                ['Location'] = vehicle.location
            },
            onSelect = function(args)
                if args.action == 'Manage' then
                    manageVehicle({component = data.component, vehicle = vehicle})
                else
                    local response, msg = lib.callback.await('ox_property:parking', 100, args.action == 'Retrieve' and 'retrieve_vehicle' or 'move_vehicle', {
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
                action = vehicle.action
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
        vehicle.name = vehicleNames[vehicle.model]
        vehicle.location = 'Unknown'
        vehicle.action = 'Recover'

        if vehicle.stored and vehicle.stored:find(':') then
            if vehicle.stored == currentComponent then
                vehicle.location = 'Current location'
                vehicle.action = vehicle.owner == player.charid and 'Manage' or 'Retrieve'
                componentVehicles[#componentVehicles + 1] = vehicle
            else
                local propertyName, componentId = string.strsplit(':', vehicle.stored)
                local property = Properties[propertyName]
                local component = property and property.components[tonumber(componentId)]

                if property and component then
                    vehicle.location = ('%s - %s'):format(property.label, component.name)
                    vehicle.action = 'Move'
                end
            end
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

RegisterMenu({'vehicle_list', 'manage_vehicle'}, 'contextMenu')

---@param point vector3
---@param entities integer[]
---@return boolean response
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
---@return false | { coords: vector3, heading: number, slot: integer, rotate: boolean } response
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

---@return false | { coords: vector3, heading: number, slot: integer, rotate: boolean } response
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
