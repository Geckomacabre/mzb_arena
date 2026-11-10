-- mzb_arena - client: the followspot (GlobalState.mzbSpot, server/spot.lua).
-- (1.6.0) The lamps are real: three local props per stand in the press boxes' bays (Config.FollowSpot.fixtures,
-- lamp: the stand, the yoke that pans on it, the lamp that tilts in the yoke), turned every frame to where the beam
-- goes - and the beam (a DrawSpotLight) leaves their lens. Idle, they look at the floor's middle. Locked onto a player,
-- every client follows that ped itself; aimed by hand, the operator's points arrive a few times a second and the
-- lamps glide after them. The operator either stands at a lamp ("Operate the followspot": first person behind it, the
-- lamp follows where they look) or grabs free aim from anywhere with a key (RegisterKeyMapping) and the spot follows
-- their camera.

local FS = Config.FollowSpot or {}
local LAMP = FS.lamp or {}
local OP = FS.operate or {}
local S = GlobalState.mzbSpot
local dark = (GlobalState.mzbLights or {}).bo == true      -- (1.5.0) the light desk's BLACKOUT takes the spot out too
AddStateBagChangeHandler('mzbLights', 'global', function(_, _, value) dark = type(value) == 'table' and value.bo == true end)
local goal = nil                      -- where the beam should be (vector3)
local cur = nil                       -- where it is (it glides to goal)
local grabbing = false
local asked = nil                     -- free aim asked for, not yet handed over by the server: { quiet, granted }
local op = nil                        -- running a lamp from its box: { i, cam, yaw, pitch, locked, waiting }

local function say(msg) TriggerEvent('chat:addMessage', { args = { 'spot', msg } }) end

-- the state names this player as the one aiming by hand
local function mine()
    return S ~= nil and S.aim == 'point' and S.by == GetPlayerServerId(PlayerId())
end

-- ------------------------------------------------------------------ the lamps
local AF = Config.ArenaFrame
local AC, AS = math.cos(AF.ang), math.sin(AF.ang)
local lamps = {}                      -- { base, pivot, facing (the heading its box looks), yaw, pitch, ents, props }
for _, f in ipairs(FS.fixtures or {}) do
    if type(f) == 'table' and f.u then
        local base = vector3(AF.x + f.u * AC - f.v * AS, AF.y + f.u * AS + f.v * AC, AF.z + f.z)
        local sgn = f.v > 0 and -1.0 or 1.0                    -- the box looks across the arena, at v = 0
        local out = vector3(-AS * sgn, AC * sgn, 0.0)
        lamps[#lamps + 1] = { base = base, pivot = base + vector3(0.0, 0.0, (LAMP.column or 1.22) + (LAMP.trunnion or 0.40)),
                              facing = math.deg(math.atan(-out.x, out.y)), props = true }
    else                                                   -- a bare point in the world (as before 1.6.0)
        lamps[#lamps + 1] = { pivot = vector3(f.x + 0.0, f.y + 0.0, f.z + 0.0), props = false }
    end
end
local IDLE = vector3(AF.x, AF.y, AF.z)                     -- where an idle lamp looks: the floor's middle

-- heading (deg, the game's: 0 = north, counter-clockwise) and pitch (deg, up +) from a to b
local function angles(a, b)
    local d = b - a
    return math.deg(math.atan(-d.x, d.y)), math.deg(math.atan(d.z, math.sqrt(d.x * d.x + d.y * d.y)))
end

local function forward(yaw, pitch)
    local h, p = math.rad(yaw), math.rad(pitch)
    return vector3(-math.sin(h) * math.cos(p), math.cos(h) * math.cos(p), math.sin(p))
end

local function clampPitch(p)
    local t = LAMP.tilt or { -58.0, 12.0 }
    return math.max(t[1], math.min(t[2], p))
end

local function loadModel(name)
    local m = GetHashKey(name)
    if not IsModelInCdimage(m) then return nil end
    RequestModel(m)
    local untilT = GetGameTimer() + 5000
    while not HasModelLoaded(m) do
        if GetGameTimer() > untilT then return nil end
        Wait(0)
    end
    return m
end

local made = false
local function makeLamps(interior)
    for _, L in ipairs(lamps) do
        if L.props and not L.ents then
            local ms = { loadModel(LAMP.stand or 'mzb_spot_stand'), loadModel(LAMP.yoke or 'mzb_spot_yoke'),
                         loadModel(LAMP.body or 'mzb_spot_body') }
            if ms[1] and ms[2] and ms[3] then
                local bearing = L.base + vector3(0.0, 0.0, LAMP.column or 1.22)
                local stand = CreateObjectNoOffset(ms[1], L.base.x, L.base.y, L.base.z, false, false, false)
                local yoke = CreateObjectNoOffset(ms[2], bearing.x, bearing.y, bearing.z, false, false, false)
                local body = CreateObjectNoOffset(ms[3], L.pivot.x, L.pivot.y, L.pivot.z, false, false, false)
                L.ents = { stand, yoke, body }
                L.yaw, L.pitch = angles(L.pivot, IDLE)
                L.pitch = clampPitch(L.pitch)
                SetEntityHeading(stand, L.facing)
                for _, e in ipairs(L.ents) do
                    FreezeEntityPosition(e, true)
                    if interior ~= 0 then MzbPutInRoom(e, interior, GetHashKey('bowl')) end
                end
                SetEntityCollision(yoke, false, false)
                SetEntityCollision(body, false, false)
                SetEntityRotation(yoke, 0.0, 0.0, L.yaw, 2, true)
                SetEntityRotation(body, L.pitch, 0.0, L.yaw, 2, true)
            end
            for _, m in ipairs(ms) do if m then SetModelAsNoLongerNeeded(m) end end
        end
    end
    made = true
end

local function removeLamps()
    for _, L in ipairs(lamps) do
        for _, e in ipairs(L.ents or {}) do
            if DoesEntityExist(e) then DeleteEntity(e) end
        end
        L.ents = nil
    end
    made = false
end

-- the lamp turned to look at a point (it glides there): its lens and the way it points
local function aimLamp(L, at, dt)
    local yaw, pitch = angles(L.pivot, at)
    pitch = clampPitch(pitch)
    if L.yaw then
        local dy = (yaw - L.yaw + 540.0) % 360.0 - 180.0
        local k = math.min(1.0, dt * 9.0)
        L.yaw, L.pitch = L.yaw + dy * k, L.pitch + (pitch - L.pitch) * k
    else
        L.yaw, L.pitch = yaw, pitch
    end
    if L.ents then
        SetEntityRotation(L.ents[2], 0.0, 0.0, L.yaw, 2, true)
        SetEntityRotation(L.ents[3], L.pitch, 0.0, L.yaw, 2, true)
    end
    local fwd = forward(L.yaw, L.pitch)
    return L.props and (L.pivot + fwd * (LAMP.lens or 0.71)) or L.pivot, fwd
end

-- the lamps while the player is in (or near) the arena; a zone at each to run it from (client/pressbox.lua)
CreateThread(function()
    local zonesUp = false
    while true do
        local id, ready = MzbInterior()
        local here = ready and GetInteriorFromEntity(PlayerPedId()) == id
        if FS.enabled and here and not made then makeLamps(id)
        elseif made and not here and #(GetEntityCoords(PlayerPedId()) - Config.InteriorProbe) > 160.0 then removeLamps() end
        if FS.enabled and MzbTarget and not zonesUp then
            for i, L in ipairs(lamps) do
                if L.props then
                    local back = forward(L.facing, 0.0) * -0.75
                    MzbTarget.add('followspot' .. i, { coords = L.pivot + back + vector3(0.0, 0.0, -0.25),
                        size = vector3(1.2, 1.2, 1.4), label = OP.label or 'Operate the followspot',
                        icon = OP.icon or 'lightbulb', distance = OP.distance or 1.4,
                        enabled = function() return op == nil end,
                        onUse = function() MzbOperateSpot(i) end })
                end
            end
            zonesUp = true
        end
        Wait(1000)
    end
end)

AddStateBagChangeHandler('mzbSpot', 'global', function(_, _, value)
    S = value
    if asked and mine() then
        -- the server handed it over
        local a = asked
        asked = nil
        a.granted(a)
    elseif grabbing and not mine() then
        grabbing = false                                  -- someone else took it, or it follows a player now
    end
    if S and S.aim == 'point' and S.point and not grabbing then
        goal = vector3(S.point.x + 0.0, S.point.y + 0.0, S.point.z + 0.0)
    end
    SendNUIMessage({ type = 'spotDesk', spot = S })
end)

RegisterNetEvent('mzb_arena:spotPoint', function(x, y, z)
    if type(x) == 'number' and type(y) == 'number' and type(z) == 'number' and not grabbing then
        goal = vector3(x, y, z)
    end
end)

local function pedOf(serverId)
    if serverId == GetPlayerServerId(PlayerId()) then return PlayerPedId() end
    local p = GetPlayerFromServerId(serverId)
    if p == -1 then return 0 end
    return GetPlayerPed(p)
end

-- the camera's forward vector
local function camForward()
    local r = GetFinalRenderedCamRot(2)
    local x, z = math.rad(r.x), math.rad(r.z)
    return vector3(-math.sin(z) * math.cos(x), math.cos(z) * math.cos(x), math.sin(x))
end

-- what the operator's camera looks at (world, vehicles, peds, objects), 150 m at most (running a lamp from its box:
-- from past the lamp, so its stand is not what it looks at)
local function aimPoint()
    local from, dir = GetFinalRenderedCamCoord(), camForward()
    if op then from = from + dir * 1.4 end
    local to = from + dir * 150.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 2 + 4 + 16,
        PlayerPedId(), 7)
    local _, hit, pos = GetShapeTestResult(ray)
    if hit == 1 or hit == true then return pos end
    return nil
end

-- the player nearest the crosshair (within Config.FollowSpot.lookAngle degrees), not yourself
local function lookedAt()
    local from, fwd = GetFinalRenderedCamCoord(), camForward()
    local best, bestAng = nil, math.rad(FS.lookAngle or 8.0)
    local me = PlayerId()
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= me then
            local ped = GetPlayerPed(p)
            local d = GetEntityCoords(ped) - from
            local len = #d
            if len > 1.0 and len < 150.0 then
                local dot = (d.x * fwd.x + d.y * fwd.y + d.z * fwd.z) / len
                local ang = math.acos(math.max(-1.0, math.min(1.0, dot)))
                if ang < bestAng then best, bestAng = GetPlayerServerId(p), ang end
            end
        end
    end
    return best
end

-- ------------------------------------------------------------------ tracks: another script's use of the lamps
-- (2026-11-10, the user: "make sure the stream server stuff uses the proper arena lights") A show running on this
-- client (vi_bucks' walk-outs, its fan cam) points the real lamps at its own peds - peds it made on each client, so
-- not a player the server's followspot could lock onto - instead of drawing a beam from a point in the air:
--   local t = exports.mzb_arena:SpotTrack({ entity = ped | point = vector3, lamps = { 1, 2 } | 'all' | 'reach',
--                                           color = { r, g, b } | 'red' | '#rrggbb', size = 6.0, intensity = 1.0,
--                                           ms = 10000 })            -> a token, or false (no lamp for it)
--   exports.mzb_arena:SpotRetarget(t, { entity = | point = | color = | size = })   (the same lamps)
--   exports.mzb_arena:SpotRelease(t)
--   exports.mzb_arena:SpotReach(point)   -> the lamps that can turn to it (their box's side, the tilt), or {}
-- 'reach' (the default) takes the lamps that can turn to it. A track lasts `ms` (at most 2 minutes, each Retarget
-- starts it again) and gives way to the player running that lamp, to the desk's blackout, and ends with the resource
-- that set it.
local tracks = {}                     -- lamp index -> { token, entity, point, color, size, intensity, till, owner, cur }
local nextToken = 0

local function colourOf(c, fallback)
    if type(c) == 'string' then
        local named = Config.LightColors and Config.LightColors[c:lower()]
        if named then return { named[1], named[2], named[3] } end
        local hex = c:match('^#?(%x%x%x%x%x%x)$')
        if hex then return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) } end
    elseif type(c) == 'table' and tonumber(c[1]) and tonumber(c[2]) and tonumber(c[3]) then
        return { math.floor(math.max(0, math.min(255, c[1]))), math.floor(math.max(0, math.min(255, c[2]))),
                 math.floor(math.max(0, math.min(255, c[3]))) }
    end
    return fallback
end

local function pointOf(p)
    if type(p) == 'vector3' or (type(p) == 'table' and tonumber(p.x) and tonumber(p.y) and tonumber(p.z)) then
        return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    end
    if type(p) == 'table' and tonumber(p[1]) and tonumber(p[2]) and tonumber(p[3]) then
        return vector3(p[1] + 0.0, p[2] + 0.0, p[3] + 0.0)
    end
    return nil
end

-- can lamp L turn to point p (its box's side: within the operator's pan either side of the way it looks; its tilt)
local function reaches(L, p)
    if not L.props then return true end
    local yaw, pitch = angles(L.pivot, p)
    local d = (yaw - L.facing + 540.0) % 360.0 - 180.0
    local t = LAMP.tilt or { -58.0, 12.0 }
    return math.abs(d) <= (OP.pan or 80.0) and pitch >= t[1] and pitch <= t[2]
end

local function reachList(p)
    local out = {}
    if not p then return out end
    for i, L in ipairs(lamps) do if reaches(L, p) then out[#out + 1] = i end end
    return out
end

local function trackTarget(t)
    if t.entity and t.entity ~= 0 and DoesEntityExist(t.entity) then
        local p = GetEntityCoords(t.entity)
        return vector3(p.x, p.y, p.z - 0.2)
    end
    return t.point
end

local function apply(t, opts)
    if opts.entity ~= nil then
        t.entity = (type(opts.entity) == 'number' and opts.entity ~= 0) and opts.entity or nil
        if t.entity then t.point = nil end
    end
    if opts.point ~= nil then
        t.point = pointOf(opts.point)
        if t.point then t.entity = nil end
    end
    t.color = colourOf(opts.color, t.color or FS.color or { 255, 248, 235 })
    if tonumber(opts.size) then t.size = math.max(1.0, math.min(30.0, tonumber(opts.size))) end
    if tonumber(opts.intensity) then t.intensity = math.max(0.0, math.min(1.5, tonumber(opts.intensity))) end
    local ms = tonumber(opts.ms) or t.ms or 10000
    t.ms = math.max(100, math.min(120000, ms))
    t.till = GetGameTimer() + t.ms
end

exports('SpotTrack', function(opts)
    if not FS.enabled or type(opts) ~= 'table' or #lamps == 0 then return false end
    local t = { size = FS.size or 5.0, intensity = 1.0, owner = GetInvokingResource() }
    apply(t, opts)
    local at = trackTarget(t)
    if not at then return false end
    local which = {}
    if opts.lamps == 'all' then
        for i = 1, #lamps do which[#which + 1] = i end
    elseif type(opts.lamps) == 'table' then
        for _, i in ipairs(opts.lamps) do if lamps[tonumber(i)] then which[#which + 1] = tonumber(i) end end
    else
        which = reachList(at)
    end
    if #which == 0 then return false end
    nextToken = nextToken + 1
    t.token, t.lamps = nextToken, which
    for _, i in ipairs(which) do tracks[i] = t end
    return nextToken
end)

local function byToken(token)
    for _, t in pairs(tracks) do if t.token == token then return t end end
    return nil
end

exports('SpotRetarget', function(token, opts)
    local t = byToken(token)
    if not t or type(opts) ~= 'table' then return false end
    apply(t, opts)
    return true
end)

exports('SpotRelease', function(token)
    local found = false
    for i, t in pairs(tracks) do
        if t.token == token then tracks[i] = nil; found = true end
    end
    return found
end)

exports('SpotReach', function(p) return reachList(pointOf(p)) end)

AddEventHandler('onResourceStop', function(res)
    for i, t in pairs(tracks) do if t.owner == res then tracks[i] = nil end end
end)

-- the track lamp i runs now (nil: none, or it gave way)
local function trackOf(i, now)
    local t = tracks[i]
    if not t then return nil end
    if now > t.till then tracks[i] = nil return nil end
    if op and op.i == i then return nil end              -- the player running this lamp has it
    return t
end

-- ------------------------------------------------------------------ the beam
local visible = { bowl = true, near = true }

CreateThread(function()
    while true do
        if FS.enabled and visible[MzbListener.zone] and #lamps > 0 then
            local dt = math.min(GetFrameTime(), 0.1)
            local on = S ~= nil and S.on and not dark
            if on and S.aim == 'player' then
                local ped = pedOf(S.target)
                if ped ~= 0 and DoesEntityExist(ped) then
                    local p = GetEntityCoords(ped)
                    goal = vector3(p.x, p.y, p.z - 0.2)          -- the middle of the body: the beam covers head to feet
                end
            end
            local target = cur or IDLE                           -- off: the lamps rest where the beam last was
            if on and goal then
                cur = cur and (cur + (goal - cur) * math.min(1.0, dt * (grabbing and 20.0 or 8.0))) or goal
                target = cur
            end
            local c = S and S.color or FS.color or { 255, 248, 235 }
            local bright = (FS.brightness or 40.0) * (S and S.intensity or 1.0)
            local now = GetGameTimer()
            for i, L in ipairs(lamps) do
                local t = trackOf(i, now)
                local at = t and trackTarget(t)
                if at then
                    -- another script's track (SpotTrack): this lamp glides after its ped or point, its own beam
                    t.cur = t.cur and (t.cur + (at - t.cur) * math.min(1.0, dt * 8.0)) or at
                    local lens, n = aimLamp(L, t.cur, dt)
                    local len = #(t.cur - lens)
                    if not dark and len > 0.5 then
                        DrawSpotLight(lens.x, lens.y, lens.z, n.x, n.y, n.z, t.color[1], t.color[2], t.color[3],
                            len + 10.0, (FS.brightness or 40.0) * t.intensity, FS.hardness or 0.75, t.size,
                            FS.falloff or 1.0)
                        if Config.LightLensGlow then
                            DrawLightWithRange(lens.x + n.x * 0.08, lens.y + n.y * 0.08, lens.z + n.z * 0.08,
                                t.color[1], t.color[2], t.color[3], 1.6, 3.0 * t.intensity)
                        end
                    end
                else
                    local lens, n = aimLamp(L, target, dt)
                    if on and goal then
                        local len = #(target - lens)
                        if len > 0.5 then
                            DrawSpotLight(lens.x, lens.y, lens.z, n.x, n.y, n.z, c[1], c[2], c[3], len + 10.0, bright,
                                FS.hardness or 0.75, S.size or 5.0, FS.falloff or 1.0)
                            if Config.LightLensGlow then
                                DrawLightWithRange(lens.x + n.x * 0.08, lens.y + n.y * 0.08, lens.z + n.z * 0.08, c[1],
                                    c[2], c[3], 1.6, 3.0 * (S.intensity or 1.0))
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

-- ------------------------------------------------------------------ free aim (the operator)
CreateThread(function()
    local lastSent, lastPos = 0, nil
    local gap = math.floor(1000 / math.max(1, FS.sendRate or 8))
    while true do
        if grabbing then
            local p = aimPoint()
            if p then
                goal = p
                local now = GetGameTimer()
                if now - lastSent >= gap and (not lastPos or #(p - lastPos) > 0.05) then
                    TriggerServerEvent('mzb_arena:spotPoint', p.x, p.y, p.z)
                    lastSent, lastPos = now, p
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- Free aim is asked for and only taken up once the server hands it over (the state then names this player), so a
-- player who may not run the spot never aims anything. They are told so if they asked in words (the command, the
-- desk, a lamp) and not if they only touched the key: it is bound for every player, and most of them are not the
-- operator. granted(ask) runs once it is handed over; ask.onRefused (if set) when it is not, 2 s on.
local function askAim(quiet, granted)
    TriggerServerEvent('mzb_arena:spot', { on = true, aim = 'point' })   -- the server checks you may
    if mine() then                                       -- it was this player's already (released a moment ago)
        granted({ quiet = quiet })
        return nil
    end
    local ask = { quiet = quiet, granted = granted }
    asked = ask
    CreateThread(function()
        Wait(2000)
        if asked == ask then
            asked = nil
            if not quiet then say('you are not allowed to run the followspot') end
            if ask.onRefused then ask.onRefused() end
        end
    end)
    return ask
end

local function grab(quiet)
    if not FS.enabled then return end
    if grabbing then
        grabbing = false
        say('free aim released: the spot stays where it is')
        return
    end
    askAim(quiet, function()
        grabbing = true
        say('free aim: the spot follows your camera (press again to let go)')
    end)
end

RegisterCommand('arenaspotaim', function() if not op then grab(true) end end, false)
RegisterKeyMapping('arenaspotaim', 'Arena followspot: grab / release free aim', 'keyboard', FS.key or 'F7')

local function follow(id)
    if not id then return say('nobody under your crosshair') end
    TriggerServerEvent('mzb_arena:spot', { on = true, aim = 'player', target = id })
    grabbing = false
end

-- ------------------------------------------------------------------ running a lamp from its box
local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function leave()
    if not op then return end
    local o = op
    op = nil
    grabbing = false
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    local L = lamps[o.i]
    for _, e in ipairs(L and L.ents or {}) do                           -- their lamp, hidden while they ran it
        if DoesEntityExist(e) then SetEntityVisible(e, true, false) end
    end
    if o.viewMode then SetFollowPedCamViewMode(o.viewMode) end          -- the view the player had
    if MzbHoldRoom then MzbHoldRoom(o.id, o.room, 4000, GetEntityCoords(ped), true) end
end

local function startView(i)
    local L = lamps[i]
    local ped = PlayerPedId()
    -- the player and their camera are kept in the bowl's room while they run the lamp (MzbHoldRoom, strict): the
    -- boxes and the lamps are the bowl's. (2026-11-10: it kept the room the player stood in, which in a box can be the
    -- concourse - the bowl then drawn only through its doorways: the far crowd and the centre board gone)
    local id = GetInteriorFromEntity(ped)
    if id == 0 then id = MzbInterior and MzbInterior() or 0 end
    op.id, op.room = id, GetHashKey('bowl')
    -- behind the lamp, at its handles, facing the way its box looks (on the front tier: at 0.95 m they stood in the
    -- back tier's step and counter)
    local back = forward(L.facing, 0.0) * -(OP.stand or 0.85)
    SetEntityCoords(ped, L.base.x + back.x, L.base.y + back.y, L.base.z, false, false, false, false)
    SetEntityHeading(ped, L.facing)
    FreezeEntityPosition(ped, true)
    local a = OP.anim
    if a and a[1] then
        RequestAnimDict(a[1])
        local untilT = GetGameTimer() + 2000
        while not HasAnimDictLoaded(a[1]) and GetGameTimer() < untilT do Wait(0) end
        if HasAnimDictLoaded(a[1]) then TaskPlayAnim(ped, a[1], a[2], 4.0, -4.0, -1, 1, 0.0, false, false, false) end
    end
    if not op then return end                            -- (let go while the pose loaded)
    -- (2026-11-06) the player's own camera in first person, not a script's: from a script's camera the game drew the
    -- arena wrongly (its interior gone, the far chairs gone) with the camera's room reported right all along. The lamp
    -- follows where they look, as free aim does, and is hidden from them while they run it (it stood in the view)
    op.viewMode = GetFollowPedCamViewMode()
    SetFollowPedCamViewMode(4)
    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(L.pitch or -20.0, 1.0)
    op.active = true
    if MzbHoldRoom then MzbHoldRoom(op.id, op.room, 6 * 3600 * 1000, GetEntityCoords(ped), true) end   -- (until leave())
    grabbing = true
end

-- "Operate the followspot" at lamp i (its zone, or /arenaspot man at it)
function MzbOperateSpot(i)
    if not FS.enabled or not lamps[i] or not lamps[i].props then return end
    if op then return leave() end
    op = { i = i, waiting = true }
    local ask = askAim(false, function()
        if op and op.i == i and op.waiting then
            op.waiting = false
            startView(i)
            say('the followspot is yours: it follows where you look, LEFT CLICK locks it onto a player, RIGHT CLICK aims by hand, the wheel sizes it, E lets go')
        end
    end)
    if ask then ask.onRefused = function() if op and op.waiting then op = nil end end end
end

-- the lamp's sight: the beam goes where the middle of the view is (it follows the camera's ray), so a sight there -
-- dim while the lamp is locked onto a player (then it follows them, not the view)
local function sight(alpha)
    local w, h = GetActiveScreenResolution()
    local k = h / 1080.0
    local th, len, gap = math.max(1.0, math.floor(2.0 * k + 0.5)), 11.0 * k, 5.0 * k
    local r, g, b = 255, 236, 190
    DrawRect(0.5 - (gap + len / 2) / w, 0.5, len / w, th / h, r, g, b, alpha)
    DrawRect(0.5 + (gap + len / 2) / w, 0.5, len / w, th / h, r, g, b, alpha)
    DrawRect(0.5, 0.5 - (gap + len / 2) / h, th / w, len / h, r, g, b, alpha)
    DrawRect(0.5, 0.5 + (gap + len / 2) / h, th / w, len / h, r, g, b, alpha)
    DrawRect(0.5, 0.5, th / w, th / h, r, g, b, alpha)
end

-- what the operator's controls are kept from while they run a lamp (the mouse still looks): the camera switch, fire /
-- aim (lock on / by hand), the weapon wheel (the size), jump, sprint, cover, melee, E and the pause menu (let go)
local BLOCK = { 0, 14, 15, 16, 17, 21, 22, 24, 25, 26, 37, 38, 44, 45, 140, 141, 142, 143, 199, 200, 202, 257, 263, 264 }

CreateThread(function()
    local lastSize = 0
    while true do
        if op and op.active then
            local L = lamps[op.i]
            for _, c in ipairs(BLOCK) do DisableControlAction(0, c, true) end
            if GetFollowPedCamViewMode() ~= 4 then SetFollowPedCamViewMode(4) end
            -- the view kept to the lamp's reach: its pan either side of the way the box looks, its tilt
            local pan = OP.pan or 80.0
            local h = GetGameplayCamRelativeHeading()
            if h > pan then SetGameplayCamRelativeHeading(pan) elseif h < -pan then SetGameplayCamRelativeHeading(-pan) end
            local t = LAMP.tilt or { -58.0, 12.0 }
            local p = GetGameplayCamRelativePitch()
            if p < t[1] then SetGameplayCamRelativePitch(t[1], 1.0) elseif p > t[2] then SetGameplayCamRelativePitch(t[2], 1.0) end
            -- (2026-11-07) their own lamp out of their view: its house's back stood 10 cm before their eyes. Hidden in
            -- their game only - the props are each player's own (not networked: everyone else's turns as before), and
            -- SetEntityLocallyInvisible did nothing to them. Put back in leave()
            for _, e in ipairs(L.ents or {}) do
                if IsEntityVisible(e) then SetEntityVisible(e, false, false) end
            end
            -- (2026-11-07) and their own body: the pose's hands filled the view looking down at the court ("all i see
            -- is the hand animations"). Their ped is networked, so this hides it from them alone: everyone else sees
            -- them at the lamp
            SetEntityLocallyInvisible(PlayerPedId())
            if OP.sight ~= false then sight(op.locked and 80 or 210) end
            if IsDisabledControlJustPressed(0, 24) then                 -- left click: lock onto who is under it
                local who = lookedAt()
                if who then
                    follow(who)
                    op.locked = true
                else
                    say('nobody under your crosshair')
                end
            elseif IsDisabledControlJustPressed(0, 25) and op.locked then  -- right click: aim by hand again
                op.locked = false
                askAim(true, function() grabbing = true end)
            end
            local now = GetGameTimer()
            local wheel = (IsDisabledControlJustPressed(0, 15) and 1 or 0) - (IsDisabledControlJustPressed(0, 14) and 1 or 0)
            if wheel ~= 0 and now - lastSize > 120 then
                lastSize = now
                TriggerServerEvent('mzb_arena:spot', { size = (S and S.size or FS.size or 5.0) + wheel * 0.5 })
            end
            help('~INPUT_ATTACK~ lock on ~INPUT_AIM~ by hand ~INPUT_WEAPON_WHEEL_NEXT~ size ~INPUT_CONTEXT~ let go')
            -- E, or Backspace / Esc (202; not 177, which is the right mouse button too: that is "by hand")
            if IsDisabledControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 202) or IsEntityDead(PlayerPedId()) then
                leave()
                say('you let go of the followspot: it stays where it is')
            elseif not op.locked and S and S.aim == 'point' and S.by ~= GetPlayerServerId(PlayerId()) then
                leave()                                    -- someone else took it by hand: it is not yours to move
                say('someone else is running the followspot')
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- /arenaspot: free, follow look and man run here (they need your camera); the rest goes to the server
RegisterCommand(FS.command or 'arenaspot', function(_, args)
    local sub = args[1] and args[1]:lower()
    if sub == 'free' then return grab() end
    if sub == 'follow' and args[2] == 'look' then return follow(lookedAt()) end
    if sub == 'man' then                                         -- the lamp you stand at
        local p, best, bestD = GetEntityCoords(PlayerPedId()), nil, 3.0
        for i, L in ipairs(lamps) do
            if L.props and #(p - L.base) < bestD then best, bestD = i, #(p - L.base) end
        end
        if not best then return say('stand at a followspot (in a press box) first') end
        return MzbOperateSpot(best)
    end
    TriggerServerEvent('mzb_arena:spotCmd', { args[1], args[2], args[3] })
end, false)

-- ------------------------------------------------------------------ the desk's Followspot section (html/spot.js)
AddEventHandler('mzb_arena:lightsDesk', function()
    SendNUIMessage({ type = 'spotDesk', spot = S, enabled = FS.enabled == true })
end)

-- the players in the arena, for the desk's list (asked by the desk while it is open)
RegisterNUICallback('spotPlayers', function(_, cb)
    local list = {}
    for _, p in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(p)
        if GetInteriorFromEntity(ped) ~= 0 and GetInteriorFromEntity(ped) == GetInteriorFromEntity(PlayerPedId()) then
            list[#list + 1] = { id = GetPlayerServerId(p), name = GetPlayerName(p) }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    cb(list)
end)

RegisterNUICallback('spot', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    if data.action == 'free' then
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'close' })                   -- the desk closes: free aim needs the camera
        if not grabbing then grab() end
    elseif data.action == 'look' then
        follow(lookedAt())
    else
        TriggerServerEvent('mzb_arena:spot', data.patch)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if op then leave() end
    removeLamps()
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (FS.command or 'arenaspot'), 'Maze Bank Arena: the followspot (staff)',
        { { name = 'what', help = 'on | off | follow <id|me|look> | free | man (at a lamp) | color <c> | size <2-15> | intensity <0-100> | status' } })
end)
