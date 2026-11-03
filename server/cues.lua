-- mzb_arena - server: the desk's cue lists (1.5.0). A list per kind of show (Config.ShowKinds, Config.Cues.kinds): the
-- set list of a concert or a DJ set (tracks, one after another), the entrances of a fight night (a wrestler's theme on
-- the screens, the entrance look, the pyro), the cues of a game night. A cue: { name, link (a YouTube link or an
-- audio file: on the screens with its sound from the speakers, or the music player alone), preset (a light look),
-- pyro (a cue of Config.Pyro), screens (the link's picture on the screens too) }. GO fires the next one (the desk's
-- GO, the numpad's + / Enter, /arenacue go); a set list with Auto next goes on by itself when a track ends.
-- The lists are kept on the server (resource KVP), for every staff member alike.
--
--   GlobalState.mzbCues = { kind, index (the cue fired last, 0: none yet), name, auto, rev (the lists' edits),
--                           media / music (the rev of what the cue started: its end is the set list's next) }
--   /arenacue go | back | <n> | auto [on|off] | list            (ACE: the light desk's, Config.LightAccess)
local CQ = Config.Cues or {}
local MAX, MAXLEN = CQ.max or 60, 500
local lists = {}                                 -- kind -> { cues }

local function show() return GlobalState.mzbShow or Config.DefaultShow end
local function kindOf(s) return (Config.ShowKinds or {})[s or show()] or 'default' end
local function allowed(src) return MzbAllowed(src, CQ.access) end

local function load(kind)
    if not lists[kind] then
        local ok, t = pcall(json.decode, GetResourceKvpString('mzb_cues_' .. kind) or '[]')
        lists[kind] = (ok and type(t) == 'table') and t or {}
    end
    return lists[kind]
end

local function state() return GlobalState.mzbCues or { kind = kindOf(), index = 0, auto = false, rev = 0 } end

-- a cue as a person typed it, checked field by field (nil: not one)
local function clean(c)
    if type(c) ~= 'table' then return nil end
    local name = type(c.name) == 'string' and c.name:gsub('[%c<>]', ''):sub(1, 60) or ''
    local link = type(c.link) == 'string' and c.link:gsub('%s', ''):sub(1, MAXLEN) or ''
    if link ~= '' and not link:match('^https?://') then link = '' end
    local preset = (type(c.preset) == 'string' and (Config.LightPresets or {})[c.preset]) and c.preset or ''
    local pyro = (type(c.pyro) == 'string' and ((Config.Pyro or {}).cues or {})[c.pyro]) and c.pyro or ''
    if name == '' and link == '' and preset == '' and pyro == '' then return nil end
    if name == '' then name = link ~= '' and link:sub(1, 60) or (preset ~= '' and preset or pyro) end
    return { name = name, link = link, preset = preset, pyro = pyro, screens = c.screens ~= false }
end

local function publish(patch)
    local st = state()
    local out = { kind = st.kind, index = st.index, name = st.name, auto = st.auto, rev = st.rev,
                  media = st.media, music = st.music }
    for k, v in pairs(patch or {}) do out[k] = v end
    GlobalState.mzbCues = out
end

-- fire cue i of the show's list: its link, its look, its pyro
local function fire(i)
    local kind = kindOf()
    local list = load(kind)
    local c = list[i]
    if not c then return false, ('no cue %s in the %s list (%d cues)'):format(tostring(i), kind, #list) end
    local media, music = nil, nil
    if c.link ~= '' then
        if c.screens and MzbScreenPlay and (Config.Media or {}).enabled ~= false then
            local ok = MzbScreenPlay(c.link)
            if ok then media = (GlobalState.mzbMedia or {}).rev end
        end
        if not media and MzbMusicPlay then
            local ok = MzbMusicPlay(c.link)
            if ok then music = (GlobalState.mzbMusic or {}).rev end
        end
    end
    if c.preset ~= '' and MzbLightPreset then MzbLightPreset(c.preset) end
    if c.pyro ~= '' and MzbPyro then MzbPyro(c.pyro) end
    publish({ kind = kind, index = i, name = c.name, media = media or false, music = music or false })
    return true
end

local function go(how)
    local st = state()
    local i = st.kind == kindOf() and st.index or 0
    if how == 'back' then i = i - 1 elseif type(how) == 'number' then i = how else i = i + 1 end
    return fire(i)
end

-- a set list goes on by itself: the track the cue started has ended (server/media.lua, server/music.lua)
local function ended(what, rev)
    local st = state()
    if st.auto and st.kind == kindOf() and st[what] == rev and st.index < #load(st.kind) then go() end
end
AddEventHandler('mzb_arena:mediaEnded', function(rev) ended('media', rev) end)
AddEventHandler('mzb_arena:musicEnded', function(rev) ended('music', rev) end)

-- the show changes (server/main.lua): its own list, from its start
function MzbCuesShow(value)
    local kind = kindOf(value)
    if state().kind ~= kind then
        publish({ kind = kind, index = 0, name = false, media = false, music = false,
                  auto = ((CQ.kinds or {})[kind] or {}).auto == true })
    end
end

-- ------------------------------------------------------------------ the desk
local throttled = MzbThrottle(250)

local function send(src)
    local kind = kindOf()
    TriggerClientEvent('mzb_arena:cues', src, { kind = kind, list = load(kind) })
end

RegisterNetEvent('mzb_arena:cuesGet', function()
    local src = source
    if throttled(src) or not allowed(src) then return end
    send(src)
end)

RegisterNetEvent('mzb_arena:cuesSave', function(list)
    local src = source
    if throttled(src) or not allowed(src) or type(list) ~= 'table' then return end
    local kind, out = kindOf(), {}
    for i = 1, math.min(#list, MAX) do
        local c = clean(list[i])
        if c then out[#out + 1] = c end
    end
    lists[kind] = out
    SetResourceKvp('mzb_cues_' .. kind, json.encode(out))
    local st = state()
    publish({ rev = (st.rev or 0) + 1, index = math.min(st.index or 0, #out) })
    send(src)
end)

RegisterNetEvent('mzb_arena:cuesGo', function(how)
    local src = source
    if throttled(src) or not allowed(src) then return end
    if how == 'next' then go()
    elseif how == 'back' then go('back')
    elseif type(how) == 'number' and how == how then go(math.floor(how)) end
end)

RegisterNetEvent('mzb_arena:cuesAuto', function(on)
    local src = source
    if throttled(src) or not allowed(src) then return end
    publish({ auto = on == true })
end)

-- ------------------------------------------------------------------ chat, exports
local function reply(src, msg)
    if src == 0 then print('[mzb_arena] ' .. msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'arena', msg } }) end
end

RegisterCommand(CQ.command or 'arenacue', function(src, args)
    if not allowed(src) then return reply(src, 'you are not allowed to run the arena cues') end
    local sub = (args[1] or 'list'):lower()
    local ok, err = true, nil
    if sub == 'go' or sub == 'next' then ok, err = go()
    elseif sub == 'back' then ok, err = go('back')
    elseif tonumber(sub) then ok, err = go(math.floor(tonumber(sub)))
    elseif sub == 'auto' then publish({ auto = args[2] == nil and not state().auto or args[2] == 'on' })
    end
    if not ok then return reply(src, err) end
    local st, list = state(), load(kindOf())
    local names = {}
    for i, c in ipairs(list) do names[#names + 1] = ((i == st.index) and '> ' or '') .. i .. ' ' .. c.name end
    reply(src, ('%s list (%s): %s | auto next %s'):format(kindOf(), st.index > 0 and ('at ' .. st.index) or 'not started',
        #names > 0 and table.concat(names, ', ') or 'empty - add cues on the desk (Cues)', st.auto and 'on' or 'off'))
end, false)

exports('CueGo', function(how) return go(how) end)
exports('GetCues', function(kind) return load(kind or kindOf()) end)
exports('SetCues', function(list, kind)
    kind = kind or kindOf()
    local out = {}
    for i = 1, math.min(type(list) == 'table' and #list or 0, MAX) do
        local c = clean(list[i])
        if c then out[#out + 1] = c end
    end
    lists[kind] = out
    SetResourceKvp('mzb_cues_' .. kind, json.encode(out))
    publish({ rev = (state().rev or 0) + 1 })
    return #out
end)

CreateThread(function()
    publish({ kind = kindOf(), index = 0, auto = ((CQ.kinds or {})[kindOf()] or {}).auto == true, rev = 0,
              media = false, music = false, name = false })
end)
