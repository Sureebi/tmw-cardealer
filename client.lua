-- Wait for dependencies
local QBCore = nil
local oxLib = nil

CreateThread(function()
    -- Wait for ox_lib
    while GetResourceState('ox_lib') ~= 'started' do
        Wait(100)
    end
    oxLib = true
    
    -- Try different QBCore exports
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('qbx_core') == 'started' then
        QBCore = exports.qbx_core:GetCoreObject()
    elseif GetResourceState('qbx-core') == 'started' then
        QBCore = exports['qbx-core']:GetCoreObject()
    end
    
    if not QBCore then
        print('^1[car_showroom] ERROR: QBCore/Qbox not found!^7')
    else
        print('^2[car_showroom] Successfully loaded with QBCore^7')
    end
end)

local showroomVehicles = {}
local vehicleLocks = {} -- За да предотвратим едновременни промени
local playerViewingCar = {} -- Коя кола гледа всеки играч
local isCleaningUp = false -- Флаг за cleanup
local hasSpawned = false -- Флаг дали вече са спаунати колите
local spawnedCount = 0 -- Брой спаунати коли
local expectedCount = 0 -- Очакван брой коли
local currentlyViewingSpot = nil -- Кое място гледа играчът в момента

-- Check if player has dealer job/gang
local function HasDealerAccess()
    if not QBCore then return false end
    
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return false end
    
    if Config.UseGang then
        return PlayerData.gang and PlayerData.gang.name == Config.DealerJob
    else
        return PlayerData.job and PlayerData.job.name == Config.DealerJob
    end
end

-- Notification helper
local function Notify(title, description, type)
    if oxLib and exports.ox_lib then
        exports.ox_lib:notify({
            title = title,
            description = description,
            type = type
        })
    else
        QBCore.Functions.Notify(description, type)
    end
end

-- Cleanup old showroom vehicles on resource restart
local function CleanupShowroomVehicles()
    isCleaningUp = true
    
    print('^3[car_showroom] Cleaning up ' .. #showroomVehicles .. ' vehicles...^7')
    
    -- Изтрий всички стари showroom коли
    for _, spot in ipairs(showroomVehicles) do
        if DoesEntityExist(spot.vehicle) then
            DeleteEntity(spot.vehicle)
        end
    end
    showroomVehicles = {}
    vehicleLocks = {}
    
    Wait(1000) -- Изчакай да се изтрият напълно
    isCleaningUp = false
    hasSpawned = false
    
    print('^2[car_showroom] Cleanup complete^7')
end

-- Spawn Showroom Vehicles (request from server)
CreateThread(function()
    -- Изчакай QBCore и ox_lib да се заредят
    while not QBCore or not oxLib do
        Wait(100)
    end
    
    print('^2[car_showroom] QBCore and ox_lib loaded^7')
    
    -- Изчакай малко повече за да се зареди всичко
    Wait(3000)
    
    -- Провери дали вече са спаунати
    if hasSpawned then
        print('^1[car_showroom] Vehicles already spawned, skipping...^7')
        return
    end
    
    hasSpawned = true
    spawnedCount = 0
    
    -- Изчисли очаквания брой коли
    for _, car in ipairs(Config.ShowroomCars) do
        if car.coords.x ~= 0 and car.coords.y ~= 0 then
            expectedCount = expectedCount + 1
        end
    end
    
    -- Cleanup преди да спаунваме нови
    CleanupShowroomVehicles()
    
    print('^2[car_showroom] ===== CLIENT REQUESTING SPAWN FROM SERVER (expecting ' .. expectedCount .. ' vehicles) =====^7')
    
    -- Request server to send vehicle data
    TriggerServerEvent('gang_dealership:requestInitialSpawn')
    
    -- Timeout check
    SetTimeout(10000, function()
        if spawnedCount < expectedCount then
            print('^1[car_showroom] WARNING: Only ' .. spawnedCount .. '/' .. expectedCount .. ' vehicles spawned after 10 seconds!^7')
        end
    end)
end)

-- Server tells us to spawn a vehicle (CLIENT-SIDE SPAWNING)
RegisterNetEvent('gang_dealership:spawnVehicleClient', function(spotIndex, model, coords, config)
    print('^2[car_showroom] ===== CLIENT SPAWNING VEHICLE ' .. spotIndex .. ': ' .. model .. ' =====^7')
    
    local carModel = GetHashKey(model)
    
    print('^3[car_showroom] Requesting model ' .. model .. ' (hash: ' .. carModel .. ')^7')
    RequestModel(carModel)
    
    -- Увеличен timeout за тежки модели (15 секунди)
    local timeout = 0
    while not HasModelLoaded(carModel) and timeout < 15000 do
        Wait(100)
        timeout = timeout + 100
        
        -- Debug на всеки 2 секунди
        if timeout % 2000 == 0 then
            print('^3[car_showroom] Still loading model ' .. model .. ' (' .. timeout .. 'ms)^7')
        end
    end
    
    if not HasModelLoaded(carModel) then
        print('^1[car_showroom] ERROR: Failed to load model ' .. model .. ' after ' .. timeout .. 'ms^7')
        return
    end
    
    print('^2[car_showroom] Model loaded successfully after ' .. timeout .. 'ms^7')
    
    local finalZ = coords.z - (config.zOffset or 0.0)
    local vehicle = CreateVehicle(carModel, coords.x, coords.y, finalZ, coords.w, false, false)
    
    -- Изчакай малко за да се създаде колата
    Wait(200)
    
    if not DoesEntityExist(vehicle) then
        print('^1[car_showroom] ERROR: Failed to create vehicle^7')
        SetModelAsNoLongerNeeded(carModel)
        return
    end
    
    print('^2[car_showroom] Vehicle created (Entity ID: ' .. vehicle .. ')^7')
    
    -- Приложи properties - МАКСИМАЛНА ЗАЩИТА
    SetEntityAsMissionEntity(vehicle, true, true)
    
    -- Заключване - ПО-СИЛНО
    SetVehicleDoorsLocked(vehicle, 4) -- 4 = Can be broken into (но ще добавим защита)
    SetVehicleDoorsLockedForAllPlayers(vehicle, true)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), true)
    
    -- Затвори всички врати
    for i = 0, 5 do
        SetVehicleDoorShut(vehicle, i, false)
    end
    
    -- Защита
    SetEntityInvincible(vehicle, true)
    FreezeEntityPosition(vehicle, true)
    SetEntityProofs(vehicle, true, true, true, true, true, true, true, true)
    
    -- Визуални и механични настройки
    SetVehicleNumberPlateText(vehicle, "SHOWROOM")
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleUndriveable(vehicle, true)
    SetVehicleCanBeVisiblyDamaged(vehicle, false)
    SetVehicleCanBreak(vehicle, false)
    
    -- Гуми - НОРМАЛНИ (не bulletproof)
    SetVehicleTyresCanBurst(vehicle, true)
    SetVehicleWheelsCanBreak(vehicle, false)
    
    -- Допълнителна защита
    SetVehicleAlarm(vehicle, false)
    SetVehicleAlarmTimeLeft(vehicle, 0)
    
    -- Направи колата ПЕРФЕКТНА (без пушек)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    
    SetModelAsNoLongerNeeded(carModel)
    
    -- Запази в локалната таблица
    showroomVehicles[spotIndex] = {
        vehicle = vehicle,
        model = model,
        coords = coords,
        config = config
    }
    
    -- Добави ox_target
    local options = {
        {
            name = 'view_car_' .. spotIndex,
            icon = 'fa-solid fa-eye',
            label = 'Преглед',
            onSelect = function()
                ShowCarInfo(spotIndex)
            end
        },
        {
            name = 'test_drive_' .. spotIndex,
            icon = 'fa-solid fa-car',
            label = 'Тест драйв',
            canInteract = function()
                return HasDealerAccess()
            end,
            onSelect = function()
                StartTestDrive(model)
            end
        },
        {
            name = 'sell_car_' .. spotIndex,
            icon = 'fa-solid fa-handshake',
            label = 'Продай кола',
            canInteract = function()
                return HasDealerAccess()
            end,
            onSelect = function()
                SellCarToPlayer(config)
            end
        }
    }
    
    exports.ox_target:addLocalEntity(vehicle, options)
    
    -- Увеличи брояча
    spawnedCount = spawnedCount + 1
    
    print('^2[car_showroom] Showroom vehicle ' .. spotIndex .. ' ready (' .. spawnedCount .. '/' .. expectedCount .. ')^7')
    
    -- Ако всички коли са спаунати
    if spawnedCount >= expectedCount then
        print('^2[car_showroom] All vehicles spawned successfully!^7')
        print('^2[car_showroom] Total ' .. #Config.ShowroomCars .. ' vehicles available for sale^7')
    end
end)

-- Server tells us to change a vehicle (CLIENT-SIDE SPAWNING)
RegisterNetEvent('gang_dealership:changeVehicleClient', function(spotIndex, newModel, newConfig)
    local spot = showroomVehicles[spotIndex]
    if not spot then 
        print('^1[car_showroom] ERROR: Spot ' .. spotIndex .. ' not found in client!^7')
        return 
    end
    
    print('^3[car_showroom] Changing spot ' .. spotIndex .. ' to: ' .. newModel .. '^7')
    
    -- Премахни ox_target и изтрий старата кола
    if DoesEntityExist(spot.vehicle) then
        exports.ox_target:removeLocalEntity(spot.vehicle)
        DeleteEntity(spot.vehicle)
        print('^3[car_showroom] Deleted old vehicle^7')
    end
    
    -- Спаунвай новата кола
    local carModel = GetHashKey(newModel)
    
    print('^3[car_showroom] Requesting model ' .. newModel .. ' (hash: ' .. carModel .. ')^7')
    RequestModel(carModel)
    
    -- Увеличен timeout за тежки модели (15 секунди)
    local timeout = 0
    while not HasModelLoaded(carModel) and timeout < 15000 do
        Wait(100)
        timeout = timeout + 100
        
        -- Debug на всеки 2 секунди
        if timeout % 2000 == 0 then
            print('^3[car_showroom] Still loading model ' .. newModel .. ' (' .. timeout .. 'ms)^7')
        end
    end
    
    if not HasModelLoaded(carModel) then
        print('^1[car_showroom] ERROR: Failed to load model ' .. newModel .. ' after ' .. timeout .. 'ms^7')
        return
    end
    
    print('^2[car_showroom] Model loaded successfully after ' .. timeout .. 'ms^7')
    
    local coords = spot.coords
    local finalZ = coords.z - (newConfig.zOffset or 0.0)
    local newVehicle = CreateVehicle(carModel, coords.x, coords.y, finalZ, coords.w, false, false)
    
    -- Изчакай малко за да се създаде колата
    Wait(200)
    
    if not DoesEntityExist(newVehicle) then
        print('^1[car_showroom] ERROR: Failed to create new vehicle^7')
        SetModelAsNoLongerNeeded(carModel)
        return
    end
    
    print('^2[car_showroom] New vehicle created (Entity ID: ' .. newVehicle .. ')^7')
    
    -- Приложи properties - МАКСИМАЛНА ЗАЩИТА
    SetEntityAsMissionEntity(newVehicle, true, true)
    
    -- Заключване - ПО-СИЛНО
    SetVehicleDoorsLocked(newVehicle, 4) -- 4 = Can be broken into (но ще добавим защита)
    SetVehicleDoorsLockedForAllPlayers(newVehicle, true)
    SetVehicleDoorsLockedForPlayer(newVehicle, PlayerId(), true)
    
    -- Затвори всички врати
    for i = 0, 5 do
        SetVehicleDoorShut(newVehicle, i, false)
    end
    
    -- Защита
    SetEntityInvincible(newVehicle, true)
    FreezeEntityPosition(newVehicle, true)
    SetEntityProofs(newVehicle, true, true, true, true, true, true, true, true)
    
    -- Визуални и механични настройки
    SetVehicleNumberPlateText(newVehicle, "SHOWROOM")
    SetVehicleEngineOn(newVehicle, false, true, true)
    SetVehicleUndriveable(newVehicle, true)
    SetVehicleCanBeVisiblyDamaged(newVehicle, false)
    SetVehicleCanBreak(newVehicle, false)
    
    -- Гуми - НОРМАЛНИ (не bulletproof)
    SetVehicleTyresCanBurst(newVehicle, true)
    SetVehicleWheelsCanBreak(newVehicle, false)
    
    -- Допълнителна защита
    SetVehicleAlarm(newVehicle, false)
    SetVehicleAlarmTimeLeft(newVehicle, 0)
    
    -- Направи колата ПЕРФЕКТНА (без пушек)
    SetVehicleEngineHealth(newVehicle, 1000.0)
    SetVehicleBodyHealth(newVehicle, 1000.0)
    SetVehiclePetrolTankHealth(newVehicle, 1000.0)
    SetVehicleFixed(newVehicle)
    SetVehicleDeformationFixed(newVehicle)
    
    SetModelAsNoLongerNeeded(carModel)
    
    -- Update local data
    showroomVehicles[spotIndex].vehicle = newVehicle
    showroomVehicles[spotIndex].model = newModel
    showroomVehicles[spotIndex].config = newConfig
    
    -- Re-add ox_target
    local options = {
        {
            name = 'view_car_' .. spotIndex,
            icon = 'fa-solid fa-eye',
            label = 'Преглед',
            onSelect = function()
                ShowCarInfo(spotIndex)
            end
        },
        {
            name = 'test_drive_' .. spotIndex,
            icon = 'fa-solid fa-car',
            label = 'Тест драйв',
            canInteract = function()
                return HasDealerAccess()
            end,
            onSelect = function()
                StartTestDrive(newModel)
            end
        },
        {
            name = 'sell_car_' .. spotIndex,
            icon = 'fa-solid fa-handshake',
            label = 'Продай кола',
            canInteract = function()
                return HasDealerAccess()
            end,
            onSelect = function()
                SellCarToPlayer(newConfig)
            end
        }
    }
    
    exports.ox_target:addLocalEntity(newVehicle, options)
    
    print('^2[car_showroom] Vehicle changed successfully^7')
end)

-- Мониторинг на showroom колите - ИЗКЛЮЧЕН (причинява проблеми)
-- CreateThread(function()
--     while true do
--         Wait(10000) -- Проверявай на всеки 10 секунди (по-рядко)
--         
--         -- Не проверявай по време на cleanup
--         if not isCleaningUp and #showroomVehicles > 0 then
--             for i, spot in ipairs(showroomVehicles) do
--                 if spot and spot.vehicle and not DoesEntityExist(spot.vehicle) then
--                 print('^3[car_showroom] Showroom vehicle ' .. spot.model .. ' was destroyed, respawning...^7')
--                 
--                 local carModel = GetHashKey(spot.model)
--                 RequestModel(carModel)
--                 local timeout = 0
--                 while not HasModelLoaded(carModel) and timeout < 5000 do
--                     Wait(10)
--                     timeout = timeout + 10
--                 end
--                 
--                 if HasModelLoaded(carModel) then
--                     local coords = spot.coords
--                     local finalZ = coords.z - (spot.config.zOffset or 0.0)
--                     local newVehicle = CreateVehicle(carModel, coords.x, coords.y, finalZ, coords.w, true, false)
--                     
--                     if DoesEntityExist(newVehicle) then
--                         SetEntityAsMissionEntity(newVehicle, true, true)
--                         SetVehicleDoorsLocked(newVehicle, 2) -- Заключена
--                         SetVehicleDoorsLockedForAllPlayers(newVehicle, true) -- Заключена за всички
--                         SetEntityInvincible(newVehicle, true)
--                         FreezeEntityPosition(newVehicle, true)
--                         SetVehicleNumberPlateText(newVehicle, "SHOWROOM")
--                         SetVehicleEngineOn(newVehicle, false, true, true) -- Изключен мотор
--                         SetEntityProofs(newVehicle, true, true, true, true, true, true, true, true)
--                         SetVehicleCanBeVisiblyDamaged(newVehicle, false)
--                         SetVehicleCanBreak(newVehicle, false)
--                         SetVehicleTyresCanBurst(newVehicle, false)
--                         SetVehicleWheelsCanBreak(newVehicle, false)
--                         SetVehicleUndriveable(newVehicle, true) -- Не може да се кара
--                         SetModelAsNoLongerNeeded(carModel)
--                         
--                         -- Обнови референцията
--                         showroomVehicles[i].vehicle = newVehicle
--                         
--                         -- Добави ox_target отново
--                         local options = {
--                             {
--                                 name = 'view_car_' .. spot.model,
--                                 icon = 'fa-solid fa-eye',
--                                 label = 'Преглед',
--                                 onSelect = function()
--                                     ShowCarInfo(i)
--                                 end
--                             }
--                         }
--                         
--                         options[#options + 1] = {
--                             name = 'test_drive_' .. spot.model,
--                             icon = 'fa-solid fa-car',
--                             label = 'Тест драйв',
--                             canInteract = function()
--                                 return HasDealerAccess()
--                             end,
--                             onSelect = function()
--                                 StartTestDrive(spot.model)
--                             end
--                         }
--                         
--                         options[#options + 1] = {
--                             name = 'sell_car_' .. spot.model,
--                             icon = 'fa-solid fa-handshake',
--                             label = 'Продай кола',
--                             canInteract = function()
--                                 return HasDealerAccess()
--                             end,
--                             onSelect = function()
--                                 SellCarToPlayer(spot.config)
--                             end
--                         }
--                         
--                         exports.ox_target:addLocalEntity(newVehicle, options)
--                         
--                         print('^2[car_showroom] Showroom vehicle respawned successfully^7')
--                     end
--                 end
--             end
--         end
--     end
--     end -- Затваря if not isCleaningUp
-- end)

-- Show Car Info (всички могат да виждат)
function ShowCarInfo(spotIndex)
    local currentSpot = showroomVehicles[spotIndex]
    if not currentSpot then return end
    
    -- Lock spot on server
    currentlyViewingSpot = spotIndex
    TriggerServerEvent('gang_dealership:lockSpot', spotIndex, true)
    
    local options = {}
    
    -- Добави всички коли в менюто
    for _, showCar in ipairs(Config.ShowroomCars) do
        local priceFormatted = '$' .. tostring(showCar.price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        
        options[#options + 1] = {
            title = showCar.label or showCar.model,
            description = 'Цена: ' .. priceFormatted,
            icon = showCar.model == currentSpot.model and 'circle-check' or 'car',
            iconColor = showCar.model == currentSpot.model and 'green' or nil,
            onSelect = function()
                if showCar.model ~= currentSpot.model then
                    -- Request server to change vehicle
                    TriggerServerEvent('gang_dealership:requestChangeVehicle', spotIndex, showCar.model)
                    Wait(500)
                    ShowCarInfo(spotIndex)
                else
                    -- Същата кола, покажи менюто отново
                    ShowCarInfo(spotIndex)
                end
            end
        }
    end
    
    if oxLib and exports.ox_lib then
        exports.ox_lib:registerContext({
            id = 'car_catalog_' .. spotIndex,
            title = 'Каталог с коли',
            menu = 'car_catalog_' .. spotIndex,
            onExit = function()
                -- Unlock spot when menu closes
                if currentlyViewingSpot == spotIndex then
                    TriggerServerEvent('gang_dealership:lockSpot', spotIndex, false)
                    currentlyViewingSpot = nil
                end
            end,
            options = options
        })
        
        exports.ox_lib:showContext('car_catalog_' .. spotIndex)
    else
        local priceFormatted = '$' .. tostring(currentSpot.config.price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        QBCore.Functions.Notify(string.format('%s - Цена: %s', currentSpot.config.label or currentSpot.model, priceFormatted), 'primary', 5000)
        
        -- Unlock spot
        if currentlyViewingSpot == spotIndex then
            TriggerServerEvent('gang_dealership:lockSpot', spotIndex, false)
            currentlyViewingSpot = nil
        end
    end
end

-- Test Drive (само за dealer job)
function StartTestDrive(model)
    if not HasDealerAccess() then
        Notify('Достъп отказан', 'Трябва да работиш тук за тест драйв!', 'error')
        return
    end
    
    -- Вземи близки играчи от сървъра
    QBCore.Functions.TriggerCallback('gang_dealership:getNearbyPlayers', function(nearbyPlayers)
        if not nearbyPlayers or #nearbyPlayers == 0 then
            Notify('Грешка', 'Няма играчи наблизо (10м радиус)!', 'error')
            return
        end
        
        -- Създай меню с близки играчи
        local options = {}
        for _, playerData in ipairs(nearbyPlayers) do
            options[#options + 1] = {
                title = playerData.name,
                description = 'ID: ' .. playerData.id .. ' | Разстояние: ' .. string.format('%.1f', playerData.distance) .. 'м',
                icon = 'user',
                onSelect = function()
                    -- Намери свободно място
                    local freeSpot = nil
                    for _, spot in ipairs(Config.TestDriveSpots) do
                        if not IsAnyVehicleNearPoint(spot.x, spot.y, spot.z, 2.5) then
                            freeSpot = spot
                            break
                        end
                    end
                    
                    if not freeSpot then
                        Notify('Грешка', 'Всички места за тест драйв са заети! Опитай отново след малко.', 'error')
                        return
                    end
                    
                    -- Изпрати към сървъра да създаде тест драйв
                    TriggerServerEvent('gang_dealership:startTestDrive', playerData.id, model, freeSpot)
                end
            }
        end
        
        if oxLib and exports.ox_lib then
            exports.ox_lib:registerContext({
                id = 'test_drive_players',
                title = 'Избери играч за тест драйв',
                options = options
            })
            exports.ox_lib:showContext('test_drive_players')
        end
    end)
end

-- Receive test drive vehicle
RegisterNetEvent('gang_dealership:receiveTestDrive', function(model, freeSpot)
    print('^3[car_showroom] Receiving test drive: ' .. model .. '^7')
    
    RequestModel(GetHashKey(model))
    local timeout = 0
    while not HasModelLoaded(GetHashKey(model)) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(GetHashKey(model)) then
        Notify('Грешка', 'Неуспешно зареждане на модела!', 'error')
        return
    end
    
    local vehicle = CreateVehicle(GetHashKey(model), freeSpot.x, freeSpot.y, freeSpot.z, freeSpot.w, true, false)
    
    if not DoesEntityExist(vehicle) then
        Notify('Грешка', 'Неуспешно създаване на автомобил!', 'error')
        return
    end
    
    SetVehicleNumberPlateText(vehicle, "TEST")
    SetVehicleEngineOn(vehicle, true, true, false)
    
    -- Дай ключове на играча
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerEvent("vehiclekeys:client:SetOwner", plate)
    
    -- Запази началната позиция на играча
    local playerPed = PlayerPedId()
    local returnCoords = GetEntityCoords(playerPed)
    
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
    
    Notify('Тест драйв', 'Имате 2 минути за тест драйв!', 'success')
    
    -- Проверка дали играчът излиза от колата
    CreateThread(function()
        while DoesEntityExist(vehicle) do
            Wait(1000)
            
            if not IsPedInVehicle(playerPed, vehicle, false) then
                -- Играчът излезе от колата
                DeleteVehicle(vehicle)
                SetEntityCoords(playerPed, returnCoords.x, returnCoords.y, returnCoords.z)
                Notify('Тест драйв приключи', 'Върнахте се обратно.', 'info')
                break
            end
        end
    end)
    
    -- Timer за тест драйв (2 минути)
    SetTimeout(120000, function()
        if DoesEntityExist(vehicle) then
            DeleteVehicle(vehicle)
            SetEntityCoords(playerPed, returnCoords.x, returnCoords.y, returnCoords.z)
            Notify('Тест драйв приключи', 'Времето изтече! Върнахте се обратно.', 'info')
        end
    end)
end)

-- Sell Car to Player (само за dealer job)
function SellCarToPlayer(car)
    if not HasDealerAccess() then
        Notify('Достъп отказан', 'Трябва да работиш тук за да продаваш коли!', 'error')
        return
    end
    
    -- Вземи близки играчи от сървъра
    QBCore.Functions.TriggerCallback('gang_dealership:getNearbyPlayers', function(nearbyPlayers)
        if not nearbyPlayers or #nearbyPlayers == 0 then
            Notify('Грешка', 'Няма играчи наблизо (10м радиус)!', 'error')
            return
        end
        
        -- Създай меню с близки играчи
        local options = {}
        for _, playerData in ipairs(nearbyPlayers) do
            local priceFormatted = '$' .. tostring(car.price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            local commissionFormatted = '$' .. tostring(math.floor(car.price * Config.Commission)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            
            options[#options + 1] = {
                title = playerData.name,
                description = 'ID: ' .. playerData.id .. ' | Разстояние: ' .. string.format('%.1f', playerData.distance) .. 'м',
                icon = 'user',
                onSelect = function()
                    -- Confirm sale
                    local alert = nil
                    if oxLib and exports.ox_lib then
                        alert = exports.ox_lib:alertDialog({
                            header = 'Потвърди продажба',
                            content = string.format('Продаваш %s на %s за %s?\n\nТвоята комисионна: %s', 
                                car.label or car.model, 
                                playerData.name,
                                priceFormatted,
                                commissionFormatted),
                            centered = true,
                            cancel = true,
                            labels = {
                                confirm = 'Продай',
                                cancel = 'Откажи'
                            }
                        })
                    else
                        alert = 'confirm' -- Auto confirm for QBCore
                    end
                    
                    if alert == 'confirm' then
                        TriggerServerEvent('gang_dealership:sellCar', playerData.id, car.model, car.price)
                    end
                end
            }
        end
        
        if oxLib and exports.ox_lib then
            exports.ox_lib:registerContext({
                id = 'sell_car_players',
                title = 'Избери купувач',
                options = options
            })
            exports.ox_lib:showContext('sell_car_players')
        end
    end)
end

-- Receive purchased car
RegisterNetEvent('gang_dealership:receiveCar', function(model, plate, carData)
    print('^3[car_showroom] Receiving car: ' .. model .. ' with plate: ' .. plate .. '^7')
    
    local coords = Config.DeliveryCoords
    
    RequestModel(GetHashKey(model))
    local timeout = 0
    while not HasModelLoaded(GetHashKey(model)) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(GetHashKey(model)) then
        print('^1[car_showroom] ERROR: Failed to load model for delivery^7')
        Notify('Грешка', 'Неуспешно зареждане на модела!', 'error')
        return
    end
    
    -- Провери дали мястото е свободно
    if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then
        Notify('Грешка', 'Мястото за доставка е заето! Моля изчистете го.', 'error')
        return
    end
    
    local vehicle = CreateVehicle(GetHashKey(model), coords.x, coords.y, coords.z, coords.w, true, false)
    
    if not DoesEntityExist(vehicle) then
        print('^1[car_showroom] ERROR: Failed to create vehicle for delivery^7')
        Notify('Грешка', 'Неуспешно създаване на автомобил!', 'error')
        return
    end
    
    print('^2[car_showroom] Vehicle created successfully (ID: ' .. vehicle .. ')^7')
    
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleEngineOn(vehicle, false, false, false)
    SetVehicleDoorsLocked(vehicle, 1) -- Отключена
    
    -- Изчакай малко за да се зареди колата напълно
    Wait(500)
    
    -- Дай ключове на купувача
    TriggerEvent("vehiclekeys:client:SetOwner", plate)
    
    -- Вземи properties СЛЕД като колата е напълно заредена
    local props = {}
    if oxLib and exports.ox_lib then
        props = exports.ox_lib:getVehicleProperties(vehicle)
    else
        props = QBCore.Functions.GetVehicleProperties(vehicle)
    end
    
    -- Увери се че plate-а е правилен в props
    props.plate = plate
    
    print('^3[car_showroom] Vehicle properties collected^7')
    print('^3Props model: ' .. tostring(props.model) .. '^7')
    
    -- Запази в базата данни
    TriggerServerEvent('gang_dealership:saveVehicle', props, plate, model)
    
    -- Качи играча в колата
    local playerPed = PlayerPedId()
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
    
    Notify('Покупка успешна', 'Колата е доставена! Приятно шофиране!', 'success')
    
    print('^2[car_showroom] Car delivery completed successfully^7')
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print('^3[car_showroom] Resource stopping, cleaning up...^7')
    
    hasSpawned = false
    
    -- Изтрий всички showroom коли
    for _, spot in ipairs(showroomVehicles) do
        if DoesEntityExist(spot.vehicle) then
            DeleteEntity(spot.vehicle)
        end
    end
    
    print('^2[car_showroom] Cleanup complete^7')
end)

-- Защита срещу влизане в showroom коли
CreateThread(function()
    while true do
        Wait(100) -- Проверявай на всеки 100ms
        
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 then
            -- Провери дали това е showroom кола (по номер на таблата)
            local plate = GetVehicleNumberPlateText(vehicle)
            
            if plate and string.find(plate, "SHOWROOM") then
                -- Това е showroom кола! Изхвърли играча
                TaskLeaveVehicle(playerPed, vehicle, 16) -- 16 = instant exit
                SetPedToRagdoll(playerPed, 1000, 1000, 0, false, false, false)
                
                Notify('Забранено', 'Не можеш да влизаш в showroom колите!', 'error')
                
                print('^3[car_showroom] Player tried to enter showroom vehicle, ejecting...^7')
            end
        end
    end
end)

-- Create Blip
CreateThread(function()
    local blip = AddBlipForCoord(Config.Blip.Coords)
    SetBlipSprite(blip, Config.Blip.Sprite)
    SetBlipDisplay(blip, Config.Blip.Display)
    SetBlipScale(blip, Config.Blip.Scale)
    SetBlipColour(blip, Config.Blip.Colour)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Blip.Name)
    EndTextCommandSetBlipName(blip)
end)
