local modelData = {}
local vehicleHashes = {}
local properties = {}
local vehicleFilters = {
	class = {
		'Compacts',
		'Sedans',
		'SUVs',
		'Coupes',
		'Muscle',
		'Sports Classics',
		'Sports',
		'Super',
		'Motorcycles',
		'Off-road',
		'Industrial',
		'Utility',
		'Vans',
		'Cycles',
		'Boats',
		'Helicopters',
		'Planes',
		'Service',
		'Emergency',
		'Military',
		'Commercial',
		'Trains',
		'Open Wheel'
	}
}

local function loadResourceDataFiles()
	local resource = GetInvokingResource() or GetCurrentResourceName()
	local system = os.getenv('OS')
	local command = system and system:match('Windows') and 'dir "%s/" /b' or 'ls "%s/"'
	local path = GetResourcePath(resource)
	local dir = io.popen(command:format(path:gsub('//', '/') .. '/data'))

	local files = {}
	if dir then
		for line in dir:lines() do
			local file = line:gsub('%.lua', '')
			files[#files + 1] = file
		end
		dir:close()
	end

	local sets = {}
	for i = 1, #files do
		local file = files[i]
		local func, err = load(LoadResourceFile(resource, 'data/' .. file .. '.lua'), file, 't')
		assert(func, err == nil or '\n^1' .. err .. '^7')
		sets[i] = func()
	end

	for i = 1, #sets do
		local propertySet = sets[i]
		for k, v in pairs(propertySet) do
			properties[k] = v
			if v.stashes then
				for j = 1, #v.stashes do
					local stash = v.stashes[j]
					exports.ox_inventory:RegisterStash(('%s:%s'):format(k, j), ('%s - %s'):format(k, stash.label), stash.slots or 50, stash.maxWeight or 50000, stash.owner, stash.groups, stash.coords)
				end
			end
		end
	end
	GlobalState['Properties'] = properties
end
exports('loadDataFiles', loadResourceDataFiles)

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
		loadResourceDataFiles()

		modelData = MySQL.query.await('SELECT * FROM vehicle_data')
		GlobalState['ModelData'] = modelData
		for i = 1, #modelData do
			local vehicle = modelData[i]
			vehicleHashes[joaat(vehicle.model)] = i
		end

		local columns = {'make', 'type', 'bodytype'}
		for i = 1, #columns do
			local column = columns[i]
			local result = MySQL.query.await('SELECT DISTINCT ?? FROM vehicle_data ORDER BY ??', {column, column})
			vehicleFilters[column] = {}
			for j = 1, #result do
				vehicleFilters[column][#vehicleFilters[column] + 1] = result[j][column]
			end
		end

		local minmax = MySQL.single.await('SELECT MIN(price), MIN(doors), MIN(seats), MAX(price), MAX(doors), MAX(seats) FROM vehicle_data')

		vehicleFilters.price = {minmax['MIN(price)'], minmax['MAX(price)']}
		vehicleFilters.doors = {minmax['MIN(doors)'], minmax['MAX(doors)']}
		vehicleFilters.seats = {minmax['MIN(seats)'], minmax['MAX(seats)']}

		GlobalState['VehicleFilters'] = vehicleFilters
	end
end)

exports('getModelData', function(model)
	return modelData[vehicleHashes[model]]
end)

lib.callback.register('ox_property:getVehicleList', function(source, data)
	local player = lib.getPlayer(source)
	local vehicles = data.propertyOnly and MySQL.query.await('SELECT * FROM user_vehicles WHERE stored LIKE ? AND charid = ?', {('%s%%'):format(data.property), player.charid}) or MySQL.query.await('SELECT * FROM user_vehicles WHERE charid = ?', {player.charid})

	local zoneVehicles = {}
	if data.property and data.zoneId then
		local zone = ('%s:%s'):format(data.property, data.zoneId)
		for i = 1, #vehicles do
			local vehicle = vehicles[i]
			local vehicleData = json.decode(vehicle.data)
			vehicle.modelData = modelData[vehicleHashes[vehicleData.model]]
			if vehicle.stored == zone then
				zoneVehicles[#zoneVehicles + 1] = vehicle
			end
		end
	end

	return vehicles, zoneVehicles
end)

RegisterServerEvent('ox_property:storeVehicle', function(data)
	local player = lib.getPlayer(source)
	local vehicle = Vehicle(NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(player.source), false)))
	if player.charid == vehicle.owner then
		local passengers = {}
		local modelData = modelData[vehicleHashes[vehicle.data.model]]
		for i = -1, modelData.seats - 1 do
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
		Wait(300)
		vehicle.store(('%s:%s'):format(data.property, data.zoneId))
		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle stored', type = 'success'})
	else
		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to store', type = 'error'})
	end
end)

local function isPointClear(point, entities)
	for i = 1, #entities do
		local entity = entities[i]
		if #(point - entity) < 2.5 then
			return false
		end
	end
	return true
end

local rotate = {0, 180}
local function findClearSpawn(spawns, entities)
	local len = #spawns
	for i = len, 2, -1 do
		local j = math.random(i)
		spawns[i], spawns[j] = spawns[j], spawns[i]
	end

	for i = 1, len do
		local spawn = spawns[i]
		if isPointClear(spawn.xyz, entities) then
			return vec(spawn.xyz, spawn.w + rotate[math.random(2)])
		end
	end
end
exports('findClearSpawn', findClearSpawn)

RegisterServerEvent('ox_property:retrieveVehicle', function(data)
	local player = lib.getPlayer(source)
	local zone = properties[data.property].zones[data.zoneId]

	local vehicle = MySQL.single.await('SELECT * FROM user_vehicles WHERE plate = ? AND charid = ?', {data.plate, player.charid})
	local spawn = findClearSpawn(zone.spawns, data.entities)

	if vehicle and spawn then
		vehicle.data = json.decode(vehicle.data)
		local veh = Ox.CreateVehicle(vehicle.charid, vehicle.data, spawn)
		MySQL.update('UPDATE user_vehicles SET stored = "false" WHERE plate = ?', {vehicle.data.plate})

		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle retrieved', type = 'success'})
	else
		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to retrieve', type = 'error'})
	end
end)

RegisterServerEvent('ox_property:moveVehicle', function(data)
	local player = lib.getPlayer(source)
	local zone = properties[data.property].zones[data.zoneId]
	local vehicle = MySQL.single.await('SELECT * FROM user_vehicles WHERE plate = ? AND charid = ?', {data.plate, player.charid})

	if vehicle then
		MySQL.update.await('UPDATE user_vehicles SET stored = ? WHERE plate = ?', {('%s:%s'):format(data.property, data.zoneId), vehicle.plate})
		TriggerClientEvent('ox_lib:notify', player.source, {title = data.recover and 'Vehicle recovered' or 'Vehicle moved', type = 'success'})
	else
		TriggerClientEvent('ox_lib:notify', player.source, {title = data.recover and 'Vehicle failed to recover' or 'Vehicle failed to move', type = 'error'})
	end
end)
