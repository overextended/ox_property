return {
    label = '7611 Goma Street',
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
}
