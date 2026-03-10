Config = {}

-- Job Settings (за тестове използваме job, после може да се смени на gang)
Config.DealerJob = 'radko' -- Име на job-а който може да продава коли
Config.UseGang = true -- true = gang система, false = job система
Config.Commission = 0.10 -- 10% комисионна за продавача

-- Garage Settings (не се използва вече, колата се спаунва директно)
-- Config.GarageName = 'Central Garage'
-- Config.StoredState = 0

-- Showroom Vehicles (само 7 се показват физически, но всички са достъпни за продажба)
Config.ShowroomCars = {
    -- Showroom display (физически коли)
    { model = 'gbmugello', price = 580000, coords = vector4(-1256.94, -366.31, 36.18, 83.10), zOffset = 0.0, label = 'Mugello' },
    { model = 'gbcyphergts', price = 380000, coords = vector4(-1262.83, -353.76, 36.18, 39.72), zOffset = 0.0, label = 'Cypher GTS' },
    { model = 'gbrumina', price = 260000, coords = vector4(-1269.22, -363.61, 36.18, 92.38), zOffset = 0.0, label = 'Rumina' },
    { model = 'gbzeitgeist', price = 310000, coords = vector4(-1244.23, -356.63, 39.57, 89.15), zOffset = 0.0, label = 'Zeitgeist' },
    { model = 'gbechelon', price = 330000, coords = vector4(-1247.05, -351.81, 39.57, 81.42), zOffset = 0.0, label = 'Echelon' },
    { model = 'gbhedra', price = 295000, coords = vector4(-1269.91, -357.35, 35.76, 239.07), zOffset = 0.0, label = 'Hedra' },
    
    -- Останали коли (достъпни за продажба, но не се показват физически)
    { model = 'gbesurfer', price = 280000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'E-Surfer' },
    { model = 'gberotiq', price = 300000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Erotiq' },
    { model = 'gbvigerorat', price = 350000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Vigero RAT' },
    { model = 'gbcheetahs', price = 550000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Cheetah S' },
    { model = 'gbmugello', price = 580000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Mugello' },
    { model = 'gbarcherpro2', price = 280000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Archer Pro 2' },
    { model = 'gbargento2f', price = 270000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Argento 2F' },
    { model = 'gbcyphergts', price = 380000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Cypher GTS' },
    { model = 'gbretinueloz', price = 205000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Retinue LOZ' },
    { model = 'gbscoutgsx', price = 380000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Scout GSX' },
    { model = 'gbhedrakombi', price = 300000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Hedra Kombi' },
    { model = 'gbharmann', price = 990000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Harmann' },
    { model = 'gbirisz', price = 220000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Iris Z' },
    { model = 'gbgresleystx', price = 430000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Gresley STX' },
    { model = 'gbnexusrr', price = 305000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Nexus RR' },
    { model = 'gbronin', price = 650000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Ronin' },
    { model = 'gbschrauber', price = 220000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Schrauber' },
    { model = 'gbschwartzers', price = 330000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Schwartzer S' },
    { model = 'gbclubxr', price = 230000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Club XR' },
    { model = 'gbvivant', price = 190000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Vivant' },
    { model = 'gbbanshees', price = 390000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Banshee S' },
    { model = 'gbbisonhf', price = 350000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Bison HF' },
    { model = 'gbesperta', price = 240000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Esperta' },
    { model = 'gbeon', price = 335000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Eon' },
    { model = 'gbsolace', price = 555000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Solace' },
    { model = 'gbsolacev', price = 565000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Solace V' },
    { model = 'gbsapphire', price = 710000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Sapphire' },
    { model = 'gbbriosof', price = 205000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Brioso F' },
    { model = 'gbmilano', price = 690000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Milano' },
    { model = 'gbmogulrs', price = 335000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Mogul RS' },
    { model = 'gbmojave', price = 280000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Mojave' },
    { model = 'gbsultanrsx', price = 350000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Sultan RSX' },
    { model = 'gbargento7f', price = 400000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Argento 7F' },
    { model = 'gbargento7fs', price = 290000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Argento 7F S' },
    { model = 'gbprospero', price = 775000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Prospero' },
    { model = 'gbcomets2r', price = 690000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Comet S2 R' },
    { model = 'gbcomets2rc', price = 695000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Comet S2 RC' },
    { model = 'gbtr3s', price = 740000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'TR3 S' },
    { model = 'gbsentinelgts', price = 300000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Sentinel GTS' },
    { model = 'gbdominatorgsx', price = 330000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Dominator GSX' },
    { model = 'gbstarlight', price = 280000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Starlight' },
    { model = 'gbissimetro', price = 215000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Issi Metro' },
    { model = 'mesar', price = 235000, coords = vector4(0, 0, 0, 0), zOffset = 0.0, label = 'Mesar' },
}

-- Locations
Config.TestDriveSpots = {
    vector4(-1253.3, -392.56, 36.29, 297.66),
    vector4(-1254.43, -388.96, 36.29, 297.18),
    vector4(-1256.15, -385.86, 36.29, 291.33),
    vector4(-1233.84, -388.6, 36.29, 18.91),
    vector4(-1230.27, -386.64, 36.29, 25.09),
    vector4(-1226.86, -384.44, 36.29, 25.88),
    vector4(-1223.32, -383.06, 36.29, 16.61),
    vector4(-1219.46, -381.32, 36.29, 20.08),
    vector4(-1216.33, -378.58, 36.29, 24.99),
    vector4(-1212.94, -377.01, 36.29, 21.43),
    vector4(-1207.62, -375.04, 36.29, 21.85),
    vector4(-1204.35, -373.41, 36.29, 23.13),
    vector4(-1200.77, -371.34, 36.29, 23.83)
}
Config.DeliveryCoords = vector4(-1245.51, -394.78, 36.80, 27.77)

-- Blip Settings
Config.Blip = {
    Coords = vector3(-1264.9885, -367.0415, 36.6611),
    Sprite = 225,
    Display = 4,
    Scale = 1.0,
    Colour = 1,
    Name = "Автокъща"
}
