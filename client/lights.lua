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
    end
    return c[1], c[2], c[3], 1.0
end

-- where fixture f (i of n) aims at time t
local function aim(i, n, f, t, beat, focus)
    if f[7] == 2 and (L.focus or 'floor') == 'floor' then                 -- a wash keeps its own aim on the floor
        return f[1] + f[4] * 30.0, f[2] + f[5] * 30.0, f[3] + f[6] * 30.0
    end
    local mode = L.mode or 'static'
    local spread = Config.LightSpread or 6.0
    local a = (i / n) * math.pi * 2.0
    local tx, ty, tz
    if (L.focus or 'floor') == 'crowd' then                               -- out at the stands round the fixture
        local c = focus.floor
        local dx, dy = f[1] - c.x, f[2] - c.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1.0 then dx, dy, len = math.cos(a), math.sin(a), 1.0 end
        local r = (Config.LightCrowd and Config.LightCrowd.r) or 33.0
        local sw = 0.0
        if mode == 'sweep' then sw = math.sin(beat * math.pi * 0.5 + i) * 0.5 end
        local ca, sa = math.cos(sw), math.sin(sw)
        local ux, uy = (dx * ca - dy * sa) / len, (dx * sa + dy * ca) / len
        tx, ty = c.x + ux * r, c.y + uy * r
        tz = (Config.LightCrowd and Config.LightCrowd.z) or (c.z + 6.0)
        return tx, ty, tz
    end
    local p = (L.focus == 'stage' and focus.stage) or focus.floor
    tx, ty, tz = p.x + math.cos(a) * spread, p.y + math.sin(a) * spread, p.z - 1.0
    if mode == 'sweep' then
        local r = spread * 1.6
        local b = a + beat * math.pi * 0.5
        tx, ty = p.x + math.cos(b) * r, p.y + math.sin(b) * r
    elseif mode == 'ballyhoo' then
        tx = p.x + math.sin(t * 0.9 + i * 1.7) * spread * 2.0
        ty = p.y + math.cos(t * 1.1 + i * 2.3) * spread * 2.0
    end
    return tx, ty, tz
end

CreateThread(function()
    while true do
        if drawHere and L and L.on then
            local show = GlobalState.mzbShow or Config.DefaultShow
            local rig = (Config.LightRig or {})[show] or {}
            local focus = (Config.LightFocus or {})[show]
            if focus and #rig > 0 then
                local n = math.min(#rig, Config.LightMaxFixtures or 32)
                local t = GetNetworkTime() / 1000.0
                local beat = t * (L.bpm or 120) / 60.0
                local bright = (Config.LightBrightness or 12.0) * (L.intensity or 0.8)
                local cone = Config.LightCone or { 9.0, 20.0, 14.0 }
                for i = 1, n do
                    local f = rig[i]
                    local r, g, b, lvl = look(i, n, t, beat)
                    if lvl > 0.01 then
                        local tx, ty, tz = aim(i, n, f, t, beat, focus)
                        local dx, dy, dz = tx - f[1], ty - f[2], tz - f[3]
                        local len = math.sqrt(dx * dx + dy * dy + dz * dz)
                        if len > 0.1 then
                            DrawSpotLight(f[1], f[2], f[3], dx / len, dy / len, dz / len, r, g, b, len + 20.0,
                                bright * lvl, Config.LightHardness or 0.0, cone[f[7]] or 12.0, Config.LightFalloff or 1.0)
                            if Config.LightLensGlow then
                                DrawLightWithRange(f[1] + dx / len * 0.4, f[2] + dy / len * 0.4, f[3] + dz / len * 0.4,
                                    r, g, b, 1.6, 4.0 * lvl * (L.intensity or 0.8))
                            end
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
    SendNUIMessage({ type = 'open', state = L, presets = presets, colours = colours,
                     show = GlobalState.mzbShow or Config.DefaultShow, maxStrobe = Config.LightMaxStrobeHz })
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
        { { name = 'sub', help = 'none = open the desk | on | off | blackout | mode | color | bpm | intensity | focus | house | preset | status' } })
end)
