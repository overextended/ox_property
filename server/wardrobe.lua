local ox_appearance = exports.ox_appearance

lib.callback.register('ox_property:wardrobe', function(source, action, data)
    local permitted, msg = IsPermitted(source, data.property, data.componentId, 'wardrobe')

    if not permitted or permitted > 1 then
        return false, msg or 'not_permitted'
    end

    if action == 'get_outfits' then
        return {
            personalOutfits = ox_appearance:outfitNames(Ox.GetPlayer(source).charid),
            componentOutfits = ox_appearance:outfitNames(('%s:%s'):format(data.property, data.componentId))
        }
    elseif action == 'save_outfit' then
        ox_appearance:saveOutfit(('%s:%s'):format(data.property, data.componentId), data.appearance, data.slot, data.outfitNames)

        return true, 'outfit_saved'
    elseif action == 'apply_outfit' then
        return ox_appearance:loadOutfit(('%s:%s'):format(data.property, data.componentId), data.slot)
    end
end)
