-- mzb_arena - client: the light desk's show (GlobalState.mzbLights, server/lights.lua).
-- The interior's baked lights can't change colour in game, so the show is drawn: a spot light per fixture of the
-- show's rig (Config.LightRig, written by the build: moving heads and beams that pan, washes with their own aim, the
-- house lights in the roof) every frame while you are in the bowl / concourse / tunnel / backstage. Every effect is a
-- function of the network clock, so every player sees the same flash at the same moment. The desk is the NUI in html/.

local L = GlobalState.mzbLights or Config.LightDefault
local deskOpen = false

-- a fade-out (L.fade = { at, dur }: /arenalights fade, a video that stops - server/lights.lua): the show lights go
-- down over its seconds from the moment this client hears of it; the server switches them off when it is over
local fadeAt, fadeFrom = nil, nil
local function seeFade()
    local f = L and L.fade
    if type(f) ~= 'table' then
        fadeAt, fadeFrom = nil, nil
    elseif fadeAt ~= f.at then
        fadeAt, fadeFrom = f.at, GetGameTimer()
    end
end
seeFade()

-- (1.5.0) the desk's LIGHTS fader (the Grand Master) over every light's own level (the beams, the ring, the bars,
-- the lasers), and its BLACKOUT key (B.O.): dark at once, the house lights too, the look kept under it
local function master()
    if not L or L.bo then return 0.0 end
    return math.max(0.0, math.min(1.0, tonumber(L.master) or 1.0))
end
local function houseOf(l) return (l and l.bo) and 'off' or (l and l.house) or 'show' end

-- (1.5.0) the bowl in the dark (Config.LightDark): under BLACKOUT, and with the house lights off, the room's fill, the
-- light on every ped and the eye's getting used to the dark go too - a time cycle modifier while the camera is in the
-- bowl (the game applies a script's modifier after the room's own, and these values it sets outright). One that
-- another resource has on is left alone, and ours is only taken off while it is still ours.
local LD = Config.LightDark or {}
local darkRooms, inDark = {}, false
for name in pairs(LD.rooms or { bowl = true }) do darkRooms[GetHashKey(name)] = true end
local darkIdx, darkK, darkWarned = nil, nil, false        -- our modifier's index while it is on, and its strength
local function applyDark()
    local k = 0.0
    if LD.enabled ~= false and inDark and L then
        k = L.bo and (LD.blackout or 1.0) or (houseOf(L) == 'off' and (LD.houseOff or 0.75)) or 0.0
    end
    local now = GetTimecycleModifierIndex()
    if k > 0.0 then
        if now ~= darkIdx then
            if now ~= -1 then return end
            SetTimecycleModifier(LD.modifier or 'mzb_arena_dark')
            darkIdx, darkK = GetTimecycleModifierIndex(), nil
            if darkIdx == -1 and not darkWarned then
                darkWarned = true
                print(('[mzb_arena] lights: the time cycle modifier %s is not loaded (data/mzb_timecycle.xml) - reconnect')
                    :format(LD.modifier or 'mzb_arena_dark'))
            end
        end
        if darkK ~= k then SetTimecycleModifierStrength(k); darkK = k end
    elseif darkIdx then
        if now == darkIdx then ClearTimecycleModifier() end
        darkIdx, darkK = nil, nil
    end
end

AddStateBagChangeHandler('mzbLights', 'global', function(_, _, value)
    L = value or Config.LightDefault
    seeFade()
    if deskOpen then SendNUIMessage({ type = 'state', state = L }) end
    applyDark()
end)

-- ------------------------------------------------------------------ following the music (L.follow)
-- The page listens to the track this player's own game is playing and looks at its picture (html/follow.js); what it
-- finds comes here ten times a second and at every hit of the kick drum: the beat count, the tempo, the level and the
-- picture's main colours. The effects then run on that beat and in those colours instead of the desk's Speed and
-- colour slots - each player's lights with what that player hears. Nothing heard for 1.5 s: the desk's own again.
local FW = Config.LightFollow or {}
local heard = { at = -100000, beat = 0.0, bpm = 120.0, kickAt = -100000, level = 1.0, colors = nil, colorsAt = -100000,
                flashAt = -100000, bright = nil }
local shownBeat, asked = 0.0, nil
local COLORS, BPM = nil, 120                                -- what look() draws with this frame
local WHITE = { { 255, 255, 255 } }

-- is the tempo followed, are the colours, does the desk choose its own looks (auto: both, and the looks)?
local function following()
    local f = (FW.enabled ~= false and L and L.follow) or 'off'
    return f == 'both' or f == 'tempo' or f == 'auto', f == 'both' or f == 'colour' or f == 'auto', f == 'auto'
end

-- (1.5.0) Auto: the looks chosen from what is heard - where the track is (Config.LightAuto): calm (few or no kicks,
-- quiet), groove (a steady kick), a build-up (the kicks gone or racing while it gets louder) and the drop (the kicks
-- back hard after a build-up or a calm, for a few bars). Each player's game listens to its own music player, as
-- for the tempo and the colours, so the sections change for everyone at about the same moment.
local LA = Config.LightAuto or {}
local kicks, levels = {}, {}                -- the last hits' times; the level's last seconds { time, level }
local AUTO = { state = 'groove', since = 0, on = false }

-- (/arenalights status, the tests) the section the lights are in, nil when Auto is not running here
function MzbLightAutoSection()
    return AUTO.on and AUTO.state or nil
end

local function autoState(now)
    while kicks[1] and now - kicks[1] > 8000 do table.remove(kicks, 1) end
    while levels[1] and now - levels[1][1] > 8000 do table.remove(levels, 1) end
    local k4, k2 = 0, 0
    for _, t in ipairs(kicks) do
        if now - t < 4000 then k4 = k4 + 1 end
        if now - t < 2000 then k2 = k2 + 1 end
    end
    local rate4, e, before = k4 / 4.0, heard.level, nil
    for _, h in ipairs(levels) do
        if now - h[1] >= 3500 then before = h[2] end                    -- the newest of those 3.5 s old or more
    end
    local rising = before ~= nil and e - before > (LA.rise or 0.15)
    local quiet = LA.quiet or 0.55
    local prev = AUTO.state
    local st, held = prev, now - AUTO.since
    if k2 >= 2 and (prev == 'build' or prev == 'calm') and held >= 2000 and e > quiet then
        st = 'drop'                                                     -- the kicks back hard after it
    elseif prev == 'drop' and held < (LA.dropBeats or 16) * 60000.0 / heard.bpm then
        st = 'drop'
    elseif rate4 > (LA.roll or 3.2) or (k2 == 0 and rising) then
        st = 'build'                                                    -- racing hits, or louder without any
    elseif rate4 < 0.5 and e < quiet then
        st = 'calm'
    elseif rate4 >= 0.75 then
        st = 'groove'
    end                                                                 -- (else: a gap of a beat or two keeps it)
    if st ~= prev then AUTO.state, AUTO.since = st, now end
end

-- the look of the section this player's music is in: { mode, move, level, focus }
local function autoLook(now, beat)
    local s = (LA.looks or {})[AUTO.state] or {}
    local into = (now - AUTO.since) * heard.bpm / 60000.0             -- beats into the section
    local mode, move = s.mode or 'chase', s.move or 'sweep'
    if AUTO.state == 'build' and into >= (LA.strobeAfter or 16) then mode = s.late or 'strobe' end
    if AUTO.state == 'drop' and into >= 4 then mode = s.after or 'alternate' end
    if type(s.moves) == 'table' and #s.moves > 0 then                  -- the groove changes its movement every 16 beats
        move = s.moves[(math.floor(beat / 16) % #s.moves) + 1]
    end
    local level = s.level or 0.85
    if AUTO.state == 'build' then level = level + (1.0 - level) * math.min(1.0, into / (LA.strobeAfter or 16)) end
    return mode, move, level, s.focus
end

RegisterNUICallback('lightsFollow', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local now = GetGameTimer()
    local beat, bpm = tonumber(data.beat), tonumber(data.bpm)
    if beat and bpm and beat == beat and bpm >= 30.0 and bpm <= 300.0 then
        heard.beat, heard.bpm, heard.at = beat, bpm, now
        if data.kick == true then heard.kickAt = now; kicks[#kicks + 1] = now end
        heard.level = math.max(0.0, math.min(1.0, tonumber(data.level) or 1.0))
        levels[#levels + 1] = { now, heard.level }
    end
    local cs = nil
    if type(data.colors) == 'table' then
        cs = {}
        for i = 1, math.min(3, #data.colors) do
            local c = data.colors[i]
            local r, g, b = type(c) == 'table' and tonumber(c[1]), type(c) == 'table' and tonumber(c[2]), type(c) == 'table' and tonumber(c[3])
            if r and g and b then
                cs[#cs + 1] = { math.floor(math.max(0, math.min(255, r))), math.floor(math.max(0, math.min(255, g))),
                                math.floor(math.max(0, math.min(255, b))) }
            end
        end
        if #cs == 0 then cs = nil end
    end
    heard.colors, heard.colorsAt = cs, now
    -- the picture: a flash in it, and how bright it is (nil: no picture to look at)
    if data.flash == true then heard.flashAt = now end
    local br = tonumber(data.bright)
    heard.bright = (br and br == br) and math.max(0.0, math.min(1.0, br)) or nil
end)

-- the page is (again) there: it is told again what to follow
RegisterNUICallback('followReady', function(_, cb)
    cb('ok')
    asked = nil
end)

-- ------------------------------------------------------------------ where the player is
local drawHere = false
local inArena = false                  -- (1.5.0) in any of the arena's rooms: the house lights are drawn
local roomKeys = {}
for name in pairs(Config.LightRooms or {}) do roomKeys[GetHashKey(name)] = true end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local id = MzbInterior()
        inArena = id ~= 0 and GetInteriorFromEntity(ped) == id
        drawHere = inArena and roomKeys[GetRoomKeyFromEntity(ped)] == true
        -- (1.5.0) the camera in a room that goes dark (the time cycle goes by the camera's room)
        local dark = id ~= 0 and GetInteriorFromPrimaryView() == id and darkRooms[GetRoomKeyForGameViewport()] == true
        if dark ~= inDark then inDark = dark; applyDark() end
        -- the page listens for the lights only while this player has lights to see
        local tempo, colour, auto = following()
        -- (1.5.0) the bar lights in Video look at the picture whatever the rig follows
        local bars = L and L.bars and L.bars.on and L.bars.mode == 'video' and (Config.LightBars or {}).enabled ~= false
        local want = drawHere and L and ((L.on == true and (tempo or colour)) or bars)
        colour = colour or (bars and true) or false
        local key = want and ((tempo and 't' or '') .. (colour and 'c' or '') .. (auto and 'a' or '') .. (L.bpm or 120)) or 'off'
        if key ~= asked then
            asked = key
            SendNUIMessage({ type = 'follow', on = want == true, tempo = tempo, colour = colour, auto = auto, bpm = L.bpm or 120,
                             config = { minBpm = FW.minBpm or 80, colours = FW.colours or 3, sensitivity = FW.sensitivity or 1.0 } })
        end
        Wait(600)
    end
end)

-- ------------------------------------------------------------------ the house lights (1.5.0)
-- The roof's house lights, drawn here (shared/house_lights.lua: the two house light sets' own lights, full and
-- dimmed, with their colours, ranges, cones and falloff as the engine drew them baked). As entity sets, every change
-- of the house - a look's house setting, BLACKOUT, the HOUSE key - had the interior rebuilt: the whole arena vanished
-- for a few frames and faded back in (the user, 2026-10-29: "why does the mlo flicker when i change the playback
-- lights?"). Now the house fades up or down over Config.HouseLightFade s; 'show' is the level of the house light set
-- the show's list names.
local HL, HSETS = Config.HouseLights or {}, Config.HouseSets or {}
local function showHouse(show)
    for _, s in ipairs(Config.Shows[show] or {}) do
        if s == HSETS.full then return 'full' elseif s == HSETS.dim then return 'dim' end
    end
    return 'off'
end
local function houseLevel()
    local h = houseOf(L)                                         -- ('off' under BLACKOUT)
    if h == 'show' then return showHouse(GlobalState.mzbShow or Config.DefaultShow) end
    return h
end
local houseK = { full = 0.0, dim = 0.0 }                         -- how far up each set is (0 .. 1)
local houseBo = false                                            -- BLACKOUT as last seen: it and its lifting cut

CreateThread(function()
    local last = GetGameTimer()
    while true do
        local now = GetGameTimer()
        local step = math.min(0.25, (now - last) / 1000.0) / math.max(0.05, tonumber(Config.HouseLightFade) or 1.5)
        last = now
        local want, scale, lit = houseLevel(), tonumber(Config.HouseLightScale) or 1.0, false
        local bo = (L and L.bo) == true
        local cut = bo ~= houseBo                                -- (dark at once, and back at once)
        houseBo = bo
        for _, lvl in ipairs({ 'full', 'dim' }) do
            local k, goal = houseK[lvl], want == lvl and 1.0 or 0.0
            if cut then k = goal else k = k < goal and math.min(goal, k + step) or math.max(goal, k - step) end
            houseK[lvl] = k
            if k > 0.001 and inArena then
                lit = true
                for _, f in ipairs(HL[lvl] or {}) do
                    DrawSpotLight(f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[11], f[10] * k * scale,
                        f[12], f[13], f[14])
                end
            end
        end
        Wait(lit and 0 or 100)
    end
end)

-- (the tests) the house lights now: the level they go to, how far up each set is
function MzbHouseNow() return { level = houseLevel(), full = houseK.full, dim = houseK.dim } end

-- ------------------------------------------------------------------ the effects
local function hsv(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local r, g, b
    i = i % 6
    if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

local function hash(a, b)                                   -- the same pseudo-random pick on every client
    return ((a * 73856093) ~ (b * 19349663)) % 1000
end

local function frac(x) return x - math.floor(x) end

-- the colour and level (0..1) of fixture i of n at time t
local function look(i, n, t, beat)
    local cs = COLORS or L.colors or WHITE
    local c = cs[((i - 1) % #cs) + 1]
    local mode = (AUTO.on and AUTO.mode) or L.mode or 'static'
    if mode == 'static' or mode == 'sweep' or mode == 'ballyhoo' then
        return c[1], c[2], c[3], 1.0
    elseif mode == 'chase' then
        local step = math.floor(beat * 2)
        local cc = cs[(step % #cs) + 1]
        return cc[1], cc[2], cc[3], ((i + step) % 4 == 0) and 1.0 or 0.0
    elseif mode == 'strobe' then
        local hz = math.min(BPM / 60.0 * 2.0, Config.LightMaxStrobeHz or 8.0)
        if hz <= 0.0 then
            local lvl = 0.5 + 0.5 * math.cos(beat * math.pi * 2.0)
            return c[1], c[2], c[3], lvl * lvl
        end
        local k = math.floor(t * hz)
        local cc = cs[(k % #cs) + 1]
        return cc[1], cc[2], cc[3], (frac(t * hz) < 0.3) and 1.0 or 0.0
    elseif mode == 'pulse' then
        local lvl = 0.5 + 0.5 * math.cos((beat + i / n * 0.5) * math.pi * 2.0)
        return c[1], c[2], c[3], 0.12 + 0.88 * lvl * lvl
    elseif mode == 'rainbow' then
        local r, g, b = hsv(frac(beat / 8.0 + i / n), 1.0, 1.0)
        return r, g, b, 1.0
    elseif mode == 'random' then
        local k = math.floor(beat)
        if hash(k, i) < 400 then
            local cc = cs[(hash(k + 7, i) % #cs) + 1]
            return cc[1], cc[2], cc[3], 1.0
        end
        return 0, 0, 0, 0.0
    elseif mode == 'police' then
        local on = (math.floor(t * 4.0) % 2 == 0)
        if (i % 2 == 0) == on then return 255, 20, 20, 1.0 end
        return 20, 40, 255, 1.0
    elseif mode == 'fade' then                               -- a slow crossfade through the colours, all together
        if #cs == 1 then
            local lvl = 0.5 + 0.5 * math.cos(beat / 4.0 * math.pi * 2.0)
            return c[1], c[2], c[3], 0.1 + 0.9 * lvl
        end
        local x = beat / 4.0
        local k = math.floor(x)
        local a, b = cs[(k % #cs) + 1], cs[((k + 1) % #cs) + 1]
        local f = frac(x)
        f = f * f * (3.0 - 2.0 * f)
        return math.floor(a[1] + (b[1] - a[1]) * f), math.floor(a[2] + (b[2] - a[2]) * f),
               math.floor(a[3] + (b[3] - a[3]) * f), 1.0
    elseif mode == 'wave' then                               -- a band of light rolling round the rig
        local lvl = 0.5 + 0.5 * math.sin((beat / 2.0 - i / n * 2.0) * math.pi * 2.0)
        return c[1], c[2], c[3], 0.05 + 0.95 * lvl * lvl * lvl
    elseif mode == 'flash' then                              -- the whole rig hits on the beat and dies away
        local k = math.floor(beat)
        local cc = cs[(k % #cs) + 1]
        return cc[1], cc[2], cc[3], math.exp(-frac(beat) * 5.0)
    elseif mode == 'alternate' then                          -- every other fixture, swapping on the beat
        local k = math.floor(beat)
        if #cs == 1 then return c[1], c[2], c[3], ((i + k) % 2 == 0) and 1.0 or 0.0 end
        local cc = cs[((i + k) % #cs) + 1]
        return cc[1], cc[2], cc[3], 1.0
    elseif mode == 'twinkle' then                            -- the rig glows low, single fixtures sparkle
        local x = beat * 2.0 + hash(i, 3) / 1000.0
        local k = math.floor(x)
        if hash(k, i) < 180 then
            local cc = cs[(hash(k, i + 11) % #cs) + 1]
            return cc[1], cc[2], cc[3], math.exp(-frac(x) * 3.0)
        end
        return c[1], c[2], c[3], 0.08
    elseif mode == 'lightning' then                          -- dark, then a ragged white flicker now and then
        local x = beat / 2.0
        local k = math.floor(x)
        if hash(k, 5) < 450 then
            local f = frac(x)
            if f < 0.2 and hash(math.floor(t * 18.0), i) < 650 then return 235, 240, 255, 1.0 end
        end
        return c[1], c[2], c[3], 0.03
    elseif mode == 'fire' then                               -- warm, flickering (ignores the colour slots)
        local fl = 0.5 + 0.5 * math.sin(t * 7.3 + i * 1.9) * math.sin(t * 3.1 + i * 0.7 + beat)
        return 255, math.floor(30 + 130 * fl), math.floor(10 * fl), 0.45 + 0.55 * fl
    elseif mode == 'bounce' then                             -- a block of light running end to end and back
        local pos = math.abs(frac(beat / 8.0) * 2.0 - 1.0) * (n - 1) + 1
        local lvl = math.max(0.0, 1.0 - math.abs(i - pos) / 2.0)
        local cc = cs[(math.floor(beat / 4.0) % #cs) + 1]
        return cc[1], cc[2], cc[3], lvl
    end
    return c[1], c[2], c[3], 1.0
end

-- the aims in play: L.focus is one of floor / stage / crowd or a list of them (the fixtures take turns)
local function foci()
    local fo = (AUTO.on and AUTO.focus) or L.focus or 'floor'
    if type(fo) == 'table' then return #fo > 0 and fo or { 'floor' } end
    return { fo }
end

-- the movement: L.move, or the old sweep / ballyhoo modes that moved the beams themselves
local function movement()
    local mv = (AUTO.on and AUTO.move) or L.move or 'none'
    if mv == 'none' and (L.mode == 'sweep' or L.mode == 'ballyhoo') then mv = L.mode end
    return mv
end

local ARENA_U = vector3(math.cos(Config.ArenaFrame.ang), math.sin(Config.ArenaFrame.ang), 0.0)   -- along the arena
local ARENA_V = vector3(-ARENA_U.y, ARENA_U.x, 0.0)                                              -- across it

-- where fixture f (i of n) aims at time t
-- (1.5.0) random: every fixture glides to a new place of its own every Config.LightRandomBeats beats. The places are
-- picked from the fixture's number and the beat count (no random draw), so every player sees the same ones
local function rnd(i, k, s)
    local x = math.sin(i * 12.9898 + k * 78.233 + s * 37.719) * 43758.5453
    return x - math.floor(x)
end

local function randomStep(beat)
    local q = beat / (Config.LightRandomBeats or 2)
    local k = math.floor(q)
    local e = q - k
    return k, e * e * (3.0 - 2.0 * e)                                   -- eased: it sets off and settles
end

local function aim(i, n, f, t, beat, focus, fo, mv)
    if f[7] == 4 then                                                    -- a floor beam keeps its own aim, always
        return f[1] + f[4] * 30.0, f[2] + f[5] * 30.0, f[3] + f[6] * 30.0
    end
    if f[7] == 2 and fo == 'floor' then                                  -- a wash keeps its own aim on the floor
        return f[1] + f[4] * 30.0, f[2] + f[5] * 30.0, f[3] + f[6] * 30.0
    end
    local spread = Config.LightSpread or 6.0
    local a = (i / n) * math.pi * 2.0
    local side = (i % 2 == 0) and 1.0 or -1.0
    local wave = math.sin(beat * math.pi * 0.5 + i * 0.6)
    local c = focus.floor
    local r = (Config.LightCrowd and Config.LightCrowd.r) or 33.0
    local cz = (Config.LightCrowd and Config.LightCrowd.z) or (c.z + 6.0)
    -- the stands behind fixture f, swung by sw (radians) round the bowl's middle
    local function crowd(sw)
        local dx, dy = f[1] - c.x, f[2] - c.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1.0 then dx, dy, len = math.cos(a), math.sin(a), 1.0 end
        local ca, sa = math.cos(sw), math.sin(sw)
        local ux, uy = (dx * ca - dy * sa) / len, (dx * sa + dy * ca) / len
        return c.x + ux * r, c.y + uy * r, cz
    end
    if fo == 'crowd' then
        local sw, dz = 0.0, 0.0
        if mv == 'sweep' then sw = math.sin(beat * math.pi * 0.5 + i) * 0.5
        elseif mv == 'ballyhoo' then sw = math.sin(t * 0.9 + i * 1.7) * 0.6; dz = math.cos(t * 1.1 + i * 2.3) * 3.0
        elseif mv == 'fan' then sw = (i / n - 0.5) * math.sin(beat * math.pi * 0.5) * 1.2
        elseif mv == 'nod' then dz = wave * 5.0
        elseif mv == 'cross' then sw = side * math.sin(beat * math.pi * 0.5) * 0.6
        elseif mv == 'random' then
            local k, e = randomStep(beat)
            local s0, s1 = rnd(i, k, 1) * 1.4 - 0.7, rnd(i, k + 1, 1) * 1.4 - 0.7
            local z0, z1 = rnd(i, k, 2) * 6.0 - 2.0, rnd(i, k + 1, 2) * 6.0 - 2.0
            sw, dz = s0 + (s1 - s0) * e, z0 + (z1 - z0) * e
        end
        local tx, ty, tz = crowd(sw)
        return tx, ty, tz + dz
    end
    local p = (fo == 'stage' and focus.stage) or focus.floor
    local tx, ty, tz = p.x + math.cos(a) * spread, p.y + math.sin(a) * spread, p.z - 1.0
    if mv == 'sweep' then
        local b = a + beat * math.pi * 0.5
        tx, ty = p.x + math.cos(b) * spread * 1.6, p.y + math.sin(b) * spread * 1.6
    elseif mv == 'ballyhoo' then
        tx = p.x + math.sin(t * 0.9 + i * 1.7) * spread * 2.0
        ty = p.y + math.cos(t * 1.1 + i * 2.3) * spread * 2.0
    elseif mv == 'fan' then                                               -- the spots open out and close in
        local k = 1.0 + 0.9 * math.sin(beat * math.pi * 0.5)
        tx, ty = p.x + math.cos(a) * spread * k, p.y + math.sin(a) * spread * k
    elseif mv == 'nod' then                                               -- tilt out to the stands and back
        local cx, cy, czz = crowd(0.0)
        local k = 0.5 + 0.5 * wave
        tx, ty, tz = tx + (cx - tx) * k, ty + (cy - ty) * k, tz + (czz - tz) * k
    elseif mv == 'cross' then                                             -- pairs swing across each other
        local k = side * math.sin(beat * math.pi * 0.5) * spread * 2.5
        tx, ty = tx + ARENA_V.x * k, ty + ARENA_V.y * k
    elseif mv == 'random' then                                            -- each to a place of its own, and on
        local k, e = randomStep(beat)
        local function at(kk)
            local ang, rad = rnd(i, kk, 3) * math.pi * 2.0, math.sqrt(rnd(i, kk, 4)) * spread * 2.2
            return p.x + math.cos(ang) * rad, p.y + math.sin(ang) * rad
        end
        local x0, y0 = at(k)
        local x1, y1 = at(k + 1)
        tx, ty = x0 + (x1 - x0) * e, y0 + (y1 - y0) * e
    end
    return tx, ty, tz
end

-- (1.5.0) the beams (Config.LightBeams): a fixture is FiveM's own script light with its volume drawn - the beam
-- shows in the air, in the desk's colour and level, wherever the desk aims it. (The beams baked into a stage stand
-- still in one colour whatever the desk does: the game cannot move or recolour them.) Up to `max` a frame; past
-- that, with LightBeams off, or on a game without these natives, the lit spot alone, as before.
local LB = Config.LightBeams or {}
local HAS_BEAMS = type(PrepareLight) == 'function' and type(DrawLight) == 'function' and
                  type(SetLightVolumeDetails) == 'function' and type(SetLightInterior) == 'function'
local beamInterior, beamsLeft = 0, 0         -- this frame's: set by the drawing loop (beginBeams)
local bowlRoom = {}                          -- interior -> the bowl's room index

-- (1.5.0) the gobo (Config.LightGobos, the desk's Gobo): a pattern each beam projects - stars, dots, rings ... from the
-- texture dictionary stream/interior/mzb_tx_gobos.ytd - turning slowly on the beat
local LG = Config.LightGobos or {}
local gobo, goboAngle, goboTxd = nil, 0.0, false

local function beginBeams(id, beat)
    beamInterior = (HAS_BEAMS and LB.enabled ~= false) and id or 0
    beamsLeft = LB.max or 48
    if beamInterior ~= 0 and not bowlRoom[id] then
        local i = GetInteriorRoomIndexByHash(id, GetHashKey('bowl'))
        bowlRoom[id] = (i and i >= 0) and i or 1
    end
    gobo = nil
    if beamInterior ~= 0 and L.gobo and LG.enabled ~= false and type(SetLightTexture) == 'function' then
        if not goboTxd then
            RequestStreamedTextureDict(LG.txd or 'mzb_tx_gobos', false)
            goboTxd = HasStreamedTextureDictLoaded(LG.txd or 'mzb_tx_gobos') and true or false
        end
        if goboTxd then gobo = GetHashKey(L.gobo) end
    end
    goboAngle = (beat or 0.0) * math.pi * (LG.spin or 0.125)
end

local function spot(f, tx, ty, tz, r, g, b, bright, cone, glow)
    local dx, dy, dz = tx - f[1], ty - f[2], tz - f[3]
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len <= 0.1 then return end
    dx, dy, dz = dx / len, dy / len, dz / len
    if beamInterior ~= 0 and beamsLeft > 0 then
        beamsLeft = beamsLeft - 1
        -- the tangent: any direction square to the beam
        local ax, ay, az = 0.0, 0.0, 1.0
        if math.abs(dz) > 0.9 then ax, az = 1.0, 0.0 end
        local qx, qy, qz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
        local ql = math.sqrt(qx * qx + qy * qy + qz * qz)
        qx, qy, qz = qx / ql, qy / ql, qz / ql
        local flags = LB.flags or 4096
        if gobo then
            -- the gobo turns: the tangent round the beam's axis (q cos a + (d x q) sin a)
            local ca, sa = math.cos(goboAngle), math.sin(goboAngle)
            local cx, cy, cz = dy * qz - dz * qy, dz * qx - dx * qz, dx * qy - dy * qx
            qx, qy, qz = qx * ca + cx * sa, qy * ca + cy * sa, qz * ca + cz * sa
            flags = flags | (LG.flag or 32)
        end
        local level = math.min(1.5, bright / (Config.LightBrightness or 12.0))
        PrepareLight(LB.type or 2, flags, f[1], f[2], f[3], r, g, b, bright * (LB.intensity or 0.25))
        SetLightDirection(dx, dy, dz, qx, qy, qz)
        if gobo then SetLightTexture(LG.txd or 'mzb_tx_gobos', gobo) end
        SetLightCone(cone * 0.5, cone)
        SetLightRadius(len + 20.0)
        SetLightFalloff(LB.exponent or 16.0)
        SetLightVolumeDetails((LB.volume or 1.0) * level, LB.size or 1.0, r, g, b, 1.0, LB.edge or 1.0)
        SetLightInterior(beamInterior, false, bowlRoom[beamInterior] or 1)
        DrawLight()
    else
        DrawSpotLight(f[1], f[2], f[3], dx, dy, dz, r, g, b, len + 20.0, bright,
            Config.LightHardness or 0.0, cone, Config.LightFalloff or 1.0)
    end
    if glow > 0.0 and Config.LightLensGlow then
        DrawLightWithRange(f[1] + dx * 0.4, f[2] + dy * 0.4, f[3] + dz * 0.4, r, g, b, 1.6, glow)
    end
end

-- (1.5.0) the lasers (Config.Lasers, the desk's Lasers): from each laser unit of the show, `beams` thin beams in a
-- pattern on the beat - fan (spread across), sweep (the fan swings), tunnel (a turning cone), scan (up and down),
-- chase (one beam at a time) - in the desk's colour slots or one colour. Drawn as FiveM's script lights with a
-- volume and a cone a fraction of a degree wide; on a game without those natives, a line.
local LZ = Config.Lasers or {}
local lasersLeft = 0

local function turn(dx, dy, dz, yawDeg, pitchDeg)
    local h = math.atan(dy, dx) + math.rad(yawDeg)
    local el = math.asin(math.max(-1.0, math.min(1.0, dz))) + math.rad(pitchDeg)
    local c = math.cos(el)
    return math.cos(h) * c, math.sin(h) * c, math.sin(el)
end

local function laserBeam(x, y, z, dx, dy, dz, r, g, b)
    local range = LZ.range or 70.0
    if beamInterior ~= 0 and lasersLeft > 0 then
        lasersLeft = lasersLeft - 1
        local ax, ay, az = 0.0, 0.0, 1.0
        if math.abs(dz) > 0.9 then ax, az = 1.0, 0.0 end
        local qx, qy, qz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
        local ql = math.sqrt(qx * qx + qy * qy + qz * qz)
        PrepareLight(LB.type or 2, LB.flags or 4096, x, y, z, r, g, b, LZ.intensity or 2.0)
        SetLightDirection(dx, dy, dz, qx / ql, qy / ql, qz / ql)
        SetLightCone((LZ.width or 0.6) * 0.5, LZ.width or 0.6)
        SetLightRadius(range)
        SetLightFalloff(LZ.exponent or 2.0)
        SetLightVolumeDetails(LZ.volume or 3.0, LZ.size or 0.3, r, g, b, 1.0, 1.0)
        SetLightInterior(beamInterior, false, bowlRoom[beamInterior] or 1)
        DrawLight()
    elseif beamInterior == 0 then
        DrawLine(x, y, z, x + dx * range * 0.6, y + dy * range * 0.6, z + dz * range * 0.6, r, g, b, 255)
    end
end

local function drawLasers(show, beat)
    local lz = L and L.lasers
    if not (lz and lz.on and LZ.enabled ~= false) then return end
    local units = (LZ.units or {})[show]
    if not units or #units == 0 then return end
    local gm = master()
    if gm < 0.01 then return end
    lasersLeft = LZ.max or 24
    local n, spread, tilt = LZ.beams or 6, LZ.spread or 50.0, LZ.tilt or 6.0
    local pat = lz.pattern or 'fan'
    local cols = (type(lz.colour) == 'table') and { lz.colour } or COLORS or WHITE
    for ui, u in ipairs(units) do
        for k = 0, n - 1 do
            local f = n > 1 and (k / (n - 1) - 0.5) or 0.0               -- -0.5 .. 0.5 across the fan
            local yaw, pitch, lit = f * spread, tilt, true
            if pat == 'sweep' then
                yaw = yaw + math.sin(beat * math.pi * 0.25 + ui) * 25.0
            elseif pat == 'tunnel' then
                local a = (k / n) * math.pi * 2.0 + beat * math.pi * 0.5
                yaw, pitch = math.cos(a) * 14.0, tilt + math.sin(a) * 14.0
            elseif pat == 'scan' then
                pitch = tilt + math.sin(beat * math.pi * 0.5 + k * 0.4) * 12.0
            elseif pat == 'chase' then
                lit = (math.floor(beat * 2) % n) == k
            end
            if lit then
                local c = cols[((k + ui) % #cols) + 1]
                local dx, dy, dz = turn(u[4], u[5], u[6], yaw, pitch)
                laserBeam(u[1], u[2], u[3], dx, dy, dz, math.floor(c[1] * gm), math.floor(c[2] * gm), math.floor(c[3] * gm))
            end
        end
    end
end

-- (1.5.0) the bar lights (Config.LightBars, the desk's Bars): LED strips under the roof's trusses, along the top of
-- the upper tier's ledge and on the stage - the ramp's edges, the lip, the walkway (Config.BarStrips), a zone of
-- their own. Each is drawn as a lit strip turned to the camera
-- (both faces: DrawPoly draws one), the nearest of them cast a little light round them. Video: the colours of the
-- picture on the screens round the bowl, white on its flashes, dimmer in its dark scenes; steady: the colour slots (or
-- the one colour) round the bowl; chase: they run round it on the beat; pulse: all of them on the beat
local LBR = Config.LightBars or {}
local barGlow = {}                          -- show -> { x, y, z, angle, group } every LBR.glowEvery m along the strips

-- a group's strips: rafters and ledges are the bowl's, the stage's are the show's own (the DJ show has the concert's)
local function barList(group, list, show)
    if group == 'stage' then return MzbShowAs(list, show) or {} end
    return list
end

local function barGlowPoints(show)
    if barGlow[show] then return barGlow[show] end
    local pts = {}
    barGlow[show] = pts
    local every = LBR.glowEvery or 6.0
    for group, list in pairs(Config.BarStrips or {}) do
        for _, s in ipairs(barList(group, list, show)) do
            local dx, dy, dz = s[4] - s[1], s[5] - s[2], s[6] - s[3]
            local n = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy + dz * dz) / every + 0.5))
            for k = 0, n - 1 do
                local f = (k + 0.5) / n
                pts[#pts + 1] = { s[1] + dx * f, s[2] + dy * f, s[3] + dz * f, s[7], group }
            end
        end
    end
    return pts
end

-- how lit a strip at angle a (0 .. 1 round the bowl) is in the mode, and its colour
local function barLook(bz, a, beat, cols)
    local c = cols[(math.floor(a * #cols * 4) % #cols) + 1]          -- the colours in turn, four times round
    local idle, lvl = LBR.idle or 0.06, 1.0
    if bz.mode == 'chase' then
        local head = (beat / 8.0 * (LBR.chase or 1.0)) % 1.0
        local behind = (head - a) % 1.0
        local tail = LBR.tail or 0.18
        lvl = behind < tail and math.max(idle, 1.0 - behind / tail) or idle
    elseif bz.mode == 'pulse' then
        lvl = idle + (1.0 - idle) * math.exp(-(beat % 1.0) * 4.0)
    end
    return c, lvl
end

local function drawBars(beat, now, show)
    local bz = L and L.bars
    if not (bz and bz.on and LBR.enabled ~= false and Config.BarStrips) then return end
    local level = (bz.level or 1.0) * master()
    if level < 0.005 then return end
    local cols = (type(bz.colour) == 'table') and { bz.colour } or L.colors or WHITE
    local flash = 0.0
    if bz.mode == 'video' then
        if heard.colors and now - heard.colorsAt < 1500 then cols = heard.colors end
        if heard.bright and now - heard.colorsAt < 1500 then level = level * (0.35 + 0.65 * heard.bright) end
        flash = math.exp(-(now - heard.flashAt) / 1000.0 * 9.0)
    end
    local cam, rot = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2)
    local cx, cy, cz = cam.x, cam.y, cam.z
    local pr, hr = math.rad(rot.x), math.rad(rot.z)
    local fx, fy, fz = -math.sin(hr) * math.cos(pr), math.cos(hr) * math.cos(pr), math.sin(pr)
    local w = (LBR.width or 0.07) * 0.5
    for group, list in pairs(Config.BarStrips) do
        if bz.where == nil or bz.where == 'all' or bz.where == group then
            for _, s in ipairs(barList(group, list, show)) do
                local c, lvl = barLook(bz, s[7], beat, cols)
                local k = level * lvl
                -- (not the strips wholly behind the camera)
                local ahead = (s[1] - cx) * fx + (s[2] - cy) * fy + (s[3] - cz) * fz > 0.0
                    or (s[4] - cx) * fx + (s[5] - cy) * fy + (s[6] - cz) * fz > 0.0
                if k > 0.01 and ahead then
                    local r, g, b = c[1], c[2], c[3]
                    if flash > 0.02 then
                        r, g, b = r + (255 - r) * flash, g + (255 - g) * flash, b + (255 - b) * flash
                    end
                    r, g, b = math.floor(r * k), math.floor(g * k), math.floor(b * k)
                    if LBR.lines then
                        DrawLine(s[1], s[2], s[3], s[4], s[5], s[6], r, g, b, 255)
                    else
                        -- across the strip, square to it and to the way to the camera
                        local dx, dy, dz = s[4] - s[1], s[5] - s[2], s[6] - s[3]
                        local vx, vy, vz = (s[1] + s[4]) * 0.5 - cx, (s[2] + s[5]) * 0.5 - cy, (s[3] + s[6]) * 0.5 - cz
                        local qx, qy, qz = dy * vz - dz * vy, dz * vx - dx * vz, dx * vy - dy * vx
                        local ql = math.sqrt(qx * qx + qy * qy + qz * qz)
                        if ql > 1e-6 then
                            qx, qy, qz = qx / ql * w, qy / ql * w, qz / ql * w
                            local ax, ay, az, bx, by, bz_ = s[1] + qx, s[2] + qy, s[3] + qz, s[4] + qx, s[5] + qy, s[6] + qz
                            local ex, ey, ez, fx, fy, fz = s[4] - qx, s[5] - qy, s[6] - qz, s[1] - qx, s[2] - qy, s[3] - qz
                            DrawPoly(ax, ay, az, bx, by, bz_, ex, ey, ez, r, g, b, 255)
                            DrawPoly(ex, ey, ez, bx, by, bz_, ax, ay, az, r, g, b, 255)
                            DrawPoly(ax, ay, az, ex, ey, ez, fx, fy, fz, r, g, b, 255)
                            DrawPoly(fx, fy, fz, ex, ey, ez, ax, ay, az, r, g, b, 255)
                        end
                    end
                end
            end
        end
    end
    -- the light round them: the nearest LBR.maxGlow points of the strips that are on
    local pts, near = barGlowPoints(show), {}
    for _, p in ipairs(pts) do
        if bz.where == nil or bz.where == 'all' or bz.where == p[5] then
            local dx, dy, dz = p[1] - cx, p[2] - cy, p[3] - cz
            near[#near + 1] = { dx * dx + dy * dy + dz * dz, p }
        end
    end
    table.sort(near, function(x, y) return x[1] < y[1] end)
    for i = 1, math.min(#near, LBR.maxGlow or 40) do
        local p = near[i][2]
        local c, lvl = barLook(bz, p[4], beat, cols)
        local k = level * lvl
        if k > 0.01 then
            DrawLightWithRange(p[1], p[2], p[3] - 0.15, c[1], c[2], c[3], LBR.glowRange or 4.5, (LBR.glow or 3.0) * k)
        end
    end
end

-- the show's rig: the build's fixtures (Config.LightRig), the owner's own (Config.LightRigExtra) and the moving heads
-- on the stage's trusses (Config.StageLights: baked into the stage and always on until 1.1.2; one the rig has
-- already - the build's pick, an owner's fixture hung in the same place - is not doubled), in group order (the
-- roof's house lights last, so they are the ones Config.LightMaxFixtures leaves out). A show the build has no rig
-- for (the big-floor shows) has the empty house's - the roof's house lights - and its aim (MzbShowEntry)
local rigs = {}
local function laserAt(show, f)
    for _, u in ipairs(((Config.Lasers or {}).units or {})[show] or {}) do
        if math.abs(u[1] - f[1]) < 0.3 and math.abs(u[2] - f[2]) < 0.3 and math.abs(u[3] - f[3]) < 0.3 then return true end
    end
    return false
end

local function rigFor(show)
    if rigs[show] then return rigs[show] end
    local all = {}
    for _, f in ipairs(MzbShowEntry(Config.LightRig, show) or {}) do all[#all + 1] = f end
    for _, f in ipairs(MzbShowAs(Config.LightRigExtra, show) or {}) do all[#all + 1] = f end
    for _, s in ipairs(MzbShowAs(Config.StageLights, show) or {}) do
        local have = false
        for _, f in ipairs(all) do
            if math.abs(f[1] - s[1]) < 0.3 and math.abs(f[2] - s[2]) < 0.3 and math.abs(f[3] - s[3]) < 0.3 then
                have = true
                break
            end
        end
        if not have then all[#all + 1] = { s[1], s[2], s[3], s[4], s[5], s[6], 1 } end
    end
    local order = {}
    for i = #all, 1, -1 do
        if laserAt(show, all[i]) then table.remove(all, i) end         -- (1.5.0: the lasers' units are the lasers')
    end
    for i, f in ipairs(all) do order[i] = { f = f, k = (f[7] == 3 and 5 or f[7]) * 10000 + i } end
    table.sort(order, function(a, b) return a.k < b.k end)
    local rig = {}
    for i, o in ipairs(order) do rig[i] = o.f end
    rigs[show] = rig
    return rig
end

-- the show's ramp lights (Config.RampLights) and how many places along the ramp they take. Each one is aimed across
-- the ramp and Config.RampLightTilt degrees down, so its beam lands on the ramp (and whoever is on it) instead of
-- going up into the dark (the build aims them across and steeply up)
local ramps = {}
local function rampFor(show)
    if not ramps[show] then
        local list, n, out = (Config.RampLights or {})[show] or {}, 0, {}
        local tilt = math.rad(Config.RampLightTilt or 15.0)
        for i, f in ipairs(list) do
            n = math.max(n, f[7] or 0)
            local h = math.sqrt(f[4] * f[4] + f[5] * f[5])
            if h > 0.05 then
                out[i] = { f[1], f[2], f[3], f[4] / h * math.cos(tilt), f[5] / h * math.cos(tilt), -math.sin(tilt), f[7] }
            else
                out[i] = f
            end
        end
        ramps[show] = { out, n }
    end
    return ramps[show][1], ramps[show][2]
end

local function drawRamp(f, r, g, b, lvl, k)
    DrawSpotLight(f[1], f[2], f[3] + 0.05, f[4], f[5], f[6], r, g, b, Config.RampLightRange or 9.0,
        (Config.RampLightBrightness or 10.0) * lvl * k, 0.0, Config.RampLightCone or 28.0, 1.0)
    DrawLightWithRange(f[1], f[2], f[3] + 0.08, r, g, b, Config.RampLightGlowRange or 1.4,
        (Config.RampLightGlow or 6.0) * lvl * k)
end

CreateThread(function()
    while true do
        if drawHere and L and (L.on or L.ring or Config.RampLightIdle or (L.bars and L.bars.on)) then
            local show = GlobalState.mzbShow or Config.DefaultShow
            local rig = rigFor(show)
            local focus = MzbShowEntry(Config.LightFocus, show)
            if focus and #rig > 0 then
                local t = GetNetworkTime() / 1000.0
                beginBeams((MzbInterior()), t * (L.bpm or 120) / 60.0)
                BPM, COLORS = L.bpm or 120, L.colors or WHITE
                local beat, punch = t * BPM / 60.0, 1.0
                -- following the music: its beat count (run on from the last one heard; it never steps back, a
                -- correction holds it for a moment instead), its tempo, a dip between the hits and in quiet passages,
                -- and the picture's colours
                local now = GetGameTimer()
                local tempo, colour = following()
                if tempo and now - heard.at < 1500 then
                    BPM = heard.bpm
                    local b = heard.beat + (now - heard.at) * heard.bpm / 60000.0
                    if b < shownBeat and shownBeat - b < 0.5 then b = shownBeat end
                    shownBeat, beat = b, b
                    -- a hit: the rig jumps over full (hit) and falls back to a dip (punch) until the next one
                    local P, D, HT = FW.punch or 0.6, FW.dynamics or 0.25, FW.hit or 0.35
                    local since = (now - heard.kickAt) / 1000.0
                    punch = (1.0 - P + P * math.exp(-since * 7.0)) * (1.0 + HT * math.exp(-since * 14.0))
                        * (1.0 - D + D * heard.level)
                end
                if colour and heard.colors and now - heard.colorsAt < 1500 then COLORS = heard.colors end
                -- Auto: the section this player's music is in picks the effect, the movement, the level and the aim
                local _, _, auto = following()
                AUTO.on = auto and now - heard.at < 1500
                if AUTO.on then
                    local was = AUTO.state
                    autoState(now)
                    AUTO.mode, AUTO.move, AUTO.level, AUTO.focus = autoLook(now, beat)
                    if AUTO.state ~= was or not AUTO.told then
                        AUTO.told = true
                        SendNUIMessage({ type = 'followSection', section = AUTO.state })
                    end
                else
                    AUTO.told = false
                end
                -- the video's own picture: a flash in it flashes the rig (brighter, towards white), and a dark scene
                -- dims it
                if colour and now - heard.colorsAt < 1500 then
                    local V = FW.picture or 0.35
                    if heard.bright then punch = punch * (1.0 - V + V * heard.bright) end
                    local fl = math.exp(-(now - heard.flashAt) / 1000.0 * 9.0)
                    if fl > 0.02 then
                        punch = punch * (1.0 + (FW.flash or 0.8) * fl)
                        local w, white = (FW.flashWhite or 0.5) * fl, {}
                        for i, c in ipairs(COLORS) do
                            white[i] = { math.floor(c[1] + (255 - c[1]) * w), math.floor(c[2] + (255 - c[2]) * w),
                                         math.floor(c[3] + (255 - c[3]) * w) }
                        end
                        COLORS = white
                    end
                end
                local cone = Config.LightCone or { 9.0, 20.0, 14.0 }
                local gm = master()
                -- the ring lights, show or no show: the rig's own lights (Config.RingLights: they were baked into the
                -- rig and always on; now in the colours the build gave them, or the desk's ring colour, at its level),
                -- or for a show without them the washes over the ring / cage / stage, on their own aim
                local own = MzbShowAs(Config.RingLights, show)
                local ringGroup = (L.ring and not (own and #own > 0)) and (Config.RingLightGroup or 2) or nil
                if L.ring and own and #own > 0 then
                    local rc = L.ringColor
                    local scale = (Config.RingLightScale or 5.0) * (L.ringLevel or 1.0) * gm
                    if scale > 0.01 then
                        -- (and with them the glow off the video wall onto the stage: Config.StageGlow). While the
                        -- show lights are on, the rig's narrow beam heads among them are left to the desk, which
                        -- moves and colours the same heads: no still copy in the build's colours under them (1.5.0)
                        local heads = L.on and (Config.RingLightHeadCone or 22.0) or -1.0
                        for _, list in ipairs({ own, MzbShowAs(Config.StageGlow, show) or {} }) do
                            for _, f in ipairs(list) do
                                if list ~= own or f[12] > heads then
                                    local r, g, b = f[7], f[8], f[9]
                                    if rc then r, g, b = rc[1], rc[2], rc[3] end
                                    DrawSpotLight(f[1], f[2], f[3], f[4], f[5], f[6], r, g, b, f[11] + 4.0, f[10] * scale,
                                        0.0, f[12], Config.LightFalloff or 1.0)
                                end
                            end
                        end
                    end
                elseif ringGroup and gm > 0.01 then
                    local rc = L.ringColor or Config.RingLightColor or { 255, 244, 225 }
                    local rb = (Config.RingLightBrightness or 16.0) * (L.ringLevel or 1.0) * gm
                    for _, f in ipairs(rig) do
                        if f[7] == ringGroup then
                            spot(f, f[1] + f[4] * 30.0, f[2] + f[5] * 30.0, f[3] + f[6] * 30.0, rc[1], rc[2], rc[3],
                                rb, cone[f[7]] or 20.0, 2.0)
                        end
                    end
                end
                if L.on and gm > 0.01 then
                    local fixtures = {}
                    for _, f in ipairs(rig) do
                        if f[7] ~= ringGroup then fixtures[#fixtures + 1] = f end
                    end
                    local n = math.min(#fixtures, Config.LightMaxFixtures or 32)
                    local level = (L.intensity or 0.8) * (AUTO.on and AUTO.level or 1.0) * punch * gm
                    if L.fade and fadeFrom then
                        level = level * math.max(0.0, 1.0 - (now - fadeFrom) / ((tonumber(L.fade.dur) or 2.0) * 1000.0))
                    end
                    local bright = (Config.LightBrightness or 12.0) * level
                    local fl, mv = foci(), movement()
                    for i = 1, n do
                        local f = fixtures[i]
                        local r, g, b, lvl = look(i, n, t, beat)
                        if lvl > 0.01 then
                            local fo = fl[((i - 1) % #fl) + 1]
                            if fo == 'stage' and not focus.stage then fo = 'floor' end
                            local tx, ty, tz = aim(i, n, f, t, beat, focus, fo, mv)
                            spot(f, tx, ty, tz, r, g, b, bright * lvl, cone[f[7]] or (f[7] == 4 and Config.LightConeFloor) or 12.0,
                                4.0 * lvl * level)
                        end
                    end
                    -- the ramp lights: their place along the ramp is their place in the effect (both sides together)
                    local ramp, rn = rampFor(show)
                    if rn > 0 then
                        for _, f in ipairs(ramp) do
                            local r, g, b, lvl = look(f[7], rn, t, beat)
                            if lvl > 0.01 then drawRamp(f, r, g, b, lvl, level) end
                        end
                    end
                elseif Config.RampLightIdle then
                    -- show lights off: the ramp's lights stay on, steady, in their resting colour
                    local ramp, rn = rampFor(show)
                    local c = Config.RampLightIdle
                    if rn > 0 and gm > 0.01 then
                        for _, f in ipairs(ramp) do drawRamp(f, c[1], c[2], c[3], 1.0, (c[4] or 0.5) * gm) end
                    end
                end
                drawLasers(show, beat)
                drawBars(beat, now, show)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- ------------------------------------------------------------------ the desk (NUI)
-- what the desk shows for a show: its name, its kind's running order of looks (Config.LightPresetsByKind) and every
-- other look behind "All looks", whether it has a stage to aim at and ring lights
local function deskShow(show)
    local kind = (Config.ShowKinds or {})[show]
    local order = kind and (Config.LightPresetsByKind or {})[kind] or Config.LightPresetOrder or {}
    local presets, more, seen = {}, {}, {}
    for _, k in ipairs(order) do
        local p = Config.LightPresets[k]
        if p and not seen[k] and k ~= 'blackout' then seen[k] = true; presets[#presets + 1] = { id = k, label = p.label or k } end
    end
    for _, k in ipairs(Config.LightPresetOrder or {}) do
        local p = Config.LightPresets[k]
        if p and not seen[k] and k ~= 'blackout' then seen[k] = true; more[#more + 1] = { id = k, label = p.label or k } end
    end
    local focus = MzbShowEntry(Config.LightFocus, show)
    local hasStage, hasRing = focus ~= nil and focus.stage ~= nil, false
    for _, f in ipairs(MzbShowEntry(Config.LightRig, show) or {}) do
        if f[7] == (Config.RingLightGroup or 2) then hasRing = true end
    end
    if #(MzbShowAs(Config.RingLights, show) or {}) > 0 then hasRing = true end
    local label = (Config.ShowLabels or {})[show]
    return { show = label and label[1] or show, kind = kind and (Config.LightPresetsByKind[kind] or {}).label or nil,
             presets = presets, more = more, hasStage = hasStage, hasRing = hasRing,
             hasLasers = (Config.Lasers or {}).enabled ~= false and #(((Config.Lasers or {}).units or {})[show] or {}) > 0,
             gobos = LG.enabled ~= false and HAS_BEAMS and LB.enabled ~= false }
end

local function openDesk()
    deskOpen = true
    local colours = {}
    for name, c in pairs(Config.LightColors or {}) do colours[#colours + 1] = { name = name, rgb = c } end
    table.sort(colours, function(a, b) return a.name < b.name end)
    SetNuiFocus(true, true)
    local m = deskShow(GlobalState.mzbShow or Config.DefaultShow)
    m.type, m.state, m.colours = 'open', L, colours
    m.maxStrobe, m.follow = Config.LightMaxStrobeHz, FW.enabled ~= false and (Config.Music or {}).enabled == true
    -- (1.5.0) what the console's wing has on this server: the haze and the fog (Config.Fog), the bars
    m.fog, m.burst = (Config.Fog or {}).enabled ~= false, (Config.Fog or {}).burst or 8.0
    m.bars = LBR.enabled ~= false and Config.BarStrips ~= nil
    SendNUIMessage(m)
end

-- the show changes while the desk is open: its presets, its name and its aims change with it
AddStateBagChangeHandler('mzbShow', 'global', function(_, _, value)
    if not deskOpen then return end
    local m = deskShow(value or Config.DefaultShow)
    m.type = 'deskShow'
    SendNUIMessage(m)
end)

local function closeDesk()
    deskOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

RegisterNetEvent('mzb_arena:lightsDesk', openDesk)

-- (client/cues.lua) is the desk open on this screen
function MzbDeskOpen() return deskOpen end

RegisterNUICallback('lights', function(data, cb)
    TriggerServerEvent('mzb_arena:lights', data)
    cb('ok')
end)

RegisterNUICallback('preset', function(data, cb)
    if type(data) == 'table' and type(data.id) == 'string' then TriggerServerEvent('mzb_arena:lightsPreset', data.id) end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    closeDesk()
    cb('ok')
end)

-- a key for the desk: bound in the game's settings (Key Bindings > FiveM), or to Config.LightDeskKey for players who
-- have not picked one. The same as typing the command (the server checks who may open it)
RegisterCommand('arenadesk', function()
    if deskOpen then closeDesk() else ExecuteCommand(Config.LightCommand) end
end, false)
RegisterKeyMapping('arenadesk', 'Maze Bank Arena: open the desk', 'keyboard', Config.LightDeskKey or '')

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if deskOpen then SetNuiFocus(false, false) end
    if darkIdx and GetTimecycleModifierIndex() == darkIdx then ClearTimecycleModifier() end   -- (the bowl in the dark)
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. Config.LightCommand, 'Maze Bank Arena: the light desk (staff)',
        { { name = 'sub', help = 'none = open the desk | on | off | fade [s] | blackout | mode | move | color | bpm | intensity | focus | ring | house | follow | preset | status' } })
end)
