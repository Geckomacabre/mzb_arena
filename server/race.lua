-- mzb_arena - server: the race on the track of the show that is up (Config.Race; the tracks: Config.Races,
-- shared/races.lua). One race at a time, and the server runs it:
--   idle -> signup (the first to join at the event desk opens it; it closes after Config.Race.signup seconds, or
--   when that player starts it) -> countdown (everyone on the grid in the order they joined, held there) -> running
--   -> finished (the result stands for a moment) -> idle
--   GlobalState.mzbRace = { id, state, show, label, laps, host (the first entrant's server id), left (ms of this
--                           part left when it was sent), racers = { { src, name } ... }, last (the last result) }
-- A racer's game says which checkpoint it has passed (client/race.lua); only the next one in order counts, and only
-- with the racer's ped near it as the server sees it. The positions, the times, who has won, who is out: all here.
-- The racers get the standings as mzb_arena:raceStandings; the players at the arena are told when a sign-up opens,
-- when the race starts and who won it. Fee and prize go through the bridge (server/bridge.lua).
--   /arenarace [status]          the race on (anyone)
--   /arenarace start | cancel    close the sign-up and go / call it off (staff, Config.Race.access)

local RC = Config.Race or {}
if RC.enabled == false then return end

local TRACKS = type(Config.Races) == 'table' and Config.Races or {}
local DC = Config.EventDesk or {}
local GRID_SECONDS = 3           -- on the grid before the countdown: the racers' games make their vehicles
local RESULT_SECONDS = 10        -- the result stands this long before the next sign-up can open
local SLACK = 25.0               -- m round a checkpoint's own radius: the server sees a racer a moment late

local race = nil                 -- nil: idle. { id, show, track, state, untilT, goAt, total, entrants = { E ... },
                                 --   bySrc = { [src] = E }, finished = how many have, winnerAt, models = { [hash] = true } }
                                 -- E = { src, name, paid, slot, done, at, time, place, out = 'dnf' | 'retired', net }
local nextId, lastResult = 0, nil
local dirty = false              -- the standings changed: the racers are sent them at the next look

local function show() return GlobalState.mzbShow or Config.DefaultShow end

local function clock(ms)
    return ('%d:%05.2f'):format(ms // 60000, (ms % 60000) / 1000.0)
end

-- ------------------------------------------------------------------ who is told what
local function publish()
    if not race then
        GlobalState.mzbRace = { id = nextId, state = 'idle', last = lastResult }
        return
    end
    local racers = {}
    for i, e in ipairs(race.entrants) do racers[i] = { src = e.src, name = e.name } end
    GlobalState.mzbRace = { id = race.id, state = race.state, show = race.show, label = race.track.label,
                            laps = race.track.laps, host = race.entrants[1] and race.entrants[1].src or 0,
                            left = math.max(0, (race.untilT or 0) - GetGameTimer()), racers = racers, last = lastResult }
end

-- the players in or at the arena
local function announce(msg)
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped and ped ~= 0 and #(GetEntityCoords(ped) - Config.Screens.origin) < 150.0 then
            MzbNotify(tonumber(id), msg)
        end
    end
end

-- the order they are in: the finishers as they came in, then whoever is furthest round (the earlier there, the
-- higher), then the ones who are out
local function standings()
    local order = {}
    for i, e in ipairs(race.entrants) do order[i] = e end
    table.sort(order, function(a, b)
        if (a.place or 0) ~= (b.place or 0) then return (a.place or 1e9) < (b.place or 1e9) end
        if (a.out ~= nil) ~= (b.out ~= nil) then return b.out ~= nil end
        if a.done ~= b.done then return a.done > b.done end
        if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) < (b.at or 0) end
        return a.slot < b.slot
    end)
    return order
end

local function sendStandings()
    dirty = false
    local out = {}
    for i, e in ipairs(standings()) do
        out[i] = { src = e.src, name = e.name, done = e.done, time = e.time or false, out = e.out or false }
    end
    for _, e in ipairs(race.entrants) do
        if not e.gone then TriggerClientEvent('mzb_arena:raceStandings', e.src, race.id, out) end
    end
end

-- ------------------------------------------------------------------ the vehicles
-- A racer's game makes its own vehicle and says which it is (its network id). The server takes away the ones left
-- behind: a racer who has gone from the server, a game that did not clean up. What it is told is not taken on
-- trust: only a vehicle of the track's own models, at the arena, is ever deleted.
local function modelSet(track)
    local set = {}
    for _, names in ipairs({ track.vehicles or {}, track.fallback or {} }) do
        for _, name in ipairs(names) do set[GetHashKey(name) & 0xFFFFFFFF] = true end
    end
    return set
end

local function takeVehicle(r, e)
    local net = e.net
    e.net = nil
    if not net then return end
    local veh = NetworkGetEntityFromNetworkId(net)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    if not r.models[GetEntityModel(veh) & 0xFFFFFFFF] then return end
    if #(GetEntityCoords(veh) - Config.Screens.origin) > 200.0 then return end
    DeleteEntity(veh)
end

-- a while after a race is over: by then every game has taken its own away
local function sweepLater(r)
    SetTimeout(5000, function()
        for _, e in ipairs(r.entrants) do takeVehicle(r, e) end
    end)
end

-- ------------------------------------------------------------------ the race
local function refund(e)
    if (e.paid or 0) > 0 then
        Bridge.reward(e.src, e.paid, 'Maze Bank Arena: race entry back')
        e.paid = 0
    end
end

-- called off before it has a result: the fees go back, the racers' games take them off the track
local function cancel(why)
    local r = race
    if not r then return false end
    for _, e in ipairs(r.entrants) do
        if not e.gone then
            refund(e)
            TriggerClientEvent('mzb_arena:raceDone', e.src, r.id, { cancelled = why })
        end
    end
    race = nil
    publish()
    sweepLater(r)
    print(('[mzb_arena] race %d (%s) called off: %s'):format(r.id, r.track.label, why))
    return true
end

-- everyone has finished or is out: the result
local function finish(now)
    local r = race
    r.state, r.untilT = 'finished', now + RESULT_SECONDS * 1000
    local parts = {}
    for _, e in ipairs(standings()) do
        if not e.time and not e.out then
            e.out = 'dnf'
            if not e.gone then TriggerClientEvent('mzb_arena:raceDone', e.src, r.id, { out = 'dnf' }) end
        end
        parts[#parts + 1] = e.time and ('%d. %s %s'):format(e.place, e.name, clock(e.time))
            or ('%s %s'):format(e.name, e.out == 'retired' and 'retired' or 'DNF')
    end
    lastResult = r.track.label .. ': ' .. table.concat(parts, ', ')
    publish()
    sendStandings()
    print('[mzb_arena] race ' .. r.id .. ' - ' .. lastResult)
end

local function allDone()
    for _, e in ipairs(race.entrants) do
        if not e.time and not e.out then return false end
    end
    return true
end

-- the sign-up is closed: everyone to the grid, in the order they joined
local function grid(now)
    local r = race
    local countdown = math.max(1, math.floor(tonumber(RC.countdown) or 5))
    r.state, r.goAt = 'countdown', now + (GRID_SECONDS + countdown) * 1000
    r.untilT = r.goAt
    for i, e in ipairs(r.entrants) do
        e.slot = i
        TriggerClientEvent('mzb_arena:raceGrid', e.src, { id = r.id, show = r.show, slot = i, countdown = countdown,
                                                         goAt = r.goAt, goIn = r.goAt - now })
    end
    publish()
    announce(('%s: %d on the grid, %d laps - the start is in %d s'):format(r.track.label, #r.entrants, r.track.laps,
        GRID_SECONDS + countdown))
    print(('[mzb_arena] race %d: %s, %d on the grid'):format(r.id, r.track.label, #r.entrants))
end

local function go(now)
    race.state = 'running'
    race.untilT = race.goAt + math.max(30, tonumber(RC.timeout) or 900) * 1000
    publish()
    sendStandings()
end

local function finishRacer(e, now)
    local r = race
    r.finished = r.finished + 1
    e.time, e.place = now - r.goAt, r.finished
    TriggerClientEvent('mzb_arena:raceDone', e.src, r.id, { place = e.place, time = e.time, of = #r.entrants })
    if e.place == 1 then
        r.winnerAt = now
        local prize = math.floor(tonumber(RC.prize) or 0)
        if prize > 0 and Bridge.reward(e.src, prize, 'Maze Bank Arena: race prize') then
            MzbNotify(e.src, ('the winner\'s prize is yours: $%d'):format(prize))
        end
        announce(('%s wins the %s in %s'):format(e.name, r.track.label, clock(e.time)))
    end
end

-- one look at the race (four a second)
local function step(now)
    local r = race
    if r.state ~= 'finished' and show() ~= r.show then return cancel('the show has changed') end
    if r.state == 'signup' then
        if now >= r.untilT then
            if #r.entrants >= math.max(1, tonumber(RC.minPlayers) or 1) then return grid(now) end
            return cancel('not enough racers signed up')
        end
    elseif r.state == 'countdown' then
        if allDone() then return finish(now) end
        if now >= r.goAt then go(now) end
    elseif r.state == 'running' then
        local late = r.winnerAt and now >= r.winnerAt + math.max(0, tonumber(RC.dnf) or 240) * 1000
        if allDone() or late or now >= r.untilT then return finish(now) end
        if dirty then sendStandings() end
    elseif now >= r.untilT then
        race = nil
        publish()
        sweepLater(r)
    end
end

CreateThread(function()
    while true do
        Wait(250)
        if race then step(GetGameTimer()) end
    end
end)

-- ------------------------------------------------------------------ joining, leaving
local function join(src)
    local name = show()
    local track = TRACKS[name]
    if type(track) ~= 'table' or type(track.grid) ~= 'table' or type(track.checkpoints) ~= 'table' then
        return MzbNotify(src, 'there is no race at this show')
    end
    if race and race.state ~= 'signup' then return MzbNotify(src, 'a race is on: sign up for the next one') end
    if race and race.bySrc[src] then return MzbNotify(src, 'you are on the list already') end
    if race and #race.entrants >= #track.grid then return MzbNotify(src, 'the grid is full') end
    if DC.enabled ~= false and type(DC.ped) == 'table' and not MzbNear(src, DC.ped.coords, 8.0) then
        return MzbNotify(src, 'sign up at the event desk')
    end
    local fee = math.max(0, math.floor(tonumber(RC.fee) or 0))
    if fee > 0 then
        local ok, err = Bridge.pay(src, fee, 'Maze Bank Arena: race entry')
        if not ok then return MzbNotify(src, err or 'the entry fee could not be taken') end
    end
    local seconds = math.max(5, math.floor(tonumber(RC.signup) or 45))
    local opened = not race
    if opened then
        nextId = nextId + 1
        race = { id = nextId, show = name, track = track, state = 'signup', entrants = {}, bySrc = {}, finished = 0,
                 untilT = GetGameTimer() + seconds * 1000, total = track.laps * #track.checkpoints,
                 models = modelSet(track) }
    end
    local e = { src = src, name = GetPlayerName(tostring(src)) or ('player ' .. src), paid = fee, done = 0,
                slot = #race.entrants + 1 }
    race.entrants[#race.entrants + 1] = e
    race.bySrc[src] = e
    publish()
    if opened then
        announce(('%s: the sign-up is open at the event desk for %d s'):format(track.label, seconds))
        MzbNotify(src, ('you are first on the grid: the race starts in %d s, or when you start it at the desk'):format(seconds))
    else
        MzbNotify(src, ('you are in: grid slot %d'):format(#race.entrants))
    end
end

-- src leaves: off the list while the sign-up is open (the fee goes back), retired once the race is on.
-- gone = they have left the server
local function leave(src, gone)
    local r = race
    local e = r and r.bySrc[src]
    if not e then return end
    if gone then e.gone = true end
    if r.state == 'signup' then
        for i, x in ipairs(r.entrants) do
            if x == e then table.remove(r.entrants, i) break end
        end
        r.bySrc[src] = nil
        if not gone then
            refund(e)
            MzbNotify(src, 'you are off the list')
        end
        if #r.entrants == 0 then race = nil end
        publish()
    elseif r.state ~= 'finished' then
        if not e.time and not e.out then
            e.out, dirty = 'retired', true
            if not gone then TriggerClientEvent('mzb_arena:raceDone', src, r.id, { out = 'retired' }) end
        end
        if gone then takeVehicle(r, e) end
    elseif gone then
        takeVehicle(r, e)
    end
end

-- the first entrant (or staff: any = true) closes the sign-up and goes
local function start(src, any)
    local r = race
    if not r or r.state ~= 'signup' then return false, 'there is no sign-up open' end
    if not any and (not r.entrants[1] or r.entrants[1].src ~= src) then
        return false, 'the first on the list starts the race'
    end
    if #r.entrants < math.max(1, tonumber(RC.minPlayers) or 1) then
        return false, ('the race needs %d racers'):format(tonumber(RC.minPlayers) or 1)
    end
    grid(GetGameTimer())
    return true
end

local throttled = MzbThrottle(400)

RegisterNetEvent('mzb_arena:raceJoin', function()
    local src = source
    if not throttled(src) then join(src) end
end)

RegisterNetEvent('mzb_arena:raceLeave', function()
    local src = source
    leave(src, false)
end)

RegisterNetEvent('mzb_arena:raceStart', function()
    local src = source
    if throttled(src) then return end
    local ok, err = start(src, false)
    if not ok then MzbNotify(src, err) end
end)

-- a racer's game has made its vehicle (looked at only when there is something to take away: takeVehicle)
RegisterNetEvent('mzb_arena:raceVehicle', function(net)
    local e = race and race.bySrc[source]
    if e and math.type(net) == 'integer' and net > 0 then e.net = net end
end)

-- a racer's game has passed a checkpoint: n = how many it has passed in all. Only the next one counts, with the race
-- on and the racer near it; a game that is out of step is told where it is
RegisterNetEvent('mzb_arena:raceCp', function(n)
    local src = source
    local r = race
    local e = r and r.bySrc[src]
    if not e or e.time or e.out then return end
    local now = GetGameTimer()
    if r.state == 'countdown' and now >= r.goAt then go(now) end
    local ok = r.state == 'running' and math.type(n) == 'integer' and n == e.done + 1
    if ok then
        local cps = r.track.checkpoints
        local cp = cps[(n - 1) % #cps + 1]
        local ped = GetPlayerPed(tostring(src))
        local p = ped and ped ~= 0 and GetEntityCoords(ped)
        ok = p and #(vector2(p.x, p.y) - vector2(cp.x, cp.y)) <= (tonumber(r.track.radius) or 4.0) + SLACK or false
    end
    if not ok then return TriggerClientEvent('mzb_arena:raceSync', src, r.id, e.done) end
    e.done, e.at, dirty = n, now, true
    if n >= r.total then
        finishRacer(e, now)
        if allDone() then finish(now) end
    end
end)

AddEventHandler('playerDropped', function()
    leave(source, true)
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then GlobalState.mzbRace = { id = 0, state = 'idle' } end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not race then return end
    for _, e in ipairs(race.entrants) do
        if race.state == 'signup' then refund(e) end
        takeVehicle(race, e)
    end
end)

-- ------------------------------------------------------------------ chat, other resources
local function status(src)
    local r = race
    if not r then return MzbReply(src, 'race', 'no race on' .. (lastResult and (' | last: ' .. lastResult) or '')) end
    local names = {}
    for i, e in ipairs(r.entrants) do names[i] = e.name end
    MzbReply(src, 'race', ('%s, %d laps | %s | %s'):format(r.track.label, r.track.laps, r.state, table.concat(names, ', ')))
end

RegisterCommand(RC.command or 'arenarace', function(src, args)
    local sub = args[1] and tostring(args[1]):lower()
    if not sub or sub == 'status' then return status(src) end
    if not MzbAllowed(src, RC.access) then return MzbReply(src, 'race', 'you are not allowed to run the arena\'s races') end
    if sub == 'start' then
        local ok, err = start(src, true)
        MzbReply(src, 'race', ok and 'the sign-up is closed: to the grid' or err)
    elseif sub == 'cancel' or sub == 'stop' then
        MzbReply(src, 'race', cancel('called off by the staff') and 'the race is off' or 'there is no race to call off')
    else
        MzbReply(src, 'race', ('/%s [status] | start | cancel'):format(RC.command or 'arenarace'))
    end
end, false)

-- other resources: an event script that wants to know, or to clear the track
exports('GetRace', function() return GlobalState.mzbRace end)
exports('CancelRace', function() return cancel('called off') end)
