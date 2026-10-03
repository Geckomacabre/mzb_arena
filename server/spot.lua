-- mzb_arena - server: the followspot (GlobalState.mzbSpot, client/spot.lua draws it)
--   GlobalState.mzbSpot = { on, aim = 'player' | 'point', target (server id), point = { x, y, z }, color = { r, g, b },
--                           size (beam radius, degrees), intensity (0..1), by (the operator aiming by hand) }
-- Free aim: the operator's client sends a point a few times a second (mzb_arena:spotPoint); it is checked and passed
-- on to the players near the arena, and written to the state bag once a second so late joiners have it.

local FS = Config.FollowSpot or {}
local DEFAULT = { on = false, aim = 'point', target = 0, point = { x = Config.ArenaFrame.x, y = Config.ArenaFrame.y,
                  z = Config.ArenaFrame.z + 1.0 }, color = FS.color or { 255, 248, 235 }, size = FS.size or 5.0,
                  intensity = FS.intensity or 1.0, by = 0 }

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

local function current() return GlobalState.mzbSpot or copy(DEFAULT) end

local function colour(c)
    if type(c) == 'string' then
        local named = Config.LightColors and Config.LightColors[c:lower()]
        if named then return { named[1], named[2], named[3] } end
        local hex = c:match('^#?(%x%x%x%x%x%x)$')
        if hex then return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) } end
        return nil
    end
    if type(c) ~= 'table' then return nil end
    local out = {}
    for i = 1, 3 do
        local v = tonumber(c[i])
        if not v or v ~= v then return nil end
        out[i] = math.floor(math.max(0, math.min(255, v)))
    end
    return out
end

-- a point inside the arena (finite numbers within Config.FollowSpot.bounds of its middle)
local function inside(x, y, z)
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return false end
    if x ~= x or y ~= y or z ~= z then return false end
    local b = FS.bounds or { radius = 70.0, zMin = 15.0, zMax = 60.0 }
    local dx, dy = x - Config.ArenaFrame.x, y - Config.ArenaFrame.y
    return dx * dx + dy * dy <= b.radius * b.radius and z >= b.zMin and z <= b.zMax
end

local function online(id)
    return type(id) == 'number' and id > 0 and id == math.floor(id) and GetPlayerName(tostring(id)) ~= nil
end

local function sanitize(patch, cur, src)
    local out = copy(cur)
    if type(patch) ~= 'table' then return out end
    if patch.on ~= nil then out.on = patch.on == true end
    if patch.aim == 'player' and online(tonumber(patch.target)) then
        out.aim, out.target = 'player', tonumber(patch.target)
    elseif patch.aim == 'point' then
        out.aim, out.by = 'point', src or 0
    end
    local c = patch.color ~= nil and colour(patch.color)
    if c then out.color = c end
    if tonumber(patch.size) then out.size = math.max(2.0, math.min(15.0, tonumber(patch.size) + 0.0)) end
    if tonumber(patch.intensity) then out.intensity = math.max(0.0, math.min(1.0, tonumber(patch.intensity) + 0.0)) end
    if out.size ~= out.size then out.size = DEFAULT.size end
    if out.intensity ~= out.intensity then out.intensity = DEFAULT.intensity end
    return out
end

local function setSpot(patch, src)
    if not FS.enabled then return false end
    GlobalState.mzbSpot = sanitize(patch, current(), src)
    return true
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and GlobalState.mzbSpot == nil then GlobalState.mzbSpot = copy(DEFAULT) end
end)

local function allowed(src) return MzbAllowed(src, FS.access) end
local throttled = MzbThrottle(100)

RegisterNetEvent('mzb_arena:spot', function(patch)
    local src = source
    if not FS.enabled or not allowed(src) or throttled(src) then return end
    if type(patch) == 'table' and patch.target == 'me' then patch.target = src end
    setSpot(patch, src)
end)

-- free aim: points from the operator, passed on to the players near the arena
local pointThrottled = MzbThrottle(math.floor(1000 / math.max(1, (FS.sendRate or 8) + 2)))
local latest, dirty = nil, false

RegisterNetEvent('mzb_arena:spotPoint', function(x, y, z)
    local src = source
    if not FS.enabled or not allowed(src) or pointThrottled(src) then return end
    if not inside(x, y, z) then return end
    local cur = current()
    if cur.aim ~= 'point' or cur.by ~= src then return end        -- grab first (aim = point) - one operator at a time
    latest, dirty = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }, true
    local centre = vector3(Config.ArenaFrame.x, Config.ArenaFrame.y, Config.ArenaFrame.z)
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 and #(GetEntityCoords(ped) - centre) < 250.0 and tonumber(id) ~= src then
            TriggerClientEvent('mzb_arena:spotPoint', tonumber(id), latest.x, latest.y, latest.z)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if dirty then
            dirty = false
            local cur = copy(current())
            cur.point = latest
            GlobalState.mzbSpot = cur
        end
    end
end)

-- ------------------------------------------------------------------ chat (players' /arenaspot runs in client/spot.lua)
local function status(src)
    local s = current()
    local aim = s.aim == 'player' and ('following ' .. (GetPlayerName(tostring(s.target)) or ('#' .. s.target)))
        or ('aimed by hand at %.1f %.1f %.1f'):format(s.point.x, s.point.y, s.point.z)
    MzbReply(src, 'spot', ('followspot %s | %s | colour #%02x%02x%02x | size %.1f | intensity %d%%'):format(
        s.on and 'ON' or 'off', aim, s.color[1], s.color[2], s.color[3], s.size, math.floor(s.intensity * 100 + 0.5)))
end

local HELP = '/%s on | off | follow <id|me|look> | free (grab / release, also key %s) | color <name|#hex> | size <2-15> | intensity <0-100> | status'

local function command(src, args)
    if not FS.enabled then return MzbReply(src, 'spot', 'the followspot is off (Config.FollowSpot.enabled)') end
    if not allowed(src) then return MzbReply(src, 'spot', 'you are not allowed to run the followspot') end
    local sub = args[1] and tostring(args[1]):lower()
    if sub == 'on' or sub == 'off' then setSpot({ on = sub == 'on' }, src)
    elseif sub == 'follow' and args[2] then
        local id = args[2] == 'me' and src or tonumber(args[2])
        if not online(id) then return MzbReply(src, 'spot', 'no player with that id') end
        setSpot({ on = true, aim = 'player', target = id }, src)
    elseif (sub == 'color' or sub == 'colour') and args[2] then
        if not colour(args[2]) then return MzbReply(src, 'spot', 'a colour name (Config.LightColors) or #rrggbb') end
        setSpot({ color = args[2] }, src)
    elseif sub == 'size' and tonumber(args[2]) then setSpot({ size = tonumber(args[2]) }, src)
    elseif sub == 'intensity' and tonumber(args[2]) then setSpot({ intensity = tonumber(args[2]) / 100.0 }, src)
    elseif sub ~= 'status' then
        return MzbReply(src, 'spot', HELP:format(FS.command or 'arenaspot', FS.key or 'F7'))
    end
    status(src)
end

RegisterCommand(FS.command or 'arenaspot', function(src, args)
    if src == 0 then command(src, args) end          -- players come through mzb_arena:spotCmd
end, false)

local cmdThrottled = MzbThrottle(250)
RegisterNetEvent('mzb_arena:spotCmd', function(args)
    local src = source
    if cmdThrottled(src) or type(args) ~= 'table' then return end
    local clean = {}
    for i = 1, 3 do
        if args[i] ~= nil then
            if type(args[i]) ~= 'string' or #args[i] > 32 then return end
            clean[i] = args[i]
        end
    end
    command(src, clean)
end)

-- (server/fights.lua: a followspot that is on follows the player fighters)
function MzbSpotFollow(id)
    if not FS.enabled or not current().on then return false end
    return setSpot({ aim = 'player', target = tonumber(id) }, 0)
end

-- other resources: a ring announcer script, an entrance cue
exports('SetFollowSpot', function(patch) return setSpot(patch, 0) end)
exports('FollowPlayer', function(id) return setSpot({ on = true, aim = 'player', target = tonumber(id) }, 0) end)
exports('GetFollowSpot', function() return copy(current()) end)
