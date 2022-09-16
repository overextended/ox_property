GlobalState['VehicleClasses'] = {
	[0] = 'Compacts',
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

local defaultPermissions = {}
local properties = {}

local function loadResourceDataFiles(property)
	local sets = {}
	if property then
		sets[1] = {[property] = properties[property]}
	else
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

		for i = 1, #files do
			local file = files[i]
			local func, err = load(LoadResourceFile(resource, 'data/' .. file .. '.lua'), file, 't')
			assert(func, err == nil or '\n^1' .. err .. '^7')
			sets[i] = func()
		end
	end

	local propertyInsert = {}
	for i = 1, #sets do
		local propertySet = sets[i]
		for k, v in pairs(propertySet) do
			local savedData = MySQL.query.await('SELECT * FROM ox_property WHERE property = ?', {k})
			if next(savedData) then
				for j = 1, #savedData do
					local component = savedData[j]
					v[component.type == 'stash' and 'stashes' or 'zones'][component.id].permitted = json.decode(component.permitted)
				end
			else
				if v.stashes then
					for j = 1, #v.stashes do
						v.stashes[j].permitted = v.stashes[j].permitted or defaultPermissions
						propertyInsert[#propertyInsert + 1] = {k, 'stash', j, json.encode(v.stashes[j].permitted)}
					end
				end

				if v.zones then
					for j = 1, #v.zones do
						v.zones[j].permitted = v.zones[j].permitted or defaultPermissions
						propertyInsert[#propertyInsert + 1] = {k, 'zone', j, json.encode(v.zones[j].permitted)}
					end
				end
			end

			if v.stashes then
				for j = 1, #v.stashes do
					local stash = v.stashes[j]
					local owner = stash.permitted.owner == 'true' or tostring(not (stash.permitted.groups and next(stash.permitted.groups)) and tonumber(stash.permitted.owner))

					exports.ox_inventory:RegisterStash(('%s:%s'):format(k, j), ('%s - %s'):format(k, stash.name), stash.slots or 50, stash.maxWeight or 50000, owner, stash.permitted.groups, stash.coords)
				end
			end

			properties[k] = v
		end
	end
	GlobalState['Properties'] = properties

	if next(propertyInsert) then
		MySQL.prepare('INSERT INTO ox_property (property, type, id, permitted) VALUES (?, ?, ?, ?)', propertyInsert)
	end
end
exports('loadDataFiles', loadResourceDataFiles)

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
		loadResourceDataFiles()
	end
end)


local function isPermitted(player, zone)
	if next(zone.permitted) and not (zone.permitted.groups and player.hasGroup(zone.permitted.groups)) and zone.permitted.owner ~= player.charid then
		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Permission Denied', type = 'error'})
		return false
	end
	return true
end
exports('isPermitted', isPermitted)

lib.callback.register('ox_property:getVehicleList', function(source, data)
	local player = Ox.GetPlayer(source)
	local zone = properties[data.property].zones[data.zoneId]

	if not isPermitted(player, zone) then return end

	local vehicles = data.propertyOnly and MySQL.query.await('SELECT * FROM vehicles WHERE stored LIKE ? AND owner = ?', {('%s%%'):format(data.property), player.charid}) or MySQL.query.await('SELECT * FROM vehicles WHERE owner = ?', {player.charid})

	local vehicleModels = {}
	local zoneVehicles = {}
	if data.property and data.zoneId then
		local zone = ('%s:%s'):format(data.property, data.zoneId)
		for i = 1, #vehicles do
			local vehicle = vehicles[i]
			vehicleModels[#vehicleModels + 1] = vehicle.model

			if vehicle.stored == zone then
				zoneVehicles[#zoneVehicles + 1] = vehicle
			end
		end
	end

	return vehicles, zoneVehicles, Ox.GetVehicleData(vehicleModels)
end)

RegisterServerEvent('ox_property:storeVehicle', function(data)
	local player = Ox.GetPlayer(source)
	local zone = properties[data.property].zones[data.zoneId]

	if not isPermitted(player, zone) then return end

	local vehicle = Ox.GetVehicle(GetVehiclePedIsIn(GetPlayerPed(player.source), false))
	if not vehicle then
		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to store', type = 'error'})
		return
	end

	vehicle.data = Ox.GetVehicleData(vehicle.model)

	if player.charid == vehicle.owner and zone.vehicles[vehicle.data.type] then
		local passengers = {}
		for i = -1, vehicle.data.seats - 1 do
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
		vehicle.set('properties', data.properties)
		vehicle.store(('%s:%s'):format(data.property, data.zoneId))

		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle stored', type = 'success'})
		TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, 'store')
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
			return spawn.xyz, spawn.w + rotate[math.random(2)]
		end
	end
end
exports('findClearSpawn', findClearSpawn)

RegisterServerEvent('ox_property:retrieveVehicle', function(data)
	local player = Ox.GetPlayer(source)
	local zone = properties[data.property].zones[data.zoneId]

	if not isPermitted(player, zone) then return end

	local vehicle = MySQL.single.await('SELECT * FROM vehicles WHERE plate = ? AND owner = ?', {data.plate, player.charid})

	local spawn, heading = findClearSpawn(zone.spawns, data.entities)

	if vehicle and spawn and zone.vehicles[Ox.GetVehicleData(vehicle.model).type] then
		Ox.CreateVehicle(vehicle.id, spawn, heading)

		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle retrieved', type = 'success'})
		TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, 'retrieve')
	else
		TriggerClientEvent('ox_lib:notify', player.source, {title = 'Vehicle failed to retrieve', type = 'error'})
	end
end)

RegisterServerEvent('ox_property:moveVehicle', function(data)
	local player = Ox.GetPlayer(source)
	local zone = properties[data.property].zones[data.zoneId]

	if not isPermitted(player, zone) then return end

	local vehicles = Ox.GetVehicles()
	for k, v in pairs(vehicles) do
		if v.plate == data.plate then
			local seats = Ox.GetVehicleData(v.model).seats
			for i = -1, seats - 1 do
				if GetPedInVehicleSeat(v.entity, i) ~= 0 then
					TriggerClientEvent('ox_lib:notify', player.source, {title = data.recover and 'Vehicle failed to recover' or 'Vehicle failed to move', type = 'error'})
					return
				end
			end

			local vehicle = Vehicle(v.netid)
			vehicle.despawn()
			break
		end
	end

	local vehicle = MySQL.single.await('SELECT * FROM vehicles WHERE plate = ? AND owner = ?', {data.plate, player.charid})

	if vehicle and zone.vehicles[Ox.GetVehicleData(vehicle.model).type] then
		MySQL.update.await('UPDATE vehicles SET stored = ? WHERE plate = ?', {('%s:%s'):format(data.property, data.zoneId), vehicle.plate})
		TriggerClientEvent('ox_lib:notify', player.source, {title = data.recover and 'Vehicle recovered' or 'Vehicle moved', type = 'success'})
		TriggerEvent('ox_property:vehicleStateChange', vehicle.plate, data.recover and 'recover' or 'move')
	else
		TriggerClientEvent('ox_lib:notify', player.source, {title = data.recover and 'Vehicle failed to recover' or 'Vehicle failed to move', type = 'error'})
	end
end)
