-- mzb_arena - client: which interior is the arena (MzbInterior), and the show standing in it - the interior's entity
-- sets, kept the way the show wants them

-- ------------------------------------------------------------------ which interior is the arena
-- MzbInterior() -> id (0 = none), ready. Every script here that puts something into the arena asks this.
-- It is the interior the game has at Config.InteriorProbe - unless the player stands in a different interior inside
-- the arena's walls: then that one is the arena, and standing in it counts as ready. The second half is the guard for
-- joining again with the game left open (after a server restart): the probe can then keep answering with an interior
-- that never becomes ready, and everything that waits for it - the show's pieces, the crowd, the props - stays away.
local P = Config.InteriorProbe
local F = Config.ArenaFrame or { x = P.x, y = P.y, z = P.z - 5.45, ang = 0.0 }
local FC, FS = math.cos(F.ang), math.sin(F.ang)
-- the building in the arena's own frame (u along it, v across, h over the event floor): the interior's box in
-- stream/interior/mzb_arena.ytyp and 6 m
local BOX = Config.InteriorBox or { u0 = -110.0, u1 = 97.0, v = 67.0, h0 = -7.0, h1 = 51.0 }

local function inBuilding(c)
    local dx, dy = c.x - F.x, c.y - F.y
    local u, v, h = dx * FC + dy * FS, -dx * FS + dy * FC, c.z - F.z
    return u > BOX.u0 and u < BOX.u1 and v > -BOX.v and v < BOX.v and h > BOX.h0 and h < BOX.h1
end

-- the interior at the probe, the interior the player is in (0 = none) and whether that is inside the building
local function interiors()
    local ped = PlayerPedId()
    local mine = GetInteriorFromEntity(ped)
    return GetInteriorAtCoords(P.x, P.y, P.z), mine, mine ~= 0 and inBuilding(GetEntityCoords(ped))
end

function MzbInterior()
    local id, mine, inside = interiors()
    if inside and mine ~= id then id = mine end
    if id == 0 then return 0, false end
    return id, mine == id or (IsInteriorReady(id) and true or false)
end

-- ------------------------------------------------------------------ the show (interior entity sets)
-- Since 1.2.0 the lower tier's front seven rows are a set of their own: seated, or folded back for the bigger floor.
-- A show that names neither - a config kept from before 1.2.0, a show of the owner's own - is given the seated rows
-- here, in Config.Shows itself: it keeps rows 1 to 7 and the padded wall, instead of a tier that starts at row 8
-- over an open wall. This is the first client script, so everything after it (the sets below, the crowd's seats)
-- reads the completed lists; the server does the same to its own copy (server/main.lua).
for _, sets in pairs(Config.Shows) do
    local front = false
    for _, s in ipairs(sets) do
        if s == 'mzb_set_low_front_seated' or s == 'mzb_set_low_front_stowed' then front = true end
    end
    if not front then sets[#sets + 1] = 'mzb_set_low_front_seated' end
end

local managed = {}                 -- every set a show or the house lights name
for _, sets in pairs(Config.Shows) do
    for _, s in ipairs(sets) do managed[s] = true end
end
for _, s in pairs(Config.HouseSets or {}) do managed[s] = true end
for _, s in ipairs(Config.RetiredSets or {}) do managed[s] = true end    -- (always off: a game that still had one on)

-- the sets a show wants on - never the house light sets (client/lights.lua draws the house lights at the desk's
-- house setting: the show's own, full, dimmed or off)
local function wanted(name)
    local sets = Config.Shows[name]
    if not sets then return nil end
    local on = {}
    for _, s in ipairs(sets) do on[s] = true end
    -- (1.5.0) the house light sets stay off: their lights are drawn by client/lights.lua (shared/house_lights.lua), so
    -- the house going up, down or out - a look, BLACKOUT, the HOUSE key - no longer has the interior rebuilt (the
    -- whole arena vanished for a few frames and faded back in). A show's list still names its own house level.
    for _, s in pairs(Config.HouseSets or {}) do on[s] = nil end
    -- sets another resource asked to have left out (the server's HideSets export: it brings a ring or a stage of
    -- its own and ours would stand in it)
    for _, s in ipairs(GlobalState.mzbHideSets or {}) do on[s] = nil end
    return on
end

local function isOn(id, s)
    local a = IsInteriorEntitySetActive(id, s)
    return a == true or a == 1
end

local function matches(id, on)
    for s in pairs(managed) do
        if isOn(id, s) ~= (on[s] == true) then return false end
    end
    return true
end

-- What this resource puts into the arena's rooms (the crowd and the staff, props, litter, the curtains, the doors,
-- the screens), with the room each one is in. An entity set only shows or goes with a refresh of the interior, and
-- Rockstar's own scripts refresh with players inside and leave the rooms to the game - so the refresh is left alone.
-- (1.5.0's first build forced the player's room and the camera's in the same frame as the refresh and let the camera
-- go half a second later: the camera was then left outside the arena it stood in, "everything around me goes
-- invisible" until noclip.) For a few seconds after a refresh, once the interior is ready again, whatever the refresh
-- left out of its room is put back the way Rockstar's scripts do it: our things and the player with
-- FORCE_ROOM_FOR_ENTITY; the camera with SET_ROOM_FOR_GAME_VIEWPORT_BY_KEY and the player's room and, if that does
-- not take, a cut to a copy of the game's camera for one frame and back (what noclip's camera does). Whenever
-- anything had to be put back, F8 (and the client's log) says what.
local placed = {}                  -- entity -> { room key, model }
function MzbPutInRoom(e, interior, room)
    ForceRoomForEntity(e, interior, room)
    placed[e] = { room, GetEntityModel(e) }
end

-- the refresh being looked after: the interior, when it was asked for and until when it is looked after, the
-- player's room then and where the player stood in it, and whether the camera was in one of the arena's rooms.
-- Only what goes out of its room within LOST_MS of a refresh is the refresh's doing: one who walks out of a door
-- later on is outside, and is left there.
local GUARD_MS, LOST_MS = 4000, 1500
local guard = { id = 0, t0 = 0, till = 0, room = 0, at = nil, cam = false, running = false }

-- a room of the interior proper: not 0, not a key it does not have, not its limbo (room 0)
local function aRoom(id, key)
    return key ~= 0 and GetInteriorRoomIndexByHash(id, key) > 0
end

-- the camera cut to a copy of itself for one frame and back: the game then looks for the camera's room again. Only
-- from the game's own camera: a script's camera (the merch stand's try-on, another resource's) is not ours to drop.
local function recut()
    if not IsGameplayCamRendering() then return false end
    local p, r = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2)
    local c = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(c, p.x, p.y, p.z)
    SetCamRot(c, r.x, r.y, r.z, 2)
    SetCamFov(c, GetGameplayCamFov())
    RenderScriptCams(true, false, 0, true, false)
    Wait(0)
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(c, false)
    return true
end

local function lookAfter()
    local did, nextThings, camTries, cut, lost, camLost = {}, 0, 0, false, false, false
    while GetGameTimer() < guard.till do
        Wait(0)
        local id, now, ped = guard.id, GetGameTimer(), PlayerPedId()
        local room = GetInteriorFromEntity(ped) == id and GetRoomKeyFromEntity(ped) or 0
        local view = GetInteriorFromPrimaryView() == id and GetRoomKeyForGameViewport() or 0
        if now - guard.t0 < LOST_MS then
            if aRoom(id, guard.room) and not aRoom(id, room) then lost = true end
            if guard.cam and not aRoom(id, view) then camLost = true end
        end
        if IsInteriorReady(id) then
            if now >= nextThings then
                nextThings = now + 250
                for e, p in pairs(placed) do
                    -- (a handle can be another entity's by now: only the same model is put back)
                    if not DoesEntityExist(e) or GetEntityModel(e) ~= p[2] then
                        placed[e] = nil
                    elseif GetInteriorFromEntity(e) ~= id then
                        ForceRoomForEntity(e, id, p[1])
                        did.things = (did.things or 0) + 1
                    end
                end
            end
            -- the player, where it stood (one that has walked off meanwhile is left to the game)
            if lost and not aRoom(id, room) and guard.at and #(GetEntityCoords(ped) - guard.at) < 2.0 then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 then ForceRoomForEntity(veh, id, guard.room) end
                ForceRoomForEntity(ped, id, guard.room)
                did.player = true
                room = guard.room
            end
            if camLost and aRoom(id, room) and not aRoom(id, view) then
                camTries = camTries + 1
                if camTries <= 10 then
                    -- SET_ROOM_FOR_GAME_VIEWPORT_BY_KEY: FiveM's Lua has no name for it (N_0x405dc2aef6af95b9)
                    Citizen.InvokeNative(0x405DC2AEF6AF95B9, room)
                    did.camera = 'its room'
                elseif not cut then
                    cut = true
                    if recut() then did.camera = 'a cut' end
                end
            end
        end
    end
    local id, ped = guard.id, PlayerPedId()
    local still = lost and not (GetInteriorFromEntity(ped) == id and aRoom(id, GetRoomKeyFromEntity(ped))) and 'the player'
        or camLost and not (GetInteriorFromPrimaryView() == id and aRoom(id, GetRoomKeyForGameViewport())) and 'the camera'
    if did.things or did.player or did.camera or still then
        print(('[mzb_arena] interior refresh: put back %d placed things%s%s%s'):format(did.things or 0,
            did.player and ', the player' or '', did.camera and (', the camera (%s)'):format(did.camera) or '',
            still and (' - %s is still out of the arena\'s rooms: walk through a doorway or use /arenareset'):format(still) or ''))
    end
    guard.room, guard.at, guard.cam = 0, nil, false
end

local function refresh(id)
    -- (a refresh within another's few seconds goes on with what was seen before the first: by now the player may be
    -- out of the room)
    local ped = PlayerPedId()
    local room = GetInteriorFromEntity(ped) == id and GetRoomKeyFromEntity(ped) or 0
    if aRoom(id, room) then guard.room, guard.at = room, GetEntityCoords(ped) end
    if GetInteriorFromPrimaryView() == id and aRoom(id, GetRoomKeyForGameViewport()) then guard.cam = true end
    RefreshInterior(id)
    guard.id, guard.t0 = id, GetGameTimer()
    guard.till = guard.t0 + GUARD_MS
    if not guard.running then
        guard.running = true
        CreateThread(function()
            local ok, err = pcall(lookAfter)
            guard.running = false
            if not ok then print('[mzb_arena] interior refresh: ' .. tostring(err)) end
        end)
    end
end

-- an interior's sets as the show wants them; refreshed when one changed (or when asked: a newly ready interior)
local function set(id, on, force)
    local changed = force == true
    for s in pairs(managed) do
        local a = isOn(id, s)
        if on[s] and not a then
            ActivateInteriorEntitySet(id, s)
            changed = true
        elseif a and not on[s] then
            DeactivateInteriorEntitySet(id, s)
            changed = true
        end
    end
    if changed then refresh(id) end
end

local function applyShow(name)
    local on = wanted(name)
    local id = MzbInterior()
    if on and id ~= 0 then set(id, on) end
end

AddStateBagChangeHandler('mzbShow', 'global', function(_, _, value)
    Wait(0)
    applyShow(value)
end)

AddStateBagChangeHandler('mzbHideSets', 'global', function()
    Wait(0)
    applyShow(GlobalState.mzbShow or Config.DefaultShow)
end)

-- (client/lights.lua: the desk's house setting changed)
function MzbReapplyShow()
    Wait(0)
    applyShow(GlobalState.mzbShow or Config.DefaultShow)
end

-- The interior streams in and out, and its sets can be lost without a word (the game making the interior again
-- under the number it had; joining again with the game left open). Once a second: an interior seen ready for the
-- first time gets the show, and one that has it is compared with the show and put right when a set is missing or
-- left over. An interior that does not keep the sets is left alone after three tries, with a line in F8.
CreateThread(function()
    local done, lastShow, tries = 0, nil, 0
    while true do
        local id, ready = MzbInterior()
        local show = GlobalState.mzbShow or Config.DefaultShow
        local on = wanted(show)
        if id == 0 then
            done = 0
        elseif on and ready then
            if id ~= done or show ~= lastShow then tries = 0 end
            local ok = matches(id, on)
            if id ~= done or (not ok and tries < 3) then
                set(id, on, id ~= done)
                done = id
                if matches(id, on) then
                    tries = 0
                else
                    tries = tries + 1
                    if tries == 3 then
                        print(('[mzb_arena] interior %d does not keep the sets of "%s" - send /arenainfo'):format(id, show))
                    end
                end
            elseif ok then
                tries = 0
            end
        end
        lastShow = show
        Wait(1000)
    end
end)

-- What a per-show table has for a show, or what it has for the empty house: the screens' model, the light rig and
-- its aim, the speakers and the screens' artwork are looked up through this. A show such a table does not name -
-- the big-floor shows (floor, monster, motocross, karting, sprint, oval, skatepark), a show of the owner's own - is then
-- screened, lit and heard as the empty house is: the centre-hung board and the roof's house lights.
function MzbShowEntry(t, show)
    if type(t) ~= 'table' then return nil end
    local v = MzbShowAs(t, show)                    -- (or the show it stands in for: Config.ShowAs)
    if v == nil then v = t.house end
    return v
end

-- (client/main.lua's /arenainfo) the interiors as the game has them and the show's sets on the arena's
function MzbShowStatus()
    local probe, mine, inside = interiors()
    local id, ready = MzbInterior()
    local show = GlobalState.mzbShow or Config.DefaultShow
    local n, have = 0, 0
    for s in pairs(wanted(show) or {}) do
        n = n + 1
        if id ~= 0 and isOn(id, s) then have = have + 1 end
    end
    return ('interior %d (arena %d, at the probe %d%s, ready %s) | show %s, %d of %d sets on'):format(mine, id, probe,
        (mine ~= 0 and not inside) and ', outside the building' or '', tostring(ready), tostring(show), have, n)
end

-- /arenareset: take the show's pieces down and set them up again, on your own screen only - for an arena that stands
-- bare or half set although /arenainfo counts every set on
RegisterCommand('arenareset', function()
    CreateThread(function()
        local id = MzbInterior()
        local on = wanted(GlobalState.mzbShow or Config.DefaultShow)
        local msg = 'you are not at the arena'
        if id ~= 0 and on then
            set(id, {})
            Wait(500)
            set(id, on)
            msg = 'the show was set up again: ' .. MzbShowStatus()
        end
        print('[mzb_arena] ' .. msg)
        TriggerEvent('chat:addMessage', { args = { 'arena', msg } })
    end)
end, false)
