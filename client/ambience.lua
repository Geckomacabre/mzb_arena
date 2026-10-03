-- mzb_arena - client: the arena's own sound (html/ambience.js) and quieter footsteps.
-- The building is never silent: a low room tone (the air handling) in every room of it, the crowd's chatter while the
-- crowd is in (Config.Crowd / GlobalState.mzbCrowd) and its roar in the loud moods - from the bowl as you hear it in
-- the bowl, from the concourse and the rooms off it through the walls (Config.Listener's zones). The page makes the
-- sound itself (no files); this side tells it four times a second where you are and what the crowd is doing.
-- While you are in the building your footsteps are the game's quiet ones (they rang round the bowl).
-- /arenaambience <0-100> sets your own level of it (kept on your PC); 0 = none.

local AM = Config.Ambience or {}
if AM.enabled == false then return end

local KVP = 'mzb_arena_ambience_mine'               -- your own level, stored + 1 (0 means never set)

local function mine()
    local v = GetResourceKvpInt(KVP)
    if v == 0 then return 100 end
    return math.max(0, math.min(100, v - 1))
end

local function config()
    return { volume = AM.volume or 0.5, zones = AM.zones or {}, moods = AM.moods or {} }
end

local function setMine(v)
    SetResourceKvpInt(KVP, math.floor(math.max(0, math.min(100, v))) + 1)
    SendNUIMessage({ type = 'ambience', mine = mine() })
end

CreateThread(function()
    local quiet, last, lastAt, ready = false, nil, 0, false
    while true do
        local zone = MzbListener and MzbListener.zone or 'outside'
        local crowd = GlobalState.mzbCrowd or Config.CrowdDefault or {}
        local key = ('%s|%s|%s'):format(zone, tostring(crowd.on == true), tostring(crowd.mood))
        if key ~= last or GetGameTimer() - lastAt > 5000 then
            SendNUIMessage({ type = 'ambience', zone = zone, crowd = crowd.on == true, mood = crowd.mood or 'show',
                             mine = mine(), config = not ready and config() or nil })
            last, lastAt, ready = key, GetGameTimer(), true
        end
        -- the game's quiet footsteps while in the building, its own again outside
        if AM.quietFootsteps ~= false then
            local want = zone ~= 'outside'
            if want or quiet then
                SetPedAudioFootstepQuiet(PlayerPedId(), want)
                quiet = want
            end
        end
        Wait(250)
    end
end)

-- the page (re)loaded: it needs the config again
RegisterNUICallback('ambienceReady', function(_, cb)
    cb('ok')
    SendNUIMessage({ type = 'ambience', mine = mine(), config = config() })
end)

RegisterNUICallback('ambienceMine', function(data, cb)
    cb('ok')
    local v = type(data) == 'table' and tonumber(data.value)
    if v and v == v then setMine(v) end
end)

AddEventHandler('mzb_arena:lightsDesk', function()
    SendNUIMessage({ type = 'ambience', mine = mine() })
end)

RegisterCommand(AM.command or 'arenaambience', function(_, args)
    local v = tonumber(args[1])
    if v and v == v then setMine(v) end
    TriggerEvent('chat:addMessage', { args = { 'arena', ('the arena\'s sound for you: %d%% (/%s 0-100)'):format(mine(),
        AM.command or 'arenaambience') } })
end, false)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (AM.command or 'arenaambience'),
        'Maze Bank Arena: your level of the room tone and the crowd\'s chatter', { { name = 'level', help = '0-100' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetPedAudioFootstepQuiet(PlayerPedId(), false)
    TriggerEvent('chat:removeSuggestion', '/' .. (AM.command or 'arenaambience'))
end)
