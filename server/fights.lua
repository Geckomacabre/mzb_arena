-- mzb_arena - server: fights (GlobalState.mzbFight: the bout on now; GlobalState.mzbFightCard: the bouts to come).
-- The server runs every bout: it makes the NPC fighters (networked peds; the client each one belongs to throws its
-- punches - client/fights.lua), rings the rounds and calls the result from what it sees itself - the fighters' health
-- (down at Config.Fights.koHealth) and whether they are in the ring - never from what a client says.
--   GlobalState.mzbFight = { id, state = 'idle' | 'intro' | 'round' | 'break' | 'over', show, round, rounds,
--                            left (ms of this part left when it was sent), red = F, blue = F, winner, how, last }
--     F = { kind = 'npc' | 'player', name, src (a player's server id), net (an NPC's network id) }
--   GlobalState.mzbFightCard = { { red = name, blue = name, inS = s until it starts, or nil: after the one before } }
--   /arenafight [status | card]                       the bout on and the card (anyone)
--   /arenafight challenge [id] | accept               take on an NPC, or a player who accepts (Config.Fights.challenge)
--   /arenafight npc | vs <id> | pvp <id> <id> [in <min>]   a bout on the card (staff, Config.Fights.access)
--   /arenafight stop | clear                          stop the bout on / empty the card (staff)

local FC = Config.Fights or {}
if FC.enabled == false then return end

local AF = Config.ArenaFrame
local CA, SA = math.cos(AF.ang), math.sin(AF.ang)
local CORNERS = { 'red', 'blue' }
local NPC = { kind = 'npc' }

local fight = nil              -- the bout on: { id, show, venue, red = F, blue = F, state, round, untilT, out, winner, how }
local card = {}                -- the bouts to come: { red = D, blue = D, at = server ms or nil, by = src }, D = { kind, src }
local nextId, restUntil, lastResult = 0, 0, nil
local invites, lastChallenge = {}, {}
local heldFor = nil            -- the show the card was last held for (said once)

-- ------------------------------------------------------------------ the arena's frame, the venue
local function world(u, v)
    return AF.x + u * CA - v * SA, AF.y + u * SA + v * CA
end

local function arena(x, y)
    local dx, dy = x - AF.x, y - AF.y
    return dx * CA + dy * SA, -dx * SA + dy * CA
end

-- the GTA heading of someone at (x, y) facing (tx, ty)
local function headingTo(x, y, tx, ty)
    return math.deg(math.atan(-(tx - x), ty - y)) % 360.0
end

local function cornerPos(venue, corner)
    local c = venue[corner] or { 0.0, 0.0 }
    local x, y = world(c[1], c[2])
    return x, y, venue.z
end

local function inRing(venue, c)
    if not venue or not c or math.abs(c.z - venue.z) > 2.5 then return false end
    local u, v = arena(c.x, c.y)
    if venue.shape == 'circle' then return u * u + v * v <= (venue.radius or 4.0) ^ 2 end
    local h = venue.half or 2.8
    return math.abs(u) <= h and math.abs(v) <= h
end

-- ------------------------------------------------------------------ players, fighters
local function online(id)
    id = tonumber(id)
    return id ~= nil and id > 0 and GetPlayerName(tostring(id)) ~= nil
end

local function nameOf(src)
    return GetPlayerName(tostring(src)) or ('player ' .. tostring(src))
end

local function player(id)
    return { kind = 'player', src = tonumber(id) }
end

local function pedOf(f)
    if f.kind == 'player' then return online(f.src) and GetPlayerPed(tostring(f.src)) or 0 end
    return f.ped or 0
end

local function tell(f, msg)
    if f and f.kind == 'player' and online(f.src) then MzbReply(f.src, 'fight', msg) end
end

local function other(corner)
    return corner == 'red' and 'blue' or 'red'
end

local function allowed(src)
    return MzbAllowed(src, FC.access)
end

local throttled = MzbThrottle(250)

-- ------------------------------------------------------------------ the state everyone sees
local function brief(f)
    return f and { kind = f.kind, name = f.name, src = f.src, net = f.net } or nil
end

local function publish()
    if not fight then
        GlobalState.mzbFight = { id = nextId, state = 'idle', last = lastResult }
        return
    end
    GlobalState.mzbFight = { id = fight.id, state = fight.state, show = fight.show, round = fight.round,
                             rounds = FC.rounds or 3, left = math.max(0, fight.untilT - GetGameTimer()),
                             red = brief(fight.red), blue = brief(fight.blue), winner = fight.winner, how = fight.how }
end

local function describe(d)
    return d.kind == 'npc' and 'an NPC' or nameOf(d.src)
end

local function publishCard()
    local now, out = GetGameTimer(), {}
    for _, b in ipairs(card) do
        out[#out + 1] = { red = describe(b.red), blue = describe(b.blue),
                          inS = b.at and math.max(0, math.floor((b.at - now) / 1000)) or nil }
    end
    GlobalState.mzbFightCard = out
end

-- the lights and the crowd go with the bout (Config.Fights.presets / moods)
local function cue(part)
    local p = FC.presets and FC.presets[part]
    if p and MzbLightPreset then MzbLightPreset(p) end
    local m = FC.moods and FC.moods[part]
    if m and MzbCrowdMood then MzbCrowdMood(m) end
end

local function follow(f)
    if FC.followspot and f and f.kind == 'player' and MzbSpotFollow then MzbSpotFollow(f.src) end
end

-- ------------------------------------------------------------------ a bout
local function npcName(id, corner)
    local n = FC.names or {}
    if #n == 0 then return corner == 'red' and 'Red' or 'Blue' end
    return n[(id * 5 + (corner == 'red' and 0 or 3)) % #n + 1]
end

local function deleteNpcs(f)
    for _, corner in ipairs(CORNERS) do
        local x = f and f[corner]
        if x and x.kind == 'npc' and x.ped and DoesEntityExist(x.ped) then DeleteEntity(x.ped) end
    end
end

-- an NPC fighter in its corner, facing the middle: a networked ped (everyone sees the same one), kept when nobody is
-- near (it goes after the bout)
local function makeNpc(f, venue, corner, id)
    local models = FC.models or {}
    if #models == 0 then return false end
    local x, y, z = cornerPos(venue, corner)
    local model = models[(id * 7 + (corner == 'red' and 1 or 4)) % #models + 1]
    local ped = CreatePed(4, GetHashKey(model), x, y, z, headingTo(x, y, AF.x, AF.y), true, true)
    if not ped or ped == 0 then return false end
    local untilT = GetGameTimer() + 3000
    while not DoesEntityExist(ped) and GetGameTimer() < untilT do Wait(50) end
    if not DoesEntityExist(ped) then return false end
    SetEntityOrphanMode(ped, 2)
    f.ped, f.net = ped, NetworkGetNetworkIdFromEntity(ped)
    return true
end

local function startBout(b, now)
    local show = GlobalState.mzbShow or Config.DefaultShow
    local venue = (FC.venues or {})[show]
    nextId = nextId + 1
    local f = { id = nextId, show = show, venue = venue, out = {}, round = 0 }
    for _, corner in ipairs(CORNERS) do
        local d = b[corner]
        if d.kind == 'player' then
            if not online(d.src) then
                MzbReply(b.by or 0, 'fight', 'a bout is off the card: one of its fighters has left')
                return false
            end
            f[corner] = { kind = 'player', src = d.src, name = nameOf(d.src) }
        else
            f[corner] = { kind = 'npc', name = npcName(f.id, corner) }
        end
    end
    for _, corner in ipairs(CORNERS) do
        if f[corner].kind == 'npc' and not makeNpc(f[corner], venue, corner, f.id) then
            deleteNpcs(f)
            MzbReply(b.by or 0, 'fight', 'a bout is off the card: its NPC fighter could not be made')
            return false
        end
    end
    f.state, f.untilT = 'intro', now + (FC.introSeconds or 12) * 1000
    fight = f
    publish()
    cue('intro')
    follow(f.red.kind == 'player' and f.red or f.blue)
    for _, corner in ipairs(CORNERS) do
        tell(f[corner], ('your bout against %s: get in the ring (the %s corner) - the bell goes in %d s')
            :format(f[other(corner)].name, corner, FC.introSeconds or 12))
    end
    print(('[mzb_arena] fight %d: %s (red) vs %s (blue), %s'):format(f.id, f.red.name, f.blue.name, show))
    return true
end

local function finish(winner, how, now)
    local f = fight
    f.state, f.winner, f.how = 'over', winner, how
    f.untilT = now + (FC.overSeconds or 10) * 1000
    local w = winner ~= 'draw' and f[winner] or nil
    lastResult = w and ('%s beat %s (%s)'):format(w.name, f[other(winner)].name, how)
        or ('%s and %s: %s'):format(f.red.name, f.blue.name, how)
    publish()
    cue('over')
    follow(w)
    for _, corner in ipairs(CORNERS) do
        tell(f[corner], winner == 'draw' and ('no winner: %s'):format(how)
            or (winner == corner and ('you won (%s)'):format(how) or ('you lost (%s)'):format(how)))
    end
    print(('[mzb_arena] fight %d: %s'):format(f.id, lastResult))
end

local function startRound(now)
    local f = fight
    f.round, f.state, f.out = f.round + 1, 'round', {}
    f.untilT = now + (FC.roundSeconds or 60) * 1000
    publish()
    if f.round == 1 then cue('round') end
end

-- one look at the bout (every 200 ms)
local function step(now)
    local f = fight
    if f.state == 'over' then
        if now >= f.untilT then
            deleteNpcs(f)
            fight, restUntil = nil, now + (FC.gap or 20) * 1000
            publish()
        end
        return
    end
    -- another show: the ring / cage has gone from under them
    if (GlobalState.mzbShow or Config.DefaultShow) ~= f.show then return finish('draw', 'no contest', now) end
    -- the fighters: still there, in the ring, their health
    local gone, out, health = {}, {}, {}
    for _, corner in ipairs(CORNERS) do
        local ped = pedOf(f[corner])
        if ped == 0 or not DoesEntityExist(ped) then
            gone[corner] = true
        else
            health[corner] = GetEntityHealth(ped)
            -- an NPC no client has run yet has no health to read: it is fresh (its owner never lets it fall below
            -- koHealth - 8, so 0 cannot be a real one)
            if f[corner].kind == 'npc' and health[corner] <= 0 then health[corner] = 200 end
            out[corner] = not inRing(f.venue, GetEntityCoords(ped))
        end
    end
    if gone.red and gone.blue then return finish('draw', 'no contest', now) end
    if gone.red or gone.blue then return finish(gone.red and 'blue' or 'red', 'forfeit', now) end
    if f.state == 'intro' then
        if now < f.untilT then return end
        -- at the bell: a fighter who is not in the ring forfeits
        if out.red and out.blue then return finish('draw', 'no contest', now) end
        if out.red or out.blue then return finish(out.red and 'blue' or 'red', 'forfeit', now) end
        return startRound(now)
    elseif f.state == 'break' then
        if now >= f.untilT then startRound(now) end
        return
    end
    -- a round: a knockout, a count-out, the bell
    local ko = FC.koHealth or 125
    local downR, downB = health.red <= ko, health.blue <= ko
    if downR and downB then
        if health.red == health.blue then return finish('draw', 'double knockout', now) end
        return finish(health.red > health.blue and 'red' or 'blue', 'KO', now)
    end
    if downR or downB then return finish(downR and 'blue' or 'red', 'KO', now) end
    for _, corner in ipairs(CORNERS) do
        if out[corner] then
            f.out[corner] = f.out[corner] or now
            if now - f.out[corner] > (FC.countOut or 10) * 1000 then return finish(other(corner), 'count-out', now) end
        else
            f.out[corner] = nil
        end
    end
    if now >= f.untilT then
        if f.round < (FC.rounds or 3) then
            f.state, f.untilT = 'break', now + (FC.breakSeconds or 15) * 1000
            publish()
        elseif math.abs(health.red - health.blue) <= 2 then
            finish('draw', 'decision', now)
        else
            finish(health.red > health.blue and 'red' or 'blue', 'decision', now)
        end
    end
end

CreateThread(function()
    while true do
        Wait(200)
        local now = GetGameTimer()
        if fight then
            step(now)
        elseif card[1] and now >= (card[1].at or 0) and now >= restUntil then
            -- the next bout: when its time has come, the rest after the last one is over and the show has a ring
            local show = GlobalState.mzbShow or Config.DefaultShow
            if (FC.venues or {})[show] then
                heldFor = nil
                startBout(table.remove(card, 1), now)
                publishCard()
            elseif heldFor ~= show then
                heldFor = show
                MzbReply(card[1].by or 0, 'fight', 'the card waits: bouts are fought in the ring or the cage (/mzb wrestling or /mzb mma)')
            end
        end
    end
end)

-- ------------------------------------------------------------------ the card
local function busy(src)
    if fight and fight.state ~= 'over' then
        for _, corner in ipairs(CORNERS) do
            if fight[corner].kind == 'player' and fight[corner].src == src then return true end
        end
    end
    for _, b in ipairs(card) do
        for _, corner in ipairs(CORNERS) do
            if b[corner].kind == 'player' and b[corner].src == src then return true end
        end
    end
    return false
end

-- a bout on the card: red / blue = NPC or player(id); inMin = minutes from now (nil / 0: after the one before)
local function addBout(red, blue, inMin, by)
    if #card >= (FC.maxCard or 10) then return false, 'the card is full' end
    if red.kind == 'player' and blue.kind == 'player' and red.src == blue.src then
        return false, 'a player cannot fight themselves'
    end
    for _, d in ipairs({ red, blue }) do
        if d.kind == 'player' and busy(d.src) then return false, nameOf(d.src) .. ' is already on the card' end
    end
    inMin = tonumber(inMin)
    if inMin and (inMin ~= inMin or inMin <= 0) then inMin = nil end
    card[#card + 1] = { red = red, blue = blue, by = by,
                        at = inMin and GetGameTimer() + math.floor(math.min(inMin, 240) * 60000) or nil }
    publishCard()
    return true
end

local function stop(src)
    if not fight or fight.state == 'over' then return MzbReply(src, 'fight', 'there is no bout on') end
    local now = GetGameTimer()
    finish('draw', 'stopped', now)
    fight.untilT = now + 3000
    publish()
end

local function status(src)
    local s = GlobalState.mzbFight or {}
    if fight then
        MzbReply(src, 'fight', ('%s (red) vs %s (blue) | %s, round %d of %d'):format(fight.red.name, fight.blue.name,
            fight.state, math.max(1, fight.round), FC.rounds or 3))
    else
        MzbReply(src, 'fight', 'no bout on' .. (s.last and (' | last: ' .. s.last) or ''))
    end
    for i, b in ipairs(card) do
        local when = b.at and ('in %d min'):format(math.max(0, math.ceil((b.at - GetGameTimer()) / 60000))) or 'next'
        MzbReply(src, 'fight', ('%d. %s vs %s (%s)'):format(i, describe(b.red), describe(b.blue), when))
    end
end

local function near(src)
    local ped = GetPlayerPed(tostring(src))
    if ped == 0 then return false end
    local c = GetEntityCoords(ped)
    return #(vector2(c.x, c.y) - vector2(AF.x, AF.y)) < 90.0
end

local function challenge(src, target)
    if src == 0 then return MzbReply(src, 'fight', 'challenge is for players in game') end
    if not FC.challenge and not allowed(src) then return MzbReply(src, 'fight', 'challenges are off') end
    if not near(src) then return MzbReply(src, 'fight', 'come into the arena to fight') end
    local now = GetGameTimer()
    if now - (lastChallenge[src] or -1000000) < (FC.cooldown or 30) * 1000 then
        return MzbReply(src, 'fight', 'wait a moment before the next challenge')
    end
    if target then
        local t = tonumber(target)
        if not online(t) or t == src then return MzbReply(src, 'fight', 'no such player') end
        if busy(t) or busy(src) then return MzbReply(src, 'fight', 'one of you is already on the card') end
        lastChallenge[src] = now
        invites[t] = { from = src, untilT = now + (FC.inviteSeconds or 30) * 1000 }
        MzbReply(t, 'fight', ('%s challenges you to a fight in the ring: /%s accept (%d s)'):format(nameOf(src),
            FC.command or 'arenafight', FC.inviteSeconds or 30))
        return MzbReply(src, 'fight', 'challenge sent to ' .. nameOf(t))
    end
    local ok, err = addBout(player(src), NPC, nil, src)
    if not ok then return MzbReply(src, 'fight', err) end
    lastChallenge[src] = now
    MzbReply(src, 'fight', #card > 1 and ('you are on the card (bout %d)'):format(#card)
        or 'an NPC takes you on: get in the ring')
end

local function accept(src)
    local inv = invites[src]
    invites[src] = nil
    if not inv or GetGameTimer() > inv.untilT then return MzbReply(src, 'fight', 'no challenge to answer') end
    if not online(inv.from) then return MzbReply(src, 'fight', 'they have left') end
    local ok, err = addBout(player(inv.from), player(src), nil, src)
    if not ok then return MzbReply(src, 'fight', err) end
    MzbReply(inv.from, 'fight', nameOf(src) .. ' accepted: get in the ring')
    MzbReply(src, 'fight', 'accepted: get in the ring')
end

local HELP = '/%s [status] | challenge [id] | accept | npc [in <min>] | vs <id> [in <min>] | pvp <id> <id> [in <min>] | ' ..
             'stop | clear'

-- 'in <minutes>' at args[i]
local function inMinutes(args, i)
    if args[i] and args[i]:lower() == 'in' then return tonumber(args[i + 1]) end
    return nil
end

RegisterCommand(FC.command or 'arenafight', function(src, args)
    local sub = args[1] and args[1]:lower()
    if not sub or sub == 'status' or sub == 'card' then return status(src) end
    if sub == 'challenge' then return challenge(src, args[2]) end
    if sub == 'accept' then return accept(src) end
    if not allowed(src) then return MzbReply(src, 'fight', 'you are not allowed to run the fight card') end
    local ok, err
    if sub == 'npc' then
        ok, err = addBout(NPC, NPC, inMinutes(args, 2), src)
    elseif sub == 'vs' and online(args[2]) then
        ok, err = addBout(player(args[2]), NPC, inMinutes(args, 3), src)
    elseif sub == 'pvp' and online(args[2]) and online(args[3]) then
        ok, err = addBout(player(args[2]), player(args[3]), inMinutes(args, 4), src)
    elseif sub == 'stop' then
        return stop(src)
    elseif sub == 'clear' then
        card = {}
        publishCard()
        return MzbReply(src, 'fight', 'the card is clear')
    else
        return MzbReply(src, 'fight', HELP:format(FC.command or 'arenafight'))
    end
    if not ok then return MzbReply(src, 'fight', err) end
    MzbReply(src, 'fight', ('on the card: bout %d'):format(#card))
end, false)

-- the desk's Fights section (html/fights.js): { action = 'add', red, blue = 'npc' | server id, inMin } | stop | clear
RegisterNetEvent('mzb_arena:fight', function(data)
    local src = source
    if type(data) ~= 'table' or not allowed(src) or throttled(src) then return end
    if data.action == 'add' then
        local function fighter(x)
            if x == 'npc' then return NPC end
            if online(x) then return player(x) end
        end
        local red, blue = fighter(data.red), fighter(data.blue)
        if not red or not blue then return MzbReply(src, 'fight', 'pick the two fighters') end
        local ok, err = addBout(red, blue, data.inMin, src)
        MzbReply(src, 'fight', ok and ('on the card: bout %d'):format(#card) or err)
    elseif data.action == 'stop' then
        stop(src)
    elseif data.action == 'clear' then
        card = {}
        publishCard()
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    invites[src], lastChallenge[src] = nil, nil
    for i = #card, 1, -1 do
        local b = card[i]
        if (b.red.kind == 'player' and b.red.src == src) or (b.blue.kind == 'player' and b.blue.src == src) then
            table.remove(card, i)
        end
    end
    publishCard()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    GlobalState.mzbFight = { id = 0, state = 'idle' }
    GlobalState.mzbFightCard = {}
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then deleteNpcs(fight) end
end)

-- other resources (an event script, a betting script) can run the card too: red / blue = 'npc' or a server id
exports('AddBout', function(red, blue, inMin)
    local function fighter(x)
        if x == 'npc' then return NPC end
        if online(x) then return player(x) end
    end
    local r, b = fighter(red), fighter(blue)
    if not r or not b then return false, 'no such fighter' end
    return addBout(r, b, inMin, 0)
end)
exports('StopBout', function() if fight and fight.state ~= 'over' then stop(0) return true end return false end)
exports('GetBout', function() return GlobalState.mzbFight end)
