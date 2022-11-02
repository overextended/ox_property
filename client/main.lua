local table = lib.table
local properties = {}
local components = {}
local currentZone = {}
local zoneContexts = {zone_menu = true, vehicle_list = true}
local zoneLists = {zone_menu = true, edit_permissions = true}

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

local function vehicleList(data)
    local options = {}

    for i = 1, #data.vehicles do
        local vehicle = data.vehicles[i]
        vehicle.data = data.vehicleData[vehicle.model]

        local zoneName = vehicle.stored and vehicle.stored:gsub('^%l', string.upper) or 'Unknown'
        local stored = vehicle.stored and vehicle.stored:find(':')

        if stored and vehicle.stored == ('%s:%s'):format(currentZone.property, currentZone.zoneId) then
            zoneName = 'Current Zone'
        end

        local action = zoneName == 'Current Zone' and 'Retrieve' or stored and 'Move' or 'Recover'

        options[('%s - %s'):format(vehicle.data.name, vehicle.plate)] = {
            metadata = {
                ['Action'] = action,
                ['Location'] = zoneName
            },
            onSelect = function(args)
                if args.action == 'Retrieve' then
                    TriggerServerEvent('ox_property:retrieveVehicle', {
                        property = currentZone.property,
                        zoneId = currentZone.zoneId,
                        plate = args.plate,
                        entities = getZoneEntities()
                    })
                else
                    TriggerServerEvent('ox_property:moveVehicle', {
                        property = currentZone.property,
                        zoneId = currentZone.zoneId,
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
        title = data.zoneOnly and ('%s - %s - Vehicles'):format(currentZone.property, currentZone.name) or 'All Vehicles',
        menu = 'zone_menu',
        options = options
    })

    lib.showContext('vehicle_list')
end

local zoneMenus = {
    management = function(currentZone)
        local displayData = lib.callback.await('ox_property:getDisplayData', 100, {
            property = currentZone.property,
            zoneId = currentZone.zoneId,
            players = lib.getNearbyPlayers(cache.coords, 10, false)
        })

        local property = properties[currentZone.property]
        local propertyComponents = {}
        local stashesList = {}
        for i = 1, #property.stashes do
            stashesList[#stashesList + 1] = property.stashes[i].name
            propertyComponents[#propertyComponents + 1] = property.stashes[i]
        end

        local zonesList = {}
        for i = 1, #property.zones do
            zonesList[#zonesList + 1] = property.zones[i].name
            propertyComponents[#propertyComponents + 1] = property.zones[i]
        end

        return {
            options = {
                {
                    label = currentZone.property,
                    description = 'Set permissions for the whole property'
                },
                {
                    label = next(stashesList) and 'Property stashes' or 'No stashes',
                    values = next(stashesList) and stashesList or nil,
                    description = 'View and edit stash permissions',
                    args = {
                        components = next(property.stashes) and property.stashes or nil
                    }
                },
                {
                    label = next(zonesList) and 'Property zones' or 'No zones',
                    values = next(zonesList) and zonesList or nil,
                    description = 'View and edit zone permissions',
                    args = {
                        components = next(property.zones) and property.zones or nil
                    }
                },
            },
            cb = function(selected, scrollIndex, args)
                local options = {}
                if selected == 1 then
                    local matching = true
                    if #propertyComponents > 1 then
                        for i = 1, #propertyComponents do
                            local component = propertyComponents[i]
                            if currentZone.owner ~= component.owner or not table.matches(currentZone.groups, component.groups) or currentZone.public ~= component.public then
                                matching = false
                                break
                            end
                        end
                    end

                    options[#options + 1] = {
                        label = matching and currentZone.property or 'Group permissions do not match',
                        description = matching and 'Edit all property permissions once' or 'Reset property group permissions',
                        args = {
                            matching = matching
                        }
                    }

                    options[#options + 1] = {
                        label = ('Owner: %s'):format(displayData.owner),
                        description = 'Edit owner',
                        args = {
                            editOwner = true
                        }
                    }

                    if matching then
                        options[#options + 1] = {
                            label = 'Groups',
                            description = 'Add group',
                            args = {
                                addGroup = true
                            }
                        }

                        if currentZone.groups then
                            for k, v in pairs(currentZone.groups) do
                                local group
                                for i = 1, #displayData.groups do
                                    group = displayData.groups[i]
                                    if group.name == k then
                                        break
                                    end
                                end

                                options[#options + 1] = {
                                    label = ('%s - %s'):format(group.label, group.grades[v]),
                                    description = 'Edit group',
                                    args = {
                                        group = group,
                                        editGroup = true
                                    }
                                }
                            end
                        end
                    end
                elseif args.components then
                    local component = args.components[scrollIndex]

                    options[#options + 1] = {
                        label = component.name,
                    }

                    options[#options + 1] = {
                        label = 'Groups',
                        description = 'Add group',
                        args = {
                            component = component,
                            addGroup = true
                        }
                    }

                    if component.groups then
                        for k, v in pairs(component.groups) do
                            local group
                            for i = 1, #displayData.groups do
                                group = displayData.groups[i]
                                if group.name == k then
                                    break
                                end
                            end

                            options[#options + 1] = {
                                label = ('%s - %s'):format(group.label, group.grades[v]),
                                description = 'Edit group',
                                args = {
                                    component = component,
                                    group = group,
                                    editGroup = true
                                }
                            }
                        end
                    end
                else
                    lib.showMenu('zone_menu')
                end
                lib.registerMenu({
                    id = 'edit_permissions',
                    title = 'Property Permissions',
                    options = options,
                    onClose = function(keyPressed)
                        if keyPressed == 'Backspace' then
                            lib.showMenu('zone_menu')
                        end
                    end
                },
                function(selected, scrollIndex, args)
                    if not args or args.matching then
                        lib.showMenu('edit_permissions')
                    elseif args.matching == false then
                        local confirm = lib.alertDialog({
                            header = 'Are You Sure?',
                            content = 'Continuing will wipe all group permissions for the property, leaving only the owner',
                            centered = true,
                            cancel = true
                        })

                        if confirm then
                            TriggerServerEvent('ox_property:resetPermitted', {
                                property = currentZone.property,
                                zoneId = currentZone.zoneId
                            })
                        end
                    elseif args.editOwner then
                        local input = lib.inputDialog(('Transfer Ownership of %s'):format(currentZone.property), {
                            { type = 'select', label = 'Owner type select', options = {
                                { value = 'groups', label = 'Group' },
                                { value = 'nearbyPlayers', label = 'Player' },
                            }},
                        })
                        Wait(100)
                        if input then
                            local select = {}
                            for i = 1, #displayData[input[1]] do
                                local option = displayData[input[1]][i]
                                if input[1] == 'groups' then
                                    select[#select + 1] = {
                                        value = option.name,
                                        label = option.label
                                    }
                                elseif input[1] == 'nearbyPlayers' then
                                    select[#select + 1] = {
                                        value = option.charid,
                                        label = option.name
                                    }
                                end
                            end

                            local input2 = lib.inputDialog(('Transfer Ownership of %s'):format(currentZone.property), {
                                {type = 'select', label = 'Owner select', options = select},
                            })
                            if input2 then
                                TriggerServerEvent('ox_property:updatePermitted', {
                                    property = currentZone.property,
                                    zoneId = currentZone.zoneId,
                                    change = {
                                        owner = input2[1]
                                    }
                                })
                            end
                        end
                    elseif args.addGroup then
                        local component = args.component or currentZone
                        local select = {}

                        for i = 1, #displayData.groups do
                            local option = displayData.groups[i]
                            if component.groups[option.name] then
                                select[#select + 1] = {
                                    value = i,
                                    label = option.label
                                }
                            end
                        end

                        local input = lib.inputDialog('Select Group to Permit', {
                            { type = 'select', label = 'Group', options = select},
                        })
                        Wait(100)

                        if input and next(input) then
                            local group = displayData.groups[tonumber(input[1])]
                            local select = {}
                            for i = 1, #group.grades do
                                select[#select + 1] = {
                                    value = i,
                                    label = group.grades[i]
                                }
                            end

                            local input2 = lib.inputDialog('Select Grade and Above to Permit', {
                                { type = 'select', label = 'Grade', options = select},
                            })

                            if input2 and next(input2) then
                                local componentType, componentId
                                if args.component then
                                    componentType = component.zoneId and 'zones' or 'stashes'
                                    componentId = component.zoneId or component.stashId
                                end

                                TriggerServerEvent('ox_property:updatePermitted', {
                                    property = currentZone.property,
                                    zoneId = currentZone.zoneId,
                                    componentType = componentType,
                                    componentId = componentId,
                                    change = {
                                        groups = {
                                            [group.name] = input2[1]
                                        }
                                    }
                                })
                            end
                        end
                    elseif args.editGroup then
                        local component = args.component or currentZone
                        local select = {
                            {
                                value = 0,
                                label = 'Remove'
                            }
                        }
                        for i = 1, #args.group.grades do
                            select[#select + 1] = {
                                value = i,
                                label = args.group.grades[i]
                            }
                        end

                        local input = lib.inputDialog('Edit Permitted Grade', {
                            { type = 'select', label = 'Grade', options = select},
                        })

                        if input and next(input) then
                            local componentType, componentId
                            if args.component then
                                componentType = component.zoneId and 'zones' or 'stashes'
                                componentId = component.zoneId or component.stashId
                            end

                            TriggerServerEvent('ox_property:updatePermitted', {
                                property = currentZone.property,
                                zoneId = currentZone.zoneId,
                                componentType = componentType,
                                componentId = componentId,
                                change = {
                                    groups = {
                                        [args.group.name] = input[1]
                                    }
                                }
                            })
                        end
                    end
                end)

                lib.showMenu('edit_permissions')
            end
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
                onSelect = function()
                    if cache.seat == -1 then
                        TriggerServerEvent('ox_property:storeVehicle', {
                            property = currentZone.property,
                            zoneId = currentZone.zoneId,
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
            options[#options].onSelect = vehicleList
            options[#options].args = {
                vehicles = allVehicles,
                vehicleData = vehicleData
            }
        end

        return {options = options}, 'context'
    end,
    wardrobe = function(currentZone)
        local options = {}
        local personalOutfits, zoneOutfits = lib.callback.await('ox_property:getOutfits', 100, {
            property = currentZone.property,
            zoneId = currentZone.zoneId
        })

        if currentZone.outfits then
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
                        type = 'stash',
                        name = ('%s:%s'):format(k, i),
                        nearby = nearbyPoint,
                    })
                else
                    local onEnter = function(self)
                        currentZone = self
                        lib.notify({
                            title = self.propertyLabel,
                            description = self.name,
                            duration = 5000,
                            position = 'top'
                        })
                    end

                    local onExit = function(self)
                        if currentZone.property == self.property and currentZone.zoneId == self.zoneId then
                            table.wipe(currentZone)
                            if zoneContexts[lib.getOpenContextMenu()] then lib.hideContext() end
                            if zoneLists[lib.getOpenMenu()] then lib.hideMenu() end
                        end
                    end

                    local zoneData
                    if component.points then
                        zoneData = lib.zones.poly({
                            points = component.points,
                            thickness = component.thickness,

                            onEnter = onEnter,
                            onExit = onExit,

                            property = k,
                            propertyLabel = v.label,
                            zoneId = i,
                            name = component.name,
                            type = component.type,
                            owner = component.owner,
                            groups = component.groups,
                            public = component.public,
                        })
                    elseif component.box then
                        zoneData = lib.zones.box({
                            coords = component.box,
                            rotation = component.rotation,
                            size = component.size or vec3(2),

                            onEnter = onEnter,
                            onExit = onExit,

                            property = k,
                            propertyLabel = v.label,
                            zoneId = i,
                            name = component.name,
                            type = component.type,
                            owner = component.owner,
                            groups = component.groups,
                            public = component.public,
                        })
                    elseif component.sphere then
                        zoneData = lib.zones.sphere({
                            coords = component.sphere,
                            radius = component.radius,

                            onEnter = onEnter,
                            onExit = onExit,

                            property = k,
                            propertyLabel = v.label,
                            zoneId = i,
                            name = component.name,
                            type = component.type,
                            owner = component.owner,
                            groups = component.groups,
                            public = component.public,
                        })
                    end
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
    return {property = currentZone.property, zoneId = currentZone.zoneId, name = currentZone.name}
end)

AddStateBagChangeHandler('Properties', 'global', function(bagName, key, value, reserved, replicated)
    loadProperties(value)
end)

local function isPermitted(failOnPublic)
    local property = properties[currentZone.property]
    if player.hasGroup(currentZone.groups) then return true end

    if property.owner == player.charid then return true end

    if currentZone.public and not failOnPublic then return 'public' end

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
        if not isPermitted(false) then return end

        local data, menuType = zoneMenus[currentZone.type]({
            property = currentZone.property,
            zoneId = currentZone.zoneId,
            owner = currentZone.owner,
            groups = currentZone.groups,
            public = currentZone.public
        })

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