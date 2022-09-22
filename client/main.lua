local table = lib.table
local properties = {}
local components = {}
local currentZone = {}

local zoneMenus = {
    management = function(currentZone)
        local property = properties[currentZone.property]
        return {
            {
                title = 'Stashes',
                description = 'View the stashes for this property',
                metadata = {['Count'] = property.stashes and #property.stashes or 0},
            },
            {
                title = 'Zones',
                description = 'View the zones for this property',
                metadata = {['Count'] = property.zones and #property.zones or 0},
            }
        }
    end,
    parking = function(currentZone)
        local options = {}
        local allVehicles, zoneVehicles, vehicleData = lib.callback.await('ox_property:getVehicleList', 100, {
            property = currentZone.property,
            zoneId = currentZone.zoneId
        })

        if cache.seat == -1 then
            options[#options + 1] = {
                title = 'Store Vehicle',
                event = 'ox_property:storeVehicle',
                args = {
                    property = currentZone.property,
                    zoneId = currentZone.zoneId
                }
            }
        end

        if zoneVehicles[1] then
            options[#options + 1] = {
                title = 'Open Location',
                description = 'View your vehicles at this location',
                metadata = {['Vehicles'] = #zoneVehicles},
                event = 'ox_property:vehicleList',
                args = {
                    property = currentZone.property,
                    zoneId = currentZone.zoneId,
                    vehicles = zoneVehicles,
                    vehicleData = vehicleData,
                    zoneOnly = true
                }
            }
        end

        options[#options + 1] = {
            title = 'All Vehicles',
            description = 'View all your vehicles',
            metadata = {['Vehicles'] = #allVehicles}
        }
        if #allVehicles > 0 then
            options[#options].event = 'ox_property:vehicleList'
            options[#options].args = {
                property = currentZone.property,
                zoneId = currentZone.zoneId,
                vehicles = allVehicles,
                vehicleData = vehicleData
            }
        end

        return options
    end
}

exports('registerZoneMenu', function(zone, menu)
    zoneMenus[zone] = menu
end)

function nearbyPoint(point)
    DrawMarker(2, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 30, 30, 150, 222, false, false, 0, true, false, false, false)
end

local function loadProperties(value)
    for k, v in pairs(value) do
        local create = true
        if not properties[k] and components[k] then
            RemoveBlip(components[k][1])
            for i = 2, #components[k] do
                components[k][i]:remove()
            end
        elseif properties[k] then
            create = false
        end

        if create then
            properties[k] = v
            components[k] = {}
            local blipCoords = v.blip
            local blip = AddBlipForCoord(blipCoords.x, blipCoords.y, blipCoords.z)
            components[k][#components[k] + 1] = blip

            SetBlipSprite(blip, v.sprite)
            SetBlipDisplay(blip, 2)
            SetBlipShrink(blip, true)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(k)
            EndTextCommandSetBlipName(blip)

            if v.stashes then
                for i = 1, #v.stashes do
                    local stash = v.stashes[i]
                    local pointName = ('%s:%s'):format(k, i)
                    components[k][#components[k] + 1] = lib.points.new(stash.coords, 16, {
                        type = 'stash',
                        name = pointName,
                        nearby = nearbyPoint,
                    })
                end
            end

            if v.zones then
                for i = 1, #v.zones do
                    local zone = v.zones[i]
                    local onEnter = function(self)
                        currentZone = self
                        lib.notify({
                            title = self.property,
                            description = self.name,
                            duration = 5000,
                            position = 'top'
                        })
                    end
                    local onExit = function(self)
                        if currentZone.property == self.property and currentZone.zoneId == self.zoneId then
                            currentZone = {}
                        end
                    end

                    if zone.points then
                        zoneData = lib.zones.poly({
                            points = zone.points,
                            thickness = zone.thickness,

                            onEnter = onEnter,
                            onExit = onExit,

                            property = k,
                            zoneId = i,
                            name = zone.name,
                            type = zone.type,
                            permitted = zone.permitted,
                        })
                    elseif zone.box then
                        zoneData = lib.zones.box({
                            coords = zone.box,
                            rotation = zone.rotation,
                            size = zone.size or vec3(2),

                            onEnter = onEnter,
                            onExit = onExit,

                            property = k,
                            zoneId = i,
                            name = zone.name,
                            type = zone.type,
                            permitted = zone.permitted,
                        })
                    elseif zone.sphere then
                        zoneData = lib.zones.sphere({
                            coords = zone.sphere,
                            radius = zone.radius,

                            onEnter = onEnter,
                            onExit = onExit,

                            property = k,
                            zoneId = i,
                            name = zone.name,
                            type = zone.type,
                            permitted = zone.permitted,
                        })
                    end
                    components[k][#components[k] + 1] = zoneData

                    if zone.disableGenerators then
                        local point1, point2
                        if zone.sphere then
                            point1, point2 = glm.sphere.maximalContainedAABB(zoneData.coords, zoneData.radius)
                        else
                            local verticalOffset = vec(0, 0, zoneData.thickness / 2)
                            point1, point2 = zoneData.polygon:minimalEnclosingAABB()
                            point1 -= verticalOffset
                            point2 += verticalOffset
                        end
                        SetAllVehicleGeneratorsActiveInArea(point1.x, point1.y, point1.z, point2.x, point2.y, point2.z, false, false)
                    end
                end
            end
        end
    end
end
loadProperties(GlobalState['Properties'])

exports('getCurrentZone', function()
    return {property = currentZone.property, zoneId = currentZone.zoneId, name = currentZone.name}
end)

AddStateBagChangeHandler('Properties', 'global', function(bagName, key, value, reserved, replicated)
    loadProperties(value)
end)

RegisterCommand('openZone', function()
    if IsPauseMenuActive() or IsNuiFocused() then return end

    local closestPoint = lib.points.closest()

    if closestPoint and closestPoint.type == 'stash' and closestPoint.currentDistance < 1 then
        return exports.ox_inventory:openInventory('stash', closestPoint.name)
    end

    if next(currentZone) then
        if not next(currentZone.permitted) or (currentZone.permitted.groups and player.hasGroup(currentZone.permitted.groups)) or currentZone.permitted.owner == player.charid then
            lib.registerContext({
                id = 'zone_menu',
                title = ('%s - %s'):format(currentZone.property, currentZone.name),
                options = zoneMenus[currentZone.type]({property = currentZone.property, zoneId = currentZone.zoneId})
            })
            lib.showContext('zone_menu')
        else
            lib.notify({title = 'Permission Denied', type = 'error'})
        end
    end
end)

RegisterKeyMapping('openZone', 'Zone Menu', 'keyboard', 'e')

RegisterNetEvent('ox_property:storeVehicle', function(data)
    if currentZone.property == data.property and currentZone.zoneId == data.zoneId then
        if cache.vehicle then
            if cache.seat == -1 then
                data.properties = lib.getVehicleProperties(cache.vehicle)
                TriggerServerEvent('ox_property:storeVehicle', data)
            else
                lib.notify({title = "You are not in the driver's seat", type = 'error'})
            end
        else
            lib.notify({title = 'You are not in a vehicle', type = 'error'})
        end
    end
end)

local function getZoneEntities()
    local entities = {}
    local peds = GetGamePool('CPed')
    for i = 1, #peds do
        local ped = peds[i]
        local pedCoords = GetEntityCoords(ped)
        if currentZone:contains(pedCoords) then
            entities[#entities + 1] = pedCoords
        end
    end

    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local vehicleCoords = GetEntityCoords(vehicle)
        if currentZone:contains(vehicleCoords) then
            entities[#entities + 1] = vehicleCoords
        end
    end

    return entities
end
exports('getZoneEntities', getZoneEntities)

RegisterNetEvent('ox_property:retrieveVehicle', function(data)
    if currentZone.property == data.property and currentZone.zoneId == data.zoneId then
        data.entities = getZoneEntities()
        TriggerServerEvent('ox_property:retrieveVehicle', data)
    end
end)

RegisterNetEvent('ox_property:vehicleList', function(data)
    if currentZone.property == data.property and currentZone.zoneId == data.zoneId then
        local options = {}
        local subMenus = {}
        for i = 1, #data.vehicles do
            local vehicle = data.vehicles[i]
            vehicle.data = data.vehicleData[vehicle.model]

            local zoneName = not vehicle.stored and 'Unknown' or vehicle.stored:gsub('^%l', string.upper)
            if vehicle.stored and vehicle.stored:find(':') then
                local property, zoneId = string.strsplit(':', vehicle.stored)
                zoneId = tonumber(zoneId)
                if currentZone.property == property and currentZone.zoneId == zoneId then
                    zoneName = 'Current Zone'
                elseif properties[property]?.zones?[zoneId] then
                    zoneName = ('%s - %s'):format(property, properties[property].zones[zoneId].name)
                else
                    zoneName = 'Unknown'
                end
            end

            options[('%s - %s'):format(vehicle.data.name, vehicle.plate)] = {
                menu = vehicle.plate,
                metadata = {['Location'] = zoneName}
            }

            local subOptions = {}
            if vehicle.stored == ('%s:%s'):format(data.property, data.zoneId) then
                subOptions['Retrieve'] = {
                    event = 'ox_property:retrieveVehicle',
                    args = {
                        property = currentZone.property,
                        zoneId = currentZone.zoneId,
                        plate = vehicle.plate
                    }
                }
            elseif zoneName ~= 'Unknown' and vehicle.stored:find(':') then
                subOptions['Move'] = {
                    serverEvent = 'ox_property:moveVehicle',
                    args = {
                        property = currentZone.property,
                        zoneId = currentZone.zoneId,
                        plate = vehicle.plate
                    }
                }
            else
                subOptions['Recover'] = {
                    serverEvent = 'ox_property:moveVehicle',
                    args = {
                        property = currentZone.property,
                        zoneId = currentZone.zoneId,
                        plate = vehicle.plate,
                        recover = true
                    }
                }
            end
            subMenus[#subMenus + 1] = {
                id = vehicle.plate,
                title = vehicle.plate,
                menu = 'vehicle_list',
                options = subOptions
            }
        end

        local menu = {
            id = 'vehicle_list',
            title = data.zoneOnly and ('%s - %s - Vehicles'):format(currentZone.property, currentZone.name) or 'All Vehicles',
            menu = 'zone_menu',
            options = options
        }
        for i = 1, #subMenus do
            menu[i] = subMenus[i]
        end

        lib.registerContext(menu)
        lib.showContext('vehicle_list')
    end
end)
