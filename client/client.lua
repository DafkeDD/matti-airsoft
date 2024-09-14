-- client.lua
local QBCore = exports['qb-core']:GetCoreObject()
local isHit = false
local airsoftZone, currentLoadout = nil, nil
local enterPed, exitPed -- Variables for interaction peds
local debugPeds = {} -- Table to store debug peds
local originalInventory = {} -- Store the player's original inventory

-- Function to get the player's full name
local function GetPlayerName()
    local player = QBCore.Functions.GetPlayerData()
    return player.charinfo.firstname .. ' ' .. player.charinfo.lastname
end

-- Function to handle notifications
local function SendNotification(message, type)
    if Config.NotifySystem == 'ox_lib' then
        local notificationStyle = {}
        local icon = 'info-circle'
        local iconColor = '#FFFFFF'

        if type == 'success' then
            notificationStyle = { color = '#28A745', ['.description'] = { color = '#E9ECEF' } }
            icon = 'check-circle'
            textColor = '#28A745'
        elseif type == 'error' then
            notificationStyle = { color = '#DC3545', ['.description'] = { color = '#E9ECEF' } }
            icon = 'times-circle'
            textColor = '#DC3545'
        else
            notificationStyle = { color = '#F08080', ['.description'] = { color = '#909296' } }
            icon = 'info-circle'
            textColor = '#F08080'
        end
        
        lib.notify({
            title = message,
            style = notificationStyle,
            icon = icon,
            iconColor = textColor,
        })
    else
        QBCore.Functions.Notify(message, type)
    end
end

RegisterNetEvent('matti-airsoft:sendNotification')
AddEventHandler('matti-airsoft:sendNotification', function(message, type)
    SendNotification(message, type)
end)

-- Function to save the player's inventory and clear it
local function SaveAndClearInventory()
    local playerData = QBCore.Functions.GetPlayerData()
    originalInventory = playerData.items or {}

    for _, item in pairs(originalInventory) do
        TriggerServerEvent('matti-airsoft:removeItem', item.name, item.amount)
    end
end

-- Function to restore the player's inventory
local function RestoreInventory()
    for _, item in pairs(originalInventory) do
        TriggerServerEvent('matti-airsoft:giveItem', item.name, item.amount)
    end
    originalInventory = {}
end

-- Function to teleport player to a random spawn location
local function TeleportToRandomPosition()
    local randomCoord = Config.SpawnLocations[math.random(1, #Config.SpawnLocations)]
    SetEntityCoords(PlayerPedId(), randomCoord)
end

-- Function to spawn a ped with given parameters
local function SpawnPed(modelHash, coords, event, icon, label)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(100)
    end

    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if Config.TargetSystem == 'qb-target' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = 'client',
                    event = event,
                    icon = icon,
                    label = label
                },
            },
            distance = 2.5
        })
    elseif Config.TargetSystem == 'ox_target' then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'airsoft_menu',
                label = label,
                onSelect = function()
                    TriggerEvent(event)
                end,
                icon = icon,
                distance = 2.5,
            }
        })
        
    end
    return ped
end

-- Function to create airsoft blip
local function CreateAirsoftBlip()
    if Config.AirsoftBlip.enabled then
        local blip = AddBlipForCoord(Config.AirsoftBlip.coords)
        SetBlipSprite(blip, Config.AirsoftBlip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.AirsoftBlip.scale)
        SetBlipColour(blip, Config.AirsoftBlip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.AirsoftBlip.name)
        EndTextCommandSetBlipName(blip)
    end
end

-- Function to handle loadout selection
local function HandleLoadoutSelection(loadout)
    QBCore.Functions.TriggerCallback('matti-airsoft:canAffordLoadout', function(canAfford)
        if canAfford then
            SaveAndClearInventory()
            for _, weapon in ipairs(loadout.weapons) do
                TriggerServerEvent('matti-airsoft:giveWeapon', weapon.name)
            end
            for _, ammo in ipairs(loadout.ammo) do
                TriggerServerEvent('matti-airsoft:giveItem', ammo.name, ammo.amount)
            end
            currentLoadout = loadout
            SendNotification('You have selected the "' .. loadout.name .. '" loadout!', 'success')
            TeleportToRandomPosition()
        else
            SendNotification(Lang:t('notifications.cannot_afford'), 'error')
        end
    end, loadout.price)
end


-- Function to check hit status
local function CheckHitStatus()
    Citizen.CreateThread(function()
        while airsoftZone:isPointInside(GetEntityCoords(PlayerPedId())) do
            Citizen.Wait(100)
            local playerPed = PlayerPedId()

            if IsPedBeingStunned(playerPed, 0) or IsEntityDead(playerPed) then
                if not isHit then
                    isHit = true
                    TriggerServerEvent('matti-airsoft:hitNotify', GetPlayerServerId(PlayerId()), GetPlayerName())
                    SendNotification(Lang:t('inarena.shot'))
                    SetEntityCoords(playerPed, Config.ReturnLocation)
                end
            else
                isHit = false
            end
        end
    end)
end

-- Function to handle entering or exiting airsoft zone
local function HandleZoneEntry(isPointInside)
    if isPointInside then
        SendNotification(Lang:t('notifications.entered'), 'success')
        if Config.Debug then
            TriggerServerEvent('matti-airsoft:debugZoneEntry', GetPlayerName(), 'entered')
        end
        CheckHitStatus()
    else
        SendNotification(Lang:t('notifications.exited'), 'error')
        if Config.Debug then
            TriggerServerEvent('matti-airsoft:debugZoneEntry', GetPlayerName(), 'exited')
        end
        RemoveLoadout()
        RestoreInventory()
        isHit = false
    end
end

-- Create the airsoft zone based on configuration
Citizen.CreateThread(function()
    if Config.ZoneType == 'circle' then
        airsoftZone = CircleZone:Create(Config.AirsoftZone.coordinates, Config.AirsoftZone.radius, {
            debugPoly = Config.Debug
        })
    elseif Config.ZoneType == 'poly' then
        airsoftZone = PolyZone:Create(Config.AirsoftZone.points, {
            debugPoly = Config.Debug
        })
    end
    airsoftZone:onPlayerInOut(HandleZoneEntry)

    enterPed = SpawnPed(GetHashKey(Config.EnterLocation.model), Config.EnterLocation.coords, 'matti-airsoft:openLoadoutMenu', 'fas fa-crosshairs', Lang:t('menu.choose_loadout'))
    exitPed = SpawnPed(GetHashKey(Config.ExitLocation.model), Config.ExitLocation.coords, 'matti-airsoft:exitArena', 'fas fa-door-open', Lang:t('menu.exit_arena'))
    
    CreateAirsoftBlip()

    if Config.Debug then
        for _, loc in ipairs(Config.SpawnLocations) do
            local ped = CreatePed(4, GetHashKey(Config.EnterLocation.model), loc.x, loc.y, loc.z - 1.0, 0.0, false, true)
            SetEntityAlpha(ped, 100, false)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            table.insert(debugPeds, ped)
        end
    end
end)

-- Event to handle qb-target loadout selection
RegisterNetEvent('matti-airsoft:openLoadoutMenu')
AddEventHandler('matti-airsoft:openLoadoutMenu', function()
    local loadoutMenu = {}

    for i, loadout in ipairs(Config.Loadouts) do
        local weaponsList, ammoList = '', ''
        for _, weapon in ipairs(loadout.weapons) do
            weaponsList = weaponsList .. weapon.label .. '\n'
        end
        for _, ammo in ipairs(loadout.ammo) do
            ammoList = ammoList .. ' (' .. ammo.amount .. ' clips)\n'
        end
        
        -- Configured loadout options
        if Config.MenuSystem == 'ox_lib' then
            table.insert(loadoutMenu, {
                title = loadout.name,
                description = 'Includes:\n' .. weaponsList .. ammoList .. '\nPrice: $' .. loadout.price,
                event = 'matti-airsoft:selectLoadout',
                args = { loadout = loadout },
                icon = 'fas fa-crosshairs',
                iconColor = '#EC213A'
            })
        else
            table.insert(loadoutMenu, {
                header = loadout.name,
                txt = 'Includes:\n' .. weaponsList .. ammoList .. '\nPrice: $' .. loadout.price,
                params = {
                    event = 'matti-airsoft:selectLoadout',
                    args = { loadout = loadout }
                }
            })
        end
    end

    -- Own loadout option
    if Config.MenuSystem == 'ox_lib' then
        table.insert(loadoutMenu, {
            title = Lang:t('menu.own_loadout'),
            description = Lang:t('menu.own_loadout_txt'),
            event = 'matti-airsoft:teleportOnly',
            icon = 'fas fa-box',
            iconColor = '#33A532'
        })
    else
        table.insert(loadoutMenu, {
            header = Lang:t('menu.own_loadout'),
            txt = Lang:t('menu.own_loadout_txt'),
            params = { event = 'matti-airsoft:teleportOnly' }
        })
    end

    -- Random loadout option
    if Config.MenuSystem == 'ox_lib' then
        table.insert(loadoutMenu, {
            title = Lang:t('menu.random_loadout'),
            description = Lang:t('menu.random_loadout_txt'),
            event = 'matti-airsoft:giveRandomGun',
            icon = 'fas fa-random',
            iconColor = '#EC213A'
        })
    else
        table.insert(loadoutMenu, {
            header = Lang:t('menu.random_loadout'),
            txt = Lang:t('menu.random_loadout_txt'),
            params = { event = 'matti-airsoft:giveRandomGun' }
        })
    end

    -- Open menu
    if Config.MenuSystem == 'ox_lib' then
        lib.registerContext({
            id = 'matti_airsoft_loadout_menu',
            title = Lang:t('menu.choose_loadout'),
            options = loadoutMenu
        })
        lib.showContext('matti_airsoft_loadout_menu')
    else
        exports['qb-menu']:openMenu(loadoutMenu)
    end
end)

RegisterNetEvent('matti-airsoft:teleportOnly')
AddEventHandler('matti-airsoft:teleportOnly', function()
    TeleportToRandomPosition()
end)

RegisterNetEvent('matti-airsoft:giveRandomGun')
AddEventHandler('matti-airsoft:giveRandomGun', function()
    local randomIndex = math.random(1, #Config.Loadouts)
    HandleLoadoutSelection(Config.Loadouts[randomIndex])
end)

RegisterNetEvent('matti-airsoft:selectLoadout')
AddEventHandler('matti-airsoft:selectLoadout', function(data)
    HandleLoadoutSelection(data.loadout)
end)

RegisterNetEvent('matti-airsoft:exitArena')
AddEventHandler('matti-airsoft:exitArena', function()
    RemoveLoadout()
    RestoreInventory()
    SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
end)

RegisterNetEvent('matti-airsoft:checkIfInArena')
AddEventHandler('matti-airsoft:checkIfInArena', function(adminId)
    local isInArena = airsoftZone:isPointInside(GetEntityCoords(PlayerPedId()))
    TriggerServerEvent('matti-airsoft:reportArenaStatus', adminId, isInArena)
end)

RegisterNetEvent('matti-airsoft:forceExitArena')
AddEventHandler('matti-airsoft:forceExitArena', function()
    if airsoftZone:isPointInside(GetEntityCoords(PlayerPedId())) then
        RemoveLoadout()
        RestoreInventory()
        SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
        SendNotification(Lang:t('notifications.force_exit'), 'error')
    end
end)

function RemoveLoadout()
    local playerPed = PlayerPedId()
    for _, loadout in ipairs(Config.Loadouts) do
        for _, weapon in ipairs(loadout.weapons) do
            if QBCore.Functions.HasItem(weapon.name) then
                TriggerServerEvent('matti-airsoft:removeWeapon', weapon.name)
            end
        end

        for _, ammo in ipairs(loadout.ammo) do
            local items = QBCore.Functions.GetPlayerData().items
            for _, item in pairs(items) do
                if item.name == ammo.name and item.amount > 0 then
                    TriggerServerEvent('matti-airsoft:removeItem', ammo.name, item.amount)
                end
            end
        end
    end
    currentLoadout = nil
end