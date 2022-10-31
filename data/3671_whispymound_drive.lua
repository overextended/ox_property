return {
    label = '3671 Whispymound Drive',
    sprite = 40,
    blip = vec(-4.7, 523.5),
    components = {
        {
            name = 'Garage Stash',
			type = 'stash',
            point = vec(25.3, 544.6, 176.0),
        },
        {
            name = 'Dining Stash',
			type = 'stash',
            point = vec(-7.0, 530.2, 175.0),
        },
        {
            name = 'Bedroom Stash',
			type = 'stash',
            point = vec(-1.5, 525.9, 170.6),
        },
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
}
