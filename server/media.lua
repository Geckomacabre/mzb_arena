-- mzb_arena - server: what the video screens show (GlobalState.mzbMedia, client/media.lua draws it)
--   GlobalState.mzbMedia = { kind = 'off' | 'youtube' | 'images' | 'image' | 'look' | 'feed', id (youtube), urls
--                            (images / image), look (a look: Config.Media.looks, drawn by the page in step with the
--                            lights), cam / camName (a camera feed: the player whose view of the game is on the
--                            screens), len (a video's length in s, once a page has said it: it is switched off then,
--                            or with loop it starts again; loops = how many times it has),
--                            start (server ms at position 0; a video's is a moment after the Play,
--                            Config.Media.leadIn, so every player has it loaded by then), paused, at (the position
--                            while paused, s), fade ({ at = server ms, dur = s }: fading to black, off when it is
--                            there), black (off and dark: the screens are black; without it off is the show's own
--                            graphics), volume (0-100), interval (s per picture), rev (bumped on every new item),
--                            by (who put it on: the one told when it will not play) }
-- The position runs on this server's GetGameTimer() (server/clock.lua); a client turns it into its own time.
--   /arenascreen <youtube url | id>            play a video on every screen
--   /arenascreen <picture url> [more ...]      one picture, or a cycle of them
--   /arenascreen images [set]                  a picture set from Config.Media.imageSets (no name: the show's own)
--   /arenascreen look                          your own view of the game, live on the screens: you are the camera
--   /arenascreen look <player id>              that player's view (they are told, and may take it off)
--   /arenascreen look off                      the camera feed off (staff, or the player whose view it is)
--   /arenascreen look <show|pulse|colour|bars|stripes|waves>   a look in step with the light desk
--   /arenascreen off                           the screens go dark (Config.Media.offBlack)
--   /arenascreen own                           back to the show's own graphics (another media script can have them)
--   /arenascreen fade [seconds]                fade to black, then off
--   /arenascreen loop [on|off]                 a video starts again at its end (nothing after it: the other way)
--   /arenascreen pause | resume | volume <0-100> | interval <s> | status

local M = Config.Media or {}
local OFF = { kind = 'off', paused = false, at = 0.0, start = 0, volume = M.defaultVolume or 60,
              interval = M.interval or 8, rev = 0 }

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

local function current() return GlobalState.mzbMedia or copy(OFF) end

-- a YouTube link of any usual shape, or a bare id, to the 11-character id (nil if it is not one)
local function youtubeId(s)
    if type(s) ~= 'string' or #s > 300 then return nil end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    local id
    if s:match('^[%w_%-]+$') then
        -- a bare id: not a plain lowercase word, which is a mistyped command far more often than a video
        if s:match('[%u%d_%-]') then id = s end
    else
        local host, path = s:match('^https?://([^/%?#]+)(.*)$')
        if not host then return nil end
        host = host:lower():gsub('^www%.', ''):gsub('^m%.', ''):gsub('^music%.', '')
        if host == 'youtu.be' then
            id = path:match('^/([%w_%-]+)')
        elseif host == 'youtube.com' or host == 'youtube-nocookie.com' then
            id = path:match('[%?&]v=([%w_%-]+)') or path:match('^/embed/([%w_%-]+)')
                 or path:match('^/shorts/([%w_%-]+)') or path:match('^/live/([%w_%-]+)')
        end
    end
    if id and #id == 11 and id:match('^[%w_%-]+$') then return id end
    return nil
end

-- a picture: an https URL (no spaces or quotes, at most 500 characters) or a file under html/img/ named in a set
local localImages = {}
for _, set in pairs(M.imageSets or {}) do
    for _, u in ipairs(set) do
        if type(u) == 'string' and u:match('^img/[%w_%-%./]+$') and not u:find('..', 1, true) then localImages[u] = true end
    end
end

local function imageUrl(s)
    if type(s) ~= 'string' or #s > 500 then return nil end
    if localImages[s] then return s end
    if s:match('^https://[%w%-%.]+[:/]?[^%s"\'<>\\`]*$') and not s:find('[%c]') then return s end
    return nil
end

local function looksLikePicture(s)
    local path = s:lower():gsub('[%?#].*$', '')
    return path:match('%.png$') or path:match('%.jpe?g$') or path:match('%.webp$') or path:match('%.gif$')
end

-- a video's sound from the arena's speakers (Config.Media.sound = 'speakers'): the music player plays the same video's
-- audio (server/music.lua: MzbMusicForScreen), tied to the item on the screens by its rev
local function fromSpeakers() return (M.sound or 'speakers') == 'speakers' and MzbMusicForScreen ~= nil end

-- a camera feed's watchers (the players whose screens asked for the picture), counted for Config.Media.feed.maxViewers
local viewers, viewerCount = {}, 0

local function setMedia(m)
    local cur = current()
    if cur.kind == 'youtube' and MzbMusicScreenStop then MzbMusicScreenStop(cur.rev) end   -- the video before: its sound goes
    m.rev = (cur.rev or 0) + 1
    viewers, viewerCount = {}, 0
    GlobalState.mzbMedia = m
    return true
end

-- a video that stops takes the show lights out with it (Config.Media.lightsOut; server/lights.lua)
local function lightsOut(seconds)
    if M.lightsOut ~= false and MzbLightsOut then MzbLightsOut(tonumber(seconds) or tonumber(M.lightsFade) or 2.0) end
end

-- the video's audio is ready in the music player: the picture starts again with it, so the two run together
function MzbMediaAudioReady(rev, start)
    local cur = copy(current())
    if cur.rev ~= rev or cur.kind ~= 'youtube' then return end
    cur.start, cur.at = start or GetGameTimer(), 0.0
    GlobalState.mzbMedia = cur
end

-- ms between the Play and a video's start
local function lead() return math.floor(math.max(0.0, math.min(10.0, tonumber(M.leadIn) or 2.5)) * 1000) end

local function fresh(kind, src)
    local cur = current()
    return { kind = kind, paused = false, at = 0.0, start = GetGameTimer(), volume = cur.volume or OFF.volume,
             interval = cur.interval or OFF.interval, by = src or 0 }
end

local function playYoutube(s, src)
    local id = youtubeId(s)
    if not id then return false, 'not a YouTube link or id' end
    local m = fresh('youtube', src)
    m.id = id
    m.start = m.start + lead()
    m.loop = M.loop == true                              -- (what a new video starts with: the desk's Loop changes it)
    setMedia(m)
    if fromSpeakers() then MzbMusicForScreen(id, src, m.rev, m.start) end
    return true
end

local function playImages(list, src)
    if type(list) ~= 'table' then return false, 'no pictures' end
    local urls = {}
    for _, u in ipairs(list) do
        local ok = imageUrl(u)
        if ok then urls[#urls + 1] = ok end
        if #urls >= (M.maxImages or 24) then break end
    end
    if #urls == 0 then return false, 'pictures must be https URLs (or img/ files listed in Config.Media.imageSets)' end
    local m = fresh(#urls == 1 and 'image' or 'images', src)
    m.urls = urls
    return setMedia(m)
end

-- off. Dark: the screens are black, over the show's own graphics (the desk's Off; Config.Media.offBlack). own = true:
-- nothing of ours on the screens - the show's own graphics, and another media script can have them (as the arena
-- starts)
local function stop(own)
    local cur = current()
    local m = copy(OFF)
    m.volume, m.interval = cur.volume or OFF.volume, cur.interval or OFF.interval
    m.black = (not own) and M.offBlack ~= false
    if cur.kind == 'youtube' and not cur.fade then lightsOut() end   -- (a fade-out has taken them down already)
    return setMedia(m)
end

-- fade to black, then off: the screens' page darkens the picture over the seconds (html/screen.js), and a video's
-- sound from the speakers goes down with it
local function fade(seconds)
    local cur = copy(current())
    if cur.kind == 'off' then return false, 'the screens are off' end
    if cur.fade then return true end
    local dur = math.max(0.5, math.min(30.0, tonumber(seconds) or tonumber(M.fade) or 3.0))
    cur.fade = { at = GetGameTimer(), dur = dur }
    GlobalState.mzbMedia = cur
    if cur.kind == 'youtube' and MzbMusicScreenFade then MzbMusicScreenFade(cur.rev, dur) end
    if cur.kind == 'youtube' then lightsOut(dur) end
    local rev = cur.rev
    SetTimeout(math.floor(dur * 1000) + 200, function()
        local now = current()
        if now.rev == rev and now.fade then stop() end
    end)
    return true
end

-- pause / resume keep the position: paused stores it, resuming moves the start so it carries on from there
local function pause(on)
    local cur = copy(current())
    if cur.kind == 'off' or (cur.paused == true) == on then return false end
    if on then
        cur.at, cur.paused = MzbTrackPos(cur), true
    else
        cur.start, cur.paused = GetGameTimer() - math.floor((cur.at or 0.0) * 1000), false
    end
    GlobalState.mzbMedia = cur
    if cur.kind == 'youtube' and MzbMusicScreenPause then MzbMusicScreenPause(cur.rev, on) end
    return true
end

local function setVolume(v)
    v = tonumber(v)
    if not v or v ~= v then return false end
    local cur = copy(current())
    cur.volume = math.floor(math.max(0, math.min(100, v)))
    GlobalState.mzbMedia = cur
    return true
end

-- Loop on / off (nil: the other way), for the video that is on: at its end it starts again instead of being switched
-- off. seconds: the video's length, from a script that knows it (else the page of whoever put it on says so)
local function setLoop(on, seconds)
    local cur = copy(current())
    if cur.kind ~= 'youtube' then
        return false, cur.kind == 'off' and 'the screens are off'
            or 'only a video is looped: pictures go round as they are, a look or a camera feed has no end'
    end
    if on == nil then on = not cur.loop end
    cur.loop = on == true
    seconds = tonumber(seconds)
    if seconds and seconds == seconds and seconds >= 1.0 and seconds <= 43200.0 then cur.len = seconds end
    GlobalState.mzbMedia = cur
    return true
end

-- a looped video at its end: from its beginning again, a moment ahead as a new video is (Config.Media.leadIn), so
-- every player's screens are back at its start and hold there until they all start together - and its sound from the
-- speakers with it, on the same clock. It stays the item it was (the same rev: nothing is loaded again), the screens
-- stay on and the show lights are left as they are
local function again()
    local cur = copy(current())
    cur.start, cur.at, cur.paused = GetGameTimer() + lead(), 0.0, false
    cur.loops = (cur.loops or 0) + 1
    GlobalState.mzbMedia = cur
    if MzbMusicScreenAgain then MzbMusicScreenAgain(cur.rev, cur.start) end
end

local function setInterval(v)
    v = tonumber(v)
    if not v or v ~= v then return false end
    local cur = copy(current())
    cur.interval = math.floor(math.max(2, math.min(120, v)))
    GlobalState.mzbMedia = cur
    return true
end

-- anything a person types or pastes: a YouTube link, or one or more picture URLs (split on spaces / commas)
local function play(input, src)
    if type(input) ~= 'string' or #input > 4000 then return false, 'too long' end
    local parts = {}
    for p in input:gmatch('[^%s,]+') do parts[#parts + 1] = p end
    if #parts == 0 then return false, 'nothing to play' end
    if #parts == 1 and youtubeId(parts[1]) and not looksLikePicture(parts[1]) then return playYoutube(parts[1], src) end
    return playImages(parts, src)
end

local LOOKS = {}
for _, k in ipairs(M.looks or {}) do LOOKS[k] = true end

local function playLook(name, src)
    if not LOOKS[name] then
        return false, 'looks: ' .. table.concat(M.looks or {}, ', ')
    end
    local m = fresh('look', src)
    m.look = name
    return setMedia(m)
end

-- (server/lights.lua: a light preset that carries a screen look - only while the screens show a look or nothing.
-- 'off' = dark, as in a blackout; 'own' = the show's own graphics)
function MzbScreenLook(name)
    if not M.enabled or M.presetLooks == false then return false end
    local cur = current()
    if cur.kind ~= 'off' and cur.kind ~= 'look' then return false end
    if name == 'off' or name == 'own' then
        local black = name == 'off' and M.offBlack ~= false
        if cur.kind == 'off' and (cur.black == true) == black then return false end
        return stop(name == 'own')
    end
    if not LOOKS[name] then return false end
    if cur.kind == 'look' and cur.look == name then return false end
    return playLook(name, 0)
end

-- ------------------------------------------------------------------ a camera feed (kind 'feed')
-- A player's own view of the game, live on the screens. The camera's page takes the game's picture and sends it to
-- the screens' page of each player near the arena, PC to PC (WebRTC: html/feed.js -> html/screen.js); this server
-- carries none of the picture. It passes the two pages' handshake on, and decides who may talk to whom: only the
-- camera and the players watching it, a limited number of them, near the arena, a message at a time.
local FD = M.feed or {}

local function playFeed(target, src)
    if FD.enabled == false then return false, 'camera feeds are off (Config.Media.feed.enabled)' end
    target = tonumber(target)
    if not target or target < 1 or target ~= target or not GetPlayerName(tostring(math.floor(target))) then
        return false, 'no such player'
    end
    target = math.floor(target)
    src = src or 0
    if target ~= src and FD.others == false then return false, 'a camera feed is the view of whoever asks for it (Config.Media.feed.others)' end
    local m = fresh('feed', src)
    m.cam, m.camName = target, tostring(GetPlayerName(tostring(target)) or ('player ' .. target)):sub(1, 40)
    setMedia(m)
    if target ~= src then
        MzbReply(target, 'screens', ('your view is live on the arena screens%s - /%s look off takes it off'):format(
            src > 0 and (' (put on by ' .. tostring(GetPlayerName(tostring(src)) or 'staff') .. ')') or '', M.command or 'arenascreen'))
    end
    return true
end

-- what a page may send the other one: a request, the two halves of the handshake, a route to try, a goodbye
local SIGNALS = { want = true, offer = true, answer = true, ice = true, bye = true }
local function cleanSignal(msg)
    if type(msg) ~= 'table' or not SIGNALS[msg.t] then return nil end
    local out = { t = msg.t }
    if msg.t == 'offer' or msg.t == 'answer' then
        if type(msg.sdp) ~= 'string' or #msg.sdp > 20000 then return nil end
        out.sdp = msg.sdp
    elseif msg.t == 'ice' then
        local c = msg.c
        if type(c) ~= 'table' or type(c.candidate) ~= 'string' or #c.candidate > 1000 then return nil end
        local line = tonumber(c.sdpMLineIndex)
        out.c = { candidate = c.candidate, sdpMid = type(c.sdpMid) == 'string' and c.sdpMid:sub(1, 32) or nil,
                  sdpMLineIndex = line and line == line and math.floor(line) or nil }
    end
    return out
end

-- messages per 10 s: a watcher sends a handful per connection, the camera that many to each watcher
local sent = {}
local function flooding(src, n)
    local now = GetGameTimer()
    local b = sent[src]
    if not b or now - b.t > 10000 then
        b = { t = now, n = 0 }
        sent[src] = b
    end
    b.n = b.n + 1
    return b.n > n
end

local function nearArena(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - Config.Screens.origin) < (M.range or 160.0) + 60.0
end

local function dropViewer(id)
    if viewers[id] then
        viewers[id] = nil
        viewerCount = math.max(0, viewerCount - 1)
    end
end

RegisterNetEvent('mzb_arena:feedSignal', function(rev, role, to, msg)
    local src = source
    local cur = current()
    if not M.enabled or cur.kind ~= 'feed' or cur.rev ~= rev then return end
    msg = cleanSignal(msg)
    if not msg then return end
    local max = math.max(1, math.floor(tonumber(FD.maxViewers) or 16))
    if role == 'cam' then                                 -- the camera's page, to one of its watchers
        to = tonumber(to)
        if src ~= cur.cam or not to or not viewers[to] or flooding(src, 60 * (max + 1)) then return end
        if msg.t == 'bye' then dropViewer(to) end
        TriggerClientEvent('mzb_arena:feedSignal', to, rev, 'cam', src, msg)
    elseif role == 'view' then                            -- a player's screens, to the camera
        if flooding(src, 60) then return end
        if msg.t == 'want' and not viewers[src] then
            if not nearArena(src) then return end
            if viewerCount >= max then
                return TriggerClientEvent('mzb_arena:feedSignal', src, rev, 'cam', cur.cam, { t = 'full' })
            end
            viewers[src], viewerCount = true, viewerCount + 1
        elseif not viewers[src] then
            return
        elseif msg.t == 'bye' then
            dropViewer(src)
        end
        TriggerClientEvent('mzb_arena:feedSignal', cur.cam, rev, 'view', src, msg)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    sent[src] = nil
    local cur = current()
    if cur.kind ~= 'feed' then return end
    if cur.cam == src then
        stop()                                            -- the camera has left: the screens go off
    elseif viewers[src] then
        dropViewer(src)
        TriggerClientEvent('mzb_arena:feedSignal', cur.cam, cur.rev, 'view', src, { t = 'bye' })
    end
end)

-- ------------------------------------------------------------------ a video's end
-- The server does not know how long a video is; the page playing it does. The first page to say so that may - the
-- one of whoever put the video on, or of anyone allowed to run the screens - is believed, and when the video has
-- run that long the screens are switched off (and the show lights go out with it) instead of sitting on its last frame.
-- A looped video (Loop) starts again instead: nothing is switched off and the lights stay as they are, until Loop is
-- taken off or the staff stop it.
local lenThrottled = MzbThrottle(2000)
RegisterNetEvent('mzb_arena:mediaLength', function(rev, seconds)
    local src = source
    if lenThrottled(src) or type(rev) ~= 'number' or type(seconds) ~= 'number' or seconds ~= seconds then return end
    local cur = current()
    if not M.enabled or cur.rev ~= rev or cur.kind ~= 'youtube' or cur.len then return end
    if src ~= cur.by and not MzbAllowed(src, M.access) then return end
    if seconds < 1.0 or seconds > 43200.0 then return end              -- (a live stream has no length: it runs on)
    cur = copy(cur)
    cur.len = seconds
    GlobalState.mzbMedia = cur
end)

CreateThread(function()
    while true do
        Wait(500)
        local cur = current()
        if cur.kind == 'youtube' and cur.len and not cur.paused and not cur.fade and MzbTrackPos(cur) >= cur.len + 0.5 then
            if cur.loop then again() else stop() end
        end
    end
end)

local function playSet(name, src)
    if not name then                                     -- no name: the show's own set, else the arena's
        local show = GlobalState.mzbShow or Config.DefaultShow
        name = (M.imageSets or {})[show] and show or ((M.imageSets or {}).arena and 'arena' or 'default')
    end
    local set = (M.imageSets or {})[name]
    if not set then
        local names = {}
        for k in pairs(M.imageSets or {}) do names[#names + 1] = k end
        table.sort(names)
        return false, #names > 0 and ('picture sets: ' .. table.concat(names, ', ')) or 'no picture sets in Config.Media.imageSets'
    end
    return playImages(set, src)
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then GlobalState.mzbMedia = copy(OFF) end   -- the clock starts again with us
end)

-- ------------------------------------------------------------------ from the desk
local throttled = MzbThrottle(250)
local function allowed(src) return MzbAllowed(src, M.access) end

RegisterNetEvent('mzb_arena:media', function(cmd)
    local src = source
    if not M.enabled or not allowed(src) or throttled(src) or type(cmd) ~= 'table' then return end
    local ok, err = true, nil
    if cmd.action == 'play' and type(cmd.url) == 'string' then ok, err = play(cmd.url, src)
    elseif cmd.action == 'set' and type(cmd.set) == 'string' and #cmd.set <= 64 then ok, err = playSet(cmd.set, src)
    elseif cmd.action == 'look' and type(cmd.look) == 'string' then ok, err = playLook(cmd.look, src)
    elseif cmd.action == 'feed' then ok, err = playFeed(tonumber(cmd.player) or src, src)
    elseif cmd.action == 'stop' then ok = stop()
    elseif cmd.action == 'own' then ok = stop(true)
    elseif cmd.action == 'fade' then ok, err = fade(cmd.seconds)
    elseif cmd.action == 'pause' then ok = pause(true)
    elseif cmd.action == 'resume' then ok = pause(false)
    elseif cmd.action == 'volume' then ok = setVolume(cmd.value)
    elseif cmd.action == 'interval' then ok = setInterval(cmd.value)
    elseif cmd.action == 'loop' then ok, err = setLoop(cmd.on == true)
    end
    if not ok and err then MzbReply(src, 'screens', err) end
end)

-- ------------------------------------------------------------------ chat
local function status(src)
    local m = current()
    local what = m.kind == 'youtube' and ('YouTube ' .. m.id)
        or m.kind == 'images' and (#m.urls .. ' pictures, ' .. m.interval .. ' s each')
        or m.kind == 'image' and ('picture ' .. m.urls[1]) or m.kind == 'look' and ('the ' .. tostring(m.look) .. ' look')
        or m.kind == 'feed' and ('camera: %s (%d watching)'):format(tostring(m.camName), viewerCount)
        or (m.black and 'off (dark)' or 'off (the show\'s own graphics)')
    -- Loop is a video's: on with no length yet means no page that may say it has played the video so far
    local loop = m.kind ~= 'youtube' and '' or not m.loop and ' | loop off' or m.len and ' | loop on'
        or ' | loop on (waiting to hear how long the video is)'
    MzbReply(src, 'screens', ('%s%s | volume %d%% | at %d s%s'):format(what,
        m.fade and ' (fading out)' or m.paused and ' (paused)' or '', m.volume or 0, math.floor(MzbTrackPos(m)), loop))
end

local HELP = '/%s <youtube url | picture url(s)> | images [set] | look [player id | off] (a camera feed) | ' ..
             'look <name> | off | own | fade [seconds] | pause | resume | loop [on|off] | volume <0-100> | ' ..
             'interval <s> | status'

-- /arenascreen look ...: nothing or "me" = the view of whoever types it, a player id = theirs, off; a name = a look
local function lookCommand(src, arg)
    arg = (arg or ''):lower()
    if LOOKS[arg] then return playLook(arg, src) end
    if arg == 'off' or arg == 'stop' then
        if current().kind ~= 'feed' then return false, 'no camera feed is on' end
        return stop()
    end
    if arg == '' or arg == 'me' then
        if src == 0 then return false, 'look <player id>: whose view goes on the screens' end
        return playFeed(src, src)
    end
    if tonumber(arg) then return playFeed(tonumber(arg), src) end
    return false, 'look = your own view on the screens, look <player id> = theirs, look off; or a look: ' ..
        table.concat(M.looks or {}, ', ')
end

RegisterCommand(M.command or 'arenascreen', function(src, args, raw)
    if not M.enabled then return MzbReply(src, 'screens', 'the built-in screen player is off (Config.Media.enabled)') end
    local sub = args[1] and args[1]:lower()
    -- the player whose view is on the screens may always take it off, staff or not
    if src ~= 0 and (sub == 'look' or sub == 'cam') and (args[2] or ''):lower() == 'off' then
        local cur = current()
        if cur.kind == 'feed' and cur.cam == src then
            stop()
            return MzbReply(src, 'screens', 'your view is off the screens')
        end
    end
    if not allowed(src) then return MzbReply(src, 'screens', 'you are not allowed to run the arena screens') end
    local ok, err = true, nil
    if not sub then return MzbReply(src, 'screens', HELP:format(M.command or 'arenascreen'))
    elseif sub == 'off' or sub == 'stop' then ok = stop()
    elseif sub == 'own' or sub == 'graphics' then ok = stop(true)
    elseif sub == 'fade' then ok, err = fade(args[2])
    elseif sub == 'pause' then ok = pause(true)
    elseif sub == 'resume' or sub == 'play' then ok = pause(false)
    elseif sub == 'volume' and tonumber(args[2]) then ok = setVolume(args[2])
    elseif sub == 'interval' and tonumber(args[2]) then ok = setInterval(args[2])
    elseif sub == 'loop' then
        local a = args[2] and args[2]:lower()
        if a and a ~= 'on' and a ~= 'off' then
            return MzbReply(src, 'screens', ('/%s loop [on|off] (nothing after it: the other way)'):format(M.command or 'arenascreen'))
        end
        ok, err = setLoop(a and a == 'on')
    elseif sub == 'images' then ok, err = playSet(args[2], src)
    elseif sub == 'look' or sub == 'cam' or sub == 'camera' then ok, err = lookCommand(src, args[2])
    elseif sub ~= 'status' then
        ok, err = play(table.concat(args, ' '), src)
    end
    if not ok and err then return MzbReply(src, 'screens', err) end
    status(src)
end, false)

-- other resources: a sponsor rotation, a replay system, a stream overlay
exports('SetScreenMedia', function(input)
    if type(input) == 'table' then return playImages(input) end
    return play(input)
end)
exports('ScreenImageSet', function(name) return playSet(name) end)
exports('ScreenLook', function(name) return playLook(name, 0) end)
exports('ScreenCamera', function(playerId) return playFeed(playerId, 0) end)
exports('ScreenOff', function() return stop() end)
exports('ScreenOwn', function() return stop(true) end)
exports('ScreenFade', function(seconds) return fade(seconds) end)
exports('ScreenPause', function(on) return pause(on ~= false) end)
-- ScreenLoop(on, seconds): seconds = the video's length, if the script knows it. Without it a looped video starts
-- again once a page that may say how long it is has played it (the one of whoever put it on, staff's)
exports('ScreenLoop', function(on, seconds) return setLoop(on ~= false, seconds) end)
exports('ScreenVolume', function(v) return setVolume(v) end)
exports('GetScreenMedia', function() return copy(current()) end)
