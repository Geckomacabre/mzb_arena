-- mzb_arena - client: the light desk's show (GlobalState.mzbLights, server/lights.lua).
-- The interior's baked lights can't change colour in game, so the show is drawn: a spot light per fixture of the
-- show's rig (Config.LightRig, written by the build: moving heads and beams that pan, washes with their own aim, the
-- house lights in the roof) every frame while you are in the bowl / concourse / tunnel / backstage. Every effect is a
-- function of the network clock, so every player sees the same flash at the same moment. The desk is the NUI in html/.

local L = GlobalState.mzbLights or Config.LightDefault
local deskOpen = false

AddStateBagChangeHandler('mzbLights', 'global', function(_, _, value)
    local before = (L and L.house) or 'show'
    L = value or Config.LightDefault
    if deskOpen then SendNUIMessage({ type = 'state', state = L }) end
    if (L.house or 'show') ~= before and MzbReapplyShow then MzbReapplyShow() end   -- client/main.lua
end)

-- ------------------------------------------------------------------ where the player is
local drawHere = false
local roomKeys = {}
for name in pairs(Config.LightRooms or {}) do roomKeys[GetHashKey(name)] = true end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local id = GetInteriorAtCoords(Config.InteriorProbe.x, Config.InteriorProbe.y, Config.InteriorProbe.z)
        drawHere = id ~= 0 and GetInteriorFromEntity(ped) == id and roomKeys[GetRoomKeyFromEntity(ped)] == true
        Wait(600)
    end
end)

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
    local cs = L.colors or { { 255, 255, 255 } }
    local c = cs[((i - 1) % #cs) + 1]
    local mode = L.mode or 'static'
    if mode == 'static' or mode == 'sweep' or mode == 'ballyhoo' then
        return c[1], c[2], c[3], 1.0
    elseif mode == 'chase' then
        local step = math.floor(beat * 2)
        local cc = cs[(step % #cs) + 1]
        return cc[1], cc[2], cc[3], ((i + step) % 4 == 0) and 1.0 or 0.0
    elseif mode == 'strobe' then
        local hz = math.min((L.bpm or 120) / 60.0 * 2.0, Config.LightMaxStrobeHz or 8.0)
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
    local fo = L.focus or 'floor'
    if type(fo) == 'table' then return #fo > 0 and fo or { 'floor' } end
    return { fo }
end

-- the movement: L.move, or the old sweep / ballyhoo modes that moved the beams themselves
local function movement()
    local mv = L.move or 'none'
    if mv == 'none' and (L.mode == 'sweep' or L.mode == 'ballyhoo') then mv = L.mode end
    return mv
end

local ARENA_U = vector3(math.cos(Config.ArenaFrame.ang), math.sin(Config.ArenaFrame.ang), 0.0)   -- along the arena
local ARENA_V = vector3(-ARENA_U.y, ARENA_U.x, 0.0)                                              -- across it

-- where fixture f (i of n) aims at time t
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
        elseif mv == 'cross' then sw = side * math.sin(beat * math.pi * 0.5) * 0.6 end
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
    end
    return tx, ty, tz
end

local function spot(f, tx, ty, tz, r, g, b, bright, cone, glow)
    local dx, dy, dz = tx - f[1], ty - f[2], tz - f[3]
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len <= 0.1 then return end
    DrawSpotLight(f[1], f[2], f[3], dx / len, dy / len, dz / len, r, g, b, len + 20.0, bright,
        Config.LightHardness or 0.0, cone, Config.LightFalloff or 1.0)
    if glow > 0.0 and Config.LightLensGlow then
        DrawLightWithRange(f[1] + dx / len * 0.4, f[2] + dy / len * 0.4, f[3] + dz / len * 0.4, r, g, b, 1.6, glow)
    end
end

-- the show's rig: the build's fixtures (Config.LightRig) and the owner's own (Config.LightRigExtra), in group order
-- (the roof's house lights last, so they are the ones Config.LightMaxFixtures leaves out)
local rigs = {}
local function rigFor(show)
    if rigs[show] then return rigs[show] end
    local all = {}
    for _, f in ipairs((Config.LightRig or {})[show] or {}) do all[#all + 1] = f end
    for _, f in ipairs((Config.LightRigExtra or {})[show] or {}) do all[#all + 1] = f end
    local order = {}
    for i, f in ipairs(all) do order[i] = { f = f, k = (f[7] == 3 and 5 or f[7]) * 10000 + i } end
    table.sort(order, function(a, b) return a.k < b.k end)
    local rig = {}
    for i, o in ipairs(order) do rig[i] = o.f end
    rigs[show] = rig
    return rig
end

CreateThread(function()
    while true do
        if drawHere and L and (L.on or L.ring) then
            local show = GlobalState.mzbShow or Config.DefaultShow
            local rig = rigFor(show)
            local focus = (Config.LightFocus or {})[show]
            if focus and #rig > 0 then
                local t = GetNetworkTime() / 1000.0
                local beat = t * (L.bpm or 120) / 60.0
                local cone = Config.LightCone or { 9.0, 20.0, 14.0 }
                -- the ring lights: the washes over the ring / cage / stage, white, on their own aim, show or no show
                local ringGroup = L.ring and (Config.RingLightGroup or 2) or nil
                if ringGroup then
                    local rc = Config.RingLightColor or { 255, 244, 225 }
                    local rb = Config.RingLightBrightness or 16.0
                    for _, f in ipairs(rig) do
                        if f[7] == ringGroup then
                            spot(f, f[1] + f[4] * 30.0, f[2] + f[5] * 30.0, f[3] + f[6] * 30.0, rc[1], rc[2], rc[3],
                                rb, cone[f[7]] or 20.0, 2.0)
                        end
                    end
                end
                if L.on then
                    local fixtures = {}
                    for _, f in ipairs(rig) do
                        if f[7] ~= ringGroup then fixtures[#fixtures + 1] = f end
                    end
                    local n = math.min(#fixtures, Config.LightMaxFixtures or 32)
                    local bright = (Config.LightBrightness or 12.0) * (L.intensity or 0.8)
                    local fl, mv = foci(), movement()
                    for i = 1, n do
                        local f = fixtures[i]
                        local r, g, b, lvl = look(i, n, t, beat)
                        if lvl > 0.01 then
                            local fo = fl[((i - 1) % #fl) + 1]
                            if fo == 'stage' and not focus.stage then fo = 'floor' end
                            local tx, ty, tz = aim(i, n, f, t, beat, focus, fo, mv)
                            spot(f, tx, ty, tz, r, g, b, bright * lvl, cone[f[7]] or (f[7] == 4 and Config.LightConeFloor) or 12.0,
                                4.0 * lvl * (L.intensity or 0.8))
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- ------------------------------------------------------------------ the desk (NUI)
local function openDesk()
    deskOpen = true
    local presets = {}
    for _, k in ipairs(Config.LightPresetOrder or {}) do
        local p = Config.LightPresets[k]
        if p then presets[#presets + 1] = { id = k, label = p.label or k } end
    end
    local colours = {}
    for name, c in pairs(Config.LightColors or {}) do colours[#colours + 1] = { name = name, rgb = c } end
    table.sort(colours, function(a, b) return a.name < b.name end)
    SetNuiFocus(true, true)
    local show = GlobalState.mzbShow or Config.DefaultShow
    local hasStage, hasRing = (Config.LightFocus or {})[show] and (Config.LightFocus or {})[show].stage ~= nil, false
    for _, f in ipairs((Config.LightRig or {})[show] or {}) do
        if f[7] == (Config.RingLightGroup or 2) then hasRing = true end
    end
    SendNUIMessage({ type = 'open', state = L, presets = presets, colours = colours, show = show,
                     maxStrobe = Config.LightMaxStrobeHz, hasStage = hasStage, hasRing = hasRing })
end

local function closeDesk()
    deskOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

RegisterNetEvent('mzb_arena:lightsDesk', openDesk)

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

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and deskOpen then SetNuiFocus(false, false) end
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. Config.LightCommand, 'Maze Bank Arena: the light desk (staff)',
        { { name = 'sub', help = 'none = open the desk | on | off | blackout | mode | move | color | bpm | intensity | focus | ring | house | preset | status' } })
end)
