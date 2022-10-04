local table = lib.table
local properties = {}
local components = {}
local currentZone = {}
local zoneContexts = {zone_menu = true}
local zoneLists = {zone_menu = true}

local zoneMenus = {
    management = function(currentZone)
        local property = properties[currentZone.property]

        local stashesList = {}
        for i = 1, #property.stashes do
            stashesList[#stashesList + 1] = property.stashes[i].name
        end
        if not next(stashesList) then stashesList = false end

        local zonesList = {}
        for i = 1, #property.zones do
            zonesList[#zonesList + 1] = property.zones[i].name
        end
        if not next(zonesList) then zonesList = false end

        return {
            options = {
                {label = currentZone.property, description = 'Set permissions for the whole property'},
                {label = 'Property stashes', values = stashesList or {'None'}, description = 'View and edit stash permissions'},
                {label = 'Property zones', values = zonesList or {'None'}, description = 'View and edit zone permissions'},
            },
        }, 'list'
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

        return {options = options}, 'context'
    end,
    wardrobe = function(currentZone)
        local options = {}
        local zone = GlobalState['Properties'][currentZone.property].zones[currentZone.zoneId]
        local personalOutfits, zoneOutfits = lib.callback.await('ox_property:getOutfits', 100, {
            property = currentZone.property,
            zoneId = currentZone.zoneId
        })

        if zone.outfits then
            options[#options + 1] = {
                title = 'Zone wardrobe',
                event = 'ox_property:outfits',
                args = {
                    property = currentZone.property,
                    zoneId = currentZone.zoneId,
                    outfitNames = zoneOutfits,
                    zoneOutfits = true
                }
            }

            options[#options + 1] = {
                title = 'Save new zone outfit',
                arrow = true,
                event = 'ox_property:saveOutfit',
                args = {
                    property = currentZone.property,
                    zoneId = currentZone.zoneId,
                    slot = 'new',
                    name = '',
                    outfitNames = zoneOutfits
                }
            }
        end

        options[#options + 1] = {
            title = 'Personal wardrobe',
            event = 'ox_property:outfits',
            args = {
                property = currentZone.property,
                zoneId = currentZone.zoneId,
                outfitNames = personalOutfits
            }
        }

        options[#options + 1] = {
            title = 'Save new personal outfit',
            arrow = true,
            event = 'ox_appearance:saveOutfit',
            args = {slot = 'new', name = ''}
        }

        return {options = options}, 'context'
    end
}

exports('registerZoneMenu', function(zone, menu, subMenus)
    zoneMenus[zone] = menu

    if type(subMenus) == 'table' then
        if subMenus.zoneContexts then
            if type(subMenus.zoneContexts) == 'table' then
                for i = 1, #subMenus.zoneContexts do
                    zoneContexts[subMenus.zoneContexts[i]] = true
                end
            elseif type(subMenus.zoneContexts) == 'string' then
                zoneContexts[subMenus.zoneContexts] = true
            end
        end

        if subMenus.zoneLists then
            if type(subMenus.zoneLists) == 'table' then
                for i = 1, #subMenus.zoneLists do
                    zoneLists[subMenus.zoneLists[i]] = true
                end
            elseif type(subMenus.zoneLists) == 'string' then
                zoneLists[subMenus.zoneLists] = true
            end
        end
    end
end)

local function nearbyPoint(point)
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
                            if zoneContexts[lib.getOpenContextMenu()] then lib.hideContext() end
                            if zoneLists[lib.getOpenMenu()] then lib.hideMenu() end
                        end
                    end

                    local zoneData
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

local function isPermitted()
    if not next(currentZone.permitted) then return true end

    if currentZone.permitted.groups and player.hasGroup(currentZone.permitted.groups) then return true end

    if currentZone.permitted.owner == player.charid then return true end

    local groupOwner = GlobalState[('group.%s'):format(currentZone.permitted.owner)]
    if groupOwner and #groupOwner.grades == player.groups[currentZone.permitted.owner] then return true end

    lib.notify({title = 'Permission Denied', type = 'error'})
    return false
end
exports('isPermitted', isPermitted)

RegisterCommand('openZone', function()
    if zoneContexts[lib.getOpenContextMenu()] then lib.hideContext() return end
    if zoneLists[lib.getOpenMenu()] then lib.hideMenu() return end
    if IsPauseMenuActive() or IsNuiFocused() then return end

    local closestPoint = lib.points.closest()

    if closestPoint and closestPoint.type == 'stash' and closestPoint.currentDistance < 1 then
        return exports.ox_inventory:openInventory('stash', closestPoint.name)
    end

    if next(currentZone) then
        if not isPermitted() then return end

        local data, menuType = zoneMenus[currentZone.type]({property = currentZone.property, zoneId = currentZone.zoneId})

        if data.event then
            TriggerEvent(data.event, data.args)
        elseif data.serverEvent then
            TriggerServerEvent(data.serverEvent, data.args)
        elseif menuType == 'list' then
            lib.registerMenu({
                id = 'zone_menu',
                title = data.title or currentZone.name,
                options = data.options,
                position = data.position or 'top-left',
                disableInput = data.disableInput,
                canClose = data.canClose,
                onClose = data.onClose,
                onSelected = data.onSelected,
                onSideScroll = data.onSideScroll,
            }, data.cb)
            lib.showMenu('zone_menu')
        elseif menuType == 'context' then
            local menu = {
                id = 'zone_menu',
                title = data.title or ('%s - %s'):format(currentZone.property, currentZone.name),
                canClose = data.canClose,
                onExit = data.onExit,
                options = data.options
            }

            if type(data.subMenus) == 'table' then
                for i = 1, #data.subMenus do
                    menu[i] = data.subMenus[i]
                end
            end

            lib.registerContext(menu)
            lib.showContext('zone_menu')
        end
    end
end)

RegisterKeyMapping('openZone', 'Zone Menu', 'keyboard', 'e')

local function checkCurrentZone(data)
    if currentZone.property == data.property and currentZone.zoneId == data.zoneId then return true end

    lib.notify({title = 'Zone Mismatch', type = 'error'})
    return false
end
exports('checkCurrentZone', checkCurrentZone)

RegisterNetEvent('ox_property:storeVehicle', function(data)
    if not checkCurrentZone(data) then return end

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
    if not checkCurrentZone(data) then return end

    data.entities = getZoneEntities()
    TriggerServerEvent('ox_property:retrieveVehicle', data)
end)

RegisterNetEvent('ox_property:vehicleList', function(data)
    if not checkCurrentZone(data) then return end

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
end)

RegisterNetEvent('ox_property:outfits', function(data)
    if not checkCurrentZone(data) then return end

    local options = {}

    for k, v in pairs(data.outfitNames) do
        options[v] = {
            event = data.zoneOutfits and 'ox_property:setOutfit' or 'ox_appearance:setOutfit',
            args = data.zoneOutfits and {
                property = currentZone.property,
                zoneId = currentZone.zoneId,
                slot = k,
                name = v,
                outfitNames = data.outfitNames
            } or {slot = k, name = v}
        }
    end

    local menu = {
        id = 'zone_wardrobe',
        title = data.zoneOutfits and ('%s - %s - Wardrobe'):format(currentZone.property, currentZone.name) or 'Personal Wardrobe',
        menu = 'zone_menu',
        options = options
    }

    lib.registerContext(menu)
    lib.showContext('zone_wardrobe')
end)

AddEventHandler('ox_property:setOutfit', function(data)
    if not checkCurrentZone(data) then return end

    lib.registerContext({
        id = 'set_outfit',
        title = data.name,
        menu = 'zone_wardrobe',
        options = {
            {
                title = 'Wear',
                serverEvent = 'ox_property:applyOutfit',
                args = {
                    property = currentZone.property,
                    zoneId = currentZone.zoneId,
                    slot = data.slot
                }
            },
            {
                title = 'Update',
                event = 'ox_property:saveOutfit',
                args = {
                    property = currentZone.property,
                    zoneId = currentZone.zoneId,
                    slot = data.slot,
                    name = data.name,
                    outfitNames = data.outfitNames
                }
            }
        }
    })

    lib.showContext('set_outfit')
end)

local function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

AddEventHandler('ox_property:saveOutfit', function(data)
    if not checkCurrentZone(data) then return end

    if data.slot == 'new' then
        data.slot = getTableSize(data.outfitNames) + 1
        local name = lib.inputDialog('New Zone Outfit', {'Outfit Name'})

        if name then
            local appearance = exports['fivem-appearance']:getPedAppearance(cache.ped)
            data.outfitNames[data.slot] = name[1]

            TriggerServerEvent('ox_property:saveOutfit', data, appearance)
        end
    else
        local input = lib.inputDialog(('Update %s'):format(data.name), {'Outfit Name (leave blank to delete)'})

        local appearance = exports['fivem-appearance']:getPedAppearance(cache.ped)
        data.outfitNames[data.slot] = input?[1]

        TriggerServerEvent('ox_property:saveOutfit', data, appearance)
    end
end)

RegisterNetEvent('ox_property:applyOutfit', function(appearance)
    if not appearance.model then appearance.model = 'mp_m_freemode_01' end

    if lib.progressCircle({
        duration = 3000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
        },
        anim = {
            dict = 'missmic4',
            clip = 'michael_tux_fidget'
        },
    }) then
        exports['fivem-appearance']:setPlayerAppearance(appearance)

        TriggerServerEvent('ox_appearance:save', appearance)
    end
end)