---@type table<string, OxPropertyObject>
Properties = {}

---@param property string
---@param componentId integer
---@return OxPropertyObject | OxPropertyComponent
exports('getPropertyData', function(property, componentId)
    return componentId and Properties[property].components[componentId] or Properties[property]
end)

---@type table<string, OxPropertyComponent>
local zones = {}

---@param player integer | OxPlayer
---@param propertyName string
---@param componentId integer
---@param componentType string
---@return boolean | integer, string?
function IsPermitted(player, propertyName, componentId, componentType)
    player = type(player) == 'number' and Ox.GetPlayer(player) or player --[[@as OxPlayer]]
    local property = Properties[propertyName]
    local component = property.components[componentId]

    if componentType ~= component.type then
        return false, 'component_mismatch'
    end

    local zone = zones[propertyName][componentId]
    local coords = player.getCoords()

    if zone and not zone:contains(coords) then
        return false, 'component_mismatch'
    elseif not zone and #(component.point - coords) > 1 then
        return false, 'component_mismatch'
    end

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

    return false
end
exports('isPermitted', IsPermitted)

---@type table<string, true>
local stashes = {}
local stashHook

local function resetStashHook()
    local stashesArray = {}

    for stash in pairs(stashes) do
        stashesArray[#stashesArray + 1] = stash
    end

    if stashHook then
        exports.ox_inventory:removeHooks(stashHook)
    end

    stashHook = exports.ox_inventory:registerHook('openInventory', function(payload)
        local property, componentId = string.strsplit(':', payload.inventoryId)

        if not IsPermitted(payload.source, property, tonumber(componentId) --[[@as integer]], 'stash') then
            return false
        end
    end, {
        inventoryFilter = stashesArray
    })
end

---@type table<string, string[]>
local propertyResources = {}
local defaultOwner = nil
local defaultOwnerName
local defaultGroup = nil
local defaultGroupName
local defaultGroupColour

AddEventHandler('onResourceStart', function(resource)
    local count = GetNumResourceMetadata(resource, 'ox_property_data')
    if count < 1 then return end

    propertyResources[resource] = {}
    local data = {}

    for i = 0, count - 1 do
        local file = GetResourceMetadata(resource, 'ox_property_data', i)
        local func, err = load(LoadResourceFile(resource, file), ('@@%s%s'):format(resource, file), 't', Shared.DATA_ENVIRONMENT)
        assert(func, err == nil or ('\n^1%s^7'):format(err))
        local propertyName = file:match('([%w_]+)%..+$')
        data[propertyName] = func()

        propertyResources[resource][#propertyResources[resource] + 1] = propertyName
    end

    for k, v in pairs(data) do
        Properties[k] = v
        zones[k] = {}

        for i = 1, #v.components do
            local component = v.components[i]
            component.property = k
            component.componentId = i

            if not component.point then
                zones[k][i] = lib.zones[component.points and 'poly' or component.box and 'box' or component.sphere and 'sphere']({
                    points = component.points,
                    thickness = component.thickness,
                    coords = component.box or component.sphere,
                    rotation = component.rotation,
                    size = component.size or vec3(2),
                    radius = component.radius
                })
            end

            if component.type == 'stash' then
                local stashName = ('%s:%s'):format(k, i)
                stashes[stashName] = true

                exports.ox_inventory:RegisterStash(stashName, ('%s - %s'):format(v.label, component.name), component.slots or 50, component.maxWeight or 1000000, not component.shared == true, nil, component.coords)
            end
        end
    end

    local result = MySQL.query.await('SELECT ox_property.*, CONCAT(characters.firstname, " ", characters.lastname) AS ownerName, ox_groups.label as groupName, ox_groups.colour as colour FROM ox_property LEFT JOIN characters ON ox_property.owner = characters.charid LEFT JOIN ox_groups ON ox_property.group = ox_groups.name')

    defaultOwnerName = defaultOwnerName or defaultOwner and MySQL.scalar.await('SELECT CONCAT(characters.firstname, " ", characters.lastname) FROM characters WHERE charid = ?', {defaultOwner})

    if defaultGroup and not (defaultGroupName and defaultGroupColour) then
        local label, colour in MySQL.single.await('SELECT label, colour FROM ox_groups WHERE name = ?', {defaultGroup})
        defaultGroupName = label
        defaultGroupColour = colour
    end

    local existingProperties = {}
    local propertyInsert = {}

    for i = 1, #result do
        local property = result[i]
        existingProperties[property.name] = property
    end

    for k, v in pairs(data) do
        local variables = existingProperties[k]

        if variables then
            variables.name = k
            variables.permissions = json.decode(variables.permissions)
        else
            variables = {
                name = k,
                permissions = {{}},
                owner = defaultOwner,
                ownerName = defaultOwnerName,
                group = defaultGroup,
                groupName = defaultGroupName,
                colour = defaultGroupColour
            }

            propertyInsert[#propertyInsert + 1] = {k, defaultOwner, defaultGroup}
        end

        GlobalState[('property.%s'):format(k)] = variables

        for key, value in pairs(variables) do
            v[key] = value
        end
    end

    if next(propertyInsert) then
        MySQL.prepare('INSERT INTO ox_property (name, owner, `group`) VALUES (?, ?, ?)', propertyInsert)
    end

    resetStashHook()
end)

AddEventHandler('onResourceStop', function(resource)
    if not propertyResources[resource] then return end

    for i = 1, #propertyResources[resource] do
        Properties[propertyResources[resource][i]] = nil
    end

    propertyResources[resource] = nil
end)

local invoiceThreshold = 1000

---@param source number
---@param msg string
---@param data { amount: number, from: OxPropertyTransactionParty, to: OxPropertyTransactionParty }
---@return boolean, string?
function Transaction(source, msg, data)
    local available
    local amount, from, to in data

    if from then
        local accounts = exports.pefcl:getAccountsByIdentifier(source, from.identifier).data
        for i = 1, #accounts do
            local account = accounts[i].dataValues
            if account.isDefault then
                available = account.balance
            end
        end
    end

    if not from or amount <= available then
        if from then
            exports.pefcl:removeBankBalanceByIdentifier(source, {
                identifier = from.identifier,
                amount = amount,
                message = msg
            })
        end

        if to then
            exports.pefcl:addBankBalanceByIdentifier(source, {
                identifier = to.identifier,
                amount = amount,
                message = msg
            })
        end

        return true
    elseif amount <= invoiceThreshold and from and to then
        exports.pefcl:createInvoice(source, {
            to = from.name,
            toIdentifier = from.identifier,
            from = to.name,
            fromIdentifier = to.identifier,
            amount = amount,
            message = msg
        })

        return true
    end

    return false, 'transaction_failed'
end
exports('transaction', Transaction)
