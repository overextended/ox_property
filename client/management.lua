local permissionData

---@param selected number
---@param secondary number
---@param args any
local function updatePermissionData(selected, secondary, args)
    permissionData[args.section] = permissionData[args.section] or {}
    if args.section == 'players' then
        permissionData[args.section][args.id] = secondary
    elseif args.section == 'everyone' then
        permissionData[args.section] = secondary
    elseif args.section == 'doors' then
        permissionData[args.section][args.id] = secondary
    else
        permissionData[args.section][args.id] = secondary - 1
    end
end

---@param keyPressed 'Backspace' | 'Escape'
local function onClose(keyPressed)
    if keyPressed == 'Backspace' then
        lib.showMenu('component_menu')
    end
end

RegisterComponentAction('management', function(component)
    local displayData, msg = lib.callback.await('ox_property:management', 100, 'get_data', {
        property = component.property,
        componentId = component.componentId
    })

    if msg then
        lib.notify({title = msg, type = displayData and 'success' or 'error'})
    end
    if not displayData then return end

    local property = Properties[component.property]
    local variables = PropertyVariables[property.name]
    local values = {locale("edit_componet_access"), locale("edit_door_acces"), locale("edit_menbers"), locale("delete_level")}
    local options = {
        {
            label = locale("owner", variables.ownerName or locale("none")),
            description = locale("set_property_owner")
        },
        {
            label = locale("group", variables.ownerName or locale("none")),
            description = locale("set_property_group")
        }
    }

    for i = 1, #variables.permissions do
        options[#options + 1] = {
            label = locale("level",i),
            values = values
        }
    end

    options[#options + 1] = {
        label = locale("create_new_level"),
    }

    return {
        options = options,
        cb = function(selected, scrollIndex, args)
            permissionData = {}

            local level = scrollIndex and selected - 2 or #variables.permissions + 1
            local permissionLevel = variables.permissions[level]
            local title = values[scrollIndex] or locale("new_level")

            if scrollIndex then
                local options = {
                    {label = locale("save_level",level)}
                }

                if level == 1 and scrollIndex ~= 3 then
                    lib.notify({title =locale("action_not_possible_for_level"), type = 'error'})
                    lib.showMenu('component_menu')
                    return
                elseif scrollIndex == 1 then
                    for i = 1, #property.components do
                        local component = property.components[i]

                        options[#options + 1] = {
                            label = component.name,
                            values = {'None', table.unpack(Permissions[component.type])},
                            defaultIndex = permissionLevel.components and permissionLevel.components[i] and permissionLevel.components[i] + 1 or 1,
                            description = locale("type", component.type:gsub('^%l', string.upper)),
                            close = false,
                            args = {
                                section = 'components',
                                id = i
                            }
                        }
                    end
                elseif scrollIndex == 2 then
                    for i = 1, #displayData.doors do
                        local door = displayData.doors[i]

                        options[#options + 1] = {
                            label = door.name:gsub(property.name, ''),
                            checked = permissionLevel.doors and permissionLevel.doors[door.id] or false,
                            close = false,
                            args = {
                                section = 'doors',
                                id = door.id
                            }
                        }
                    end
                elseif scrollIndex == 3 then
                    options[#options + 1] = {
                        label = locale("everyone"),
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
                            checked = permissionLevel.players and permissionLevel.players[player.charId] or false,
                            close = false,
                            args = {
                                section = 'players',
                                id = player.charId
                            }
                        }
                    end
                elseif scrollIndex == 4 then
                    local delete = lib.alertDialog({
                        header = locale("please_confirm"),
                        content = locale("are_you_sure_delete_permission_level"),
                        centered = true,
                        cancel = true
                    })

                    if delete == 'confirm' then
                        local response, msg = lib.callback.await('ox_property:management', 100, 'delete_permission', {
                            property = component.property,
                            componentId = component.componentId,
                            level = level
                        })

                        if msg then
                            lib.notify({title = msg, type = response and 'success' or 'error'})
                        end
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
                    if next(permissionData) then
                        local response, msg = lib.callback.await('ox_property:management', 100, 'update_permission', {
                            property = component.property,
                            componentId = component.componentId,
                            permissions = permissionData,
                            level = level
                        })

                        if msg then
                            lib.notify({title = msg, type = response and 'success' or 'error'})
                        end
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
                                id = player.charId,
                                label = player.name
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
                                id = group.name,
                                label = group.label
                            }
                        }
                    end
                end

                lib.registerMenu({
                    id = 'set_property_value',
                    title = locale("set_property",value:gsub('^%l', string.upper)),
                    options = options,
                    onClose = onClose
                },
                function(selected, scrollIndex, args)
                    local setValue = lib.alertDialog({
                        header = locale("please_confirm"),
                        content = locale("are_you_sure_set_property", value, args.label),
                        centered = true,
                        cancel = true
                    })

                    if setValue == 'confirm' then
                        local response, msg = lib.callback.await('ox_property:management', 100, 'set_value', {
                            property = component.property,
                            componentId = component.componentId,
                            owner = value == 'owner' and (args?.id or 0),
                            group = value == 'group' and (args?.id or 0)
                        })

                        if msg then
                            lib.notify({title = msg, type = response and 'success' or 'error'})
                        end
                    end
                end)

                lib.showMenu('set_property_value')
            else
                local options = {
                    {label = locale("continue_level", level)}
                }
                for i = 1, #property.components do
                    local component = property.components[i]

                    options[#options + 1] = {
                        label = component.name,
                        values = {'None', table.unpack(Permissions[component.type])},
                        description = locale("type", component.type:gsub('^%l', string.upper)),
                        close = false,
                        args = {
                            section = 'components',
                            id = i
                        }
                    }
                end

                lib.registerMenu({
                    id = 'new_level_components',
                    title = locale("set_component_access"),
                    options = options,
                    onSideScroll = updatePermissionData,
                    onClose = onClose
                },
                function(selected, scrollIndex, args)
                    local options = {
                        {label = locale("continue_level", level)}
                    }
                    for i = 1, #displayData.doors do
                        local door = displayData.doors[i]

                        options[#options + 1] = {
                            label = door.name,
                            checked = false,
                            close = false,
                            args = {
                                section = 'doors',
                                id = door.id
                            }
                        }
                    end

                    lib.registerMenu({
                        id = 'new_level_doors',
                        title = locale("set_door_access"),
                        options = options,
                        onSideScroll = updatePermissionData,
                        onCheck = updatePermissionData,
                        onClose = onClose
                    },
                    function(selected, scrollIndex, args)
                        local options = {
                            {label = locale ("finish_level", level)}
                        }

                        options[#options + 1] = {
                            label = locale("everyone"),
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
                                    id = player.charId
                                }
                            }
                        end

                        lib.registerMenu({
                            id = 'new_level_members',
                            title = locale("set_members"),
                            options = options,
                            onSideScroll = updatePermissionData,
                            onCheck = updatePermissionData,
                            onClose = onClose
                        },
                        function(selected, scrollIndex, args)
                            local response, msg = lib.callback.await('ox_property:management', 100, 'update_permission', {
                                property = component.property,
                                componentId = component.componentId,
                                permissions = permissionData,
                                level = level
                            })

                            if msg then
                                lib.notify({title = msg, type = response and 'success' or 'error'})
                            end
                        end)

                        lib.showMenu('new_level_members')
                    end)

                    lib.showMenu('new_level_doors')
                end)

                lib.showMenu('new_level_components')
            end
        end
    }, 'listMenu'
end, {locale('all_access')})

RegisterMenu({'edit_level', 'set_property_value', 'new_level_components', 'new_level_doors', 'new_level_members'}, 'listMenu')
