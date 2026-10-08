-- mzb_arena - client: the crowd (GlobalState.mzbCrowd, server/crowd.lua).
--   * the spots of the show that is up come from the build (client/crowd_slots.lua): the bowl's seats, the stage end
--     when the show seats it, the show's floor chairs or standing floor - less the front rows a big-floor show has
--     folded back and the rows a show keeps closed. Each has a key, its place in the fill order.
--     You see Config.Crowd.MaxPeds of them (/arenacrowd mine <n> changes it for you): the house's best keys, the
--     same for everyone, and a share of them in the seats round you (Config.Crowd.NearShare);
--   * everyone is a local ped (not networked): each player makes their own copy, the same person in the same seat
--     doing the same thing (picked from the spot itself), in the crowd's mood. People with a seat sit in it for the
--     share of the house the mood seats (Config.CrowdMoods[...].sit) and stand in their row for the rest;
--   * the staff and the press come in with them (Config.CrowdStaff from the build, Config.CrowdRoles): first, and not
--     counted against your own number. Their camera / clipboard props are local objects too;
--   * so do the people on the concourse (Config.CrowdConcourse: vendors and their queues, cooks, clerks, guards,
--     medics, cleaners): the ones nearest you, Config.Concourse.MaxPeds at most, in the concourse room.
-- The crowd is only made while you are inside the arena.

local CC = Config.Crowd
local ST = GlobalState.mzbCrowd or Config.CrowdDefault
local KVP = 'mzb_crowd_max'

local function clampCount(n)
    return math.floor(math.max(0, math.min(CC.MaxPedsLimit or 220, n)))
end

local maxPeds = clampCount(tonumber(GetResourceKvpString(KVP) or '') or CC.MaxPeds or 140)

local slots, slotShow = {}, nil   -- the show's spots, best key first
local crowd = {}                  -- [index into slots] = { ped, s, sitting, gen, freezeAt }
local staffSlots = {}             -- the show's staff spots (Config.CrowdStaff)
local staff = {}                  -- [index into staffSlots] = { ped, props = { object, ... }, freezeAt, fade }
local CON = Config.Concourse or {}
local conSlots = (CON.enabled ~= false and Config.CrowdConcourse) or {}   -- the concourse's people, every show
local con = {}                    -- [index into conSlots] = as staff
local conWanted, conList = {}, {} -- the ones near you: [index] = true, and nearest first
local conRoom = GetHashKey('concourse')
local bowlRoom = GetHashKey(CC.Room or 'bowl')
local moodGen = 0                 -- bumped when the mood changes; the crowd picks it up a few at a time
local phases = {}                 -- anims to start at a random point next tick, so the crowd doesn't move in unison
local dirty = true                -- pick the spots again (the show, the count or the crowd itself changed)
local roomKey = CC.Room and GetHashKey(CC.Room) or nil
-- they fade in over Config.Crowd.FadeMs: this much more opaque per step of the manager (nil = they just appear)
local fadeStep = (CC.FadeMs or 0) > 0 and math.max(1, math.floor(255 * (CC.TickMs or 50) / CC.FadeMs)) or nil
local MOOD_SALT = { doors = 11, show = 23, peak = 37, cheer = 51 }

-- ------------------------------------------------------------------ the same picks on every client
-- the same pseudo-random number on every client for (a, b): 0 .. 0x7fffffff
local function hash(a, b)
    local h = (a * 2654435761) ~ (b * 40503) ~ 0x5bd1e995
    h = (h ~ (h >> 13)) * 1274126177
    return (h ~ (h >> 16)) & 0x7fffffff
end

-- 0 .. 1
local function rand(a, b)
    return (hash(a, b) % 100000) / 100000.0
end

-- a weighted pick from { { value, weight }, ... } with r in 0 .. 1
local function weighted(pool, r)
    local total = 0.0
    for _, e in ipairs(pool) do total = total + e[2] end
    local x = r * total
    for _, e in ipairs(pool) do
        x = x - e[2]
        if x < 0.0 then return e[1] end
    end
    return pool[#pool][1]
end

local function loadModel(model, timeout)
    if HasModelLoaded(model) then return true end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local untilT = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(model) do
        if GetGameTimer() > untilT then return false end
        Wait(0)
    end
    return true
end

-- a dictionary that is not in the game, or would not load, is not asked for again: one bad name in the config would
-- otherwise stall the manager five seconds for every ped meant to use it
local badDict = {}

local function loadDict(dict, timeout)
    if HasAnimDictLoaded(dict) then return true end
    if badDict[dict] then return false end
    if not DoesAnimDictExist(dict) then
        badDict[dict] = true
        print(('[mzb_arena] crowd: there is no animation dictionary "%s" (Config.CrowdAnims)'):format(dict))
        return false
    end
    RequestAnimDict(dict)
    local untilT = GetGameTimer() + (timeout or 5000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > untilT then
            badDict[dict] = true
            return false
        end
        Wait(0)
    end
    return true
end

-- ------------------------------------------------------------------ the show's spots
local function showHas(show, set)
    for _, s in ipairs(Config.Shows[show] or {}) do
        if s == set then return true end
    end
    return false
end

-- how deep in the stands a seat is: its distance from the event floor's outline, a rounded rectangle about the
-- arena's middle (Config.Crowd.FloorEdge) - under a metre for the front row, more with every row behind it. The
-- bigger floor's shows fold the front rows away and a show can keep rows closed: both go by this
local AF = Config.ArenaFrame
local FE = CC.FloorEdge or { halfL = 30.0, halfW = 15.0, r = 8.5 }
local AC, AS = math.cos(AF.ang), math.sin(AF.ang)

local function depth(x, y)
    local dx, dy = x - AF.x, y - AF.y
    local qx = math.abs(dx * AC + dy * AS) - (FE.halfL - FE.r)           -- along the arena, past the corner's centre
    local qy = math.abs(-dx * AS + dy * AC) - (FE.halfW - FE.r)          -- across it
    local ox, oy = math.max(qx, 0.0), math.max(qy, 0.0)
    return math.sqrt(ox * ox + oy * oy) + math.min(math.max(qx, qy), 0.0) - FE.r
end

-- a spot: { x, y, z, heading, zone, sit x, sit y, sit z, key } or, without a seat, { x, y, z, heading, zone, key };
-- its key, whether it has a seat, a number of its own (the same on every client: who sits there, what they do) and,
-- for a seat, how deep in the stands it is (d, measured at the seat itself) are worked out once
local function prepare(s)
    if not s.id then
        s.seat = #s >= 9
        s.key = s[#s]
        s.id = math.floor(s[1] * 100.0 + 0.5) * 7919 + math.floor(s[2] * 100.0 + 0.5) * 31 + math.floor(s[3] * 10.0 + 0.5)
        if s.seat then s.d = depth(s[6], s[7]) end
    end
    return s
end

local function buildSlots(show)
    local S = Config.CrowdSlots or {}
    local out = {}
    -- the rows nobody sits in: the lower tier's front rows when the show has them folded back (the bigger floor),
    -- and the rows the show keeps closed (Config.Crowd.ClosedDepth: the truck show's tarped rows)
    local frontDepth = CC.FrontDepth or 6.2
    local folded = showHas(show, CC.FrontStowedSet) and frontDepth or 0.0
    local closed = tonumber((CC.ClosedDepth or {})[show]) or 0.0
    local function open(s)
        local d = s.d or math.huge
        return d >= closed and (s[5] ~= 'l' or d >= folded)
    end
    for _, s in ipairs(S.bowl or {}) do
        if open(prepare(s)) then out[#out + 1] = s end
    end
    -- the stage end: its lower seats are the retractable sections (all there when the show seats them, the rows
    -- behind the front ones when it has only those out, none when they are stowed), its upper ones are behind the
    -- end-stage shows' masking
    local seated, back, masked = showHas(show, CC.SeatedSet), showHas(show, CC.BackSet), showHas(show, CC.MaskSet)
    for _, s in ipairs(S.stage_end or {}) do
        prepare(s)
        local there
        if s[5] == 'l' then there = seated or (back and (s.d or math.huge) >= frontDepth) else there = not masked end
        if there and open(s) then out[#out + 1] = s end
    end
    for _, s in ipairs((S.floor or {})[show] or {}) do out[#out + 1] = prepare(s) end
    table.sort(out, function(a, b) return a.key > b.key end)
    return out
end

-- (client/litter.lua: the litter lies at the same spots)
function MzbCrowdSpots(show)
    return buildSlots(show)
end

-- ------------------------------------------------------------------ peds
local function makePed(model, x, y, z, h, interior, room)
    if not loadModel(model, 3000) then return nil end
    local ped = CreatePed(4, model, x, y, z, h, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then return nil end
    SetEntityHeading(ped, h)
    SetPedRandomComponentVariation(ped, 0)
    SetPedRandomProps(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)
    SetPedCanEvasiveDive(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanBeTargetted(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    if not CC.Collision then SetEntityCollision(ped, false, false) end
    room = room or roomKey
    if room and interior ~= 0 then ForceRoomForEntity(ped, interior, room) end
    return ped
end

local function deletePed(ped)
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
end

-- start an action: a scenario ('s:NAME') or a Config.CrowdAnims key; phase (0..1) starts the anim part-way through.
-- switching = the ped was doing something else: drop it at once (a scenario's phone / drink goes with it).
-- Returns whether it started.
local function perform(ped, act, phase, switching)
    if switching then ClearPedTasksImmediately(ped) end
    if act:sub(1, 2) == 's:' then
        TaskStartScenarioInPlace(ped, act:sub(3), 0, true)
        return true
    end
    local a = Config.CrowdAnims[act]
    if not a then return false end
    local dict, clip = a[1], a[2]
    if a.f and not IsPedMale(ped) then dict, clip = a.f[1], a.f[2] end
    if not loadDict(dict) then return false end
    TaskPlayAnim(ped, dict, clip, 3.0, 3.0, -1, a[3] or 1, 0.0, false, false, false)
    if phase then phases[#phases + 1] = { ped, dict, clip, phase } end
    return true
end

local function applyPhases()
    for _, p in ipairs(phases) do
        if DoesEntityExist(p[1]) and IsEntityPlayingAnim(p[1], p[2], p[3], 3) then
            SetEntityAnimCurrentTime(p[1], p[2], p[3], p[4])
        end
    end
    phases = {}
end

-- ------------------------------------------------------------------ the crowd
local function mood()
    return Config.CrowdMoods[ST.mood] or Config.CrowdMoods.show
end

-- what the person on spot s does in the current mood ('sit' = take the seat)
local function actOf(s)
    local m = mood()
    local salt = MOOD_SALT[ST.mood] or 3
    if s.seat then
        local share = m.sit == true and 1.0 or tonumber(m.sit) or 0.0
        if rand(s.id, salt + 100) < share then return 'sit' end
        return weighted(m.seats, rand(s.id, salt))
    end
    return weighted(m.floor or m.seats, rand(s.id, salt))
end

-- on their feet nobody stands square to the row: a few degrees either way
local function standHeading(s)
    return s[4] + (rand(s.id, 5) - 0.5) * (s.seat and 12.0 or 0.0)
end

local function apply(c)
    local s, ped = c.s, c.ped
    local act = actOf(s)
    if act == 'sit' then
        if not c.sitting then
            -- the seat scenario walks / teleports them onto the seat: let them move, freeze them once they're down
            FreezeEntityPosition(ped, false)
            ClearPedTasksImmediately(ped)
            TaskStartScenarioAtPosition(ped, CC.SeatScenario, s[6], s[7], s[8] + (CC.SitZ or 0.0), s[4], 0, true, true)
            c.sitting, c.freezeAt = true, GetGameTimer() + 2500
        end
    else
        if c.sitting then
            -- up out of the seat, standing in the row
            ClearPedTasksImmediately(ped)
            SetEntityCoords(ped, s[1], s[2], s[3], false, false, false, false)
            SetEntityHeading(ped, standHeading(s))
            FreezeEntityPosition(ped, true)
            c.sitting, c.freezeAt = false, nil
        end
        perform(ped, act, rand(s.id, 97), c.gen ~= nil)
    end
    c.gen = moodGen
end

local function spawnCrowd(i, interior)
    local s = slots[i]
    local own = (CC.ShowModels or {})[slotShow]            -- the show's own mix, if it has one
    local models = (own and #own > 0) and own or CC.Models
    local c = { s = s, sitting = false }
    crowd[i] = c
    c.ped = makePed(GetHashKey(models[(hash(s.id, 7) % #models) + 1]), s[1], s[2], s[3], standHeading(s), interior)
    if c.ped then
        if fadeStep then                                  -- see-through at first: the manager fades them in
            SetEntityAlpha(c.ped, 0, false)
            c.fade = 0
        end
        apply(c)
    end
end

local function deleteCrowd(i)
    local c = crowd[i]
    if c then deletePed(c.ped) end
    crowd[i] = nil
end

-- ------------------------------------------------------------------ the staff and the press
-- a staff spot: { x, y, z, heading, role } or, with a seat, { x, y, z, heading, role, sit x, sit y, sit z }
local function staffId(s)
    if not s.id then
        s.id = math.floor(s[1] * 100.0 + 0.5) * 7919 + math.floor(s[2] * 100.0 + 0.5) * 31 + math.floor(s[3] * 10.0 + 0.5)
    end
    return s.id
end

-- a held prop: { model, ped bone, x, y, z, rx, ry, rz }
local function holdProp(ped, p)
    local m = GetHashKey(p[1])
    if not loadModel(m, 3000) then return nil end
    local c = GetEntityCoords(ped)
    local o = CreateObject(m, c.x, c.y, c.z, false, false, false)
    SetModelAsNoLongerNeeded(m)
    if not o or o == 0 then return nil end
    SetEntityCollision(o, false, false)
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, p[2]), p[3] or 0.0, p[4] or 0.0, p[5] or 0.0, p[6] or 0.0,
        p[7] or 0.0, p[8] or 0.0, true, true, false, true, 1, true)
    return o
end

-- a prop put down in front of spot s: { model, how far ahead, the model's origin over the floor, turn (deg) }
local function standProp(s, st, interior, room)
    local m = GetHashKey(st[1])
    if not loadModel(m, 3000) then return nil end
    local h = math.rad(s[4])
    local ahead = st[2] or 1.0
    local o = CreateObjectNoOffset(m, s[1] - math.sin(h) * ahead, s[2] + math.cos(h) * ahead, s[3] + (st[3] or 0.0),
        false, false, false)
    SetModelAsNoLongerNeeded(m)
    if not o or o == 0 then return nil end
    SetEntityHeading(o, (s[4] + (st[4] or 0.0)) % 360.0)
    FreezeEntityPosition(o, true)
    room = room or roomKey
    if room and interior ~= 0 then ForceRoomForEntity(o, interior, room) end
    return o
end

-- someone in their role on spot s (a staff spot or a concourse spot): their record { ped, props, freezeAt, fade }
local function spawnRole(s, interior, room)
    local role = Config.CrowdRoles and Config.CrowdRoles[s[5]]
    local rec = { props = {} }
    if not role then return rec end
    local id = staffId(s)
    if role.stand then rec.props[#rec.props + 1] = standProp(s, role.stand, interior, room) end
    local models = role.models
    if role.crowd then                                   -- one of the crowd: the show's own mix, if it has one
        local own = (CC.ShowModels or {})[slotShow]
        models = (own and #own > 0) and own or CC.Models
    end
    if not models or #models == 0 then return rec end
    rec.ped = makePed(GetHashKey(models[(hash(id, 13) % #models) + 1]), s[1], s[2], s[3], s[4], interior, room)
    local ped = rec.ped
    if not ped then return rec end
    if fadeStep then
        SetEntityAlpha(ped, 0, false)
        rec.fade = 0
    end
    if #s >= 8 then
        -- a seat (the scorer's table, the umpire's chair ...): down into it as the crowd sits, frozen once they're down
        FreezeEntityPosition(ped, false)
        TaskStartScenarioAtPosition(ped, CC.SeatScenario, s[6], s[7], s[8] + (CC.SitZ or 0.0), s[4], 0, true, true)
        rec.freezeAt = GetGameTimer() + 2500
    elseif perform(ped, weighted(role.acts or { { 'crossarms', 1 } }, rand(id, 29)), rand(id, 43), false) and role.prop then
        rec.props[#rec.props + 1] = holdProp(ped, role.prop)
    end
    if rec.fade then                                      -- their camera fades in with them
        for _, o in ipairs(rec.props) do SetEntityAlpha(o, 0, false) end
    end
    return rec
end

local function deleteRec(rec)
    if not rec then return end
    deletePed(rec.ped)
    for _, o in pairs(rec.props) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
end

local function deleteStaff(j)
    deleteRec(staff[j])
    staff[j] = nil
end

local function deleteCon(j)
    deleteRec(con[j])
    con[j] = nil
end

local function deleteAll()
    for i in pairs(crowd) do deleteCrowd(i) end
    for j in pairs(staff) do deleteStaff(j) end
    for j in pairs(con) do deleteCon(j) end
    phases = {}
end

-- the concourse's people nearest me (staff among them only while the staff are in): conWanted / conList. From the
-- bowl only a few (Config.Concourse.FromBowl): the concourse is behind its walls, the seats get the peds
local function chooseCon(me, withStaff, cap)
    conWanted, conList = {}, {}
    local r2, near = (CON.Radius or 45.0) ^ 2, {}
    for j, s in ipairs(conSlots) do
        local role = Config.CrowdRoles and Config.CrowdRoles[s[5]]
        if role and (withStaff or role.crowd) then
            local dx, dy, dz = s[1] - me.x, s[2] - me.y, s[3] - me.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 < r2 then near[#near + 1] = { j, d2 } end
        end
    end
    table.sort(near, function(a, b) return a[2] < b[2] end)
    for k = 1, math.min(#near, cap or CON.MaxPeds or 36) do
        conWanted[near[k][1]] = true
        conList[k] = near[k][1]
    end
end

-- one step of a ped's fade-in (and of what it holds); c.fade goes once it is opaque
local function fadeIn(c)
    c.fade = c.fade + fadeStep
    local done = c.fade >= 255
    for _, e in ipairs({ c.ped, table.unpack(c.props or {}) }) do
        if done then ResetEntityAlpha(e) else SetEntityAlpha(e, c.fade, false) end
    end
    if done then c.fade = nil end
end

-- ------------------------------------------------------------------ which spots you see
-- Two lots make up your maxPeds. The house: the best spots by key, the same for every player (ringside and the lower
-- rows first, people all round the bowl). And the people round you (Config.Crowd.NearShare of the count): the best of
-- what is left once a spot within NearRadius of you is counted up by as much as NearBoost. A spot that is already
-- filled counts a little more, so two near-equal spots don't swap as you move. No sort: the spots are counted into
-- bins by their score and the bins taken from the top.
local BINS, KEEP = 256, 0.04
local wantedSet, wantedList = {}, {}
local binOf, count = {}, {}

-- the best n spots not yet in wantedSet, added to it and to list; me = score the spots near that point up
local function take(n, me, list)
    if n <= 0 then return end
    local m = #slots
    local boost, radius = me and (CC.NearBoost or 0.6) or 0.0, CC.NearRadius or 45.0
    local scale = BINS / (1.0 + boost + KEEP)
    for b = 0, BINS do count[b] = 0 end
    for i = 1, m do
        local b = -1
        if not wantedSet[i] then
            local s = slots[i]
            local p = s.key
            if me then
                local dx, dy, dz = s[1] - me.x, s[2] - me.y, s[3] - me.z
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d < radius then p = p + boost * (1.0 - d / radius) end
            end
            if crowd[i] then p = p + KEEP end
            b = math.floor(p * scale)
            if b > BINS then b = BINS elseif b < 0 then b = 0 end
            count[b] = count[b] + 1
        end
        binOf[i] = b
    end
    local cut, have = BINS, 0
    while cut >= 0 and have + count[cut] <= n do
        have = have + count[cut]
        cut = cut - 1
    end
    local left = n - have                                   -- the bin on the line fills what is left, best key first
    for i = 1, m do
        local b = binOf[i]
        if b >= 0 and (b > cut or (b == cut and left > 0)) then
            if b == cut then left = left - 1 end
            wantedSet[i] = true
            list[#list + 1] = i
        end
    end
end

local function choose(me)
    local n = math.min(maxPeds, #slots)
    local near = (CC.NearBoost or 0.0) > 0.0 and math.floor(n * (CC.NearShare or 0.5) + 0.5) or 0
    local house, round = {}, {}
    wantedSet = {}
    take(n - near, nil, house)
    take(near, me, round)
    -- the people round you come in first
    wantedList = round
    for _, i in ipairs(house) do wantedList[#wantedList + 1] = i end
end

-- ------------------------------------------------------------------ the manager
AddStateBagChangeHandler('mzbCrowd', 'global', function(_, _, value)
    local before = ST.mood
    ST = value or Config.CrowdDefault
    if ST.mood ~= before then moodGen = moodGen + 1 end
    dirty = true
    MzbCrowdDesk()
end)

CreateThread(function()
    local present = false
    local lastPick, lastPos, poolWait, conStaff, inBowl = 0, nil, 0, nil, nil
    while true do
        applyPhases()
        local now = GetGameTimer()
        local ped = PlayerPedId()
        local me = GetEntityCoords(ped)
        local id = 0
        if ST.on and maxPeds > 0 then
            local ready
            id, ready = MzbInterior()
            -- in the arena: they come in; outside it and far away (or the interior gone): they go
            if ready and GetInteriorFromEntity(ped) == id then
                present = true
            elseif not ready or #(me - Config.InteriorProbe) > (CC.DespawnDistance or 160.0) then
                present = false
            end
        else
            present = false
        end
        -- another show: other seats, another floor, other staff
        local show = GlobalState.mzbShow or Config.DefaultShow
        if present and show ~= slotShow then
            deleteAll()
            slots, slotShow, dirty = buildSlots(show), show, true
            staffSlots = (Config.CrowdStaff or {})[show] or {}
        end
        if not present or #slots == 0 then
            if next(crowd) or next(staff) or next(con) then deleteAll() end
            dirty = true
            Wait(500)
        else
            -- the staff: with the crowd, unless they have been sent home (/arenacrowd staff off) or are off for good
            local withStaff = Config.CrowdStaffEnabled ~= false and ST.staff ~= false
            if not withStaff and next(staff) then
                for j in pairs(staff) do deleteStaff(j) end
            end
            -- who you see: picked again when something changed, or you have moved a few steps
            local bowl = GetRoomKeyFromEntity(ped) == bowlRoom
            if dirty or (now - lastPick > 1500 and #(me - lastPos) > 3.0) or (withStaff ~= conStaff) or bowl ~= inBowl then
                choose(me)
                chooseCon(me, withStaff, bowl and (CON.FromBowl or 8) or nil)
                lastPick, lastPos, dirty, conStaff, inBowl = now, me, false, withStaff, bowl
                for i in pairs(crowd) do
                    if not wantedSet[i] then deleteCrowd(i) end
                end
                for j in pairs(con) do
                    if not conWanted[j] then deleteCon(j) end
                end
            end
            -- a few come in per step (the staff first, then the concourse round you, then the house), as long as the
            -- game has room for more peds
            if now >= poolWait then
                local todo, budget = {}, CC.PerTick or 5
                if withStaff then
                    for j = 1, #staffSlots do
                        if #todo >= budget then break end
                        if not staff[j] then todo[#todo + 1] = { 's', j } end
                    end
                end
                for _, j in ipairs(conList) do
                    if #todo >= budget then break end
                    if not con[j] then todo[#todo + 1] = { 'c', j } end
                end
                for _, i in ipairs(wantedList) do
                    if #todo >= budget then break end
                    if not crowd[i] then todo[#todo + 1] = { 'p', i } end
                end
                if #todo > 0 then
                    if #GetGamePool('CPed') >= (CC.PoolLimit or 236) then
                        poolWait = now + 3000
                    else
                        for _, k in ipairs(todo) do
                            if k[1] == 's' then staff[k[2]] = spawnRole(staffSlots[k[2]], id)
                            elseif k[1] == 'c' then con[k[2]] = spawnRole(conSlots[k[2]], id, conRoom)
                            else spawnCrowd(k[2], id) end
                        end
                    end
                end
            end
            -- a new mood: a dozen people at a time pick it up; the seated freeze once they're down; the new fade in
            local retask = 12
            now = GetGameTimer()
            for _, group in ipairs({ crowd, staff, con }) do
                for _, c in pairs(group) do
                    if c.ped then
                        if group == crowd and c.gen ~= moodGen and retask > 0 then
                            apply(c)
                            retask = retask - 1
                        end
                        if c.freezeAt and now > c.freezeAt then
                            FreezeEntityPosition(c.ped, true)
                            c.freezeAt = nil
                        end
                        if c.fade then fadeIn(c) end
                    end
                end
            end
            Wait(CC.TickMs or 50)
        end
    end
end)

-- ------------------------------------------------------------------ your own crowd size, the desk
local function setMine(n)
    maxPeds = clampCount(n)
    SetResourceKvp(KVP, tostring(maxPeds))
    dirty = true
    MzbCrowdDesk()
end

-- (server/crowd.lua: /arenacrowd mine [n], and the status line's "you see")
RegisterNetEvent('mzb_arena:crowdMine', function(n)
    if tonumber(n) then setMine(tonumber(n)) end
    TriggerEvent('chat:addMessage', { args = { 'crowd', ('you see up to %d people (/%s mine 0-%d)'):format(maxPeds,
        Config.CrowdCommand, CC.MaxPedsLimit or 220) } })
end)

-- the desk's Crowd section (html/crowd.js): what the crowd is doing and your own count
function MzbCrowdDesk()
    SendNUIMessage({ type = 'crowd', state = ST, mine = maxPeds, limit = CC.MaxPedsLimit or 220,
                     moods = Config.CrowdMoodOrder or { 'doors', 'show', 'peak', 'cheer' },
                     staff = Config.CrowdStaffEnabled ~= false, litter = (Config.Litter or {}).enabled ~= false })
end

RegisterNetEvent('mzb_arena:lightsDesk', MzbCrowdDesk)         -- the desk opens (client/lights.lua opens it)

RegisterNUICallback('crowd', function(data, cb)
    TriggerServerEvent('mzb_arena:crowd', data)
    cb('ok')
end)

RegisterNUICallback('crowdMine', function(data, cb)
    if type(data) == 'table' and tonumber(data.n) then setMine(tonumber(data.n)) end
    cb('ok')
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. Config.CrowdCommand, 'Maze Bank Arena: the crowd',
        { { name = 'sub', help = 'on | off | toggle | mood <doors|show|peak|cheer> | staff <on|off> | litter <clean|some|trashed> | ' ..
            'status (staff)   mine <0-' ..
            (CC.MaxPedsLimit or 220) .. '>: how many you see (anyone, saved)' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deleteAll()
    TriggerEvent('chat:removeSuggestion', '/' .. Config.CrowdCommand)
end)
