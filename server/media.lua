-- mzb_arena - server: what the video screens show (GlobalState.mzbMedia, client/media.lua draws it)
--   GlobalState.mzbMedia = { kind = 'off' | 'youtube' | 'images' | 'image' | 'look', id (youtube), urls (images /
--                            image), look (a look: Config.Media.looks, drawn by the page in step with the lights),
--                            start (server ms at position 0), paused, at (the position while paused, s),
--                            volume (0-100), interval (s per picture), rev (bumped on every new item),
--                            by (who put it on: the one told when it will not play) }
-- The position runs on this server's GetGameTimer() (server/clock.lua); a client turns it into its own time.
--   /arenascreen <youtube url | id>            play a video on every screen
--   /arenascreen <picture url> [more ...]      one picture, or a cycle of them
--   /arenascreen images [set]                  a picture set from Config.Media.imageSets (no name: the show's own)
--   /arenascreen look <show|pulse|colour|bars|stripes|waves>   a look in step with the light desk
--   /arenascreen off | pause | resume | volume <0-100> | interval <s> | status

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

local function setMedia(m)
    m.rev = (current().rev or 0) + 1
    GlobalState.mzbMedia = m
    return true
end

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
    return setMedia(m)
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

local function stop()
    local cur = current()
    local m = copy(OFF)
    m.volume, m.interval = cur.volume or OFF.volume, cur.interval or OFF.interval
    return setMedia(m)
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

-- (server/lights.lua: a light preset that carries a screen look - only while the screens show a look or nothing)
function MzbScreenLook(name)
    if not M.enabled or M.presetLooks == false or not LOOKS[name] then return false end
    local cur = current()
    if cur.kind ~= 'off' and cur.kind ~= 'look' then return false end
    if cur.kind == 'look' and cur.look == name then return false end
    return playLook(name, 0)
end

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
    elseif cmd.action == 'stop' then ok = stop()
    elseif cmd.action == 'pause' then ok = pause(true)
    elseif cmd.action == 'resume' then ok = pause(false)
    elseif cmd.action == 'volume' then ok = setVolume(cmd.value)
    elseif cmd.action == 'interval' then ok = setInterval(cmd.value)
    end
    if not ok and err then MzbReply(src, 'screens', err) end
end)

-- ------------------------------------------------------------------ chat
local function status(src)
    local m = current()
    local what = m.kind == 'youtube' and ('YouTube ' .. m.id)
        or m.kind == 'images' and (#m.urls .. ' pictures, ' .. m.interval .. ' s each')
        or m.kind == 'image' and ('picture ' .. m.urls[1]) or m.kind == 'look' and ('the ' .. tostring(m.look) .. ' look')
        or 'off'
    MzbReply(src, 'screens', ('%s%s | volume %d%% | at %d s'):format(what, m.paused and ' (paused)' or '',
        m.volume or 0, math.floor(MzbTrackPos(m))))
end

local HELP = '/%s <youtube url | picture url(s)> | images [set] | look <name> | off | pause | resume | volume <0-100> | ' ..
             'interval <s> | status'

RegisterCommand(M.command or 'arenascreen', function(src, args, raw)
    if not M.enabled then return MzbReply(src, 'screens', 'the built-in screen player is off (Config.Media.enabled)') end
    if not allowed(src) then return MzbReply(src, 'screens', 'you are not allowed to run the arena screens') end
    local sub = args[1] and args[1]:lower()
    local ok, err = true, nil
    if not sub then return MzbReply(src, 'screens', HELP:format(M.command or 'arenascreen'))
    elseif sub == 'off' or sub == 'stop' then ok = stop()
    elseif sub == 'pause' then ok = pause(true)
    elseif sub == 'resume' or sub == 'play' then ok = pause(false)
    elseif sub == 'volume' and tonumber(args[2]) then ok = setVolume(args[2])
    elseif sub == 'interval' and tonumber(args[2]) then ok = setInterval(args[2])
    elseif sub == 'images' then ok, err = playSet(args[2], src)
    elseif sub == 'look' then ok, err = playLook((args[2] or ''):lower(), src)
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
exports('ScreenOff', function() return stop() end)
exports('ScreenPause', function(on) return pause(on ~= false) end)
exports('ScreenVolume', function(v) return setVolume(v) end)
exports('GetScreenMedia', function() return copy(current()) end)
