---@param property string
---@param player OxPlayer
---@return OxPropertyManagementData data
local function getManagementData(property, player)
    local data = {
        groups = MySQL.query.await('SELECT name, label, grades FROM ox_groups'),
        doors = MySQL.query.await('SELECT id, name, data FROM ox_doorlock WHERE name LIKE ?', {('%s%%'):format(property)}),
        nearbyPlayers = {
            {
                name = player.name,
                charId = player.charId
            }
        }
    }

    for i = 1, #data.groups do
        local group = data.groups[i]
        group.grades = json.decode(group.grades)
    end

    for i = 1, #data.doors do
        local door = data.doors[i]
        door.data = json.decode(door.data)
    end

    local playerPos = player.getCoords()
    local players = Ox.GetPlayers()
    local len = #players
    for i = 1, len do
        local nearbyPlayer = players[i]
        if nearbyPlayer.source ~= player.source and #(nearbyPlayer.getCoords() - playerPos) < 10 then
            data.nearbyPlayers[#data.nearbyPlayers + 1] = {
                name = nearbyPlayer.name,
                charId = nearbyPlayer.charId
            }
        end
    end

    return data
end

local function sort(a, b)
    return a > b
end

---@param property OxPropertyObject
local function updateProperty(property)
    Properties[property.name] = property
    GlobalState[('property.%s'):format(property.name)] = {
        name = property.name,
        permissions = property.permissions,
        owner = property.owner,
        ownerName = property.ownerName,
        group = property.group,
        groupName = property.groupName,
        colour = property.colour
    }

    local doorIds = MySQL.query.await('SELECT id FROM ox_doorlock WHERE name LIKE ?', {('%s%%'):format(property.name)})

    if not next(doorIds) then return end

    local doors = {}

    for i = 1, #doorIds do
        doors[doorIds[i].id] = exports.ox_doorlock:getDoor(doorIds[i].id)
    end

    local groupBoss = property.group and #GlobalState[('group.%s'):format(property.group)].grades
    local doorPermissions = {}

    for i = 1, #property.permissions do
        local level = property.permissions[i]

        if i == 1 then
            for id in pairs(doors) do
                doorPermissions[id] = {
                    characters = {},
                    groups = {}
                }

                if property.owner then
                    doorPermissions[id].characters[property.owner] = true
                end

                if property.group then
                    doorPermissions[id].groups[property.group] = groupBoss
                end
            end
        end

        for id in pairs(i == 1 and doors or level.doors) do
            for k, v in pairs(level) do
                if k == 'groups' then
                    for group, grade in pairs(v) do
                        if not doorPermissions[id].groups[group] or (doorPermissions[id].groups[group] and doorPermissions[id].groups[group] > grade) then
                            doorPermissions[id].groups[group] = grade
                        end
                    end
                elseif k == 'players' then
                    for player in pairs(v) do
                        doorPermissions[id].characters[tonumber(player)] = true
                    end
                end
            end
        end
    end

    for id, perms in pairs(doorPermissions) do
        local characters = {}

        for character in pairs(perms.characters) do
            characters[#characters + 1] = character
        end

        perms.characters = characters

        if doors[id].characters then
            table.sort(perms.characters, sort)
            table.sort(doors[id].characters, sort)
        end

        if not table.matches(perms.characters, doors[id].characters) or not table.matches(perms.groups, doors[id].groups) then
            exports.ox_doorlock:editDoor(id, perms)
        end
    end
end

---@param property OxPropertyObject
---@param data { level?: integer, permissions?: table }
---@return boolean response, string msg
local function updatePermissionLevel(property, data)
    local level = property.permissions[data.level] and table.deepclone(property.permissions[data.level]) or {}

    if data.level == 1 then
        data.permissions.components = nil
        data.permissions.doors = nil
    end

    for k, v in pairs(data.permissions) do
        if k == 'everyone' then
            level.everyone = v or nil
        else
            for key, value in pairs(v) do
                level[k] = level[k] or {}
                level[k][key] = value ~= 0 and value or nil
            end
        end
    end

    if not table.matches(level, property.permissions[data.level]) then
        property.permissions[data.level] = level

        MySQL.update('UPDATE ox_property SET permissions = ? WHERE name = ?', {json.encode(property.permissions), property.name})

        updateProperty(property)
    end

    return true, 'permission_level_updated'
end

---@param property OxPropertyObject
---@param level integer
---@return boolean response, string msg
local function deletePermissionLevel(property, level)
    if level == 1 then
        return false, 'action_not_allowed'
    end

    table.remove(property.permissions, level)

    MySQL.update('UPDATE ox_property SET permissions = ? WHERE name = ?', {json.encode(property.permissions), property.name})

    updateProperty(property)

    return true, 'permission_level_deleted'
end

---@param property OxPropertyObject
---@param data { owner?: integer, group?: string }
---@return boolean response, string msg
local function setPropertyValue(property, data)
    if data.owner then
        local owner = data.owner ~= 0 and data.owner or nil
        MySQL.update('UPDATE ox_property SET owner = ? WHERE name = ?', {owner, property.name})

        property.owner = owner
        property.ownerName = owner and MySQL.scalar.await('SELECT CONCAT(characters.firstName, " ", characters.lastName) FROM characters WHERE charId = ?', {owner}) or nil
    elseif data.group then
        local group = data.group ~= 0 and data.group or nil
        MySQL.update('UPDATE ox_property SET `group` = ? WHERE name = ?', {group, property.name})

        property.group = group
        if group then
            local result = MySQL.single.await('SELECT label, colour FROM ox_groups WHERE name = ?', {group})

            if result then
                property.groupName = result.label
                property.colour = result.colour
            end
        else
            property.groupName = nil
            property.colour = nil
        end
    end

    updateProperty(property)

    return true, 'property_value_set'
end

---@param source integer
---@param action string
---@param data { property: string, componentId: integer, level?: integer, permissions?: table, owner?: integer, group?: string }
---@return boolean | OxPropertyManagementData response, string | nil msg
lib.callback.register('ox_property:management', function(source, action, data)
    local permitted, msg = IsPermitted(source, data.property, data.componentId, 'management')

    if not permitted or permitted > 1 then
        return false, msg or 'not_permitted'
    end

    if action == 'get_data' then
        return getManagementData(data.property, Ox.GetPlayer(source) --[[@as OxPlayer]])
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
