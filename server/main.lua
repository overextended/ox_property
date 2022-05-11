local sets do
	local files = {}
	local system = os.getenv('OS')
	local command = system and system:match('Windows') and 'dir "' or 'ls "'
	local path = GetResourcePath(GetCurrentResourceName())
	local types = path:gsub('//', '/') .. '/data'
	local suffix = command == 'dir "' and '/" /b' or '/"'
	local dir = io.popen(command .. types .. suffix)

	if dir then
		for line in dir:lines() do
			local file = line:gsub('%.lua', '')
			files[#files + 1] = file
		end
		dir:close()
	end

	sets = files
end

local function data(name)
	local func, err = load(LoadResourceFile(GetCurrentResourceName(), 'data/' .. name .. '.lua'), name, 't')
	assert(func, err == nil or '\n^1' .. err .. '^7')
	return func()
end

local properties = {}
local ready

for i = 1, #sets do
    local set = sets[i]
	local propertyData = data(set)
	for k, v in pairs(propertyData) do
		properties[k] = v
	end
	ready = true
end

lib.callback.register('ox_property:getProperties', function(source)
	while not ready do
		Wait(100)
	end
	return properties
end)

lib.callback.register('ox_property:getOwnedVehicles', function(source, property, zoneId)
	local player = exports.ox_core:getPlayer(source)
	local vehicles = MySQL.query.await('SELECT * FROM user_vehicles WHERE charid = ?', {player.charid})
	local zoneVehicles = {}

	if property and zoneId then
		for i = 1, #vehicles do
			local vehicle = vehicles[i]
			if vehicle.stored == ('%s:%s'):format(property, zoneId) then
				zoneVehicles[#zoneVehicles + 1] = vehicle
			end
		end
	end

	return vehicles, zoneVehicles
end)

lib.callback.register('ox_property:getPropertyVehicles', function(source, property)
	return MySQL.query.await('SELECT * FROM user_vehicles WHERE stored LIKE ?', {('%s%%'):format(property)})
end)

RegisterServerEvent('ox_property:storeVehicle', function(netid, property, zoneId)
	local source = source
	local player = exports.ox_core:getPlayer(source)
	local vehicle = Vehicle(netid)
	if player.charid == vehicle.owner then
		local passengers = {}
		for i = -1, 15 do
			local ped = GetPedInVehicleSeat(vehicle.entity, i)
			if ped ~= 0 then
				passengers[#passengers + 1] = ped
				TaskLeaveVehicle(ped, vehicle.entity, 0)
			end
		end
		local empty
		while not empty do
			Wait(100)
			empty = true
			for i = 1, #passengers do
				local passenger = passengers[i]
				if GetVehiclePedIsIn(passenger) == vehicle.entity then
					empty = false
				end
			end
		end
		Wait(500)
		vehicle.store(('%s:%s'):format(property, zoneId))
		TriggerClientEvent('ox_lib:notify', source, {title = 'Vehicle stored', type = 'success'})
	else
		TriggerClientEvent('ox_lib:notify', source, {title = 'Vehicle failed to store', type = 'error'})
	end
end)

local rotate = {0, 180}
local function shuffle(tbl)
	for i = #tbl, 2, -1 do
	  local j = math.random(i)
	  tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

local function isPointClear(point, entities)
	for i = 1, #entities do
		local entity = entities[i]
		if #(point - entity) < 2.5 then
			return false
		end
	end
	return true
end

RegisterServerEvent('ox_property:retrieveVehicle', function(plate, property, zoneId, entities)
	local source = source
	local player = exports.ox_core:getPlayer(source)
	local zone = properties[property].zones[zoneId]
	local vehicle = MySQL.single.await('SELECT * FROM user_vehicles WHERE plate = ? AND charid = ?', {plate, player.charid})

	local spawns = shuffle(zone.spawns)
	local spawn
	for i = 1, #spawns do
		local point = spawns[i]
		if isPointClear(point.xyz, entities) then
			spawn = vec(point.xyz, point.w + rotate[math.random(2)])
			break
		end
	end

	if vehicle and spawn then
		vehicle.data = json.decode(vehicle.data)
		Ox.CreateVehicle(vehicle.charid, vehicle.data.model, spawn, vehicle.data)
		TriggerClientEvent('ox_lib:notify', source, {title = 'Vehicle retrieved', type = 'success'})
		MySQL.update('UPDATE user_vehicles SET stored = "false" WHERE plate = ?', {vehicle.plate})
	else
		TriggerClientEvent('ox_lib:notify', source, {title = 'Vehicle failed to retrieve', type = 'error'})
	end
end)

RegisterServerEvent('ox_property:moveVehicle', function(data)
	local source = source
	local player = exports.ox_core:getPlayer(source)
	local zone = properties[data.property].zones[data.zoneId]
	local vehicle = MySQL.single.await('SELECT * FROM user_vehicles WHERE plate = ? AND charid = ?', {data.plate, player.charid})

	if vehicle then
		MySQL.update.await('UPDATE user_vehicles SET stored = ? WHERE plate = ?', {('%s:%s'):format(data.property, data.zoneId), vehicle.plate})
		TriggerClientEvent('ox_lib:notify', source, {title = data.recover and 'Vehicle recovered' or 'Vehicle moved', type = 'success'})
	else
		TriggerClientEvent('ox_lib:notify', source, {title = data.recover and 'Vehicle failed to recover' or 'Vehicle failed to move', type = 'error'})
	end
end)
