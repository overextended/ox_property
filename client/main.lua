local table = lib.table
local properties = {}
local components = {}
local currentZone = nil
local vehicleData = Ox.GetVehicleData()
local menus = {
    contextMenus = {component_menu = true, vehicle_list = true},
    listMenus = {
        component_menu = true,
        edit_level = true,
        set_property_value = true,
        new_level_access = true,
        new_level_members = true
    }
}

local permissions = {
    management = {
        'All access'
    },
    parking = {
        'All access'
    },
    stash = {
        'All access'
    },
    wardrobe = {
        'All access'
    },
}

local function getZoneEntities()
    local entities = {}
    local peds = GetGamePool('CPed')
    for i = 1, #peds do
        local ped = peds[i]
        local pedCoords = GetEntityCoords(ped)
        if currentZone and currentZone:contains(pedCoords) then
            entities[#entities + 1] = pedCoords
        end
    end

    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local vehicleCoords = GetEntityCoords(vehicle)
        if currentZone and currentZone:contains(vehicleCoords) then
            entities[#entities + 1] = vehicleCoords
        end
    end

    return entities
end
exports('getZoneEntities', getZoneEntities)

local function vehicleList(data)
    local options = {}

    for i = 1, #data.vehicles do
        local vehicle = data.vehicles[i]
        vehicle.data = vehicleData[vehicle.model]

        local location = 'Unknown'
        local stored = vehicle.stored and vehicle.stored:find(':')

        if stored then
            if vehicle.stored == ('%s:%s'):format(data.component.property, data.component.componentId) then
                location = 'Current Zone'
            else
                local propertyName, componentId = string.strsplit(':', vehicle.stored)
                if properties[propertyName] then
                    location = ('%s:%s'):format(properties[propertyName].label, componentId)
                end
            end
        end

        local action = location == 'Current Zone' and 'Retrieve' or stored and 'Move' or 'Recover'

        options[('%s - %s'):format(vehicle.data.name, vehicle.plate)] = {
            metadata = {
                ['Action'] = action,
                ['Location'] = location
            },
            onSelect = function(args)
                if args.action == 'Retrieve' then
                    TriggerServerEvent('ox_property:retrieveVehicle', {
                        property = data.component.property,
                        componentId = data.component.componentId,
                        plate = args.plate,
                        entities = getZoneEntities()
                    })
                else
                    TriggerServerEvent('ox_property:moveVehicle', {
                        property = data.component.property,
                        componentId = data.component.componentId,
                        plate = args.plate
                    })
                end
            end,
            args = {
                plate = vehicle.plate,
                action = action
            }
        }
    end

    lib.registerContext({
        id = 'vehicle_list',
        title = data.zoneOnly and ('%s - %s - Vehicles'):format(properties[data.component.property].label, data.component.name) or 'All Vehicles',
        menu = 'component_menu',
        options = options
    })

    lib.showContext('vehicle_list')
end

local permissionData
local function updatePermissionData(selected, secondary, args)
    permissionData[args.section] = permissionData[args.section] or {}
    if args.section == 'players' then
        permissionData[args.section][args.id] = secondary
    elseif args.section == 'everyone' then
        permissionData[args.section] = secondary
    else
        permissionData[args.section][args.id] = secondary - 1
    end
end

local function onClose(keyPressed)
    if keyPressed == 'Backspace' then
        lib.showMenu('component_menu')
    end
end

local componentActions = {
    management = function(component)
        local displayData = lib.callback.await('ox_property:getDisplayData', 100, {
            property = component.property,
            componentId = component.componentId
        })

        local property = properties[component.property]
        local values = {'Edit Access', 'Edit Members', 'Delete Level'}
        local options = {
            {
                label = ('Owner: %s'):format(property.ownerName or 'None'),
                description = 'Set Property Owner'
            },
            {
                label = ('Group: %s'):format(property.groupName or 'None'),
                description = 'Set Property Group'
            }
        }

        for i = 1, #property.permissions do
            options[#options + 1] = {
                label = ('Level %s'):format(i),
                values = values
            }
        end

        options[#options + 1] = {
            label = 'Create New Level',
        }

        return {
            options = options,
            cb = function(selected, scrollIndex, args)
                permissionData = {}

                local level = scrollIndex and selected - 2 or #property.permissions + 1
                local permissionLevel = property.permissions[level]
                local title = values[scrollIndex] or 'New Level'

                if scrollIndex then
                    local options = {
                        {label = ('Save Level %s'):format(level)}
                    }

                    if level == 1 and scrollIndex ~= 2 then
                        lib.notify({title = 'Action not possible for this permission level', type = 'error'})
                        lib.showMenu('component_menu')
                        return
                    elseif scrollIndex == 1 then
                        for i = 1, #property.components do
                            local component = property.components[i]

                            options[#options + 1] = {
                                label = component.name,
                                values = {'None', table.unpack(permissions[component.type])},
                                defaultIndex = permissionLevel.components[i] and permissionLevel.components[i] + 1 or 1,
                                description = ('Type: %s'):format(component.type:gsub('^%l', string.upper)),
                                close = false,
                                args = {
                                    section = 'components',
                                    id = i
                                }
                            }
                        end
                    elseif scrollIndex == 2 then
                        options[#options + 1] = {
                            label = 'Everyone',
                            checked = permissionLevel.everyone or false,
                            close = false,
                            args = {section = 'everyone'}
                        }

                        for i = 1, #displayData.groups do
                            local group = displayData.groups[i]

                            options[#options + 1] = {
                                label = group.label,
                                values = {'None', table.unpack(group.grades)},
                                defaultIndex = permissionLevel.groups and permissionLevel.groups[group.name] and permissionLevel.groups[group.name] + 1 or 1,
                                close = false,
                                args = {
                                    section = 'groups',
                                    id = group.name
                                }
                            }
                        end

                        for i = 1, #displayData.nearbyPlayers do
                            local player = displayData.nearbyPlayers[i]

                            options[#options + 1] = {
                                label = player.name,
                                checked = permissionLevel[player.charid] or false,
                                close = false,
                                args = {
                                    section = 'players',
                                    id = player.charid
                                }
                            }
                        end
                    elseif scrollIndex == 3 then
                        local confirm = lib.alertDialog({
                            header = 'Please Confirm',
                            content = 'Are you sure you want to delete this permission level?',
                            centered = true,
                            cancel = true
                        })

                        if confirm then
                            TriggerServerEvent('ox_property:deletePermissionLevel', {
                                property = component.property,
                                componentId = component.componentId,
                                level = level
                            })
                        end

                        return
                    end

                    lib.registerMenu({
                        id = 'edit_level',
                        title = title,
                        options = options,
                        onSideScroll = updatePermissionData,
                        onCheck = updatePermissionData,
                        onClose = onClose
                    },
                    function(selected, scrollIndex, args)
                        if not scrollIndex then
                            TriggerServerEvent('ox_property:updatePermissions', {
                                property = component.property,
                                componentId = component.componentId,
                                permissions = permissionData,
                                level = level
                            })
                        end
                    end)

                    lib.showMenu('edit_level')
                elseif selected == 1 or selected == 2 then
                    local value
                    local options = {
                        {label = 'None'}
                    }

                    if selected == 1 then
                        value = 'owner'
                        for i = 1, #displayData.nearbyPlayers do
                            local player = displayData.nearbyPlayers[i]

                            options[#options + 1] = {
                                label = player.name,
                                args = {
                                    id = player.charid
                                }
                            }
                        end
                    elseif selected == 2 then
                        value = 'group'
                        for i = 1, #displayData.groups do
                            local group = displayData.groups[i]

                            options[#options + 1] = {
                                label = group.label,
                                args = {
                                    id = group.name
                                }
                            }
                        end
                    end

                    lib.registerMenu({
                        id = 'set_property_value',
                        title = ('Set Property %s'):format(value:gsub('^%l', string.upper)),
                        options = options,
                        onClose = onClose
                    },
                    function(selected, scrollIndex, args)
                        TriggerServerEvent('ox_property:setPropertyValue', {
                            property = component.property,
                            componentId = component.componentId,
                            owner = value == 'owner' and (args?.id or 0),
                            group = value == 'group' and (args?.id or 0)
                        })
                    end)

                    lib.showMenu('set_property_value')
                else
                    local options = {
                        {label = ('Continue Level %s'):format(level)}
                    }
                    for i = 1, #property.components do
                        local component = property.components[i]

                        options[#options + 1] = {
                            label = component.name,
                            values = {'None', table.unpack(permissions[component.type])},
                            description = ('Type: %s'):format(component.type:gsub('^%l', string.upper)),
                            close = false,
                            args = {
                                section = 'components',
                                id = i
                            }
                        }
                    end

                    lib.registerMenu({
                        id = 'new_level_access',
                        title = 'Set Access',
                        options = options,
                        onSideScroll = updatePermissionData,
                        onClose = onClose
                    },
                    function(selected, scrollIndex, args)
                        if not scrollIndex then
                            local options = {
                                {label = ('Finish Level %s'):format(level)}
                            }

                            options[#options + 1] = {
                                label = 'Everyone',
                                checked = false,
                                close = false,
                                args = {section = 'everyone'}
                            }

                            for i = 1, #displayData.groups do
                                local group = displayData.groups[i]

                                options[#options + 1] = {
                                    label = group.label,
                                    values = {'None', table.unpack(group.grades)},
                                    close = false,
                                    args = {
                                        section = 'groups',
                                        id = group.name
                                    }
                                }
                            end

                            for i = 1, #displayData.nearbyPlayers do
                                local player = displayData.nearbyPlayers[i]

                                options[#options + 1] = {
                                    label = player.name,
                                    checked = false,
                                    close = false,
                                    args = {
                                        section = 'players',
                                        id = player.charid
                                    }
                                }
                            end

                            lib.registerMenu({
                                id = 'new_level_members',
                                title = 'Set Members',
                                options = options,
                                onSideScroll = updatePermissionData,
                                onCheck = updatePermissionData,
                                onClose = onClose
                            },
                            function(selected, scrollIndex, args)
                                if not scrollIndex then
                                    TriggerServerEvent('ox_property:updatePermissions', {
                                        property = component.property,
                                        componentId = component.componentId,
                                        permissions = permissionData,
                                        level = level
                                    })
                                end
                            end)

                            lib.showMenu('new_level_members')
                        end
                    end)

                    lib.showMenu('new_level_access')
                end
            end
        }, 'listMenu'
    end,
    parking = function(component)
        local options = {}
        local allVehicles, zoneVehicles = lib.callback.await('ox_property:getVehicleList', 100, {
            property = component.property,
            componentId = component.componentId
        })

        if cache.seat == -1 then
            options[#options + 1] = {
                title = 'Store Vehicle',
                onSelect = function()
                    if cache.seat == -1 then
                        TriggerServerEvent('ox_property:storeVehicle', {
                            property = component.property,
                            componentId = component.componentId,
                            properties = lib.getVehicleProperties(cache.vehicle)
                        })
                    else
                        lib.notify({title = "You are not in the driver's seat", type = 'error'})
                    end
                end
            }
        end

        if zoneVehicles and next(zoneVehicles) then
            options[#options + 1] = {
                title = 'Open Location',
                description = 'View your vehicles at this location',
                metadata = {['Vehicles'] = #zoneVehicles},
                onSelect = vehicleList,
                args = {
                    component = component,
                    vehicles = zoneVehicles,
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
            options[#options].onSelect = vehicleList
            options[#options].args = {
                component = component,
                vehicles = allVehicles
            }
        end

        return {options = options}, 'contextMenu'
    end,
    stash = function(component)
        return {fun = function() exports.ox_inventory:openInventory('stash', component.name) end}, 'function'
    end,
    wardrobe = function(component)
        local options = {}
        local personalOutfits, zoneOutfits = lib.callback.await('ox_property:getOutfits', 100, {
            property = component.property,
            componentId = component.componentId
        })

        if component.outfits then
            options[#options + 1] = {
                title = 'Zone wardrobe',
                event = 'ox_property:outfits',
                args = {
                    property = component.property,
                    componentId = component.componentId,
                    outfitNames = zoneOutfits,
                    zoneOutfits = true
                }
            }

            options[#options + 1] = {
                title = 'Save new zone outfit',
                arrow = true,
                event = 'ox_property:saveOutfit',
                args = {
                    property = component.property,
                    componentId = component.componentId,
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
                property = component.property,
                componentId = component.componentId,
                outfitNames = personalOutfits
            }
        }

        options[#options + 1] = {
            title = 'Save new personal outfit',
            arrow = true,
            event = 'ox_appearance:saveOutfit',
            args = {slot = 'new', name = ''}
        }

        return {options = options}, 'contextMenu'
    end
}

exports('registerComponentAction', function(componentType, action, subMenus, actionPermissions)
    componentActions[componentType] = action
    permissions[componentType] = actionPermissions

    if type(subMenus) == 'table' then
        for menuType, menu in pairs(subMenus) do
            if type(menu) == 'table' then
                for i = 1, #menu do
                    menus[menuType][menu[i]] = true
                end
            elseif type(menu) == 'string' then
                menus[menuType][menu] = true
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
        if (not properties[k] or v.refresh) and components[k] then
            if components[k].blip then
                RemoveBlip(components[k].blip)
            end

            for i = 1, #components[k] do
                components[k][i]:remove()
            end
            v.refresh = nil
        elseif properties[k] then
            create = false
        end

        if create then
            properties[k] = v
            components[k] = {}

            if v.blip and v.sprite then
                local x, y, z in v.blip
                local blip = AddBlipForCoord(x, y, z)
                components[k].blip = blip

                SetBlipSprite(blip, v.sprite)
                SetBlipDisplay(blip, 2)
                SetBlipShrink(blip, true)
                SetBlipAsShortRange(blip, true)

                AddTextEntry(k, v.label)
                BeginTextCommandSetBlipName(k)
                EndTextCommandSetBlipName(blip)
            end

            for i = 1, #v.components do
                local component = v.components[i]

                if component.point then
                    components[k][i] = lib.points.new(component.point, 16, {
                        property = k,
                        componentId = i,
                        type = component.type,
                        name = ('%s:%s'):format(k, i),
                        nearby = nearbyPoint,
                    })
                else
                    local onEnter = function(self)
                        currentZone = self
                        lib.notify({
                            title = properties[self.property].label,
                            description = self.name,
                            duration = 5000,
                            position = 'top'
                        })
                    end

                    local onExit = function(self)
                        if currentZone?.property == self.property and currentZone?.componentId == self.componentId then
                            currentZone = nil
                            if menus.contextMenus[lib.getOpenContextMenu()] then lib.hideContext() end
                            if menus.listMenus[lib.getOpenMenu()] then lib.hideMenu() end
                        end
                    end

                    local zoneData = lib.zones[component.points and 'poly' or component.box and 'box' or component.sphere and 'sphere']({
                        points = component.points,
                        thickness = component.thickness,
                        coords = component.box or component.sphere,
                        rotation = component.rotation,
                        size = component.size or vec3(2),
                        radius = component.radius,

                        onEnter = onEnter,
                        onExit = onExit,

                        property = k,
                        componentId = i,
                        name = component.name,
                        type = component.type
                    })

                    components[k][i] = zoneData

                    if component.disableGenerators then
                        local point1, point2
                        if component.sphere then
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
    return {property = currentZone?.property, componentId = currentZone?.componentId}
end)

AddStateBagChangeHandler('Properties', 'global', function(bagName, key, value, reserved, replicated)
    loadProperties(value)
end)

local function isPermitted(component)
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

    lib.notify({title = 'Permission Denied', type = 'error'})
    return false
end
exports('isPermitted', isPermitted)

RegisterCommand('triggerComponent', function()
    if menus.contextMenus[lib.getOpenContextMenu()] then lib.hideContext() return end
    if menus.listMenus[lib.getOpenMenu()] then lib.hideMenu() return end
    if IsPauseMenuActive() or IsNuiFocused() then return end

    local component
    local closestPoint = lib.points.closest()
    if closestPoint and closestPoint.currentDistance < 1 and isPermitted(closestPoint) then
        component = closestPoint
    elseif currentZone and isPermitted(currentZone) then
        component = currentZone
    else
        return
    end

    local data, actionType = componentActions[component.type]({
        property = component.property,
        componentId = component.componentId,
        name = component.name,
        type = component.type
    })

    if actionType == 'function' then
        data.fun(data.args)
    elseif actionType == 'event' then
        TriggerEvent(data.event, data.args)
    elseif actionType == 'serverEvent' then
        TriggerServerEvent(data.serverEvent, data.args)
    elseif actionType == 'listMenu' then
        lib.registerMenu({
            id = 'component_menu',
            title = data.title or component.name,
            options = data.options,
            position = data.position or 'top-left',
            disableInput = data.disableInput,
            canClose = data.canClose,
            onClose = data.onClose,
            onSelected = data.onSelected,
            onSideScroll = data.onSideScroll,
            onCheck = data.onCheck,
        }, data.cb)
        lib.showMenu('component_menu')
    elseif actionType == 'contextMenu' then
        local menu = {
            id = 'component_menu',
            title = data.title or ('%s - %s'):format(properties[component.property].label, component.name),
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
        lib.showContext('component_menu')
    end
end)
RegisterKeyMapping('triggerComponent', 'Trigger Component', 'keyboard', 'e')

local function checkCurrentZone(data)
    if currentZone?.property == data.property and currentZone?.componentId == data.componentId then return true end

    lib.notify({title = 'Zone Mismatch', type = 'error'})
    return false
end
exports('checkCurrentZone', checkCurrentZone)

RegisterNetEvent('ox_property:outfits', function(data)
    if not checkCurrentZone(data) then return end

    local options = {}

    for k, v in pairs(data.outfitNames) do
        options[v] = {
            event = data.zoneOutfits and 'ox_property:setOutfit' or 'ox_appearance:setOutfit',
            args = data.zoneOutfits and {
                property = currentZone.property,
                componentId = currentZone.componentId,
                slot = k,
                name = v,
                outfitNames = data.outfitNames
            } or {slot = k, name = v}
        }
    end

    local menu = {
        id = 'zone_wardrobe',
        title = data.zoneOutfits and ('%s - %s - Wardrobe'):format(currentZone.property, currentZone.name) or 'Personal Wardrobe',
        menu = 'component_menu',
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
                    componentId = currentZone.componentId,
                    slot = data.slot
                }
            },
            {
                title = 'Update',
                event = 'ox_property:saveOutfit',
                args = {
                    property = currentZone.property,
                    componentId = currentZone.componentId,
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
