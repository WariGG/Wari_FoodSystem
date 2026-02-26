local ESX = exports['es_extended']:getSharedObject()

local function applyItemToTarget(targetServerId, itemName, itemType)
    TriggerServerEvent('Wari_FoodSystem:server:triggerTarget', targetServerId, itemName, itemType)
end

RegisterNetEvent('Wari_FoodSystem:client:consumeItem')
AddEventHandler('Wari_FoodSystem:client:consumeItem', function(itemName, itemType, sourceId)
    local animDict = itemType == 'drink' and 'mp_player_intdrink' or 'anim@eat@fork'
    local animClip = itemType == 'drink' and 'loop_bottle' or 'fork_clip'
    local progressLabel = itemType == 'food' and 'Jíš...' or 'Piješ...'
    
    local prop = nil
    local plateProp = nil
    if itemType == 'food' then
        RequestModel(`alcaprop_fork`)
        while not HasModelLoaded(`alcaprop_fork`) do Wait(0) end
        prop = CreateObject(`alcaprop_fork`, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, 57005),
            0.11, 0.03, -0.04,
            2.9, -0.5, -15.5,
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(`alcaprop_fork`)

        RequestModel(`v_res_mplatesml`)
        while not HasModelLoaded(`v_res_mplatesml`) do Wait(0) end
        plateProp = CreateObject(`v_res_mplatesml`, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(plateProp, cache.ped, GetPedBoneIndex(cache.ped, 18905),
            0.14, 0.05, 0.0,
            0.0, 0.0, 0.0,
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(`v_res_mplatesml`)
    end
    local animRunning = true
    CreateThread(function()
        lib.requestAnimDict(animDict)
        while animRunning do
            if not IsEntityPlayingAnim(cache.ped, animDict, animClip, 3) then
                TaskPlayAnim(cache.ped, animDict, animClip, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(500)
        end
        ClearPedTasks(cache.ped)
    end)
    
    if lib.progressBar({
        duration = 20000,
        label = progressLabel,
        useWhileDead = false,
        canCancel = false,
        disable = { car = true, combat = true },
        anim = false
    }) then
        animRunning = false
        if prop then DeleteObject(prop) end
        if plateProp then DeleteObject(plateProp) end
        TriggerServerEvent('Wari_FoodSystem:server:finishConsume', sourceId, itemName, itemType)
    else
        animRunning = false
        if prop then DeleteObject(prop) end
        if plateProp then DeleteObject(plateProp) end
        lib.notify({ title = 'Cancelled', description = 'Jezení/Pití bylo přerušeno.', type = 'error' })
        TriggerServerEvent('Wari_FoodSystem:server:notifyCancel', sourceId)
    end
end)

RegisterNetEvent('Wari_FoodSystem:client:openMenu', function(itemName, itemType)
    local nearbyPlayers = lib.getNearbyPlayers(GetEntityCoords(cache.ped), 3.0, false)
    
    if #nearbyPlayers == 0 then
        lib.notify({ title = 'Error', description = 'Nikdo není v okolí.', type = 'error' })
        return
    end
    
    local serverIds = {}
    for _, player in ipairs(nearbyPlayers) do
        table.insert(serverIds, GetPlayerServerId(player.id))
    end
    
    local names = lib.callback.await('Wari_FoodSystem:getPlayerNames', false, serverIds)
    
    local menuOptions = {}
    for _, player in ipairs(nearbyPlayers) do
        local targetServerId = GetPlayerServerId(player.id)
        local displayName = (names and names[targetServerId]) or ('Player ' .. targetServerId)
        
        table.insert(menuOptions, {
            title = displayName,
            description = itemType == 'food' and 'Dát jídlo' or 'Dát pití',
            icon = 'user',
            onSelect = function()
                applyItemToTarget(targetServerId, itemName, itemType)
            end
        })
    end
    
    lib.registerContext({
        id = 'food_target_menu',
        title = 'Vyber osobu',
        options = menuOptions,
        canClose = true
    })
    
    lib.showContext('food_target_menu')
end)
