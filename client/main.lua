-- mzb_arena - client: the interior's show (entity sets), the loading dock's roller shutters, the vanilla clean-up
local interior = 0

local function arenaInterior()
    if interior == 0 or not IsValidInterior(interior) then
        interior = GetInteriorAtCoords(Config.InteriorProbe.x, Config.InteriorProbe.y, Config.InteriorProbe.z)
    end
    return interior
end

-- ------------------------------------------------------------------ vanilla clean-up
-- Rockstar's Fame or Shame lobby (bob74_ipl requests it) stands where our concourse is; the resource streams empty
-- copies of both ymaps, this is the belt to those braces. The Arena War banners on the outside of the building
-- (xs_arena_banners_ipl: the big ARENA WAR banner and three cloths) go too - removing the IPL takes its collision
-- with it. Checked every few seconds: a map or IPL loader may request them after we start.
CreateThread(function()
    local ipls = { 'sp1_10_real_interior', 'sp1_10_real_interior_lod', 'xs_arena_banners_ipl' }
    while true do
        for _, ipl in ipairs(ipls) do
            if IsIplActive(ipl) then RemoveIpl(ipl) end
        end
        Wait(5000)
    end
end)

-- ------------------------------------------------------------------ shows (interior entity sets)
local managed = {}
for _, sets in pairs(Config.Shows) do
    for _, s in ipairs(sets) do managed[s] = true end
end
for _, s in pairs(Config.HouseSets or {}) do managed[s] = true end

local function applyShow(name)
    local sets = Config.Shows[name]
    if not sets then return end
    local id = arenaInterior()
    if id == 0 then return end
    local on = {}
    for _, s in ipairs(sets) do on[s] = true end
    -- the light desk's house buttons (client/lights.lua): the show's own house light set, or full / dimmed / off
    local house = (GlobalState.mzbLights or {}).house or 'show'
    local hs = Config.HouseSets or {}
    if house ~= 'show' then
        for _, s in pairs(hs) do on[s] = nil end
        if hs[house] then on[hs[house]] = true end
    end
    for s in pairs(managed) do
        if on[s] then
            if not IsInteriorEntitySetActive(id, s) then ActivateInteriorEntitySet(id, s) end
        elseif IsInteriorEntitySetActive(id, s) then
            DeactivateInteriorEntitySet(id, s)
        end
    end
    RefreshInterior(id)
end

AddStateBagChangeHandler('mzbShow', 'global', function(_, _, value)
    Wait(0)
    applyShow(value)
end)

-- (client/lights.lua: the desk's house setting changed)
function MzbReapplyShow()
    Wait(0)
    applyShow(GlobalState.mzbShow or Config.DefaultShow)
end

-- chat suggestions for the commands (the chat resource shows them as you type)
CreateThread(function()
    Wait(1000)
    local names = {}
    for k in pairs(Config.Shows) do names[#names + 1] = k end
    table.sort(names)
    if Config.QuickCommand then
        TriggerEvent('chat:addSuggestion', '/' .. Config.QuickCommand, 'Maze Bank Arena: switch the show (staff)',
            { { name = 'show', help = table.concat(names, ' | ') .. '  (or list, status)' } })
    end
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Maze Bank Arena (staff)',
        { { name = 'show | dock | status', help = 'show <name>  |  dock <a|b|c|all> <open|close|toggle>  |  status' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Config.QuickCommand then TriggerEvent('chat:removeSuggestion', '/' .. Config.QuickCommand) end
    TriggerEvent('chat:removeSuggestion', '/' .. Config.Command)
end)

-- the interior streams in and out: re-apply the show whenever it (re)appears
CreateThread(function()
    local last = 0
    while true do
        local id = GetInteriorAtCoords(Config.InteriorProbe.x, Config.InteriorProbe.y, Config.InteriorProbe.z)
        if id ~= 0 and IsInteriorReady(id) and id ~= last then
            interior = id
            last = id
            applyShow(GlobalState.mzbShow or Config.DefaultShow)
        elseif id == 0 then
            last = 0
        end
        Wait(2000)
    end
end)

-- ------------------------------------------------------------------ the dock's roller shutters
local shutters = {}                -- door name -> { bands = {entity...}, offset = 0..H, target = 0|H }
local H = Config.ShutterBands * Config.ShutterBandH

local function loadModel(m)
    local h = joaat(m)
    RequestModel(h)
    local t = GetGameTimer() + 10000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return h
end

local function placeBand(d, e, i, offset)
    local z = d.z + (i - 1) * Config.ShutterBandH + offset
    local x = d.x + d.nx * Config.ShutterOut
    local y = d.y + d.ny * Config.ShutterOut
    SetEntityCoordsNoOffset(e, x, y, z, false, false, false)
    -- a band shows while its middle is below the lintel: it "rolls" into the head as the shutter opens
    local visible = (z + Config.ShutterBandH * 0.5) < d.top
    SetEntityVisible(e, visible, false)
    SetEntityCollision(e, visible, visible)
end

local function spawnShutters()
    local band, bottom = loadModel('mzb_dock_shutter_band'), loadModel('mzb_dock_shutter_bottom')
    local open = GlobalState.mzbDock or {}
    for name, d in pairs(Config.DockDoors) do
        if not shutters[name] then
            local heading = math.deg(math.atan(d.nx, -d.ny))       -- the band's +x along the opening
            local s = { bands = {}, offset = open[name] and H or 0.0 }
            s.target = s.offset
            for i = 1, Config.ShutterBands do
                local e = CreateObjectNoOffset(i == 1 and bottom or band, d.x, d.y, d.z, false, false, false)
                SetEntityHeading(e, heading)
                FreezeEntityPosition(e, true)
                SetEntityLodDist(e, 200)
                s.bands[i] = e
                placeBand(d, e, i, s.offset)
            end
            shutters[name] = s
        end
    end
    SetModelAsNoLongerNeeded(band)
    SetModelAsNoLongerNeeded(bottom)
end

local function deleteShutters()
    for _, s in pairs(shutters) do
        for _, e in ipairs(s.bands) do
            if DoesEntityExist(e) then DeleteEntity(e) end
        end
    end
    shutters = {}
end

AddStateBagChangeHandler('mzbDock', 'global', function(_, _, value)
    for name, s in pairs(shutters) do
        s.target = (value and value[name]) and H or 0.0
    end
end)

-- spawn near the arena, animate towards the target, despawn far away
CreateThread(function()
    local near = false
    while true do
        local p = GetEntityCoords(PlayerPedId())
        local dist = #(p - vector3(-376.0, -1878.7, 21.0))
        if dist < 250.0 and not near then
            near = true
            spawnShutters()
        elseif dist > 300.0 and near then
            near = false
            deleteShutters()
        end
        local moving = false
        if near then
            local step = H / (Config.ShutterSeconds * 30.0)
            for name, s in pairs(shutters) do
                if math.abs(s.offset - s.target) > 1e-3 then
                    moving = true
                    if s.offset < s.target then s.offset = math.min(s.target, s.offset + step)
                    else s.offset = math.max(s.target, s.offset - step) end
                    local d = Config.DockDoors[name]
                    for i, e in ipairs(s.bands) do placeBand(d, e, i, s.offset) end
                end
            end
        end
        Wait(moving and 33 or 500)
    end
end)

-- the shutters' controls: [E] at each door, inside or out, on foot or at the wheel (Config.DockButtons; the server
-- checks the distance, Config.DockAccess and a cooldown). Until 2026-09-29 only the staff command moved them.
if Config.DockButtons then
    CreateThread(function()
        while true do
            local wait = 500
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local inCar = IsPedInAnyVehicle(ped, false)
            local reach = inCar and Config.DockReachVehicle or Config.DockReach
            local best, bestD
            for name, d in pairs(Config.DockDoors) do
                local dz = p.z - d.z
                if dz > -1.5 and dz < 4.0 then
                    local dist = #(vector2(p.x, p.y) - vector2(d.x, d.y))
                    if dist < reach and (not bestD or dist < bestD) then best, bestD = name, dist end
                end
            end
            if best then
                wait = 0
                local open = (GlobalState.mzbDock or {})[best]
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(('~INPUT_PICKUP~ %s the roller door'):format(open and 'Close' or 'Open'))
                EndTextCommandDisplayHelp(0, false, false, -1)
                if IsControlJustReleased(0, 38) then            -- E, on foot and at the wheel
                    TriggerServerEvent('mzb_arena:dockButton', best)
                    Wait(750)
                end
            end
            Wait(wait)
        end
    end)
end

-- ------------------------------------------------------------------ the walk-through curtains
-- The titantron's entrance and the Gorilla's door to the stage stair: rows of velour strips (scripted props, no
-- collision), each strip two pieces hinged together (a short top piece on the track, a longer bottom piece hung from
-- its lower edge). A ped walking through pushes the piece at its height out of the way - mostly the bottom one, which
-- drags the top along through the hinge - the strip slides off once pushed too far, then both pieces sway back with a
-- lag between them (cloth, not a board); the strip also swings aside, away from the body's middle. Config.Curtains /
-- CurtainSwing come from the build (shared/generated.lua, arena_build/ar_curtain.py - the Python runs the same maths).
local curtains = {}                -- name -> { { e1, e2, pivot, a1, v1, a2, v2, b, vb } ... }
local CS = Config.CurtainSwing

local function curtainHeading(c)
    return c.heading or Config.CurtainHeading
end

local function curtainAxes(c)
    local h = math.rad(curtainHeading(c))
    return vector3(math.cos(h), math.sin(h), 0.0), vector3(-math.sin(h), math.cos(h), 0.0)   -- along, through
end

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

local function deleteCurtains()
    for _, strips in pairs(curtains) do
        for _, s in ipairs(strips) do
            if DoesEntityExist(s.e1) then DeleteEntity(s.e1) end
            if DoesEntityExist(s.e2) then DeleteEntity(s.e2) end
        end
    end
    curtains = {}
end

local function curtainPiece(model, p, id, heading)
    local e = CreateObjectNoOffset(model, p.x, p.y, p.z, false, false, false)
    SetEntityCollision(e, false, false)
    FreezeEntityPosition(e, true)
    SetEntityRotation(e, 0.0, 0.0, heading, 2, false)
    SetEntityLodDist(e, 120)
    ForceRoomForEntity(e, id, `bowl`)
    return e
end

local function spawnCurtains()
    local id = arenaInterior()
    if id == 0 or not IsInteriorReady(id) then return false end
    for name, c in pairs(Config.Curtains) do
        if not curtains[name] then
            local ax = curtainAxes(c)
            local heading = curtainHeading(c)
            local tops = { loadModel(c.tops[1]), loadModel(c.tops[2]) }
            local lows = { loadModel(c.lows[1]), loadModel(c.lows[2]) }
            local strips = {}
            for i = 1, c.strips do
                local x = -c.halfWidth + (i - 0.5) * 2.0 * c.halfWidth / c.strips
                local p = c.top + ax * x
                local k = (i % 2) + 1
                strips[i] = { e1 = curtainPiece(tops[k], p, id, heading), e2 = curtainPiece(lows[k], p - vector3(0.0, 0.0, c.l1), id, heading),
                              pivot = p, a1 = 0.0, v1 = 0.0, a2 = 0.0, v2 = 0.0, b = 0.0, vb = 0.0 }
            end
            curtains[name] = strips
            for k = 1, 2 do
                SetModelAsNoLongerNeeded(tops[k])
                SetModelAsNoLongerNeeded(lows[k])
            end
        end
    end
    return true
end

local function pushStrip(c, s, lx, ly, pz, vy, dt)
    local L1, R = c.l1, CS.body
    local hb = math.max(0.3, math.min(c.drop - 0.1, -pz + 0.45))   -- where the body presses: hips to knees
    local r = hb - L1
    local sy = r <= 0 and hb * math.sin(s.a1) or L1 * math.sin(s.a1) + r * math.sin(s.a2)
    if math.abs(sy - ly) >= R then return end              -- not touching this strip
    local d
    if math.abs(vy) > 0.3 then d = vy > 0 and 1.0 or -1.0 else d = sy >= ly and 1.0 or -1.0 end
    local yt = ly + d * R                                  -- push it out ahead of the body ...
    local side = lx >= 0 and -1.0 or 1.0                   -- ... and aside, away from the body's middle
    local push = 1.0 - math.min(1.0, math.abs(lx) / (c.stripWidth * 0.5 + R))
    s.vb = s.vb + side * (1.5 + math.abs(vy)) * push * dt * 3.0
    local s1, s2 = math.sin(CS.push1), math.sin(CS.push2)
    if r <= 0 then                                         -- the body is at the top piece's height
        local need = yt / hb
        if math.abs(need) > s1 then return end             -- too far: it slips off
        s.a1, s.v1 = math.asin(need), clamp(vy / hb, -3.0, 3.0)
        return
    end
    local need2 = (yt - L1 * math.sin(s.a1)) / r
    if math.abs(need2) > s2 then                           -- the bottom piece at its limit: the top takes the rest
        local b2 = need2 > 0 and s2 or -s2
        local need1 = (yt - r * b2) / L1
        if math.abs(need1) > s1 then return end            -- too far: it slides over the shoulder and falls back
        s.a1, s.v1 = math.asin(need1), clamp(vy / hb, -3.0, 3.0)
        s.a2 = math.asin(b2)
    else
        s.a2 = math.asin(need2)
    end
    s.v2 = clamp(vy / r, -4.0, 4.0)
end

local function stepCurtains(dt)
    local peds = {}
    local centre = Config.Curtains.stage.top
    for _, ped in ipairs(GetGamePool('CPed')) do
        local p = GetEntityCoords(ped)
        if #(p - centre) < 16.0 then peds[#peds + 1] = { p = p, v = GetEntityVelocity(ped) } end
    end
    for name, strips in pairs(curtains) do
        local c = Config.Curtains[name]
        local ax, ay = curtainAxes(c)
        local heading = curtainHeading(c)
        local reach = c.stripWidth * 0.5 + CS.body
        for _, s in ipairs(strips) do
            for _, pd in ipairs(peds) do
                local r = pd.p - s.pivot
                local lx = r.x * ax.x + r.y * ax.y                 -- the ped along the curtain, from this strip
                local ly = r.x * ay.x + r.y * ay.y                 -- through it
                if r.z < 0.3 and r.z > -(c.drop + 0.3) and math.abs(lx) <= reach then
                    pushStrip(c, s, lx, ly, r.z, pd.v.x * ay.x + pd.v.y * ay.y, dt)
                end
            end
            s.v1 = s.v1 + (-CS.k1 * s.a1 - CS.d1 * s.v1 + CS.c1 * (s.a2 - s.a1)) * dt
            s.v2 = s.v2 + (-CS.k2 * s.a2 - CS.d2 * s.v2 - CS.c2 * (s.a2 - s.a1)) * dt
            s.vb = s.vb + (-CS.kb * s.b - CS.db * s.vb) * dt
            s.a1 = clamp(s.a1 + s.v1 * dt, -CS.amax, CS.amax)
            s.a2 = clamp(s.a2 + s.v2 * dt, -CS.amax, CS.amax)
            s.b = clamp(s.b + s.vb * dt, -CS.bmax, CS.bmax)
            -- pitch about a piece's own x swings its bottom through the curtain (+y), roll about its y swings it along
            -- the curtain (a positive roll takes the bottom to -x); the bottom piece hangs from the top one's lower edge
            SetEntityRotation(s.e1, math.deg(s.a1), -math.deg(s.b), heading, 2, false)
            local hinge = GetOffsetFromEntityInWorldCoords(s.e1, 0.0, 0.0, -c.l1)
            SetEntityCoordsNoOffset(s.e2, hinge.x, hinge.y, hinge.z, false, false, false)
            SetEntityRotation(s.e2, math.deg(s.a2), -math.deg(s.b), heading, 2, false)
        end
    end
end

CreateThread(function()
    local spawned = false
    while true do
        local show = GlobalState.mzbShow or Config.DefaultShow
        local dist = #(GetEntityCoords(PlayerPedId()) - Config.Curtains.stage.top)
        if Config.CurtainShows[show] and dist < 90.0 then
            if not spawned then spawned = spawnCurtains() end
            if spawned and dist < 30.0 then
                stepCurtains(math.min(GetFrameTime(), 0.05))
                Wait(0)
            else
                Wait(250)
            end
        else
            if spawned then
                deleteCurtains()
                spawned = false
            end
            Wait(1000)
        end
    end
end)

-- ------------------------------------------------------------------ the toilet stall doors
-- Every stall's door is a scripted prop (Config.StallDoors from the build, arena_build/ar_stalls.py: its hinge, the
-- shut leaf's heading, which side is inside the stall, its width): no collision - a body walking into it pushes it
-- open ahead of it, in or out (it swings both ways: a ped cannot pull a handle), and its closer (a damped spring,
-- Config.StallSwing) swings it shut behind them. Doors spawn within 45 m of the player and move within 20 m; the
-- Python twin (ar_stalls.push / step) runs the same maths.
local stalls = {}                  -- index into Config.StallDoors -> { e, a, v }
local SW = Config.StallSwing

local function deleteStalls()
    for _, st in pairs(stalls) do
        if DoesEntityExist(st.e) then DeleteEntity(st.e) end
    end
    stalls = {}
end

local function stallYaw(d, a)
    return d.yaw + d.s * math.deg(a)
end

local function spawnStall(i, d, id)
    local h = loadModel(d.m)
    local e = CreateObjectNoOffset(h, d.x, d.y, d.z, false, false, false)
    SetEntityCollision(e, false, false)
    FreezeEntityPosition(e, true)
    SetEntityRotation(e, 0.0, 0.0, d.yaw, 2, false)
    SetEntityLodDist(e, 60)
    ForceRoomForEntity(e, id, GetHashKey(d.room))
    SetModelAsNoLongerNeeded(h)
    stalls[i] = { e = e, a = 0.0, v = 0.0 }
end

local function pushStall(d, st, peds, dt)
    local R, w = SW.body, d.w
    local h = math.rad(d.yaw)
    local ex, ey = vector2(math.cos(h), math.sin(h)), vector2(-math.sin(h) * d.s, math.cos(h) * d.s)
    local a0 = st.a
    local a = a0
    for _, pd in ipairs(peds) do
        local dz = pd.p.z - d.z
        if dz > -0.2 and dz < 2.2 then
            local rx, ry = pd.p.x - d.x, pd.p.y - d.y
            local lx, ly = rx * ex.x + ry * ex.y, rx * ey.x + ry * ey.y      -- along the shut leaf, into the stall
            local r = math.sqrt(lx * lx + ly * ly)
            if r >= 0.05 and r <= w + R then
                local phi = math.atan(ly, lx)
                if phi >= -(d.o or SW.out_max) - 0.6 and phi <= (d.i or SW.in_max) + 0.6 then  -- not behind the hinge
                    local half = math.asin(math.min(1.0, R / r))
                    if math.abs(phi - a) < half then                     -- the leaf is in this body
                        local vin = pd.v.x * ey.x + pd.v.y * ey.y
                        local inward
                        if math.abs(phi - a) < half * 0.5 and math.abs(vin) > 0.1 then
                            inward = vin > 0                             -- in the doorway: the way it walks
                        else
                            inward = phi < a                             -- from outside the leaf's line: into the stall
                        end
                        a = inward and (phi + half) or (phi - half)
                    end
                end
            end
        end
    end
    a = math.max(-(d.o or SW.out_max), math.min(d.i or SW.in_max, a))   -- its own stops: clear of the walls
    if a ~= a0 and dt > 0 then
        st.v = math.max(-4.0, math.min(4.0, (a - a0) / dt))
    end
    st.a = a
end

local function stepStall(d, st, peds, dt)
    local before = st.a
    st.v = st.v + (-SW.k * st.a - SW.c * st.v) * dt
    st.a = st.a + st.v * dt
    local imax, omax = d.i or SW.in_max, d.o or SW.out_max
    if st.a > imax or st.a < -omax then
        st.a, st.v = math.max(-omax, math.min(imax, st.a)), 0.0
    end
    pushStall(d, st, peds, dt)
    if math.abs(st.a) < 0.0005 and math.abs(st.v) < 0.001 then st.a, st.v = 0.0, 0.0 end
    if math.abs(st.a - before) > 0.00005 then
        SetEntityRotation(st.e, 0.0, 0.0, stallYaw(d, st.a), 2, false)
    end
end

-- spawn / despawn by distance (twice a second)
CreateThread(function()
    while true do
        local id = arenaInterior()
        local p = GetEntityCoords(PlayerPedId())
        if id ~= 0 and IsInteriorReady(id) then
            for i, d in ipairs(Config.StallDoors) do
                local dist = #(p - vector3(d.x, d.y, d.z))
                if dist < 45.0 and not stalls[i] then
                    spawnStall(i, d, id)
                elseif dist > 60.0 and stalls[i] then
                    if DoesEntityExist(stalls[i].e) then DeleteEntity(stalls[i].e) end
                    stalls[i] = nil
                end
            end
        elseif next(stalls) then
            deleteStalls()
        end
        Wait(500)
    end
end)

-- swing the ones near the player every frame (a sleep when none are near)
CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local near = {}
        for i, st in pairs(stalls) do
            local d = Config.StallDoors[i]
            if math.abs(me.x - d.x) < 20.0 and math.abs(me.y - d.y) < 20.0 and math.abs(me.z - d.z) < 6.0 then
                near[#near + 1] = i
            end
        end
        if #near == 0 then
            Wait(300)
        else
            local peds = {}
            for _, ped in ipairs(GetGamePool('CPed')) do
                local p = GetEntityCoords(ped)
                if #(p - me) < 24.0 then peds[#peds + 1] = { p = p, v = GetEntityVelocity(ped) } end
            end
            local dt = math.min(GetFrameTime(), 0.05)
            for _, i in ipairs(near) do
                stepStall(Config.StallDoors[i], stalls[i], peds, dt)
            end
            Wait(0)
        end
    end
end)

-- ------------------------------------------------------------------ the video screens (pmms / TV scripts)
-- One model per show holds every screen of that show - the titantron and its panels, the LED walls, the side screens
-- and the centre-hung board's four faces - all on the one render target Config.Screens.renderTarget: a media script
-- plays on it and every screen shows the same picture from one source. The faces are clear until something plays, so
-- the show's own graphics show through. Spawned at the arena's centre (a local object a script can find by model),
-- swapped when the show changes. Build: arena_build/ar_screens.py.
local screen = nil                 -- { e, model }

local function deleteScreens()
    if screen and DoesEntityExist(screen.e) then DeleteEntity(screen.e) end
    screen = nil
end

CreateThread(function()
    while true do
        local show = GlobalState.mzbShow or Config.DefaultShow
        local want = Config.Screens.models[show]
        local id = arenaInterior()
        local near = #(GetEntityCoords(PlayerPedId()) - Config.Screens.origin) < 250.0
        if want and near and id ~= 0 and IsInteriorReady(id) then
            if not screen or screen.model ~= want then
                deleteScreens()
                local h = loadModel(want)
                local o = Config.Screens.origin
                local e = CreateObjectNoOffset(h, o.x, o.y, o.z, false, false, false)
                SetEntityCollision(e, false, false)
                FreezeEntityPosition(e, true)
                SetEntityRotation(e, 0.0, 0.0, Config.Screens.heading, 2, false)
                SetEntityLodDist(e, 500)
                ForceRoomForEntity(e, id, `bowl`)
                SetModelAsNoLongerNeeded(h)
                screen = { e = e, model = want }
            end
        elseif screen then
            deleteScreens()
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        deleteShutters()
        deleteCurtains()
        deleteStalls()
        deleteScreens()
    end
end)

-- ------------------------------------------------------------------ dev: /arenainfo (where you are, which room)
-- Prints to chat and F8: the world position, the arena's own (u, v, height over the event floor), the interior and
-- the room the game has you in (by name) - send it with a screenshot when something looks or feels wrong.
RegisterCommand('arenainfo', function()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local id = GetInteriorFromEntity(ped)
    local key = GetRoomKeyFromEntity(ped)
    local name = (key == 0) and 'outside' or ('key ' .. key)
    for _, r in ipairs(Config.Rooms or {}) do
        if GetHashKey(r) == key then name = r end
    end
    local f = Config.ArenaFrame or { x = 0.0, y = 0.0, z = 0.0, ang = 0.0 }
    local dx, dy = p.x - f.x, p.y - f.y
    local c, s = math.cos(f.ang), math.sin(f.ang)
    local u, v = dx * c + dy * s, -dx * s + dy * c
    local msg = ('pos %.2f %.2f %.2f (heading %.0f) | arena u %.2f v %.2f h %.2f | interior %d (arena %d, ready %s) | room %s | show %s')
        :format(p.x, p.y, p.z, GetEntityHeading(ped), u, v, p.z - f.z, id, arenaInterior(),
            tostring(IsInteriorReady(arenaInterior())), name, tostring(GlobalState.mzbShow))
    print('[mzb_arena] ' .. msg)
    TriggerEvent('chat:addMessage', { args = { 'arena', msg } })
end, false)
