return {
    label = 'Casa Philips',
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
}
