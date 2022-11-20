RegisterComponentAction('wardrobe', function(component)
    local options = {}
    local data, msg = lib.callback.await('ox_property:wardrobe', 100, 'get_outfits', {
        property = component.property,
        componentId = component.componentId
    })

    if msg then
        lib.notify({title = msg, type = data and 'success' or 'error'})
    end
    if not data then return end

    local personalOutfits, componentOutfits in data

    if component.outfits then
        options[#options + 1] = {
            title = 'Zone wardrobe',
            event = 'ox_property:outfits',
            args = {
                property = component.property,
                componentId = component.componentId,
                outfitNames = componentOutfits or {},
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
                outfitNames = componentOutfits or {}
            }
        }
    end

    options[#options + 1] = {
        title = 'Personal wardrobe',
        event = 'ox_property:outfits',
        args = {
            property = component.property,
            componentId = component.componentId,
            outfitNames = personalOutfits or {}
        }
    }

    options[#options + 1] = {
        title = 'Save new personal outfit',
        arrow = true,
        event = 'ox_appearance:saveOutfit',
        args = {slot = 'new', name = ''}
    }

    return {options = options}, 'contextMenu'
end, {'All access'})

local function checkCurrentZone(data)
    if CurrentZone?.property == data.property and CurrentZone?.componentId == data.componentId then return true end

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
                property = CurrentZone.property,
                componentId = CurrentZone.componentId,
                slot = k,
                name = v,
                outfitNames = data.outfitNames
            } or {slot = k, name = v}
        }
    end

    local menu = {
        id = 'zone_wardrobe',
        title = data.zoneOutfits and ('%s - %s - Wardrobe'):format(CurrentZone.property, CurrentZone.name) or 'Personal Wardrobe',
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
                onSelect = function(args)
                    local data, msg = lib.callback.await('ox_property:wardrobe', 100, 'apply_outfit', {
                        property = args.property,
                        componentId = args.componentId,
                        slot = args.slot
                    })

                    if msg then
                        lib.notify({title = msg, type = data and 'success' or 'error'})
                    end
                    if not data then return end

                    TriggerEvent('ox_property:applyOutfit', data)
                end,
                args = {
                    property = CurrentZone.property,
                    componentId = CurrentZone.componentId,
                    slot = data.slot
                }
            },
            {
                title = 'Update',
                event = 'ox_property:saveOutfit',
                args = {
                    property = CurrentZone.property,
                    componentId = CurrentZone.componentId,
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
