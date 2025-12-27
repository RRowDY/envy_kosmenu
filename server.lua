local QBCore = exports['qb-core']:GetCoreObject()

-- Bucket storage (persists until restart)
local Buckets = {} -- Format: [bucketId] = { position = vector3(x, y, z), scoreboard = {...}, killLog = {...}, creatorName = "PlayerName" }
-- Scoreboard format: { team1Name = "Team 1", team2Name = "Team 2", team1Score = 0, team2Score = 0, visible = false }
-- Kill log format: { timestamp = os.time(), killerId = playerId, killerName = "Name", killedId = playerId, killedName = "Name", weapon = "WEAPON_NAME" }

-- Helper function to check if bucket exists
local function BucketExists(bucketId)
    return Buckets[bucketId] ~= nil
end

-- Discord Webhook function
local function SendDiscordWebhook(embed)
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' then
        return
    end
    
    local webhookData = {
        embeds = { embed }
    }
    
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode(webhookData), { ['Content-Type'] = 'application/json' })
end

-- Helper function to get player info for logging
local function GetPlayerInfo(playerId)
    local player = QBCore.Functions.GetPlayer(playerId)
    if not player then
        return {
            name = GetPlayerName(playerId) or "Unknown",
            serverId = playerId,
            charName = "Unknown"
        }
    end
    
    return {
        name = GetPlayerName(playerId) or "Unknown",
        serverId = playerId,
        charName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
    }
end

-- Helper function to get all players in a bucket
local function GetPlayersInBucket(bucketId)
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local playerIdNum = tonumber(playerId)
        if GetPlayerRoutingBucket(playerIdNum) == bucketId then
            players[#players + 1] = playerIdNum
        end
    end
    return players
end

-- Get current bucket of player
QBCore.Functions.CreateCallback('envy_kosmenu:getCurrentBucket', function(source, cb)
    local bucket = GetPlayerRoutingBucket(source)
    cb(bucket)
end)

-- Check if player has admin/god permissions
QBCore.Functions.CreateCallback('envy_kosmenu:hasPermission', function(source, cb)
    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god')
    cb(hasPermission)
end)

-- Get all available buckets
QBCore.Functions.CreateCallback('envy_kosmenu:getBuckets', function(source, cb)
    local bucketList = {}
    for bucketId, data in pairs(Buckets) do
        bucketList[#bucketList + 1] = {
            id = bucketId,
            position = data.position,
            creatorName = data.creatorName or "Unknown"
        }
    end
    cb(bucketList)
end)

-- Get all players for teleport selection
QBCore.Functions.CreateCallback('envy_kosmenu:getPlayers', function(source, cb)
    local players = {}
    local qbPlayers = QBCore.Functions.GetQBPlayers()
    
    for playerId, player in pairs(qbPlayers) do
        local playerPed = GetPlayerPed(playerId)
        local name = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
        players[#players + 1] = {
            id = playerId,
            name = name,
            serverId = playerId
        }
    end
    
    cb(players)
end)

-- Get players in same bucket for spectating (excluding spectator)
QBCore.Functions.CreateCallback('envy_kosmenu:getBucketPlayers', function(source, cb)
    local src = source
    local currentBucket = GetPlayerRoutingBucket(src)
    local players = {}
    local qbPlayers = QBCore.Functions.GetQBPlayers()
    
    for playerId, player in pairs(qbPlayers) do
        local playerIdNum = tonumber(playerId)
        -- Only include players in the same bucket, excluding the spectator
        if GetPlayerRoutingBucket(playerIdNum) == currentBucket and playerIdNum ~= src then
            local name = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
            players[#players + 1] = {
                id = playerIdNum,
                name = name,
                serverId = playerIdNum
            }
        end
    end
    
    cb(players)
end)

-- Get scoreboard data for current bucket
QBCore.Functions.CreateCallback('envy_kosmenu:getScoreboard', function(source, cb)
    local bucketId = GetPlayerRoutingBucket(source)
    if BucketExists(bucketId) and Buckets[bucketId].scoreboard then
        cb(Buckets[bucketId].scoreboard)
    else
        cb(nil)
    end
end)

-- Get player metadata (death status) for multiple players
QBCore.Functions.CreateCallback('envy_kosmenu:getPlayerMetadata', function(source, cb, playerIds)
    local metadataTable = {}
    
    if not playerIds or type(playerIds) ~= 'table' then
        cb(metadataTable)
        return
    end
    
    for _, playerId in ipairs(playerIds) do
        local player = QBCore.Functions.GetPlayer(playerId)
        if player then
            metadataTable[playerId] = {
                isDead = player.PlayerData.metadata['isdead'] == true,
                inLaststand = player.PlayerData.metadata['inlaststand'] == true
            }
        else
            -- Default to false if player not found
            metadataTable[playerId] = {
                isDead = false,
                inLaststand = false
            }
        end
    end
    
    cb(metadataTable)
end)

-- Get kill log for current bucket
QBCore.Functions.CreateCallback('envy_kosmenu:getKillLog', function(source, cb, page)
    local bucketId = GetPlayerRoutingBucket(source)
    if not BucketExists(bucketId) or not Buckets[bucketId].killLog then
        cb({ logs = {}, totalPages = 0, currentPage = 1 })
        return
    end
    
    local killLog = Buckets[bucketId].killLog
    local totalLogs = #killLog
    local logsPerPage = 20
    local totalPages = math.ceil(totalLogs / logsPerPage)
    page = tonumber(page) or 1
    
    if page < 1 then page = 1 end
    if page > totalPages and totalPages > 0 then page = totalPages end
    
    -- Get logs for current page (most recent first)
    local startIndex = math.max(1, totalLogs - (page * logsPerPage) + 1)
    local endIndex = math.max(1, totalLogs - ((page - 1) * logsPerPage))
    
    local pageLogs = {}
    for i = endIndex, startIndex, -1 do
        if killLog[i] then
            table.insert(pageLogs, killLog[i])
        end
    end
    
    cb({
        logs = pageLogs,
        totalPages = totalPages,
        currentPage = page,
        totalLogs = totalLogs
    })
end)

-- Create a new bucket
RegisterNetEvent('envy_kosmenu:createBucket', function(bucketId)
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to create buckets', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'createBucket', 'You do not have permission to create buckets')
        return
    end
    
    -- Validate bucket ID
    bucketId = tonumber(bucketId)
    if not bucketId or bucketId < 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid bucket ID', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'createBucket', 'Invalid bucket ID')
        return
    end
    
    -- Cannot create bucket 0
    if bucketId == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Cannot create bucket 0 (main dimension)', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'createBucket', 'Cannot create bucket 0 (main dimension)')
        return
    end
    
    -- Check if bucket already exists
    if BucketExists(bucketId) then
        TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. bucketId .. ' already exists', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'createBucket', 'Bucket ' .. bucketId .. ' already exists')
        return
    end
    
    -- Get player position
    local playerPed = GetPlayerPed(src)
    local coords = GetEntityCoords(playerPed)
    local position = vector3(coords.x, coords.y, coords.z)
    
    -- Get creator name
    local creatorName = GetPlayerName(src)
    
    -- Create bucket and save position
    Buckets[bucketId] = {
        position = position,
        scoreboard = {
            team1Name = "Team 1",
            team2Name = "Team 2",
            team1Score = 0,
            team2Score = 0,
            visible = false
        },
        killLog = {}, -- Initialize empty kill log
        creatorName = creatorName
    }
    
    -- Set player to new bucket
    SetPlayerRoutingBucket(src, bucketId)
    
    -- Teleport player to same position in new bucket
    SetEntityCoords(playerPed, coords.x, coords.y, coords.z, false, false, false, true)
    
    -- Load scoreboard for the new bucket
    TriggerClientEvent('envy_kosmenu:client:LoadScoreboard', src)
    
    TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. bucketId .. ' created successfully', 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'createBucket', 'Bucket ' .. bucketId .. ' created successfully')
    TriggerClientEvent('envy_kosmenu:refreshMenu', src)
    
    -- Discord Logging
    local playerInfo = GetPlayerInfo(src)
    local embed = {
        title = "🪣 Bucket Created",
        description = "A new bucket has been created",
        color = 3447003, -- Blue
        fields = {
            {
                name = "👤 Created By",
                value = playerInfo.charName .. " (" .. playerInfo.name .. " [" .. playerInfo.serverId .. "])",
                inline = true
            },
            {
                name = "🆔 Bucket ID",
                value = tostring(bucketId),
                inline = true
            },
            {
                name = "📍 Location",
                value = string.format("%.2f %.2f %.2f", position.x, position.y, position.z),
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    SendDiscordWebhook(embed)
end)

-- Delete a bucket
RegisterNetEvent('envy_kosmenu:deleteBucket', function(bucketId)
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to delete buckets', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'deleteBucket', 'You do not have permission to delete buckets')
        return
    end
    
    -- Validate bucket ID
    bucketId = tonumber(bucketId)
    if not bucketId or bucketId < 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid bucket ID', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'deleteBucket', 'Invalid bucket ID')
        return
    end
    
    -- Cannot delete bucket 0
    if bucketId == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Cannot delete bucket 0 (main dimension)', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'deleteBucket', 'Cannot delete bucket 0 (main dimension)')
        return
    end
    
    -- Check if bucket exists
    if not BucketExists(bucketId) then
        TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. bucketId .. ' does not exist', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'deleteBucket', 'Bucket ' .. bucketId .. ' does not exist')
        return
    end
    
    -- Get all players in the bucket
    local playersInBucket = GetPlayersInBucket(bucketId)
    
    -- Teleport all players to default location and set to bucket 0
    for _, playerId in ipairs(playersInBucket) do
        SetPlayerRoutingBucket(playerId, 0)
        -- Trigger client event to teleport player to default location
        TriggerClientEvent('envy_kosmenu:client:TeleportToDefault', playerId, Config.DefaultLocation)
        TriggerClientEvent('envy_kosmenu:client:ClearScoreboard', playerId)
        TriggerClientEvent('QBCore:Notify', playerId, 'You have been moved to the main dimension', 'info')
    end
    
    -- Delete bucket
    Buckets[bucketId] = nil
    
    TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. bucketId .. ' deleted successfully', 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'deleteBucket', 'Bucket ' .. bucketId .. ' deleted successfully')
    TriggerClientEvent('envy_kosmenu:refreshMenu', src)
    
    -- Discord Logging
    local playerInfo = GetPlayerInfo(src)
    local playersAffected = #playersInBucket
    local embed = {
        title = "🗑️ Bucket Deleted",
        description = "A bucket has been deleted",
        color = 15158332, -- Red
        fields = {
            {
                name = "👤 Deleted By",
                value = playerInfo.charName .. " (" .. playerInfo.name .. " [" .. playerInfo.serverId .. "])",
                inline = true
            },
            {
                name = "🆔 Bucket ID",
                value = tostring(bucketId),
                inline = true
            },
            {
                name = "👥 Players Affected",
                value = tostring(playersAffected) .. " player(s) moved to main dimension",
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    SendDiscordWebhook(embed)
end)

-- Teleport player to bucket
RegisterNetEvent('envy_kosmenu:teleportToBucket', function(targetPlayerId, bucketId)
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to teleport players', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'teleportToBucket', 'You do not have permission to teleport players')
        return
    end
    
    -- Validate inputs
    targetPlayerId = tonumber(targetPlayerId)
    bucketId = tonumber(bucketId)
    
    if not targetPlayerId or not bucketId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid parameters', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'teleportToBucket', 'Invalid parameters')
        return
    end
    
    -- Check if target player exists
    local targetPlayer = QBCore.Functions.GetPlayer(targetPlayerId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'teleportToBucket', 'Player not found')
        return
    end
    
    -- Check if bucket exists (or is 0)
    if bucketId ~= 0 and not BucketExists(bucketId) then
        TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. bucketId .. ' does not exist', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'teleportToBucket', 'Bucket ' .. bucketId .. ' does not exist')
        return
    end
    
    -- Get bucket position
    local targetPosition
    if bucketId == 0 then
        -- For bucket 0, use default location or player's current position
        local playerPed = GetPlayerPed(targetPlayerId)
        local coords = GetEntityCoords(playerPed)
        targetPosition = vector3(coords.x, coords.y, coords.z)
    else
        targetPosition = Buckets[bucketId].position
    end
    
    -- Set player routing bucket
    SetPlayerRoutingBucket(targetPlayerId, bucketId)
    
    -- Teleport player
    local playerPed = GetPlayerPed(targetPlayerId)
    SetEntityCoords(playerPed, targetPosition.x, targetPosition.y, targetPosition.z, false, false, false, true)
    
    -- Load scoreboard for the new bucket
    if bucketId == 0 then
        TriggerClientEvent('envy_kosmenu:client:ClearScoreboard', targetPlayerId)
    else
        TriggerClientEvent('envy_kosmenu:client:LoadScoreboard', targetPlayerId)
    end
    
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    TriggerClientEvent('QBCore:Notify', src, 'Teleported ' .. targetName .. ' to bucket ' .. bucketId, 'success')
    TriggerClientEvent('QBCore:Notify', targetPlayerId, 'You have been teleported to bucket ' .. bucketId, 'info')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'teleportToBucket', 'Teleported ' .. targetName .. ' to bucket ' .. bucketId)
    
    -- Discord Logging
    local adminInfo = GetPlayerInfo(src)
    local targetInfo = GetPlayerInfo(targetPlayerId)
    local bucketName = bucketId == 0 and "Main Dimension (0)" or ("Bucket " .. bucketId)
    local embed = {
        title = "🚀 Player Teleported to Bucket",
        description = "A player has been teleported to a different bucket",
        color = 15844367, -- Gold
        fields = {
            {
                name = "👤 Admin",
                value = adminInfo.charName .. " (" .. adminInfo.name .. " [" .. adminInfo.serverId .. "])",
                inline = true
            },
            {
                name = "👥 Teleported Player",
                value = targetInfo.charName .. " (" .. targetInfo.name .. " [" .. targetInfo.serverId .. "])",
                inline = true
            },
            {
                name = "🪣 Destination",
                value = bucketName,
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    SendDiscordWebhook(embed)
end)

-- Leave current bucket (for non-admin users)
RegisterNetEvent('envy_kosmenu:leaveBucket', function()
    local src = source
    local currentBucket = GetPlayerRoutingBucket(src)
    
    -- Can only leave if not in bucket 0
    if currentBucket == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You are already in the main dimension', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'leaveBucket', 'You are already in the main dimension')
        return
    end
    
    -- Set to bucket 0
    SetPlayerRoutingBucket(src, 0)
    
    -- Teleport player to default location
    TriggerClientEvent('envy_kosmenu:client:TeleportToDefault', src, Config.DefaultLocation)
    
    -- Clear scoreboard when leaving bucket
    TriggerClientEvent('envy_kosmenu:client:ClearScoreboard', src)
    
    TriggerClientEvent('QBCore:Notify', src, 'You have left the bucket and returned to the main dimension', 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'leaveBucket', 'You have left the bucket and returned to the main dimension')
    TriggerClientEvent('envy_kosmenu:refreshMenu', src)
end)

-- Move bucket to current player's position
RegisterNetEvent('envy_kosmenu:moveBucket', function()
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to move buckets', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'moveBucket', 'You do not have permission to move buckets')
        return
    end
    
    local currentBucket = GetPlayerRoutingBucket(src)
    
    -- Must be in a bucket other than 0
    if currentBucket == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You must be in a bucket to use this feature', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'moveBucket', 'You must be in a bucket to use this feature')
        return
    end
    
    -- Check if bucket exists
    if not BucketExists(currentBucket) then
        TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. currentBucket .. ' does not exist', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'moveBucket', 'Bucket ' .. currentBucket .. ' does not exist')
        return
    end
    
    -- Get player's current position
    local playerPed = GetPlayerPed(src)
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local newPosition = vector3(coords.x, coords.y, coords.z)
    
    -- Update bucket position
    Buckets[currentBucket].position = newPosition
    
    -- Get all players in the bucket (excluding the one who triggered it)
    local playersInBucket = GetPlayersInBucket(currentBucket)
    
    -- Teleport all other players in the bucket to the new position
    for _, playerId in ipairs(playersInBucket) do
        if playerId ~= src then
            local targetPed = GetPlayerPed(playerId)
            SetEntityCoords(targetPed, newPosition.x, newPosition.y, newPosition.z, false, false, false, true)
            TriggerClientEvent('QBCore:Notify', playerId, 'Bucket location has been moved', 'info')
        end
    end
    
    -- Load scoreboard for all players in the bucket
    for _, playerId in ipairs(playersInBucket) do
        TriggerClientEvent('envy_kosmenu:client:LoadScoreboard', playerId)
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. currentBucket .. ' location updated to your current position', 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'moveBucket', 'Bucket location updated successfully')
    
    -- Discord Logging
    local playerInfo = GetPlayerInfo(src)
    local playersTeleported = #playersInBucket - 1 -- Exclude the one who triggered it
    local embed = {
        title = "📍 Bucket Moved",
        description = "A bucket location has been updated",
        color = 3066993, -- Green
        fields = {
            {
                name = "👤 Moved By",
                value = playerInfo.charName .. " (" .. playerInfo.name .. " [" .. playerInfo.serverId .. "])",
                inline = true
            },
            {
                name = "🆔 Bucket ID",
                value = tostring(currentBucket),
                inline = true
            },
            {
                name = "📍 New Location",
                value = string.format("%.2f %.2f %.2f", newPosition.x, newPosition.y, newPosition.z),
                inline = false
            },
            {
                name = "👥 Players Teleported",
                value = tostring(playersTeleported) .. " player(s)",
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    SendDiscordWebhook(embed)
end)

-- Give ammo to all players in bucket
RegisterNetEvent('envy_kosmenu:giveAmmo', function()
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to give ammo', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'giveAmmo')
        return
    end
    
    local currentBucket = GetPlayerRoutingBucket(src)
    
    -- Must be in a bucket other than 0
    if currentBucket == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You must be in a bucket to use this feature', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'giveAmmo')
        return
    end
    
    -- Get all players in the bucket
    local playersInBucket = GetPlayersInBucket(currentBucket)
    
    -- Give ammo to all players (client-side using SetPedAmmo)
    for _, playerId in ipairs(playersInBucket) do
        TriggerClientEvent('envy_kosmenu:client:GiveAmmo', playerId)
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Ammo given to all players in bucket ' .. currentBucket, 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'giveAmmo', 'Ammo given to all players in bucket')
    
    -- Discord Logging
    local playerInfo = GetPlayerInfo(src)
    local embed = {
        title = "🔫 Ammo Given",
        description = "Ammo has been given to all players in a bucket",
        color = 15105570, -- Orange
        fields = {
            {
                name = "👤 Admin",
                value = playerInfo.charName .. " (" .. playerInfo.name .. " [" .. playerInfo.serverId .. "])",
                inline = true
            },
            {
                name = "🪣 Bucket ID",
                value = tostring(currentBucket),
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    SendDiscordWebhook(embed)
end)

-- Repair weapons for all players in bucket
RegisterNetEvent('envy_kosmenu:repairWeapons', function()
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to repair weapons', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'repairWeapons')
        return
    end
    
    local currentBucket = GetPlayerRoutingBucket(src)
    
    -- Must be in a bucket other than 0
    if currentBucket == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You must be in a bucket to use this feature', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'repairWeapons')
        return
    end
    
    -- Get all players in the bucket
    local playersInBucket = GetPlayersInBucket(currentBucket)
    
    -- Repair weapons for all players
    for _, playerId in ipairs(playersInBucket) do
        TriggerClientEvent('qb-weapons:client:SetWeaponQuality', playerId, 100)
        TriggerClientEvent('QBCore:Notify', playerId, 'All your weapons have been repaired to 100%', 'success')
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Weapons repaired for all players in bucket ' .. currentBucket, 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'repairWeapons', 'Weapons repaired for all players in bucket')
    
    -- Discord Logging
    local playerInfo = GetPlayerInfo(src)
    local embed = {
        title = "🔧 Weapons Repaired",
        description = "All weapons have been repaired in a bucket",
        color = 15105570, -- Orange
        fields = {
            {
                name = "👤 Admin",
                value = playerInfo.charName .. " (" .. playerInfo.name .. " [" .. playerInfo.serverId .. "])",
                inline = true
            },
            {
                name = "🪣 Bucket ID",
                value = tostring(currentBucket),
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    SendDiscordWebhook(embed)
end)

-- Revive all players in bucket
RegisterNetEvent('envy_kosmenu:revivePlayers', function()
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to revive players', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'revivePlayers')
        return
    end
    
    local currentBucket = GetPlayerRoutingBucket(src)
    
    -- Must be in a bucket other than 0
    if currentBucket == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You must be in a bucket to use this feature', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'revivePlayers')
        return
    end
    
    -- Get all players in the bucket
    local playersInBucket = GetPlayersInBucket(currentBucket)
    
    -- Revive all players
    for _, playerId in ipairs(playersInBucket) do
        TriggerClientEvent('hospital:client:Revive', playerId)
        -- Set armor to 100 (client-side)
        TriggerClientEvent('envy_kosmenu:client:SetArmor', playerId, 100)
        TriggerClientEvent('QBCore:Notify', playerId, 'You have been revived with full health and armor', 'success')
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'All players in bucket ' .. currentBucket .. ' have been revived', 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'revivePlayers', 'All players in bucket have been revived')
    
    -- Discord Logging
    local playerInfo = GetPlayerInfo(src)
    local embed = {
        title = "💚 Players Revived",
        description = "All players have been revived in a bucket",
        color = 3066993, -- Green
        fields = {
            {
                name = "👤 Admin",
                value = playerInfo.charName .. " (" .. playerInfo.name .. " [" .. playerInfo.serverId .. "])",
                inline = true
            },
            {
                name = "🪣 Bucket ID",
                value = tostring(currentBucket),
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    SendDiscordWebhook(embed)
end)

-- Start spectating a player
RegisterNetEvent('envy_kosmenu:startSpectate', function(targetPlayerId)
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to spectate players', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'spectatePlayer', 'You do not have permission to spectate players')
        return
    end
    
    -- Validate target player
    targetPlayerId = tonumber(targetPlayerId)
    if not targetPlayerId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'spectatePlayer', 'Invalid player ID')
        return
    end
    
    -- Check if target player exists
    local targetPlayer = QBCore.Functions.GetPlayer(targetPlayerId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'spectatePlayer', 'Player not found')
        return
    end
    
    -- Check if both players are in the same bucket
    local srcBucket = GetPlayerRoutingBucket(src)
    local targetBucket = GetPlayerRoutingBucket(targetPlayerId)
    
    if srcBucket ~= targetBucket then
        TriggerClientEvent('QBCore:Notify', src, 'Player is not in the same bucket', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'spectatePlayer', 'Player is not in the same bucket')
        return
    end
    
    -- Get target player name
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    
    -- Trigger spectate on client (custom implementation)
    TriggerClientEvent('envy_kosmenu:client:StartSpectate', src, targetPlayerId, targetName, srcBucket)
    TriggerClientEvent('QBCore:Notify', src, 'Spectating ' .. targetName, 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'spectatePlayer', 'Spectating ' .. targetName)
end)

-- Stop spectating
RegisterNetEvent('envy_kosmenu:stopSpectate', function()
    local src = source
    TriggerClientEvent('envy_kosmenu:client:StopSpectate', src)
end)

-- Update scoreboard
RegisterNetEvent('envy_kosmenu:updateScoreboard', function(scoreboardData)
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to edit scoreboard', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'updateScoreboard', 'You do not have permission to edit scoreboard')
        return
    end
    
    local currentBucket = GetPlayerRoutingBucket(src)
    
    -- Must be in a bucket (not 0)
    if currentBucket == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You must be in a bucket to edit scoreboard', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'updateScoreboard', 'You must be in a bucket to edit scoreboard')
        return
    end
    
    -- Check if bucket exists
    if not BucketExists(currentBucket) then
        TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. currentBucket .. ' does not exist', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'updateScoreboard', 'Bucket ' .. currentBucket .. ' does not exist')
        return
    end
    
    -- Store old scoreboard data before updating
    local oldScoreboard = {}
    if Buckets[currentBucket].scoreboard then
        oldScoreboard.team1Name = Buckets[currentBucket].scoreboard.team1Name
        oldScoreboard.team2Name = Buckets[currentBucket].scoreboard.team2Name
        oldScoreboard.visible = Buckets[currentBucket].scoreboard.visible
    end
    
    -- Update scoreboard data
    if Buckets[currentBucket].scoreboard then
        if scoreboardData.team1Name then
            Buckets[currentBucket].scoreboard.team1Name = scoreboardData.team1Name
        end
        if scoreboardData.team2Name then
            Buckets[currentBucket].scoreboard.team2Name = scoreboardData.team2Name
        end
        if scoreboardData.visible ~= nil then
            Buckets[currentBucket].scoreboard.visible = scoreboardData.visible
        end
    end
    
    -- Broadcast scoreboard update to all players in bucket
    local playersInBucket = GetPlayersInBucket(currentBucket)
    for _, playerId in ipairs(playersInBucket) do
        TriggerClientEvent('envy_kosmenu:client:UpdateScoreboard', playerId, Buckets[currentBucket].scoreboard)
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Scoreboard updated successfully', 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'updateScoreboard', 'Scoreboard updated successfully')
    TriggerClientEvent('envy_kosmenu:refreshMenu', src)
    
    -- Discord Logging
    local playerInfo = GetPlayerInfo(src)
    local fields = {}
    
    -- Check for visibility change (only log if it actually changed)
    if scoreboardData.visible ~= nil and scoreboardData.visible ~= oldScoreboard.visible then
        local visibilityText = scoreboardData.visible and "Enabled" or "Disabled"
        table.insert(fields, {
            name = "👁️ Visibility",
            value = visibilityText,
            inline = true
        })
    end
    
    -- Check for team name changes
    if scoreboardData.team1Name and scoreboardData.team1Name ~= oldScoreboard.team1Name then
        table.insert(fields, {
            name = "🏷️ Team 1 Name",
            value = "**" .. oldScoreboard.team1Name .. "** → **" .. scoreboardData.team1Name .. "**",
            inline = false
        })
    end
    
    if scoreboardData.team2Name and scoreboardData.team2Name ~= oldScoreboard.team2Name then
        table.insert(fields, {
            name = "🏷️ Team 2 Name",
            value = "**" .. oldScoreboard.team2Name .. "** → **" .. scoreboardData.team2Name .. "**",
            inline = false
        })
    end
    
    -- Only send webhook if something actually changed
    if #fields > 0 then
        -- Add admin and bucket info at the beginning
        table.insert(fields, 1, {
            name = "👤 Admin",
            value = playerInfo.charName .. " (" .. playerInfo.name .. " (" .. playerInfo.serverId .. "))",
            inline = true
        })
        table.insert(fields, 2, {
            name = "🪣 Bucket ID",
            value = tostring(currentBucket),
            inline = true
        })
        
        local embed = {
            title = "📊 Scoreboard Edited",
            description = "Scoreboard settings have been updated",
            color = 10181046, -- Purple
            fields = fields,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        SendDiscordWebhook(embed)
    end
end)

-- Adjust score
RegisterNetEvent('envy_kosmenu:adjustScore', function(team, score)
    local src = source
    
    -- Permission check
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to adjust scores', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'adjustScore', 'You do not have permission to adjust scores')
        return
    end
    
    local currentBucket = GetPlayerRoutingBucket(src)
    
    -- Must be in a bucket (not 0)
    if currentBucket == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You must be in a bucket to adjust scores', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'adjustScore', 'You must be in a bucket to adjust scores')
        return
    end
    
    -- Check if bucket exists
    if not BucketExists(currentBucket) then
        TriggerClientEvent('QBCore:Notify', src, 'Bucket ' .. currentBucket .. ' does not exist', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'adjustScore', 'Bucket ' .. currentBucket .. ' does not exist')
        return
    end
    
    -- Validate team and score
    team = tonumber(team)
    score = tonumber(score)
    
    if not team or (team ~= 1 and team ~= 2) then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid team number', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'adjustScore', 'Invalid team number')
        return
    end
    
    if not score or score < 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid score', 'error')
        TriggerClientEvent('envy_kosmenu:client:ActionResult', src, false, 'adjustScore', 'Invalid score')
        return
    end
    
    -- Update score
    local oldScore
    local teamName
    if team == 1 then
        oldScore = Buckets[currentBucket].scoreboard.team1Score
        Buckets[currentBucket].scoreboard.team1Score = score
        teamName = Buckets[currentBucket].scoreboard.team1Name
    else
        oldScore = Buckets[currentBucket].scoreboard.team2Score
        Buckets[currentBucket].scoreboard.team2Score = score
        teamName = Buckets[currentBucket].scoreboard.team2Name
    end
    
    -- Broadcast score update to all players in bucket with notification
    local playersInBucket = GetPlayersInBucket(currentBucket)
    for _, playerId in ipairs(playersInBucket) do
        TriggerClientEvent('envy_kosmenu:client:UpdateScoreboard', playerId, Buckets[currentBucket].scoreboard)
        -- Show score change notification
        TriggerClientEvent('envy_kosmenu:client:ScoreChange', playerId, teamName, oldScore, score)
    end
    
    TriggerClientEvent('QBCore:Notify', src, teamName .. ' score set to ' .. score, 'success')
    TriggerClientEvent('envy_kosmenu:client:ActionResult', src, true, 'adjustScore', teamName .. ' score set to ' .. score)
    
    -- Discord Logging
    local playerInfo = GetPlayerInfo(src)
    local embed = {
        title = "📈 Score Adjusted",
        description = "A team's score has been adjusted",
        color = 10181046, -- Purple
        fields = {
            {
                name = "👤 Admin",
                value = playerInfo.charName .. " (" .. playerInfo.name .. " [" .. playerInfo.serverId .. "])",
                inline = true
            },
            {
                name = "🪣 Bucket ID",
                value = tostring(currentBucket),
                inline = true
            },
            {
                name = "🏆 Team",
                value = teamName,
                inline = true
            },
            {
                name = "📊 Score Change",
                value = "**" .. tostring(oldScore) .. "** → **" .. tostring(score) .. "**",
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    SendDiscordWebhook(embed)
end)

-- Track player kill (called from client when death detected)
RegisterNetEvent('envy_kosmenu:logKill', function(killerId, weaponHash)
    local src = source
    local bucketId = GetPlayerRoutingBucket(src)
    
    -- Only track if in a bucket (not 0)
    if bucketId == 0 or not BucketExists(bucketId) then
        return
    end
    
    -- Get killed player info
    local killedPlayer = QBCore.Functions.GetPlayer(src)
    if not killedPlayer then return end
    
    local killedName = killedPlayer.PlayerData.charinfo.firstname .. ' ' .. killedPlayer.PlayerData.charinfo.lastname
    
    -- Get killer info
    local killerName = nil
    local weapon = nil
    
    if killerId and killerId > 0 then
        local killerPlayer = QBCore.Functions.GetPlayer(killerId)
        if killerPlayer then
            killerName = killerPlayer.PlayerData.charinfo.firstname .. ' ' .. killerPlayer.PlayerData.charinfo.lastname
            
            -- Get weapon used
            if weaponHash then
                weapon = QBCore.Shared.Weapons[weaponHash] and QBCore.Shared.Weapons[weaponHash].label or "Unknown Weapon"
            else
                weapon = "Unknown Weapon"
            end
        end
    else
        killerName = "Suicide/Environment"
        weapon = "Unknown"
    end
    
    -- Add to kill log
    if not Buckets[bucketId].killLog then
        Buckets[bucketId].killLog = {}
    end
    
    table.insert(Buckets[bucketId].killLog, {
        timestamp = os.time(),
        killerId = killerId,
        killerName = killerName or "Unknown",
        killedId = src,
        killedName = killedName,
        weapon = weapon or "Unknown Weapon"
    })
    
    -- Keep only last 100 entries per bucket (to prevent memory issues)
    if #Buckets[bucketId].killLog > 100 then
        table.remove(Buckets[bucketId].killLog, 1)
    end
end)

