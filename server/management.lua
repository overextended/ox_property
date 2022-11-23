local function getManagementData(player)
    local data = {
        groups = MySQL.query.await('SELECT name, label, grades FROM ox_groups'),
        nearbyPlayers = {
            {
                name = player.name,
                charid = player.charid
            }
        }
    }

    for i = 1, #data.groups do
        local group = data.groups[i]
        group.grades = json.decode(group.grades)
    end

    local playerPos = player.getCoords()
    local players = Ox.GetPlayers()
    local len = #players
    for i = 1, len do
        local nearbyPlayer = players[i]
        if nearbyPlayer.source ~= player.source and #(nearbyPlayer.getCoords() - playerPos) < 10 then
            data.nearbyPlayers[#data.nearbyPlayers + 1] = {
                name = nearbyPlayer.name,
                charid = nearbyPlayer.charid
            }
        end
    end

    return data
end

local function updateProperty(property)
    Properties[property.name] = property
    GlobalState[('property.%s'):format(property.name)] = {
        name = property.name,
        permissions = property.permissions,
        owner = property.owner,
        ownerName = property.ownerName,
        group = property.group,
        groupName = property.groupName
    }
end

local function updatePermissionLevel(property, data)
    local level = property.permissions[data.level] or {}

    if data.level == 1 then
        data.permissions.components = nil
    end

    for k, v in pairs(data.permissions) do
        if k == 'players' then
            for key, value in pairs(v) do
                level[key] = value or nil
            end
        elseif k == 'everyone' then
            level.everyone = v or nil
        else
            for key, value in pairs(v) do
                level[k] = level[k] or {}
                level[k][key] = value ~= 0 and value or nil
            end
        end
    end
    property.permissions[data.level] = level

    MySQL.update('UPDATE ox_property SET permissions = ? WHERE name = ?', {json.encode(property.permissions), property.name})

    updateProperty(property)

    return true, 'permission_level_updated'
end

local function deletePermissionLevel(property, level)
    if level == 1 then
        return false, 'action_not_allowed'
    end

    property.permissions[level] = nil

    MySQL.update('UPDATE ox_property SET permissions = ? WHERE name = ?', {json.encode(property.permissions), property.name})

    updateProperty(property)

    return true, 'permission_level_deleted'
end

local function setPropertyValue(property, data)
    if data.owner then
        local owner = data.owner ~= 0 and data.owner or nil
        MySQL.update('UPDATE ox_property SET owner = ? WHERE name = ?', {owner, property.name})

        property.owner = owner
        property.ownerName = owner and MySQL.scalar.await('SELECT CONCAT(characters.firstname, " ", characters.lastname) FROM characters WHERE charid = ?', {owner}) or nil
    elseif data.group then
        local group = data.group ~= 0 and data.group or nil
        MySQL.update('UPDATE ox_property SET `group` = ? WHERE name = ?', {group, property.name})

        property.group = group
        property.groupName = group and GlobalState[('group.%s'):format(group)].label or nil
    end

    updateProperty(property)

    return true, 'property_value_set'
end

lib.callback.register('ox_property:management', function(source, action, data)
    local permitted, msg = IsPermitted(source, data.property, data.componentId, 'management')

    if not permitted or permitted > 1 then
        return false, msg or 'not_permitted'
    end

    if action == 'get_data' then
        return getManagementData(Ox.GetPlayer(source))
    end

    local property = Properties[data.property]
    if action == 'update_permission' then
        return updatePermissionLevel(property, data)
    elseif action == 'delete_permission' then
        return deletePermissionLevel(property, data.level)
    elseif action == 'set_value' then
        return setPropertyValue(property, data)
    end

    return false, 'invalid_action'
end)
