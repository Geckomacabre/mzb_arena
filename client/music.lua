-- mzb_arena - client: the music player (GlobalState.mzbMusic, server/music.lua).
-- The sound plays in this resource's NUI page (html/music.js; the page is always loaded, the desk is only its visible
-- part), and only as sound in the world: every speaker of the show (Config.Music.speakers) is a source of its own
-- there. This side tells the page what to play and where in it to be (on the server's clock: client/listener.lua),
-- and ten times a second where the listener is: the zone (bowl / near / building / outside), the camera (where it is,
-- which way it looks) and the speakers, all from the arena's middle. The page plays the track from each speaker in
-- 3D (Web Audio panners: nearer is louder, left is left, behind is behind), through the walls outside the bowl, with
-- the arena's reverb. The page takes the sound of a hidden YouTube player, or of the audio file, into its own sound
-- graph; with Config.Music.relay.enabled the server fetches the track first and the page reads it from the server's
-- relay (server/relay.js, over the server's HTTP port). A track that cannot be taken in is not played at all.
-- Far from the arena the page is told to unload the track; back near, it loads it mid-track.

local MU = Config.Music or {}
local S = GlobalState.mzbMusic or { kind = 'off' }
local KVP = 'mzb_arena_music_mine'                 -- your own level, stored + 1 (0 means never set)

local function mine()
    local v = GetResourceKvpInt(KVP)
    if v == 0 then return 100 end
    return math.max(0, math.min(100, v - 1))
end

local loaded = nil                                  -- the rev the page has
local pageState = nil                               -- what the page says it is doing (html/music.js: musicState)

-- where the relay answers: the server's own HTTP port, then its https name if it has one (S.web)
local function bases()
    local res, out = GetCurrentResourceName(), {}
    local ep = GetCurrentServerEndpoint()
    if type(ep) == 'string' and ep ~= '' then out[#out + 1] = ('http://%s/%s'):format(ep, res) end
    if type(S.web) == 'string' and S.web ~= '' then out[#out + 1] = ('https://%s/%s'):format(S.web, res) end
    return out
end

local function config()
    return { volume = MU.volume or 0.8, boost = MU.boost or 1.0, refDistance = MU.refDistance or 12.0, rolloff = MU.rolloff or 0.7,
             panning = MU.panning or 'HRTF', rooms = MU.rooms or {}, reverbSeconds = MU.reverbSeconds or 3.0,
             preDelay = MU.preDelay or 0.035, echo = MU.echo or false, farWet = MU.farWet or 0.0, bases = bases() }
end

local function sendLoad()
    pageState = nil
    SendNUIMessage({ type = 'music', action = 'load', music = S, pos = MzbTrackPos(S, true), fade = MzbFadeLeft(S),
                     mine = mine(), config = config() })
    loaded = S.rev
end

local function sendUnload()
    SendNUIMessage({ type = 'music', action = 'unload' })
    loaded, pageState = nil, nil
end

local function wanted()
    return MU.enabled and (S.kind == 'file' or S.kind == 'youtube')
        and #(GetEntityCoords(PlayerPedId()) - Config.Screens.origin) < (MU.range or 200.0)
end

local needSync = false
AddStateBagChangeHandler('mzbMusic', 'global', function(_, _, value)
    local before = S
    S = value or { kind = 'off' }
    if loaded and S.rev == (before and before.rev) then
        needSync = true                                                       -- pause / resume / volume
        if S.fade and not (before and before.fade) then                       -- a fade-out starts now, not at the next check
            SendNUIMessage({ type = 'music', action = 'sync', music = S, pos = MzbTrackPos(S, true), fade = MzbFadeLeft(S) })
        end
    end
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
                SendNUIMessage({ type = 'music', action = 'sync', music = S, pos = MzbTrackPos(S, true), fade = MzbFadeLeft(S) })
                lastSync = GetGameTimer()
            end
        elseif loaded then
            sendUnload()
        end
        Wait(500)
    end
end)

-- the speakers of the show that is up and the ones every show has: { x, y, z (from the arena's middle), gain,
-- ref (0 = Config.Music.refDistance), local (1 = in a room of its own, sent only while you are in that room) }
local function speakersFor(show, room)
    local all, o, out = MU.speakers or MU.hangs or {}, Config.ArenaFrame, {}
    for _, list in ipairs({ all[show] or {}, all.all or {} }) do
        for _, sp in ipairs(list) do
            local p, gain, own, ref = sp, 1.0, nil, 0.0
            if type(sp) == 'table' and sp[1] ~= nil then p, gain, own, ref = sp[1], sp[2] or 1.0, sp.room, sp.ref or 0.0 end
            if p and (not own or own == room) then
                out[#out + 1] = { p.x - o.x, p.y - o.y, p.z - o.z, gain, ref, own and 1 or 0 }
            end
        end
    end
    return out
end

-- where the listener is, ten times a second while a track is loaded
CreateThread(function()
    while true do
        if loaded then
            local show = GlobalState.mzbShow or Config.DefaultShow
            local p = GetFinalRenderedCamCoord()
            local rot = GetFinalRenderedCamRot(2)
            local h, pt = math.rad(rot.z), math.rad(rot.x)
            local rx, ry = math.cos(h), math.sin(h)               -- the camera's right, flat
            local o = Config.ArenaFrame
            local fwd = { -ry * math.cos(pt), rx * math.cos(pt), math.sin(pt) }
            local up = { ry * math.sin(pt), -rx * math.sin(pt), math.cos(pt) }
            SendNUIMessage({ type = 'music', action = 'listen', zone = MzbListener.zone, level = MzbListener.level,
                             cam = { p.x - o.x, p.y - o.y, p.z - o.z }, fwd = fwd, up = up,
                             speakers = speakersFor(show, MzbListener.room) })
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

-- the page says what it is playing and how (for /arenamusic status)
RegisterNUICallback('musicState', function(data, cb)
    cb('ok')
    if type(data) == 'table' and data.rev == S.rev then pageState = data end
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

-- what this player's own page is doing with the track (the answer to "is it really coming from the speakers?")
local function hereLine()
    if S.kind ~= 'file' and S.kind ~= 'youtube' then return nil end
    if not loaded then return 'here: not loaded (you are too far from the arena)' end
    local st = pageState
    if not st then return 'here: loading ...' end
    if st.error then return 'here: not playing - ' .. tostring(st.error):sub(1, 120) end
    return ('here: in the world from %d speaker%s (%s), reverb %s'):format(st.speakers or 0,
        st.speakers == 1 and '' or 's', st.zone or '?', st.signal == false and 'on, no signal yet' or 'on')
end

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
    if args[1] and args[1]:lower() == 'status' then
        local line = hereLine()
        if line then TriggerEvent('chat:addMessage', { args = { 'music', line } }) end
    end
end, false)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (MU.command or 'arenamusic'), 'Maze Bank Arena: the music player',
        { { name = 'what', help = 'url | pause | resume | stop | fade [seconds] | volume <0-100> | status (staff) | mine <0-100> (your own level)' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and loaded then sendUnload() end
end)
