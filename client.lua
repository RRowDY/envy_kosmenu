local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('QBCore:Client:UpdateObject', function() QBCore = exports['qb-core']:GetCoreObject() end)

-- NUI State
local isMenuOpen = false

-- Functions
local function OpenKOSMenu()
    if isMenuOpen then return end
    
    -- Get player data
    QBCore.Functions.TriggerCallback('envy_kosmenu:hasPermission', function(hasPermission)
        QBCore.Functions.TriggerCallback('envy_kosmenu:getCurrentBucket', function(currentBucket)
            local menuData = {
                hasPermission = hasPermission,
                currentBucket = currentBucket,
                canLeaveBucket = currentBucket ~= 0,
                inBucket = currentBucket ~= 0, -- True if in a bucket (not 0)
                canUseBucketActions = hasPermission and currentBucket ~= 0 -- Admin/god in a bucket
            }
            
            -- If admin, get additional data
            if hasPermission then
                QBCore.Functions.TriggerCallback('envy_kosmenu:getBuckets', function(buckets)
                    QBCore.Functions.TriggerCallback('envy_kosmenu:getPlayers', function(players)
                        -- Get bucket players for spectate button
                        QBCore.Functions.TriggerCallback('envy_kosmenu:getBucketPlayers', function(bucketPlayers)
                            menuData.buckets = buckets
                            menuData.players = players
                            menuData.bucketPlayers = bucketPlayers
                            menuData.logoImage = Config.LogoImage -- Logo image path from config
                            
                            isMenuOpen = true
                            SetNuiFocus(true, true)
                            
                            SendNUIMessage({
                                action = 'openMenu',
                                data = menuData
                            })
                        end)
                    end)
                end)
            else
                menuData.logoImage = Config.LogoImage -- Logo image path from config
                isMenuOpen = true
                SetNuiFocus(true, true)
                
                SendNUIMessage({
                    action = 'openMenu',
                    data = menuData
                })
            end
        end)
    end)
end

local function CloseKOSMenu()
    if not isMenuOpen then return end
    
    isMenuOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = 'closeMenu'
    })
end

local function RefreshMenu()
    if not isMenuOpen then return end
    
    -- Refresh menu data
    QBCore.Functions.TriggerCallback('envy_kosmenu:hasPermission', function(hasPermission)
        QBCore.Functions.TriggerCallback('envy_kosmenu:getCurrentBucket', function(currentBucket)
            local menuData = {
                hasPermission = hasPermission,
                currentBucket = currentBucket,
                canLeaveBucket = currentBucket ~= 0,
                inBucket = currentBucket ~= 0, -- True if in a bucket (not 0)
                canUseBucketActions = hasPermission and currentBucket ~= 0 -- Admin/god in a bucket
            }
            
            if hasPermission then
                QBCore.Functions.TriggerCallback('envy_kosmenu:getBuckets', function(buckets)
                    QBCore.Functions.TriggerCallback('envy_kosmenu:getPlayers', function(players)
                        -- Get bucket players for spectate button
                        QBCore.Functions.TriggerCallback('envy_kosmenu:getBucketPlayers', function(bucketPlayers)
                            menuData.buckets = buckets
                            menuData.players = players
                            menuData.bucketPlayers = bucketPlayers
                            
                            SendNUIMessage({
                                action = 'updateMenu',
                                data = menuData
                            })
                        end)
                    end)
                end)
            else
                SendNUIMessage({
                    action = 'updateMenu',
                    data = menuData
                })
            end
        end)
    end)
end

-- Command
RegisterCommand('kosmenu', function()
    OpenKOSMenu()
end, false)

-- Refresh menu event
RegisterNetEvent('envy_kosmenu:refreshMenu', function()
    RefreshMenu()
end)

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(data, cb)
    CloseKOSMenu()
    cb('ok')
end)

RegisterNUICallback('createBucket', function(data, cb)
    local bucketId = tonumber(data.bucketId)
    if not bucketId then
        cb('error')
        return
    end
    
    TriggerServerEvent('envy_kosmenu:createBucket', bucketId)
    cb('ok')
end)

RegisterNUICallback('deleteBucket', function(data, cb)
    local bucketId = tonumber(data.bucketId)
    if not bucketId then
        cb('error')
        return
    end
    
    TriggerServerEvent('envy_kosmenu:deleteBucket', bucketId)
    cb('ok')
end)

RegisterNUICallback('teleportToBucket', function(data, cb)
    local targetPlayerId = tonumber(data.targetPlayerId)
    local bucketId = tonumber(data.bucketId)
    
    if not targetPlayerId or not bucketId then
        cb('error')
        return
    end
    
    TriggerServerEvent('envy_kosmenu:teleportToBucket', targetPlayerId, bucketId)
    cb('ok')
end)

RegisterNUICallback('leaveBucket', function(data, cb)
    TriggerServerEvent('envy_kosmenu:leaveBucket')
    cb('ok')
end)

RegisterNUICallback('giveAmmo', function(data, cb)
    TriggerServerEvent('envy_kosmenu:giveAmmo')
    cb('ok')
end)

RegisterNUICallback('repairWeapons', function(data, cb)
    TriggerServerEvent('envy_kosmenu:repairWeapons')
    cb('ok')
end)

RegisterNUICallback('revivePlayers', function(data, cb)
    TriggerServerEvent('envy_kosmenu:revivePlayers')
    cb('ok')
end)

RegisterNUICallback('spectatePlayer', function(data, cb)
    -- Close menu when starting spectate
    CloseKOSMenu()
    
    -- Get players in bucket and show selection
    QBCore.Functions.TriggerCallback('envy_kosmenu:getBucketPlayers', function(players)
        if #players == 0 then
            QBCore.Functions.Notify('No players available to spectate in this bucket', 'error')
            cb('ok')
            return
        end
        
        -- Start spectating first player (can cycle with arrows)
        TriggerServerEvent('envy_kosmenu:startSpectate', players[1].id)
        
        cb('ok')
    end)
end)

RegisterNUICallback('moveBucket', function(data, cb)
    TriggerServerEvent('envy_kosmenu:moveBucket')
    cb('ok')
end)

RegisterNUICallback('updateScoreboard', function(data, cb)
    TriggerServerEvent('envy_kosmenu:updateScoreboard', data)
    cb('ok')
end)

RegisterNUICallback('adjustScore', function(data, cb)
    TriggerServerEvent('envy_kosmenu:adjustScore', data.team, data.score)
    cb('ok')
end)

RegisterNUICallback('getScoreboard', function(data, cb)
    QBCore.Functions.TriggerCallback('envy_kosmenu:getScoreboard', function(scoreboardData)
        cb(scoreboardData)
    end)
end)

RegisterNUICallback('getKillLog', function(data, cb)
    local page = data.page or 1
    QBCore.Functions.TriggerCallback('envy_kosmenu:getKillLog', function(killLogData)
        cb(killLogData)
    end, page)
end)

-- Set armor event (for revive)
RegisterNetEvent('envy_kosmenu:client:SetArmor', function(armor)
    local ped = PlayerPedId()
    SetPedArmour(ped, armor)
end)

-- Give ammo event (uses SetPedAmmo for current weapon)
RegisterNetEvent('envy_kosmenu:client:GiveAmmo', function()
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    
    -- Only set ammo if player has a weapon out
    if weapon and weapon ~= GetHashKey('WEAPON_UNARMED') then
        SetPedAmmo(ped, weapon, 250)
        QBCore.Functions.Notify('Ammo set to 250 for your current weapon', 'success')
    else
        QBCore.Functions.Notify('You must have a weapon out to receive ammo', 'error')
    end
end)

-- Action result event (for NUI notifications)
RegisterNetEvent('envy_kosmenu:client:ActionResult', function(success, action, message)
    if isMenuOpen then
        SendNUIMessage({
            action = 'actionResult',
            success = success,
            actionType = action,
            message = message or ''
        })
    end
end)

-- Teleport to default location
RegisterNetEvent('envy_kosmenu:client:TeleportToDefault', function(location)
    local ped = PlayerPedId()
    SetEntityCoords(ped, location.x, location.y, location.z, false, false, false, true)
    if location.w then
        SetEntityHeading(ped, location.w)
    end
end)

-- Teleport to specific location (for move bucket)
RegisterNetEvent('envy_kosmenu:client:TeleportToLocation', function(location)
    local ped = PlayerPedId()
    SetEntityCoords(ped, location.x, location.y, location.z, false, false, false, true)
end)

-- Scoreboard variables
local scoreboardData = nil
local scoreboardVisible = false

-- Update scoreboard display
RegisterNetEvent('envy_kosmenu:client:UpdateScoreboard', function(data)
    scoreboardData = data
    scoreboardVisible = data.visible
    
    SendNUIMessage({
        action = 'updateScoreboard',
        data = data
    })
end)

-- Score change notification
RegisterNetEvent('envy_kosmenu:client:ScoreChange', function(teamName, oldScore, newScore)
    -- Show subtle notification
    QBCore.Functions.Notify(teamName .. ' score: ' .. oldScore .. ' → ' .. newScore, 'info', 3000)
    
    -- Also send to NUI for visual feedback
    SendNUIMessage({
        action = 'scoreChange',
        teamName = teamName,
        oldScore = oldScore,
        newScore = newScore
    })
end)

-- Function to load scoreboard for current bucket
local function LoadScoreboard()
    QBCore.Functions.TriggerCallback('envy_kosmenu:getCurrentBucket', function(currentBucket)
        if currentBucket ~= 0 then
            QBCore.Functions.TriggerCallback('envy_kosmenu:getScoreboard', function(data)
                if data then
                    scoreboardData = data
                    scoreboardVisible = data.visible
                    SendNUIMessage({
                        action = 'updateScoreboard',
                        data = data
                    })
                end
            end)
        else
            -- Clear scoreboard when not in a bucket
            scoreboardData = nil
            scoreboardVisible = false
            SendNUIMessage({
                action = 'updateScoreboard',
                data = nil
            })
        end
    end)
end

-- Function to clear scoreboard
local function ClearScoreboard()
    scoreboardData = nil
    scoreboardVisible = false
    SendNUIMessage({
        action = 'updateScoreboard',
        data = nil
    })
end

-- Load scoreboard when entering a bucket (via server events)
RegisterNetEvent('envy_kosmenu:client:LoadScoreboard', function()
    LoadScoreboard()
end)

-- Clear scoreboard when leaving bucket or bucket is deleted
RegisterNetEvent('envy_kosmenu:client:ClearScoreboard', function()
    ClearScoreboard()
end)

-- Track player deaths for kill log (QBCore approach)
AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim, attacker, victimDied, weapon = data[1], data[2], data[4], data[7]
        
        if not IsEntityAPed(victim) then return end
        if not victimDied then return end
        
        -- Check if victim is the local player
        if NetworkGetPlayerIndexFromPed(victim) ~= PlayerId() then return end
        if not IsEntityDead(PlayerPedId()) then return end
        
        -- Get killer info
        local killerId = 0
        local weaponHash = weapon
        
        if attacker and DoesEntityExist(attacker) and IsPedAPlayer(attacker) then
            local killerPlayerId = NetworkGetPlayerIndexFromPed(attacker)
            if killerPlayerId ~= -1 then
                killerId = GetPlayerServerId(killerPlayerId)
            end
        end
        
        -- Send kill log to server
        TriggerServerEvent('envy_kosmenu:logKill', killerId, weaponHash)
    end
end)

-- Spectate variables
local isSpectating = false
local spectatePlayerList = {}
local currentSpectateIndex = 1
local currentSpectatePlayerId = nil
local currentSpectatePlayerName = ''
local currentSpectateBucket = 0
local showESP = false
local lastSpectateCoord = nil
local spectateFOV = 50.0 -- Default FOV
local defaultFOV = 50.0 -- Default FOV value (for ±2 range)
local spectateCamera = nil -- Custom camera handle
local cameraDistance = 3.0 -- Distance from target player
local defaultDistance = 3.0 -- Default distance value (for ±2 range)
local cameraHeight = 0.5 -- Height offset from target player
local cameraRotationSpeed = 3.0 -- Camera rotation speed
local cameraYaw = 0.0 -- Horizontal rotation (around Y axis)
local cameraPitch = -10.0 -- Vertical rotation (pitch angle)

-- Function to refresh player metadata (death status)
local function RefreshPlayerMetadata()
    if not isSpectating or #spectatePlayerList == 0 then return end
    
    local playerIds = {}
    for _, player in ipairs(spectatePlayerList) do
        table.insert(playerIds, player.id)
    end
    
    QBCore.Functions.TriggerCallback('envy_kosmenu:getPlayerMetadata', function(metadataTable)
        if not metadataTable then return end
        for _, player in ipairs(spectatePlayerList) do
            if metadataTable[player.id] then
                player.isDead = metadataTable[player.id].isDead == true
                player.inLaststand = metadataTable[player.id].inLaststand == true
            else
                -- Default to false if player not found
                player.isDead = false
                player.inLaststand = false
            end
        end
    end, playerIds)
end

-- Start spectating
RegisterNetEvent('envy_kosmenu:client:StartSpectate', function(targetPlayerId, targetName, bucketId)
    local myPed = PlayerPedId()
    local targetplayer = GetPlayerFromServerId(targetPlayerId)
    
    if targetplayer == -1 then
        QBCore.Functions.Notify('Player not found', 'error')
        return
    end
    
    local target = GetPlayerPed(targetplayer)
    local targetCoords = GetEntityCoords(target)
    local targetHeading = GetEntityHeading(target)
    
    if not isSpectating then
        -- First time spectating - save position and setup
        isSpectating = true
        lastSpectateCoord = GetEntityCoords(myPed)
        SetEntityVisible(myPed, false, false)
        SetEntityCollision(myPed, false, false)
        SetEntityInvincible(myPed, true)
        NetworkSetEntityInvisibleToNetwork(myPed, true)
        
        -- Create custom camera that orbits around target player
        spectateCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        
        -- Initialize camera angles
        cameraYaw = targetHeading
        cameraPitch = -10.0
        cameraDistance = defaultDistance
        spectateFOV = defaultFOV
        
        -- Calculate initial camera position (orbiting around target)
        local horizontalDistance = cameraDistance * math.cos(math.rad(cameraPitch))
        local camX = targetCoords.x - (math.sin(math.rad(cameraYaw)) * horizontalDistance)
        local camY = targetCoords.y - (math.cos(math.rad(cameraYaw)) * horizontalDistance)
        local camZ = targetCoords.z + cameraHeight + (math.sin(math.rad(cameraPitch)) * cameraDistance)
        
        SetCamCoord(spectateCamera, camX, camY, camZ)
        PointCamAtCoord(spectateCamera, targetCoords.x, targetCoords.y, targetCoords.z + cameraHeight)
        SetCamFov(spectateCamera, spectateFOV)
        SetCamActive(spectateCamera, true)
        RenderScriptCams(true, false, 0, true, true)
    else
        -- Already spectating - switch target
        -- Reset camera angles to face new target
        cameraYaw = targetHeading
        cameraPitch = -10.0
        -- Reset FOV and distance to defaults when switching targets
        spectateFOV = defaultFOV
        cameraDistance = defaultDistance
    end
    
    -- Position spectator below target player (once per switch)
    local belowCoords = GetOffsetFromEntityInWorldCoords(target, 0.0, 0.0, -15.0)
    SetEntityCoords(myPed, belowCoords.x, belowCoords.y, belowCoords.z, false, false, false, true)
    FreezeEntityPosition(myPed, true)

    currentSpectatePlayerId = targetPlayerId
    currentSpectatePlayerName = targetName
    currentSpectateBucket = bucketId
    
    -- Get players in bucket for cycling
    QBCore.Functions.TriggerCallback('envy_kosmenu:getBucketPlayers', function(players)
        -- Preserve existing metadata for players that are still in the list
        local oldMetadata = {}
        for _, oldPlayer in ipairs(spectatePlayerList) do
            oldMetadata[oldPlayer.id] = {
                isDead = oldPlayer.isDead or false,
                inLaststand = oldPlayer.inLaststand or false
            }
        end
        
        spectatePlayerList = players
        
        -- Initialize metadata fields, preserving existing data if available
        for _, player in ipairs(spectatePlayerList) do
            if oldMetadata[player.id] then
                -- Preserve existing metadata
                player.isDead = oldMetadata[player.id].isDead
                player.inLaststand = oldMetadata[player.id].inLaststand
            else
                -- New player, initialize to false
                player.isDead = false
                player.inLaststand = false
            end
        end
        
        -- Find current player index
        currentSpectateIndex = 1
        for i, player in ipairs(spectatePlayerList) do
            if player.id == targetPlayerId then
                currentSpectateIndex = i
                break
            end
        end
        
        -- Show spectate overlay
        SendNUIMessage({
            action = 'showSpectate',
            playerName = currentSpectatePlayerName
        })
        
        -- Fetch initial metadata immediately after list is populated (no delay)
        RefreshPlayerMetadata()
    end)
end)

-- Stop spectating
RegisterNetEvent('envy_kosmenu:client:StopSpectate', function()
    if isSpectating then
        local myPed = PlayerPedId()
        
        -- Destroy custom camera
        if spectateCamera and DoesCamExist(spectateCamera) then
            RenderScriptCams(false, true, 500, true, true)
            SetCamActive(spectateCamera, false)
            DestroyCam(spectateCamera, true)
            spectateCamera = nil
        end
        
        NetworkSetEntityInvisibleToNetwork(myPed, false)
        SetEntityCollision(myPed, true, true)
        
        if lastSpectateCoord then
            SetEntityCoords(myPed, lastSpectateCoord.x, lastSpectateCoord.y, lastSpectateCoord.z, false, false, false, true)
        end
        
        SetEntityVisible(myPed, true, false)
        SetEntityInvincible(myPed, false)
        FreezeEntityPosition(myPed, false)
    end
    
    isSpectating = false
    showESP = false
    currentSpectatePlayerId = nil
    currentSpectatePlayerName = ''
    currentSpectateBucket = 0
    spectatePlayerList = {}
    currentSpectateIndex = 1
    lastSpectateCoord = nil
    spectateFOV = defaultFOV -- Reset FOV to default
    cameraDistance = defaultDistance -- Reset camera distance
    cameraYaw = 0.0 -- Reset camera angles
    cameraPitch = -10.0
    
    -- Hide spectate overlay
    SendNUIMessage({
        action = 'hideSpectate'
    })
end)

-- Spectate controls thread
CreateThread(function()
    while true do
        Wait(0)
        if isSpectating then
            -- Left arrow key - Previous player
            if IsDisabledControlJustPressed(0, 174) then -- LEFT ARROW
                if #spectatePlayerList > 0 then
                    currentSpectateIndex = currentSpectateIndex - 1
                    if currentSpectateIndex < 1 then
                        currentSpectateIndex = #spectatePlayerList
                    end
                    
                    local targetPlayer = spectatePlayerList[currentSpectateIndex]
                    if targetPlayer then
                        TriggerServerEvent('envy_kosmenu:startSpectate', targetPlayer.id)
                    end
                end
            end
            
            -- Right arrow key - Next player
            if IsDisabledControlJustPressed(0, 175) then -- RIGHT ARROW
                if #spectatePlayerList > 0 then
                    currentSpectateIndex = currentSpectateIndex + 1
                    if currentSpectateIndex > #spectatePlayerList then
                        currentSpectateIndex = 1
                    end
                    
                    local targetPlayer = spectatePlayerList[currentSpectateIndex]
                    if targetPlayer then
                        TriggerServerEvent('envy_kosmenu:startSpectate', targetPlayer.id)
                    end
                end
            end
            
            -- G key - Toggle ESP
            if IsDisabledControlJustPressed(0, 47) then -- G KEY
                showESP = not showESP
                if showESP then
                    -- Refresh metadata when ESP is turned on
                    RefreshPlayerMetadata()
                end
            end
            
            -- Backspace key - Stop spectating
            if IsDisabledControlJustPressed(0, 194) then -- BACKSPACE KEY
                TriggerServerEvent('envy_kosmenu:stopSpectate')
            end
            
            -- Mouse scroll for FOV and distance control (same bindings)
            -- Control 241 = Mouse wheel up, Control 242 = Mouse wheel down
            -- Both FOV and distance adjust simultaneously with ±2 max change from default
            if IsDisabledControlJustPressed(0, 241) then -- Mouse wheel up - increase both
                -- Increase FOV (max +2 from default)
                spectateFOV = math.min(spectateFOV + 0.5, defaultFOV + 2.0)
                if spectateCamera and DoesCamExist(spectateCamera) then
                    SetCamFov(spectateCamera, spectateFOV)
                end
                -- Increase distance (max +2 from default)
                cameraDistance = math.min(cameraDistance + 0.5, defaultDistance + 2.0)
            elseif IsDisabledControlJustPressed(0, 242) then -- Mouse wheel down - decrease both
                -- Decrease FOV (min -2 from default)
                spectateFOV = math.max(spectateFOV - 0.5, defaultFOV - 2.0)
                if spectateCamera and DoesCamExist(spectateCamera) then
                    SetCamFov(spectateCamera, spectateFOV)
                end
                -- Decrease distance (min -2 from default)
                cameraDistance = math.max(cameraDistance - 0.5, defaultDistance - 2.0)
            end
        else
            Wait(500)
        end
    end
end)

-- Custom Camera Control Thread (orbits around target player with mouse controls)
CreateThread(function()
    while true do
        if isSpectating and spectateCamera and DoesCamExist(spectateCamera) then
            Wait(0) -- Update every frame when spectating
            
            local targetplayer = GetPlayerFromServerId(currentSpectatePlayerId)
            if targetplayer ~= -1 then
                local targetPed = GetPlayerPed(targetplayer)
                if targetPed and targetPed ~= 0 then
                    local targetCoords = GetEntityCoords(targetPed)
                    local targetCenter = vector3(targetCoords.x, targetCoords.y, targetCoords.z + cameraHeight)
                    
                    -- Get mouse input for camera rotation (Controls 220 and 221 are right stick/mouse)
                    local rightAxisX = GetDisabledControlNormal(0, 220) -- Mouse X / Right stick X
                    local rightAxisY = GetDisabledControlNormal(0, 221) -- Mouse Y / Right stick Y
                    
                    -- Update camera angles based on mouse input
                    if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
                        -- Horizontal rotation (yaw) - rotate around target (inverted)
                        cameraYaw = cameraYaw + rightAxisX * 1.0 * cameraRotationSpeed
                        
                        -- Vertical rotation (pitch) - limit to prevent flipping (inverted)
                        cameraPitch = cameraPitch + rightAxisY * 1.0 * cameraRotationSpeed
                        cameraPitch = math.max(math.min(89.0, cameraPitch), -89.0) -- Clamp between -89 and 89 degrees
                    end
                    
                    -- Calculate camera position orbiting around target
                    -- Using spherical coordinates: distance, yaw (horizontal), pitch (vertical)
                    local horizontalDistance = cameraDistance * math.cos(math.rad(cameraPitch))
                    local camX = targetCenter.x - (math.sin(math.rad(cameraYaw)) * horizontalDistance)
                    local camY = targetCenter.y - (math.cos(math.rad(cameraYaw)) * horizontalDistance)
                    local camZ = targetCenter.z + (math.sin(math.rad(cameraPitch)) * cameraDistance)
                    
                    -- Update camera position and rotation
                    SetCamCoord(spectateCamera, camX, camY, camZ)
                    PointCamAtCoord(spectateCamera, targetCenter.x, targetCenter.y, targetCenter.z)
                    
                    -- Update FOV (applied continuously)
                    SetCamFov(spectateCamera, spectateFOV)
                    
                    -- Disable ALL controls while spectating
                    for i = 0, 350 do
                        DisableControlAction(0, i, true)
                    end
                    
                    -- Hide HUD elements for cleaner spectate view
                    HideHudAndRadarThisFrame()
                else
                    Wait(100) -- Target ped invalid, wait longer
                end
            else
                Wait(100) -- Target player invalid, wait longer
            end
        else
            Wait(500) -- Not spectating, wait longer to save performance
        end
    end
end)

-- ESP Drawing Thread
CreateThread(function()
    local lastMetadataRefresh = 0
    while true do
        Wait(0)
        if isSpectating and showESP then
            local currentTime = GetGameTimer()
            -- Refresh metadata every 500ms while ESP is active
            if currentTime - lastMetadataRefresh > 500 then
                RefreshPlayerMetadata()
                lastMetadataRefresh = currentTime
            end
            
            local myPed = PlayerPedId()
            local myServerId = GetPlayerServerId(PlayerId())
            
            -- Draw ESP for all players in bucket
            for _, playerData in ipairs(spectatePlayerList) do
                local targetPlayer = GetPlayerFromServerId(playerData.id)
                if targetPlayer ~= -1 then
                    local targetPed = GetPlayerPed(targetPlayer)
                    if targetPed and targetPed ~= 0 then
                        local coords = GetEntityCoords(targetPed)
                        local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z + 1.0)
                        
                        if onScreen then
                            local rawHealth = GetEntityHealth(targetPed)
                            local health = math.max(0, math.min(100, math.floor(((rawHealth - 100) / 100) * 100)))
                            local armor = GetPedArmour(targetPed)
                            
                            -- Check if player is dead or in laststand using QBCore metadata
                            local isDead = playerData.isDead == true
                            local inLaststand = playerData.inLaststand == true
                            local healthColor = (isDead or inLaststand) and '~r~' or '~g~' -- Red if dead or in laststand, green if alive
                            
                            -- Get weapon info
                            local weaponHash = GetSelectedPedWeapon(targetPed)
                            local weaponName = 'Unarmed'
                            local ammo = 0
                            
                            if weaponHash and weaponHash ~= GetHashKey('WEAPON_UNARMED') then
                                local weaponData = QBCore.Shared.Weapons[weaponHash]
                                if weaponData then
                                    weaponName = weaponData.label or weaponData.name or 'Unknown'
                                    -- Get ammo - GetAmmoInPedWeapon returns total ammo (clip + reserve)
                                    local ammoCount = GetAmmoInPedWeapon(targetPed, weaponHash)
                                    -- Handle -1 or invalid values
                                    if ammoCount and ammoCount >= 0 then
                                        ammo = ammoCount
                                    else
                                        -- Try getting ammo from clip as fallback
                                        local _, ammoInClip = GetAmmoInClip(targetPed, weaponHash)
                                        if ammoInClip and ammoInClip >= 0 then
                                            ammo = ammoInClip
                                        else
                                            ammo = 0
                                        end
                                    end
                                else
                                    weaponName = 'Unknown'
                                end
                            end
                            
                            -- Draw ESP info above player (compact format)
                            local espText = string.format('~b~%s~w~~n~HP: %s%d%%~w~ | Armor: ~b~%d%%~w~ ~n~%s | Ammo: ~y~%d~w~', 
                                playerData.name, 
                                healthColor,
                                health, 
                                math.floor(armor), 
                                weaponName, 
                                ammo
                            )
                            DrawText3D(coords.x, coords.y, coords.z + 1.0, espText)
                        end
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- Draw 3D Text function (prettier ESP without black background, compact spacing)
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local camCoords = GetGameplayCamCoord()
    
    local fov = (1 / GetGameplayCamFov()) * 100
    
    if onScreen then
        -- Increased scale (doubled from 0.32 to 0.64 for better visibility with custom camera)
        SetTextScale(0.0, 0.30 * fov)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(2, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 200)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        
        -- Process color codes and newlines
        AddTextComponentSubstringPlayerName(text)
        
        DrawText(_x, _y)
    end
end

-- ESC Key Handler
CreateThread(function()
    while true do
        Wait(0)
        if isMenuOpen then
            if IsControlJustPressed(0, 194) then -- ESC Key
                CloseKOSMenu()
            end
        elseif isSpectating then
            -- ESC to stop spectating (backup, but Backspace is primary)
            if IsDisabledControlJustPressed(0, 194) then -- ESC Key
                TriggerServerEvent('envy_kosmenu:stopSpectate')
            end
        else
            Wait(500)
        end
    end
end)

