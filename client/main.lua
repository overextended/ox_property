local table = lib.table
local properties = {}
local currentZone = {}
local nearbyPoints = {}

CreateThread(function()
	properties = lib.callback.await('ox_property:getProperties', 100)
	for k, v in pairs(properties) do

		local blip = AddBlipForCoord(v.blip)
		SetBlipSprite(blip, v.sprite)

		BeginTextCommandSetBlipName('STRING')
		AddTextComponentString(k)
		EndTextCommandSetBlipName(blip)

		for i = 1, #v.stashes do
			local stash = v.stashes[i]
			local pointId = ('%s:%s'):format(k, i)
			local point = lib.points.new(stash.coords, 16, {type = 'stash', id = pointId})

			function point:onEnter()
				nearbyPoints[self.id] = self
			end

			function point:onExit()
				nearbyPoints[self.id] = nil
			end

			function point:nearby()
				DrawMarker(2, self.coords.x, self.coords.y, self.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 30, 30, 150, 222, false, false, false, true, false, false, false)
			end
		end

		for i = 1, #v.zones do
			local zone = v.zones[i]
			local onEnter = function(self)
				currentZone = self
				lib.notify({
					title = self.property,
					description = self.name,
					duration = 5000,
					position = 'top'
				})
			end
			local onExit = function(self)
				if currentZone.property == self.property and currentZone.id == self.id then
					currentZone = {}
				end
			end

			if zone.points then
				zoneData = lib.zones.poly({
					points = zone.points,
					thickness = zone.thickness,
					debug = true,

					onEnter = onEnter,
					onExit = onExit,

					property = k,
					id = i,
					name = zone.name,
					type = zone.type,
				})
			elseif zone.box then
				zoneData = lib.zones.box({
					coords = zone.coords,
					rotation = zone.rotation,
					size = zone.size or vec3(2),
					debug = true,

					onEnter = onEnter,
					onExit = onExit,

					property = k,
					id = i,
					name = zone.name,
					type = zone.type,
				})
			elseif zone.sphere then
				zoneData = lib.zones.sphere({
					coords = zone.coords,
					radius = zone.radius,
					debug = true,

					onEnter = onEnter,
					onExit = onExit,

					property = k,
					id = i,
					name = zone.name,
					type = zone.type,
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
	local point
	for k, v in pairs(nearbyPoints) do
		if v.currentDistance < 1 then
			if v.type == 'stash' then
				exports.ox_inventory:openInventory('stash', {id = v.id})
			end
			point = true
			break
		end
	end

	if not point and next(currentZone) then
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
						zoneId = currentZone.id
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
		local peds = GetGamePool('CPed')
		for i = 1, #peds do
			local ped = peds[i]
			local pedCoords = GetEntityCoords(ped)
			if currentZone:contains(pedCoords) then
				entities[#entities + 1] = pedCoords
			end
		end

		local vehicles = GetGamePool('CVehicle')
		for i = 1, #vehicles do
			local vehicle = vehicles[i]
			local vehicleCoords = GetEntityCoords(vehicle)
			if currentZone:contains(vehicleCoords) then
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
			if vehicle.stored == ('%s:%s'):format(data.property, data.zoneId) then
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