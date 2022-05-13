return {
	['Premium Deluxe Motorsport'] = {
		sprite = 326,
		blip = vec(-40.709, -1099.769),
		stashes = {
			{
				label = 'Boss Stash',
				coords = vec(-31.2, -1110.8, 26.4),
			},
			{
				label = 'Office Stash',
				coords = vec(-29.8, -1107.7, 26.4),
			},
		},
		zones = {
			{
				name = 'Boss',
				type = 'boss',
				points = {
					vec(-29.704624176025, -1110.2766113281, 26.5),
					vec(-31.831315994263, -1116.0166015625, 26.5),
					vec(-36.002246856689, -1114.4670410156, 26.5),
					vec(-34.633644104004, -1111.32421875, 26.5),
				},
			},
			{
				name = 'Showroom',
				type = 'showroom',
				vehicles = {'automobile', 'bike'},
				disableGenerators = true,
				points = {
					vec(-37.8, -1094.4, 26.5),
					vec(-33.0, -1100.2, 26.5),
					vec(-35.1, -1105.9, 26.5),
					vec(-41.0, -1107.0, 26.5),
					vec(-59.4, -1098.7, 26.5),
					vec(-56.0, -1088.0, 26.5),
					vec(-49.6, -1089.2, 26.5),
				},
				spawns = {
					vec(-53.2, -1091.3, 26.1, 159.7),
					vec(-47.9, -1093.2, 26.1, 121.0),
					vec(-43.8, -1094.5, 26.1, 122.8),
					vec(-49.0, -1100.9, 26.1, 28.1),
					vec(-45.1, -1101.3, 26.1, 30.0),
					vec(-38.4, -1103.0, 26.1, 132.3),
				},
			},
			{
				name = 'Garage A',
				type = 'parking',
				vehicles = {'automobile', 'bike'},
				points = {
					vec(-63.451034545898, -1119.6665039062, 26.5),
					vec(-38.897029876709, -1118.3724365234, 26.5),
					vec(-36.507881164551, -1111.7186279297, 26.5),
					vec(-63.421985626221, -1102.1765136719, 26.5),
				},
				spawns = {
					vec(-40.9, -1115.6, 26.1, 206.4),
					vec(-45.0, -1116.0, 26.1, 184.0),
					vec(-47.9, -1116.2, 26.1, 181.8),
					vec(-50.7, -1116.3, 26.1, 183.4),
					vec(-53.5, -1116.3, 26.1, 183.5),
					vec(-56.3, -1116.4, 26.1, 181.6),
					vec(-59.1, -1116.7, 26.1, 183.3),
					vec(-61.8, -1116.7, 26.1, 181.7),
				},
			},
		},
	},
}
