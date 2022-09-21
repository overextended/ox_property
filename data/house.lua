return {
	['3671 Whispymound Drive'] = {
		sprite = 40,
		blip = vec(-4.7, 523.5),
		stashes = {
			{
				name = 'Garage Stash',
				coords = vec(25.3, 544.6, 176.0),
			},
			{
				name = 'Dining Stash',
				coords = vec(-7.0, 530.2, 175.0),
			},
			{
				name = 'Bedroom Stash',
				coords = vec(-1.5, 525.9, 170.6),
			},
		},
		zones = {
			{
				name = 'Management',
				type = 'management',
				sphere = vec(3.7, 525.5, 174.6),
			},
			{
				name = 'Wardrobe',
				type = 'wardrobe',
				sphere = vec(8.4, 528.5, 170.6),
			},
			{
				name = 'Garage',
				type = 'parking',
				vehicles = { automobile = true, bicycle = true, bike = true, quadbike = true },
				points = {
					vec(20.8, 548.9, 176.0),
					vec(17.7, 543.4, 176.0),
					vec(24.5, 540.0, 176.0),
					vec(26.4, 544.9, 176.0),
				},
				spawns = {
					vec(21.5, 544.1, 175.6, 239.6),
				},
			},
		},
	},
	['7611 Goma Street'] = {
		sprite = 40,
		blip = vec(-1148.3, -1523.0),
		stashes = {
			{
				name = 'Parking Stash',
				coords = vec(-1147.2, -1525.4, 4.3),
			},
			{
				name = 'Stairs Stash',
				coords = vec(-1144.7, -1518.0, 4.3),
			},
			{
				name = 'Entrance Stash',
				coords = vec(-1152.8, -1516.9, 10.6),
			},
		},
		zones = {
			{
				name = 'Management',
				type = 'management',
				sphere = vec(-1156.7, -1517.9, 10.6),
			},
			{
				name = 'Wardrobe',
				type = 'wardrobe',
				sphere = vec(-1150.0, -1513.5, 10.6),
				radius = 1.5,
			},
			{
				name = 'Parking',
				type = 'parking',
				vehicles = { automobile = true, bicycle = true, bike = true, quadbike = true },
				points = {
					vec(-1154.0, -1514.9, 4.3),
					vec(-1160.8, -1520.0, 4.3),
					vec(-1150.5, -1534.7, 4.3),
					vec(-1147.6, -1532.5, 4.3),
					vec(-1150.2, -1528.6, 4.3),
					vec(-1150.3, -1520.3, 4.3),
				},
				spawns = {
					vec(-1150.6, -1531.4, 3.8, 214.9),
					vec(-1154.5, -1518.3, 3.9, 216.2),
					vec(-1157.4, -1520.4, 3.9, 216.3),
				},
			},
		},
	},
	['Casa Philips'] = {
		sprite = 40,
		blip = vec(1973.6, 3818.2),
		stashes = {
			{
				name = 'Parking Stash',
				coords = vec(1964.6, 3819.0, 32.4),
			},
			{
				name = 'TV Stash',
				coords = vec(1978.2, 3819.4, 33.5),
			},
		},
		zones = {
			{
				name = 'Management',
				type = 'management',
				sphere = vec(1975.0, 3818.6, 33.4),
			},
			{
				name = 'Wardrobe',
				type = 'wardrobe',
				sphere = vec(1969.5, 3815.0, 33.4),
				radius = 1.5,
			},
			{
				name = 'Parking',
				type = 'parking',
				vehicles = { automobile = true, bicycle = true, bike = true, quadbike = true },
				points = {
					vec(1971.7, 3825.6, 32.4),
					vec(1973.6, 3822.3, 32.4),
					vec(1965.8, 3818.4, 32.4),
					vec(1964.1, 3821.4, 32.4),
				},
				spawns = {
					vec(1968.2, 3821.8, 32.0, 121.1),
				},
			},
		},
	},
	['The Clinton Residence'] = {
		sprite = 40,
		blip = vec(-14.9, -1433.2),
		stashes = {
			{
				name = 'Garage Stash',
				coords = vec(-25.8, -1424.7, 30.7),
			},
			{
				name = 'Storage Room',
				coords = vec(-17.1, -1430.4, 31.1),
			},
		},
		zones = {
			{
				name = 'Management',
				type = 'management',
				sphere = vec(-9.9, -1433.4, 31.1),
			},
			{
				name = 'Wardrobe',
				type = 'wardrobe',
				sphere = vec(-17.5, -1439.0, 31.1),
			},
			{
				name = 'Garage',
				type = 'parking',
				vehicles = { automobile = true, bicycle = true, bike = true, quadbike = true },
				points = {
					vec(-23.3, -1432.3, 30.7),
					vec(-23.5, -1425.3, 30.7),
					vec(-27.4, -1425.4, 30.7),
					vec(-27.1, -1432.5, 30.7),
				},
				spawns = {
					vec(-25.2, -1428.1, 30.2, 0.1),
				},
			},
		},
	},
	['The Crest Residence'] = {
		sprite = 40,
		blip = vec(1274.4, -1712.6),
		stashes = {
			{
				name = 'Electronics Stash',
				coords = vec(1272.1, -1711.9, 54.8),
			},
			{
				name = 'Chemicals Stash',
				coords = vec(1268.6, -1710.4, 54.8),
			},
		},
		zones = {
			{
				name = 'Management',
				type = 'management',
				sphere = vec(1275.4, -1710.9, 54.8),
				radius = 1,
			},
		},
	},
	['The De Santa Residence'] = {
		sprite = 40,
		blip = vec(-803.4, 175.9),
		stashes = {
			{
				name = 'Garage Stash',
				coords = vec(-809.4, 190.8, 72.5),
			},
			{
				name = 'Kitchen Stash',
				coords = vec(-803.1, 184.7, 72.6),
			},
			{
				name = 'Living Stash',
				coords = vec(-804.9, 177.4, 72.8),
			},
		},
		zones = {
			{
				name = 'Management',
				type = 'management',
				sphere = vec(-807.2, 167.7, 76.7),
				radius = 1.5,
			},
			{
				name = 'Wardrobe',
				type = 'wardrobe',
				sphere = vec(-811.8, 175.0, 76.7),
				radius = 1.5,
			},
			{
				name = 'Garage',
				type = 'parking',
				vehicles = { automobile = true, bicycle = true, bike = true, quadbike = true },
				points = {
					vec(-814.0, 183.7, 72.5),
					vec(-815.9, 188.9, 72.5),
					vec(-810.6, 190.9, 72.5),
					vec(-808.5, 185.6, 72.5),
				},
				spawns = {
					vec(-812.2, 186.5, 72.0, 292.5),
				},
			},
			{
				name = 'Carport',
				type = 'parking',
				vehicles = { automobile = true, bicycle = true, bike = true, quadbike = true },
				points = {
					vec(-805.0, 166.2, 71.6),
					vec(-811.0, 163.7, 71.6),
					vec(-808.9, 158.7, 71.6),
					vec(-801.5, 161.5, 71.6),
				},
				spawns = {
					vec(-807.1, 162.5, 71.1, 290.7),
				},
			},
		},
	},
}
