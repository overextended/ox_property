return{
    label = 'Mission Row Police Department',
    sprite = 40,
    blip = vec(448.82, -984.38),
    components = {
        {
            name = 'mrpd_front_park',
            type = 'parking',
            vehicles = { automobile = true, bicycle = true, bike = true, quadbike = true },
            points = {
                vec(410.5, -1002.75, 29.0),
                vec(405.5, -998.5, 29.0),
                vec(405.5, -975.5, 29.0),
                vec(410.5, -979.5, 29.0),
            },
            spawns = {
                vec(407.28, -979.47, 29.27, 231.82),
                vec(406.36, -982.95, 29.27, 231.23),
                vec(406.01, -987.22, 29.27, 230.4),
                vec(405.46, -991.71, 29.27, 229.67),
                vec(405.94, -996.77, 29.27, 230.66),
            },
        },
        {
            name = 'Management',
            type = 'management',
            sphere = vec(447.05, -973.95, 30.45),
        },
        {
            name = 'Wardrobe',
            type = 'wardrobe',
            sphere = vec(454.4, -993.4, 31.1),
        },
        {
            name = 'mrpd_side_park',
            type = 'parking',
            vehicles = { automobile = true, bicycle = true, bike = true, quadbike = true },
            points = {
                vec(448.0, -1028.25, 29.0),
                vec(448.0, -1023.0, 29.0),
                vec(426.0, -1024.25, 29.0),
                vec(426.0, -1030.75, 29.0),
            },
            spawns = {
                vec(427.61, -1026.63, 28.98, 179.95),
                vec(431.28, -1026.61, 28.92, 181.58),
                vec(434.85, -1026.32, 28.85, 182.36),
                vec(438.67, -1026.0, 28.78, 182.7),
                vec(442.71, -1026.1, 28.71, 175.83),
                vec(446.05, -1025.19, 28.65, 183.17),
            }
        }
    }
}