local ESX = exports['es_extended']:getSharedObject()
local ValidItems = {}
local ActiveSessions = {}
local CancelCooldowns = {} 
---------------------------- GitHub Version Check ----------------------------
CreateThread(function()
    local resourceName = GetCurrentResourceName()
    local currentVersion = GetResourceMetadata(resourceName, "version", 0)
    
    if currentVersion == nil then
        print("^1[Wari_FoodSystem] You removed version from fxmanifest, redownload script.^7")
        return
    end

    PerformHttpRequest("https://raw.githubusercontent.com/WariGG/Wari_FoodSystem/main/fxmanifest.lua", function(errorCode, resultData, resultHeaders)
        if errorCode == 200 then
            local latestVersion = string.match(resultData, "version%s+['\"](.-)['\"]")
            
            if latestVersion == nil then
                print("^1[Wari_FoodSystem] Failed to fetch latest version from GitHub.^7")
                return
            end

            if currentVersion == latestVersion then
                print("^2[Wari_FoodSystem] is UP TO DATE! (Version: " .. currentVersion .. ")^7")
            else
                print("^1[Wari_FoodSystem] is OUTDATED, download new version!^7")
                print("^1Current Version: " .. currentVersion .. "^7")
                print("^2Latest Version: " .. latestVersion .. "^7")
                print("^3Download the latest update from: https://github.com/WariGG/Wari_FoodSystem^7")
            end
        else
            print("^1[Wari_FoodSystem] GitHub API request failed. Error code: " .. tostring(errorCode) .. "^7")
        end
    end, "GET", "", "")
end)
------------------------------------------------------------------------------

CreateThread(function()
    for jobName, categories in pairs(Config.JobItems) do
        if categories.food then
            for _, itemName in ipairs(categories.food) do
                if not ValidItems[itemName] then ValidItems[itemName] = { jobs = {}, type = 'food' } end
                ValidItems[itemName].jobs[jobName] = true
            end
        end
        if categories.drinks then
            for _, itemName in ipairs(categories.drinks) do
                if not ValidItems[itemName] then ValidItems[itemName] = { jobs = {}, type = 'drink' } end
                ValidItems[itemName].jobs[jobName] = true
            end
        end
    end

    for itemName, data in pairs(ValidItems) do
        ESX.RegisterUsableItem(itemName, function(source)
            local xPlayer = ESX.GetPlayerFromId(source)
            if not xPlayer then return end
            
            if not data.jobs[xPlayer.job.name] then
                TriggerClientEvent('ox_lib:notify', source, { title = 'Food Systém', description = 'Tohle jídlo není z tvojí restaurace!', type = 'error' })
                return
            end
            
            TriggerClientEvent('Wari_FoodSystem:client:openMenu', source, itemName, data.type)
        end)
    end
end)

lib.callback.register('Wari_FoodSystem:getPlayerNames', function(source, serverIds)
    local names = {}
    for _, id in ipairs(serverIds) do
        local xPlayer = ESX.GetPlayerFromId(id)
        if xPlayer then
            names[id] = xPlayer.name
        end
    end
    return names
end)

RegisterNetEvent('Wari_FoodSystem:server:triggerTarget', function(targetServerId, itemName, itemType)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetServerId)
    
    if not xPlayer or not xTarget then return end
    
    local validJob = false
    if Config.JobItems[xPlayer.job.name] then
        local cat = itemType == 'food' and Config.JobItems[xPlayer.job.name].food or Config.JobItems[xPlayer.job.name].drinks
        if cat then
            for _, name in ipairs(cat) do
                if name == itemName then
                    validJob = true
                    break
                end
            end
        end
    end
    
    if not validJob then
        return TriggerClientEvent('ox_lib:notify', source, { title = 'Food Systém', description = 'Tohle jídlo není z tvojí restaurace!', type = 'error' })
    end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetServerId))
    
    if #(playerCoords - targetCoords) > 5.0 then
        return TriggerClientEvent('ox_lib:notify', source, { title = 'Food Systém', description = 'Osoba je moc daleko.', type = 'error' })
    end
    
    local itemCount = exports.ox_inventory:Search(source, 'count', itemName)
    if not itemCount or itemCount < 1 then 
        return TriggerClientEvent('ox_lib:notify', source, { title = 'Food Systém', description = 'Nemáš tento předmět.', type = 'error' })
    end
    
    exports.ox_inventory:RemoveItem(source, itemName, 1)

    ActiveSessions[targetServerId] = { sourceId = source, itemName = itemName, itemType = itemType }
    
    TriggerClientEvent('Wari_FoodSystem:client:consumeItem', targetServerId, itemName, itemType, source)
end)

RegisterNetEvent('Wari_FoodSystem:server:finishConsume', function(sourceId, itemName, itemType)
    local targetServerId = source

    local session = ActiveSessions[targetServerId]
    if not session or session.sourceId ~= sourceId or session.itemName ~= itemName or session.itemType ~= itemType then
        return
    end
    
    ActiveSessions[targetServerId] = nil
    
    local xTarget = ESX.GetPlayerFromId(targetServerId)
    if not xTarget then return end
    
    local statName = itemType == 'food' and 'hunger' or 'thirst'
    TriggerClientEvent('esx_status:add', targetServerId, statName, 1000000)
    
    local xSource = ESX.GetPlayerFromId(sourceId)
    if xSource then
        local msgSrc = itemType == 'food' and 'Osoba snědla tvoje jídlo.' or 'Osoba vypila tvoje pití.'
        TriggerClientEvent('ox_lib:notify', sourceId, { title = 'Success', description = msgSrc, type = 'success' })
    end
end)

RegisterNetEvent('Wari_FoodSystem:server:notifyCancel', function(sourceId)
    local targetServerId = source
    
    local now = GetGameTimer()
    if CancelCooldowns[targetServerId] and (now - CancelCooldowns[targetServerId]) < 5000 then return end
    CancelCooldowns[targetServerId] = now
    
    local session = ActiveSessions[targetServerId]
    if not session or session.sourceId ~= sourceId then return end

    ActiveSessions[targetServerId] = nil

    local xSource = ESX.GetPlayerFromId(sourceId)
    if xSource then
        TriggerClientEvent('ox_lib:notify', sourceId, { title = 'Food Systém', description = 'Osoba přerušila pití/jezení.', type = 'error' })
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    ActiveSessions[source] = nil
    CancelCooldowns[source] = nil
    for targetId, session in pairs(ActiveSessions) do
        if session.sourceId == source then
            ActiveSessions[targetId] = nil
        end
    end
end)
