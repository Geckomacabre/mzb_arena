-- mzb_arena - server: the music player (GlobalState.mzbMusic, client/music.lua and html/music.js play it)
--   GlobalState.mzbMusic = { kind = 'off' | 'file' | 'youtube', url (file / stream), id (youtube), title,
--                            start (server ms at position 0), paused, at (the position while paused, s),
--                            volume (0-100), rev (bumped on every new track), by (who started it) }
-- Positions run on this server's GetGameTimer() (server/clock.lua), so a late joiner lands mid-track.
--   /arenamusic <url>                          play a track or stream (a YouTube link works too)
--   /arenamusic pause | resume | stop | volume <0-100> | status
--   /arenamusic mine <0-100>                   your own level (client side, kept with KVP)

local MU = Config.Music or {}
local OFF = { kind = 'off', paused = false, at = 0.0, start = 0, volume = MU.defaultVolume or 70, rev = 0 }

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

local function current() return GlobalState.mzbMusic or copy(OFF) end

local function youtubeId(s)
    local host, path = s:match('^https?://([^/%?#]+)(.*)$')
    if not host then return nil end
    host = host:lower():gsub('^www%.', ''):gsub('^m%.', ''):gsub('^music%.', '')
    local id
    if host == 'youtu.be' then
        id = path:match('^/([%w_%-]+)')
    elseif host == 'youtube.com' or host == 'youtube-nocookie.com' then
        id = path:match('[%?&]v=([%w_%-]+)') or path:match('^/embed/([%w_%-]+)')
             or path:match('^/shorts/([%w_%-]+)') or path:match('^/live/([%w_%-]+)')
    end
    if id and #id == 11 then return id end
    return nil
end

-- a track: an http(s) URL without spaces, quotes or control characters, at most 500 characters
local function trackUrl(s)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if #s > 500 or #s < 10 then return nil end
    if not s:match('^https?://[%w%-%.]+[:/]?[^%s"\'<>\\`]*$') or s:find('%c') then return nil end
    return s
end

local function titleOf(url)
    local name = url:gsub('[%?#].*$', ''):match('([^/]+)$') or url
    name = name:gsub('%%20', ' '):gsub('[^%w%s%-%._%(%)]', '')
    if #name == 0 then name = url:match('^https?://([^/]+)') or 'stream' end
    return name:sub(1, 80)
end

local function play(input, src)
    local url = trackUrl(input)
    if not url then return false, 'not a usable link (http/https, at most 500 characters)' end
    local cur = current()
    local m = { paused = false, at = 0.0, start = GetGameTimer(), volume = cur.volume or OFF.volume,
                rev = (cur.rev or 0) + 1, by = src or 0 }
    local id = youtubeId(url)
    if id then
        m.kind, m.id, m.title = 'youtube', id, 'YouTube ' .. id
    else
        m.kind, m.url, m.title = 'file', url, titleOf(url)
    end
    GlobalState.mzbMusic = m
    return true
end

local function stop()
    local cur = current()
    local m = copy(OFF)
    m.volume, m.rev = cur.volume or OFF.volume, (cur.rev or 0) + 1
    GlobalState.mzbMusic = m
    return true
end

local function pause(on)
    local cur = copy(current())
    if cur.kind == 'off' or (cur.paused == true) == on then return false end
    if on then
        cur.at, cur.paused = MzbTrackPos(cur), true
    else
        cur.start, cur.paused = GetGameTimer() - math.floor((cur.at or 0.0) * 1000), false
    end
    GlobalState.mzbMusic = cur
    return true
end

local function setVolume(v)
    v = tonumber(v)
    if not v or v ~= v then return false end
    local cur = copy(current())
    cur.volume = math.floor(math.max(0, math.min(100, v)))
    GlobalState.mzbMusic = cur
    return true
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then GlobalState.mzbMusic = copy(OFF) end
end)

local function allowed(src) return MzbAllowed(src, MU.access) end

local function status(src)
    local m = current()
    local what = m.kind == 'off' and 'off' or (m.title or '?')
    MzbReply(src, 'music', ('%s%s | volume %d%% | at %d s'):format(what, m.paused and ' (paused)' or '',
        m.volume or 0, math.floor(MzbTrackPos(m))))
end

local HELP = '/%s <url> | pause | resume | stop | volume <0-100> | status | mine <0-100> (your own level)'

local function command(src, args)
    if not MU.enabled then return MzbReply(src, 'music', 'the music player is off (Config.Music.enabled)') end
    local sub = args[1] and tostring(args[1]):lower()
    if not sub then return MzbReply(src, 'music', HELP:format(MU.command or 'arenamusic')) end
    if sub == 'status' then return status(src) end
    if not allowed(src) then return MzbReply(src, 'music', 'you are not allowed to run the arena music') end
    local ok, err = true, nil
    if sub == 'stop' or sub == 'off' then ok = stop()
    elseif sub == 'pause' then ok = pause(true)
    elseif sub == 'resume' then ok = pause(false)
    elseif sub == 'volume' and tonumber(args[2]) then ok = setVolume(args[2])
    else ok, err = play(tostring(args[1]), src) end
    if not ok and err then return MzbReply(src, 'music', err) end
    status(src)
end

-- the console (players' /arenamusic runs in client/music.lua, which handles "mine" and forwards the rest)
RegisterCommand(MU.command or 'arenamusic', function(src, args) command(src, args) end, false)

local throttled = MzbThrottle(250)

RegisterNetEvent('mzb_arena:musicCmd', function(args)
    local src = source
    if throttled(src) or type(args) ~= 'table' or #args > 4 then return end
    local clean = {}
    for i = 1, math.min(#args, 4) do
        if type(args[i]) ~= 'string' or #args[i] > 500 then return end
        clean[i] = args[i]
    end
    command(src, clean)
end)

RegisterNetEvent('mzb_arena:music', function(cmd)
    local src = source
    if not MU.enabled or not allowed(src) or throttled(src) or type(cmd) ~= 'table' then return end
    local ok, err = true, nil
    if cmd.action == 'play' then ok, err = play(cmd.url, src)
    elseif cmd.action == 'stop' then ok = stop()
    elseif cmd.action == 'pause' then ok = pause(true)
    elseif cmd.action == 'resume' then ok = pause(false)
    elseif cmd.action == 'volume' then ok = setVolume(cmd.value)
    end
    if not ok and err then MzbReply(src, 'music', err) end
end)

-- a track that would not play: the one who started it hears about it once per track (not once per listener)
local told = {}
local errThrottled = MzbThrottle(2000)
RegisterNetEvent('mzb_arena:musicError', function(rev, msg)
    local src = source
    if errThrottled(src) or type(rev) ~= 'number' or type(msg) ~= 'string' then return end
    local cur = current()
    if rev ~= cur.rev or told[rev] then return end
    told[rev] = true
    local by = tonumber(cur.by) or 0
    if by > 0 and GetPlayerName(tostring(by)) then
        MzbReply(by, 'music', ('"%s" will not play: %s'):format(cur.title or '?', msg:sub(1, 120)))
    elseif by == 0 then
        print(('[mzb_arena] music: "%s" will not play: %s'):format(cur.title or '?', msg:sub(1, 120)))
    end
end)

-- other resources: a DJ booth, an event script's walk-in music
exports('PlayMusic', function(url) return play(url, 0) end)
exports('StopMusic', function() return stop() end)
exports('PauseMusic', function(on) return pause(on ~= false) end)
exports('MusicVolume', function(v) return setVolume(v) end)
exports('GetMusic', function() return copy(current()) end)
