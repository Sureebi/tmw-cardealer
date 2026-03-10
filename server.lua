-- QBCore/Qbox compatibility
local QBCore = nil

if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('qbx_core') == 'started' then
    QBCore = exports.qbx_core:GetCoreObject()
elseif GetResourceState('qbx-core') == 'started' then
    QBCore = exports['qbx-core']:GetCoreObject()
end

if not QBCore then
    print('^1[car_showroom] ERROR: QBCore/Qbox not found!^7')
end

-- Showroom vehicles state (server-side) - само състояние, без entities
local showroomVehicles = {}
local vehicleLocks = {}
local isInitialized = false

-- Initialize showroom vehicles from config
local function InitializeShowroom()
    if isInitialized then return end
    
    print('^3[car_showroom] Initializing showroom on server...^7')
    
    for i, car in ipairs(Config.ShowroomCars) do
        local hasValidCoords = (car.coords.x ~= 0 and car.coords.y ~= 0)
        
        if hasValidCoords then
            showroomVehicles[i] = {
                model = car.model,
                coords = car.coords,
                config = car,
                currentModel = car.model
            }
            vehicleLocks[i] = nil
            
            print('^2[car_showroom] Initialized showroom spot ' .. i .. ': ' .. car.model .. '^7')
        end
    end
    
    isInitialized = true
    print('^2[car_showroom] Server initialized with ' .. #showroomVehicles .. ' showroom spots^7')
end

-- Initialize on resource start
CreateThread(function()
    Wait(500)
    InitializeShowroom()
    print('^2[car_showroom] Server initialization complete, ready to accept requests^7')
end)

-- Debug: Print when event is registered
print('^3[car_showroom] Registering server events...^7')

-- Generate Random Plate
local function GeneratePlate()
    local plate = ''
    for i = 1, 3 do
        plate = plate .. string.char(math.random(65, 90))
    end
    plate = plate .. math.random(100, 999)
    return plate
end

-- Send Discord Webhook
local function SendDiscordLog(seller, buyer, carData, price, commission)
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' then
        return
    end
    
    local sellerName = seller.PlayerData.charinfo.firstname .. ' ' .. seller.PlayerData.charinfo.lastname
    local buyerName = buyer.PlayerData.charinfo.firstname .. ' ' .. buyer.PlayerData.charinfo.lastname
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    
    local priceFormatted = '$' .. tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    local commissionFormatted = '$' .. tostring(commission):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    
    local embed = {
        {
            ['title'] = '🚗 Vehicle Sale',
            ['color'] = 3066993, -- Green color
            ['fields'] = {
                {
                    ['name'] = '👤 Seller',
                    ['value'] = sellerName .. ' (ID: ' .. seller.PlayerData.source .. ')',
                    ['inline'] = true
                },
                {
                    ['name'] = '👤 Buyer',
                    ['value'] = buyerName .. ' (ID: ' .. buyer.PlayerData.source .. ')',
                    ['inline'] = true
                },
                {
                    ['name'] = '🚙 Vehicle',
                    ['value'] = carData.label or carData.model,
                    ['inline'] = true
                },
                {
                    ['name'] = '💰 Price',
                    ['value'] = priceFormatted,
                    ['inline'] = true
                },
                {
                    ['name'] = '💵 Commission',
                    ['value'] = commissionFormatted,
                    ['inline'] = true
                },
                {
                    ['name'] = '🏦 Gang/Job Profit',
                    ['value'] = '$' .. tostring(price - commission):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""),
                    ['inline'] = true
                }
            },
            ['footer'] = {
                ['text'] = 'TMW Car Dealership'
            },
            ['timestamp'] = os.date('!%Y-%m-%dT%H:%M:%S')
        }
    }
    
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({
        username = 'Car Dealership',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

-- Check if player has enough money in bank
local function HasBankMoney(source, amount)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false end
    
    -- Провери в QBCore bank (личната сметка на играча)
    local bankMoney = player.PlayerData.money.bank or 0
    print('^3[Gang Dealership] Player ' .. player.PlayerData.citizenid .. ' has $' .. bankMoney .. ' in bank^7')
    return bankMoney >= amount
end

-- Remove money from bank
local function RemoveBankMoney(source, amount, reason)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false end
    
    -- Вземи парите от QBCore bank (личната сметка на играча)
    local removed = player.Functions.RemoveMoney('bank', amount, reason or 'dealership-purchase')
    print('^3[Gang Dealership] Removed $' .. amount .. ' from player bank: ' .. tostring(removed) .. '^7')
    return removed
end

-- Client requests to spawn initial vehicles
RegisterNetEvent('gang_dealership:requestInitialSpawn', function()
    local src = source
    
    print('^2[car_showroom] ===== CLIENT ' .. src .. ' REQUESTING VEHICLES =====^7')
    
    if not isInitialized then
        print('^3[car_showroom] Server not initialized, initializing now...^7')
        InitializeShowroom()
    end
    
    print('^3[car_showroom] Server has ' .. #showroomVehicles .. ' showroom spots^7')
    
    if #showroomVehicles == 0 then
        print('^1[car_showroom] ERROR: No showroom spots found!^7')
        return
    end
    
    -- Изпрати информацията за колите към клиента (клиентът ще ги спаунва)
    for i, spot in pairs(showroomVehicles) do
        print('^3[car_showroom] Sending spot ' .. i .. ' (' .. spot.currentModel .. ') to client ' .. src .. '^7')
        TriggerClientEvent('gang_dealership:spawnVehicleClient', src, i, spot.currentModel, spot.coords, spot.config)
        Wait(500) -- Увеличен delay между колите за да има време да се заредят
    end
    
    print('^2[car_showroom] Sent all vehicle data to client ' .. src .. '^7')
end)

-- Client requests to change showroom car
RegisterNetEvent('gang_dealership:requestChangeVehicle', function(spotIndex, newModel)
    local src = source
    
    print('^3[car_showroom] Client ' .. src .. ' requesting to change spot ' .. spotIndex .. ' to: ' .. newModel .. '^7')
    
    if not showroomVehicles[spotIndex] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Невалидно място!',
            type = 'error'
        })
        return
    end
    
    if vehicleLocks[spotIndex] and vehicleLocks[spotIndex] ~= src then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Моля изчакай',
            description = 'Друг играч разглежда тази кола...',
            type = 'error'
        })
        return
    end
    
    local carConfig = nil
    for _, car in ipairs(Config.ShowroomCars) do
        if car.model == newModel then
            carConfig = car
            break
        end
    end
    
    if not carConfig then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Невалиден модел!',
            type = 'error'
        })
        return
    end
    
    -- Обнови server state
    showroomVehicles[spotIndex].currentModel = newModel
    showroomVehicles[spotIndex].config = carConfig
    
    print('^2[car_showroom] Successfully changed spot ' .. spotIndex .. ' to: ' .. newModel .. '^7')
    
    -- Изпрати към ВСИЧКИ клиенти да сменят колата (клиентите ще я спаунват)
    TriggerClientEvent('gang_dealership:changeVehicleClient', -1, spotIndex, newModel, carConfig)
end)

-- Lock/unlock spot
RegisterNetEvent('gang_dealership:lockSpot', function(spotIndex, lock)
    local src = source
    
    if not showroomVehicles[spotIndex] then return end
    
    if lock then
        vehicleLocks[spotIndex] = src
        print('^3[car_showroom] Player ' .. src .. ' locked spot ' .. spotIndex .. '^7')
    else
        if vehicleLocks[spotIndex] == src then
            vehicleLocks[spotIndex] = nil
            print('^3[car_showroom] Player ' .. src .. ' unlocked spot ' .. spotIndex .. '^7')
        end
    end
end)

-- Cleanup when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    
    for i, lockOwner in pairs(vehicleLocks) do
        if lockOwner == src then
            vehicleLocks[i] = nil
            print('^3[car_showroom] Unlocked spot ' .. i .. ' (player disconnected)^7')
        end
    end
end)

-- Sell Car Event
RegisterNetEvent('gang_dealership:sellCar', function(targetId, model, price)
    local src = source
    local seller = QBCore.Functions.GetPlayer(src)
    local buyer = QBCore.Functions.GetPlayer(targetId)
    
    if not seller or not buyer then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Играчът не е намерен!',
            type = 'error'
        })
        return
    end
    
    local hasAccess = false
    if Config.UseGang then
        hasAccess = seller.PlayerData.gang.name == Config.DealerJob
    else
        hasAccess = seller.PlayerData.job.name == Config.DealerJob
    end
    
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Нямаш право да продаваш коли!',
            type = 'error'
        })
        return
    end
    
    -- Провери разстоянието
    local sellerPed = GetPlayerPed(src)
    local buyerPed = GetPlayerPed(targetId)
    local sellerCoords = GetEntityCoords(sellerPed)
    local buyerCoords = GetEntityCoords(buyerPed)
    local distance = #(sellerCoords - buyerCoords)
    
    if distance > 10.0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Играчът е твърде далеч!',
            type = 'error'
        })
        return
    end
    
    local carData = nil
    for _, car in ipairs(Config.ShowroomCars) do
        if car.model == model then
            carData = car
            break
        end
    end
    
    if not carData then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Невалиден модел кола!',
            type = 'error'
        })
        return
    end
    
    if not HasBankMoney(targetId, price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Купувачът няма достатъчно пари в банката!',
            type = 'error'
        })
        TriggerClientEvent('ox_lib:notify', targetId, {
            title = 'Грешка',
            description = 'Нямаш достатъчно пари в банката!',
            type = 'error'
        })
        return
    end
    
    local commission = math.floor(price * Config.Commission)
    
    local success = RemoveBankMoney(targetId, price, 'Покупка на автомобил: ' .. (carData.label or model))
    
    if not success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Грешка при транзакцията!',
            type = 'error'
        })
        return
    end
    
    local gangName = Config.UseGang and seller.PlayerData.gang.name or seller.PlayerData.job.name
    local gangProfit = price - commission
    
    print('^3[Gang Dealership] Attempting to add $' .. gangProfit .. ' to gang: ' .. gangName .. '^7')
    print('^3[Gang Dealership] Renewed-Banking state: ' .. GetResourceState('Renewed-Banking') .. '^7')
    
    if GetResourceState('Renewed-Banking') == 'started' then
        local accountAdded = exports['Renewed-Banking']:addAccountMoney(gangName, gangProfit)
        
        print('^3[Gang Dealership] addAccountMoney result: ' .. tostring(accountAdded) .. '^7')
        
        if not accountAdded then
            print('^1[Gang Dealership] ERROR: Failed to add money to gang account: ' .. gangName .. '^7')
            print('^1[Gang Dealership] Make sure the account exists: /createaccount ' .. gangName .. '^7')
            
            exports['Renewed-Banking']:addAccountMoney(buyer.PlayerData.citizenid, price)
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Грешка',
                description = 'Gang account "' .. gangName .. '" не съществува!',
                type = 'error'
            })
            return
        end
        
        print('^2[Gang Dealership] Successfully added $' .. gangProfit .. ' to gang account: ' .. gangName .. '^7')
    else
        print('^1[Gang Dealership] ERROR: Renewed-Banking not started!^7')
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Предупреждение',
            description = 'Renewed-Banking не е стартиран!',
            type = 'warning'
        })
    end
    
    seller.Functions.AddMoney('cash', commission, 'dealership-commission')
    
    local plate = GeneratePlate()
    
    -- Send Discord log
    SendDiscordLog(seller, buyer, carData, price, commission)
    
    local priceFormatted = tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    local commissionFormatted = tostring(commission):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Продажба успешна',
        description = string.format('Получи $%s комисионна!', commissionFormatted),
        type = 'success'
    })
    
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = 'Покупка',
        description = string.format('Закупи %s за $%s', carData.label or model, priceFormatted),
        type = 'info'
    })
    
    TriggerClientEvent('gang_dealership:receiveCar', targetId, model, plate, carData)
end)

-- Save Vehicle to Database
RegisterNetEvent('gang_dealership:saveVehicle', function(props, plate, modelName)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    
    if not player then 
        print('[Gang Dealership] ERROR: Player not found when saving vehicle')
        return 
    end
    
    print('^3[Gang Dealership] Saving vehicle to DB...^7')
    print('^3Model: ' .. modelName .. ', Plate: ' .. plate .. '^7')
    
    exports.oxmysql:insert('INSERT INTO player_vehicles (citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?)', {
        player.PlayerData.citizenid,
        modelName,
        props.model,
        json.encode(props),
        plate,
        0
    }, function(insertId)
        if insertId then
            print(string.format('^2[Gang Dealership] Vehicle saved successfully. ID: %s, Plate: %s^7', insertId, plate))
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Успех',
                description = 'Колата е записана в системата!',
                type = 'success'
            })
        else
            print('^1[Gang Dealership] ERROR: Insert returned no ID^7')
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Грешка',
                description = 'Проблем при записване в базата данни!',
                type = 'error'
            })
        end
    end)
end)

-- Command to check nearby players
QBCore.Commands.Add('nearby', 'Виж близки играчи', {}, false, function(source)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    
    local hasAccess = false
    if Config.UseGang then
        hasAccess = player.PlayerData.gang.name == Config.DealerJob
    else
        hasAccess = player.PlayerData.job.name == Config.DealerJob
    end
    
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Нямаш достъп до тази команда!',
            type = 'error'
        })
        return
    end
    
    local players = QBCore.Functions.GetPlayers()
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local nearby = {}
    
    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(coords - targetCoords)
        
        if distance < 10.0 and playerId ~= src then
            local targetPlayer = QBCore.Functions.GetPlayer(playerId)
            if targetPlayer then
                nearby[#nearby + 1] = string.format('ID: %d | %s %s | Разстояние: %.1fm', 
                    playerId, 
                    targetPlayer.PlayerData.charinfo.firstname,
                    targetPlayer.PlayerData.charinfo.lastname,
                    distance)
            end
        end
    end
    
    if #nearby > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Близки играчи',
            description = table.concat(nearby, '\n'),
            type = 'info',
            duration = 8000
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Близки играчи',
            description = 'Няма играчи наблизо',
            type = 'info'
        })
    end
end)

-- Callback за близки играчи (за менютата)
QBCore.Functions.CreateCallback('gang_dealership:getNearbyPlayers', function(source, cb)
    local src = source
    local players = QBCore.Functions.GetPlayers()
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local nearby = {}
    
    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(coords - targetCoords)
        
        if distance < 10.0 and playerId ~= src then
            local targetPlayer = QBCore.Functions.GetPlayer(playerId)
            if targetPlayer then
                nearby[#nearby + 1] = {
                    id = playerId,
                    name = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
                    distance = distance
                }
            end
        end
    end
    
    cb(nearby)
end)

-- Start test drive for player
RegisterNetEvent('gang_dealership:startTestDrive', function(targetId, model, freeSpot)
    local src = source
    local seller = QBCore.Functions.GetPlayer(src)
    local buyer = QBCore.Functions.GetPlayer(targetId)
    
    if not seller or not buyer then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Играчът не е намерен!',
            type = 'error'
        })
        return
    end
    
    local hasAccess = false
    if Config.UseGang then
        hasAccess = seller.PlayerData.gang.name == Config.DealerJob
    else
        hasAccess = seller.PlayerData.job.name == Config.DealerJob
    end
    
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Нямаш право да даваш тест драйв!',
            type = 'error'
        })
        return
    end
    
    -- Провери разстоянието
    local sellerPed = GetPlayerPed(src)
    local buyerPed = GetPlayerPed(targetId)
    local sellerCoords = GetEntityCoords(sellerPed)
    local buyerCoords = GetEntityCoords(buyerPed)
    local distance = #(sellerCoords - buyerCoords)
    
    if distance > 10.0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Грешка',
            description = 'Играчът е твърде далеч!',
            type = 'error'
        })
        return
    end
    
    -- Изпрати тест драйв към купувача
    TriggerClientEvent('gang_dealership:receiveTestDrive', targetId, model, freeSpot)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Тест драйв',
        description = 'Дадохте тест драйв на ' .. buyer.PlayerData.charinfo.firstname .. ' ' .. buyer.PlayerData.charinfo.lastname,
        type = 'success'
    })
    
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = 'Тест драйв',
        description = seller.PlayerData.charinfo.firstname .. ' ' .. seller.PlayerData.charinfo.lastname .. ' ти даде тест драйв!',
        type = 'info'
    })
end)
