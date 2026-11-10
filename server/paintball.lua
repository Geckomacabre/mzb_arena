-- mzb_arena - server: paintball (Config.Paintball; the arena: the paintball show's set, arena_build/ar_paintball.py).
-- One match at a time, and the server runs it:
--   idle -> signup (the first to join opens it for Config.Paintball.signup seconds) -> countdown (everyone held in
--   their start box) -> live (a hit puts a player out; the last team standing takes the round) -> between (the score,
--   then the next round's countdown) -> over (the result stands a moment) -> idle
--   GlobalState.mzbPaintball = { id, state, map, label, wins, round, score = { red, blue }, left (ms of this part left
--                                when it was sent), players = { ['<src>'] = { team, name, out } }, last (a line) }
-- A hit is told by the player who was hit (their game sees the ball land: client/paintball.lua) and only counts when
-- the server agrees: the round is live, both are in it and standing, on opposite teams (unless friendly fire), the
-- weapon is the marker, the shooter is near enough. Who is out, who has won: all here.
--   /arenapaintball [status] | join [red|blue] | leave     anyone
--   /arenapaintball start [map] [wins] | stop              the staff (Config.Paintball.access)

local PB = Config.Paintball or {}
if PB.enabled == false then return end

local TEAMS = { 'red', 'blue' }
local RESULT_SECONDS = 10

local match = nil                -- nil: idle. { id, state, map, mapName, wins, round, score, untilT, players = { [src] = P },
                                 --   order = { src ... } } P = { src, team, name, out, hits, tagged }
local nextId, lastResult = 0, nil

local function show() return GlobalState.mzbShow or Config.DefaultShow end
local function other(team) return team == 'red' and 'blue' or 'red' end
local function label(team) return ((PB.teams or {})[team] or {}).label or team:upper() end

local function online(id)
    id = tonumber(id)
    return id ~= nil and id > 0 and GetPlayerName(tostring(id)) ~= nil
end

-- ------------------------------------------------------------------ who is told what
local function publish()
    if not match then
        GlobalState.mzbPaintball = { id = nextId, state = 'idle', last = lastResult }
        return
    end
    local players = {}
    for src, p in pairs(match.players) do players[tostring(src)] = { team = p.team, name = p.name, out = p.out == true } end
    GlobalState.mzbPaintball = { id = match.id, state = match.state, map = match.mapName, label = match.map.label,
                                 wins = match.wins, round = match.round, score = { red = match.score.red,
                                 blue = match.score.blue }, left = math.max(0, (match.untilT or 0) - GetGameTimer()),
                                 players = players, last = lastResult }
end

local function near(src, m)
    local ped = GetPlayerPed(tostring(src))
    return ped and ped ~= 0 and #(GetEntityCoords(ped) - Config.Screens.origin) < (m or 150.0)
end

-- the players in or at the arena
local function announce(msg)
    for _, id in ipairs(GetPlayers()) do
        if near(id) then MzbNotify(tonumber(id), msg) end
    end
end

local function cue(what)
    local look = PB.lights and PB.lights[what]
    if look and MzbLightPreset then MzbLightPreset(look) end
    if what ~= 'start' and MzbCrowdMood then MzbCrowdMood('cheer') end
end

local function count(team, standing)
    local n = 0
    for _, p in pairs(match.players) do
        if p.team == team and (not standing or not p.out) then n = n + 1 end
    end
    return n
end

-- ------------------------------------------------------------------ the places
-- a player's spot: the n-th of their team's start (or dead) spots, in the world, facing the map's middle
local function spot(team, kind, n)
    local m = match.map
    local list = (m[team] or {})[kind] or {}
    local s = list[((n - 1) % math.max(1, #list)) + 1] or { 0.0, 0.0 }
    local AF = Config.ArenaFrame
    local c, sn = math.cos(AF.ang), math.sin(AF.ang)
    local x, y = AF.x + s[1] * c - s[2] * sn, AF.y + s[1] * sn + s[2] * c
    local f = m.face or { 0.0, 0.0 }
    local fx, fy = AF.x + f[1] * c - f[2] * sn, AF.y + f[1] * sn + f[2] * c
    return { x = x, y = y, z = AF.z + (m.z or 0.0), h = math.deg(math.atan(-(fx - x), fy - y)) % 360.0 }
end

local function place(kind)
    local n = { red = 0, blue = 0 }
    for _, src in ipairs(match.order) do
        local p = match.players[src]
        if p then
            n[p.team] = n[p.team] + 1
            TriggerClientEvent('mzb_arena:pbPlace', src, spot(p.team, kind, n[p.team]), kind == 'start')
        end
    end
end

-- ------------------------------------------------------------------ the match
local function finish(winner, why)
    local m = match
    for src in pairs(m.players) do TriggerClientEvent('mzb_arena:pbEnd', src) end
    if winner then
        lastResult = ('%s won %d-%d on %s'):format(label(winner), m.score[winner], m.score[other(winner)], m.map.label)
        announce(('PAINTBALL: %s'):format(lastResult))
        cue('win')
    else
        lastResult = 'called off: ' .. (why or 'stopped')
        announce('paintball ' .. lastResult)
    end
    m.state, m.untilT = 'over', GetGameTimer() + RESULT_SECONDS * 1000
    publish()
end

local function countdown(now)
    match.round = match.round + 1
    for _, p in pairs(match.players) do p.out = false end
    match.state, match.untilT = 'countdown', now + math.max(1, tonumber(PB.countdown) or 5) * 1000
    place('start')
    for src, p in pairs(match.players) do TriggerClientEvent('mzb_arena:pbArm', src, p.team) end
    publish()
end

local function cancel(why)
    if not match or match.state == 'over' then return false end
    finish(nil, why)
    return true
end

local function roundOver(now, winner)
    local m = match
    if winner then
        m.score[winner] = m.score[winner] + 1
        announce(('paintball, round %d: %s (%d-%d)'):format(m.round, label(winner), m.score.red, m.score.blue))
        cue('point')
    else
        announce(('paintball, round %d: a draw (%d-%d)'):format(m.round, m.score.red, m.score.blue))
    end
    if winner and m.score[winner] >= m.wins then return finish(winner) end
    m.state, m.untilT = 'between', now + math.max(1, tonumber(PB.between) or 8) * 1000
    publish()
end

local function start(src, mapName, wins)
    if not match or match.state ~= 'signup' then return false, 'nobody has signed up for paintball' end
    if count('red') < 1 or count('blue') < 1 then return false, 'both teams need someone first' end
    if mapName then
        if not (PB.maps or {})[mapName] then
            local names = {}
            for k in pairs(PB.maps or {}) do names[#names + 1] = k end
            table.sort(names)
            return false, 'no such map: ' .. table.concat(names, ', ')
        end
        match.mapName, match.map = mapName, PB.maps[mapName]
    end
    if tonumber(wins) then match.wins = math.max(1, math.min(9, math.floor(tonumber(wins)))) end
    announce(('PAINTBALL on %s: %s %d v %d %s, first to %d'):format(match.map.label, label('red'), count('red'),
                                                                   count('blue'), label('blue'), match.wins))
    cue('start')
    countdown(GetGameTimer())
    return true
end

local function step(now)
    local m = match
    if m.state ~= 'over' and show() ~= (PB.show or 'paintball') then return cancel('the show has changed') end
    -- someone gone from the arena: out of the match
    if m.state ~= 'over' then
        for src in pairs(m.players) do
            if not online(src) or not near(src, 160.0) then
                m.players[src] = nil
                for i, s in ipairs(m.order) do if s == src then table.remove(m.order, i) break end end
                TriggerClientEvent('mzb_arena:pbEnd', src)
            end
        end
        if m.state ~= 'signup' and (count('red') < 1 or count('blue') < 1) then
            return finish(nil, ('%s has nobody left'):format(label(count('red') < 1 and 'red' or 'blue')))
        end
    end
    if m.state == 'signup' then
        if now >= m.untilT then
            local ok, err = start(0)
            if not ok then cancel(err) end
        end
    elseif m.state == 'countdown' then
        if now >= m.untilT then
            m.state, m.untilT = 'live', now + math.max(10, tonumber(PB.roundTime) or 180) * 1000
            for src in pairs(m.players) do TriggerClientEvent('mzb_arena:pbGo', src) end
            publish()
        end
    elseif m.state == 'live' then
        local r, b = count('red', true), count('blue', true)
        if r == 0 or b == 0 then return roundOver(now, r > 0 and 'red' or (b > 0 and 'blue' or nil)) end
        if now >= m.untilT then return roundOver(now, r > b and 'red' or (b > r and 'blue' or nil)) end
    elseif m.state == 'between' then
        if now >= m.untilT then countdown(now) end
    elseif m.state == 'over' and now >= m.untilT then
        match = nil
        publish()
    end
end

CreateThread(function()
    while true do
        Wait(250)
        if match then step(GetGameTimer()) end
    end
end)

-- ------------------------------------------------------------------ joining, leaving
local function join(src, team)
    if show() ~= (PB.show or 'paintball') then return MzbNotify(src, 'paintball is played in the paintball show') end
    if not near(src, 120.0) then return MzbNotify(src, 'come to the arena to play paintball') end
    if match and match.state ~= 'signup' then
        return MzbNotify(src, match.state == 'over' and 'the last match is just over: join again in a moment'
                                                    or 'a match is on: wait for the next one')
    end
    if not match then
        nextId = nextId + 1
        local mapName = (PB.maps or {})[PB.map or 'field'] and (PB.map or 'field') or next(PB.maps or {})
        if not mapName then return MzbNotify(src, 'paintball has no map set up (Config.Paintball.maps)') end
        match = { id = nextId, state = 'signup', mapName = mapName, map = PB.maps[mapName],
                  wins = math.max(1, tonumber(PB.wins) or 2), round = 0, score = { red = 0, blue = 0 },
                  untilT = GetGameTimer() + math.max(5, tonumber(PB.signup) or 60) * 1000, players = {}, order = {} }
        announce(('PAINTBALL: the sign-up is open for %d s - at the referees\' table, or /%s join'):format(
            math.max(5, tonumber(PB.signup) or 60), PB.command or 'arenapaintball'))
    end
    local n = 0
    for _ in pairs(match.players) do n = n + 1 end
    local was = match.players[src]
    if not was and n >= math.max(2, tonumber(PB.maxPlayers) or 16) then return MzbNotify(src, 'the match is full') end
    if team ~= 'red' and team ~= 'blue' then                   -- the smaller side
        team = count('red') <= count('blue') and 'red' or 'blue'
        if was then team = was.team end
    end
    if was then
        was.team = team
    else
        match.players[src] = { src = src, team = team, name = GetPlayerName(tostring(src)) or ('#' .. src), out = false,
                               hits = 0, tagged = 0 }
        match.order[#match.order + 1] = src
    end
    MzbNotify(src, ('you are on %s (%d v %d) - the match starts when the sign-up closes'):format(label(team),
        count('red'), count('blue')))
    publish()
end

local function leave(src)
    if not match or not match.players[src] then return MzbNotify(src, 'you are not in the paintball match') end
    match.players[src] = nil
    for i, s in ipairs(match.order) do if s == src then table.remove(match.order, i) break end end
    TriggerClientEvent('mzb_arena:pbEnd', src)
    MzbNotify(src, 'you left the paintball match')
    if not next(match.players) and match.state == 'signup' then
        match = nil
        lastResult = 'the sign-up closed: everyone left'
    end
    publish()
end

local throttled = MzbThrottle(400)
RegisterNetEvent('mzb_arena:pbJoin', function(team)
    local src = source
    if throttled(src) then return end
    join(src, (team == 'red' or team == 'blue') and team or nil)
end)

RegisterNetEvent('mzb_arena:pbLeave', function()
    local src = source
    if throttled(src) then return end
    leave(src)
end)

-- ------------------------------------------------------------------ hits
-- the marker: the configured weapon, or the fallback a game build without it is handed (client/paintball.lua)
local function marker(w)
    if type(w) ~= 'number' then return false end
    w = w % 4294967296
    return w == GetHashKey(PB.weapon or 'WEAPON_CERAMICPISTOL') % 4294967296
        or w == GetHashKey(PB.fallback or 'WEAPON_PISTOL') % 4294967296
end

local hitThrottled = MzbThrottle(250)
RegisterNetEvent('mzb_arena:pbHit', function(by, weapon)
    local src = source
    local m = match
    if not m or m.state ~= 'live' then return end
    local v, a = m.players[src], m.players[tonumber(by) or -1]
    if not v or not a or v.out or a.out or v == a then return end
    if a.team == v.team and not PB.friendlyFire then return end
    if not marker(weapon) then return end
    -- (throttled only now: a team mate's ball just before must not swallow the one that counts)
    if hitThrottled(src) then return end
    local vp, ap = GetPlayerPed(tostring(src)), GetPlayerPed(tostring(a.src))
    if not vp or vp == 0 or not ap or ap == 0 or #(GetEntityCoords(vp) - GetEntityCoords(ap)) > 90.0 then return end
    v.out, v.tagged, a.hits = true, v.tagged + 1, a.hits + 1
    local left = count(v.team, true)
    for s in pairs(m.players) do
        TriggerClientEvent('mzb_arena:pbOut', s, src, a.src, v.name, a.name, v.team, left)
    end
    local n = 0
    for _, s in ipairs(m.order) do
        local p = m.players[s]
        if p and p.team == v.team and p.out then n = n + 1 end
        if s == src then break end
    end
    TriggerClientEvent('mzb_arena:pbPlace', src, spot(v.team, 'dead', math.max(1, n)), false)
    publish()
end)

-- the paint a ball leaves, passed on to the players at the arena (each draws it: the game's decals are its own)
local splatThrottled = MzbThrottle(120)
RegisterNetEvent('mzb_arena:pbSplat', function(x, y, z, nx, ny, nz)
    local src = source
    if splatThrottled(src) or not match or match.state ~= 'live' then return end
    local p = match.players[src]
    if not p or p.out then return end
    for _, v in ipairs({ x, y, z, nx, ny, nz }) do
        if type(v) ~= 'number' or v ~= v or math.abs(v) > 100000 then return end
    end
    if #(vector3(x, y, z) - Config.Screens.origin) > 120.0 then return end
    for _, id in ipairs(GetPlayers()) do
        local i = tonumber(id)
        if i ~= src and near(i) then TriggerClientEvent('mzb_arena:pbSplat', i, x, y, z, nx, ny, nz, p.team) end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if match and match.players[src] then
        match.players[src] = nil
        for i, s in ipairs(match.order) do if s == src then table.remove(match.order, i) break end end
        publish()
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then GlobalState.mzbPaintball = { id = 0, state = 'idle' } end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not match then return end
    for src in pairs(match.players) do TriggerClientEvent('mzb_arena:pbEnd', src) end
end)

-- ------------------------------------------------------------------ chat
local function status(src)
    local m = match
    if not m then return MzbReply(src, 'paintball', 'no match on' .. (lastResult and (' | last: ' .. lastResult) or '')) end
    local names = { red = {}, blue = {} }
    for _, s in ipairs(m.order) do
        local p = m.players[s]
        if p then names[p.team][#names[p.team] + 1] = p.name .. (p.out and ' (out)' or '') end
    end
    MzbReply(src, 'paintball', ('%s on %s | round %d, %s %d-%d %s, first to %d | %s: %s | %s: %s'):format(m.state,
        m.map.label, m.round, label('red'), m.score.red, m.score.blue, label('blue'), m.wins, label('red'),
        table.concat(names.red, ', '), label('blue'), table.concat(names.blue, ', ')))
end

local HELP = '/%s [status] | join [red|blue] | leave | start [map] [wins] | stop'

local function command(src, args)
    local sub = args[1] and tostring(args[1]):lower()
    if not sub or sub == 'status' then return status(src) end
    if sub == 'join' then
        if src == 0 then return MzbReply(src, 'paintball', 'players join from their game') end
        return join(src, args[2] and tostring(args[2]):lower() or nil)
    elseif sub == 'leave' then
        if src == 0 then return end
        return leave(src)
    end
    if not MzbAllowed(src, PB.access) then return MzbReply(src, 'paintball', 'you are not allowed to run paintball') end
    if sub == 'start' then
        local mapName, wins = args[2] and tostring(args[2]):lower() or nil, args[3]
        if mapName and tonumber(mapName) then mapName, wins = nil, mapName end
        local ok, err = start(src, mapName, wins)
        MzbReply(src, 'paintball', ok and 'the match is on' or err)
    elseif sub == 'stop' or sub == 'cancel' then
        MzbReply(src, 'paintball', cancel('called off by the staff') and 'the match is off' or 'there is no match to stop')
    else
        MzbReply(src, 'paintball', HELP:format(PB.command or 'arenapaintball'))
    end
end

RegisterCommand(PB.command or 'arenapaintball', function(src, args)
    if src == 0 then command(src, args) end              -- players come through mzb_arena:pbCmd
end, false)

local cmdThrottled = MzbThrottle(250)
RegisterNetEvent('mzb_arena:pbCmd', function(args)
    local src = source
    if cmdThrottled(src) or type(args) ~= 'table' then return end
    local clean = {}
    for i = 1, 3 do
        if args[i] ~= nil then
            if type(args[i]) ~= 'string' or #args[i] > 24 then return end
            clean[i] = args[i]
        end
    end
    command(src, clean)
end)

-- other resources: an event script that wants to know, or to call it off
exports('GetPaintball', function() return GlobalState.mzbPaintball end)
exports('StopPaintball', function() return cancel('called off') end)
