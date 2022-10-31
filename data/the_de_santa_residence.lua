return {
    label = 'The De Santa Residence',
    sprite = 40,
    blip = vec(-803.4, 175.9),
    components = {
        {
            name = 'Garage Stash',
			type = 'stash',
            point = vec(-809.4, 190.8, 72.5),
        },
        {
            name = 'Kitchen Stash',
			type = 'stash',
            point = vec(-803.1, 184.7, 72.6),
        },
        {
            name = 'Living Stash',
			type = 'stash',
            point = vec(-804.9, 177.4, 72.8),
        },
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
}
