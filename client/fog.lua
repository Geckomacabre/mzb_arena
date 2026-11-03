-- mzb_arena - client: the atmosphere (Config.Fog; the desk's Haze and Fog, /arenalights haze | fog).
-- Rockstar's own dry ice from the nightclubs (the particle asset scr_ba_club, as AM_MP_NIGHTCLUB runs it): the haze
-- is their clouds (scr_ba_club_smoke) hung over the floor and up the bowl, grown with their FILL to the desk's level
-- and faded with their FADE when it goes to 0 - what makes the beams show in the air; the fog machines are the clubs'
-- machines (scr_ba_club_smoke_machine, at their own scale 5) at the stage's flame units, blowing towards the floor,
-- on while the desk has them on (at its output), or for a burst. Each player's own game draws them while near.
-- (1.5.0) Every call is local only (LOCAL, the last argument; the club's own script passes the same): left off, the
-- game sends each start, colour, FILL / FADE and stop to every player as a network event - the clouds' 30 a tenth of
-- a second filled its event pool ("Ran out of rage::netGameEvent pool space") and crashed the desk's player, and the
-- others got everyone's clouds on top of their own. FILL and FADE go to the game only when they change, and the
-- output scales the machines that are on instead of starting them again.

local FG = Config.Fog or {}
if FG.enabled == false then return end

local ASSET = 'scr_ba_club'
local LOCAL = true                          -- the looped effects' localOnly: this player's game only
local clouds, machines = {}, {}             -- looped effects that are on
local fill, fade = 0.0, 0.0                 -- the clouds' FILL and FADE now
local sentFill, sentFade = nil, nil         -- what the clouds were last given
local machinesFor, machinesK = nil, nil     -- the show the machines were started for, and their output
local burstUntil, burstN = 0, nil

local function near()
    return #(GetEntityCoords(PlayerPedId()) - Config.Screens.origin) < (FG.range or 160.0)
end

local function loaded()
    if HasNamedPtfxAssetLoaded(ASSET) then return true end
    RequestNamedPtfxAsset(ASSET)
    return false
end

-- a place in the arena's frame (m along its long axis, across, over the event floor) -> the world
local function world(u, v, h)
    local F = Config.ArenaFrame
    local c, s = math.cos(F.ang), math.sin(F.ang)
    return F.x + u * c - v * s, F.y + u * s + v * c, F.z + h
end

local function stopAll(list)
    for i = #list, 1, -1 do
        StopParticleFxLooped(list[i], LOCAL)
        list[i] = nil
    end
end

local function startClouds()
    local t = FG.tint or { 0.82, 0.84, 0.88 }
    for _, c in ipairs(FG.clouds or {}) do
        local x, y, z = world(c[1], c[2], c[3])
        UseParticleFxAsset(ASSET)
        local h = StartParticleFxLoopedAtCoord('scr_ba_club_smoke', x, y, z, 0.0, 0.0, 0.0, c[4] or 1.0, false, false, false, LOCAL)
        if h and h ~= 0 then
            SetParticleFxLoopedColour(h, t[1], t[2], t[3], LOCAL)
            clouds[#clouds + 1] = h
        end
    end
    sentFill, sentFade = nil, nil
end

-- a FILL or FADE worth sending: the first, a step of half a percent, or the value it was going to
local function worth(v, sent, goal)
    return sent == nil or math.abs(v - sent) >= 0.005 or (v == goal and v ~= sent)
end

-- the machines stand at the show's flame units (the DJ show has the concert's), each turned to the floor's middle
local function startMachines(show, k)
    local units = MzbShowAs((Config.Pyro or {}).units, show) or {}
    local F = Config.ArenaFrame
    for _, p in ipairs(units[FG.machineFrom or 'flames'] or {}) do
        local yaw = math.deg(math.atan(F.y - p.y, F.x - p.x)) - 90.0 + (FG.yaw or 0.0)
        UseParticleFxAsset(ASSET)
        local h = StartParticleFxLoopedAtCoord('scr_ba_club_smoke_machine', p.x, p.y, p.z, 0.0, 0.0, yaw,
            (FG.machineScale or 5.0) * k, false, false, false, LOCAL)
        if h and h ~= 0 then machines[#machines + 1] = h end
    end
end

CreateThread(function()
    local first = GlobalState.mzbLights or {}
    burstN = type(first.fogBurst) == 'table' and first.fogBurst.n or 0      -- (a burst before we came is not ours)
    local last = GetGameTimer()
    while true do
        local now = GetGameTimer()
        local dt = math.min(1.0, (now - last) / 1000.0)
        last = now
        local L = GlobalState.mzbLights or {}
        local here = near()
        -- the haze: grow (or thin) to the desk's level, fade out and go when it is 0 (or we left)
        local target = here and math.max(0.0, math.min(1.0, tonumber(L.haze) or 0.0)) or 0.0
        if target > 0.001 then
            if #clouds == 0 and loaded() then
                startClouds()
                fill, fade = 0.0, 0.0
            end
            fade = 0.0
            local step = dt / (FG.fill or 10.0)
            fill = fill < target and math.min(target, fill + step) or math.max(target, fill - step)
        elseif #clouds > 0 then
            fade = math.min(1.0, fade + dt / (FG.fade or 8.0))
            if fade >= 1.0 or not here then
                stopAll(clouds)
                fill, fade = 0.0, 0.0
            end
        end
        if #clouds > 0 then
            local fillNew = worth(fill, sentFill, target)
            local fadeNew = worth(fade, sentFade, target > 0.001 and 0.0 or 1.0)
            for _, h in ipairs(clouds) do
                if fillNew then SetParticleFxLoopedEvolution(h, 'FILL', fill, LOCAL) end
                if fadeNew then SetParticleFxLoopedEvolution(h, 'FADE', fade, LOCAL) end
            end
            if fillNew then sentFill = fill end
            if fadeNew then sentFade = fade end
        end
        -- the machines: on at the desk's output, or flat out for a burst
        local fb = L.fogBurst
        if type(fb) == 'table' and fb.n ~= burstN then
            burstN = fb.n
            burstUntil = now + math.floor((tonumber(fb.dur) or FG.burst or 8.0) * 1000)
        end
        local fog = type(L.fog) == 'table' and L.fog or {}
        local bursting = now < burstUntil
        local show = tostring(GlobalState.mzbShow or Config.DefaultShow)
        if here and (fog.on == true or bursting) then
            local k = bursting and 1.0 or math.max(0.05, math.min(1.0, tonumber(fog.output) or 0.6))
            if machinesFor ~= show and loaded() then
                stopAll(machines)
                startMachines(show, k)
                machinesFor, machinesK = show, k
            elseif machinesFor == show and math.abs(k - machinesK) >= 0.01 then
                for _, h in ipairs(machines) do SetParticleFxLoopedScale(h, (FG.machineScale or 5.0) * k) end
                machinesK = k
            end
        elseif machinesFor ~= nil then
            stopAll(machines)
            machinesFor, machinesK = nil, nil
        end
        Wait((#clouds > 0 or #machines > 0) and 100 or 400)
    end
end)

-- (the tests, /arenalights status) what is drawn here
function MzbFogNow()
    return { clouds = #clouds, machines = #machines, fill = fill, fade = fade }
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopAll(clouds)
    stopAll(machines)
end)
