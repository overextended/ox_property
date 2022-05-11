local table = lib.table
local properties = {}
local currentZone = {}

CreateThread(function()
	properties = lib.callback.await('ox_property:getProperties', 100)
	for k, v in pairs(properties) do

		local blip = AddBlipForCoord(v.blip)
		SetBlipSprite(blip, v.sprite)

		BeginTextCommandSetBlipName('STRING')
		AddTextComponentString(k)
		EndTextCommandSetBlipName(blip)

		for i = 1, #v.zones do
			local zone = v.zones[i]
			local zoneData = {
				property = k,
				id = i,
				name = zone.name,
				type = zone.type
			}
			local onEnter = function()
				currentZone = zoneData
				lib.notify({
					title = k,
					description = zone.name,
					duration = 5000,
					position = 'top'
				})
			end
			local onExit = function()
				if table.matches(currentZone, zoneData) then
					currentZone = {}
				end
			end

			if zone.points then
				zoneData.polygon = lib.zones.poly({
					points = zone.points,
					thickness = zone.thickness,
					debug = true,
					onEnter = onEnter,
					onExit = onExit
				})
			elseif zone.box then
				zoneData.box = lib.zones.box({
					coords = zone.coords,
					rotation = zone.rotation,
					size = zone.size or vec3(2),
					debug = true,
					onEnter = onEnter,
					onExit = onExit
				})
			elseif zone.sphere then
				zoneData.sphere = lib.zones.sphere({
					coords = zone.coords,
					radius = zone.radius,
					debug = true,
					onEnter = onEnter,
					onExit = onExit
				})
			end

			if zone.disableGenerators then
				local point1, point2
				if zone.sphere then
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
end)

RegisterCommand('openZone', function()
	if next(currentZone) then
		local options = {}
		if currentZone.type == 'parking' then
			local allVehicles, zoneVehicles = lib.callback.await('ox_property:getOwnedVehicles', 100, currentZone.property, currentZone.id)

			if cache.seat == -1 then
				options[#options + 1] = {
					title = 'Store Vehicle',
					event = 'ox_property:storeVehicle',
					args = {property = currentZone.property, zoneId = currentZone.id}
				}
			end

			if zoneVehicles[1] then
				options[#options + 1] = {
					title = 'Open Location',
					description = 'View your vehicles at this location',
					metadata = {['Vehicles'] = #zoneVehicles},
					event = 'ox_property:vehicleList',
					args = {
						vehicles = zoneVehicles,
						property = currentZone.property,
						zoneId = currentZone.id,
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
				options[#options].event = 'ox_property:vehicleList'
				options[#options].args = {
					vehicles = allVehicles,
					property = currentZone.property,
					zoneId = currentZone.id
				}
			end
		elseif currentZone.type == 'showroom' then
			local vehicles = lib.callback.await('ox_property:getPropertyVehicles', 100, currentZone.property)
			print(json.encode(vehicles, {indent=true}))
		end
		lib.registerContext({
			id = 'zone_menu',
			title = ('%s - %s'):format(currentZone.property, currentZone.name),
			options = options
		})
		lib.showContext('zone_menu')
	end
end)

RegisterKeyMapping('openZone', 'Zone Menu', 'keyboard', 'e')

RegisterNetEvent('ox_property:storeVehicle', function(data)
	if currentZone.property == data.property and currentZone.id == data.zoneId then
		if cache.vehicle then
			if cache.seat == -1 then
				TriggerServerEvent('ox_property:storeVehicle', VehToNet(cache.vehicle), data.property, data.zoneId)
			else
				lib.notify({title = "You are not in the driver's seat", type = 'error'})
			end
		else
			lib.notify({title = 'You are not in a vehicle', type = 'error'})
		end
	end
end)

RegisterNetEvent('ox_property:retrieveVehicle', function(data)
	if currentZone.property == data.property and currentZone.id == data.zoneId then
		local entities = {}
		local zone = currentZone.polygon or currentZone.box or currentZone.sphere

		local peds = GetGamePool('CPed')
		for i = 1, #peds do
			local ped = peds[i]
			local pedCoords = GetEntityCoords(ped)
			if zone.contains(zone, pedCoords) then
				entities[#entities + 1] = pedCoords
			end
		end

		local vehicles = GetGamePool('CVehicle')
		for i = 1, #vehicles do
			local vehicle = vehicles[i]
			local vehicleCoords = GetEntityCoords(vehicle)
			if zone.contains(zone, vehicleCoords) then
				entities[#entities + 1] = vehicleCoords
			end
		end

		TriggerServerEvent('ox_property:retrieveVehicle', data.plate, data.property, data.zoneId, entities)
	end
end)

RegisterNetEvent('ox_property:vehicleList', function(data)
	if currentZone.property == data.property and currentZone.id == data.zoneId then
		local options = {}
		local subMenus = {}
		for i = 1, #data.vehicles do
			local vehicle = data.vehicles[i]
			options[vehicle.plate] = {
				menu = vehicle.plate,
				metadata = {['Location'] = vehicle.stored == 'false' and 'Unknown' or vehicle.stored}
			}

			local subOptions = {}
			if data.zoneOnly or vehicle.stored == ('%s:%s'):format(data.property, data.zoneId) then
				subOptions['Retrieve'] = {
					event = 'ox_property:retrieveVehicle',
					args = {
						plate = vehicle.plate,
						property = currentZone.property,
						zoneId = currentZone.id
					}
				}
			elseif vehicle.stored:find(':') then
				subOptions['Move'] = {
					serverEvent = 'ox_property:moveVehicle',
					args = {
						plate = vehicle.plate,
						property = currentZone.property,
						zoneId = currentZone.id
					}
				}
			else
				subOptions['Recover'] = {
					serverEvent = 'ox_property:moveVehicle',
					args = {
						plate = vehicle.plate,
						property = currentZone.property,
						zoneId = currentZone.id,
						recover = true
					}
				}
			end
			subMenus[#subMenus + 1] = {
				id = vehicle.plate,
				title = vehicle.plate,
				menu = 'vehicle_list',
				options = subOptions
			}
		end

		local menu = {
			id = 'vehicle_list',
			title = data.zoneOnly and ('%s - %s - Vehicles'):format(currentZone.property, currentZone.name) or 'All Vehicles',
			menu = 'zone_menu',
			options = options
		}
		for i = 1, #subMenus do
			menu[i] = subMenus[i]
		end

		lib.registerContext(menu)
		lib.showContext('vehicle_list')
	end
end)