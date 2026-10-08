-- mzb_arena - server: the music player (GlobalState.mzbMusic, client/music.lua and html/music.js play it)
--   GlobalState.mzbMusic = { kind = 'off' | 'youtube' | 'file' | 'loading', title, id (youtube),
--                            url (the players load it themselves) or relay (a name in server/relay.js's cache),
--                            web (this server's https name, if it has one), live (a stream: no seeking),
--                            start (server ms at position 0: a moment after the Play, Config.Music.leadIn, so
--                            every player's page has the track loaded by then and none loses its first second),
--                            paused, at (the position while paused, s), fade ({ at = server ms, dur = s }: fading
--                            out, stopped when it is down), volume (0-100), rev (bumped on every new track),
--                            by (who started it) }
-- The music is heard from the arena's speakers as a sound in the world and in no other way: the players' pages take
-- the YouTube player's or the audio file's sound into their own sound graph (html/music.js). With
-- Config.Music.relay.enabled a link is first handed to server/relay.js instead ('loading'), which fetches it and
-- serves it from this server (YouTube with yt-dlp): for a game browser that will not let a page do the first.
-- Positions run on this server's GetGameTimer() (server/clock.lua), so a late joiner lands mid-track.
--   /arenamusic <url>                          play a track or stream (a YouTube link works too)
--   /arenamusic pause | resume | stop | fade [seconds] | volume <0-100> | status
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

local function stop()
    local cur = current()
    local m = copy(OFF)
    m.volume, m.rev = cur.volume or OFF.volume, (cur.rev or 0) + 1
    GlobalState.mzbMusic = m
    return true
end

-- whoever started the track hears why it will not play (the console when it was the console or another resource)
local function tellStarter(m, msg)
    local by = tonumber(m.by) or 0
    local line = ('"%s" will not play: %s'):format(m.title or '?', tostring(msg):sub(1, 160))
    if by > 0 and GetPlayerName(tostring(by)) then MzbReply(by, 'music', line)
    else print('[mzb_arena] music: ' .. line) end
end

local RELAY = MU.relay or {}

-- ms between the Play and the track's start
local function lead() return math.floor(math.max(0.0, math.min(10.0, tonumber(MU.leadIn) or 2.5)) * 1000) end

-- a link: played by the players' pages as it is, or (Config.Music.relay.enabled) 'loading' until server/relay.js has
-- said how the players can read it (or that they cannot).
-- screen: the rev of the video on the screens whose sound this is (server/media.lua), or nil; start: that video's
-- start (the two run on one clock)
local function play(input, src, screen, start)
    local url = trackUrl(input)
    if not url then return false, 'not a usable link (http/https, at most 500 characters)' end
    local cur = current()
    local id = youtubeId(url)
    if RELAY.enabled ~= true then
        local m = { kind = id and 'youtube' or 'file', id = id, title = id and ('YouTube ' .. id) or titleOf(url),
                    paused = false, at = 0.0, start = start or (GetGameTimer() + lead()),
                    volume = cur.volume or OFF.volume, rev = (cur.rev or 0) + 1, by = src or 0, screen = screen }
        if not id then m.url = url end
        GlobalState.mzbMusic = m
        return true
    end
    local m = { kind = 'loading', title = id and ('YouTube ' .. id) or titleOf(url), paused = false, at = 0.0,
                start = GetGameTimer(), volume = cur.volume or OFF.volume, rev = (cur.rev or 0) + 1, by = src or 0,
                screen = screen }
    GlobalState.mzbMusic = m
    local timeout = tonumber(RELAY.timeout) or 180
    TriggerEvent('mzb_arena:relayFetch', m.rev, id and 'youtube' or 'file', id or url,
        { ytdlp = RELAY.ytdlp, deno = RELAY.deno, ytdlpArgs = RELAY.ytdlpArgs, maxMB = RELAY.maxMB, maxMinutes = RELAY.maxMinutes,
          timeout = timeout, allowLan = RELAY.allowLan == true, keepHours = RELAY.keepHours, cacheMB = RELAY.cacheMB })
    -- no answer at all: the relay is not running (the server's JavaScript runtime did not load server/relay.js)
    SetTimeout((timeout + 15) * 1000, function()
        local now = current()
        if now.rev == m.rev and now.kind == 'loading' then
            tellStarter(now, 'the music relay did not answer (server/relay.js)')
            stop()
        end
    end)
    return true
end

AddEventHandler('mzb_arena:relayDone', function(rev, ok, info)
    local cur = copy(current())
    if type(rev) ~= 'number' or cur.rev ~= rev or cur.kind ~= 'loading' then return end   -- stopped or replaced since
    info = type(info) == 'table' and info or {}
    if not ok or (info.mode ~= 'direct' and info.mode ~= 'relay') then
        tellStarter(cur, info.err or 'it could not be fetched')
        return stop()
    end
    cur.kind, cur.live = 'file', info.live == true
    if info.mode == 'direct' then cur.url = tostring(info.url) else cur.relay = tostring(info.name) end
    if type(info.title) == 'string' and #info.title > 0 then cur.title = info.title:sub(1, 80) end
    local web = GetConvar('web_baseUrl', '')
    if web ~= '' then cur.web = web end
    cur.start, cur.at, cur.paused = GetGameTimer() + lead(), 0.0, false
    GlobalState.mzbMusic = cur
    if cur.screen and MzbMediaAudioReady then MzbMediaAudioReady(cur.screen, cur.start) end   -- the picture starts with it
end)

local function pause(on)
    local cur = copy(current())
    if (cur.kind ~= 'file' and cur.kind ~= 'youtube') or cur.live or (cur.paused == true) == on then return false end
    if on then
        cur.at, cur.paused = MzbTrackPos(cur), true
    else
        cur.start, cur.paused = GetGameTimer() - math.floor((cur.at or 0.0) * 1000), false
    end
    GlobalState.mzbMusic = cur
    return true
end

-- fade out, then stop: the players' pages bring the level down over the seconds (html/music.js), the track is
-- stopped when it is down
local function fade(seconds)
    local cur = copy(current())
    if cur.kind ~= 'file' and cur.kind ~= 'youtube' then return false, 'nothing is playing' end
    if cur.fade then return true end
    local dur = math.max(0.5, math.min(30.0, tonumber(seconds) or tonumber(MU.fade) or 3.0))
    cur.fade = { at = GetGameTimer(), dur = dur }
    GlobalState.mzbMusic = cur
    local rev = cur.rev
    SetTimeout(math.floor(dur * 1000) + 200, function()
        local now = current()
        if now.rev == rev and now.fade then stop() end
    end)
    return true
end

-- the sound of a video on the screens (server/media.lua, Config.Media.sound = 'speakers'): the same video through
-- the speakers, started, stopped, paused and faded with it
function MzbMusicForScreen(id, src, mediaRev, start)
    if not MU.enabled then return false end
    return play('https://www.youtube.com/watch?v=' .. id, src, mediaRev, start)
end

function MzbMusicScreenFade(mediaRev, seconds)
    if current().screen == mediaRev then fade(seconds) end
end

function MzbMusicScreenStop(mediaRev)
    local cur = current()
    if cur.screen == mediaRev and cur.kind ~= 'off' then stop() end
end

function MzbMusicScreenPause(mediaRev, on)
    if current().screen == mediaRev then pause(on) end
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
    if m.kind == 'loading' then
        return MzbReply(src, 'music', ('fetching %s ... | volume %d%%'):format(m.title or '?', m.volume or 0))
    end
    local what = m.kind == 'off' and 'off' or (m.title or '?')
    local how = m.kind == 'off' and '' or (m.relay and ' | served from the relay' or m.kind == 'youtube' and ' | YouTube'
        or ' | read from its own server')
    MzbReply(src, 'music', ('%s%s | volume %d%% | at %d s%s'):format(what,
        m.fade and ' (fading out)' or m.paused and ' (paused)' or '', m.volume or 0, math.floor(MzbTrackPos(m)), how))
end

local HELP = '/%s <url> | pause | resume | stop | fade [seconds] | volume <0-100> | status | mine <0-100> (your own level)'

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
    elseif sub == 'fade' then ok, err = fade(args[2])
    elseif sub == 'volume' and tonumber(args[2]) then ok = setVolume(args[2])
    else ok, err = play(tostring(args[1]), src) end
    if not ok and err then return MzbReply(src, 'music', err) end
    status(src)
end

-- the console (players' /arenamusic runs in client/music.lua, which handles "mine" and forwards the rest)
RegisterCommand(MU.command or 'arenamusic', function(src, args)
    if src == 0 then command(src, args) end          -- players come through mzb_arena:musicCmd
end, false)

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
    elseif cmd.action == 'fade' then ok, err = fade(cmd.seconds)
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
    if rev ~= cur.rev or (cur.kind ~= 'file' and cur.kind ~= 'youtube') or told[rev] then return end
    told[rev] = true
    tellStarter(cur, msg:gsub('%c', ' '))
end)

-- other resources: a DJ booth, an event script's walk-in music
exports('PlayMusic', function(url) return play(url, 0) end)
exports('StopMusic', function() return stop() end)
exports('FadeMusic', function(seconds) return fade(seconds) end)
exports('PauseMusic', function(on) return pause(on ~= false) end)
exports('MusicVolume', function(v) return setVolume(v) end)
exports('GetMusic', function() return copy(current()) end)
