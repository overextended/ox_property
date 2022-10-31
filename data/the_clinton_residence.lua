return {
    label = 'The Clinton Residence',
    sprite = 40,
    blip = vec(-14.9, -1433.2),
    components = {
        {
            name = 'Garage Stash',
			type = 'stash',
            point = vec(-25.8, -1424.7, 30.7),
        },
        {
            name = 'Storage Room',
			type = 'stash',
            point = vec(-17.1, -1430.4, 31.1),
        },
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
}
