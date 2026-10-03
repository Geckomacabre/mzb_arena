-- mzb_arena - client: the music player (GlobalState.mzbMusic, server/music.lua).
-- The sound plays in this resource's NUI page (html/music.js; the page is always loaded, the desk is only its visible
-- part). This side tells it what to play and where in it to be (on the server's clock: client/listener.lua), and ten
-- times a second where the listener is: the zone (bowl / near / building / outside), the camera (where it is, which
-- way it looks) and the PA hangs of the show (Config.Music.hangs), all from the arena's middle. In the bowl the page
-- plays the track from each hang as a sound in 3D (Web Audio panners: nearer is louder, left is left, behind is
-- behind); elsewhere through the walls (level, filter, echo). A track that can't go through Web Audio (YouTube, a
-- server without CORS) gets the level only. Far from the arena the page is told to unload the track; back near, it
-- loads it mid-track.

local MU = Config.Music or {}
local S = GlobalState.mzbMusic or { kind = 'off' }
local KVP = 'mzb_arena_music_mine'                 -- your own level, stored + 1 (0 means never set)

local function mine()
    local v = GetResourceKvpInt(KVP)
    if v == 0 then return 100 end
    return math.max(0, math.min(100, v - 1))
end

local loaded = nil                                  -- the rev the page has

local function config()
    return { volume = MU.volume or 0.8, refDistance = MU.refDistance or 12.0, minGain = MU.minGain or 0.3,
             rolloff = MU.rolloff or 0.7, panning = MU.panning or 'HRTF', rooms = MU.rooms or {},
             reverbSeconds = MU.reverbSeconds or 3.2 }
end

local function sendLoad()
    SendNUIMessage({ type = 'music', action = 'load', music = S, pos = MzbTrackPos(S), mine = mine(), config = config() })
    loaded = S.rev
end

local function sendUnload()
    SendNUIMessage({ type = 'music', action = 'unload' })
    loaded = nil
end

local function wanted()
    return MU.enabled and S.kind ~= 'off'
        and #(GetEntityCoords(PlayerPedId()) - Config.Screens.origin) < (MU.range or 200.0)
end

local needSync = false
AddStateBagChangeHandler('mzbMusic', 'global', function(_, _, value)
    local before = S
    S = value or { kind = 'off' }
    if loaded and S.rev == (before and before.rev) then needSync = true end   -- pause / resume / volume
    SendNUIMessage({ type = 'musicDesk', music = S })                          -- the desk's Music section
end)

-- load / unload / resync (twice a second)
CreateThread(function()
    local lastSync = 0
    while true do
        if wanted() then
            if loaded ~= S.rev then
                sendLoad()
                lastSync = GetGameTimer()
            elseif needSync or (not S.paused and GetGameTimer() - lastSync > (MU.resync or 30) * 1000) then
                needSync = false
                SendNUIMessage({ type = 'music', action = 'sync', music = S, pos = MzbTrackPos(S) })
                lastSync = GetGameTimer()
            end
        elseif loaded then
            sendUnload()
        end
        Wait(500)
    end
end)

-- where the listener is, ten times a second while a track is loaded
CreateThread(function()
    while true do
        if loaded then
            local show = GlobalState.mzbShow or Config.DefaultShow
            local hangs = (MU.hangs or {})[show] or {}
            local zone = MzbListener.zone
            local p = GetFinalRenderedCamCoord()
            local rot = GetFinalRenderedCamRot(2)
            local h, pt = math.rad(rot.z), math.rad(rot.x)
            local rx, ry = math.cos(h), math.sin(h)               -- the camera's right, flat
            local o = Config.ArenaFrame
            local fwd = { -ry * math.cos(pt), rx * math.cos(pt), math.sin(pt) }
            local up = { ry * math.sin(pt), -rx * math.sin(pt), math.cos(pt) }
            local rel = {}
            local nearest, pan, wsum = 1e9, 0.0, 0.0
            for k, hang in ipairs(hangs) do
                rel[k] = { hang.x - o.x, hang.y - o.y, hang.z - o.z }
                local dx, dy, dz = hang.x - p.x, hang.y - p.y, hang.z - p.z
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d < nearest then nearest = d end
                local flat = math.max(0.5, math.sqrt(dx * dx + dy * dy))
                local w = 1.0 / math.max(4.0, d) ^ 2              -- the nearer hangs count more
                pan = pan + w * (dx * rx + dy * ry) / flat
                wsum = wsum + w
            end
            if wsum > 0 then pan = pan / wsum * (MU.pan or 0.6) end
            if #hangs == 0 then nearest = 0.0 end
            SendNUIMessage({ type = 'music', action = 'listen', zone = zone, level = MzbListener.level,
                             dist = nearest, pan = pan, cam = { p.x - o.x, p.y - o.y, p.z - o.z }, fwd = fwd, up = up,
                             hangs = rel })
            Wait(100)
        else
            Wait(500)
        end
    end
end)

-- the page says it is listening (it loads a moment after the scripts start): whatever it was sent before that is
-- lost, so the track is loaded again
RegisterNUICallback('musicReady', function(_, cb)
    cb('ok')
    loaded = nil
end)

-- ------------------------------------------------------------------ errors from the page: once per track
local reported = {}
RegisterNUICallback('musicError', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or type(data.rev) ~= 'number' or reported[data.rev] then return end
    reported[data.rev] = true
    local msg = tostring(data.msg or 'error'):sub(1, 120)
    TriggerServerEvent('mzb_arena:musicError', data.rev, msg)
end)

-- ------------------------------------------------------------------ the desk's Music section (html/music.js)
AddEventHandler('mzb_arena:lightsDesk', function()
    SendNUIMessage({ type = 'musicDesk', music = S, enabled = MU.enabled == true, mine = mine() })
end)

RegisterNUICallback('music', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    if data.action == 'mine' then
        local v = tonumber(data.value)
        if v and v == v then
            SetResourceKvpInt(KVP, math.floor(math.max(0, math.min(100, v))) + 1)
            SendNUIMessage({ type = 'music', action = 'mine', mine = mine() })
        end
        return
    end
    TriggerServerEvent('mzb_arena:music', data)
end)

-- /arenamusic: "mine" is yours alone (kept with KVP); everything else goes to the server, which checks who you are
RegisterCommand(MU.command or 'arenamusic', function(_, args)
    if args[1] and args[1]:lower() == 'mine' then
        local v = tonumber(args[2])
        if v and v == v then
            SetResourceKvpInt(KVP, math.floor(math.max(0, math.min(100, v))) + 1)
            SendNUIMessage({ type = 'music', action = 'mine', mine = mine() })
        end
        TriggerEvent('chat:addMessage', { args = { 'music', ('your music level: %d%%'):format(mine()) } })
        return
    end
    TriggerServerEvent('mzb_arena:musicCmd', { args[1], args[2], args[3], args[4] })
end, false)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (MU.command or 'arenamusic'), 'Maze Bank Arena: the music player',
        { { name = 'what', help = 'url | pause | resume | stop | volume <0-100> | status (staff) | mine <0-100> (your own level)' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and loaded then sendUnload() end
end)
