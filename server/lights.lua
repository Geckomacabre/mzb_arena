-- mzb_arena - server: the light desk's state (GlobalState.mzbLights, synced to every client incl. late joiners)
--   GlobalState.mzbLights = { on, mode, move, colors = { {r, g, b} x 1..3 }, bpm, intensity (0..1),
--                             focus (one of floor / stage / crowd, or a list of them), ring, house,
--                             follow (off / both / tempo / colour: the lights follow the music, Config.LightFollow),
--                             fade ({ at = server ms, dur = s }: the show lights are fading out, off when they are
--                             down; switching them on or off ends it),
--                             master (0..1, the Grand Master), bo (the B.O. key is down), look (the last preset fired) }
-- Who may change it: Config.LightAccess (an ACE; false = anyone). The desk (NUI) and chat both land in setLights.
--   /arenalights                   open the desk
--   /arenalights on | off | blackout | status | help
--   /arenalights fade [seconds]    the show lights fade out, then off (a video that stops does this: Config.Media.lightsOut)
--   /arenalights mode <static|chase|strobe|pulse|rainbow|sweep|ballyhoo|random|police|fade|wave|flash|alternate|
--                      twinkle|lightning|fire|bounce>       the colour effect
--   /arenalights move <none|sweep|ballyhoo|fan|nod|cross|random>    the beams' movement (combines with any mode)
--   /arenalights color <name|#rrggbb> [second] [third]
--   /arenalights bpm <30-240> | intensity <0-100> | house <show|full|dim|off>
--   /arenalights follow <off|on|tempo|colour|auto>   the effects run on the music's beat and / or in the video's colours
--                                                  (auto: both, and the looks chosen from the music: Config.LightAuto)
--   /arenalights focus <floor|stage|crowd> [more ...]      several: the fixtures take turns (e.g. focus floor crowd)
--   /arenalights ring <on|off|color <c>|level <0-100>|own> the ring lights (the rig's own, on by default): off, a
--                                                          colour for all of them, their level, back to their own colours
--   /arenalights bars <on|off|video|steady|chase|pulse|all|rafters|ledges|stage|level <0-100>|desk|<colour>> (1.5.0) the bar
--                                  lights under the trusses and along the upper ledge: a zone of their own
--   /arenalights haze <0-100|off>  (1.5.0) the arena's haze (Config.Fog: the clubs' dry ice over the floor and the bowl)
--   /arenalights fog <on|off|burst [s]|0-100>   the stages' fog machines: on / off, a burst, their output
--   /arenalights master <0-100>    (1.5.0) the desk's Grand Master: every light's level (the beams, the ring, the bars,
--                                  the lasers) - not the house lights, not the haze
--   /arenalights bo [on|off]       the desk's B.O. key: dark at once, the look kept under it; again and it is back
--   /arenalights random            the desk's RANDOM: a new look on every light at once (Config.LightRandom)
--   /arenalights preset <name>     (Config.LightPresets; the desk lights the look fired last: look)

local MODES = { static = true, chase = true, strobe = true, pulse = true, rainbow = true, sweep = true,
                ballyhoo = true, random = true, police = true, fade = true, wave = true, flash = true,
                alternate = true, twinkle = true, lightning = true, fire = true, bounce = true }
local MOVES = { none = true, sweep = true, ballyhoo = true, fan = true, nod = true, cross = true, random = true }
local FOCUS = { floor = true, stage = true, crowd = true }
local LASERS = { fan = true, sweep = true, tunnel = true, scan = true, chase = true }   -- (1.5.0) the lasers' patterns
local BARS = { video = true, steady = true, chase = true, pulse = true }                -- (1.5.0) the bar lights' modes
local BAR_WHERE = { all = true, rafters = true, ledges = true, stage = true }
local GOBOS = {}                                                                         -- (1.5.0) Config.LightGobos.list
for _, g in ipairs((Config.LightGobos or {}).list or {}) do GOBOS[g] = true end
local HOUSE = { show = true, full = true, dim = true, off = true }
local FOLLOW = { off = 'off', both = 'both', on = 'both', tempo = 'tempo', colour = 'colour', color = 'colour', auto = 'auto' }

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

local function colour(c)
    if type(c) == 'string' then
        local named = Config.LightColors and Config.LightColors[c:lower()]
        if named then return { named[1], named[2], named[3] } end
        local hex = c:match('^#?(%x%x%x%x%x%x)$')
        if hex then
            return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
        end
        return nil
    end
    if type(c) ~= 'table' then return nil end
    local out = {}
    for i = 1, 3 do
        local v = tonumber(c[i])
        if not v then return nil end
        out[i] = math.floor(math.max(0, math.min(255, v)))
    end
    return out
end

-- a patch from the desk / chat / an export, checked field by field against the current state
local function sanitize(patch, cur)
    local out = copy(cur)
    if type(patch) ~= 'table' then return out end
    if patch.on ~= nil then out.on, out.fade = patch.on == true, nil end
    if MODES[patch.mode] then out.mode = patch.mode end
    if MOVES[patch.move] then out.move = patch.move end
    if FOCUS[patch.focus] then
        out.focus = patch.focus
    elseif type(patch.focus) == 'table' then                 -- several aims: each one once, in a fixed order
        local fo = {}
        for _, k in ipairs({ 'floor', 'stage', 'crowd' }) do
            for _, v in ipairs(patch.focus) do
                if v == k then fo[#fo + 1] = k; break end
            end
        end
        if #fo == 1 then out.focus = fo[1] elseif #fo > 1 then out.focus = fo end
    end
    if patch.ring ~= nil then out.ring = patch.ring == true end
    if patch.ringColor == false then
        out.ringColor = nil
    elseif patch.ringColor ~= nil then
        local c = colour(patch.ringColor)
        if c then out.ringColor = c end
    end
    if tonumber(patch.ringLevel) then out.ringLevel = math.max(0.0, math.min(1.0, tonumber(patch.ringLevel))) end
    if HOUSE[patch.house] then out.house = patch.house end
    if patch.follow == false then
        out.follow = 'off'
    elseif type(patch.follow) == 'string' and FOLLOW[patch.follow] then
        out.follow = (Config.LightFollow or {}).enabled ~= false and FOLLOW[patch.follow] or 'off'
    elseif patch.follow == nil then
        -- (1.5.0) a hand on the desk takes over from the music: a look, an effect, a movement, an aim or colours set
        -- by hand leave Auto's own looks (the lights keep the music's beat), and colours set by hand leave the
        -- video's - else Auto (on by default) would go on picking and the press would seem to do nothing
        local f = out.follow or 'off'
        if f == 'auto' and (patch.mode ~= nil or patch.move ~= nil or patch.focus ~= nil or patch.colors ~= nil) then
            out.follow = 'tempo'
        elseif patch.colors ~= nil and (f == 'both' or f == 'colour') then
            out.follow = f == 'both' and 'tempo' or 'off'
        end
    end
    if tonumber(patch.bpm) then out.bpm = math.floor(math.max(30, math.min(240, tonumber(patch.bpm)))) end
    if tonumber(patch.intensity) then out.intensity = math.max(0.0, math.min(1.0, tonumber(patch.intensity))) end
    -- (1.5.0) the desk's Grand Master (every light's level over its own) and its B.O. key (dark while it is down, the
    -- look kept under it, as a console's blackout)
    local gm = tonumber(patch.master)
    if gm and gm == gm then out.master = math.max(0.0, math.min(1.0, gm)) end
    if patch.bo ~= nil then out.bo = patch.bo == true end
    if type(patch.colors) == 'table' then
        local cs = {}
        for i = 1, math.min(3, #patch.colors) do
            local c = colour(patch.colors[i])
            if c then cs[#cs + 1] = c end
        end
        if #cs > 0 then out.colors = cs end
    end
    -- (1.5.0) the gobo every beam projects (Config.LightGobos): one of its list, or none
    if patch.gobo == false or patch.gobo == 'none' or patch.gobo == 'off' then
        out.gobo = nil
    elseif GOBOS[patch.gobo] then
        out.gobo = patch.gobo
    end
    -- (1.5.0) the lasers (Config.Lasers): on, a pattern, their colour - the desk's colour slots, or one colour
    if type(patch.lasers) == 'table' then
        local lz = copy(out.lasers or { on = false, pattern = 'fan', colour = 'desk' })
        if patch.lasers.on ~= nil then lz.on = patch.lasers.on == true end
        if LASERS[patch.lasers.pattern] then lz.pattern = patch.lasers.pattern end
        if patch.lasers.colour == 'desk' then
            lz.colour = 'desk'
        elseif patch.lasers.colour ~= nil then
            local c = colour(patch.lasers.colour)
            if c then lz.colour = c end
        end
        out.lasers = lz
    end
    -- (1.5.0) the bar lights (Config.LightBars): on, a mode, where (all / rafters / ledges), a level, their colour
    if type(patch.bars) == 'table' then
        local bz = copy(out.bars or { on = false, mode = 'video', where = 'all', level = 1.0, colour = 'desk' })
        if patch.bars.on ~= nil then bz.on = patch.bars.on == true end
        if BARS[patch.bars.mode] then bz.mode = patch.bars.mode end
        if BAR_WHERE[patch.bars.where] then bz.where = patch.bars.where end
        local lv = tonumber(patch.bars.level)
        if lv and lv == lv then bz.level = math.max(0.0, math.min(1.0, lv)) end
        if patch.bars.colour == 'desk' then
            bz.colour = 'desk'
        elseif patch.bars.colour ~= nil then
            local c = colour(patch.bars.colour)
            if c then bz.colour = c end
        end
        out.bars = bz
    end
    -- (1.5.0) the atmosphere (Config.Fog): the haze's level (0 .. 1), the fog machines (on, their output 0 .. 1),
    -- a burst of the machines (a count the clients see change, its length in s)
    if patch.haze ~= nil then
        local h = (patch.haze == false or patch.haze == 'off') and 0 or tonumber(patch.haze)
        if h and h == h then out.haze = math.max(0.0, math.min(1.0, h)) end
    end
    if type(patch.fog) == 'table' then
        local f = copy(out.fog or { on = false, output = 0.6 })
        if patch.fog.on ~= nil then f.on = patch.fog.on == true end
        local o = tonumber(patch.fog.output)
        if o and o == o then f.output = math.max(0.05, math.min(1.0, o)) end
        out.fog = f
    end
    local fb = tonumber(patch.fogBurst)
    if fb and fb == fb and fb > 0 then
        out.fogBurst = { n = ((out.fogBurst or {}).n or 0) + 1, dur = math.max(1.0, math.min(30.0, fb)) }
    end
    return out
end

local function current()
    return GlobalState.mzbLights or copy(Config.LightDefault)
end

local outByMedia = false             -- (MzbLightsOut below: a video took the show lights out; staff switching clears it)
local function setLights(patch)
    if type(patch) == 'table' and patch.on ~= nil then outByMedia = false end
    GlobalState.mzbLights = sanitize(patch, current())
    return true
end

-- (1.5.0) the desk's RANDOM: a new look on every light at once - the beams' effect, movement, aim, colours and gobo,
-- the ring washes' colour, the bars' mode, the lasers' pattern - picked here, so every player sees the same one
-- (Config.LightRandom). The tempo stays; lights that follow the music keep its beat but take these colours. Like a
-- look, it lifts the blackout
local function randomLook()
    local R = Config.LightRandom or {}
    local function one(list, fallback) return (type(list) == 'table' and #list > 0) and list[math.random(#list)] or fallback end
    local cur = current()
    local gobos = (Config.LightGobos or {}).list
    local pair = one(R.colours, { 'red', 'blue' })
    local out = sanitize({
        on = true, bo = false, mode = one(R.modes, 'chase'), move = one(R.moves, 'sweep'), colors = pair,
        ringColor = pair[math.random(#pair)], focus = one(R.focus, { 'floor' }),
        gobo = math.random() < (R.gobo or 0.35) and one(gobos, false) or false,
        bars = { on = true, mode = one(R.bars, 'chase'), colour = 'desk' },
        lasers = { on = true, pattern = one(R.lasers, 'fan'), colour = 'desk' },
        follow = (cur.follow or 'off') ~= 'off' and 'tempo' or 'off',
    }, cur)
    out.look = 'random'
    GlobalState.mzbLights = out
    return true
end

local function preset(name)
    if name == 'random' then return randomLook() end
    local p = Config.LightPresets and Config.LightPresets[name]
    if not p then return false end
    local out = sanitize(p, current())
    out.look = name                                  -- (1.5.0) the desk lights the look fired last
    out.bo = false                                   -- and a look lifts the blackout (B.O.)
    GlobalState.mzbLights = out
    -- a look can carry the crowd's mood (its mood field): the house reacts with the lights (server/crowd.lua)
    if p.mood and MzbCrowdMood then MzbCrowdMood(p.mood) end
    -- and a screen look (server/media.lua: only while the screens show a look or nothing)
    if p.screen and MzbScreenLook then MzbScreenLook(p.screen) end
    return true
end

-- (server/fights.lua: the bout's cues)
MzbLightPreset = preset

-- the show lights fade out over the seconds, then they are off (0: off at once). The clients take the level down from
-- the moment they hear of it (client/lights.lua); the ring and house lights stay as they are
local function fadeOut(seconds)
    local cur = copy(current())
    if not cur.on then return false end
    if cur.fade then return true end
    local dur = math.min(30.0, tonumber(seconds) or 2.0)
    if dur < 0.1 then GlobalState.mzbLights = sanitize({ on = false }, cur) return true end
    local at = GetGameTimer()
    cur.fade = { at = at, dur = dur }
    GlobalState.mzbLights = cur
    SetTimeout(math.floor(dur * 1000) + 100, function()
        local now = current()
        if now.fade and now.fade.at == at then GlobalState.mzbLights = sanitize({ on = false }, now) end
    end)
    return true
end

-- (1.5.0) the music runs the lights: a song that starts - a track in the music player (server/music.lua), or a video
-- on the screens playing its own sound (server/media.lua) - brings the show lights back on when the desk is on AUTO,
-- or when the last video took them out with it (Config.Media.lightsOut). Before, they stayed out until someone
-- pressed AUTO again (the user, 2026-10-29: "the lights dont auto start if i put a song in the video thing, i have to
-- reclick auto for them to turn back on"). Lights that staff switched on or off since are theirs: only AUTO brings
-- those back (outByMedia, by setLights: the last video took them out, and nobody has switched them since).

-- (server/media.lua: a video that stops)
MzbLightsOut = function(seconds)
    local out = fadeOut(seconds)
    if out then outByMedia = true end
    return out
end

local function songStarts()
    local cur = current()
    if cur.on and not cur.fade then outByMedia = false return end
    if (cur.follow or 'off') == 'auto' or outByMedia then
        outByMedia = false
        GlobalState.mzbLights = sanitize({ on = true }, cur)            -- (on: a fade-out that was under way stops)
    end
end

-- start: the server's ms the song begins at (after its lead-in); still(): is it still the one playing then?
function MzbLightsSongStart(start, still)
    local wait = math.max(0, math.min(15000, math.floor((tonumber(start) or 0) - GetGameTimer())))
    SetTimeout(wait, function()
        if not still or still() then songStarts() end
    end)
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if GlobalState.mzbLights == nil then
        GlobalState.mzbLights = copy(Config.LightDefault)
    elseif GlobalState.mzbLights.ringv ~= 2 then
        -- the ring lights were baked into the rigs (always on) before 1.1.0: they are the desk's now, on to start with
        local l = copy(GlobalState.mzbLights)
        l.ring, l.ringv = Config.LightDefault.ring ~= false, 2
        GlobalState.mzbLights = l
    end
end)

local function allowed(src)
    return src == 0 or not Config.LightAccess or IsPlayerAceAllowed(tostring(src), Config.LightAccess)
end

local function reply(src, msg)
    if src == 0 then
        print('[mzb_arena] ' .. msg)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'lights', msg } })
    end
end

-- the desk sends a patch per touch (sliders are throttled on the client); a player may not flood it
local last = {}
local function throttled(src)
    local now = GetGameTimer()
    if now - (last[src] or -100000) < 50 then return true end
    last[src] = now
    return false
end

AddEventHandler('playerDropped', function() last[source] = nil end)

RegisterNetEvent('mzb_arena:lights', function(patch)
    local src = source
    if not allowed(src) or throttled(src) then return end
    setLights(patch)
end)

RegisterNetEvent('mzb_arena:lightsPreset', function(name)
    local src = source
    if not allowed(src) or throttled(src) or type(name) ~= 'string' then return end
    preset(name)
end)

local function status(src)
    local l = current()
    local cs = {}
    for _, c in ipairs(l.colors or {}) do cs[#cs + 1] = ('#%02x%02x%02x'):format(c[1], c[2], c[3]) end
    local fo = type(l.focus) == 'table' and table.concat(l.focus, '+') or l.focus
    local ring = l.ring and ('ON (%s, %d%%)'):format(l.ringColor and ('#%02x%02x%02x'):format(l.ringColor[1],
        l.ringColor[2], l.ringColor[3]) or 'own colours', math.floor((l.ringLevel or 1.0) * 100 + 0.5)) or 'off'
    local bz = l.bars or {}
    local fog = l.fog or {}
    local atmo = ('haze %d%% | fog %s'):format(math.floor((l.haze or 0) * 100 + 0.5),
        fog.on and ('ON (%d%%)'):format(math.floor((fog.output or 0.6) * 100 + 0.5)) or 'off')
    local bars = bz.on and ('ON (%s, %s, %d%%)'):format(bz.mode or 'video', bz.where or 'all',
        math.floor((bz.level or 1.0) * 100 + 0.5)) or 'off'
    reply(src, ('show lights %s | mode %s | move %s | colours %s | %d bpm | intensity %d%% | aim %s | ring lights %s | house %s | follow the music: %s | bars %s | %s | master %d%%%s')
        :format(l.on and (l.fade and 'ON (fading out)' or 'ON') or 'off', l.mode, l.move or 'none', table.concat(cs, ' '), l.bpm,
            math.floor(l.intensity * 100 + 0.5), fo, ring, l.house, l.follow or 'off', bars, atmo,
            math.floor((l.master or 1.0) * 100 + 0.5), l.bo and ' (B.O.: dark)' or ''))
end

local HELP = '/%s [on|off|fade [s]|blackout|status] | mode <m> | move <none|sweep|ballyhoo|fan|nod|cross|random> | color <c> [c2] [c3] | ' ..
             'bpm <n> | intensity <0-100> | focus <floor|stage|crowd> [more] | ring <on|off|color <c>|level <n>|own> | ' ..
             'house <show|full|dim|off> | follow <off|on|tempo|colour|auto> | lasers <on|off|fan|sweep|tunnel|scan|chase|desk|c> | gobo <name|off> | ' ..
             'bars <on|off|video|steady|chase|pulse|all|rafters|ledges|stage|level <n>|desk|c> | ' ..
             'haze <0-100|off> | fog <on|off|burst [s]|0-100> | master <0-100> | bo [on|off] | random | ' ..
             'preset <name>'

RegisterCommand(Config.LightCommand, function(src, args)
    if not allowed(src) then return reply(src, 'you are not allowed to run the arena lights') end
    local sub = args[1] and args[1]:lower()
    if not sub then
        if src == 0 then return reply(src, HELP:format(Config.LightCommand)) end
        return TriggerClientEvent('mzb_arena:lightsDesk', src)
    end
    if sub == 'on' then setLights({ on = true })
    elseif sub == 'off' then setLights({ on = false })
    elseif sub == 'fade' then fadeOut(args[2])
    elseif sub == 'blackout' then preset('blackout')
    elseif sub == 'mode' and MODES[args[2] or ''] then setLights({ mode = args[2] })
    elseif (sub == 'color' or sub == 'colour') and args[2] then setLights({ colors = { args[2], args[3], args[4] } })
    elseif sub == 'bpm' and tonumber(args[2]) then setLights({ bpm = tonumber(args[2]) })
    elseif sub == 'intensity' and tonumber(args[2]) then setLights({ intensity = tonumber(args[2]) / 100.0 })
    elseif sub == 'move' and MOVES[args[2] or ''] then setLights({ move = args[2] })
    elseif sub == 'focus' and FOCUS[args[2] or ''] then setLights({ focus = { args[2], args[3], args[4] } })
    elseif sub == 'ring' and (args[2] == 'on' or args[2] == 'off') then setLights({ ring = args[2] == 'on' })
    elseif sub == 'ring' and (args[2] == 'color' or args[2] == 'colour') and args[3] then
        if not colour(args[3]) then return reply(src, 'a colour name (Config.LightColors) or #rrggbb') end
        setLights({ ring = true, ringColor = args[3] })
    elseif sub == 'ring' and args[2] == 'level' and tonumber(args[3]) then setLights({ ringLevel = tonumber(args[3]) / 100.0 })
    elseif sub == 'ring' and args[2] == 'own' then setLights({ ringColor = false })
    elseif sub == 'house' and HOUSE[args[2] or ''] then setLights({ house = args[2] })
    elseif sub == 'follow' and FOLLOW[(args[2] or ''):lower()] then setLights({ follow = args[2]:lower() })
    elseif sub == 'gobo' and (GOBOS[args[2] or ''] or args[2] == 'off' or args[2] == 'none') then setLights({ gobo = args[2] })
    elseif sub == 'lasers' and (args[2] == 'on' or args[2] == 'off') then setLights({ lasers = { on = args[2] == 'on' } })
    elseif sub == 'lasers' and LASERS[args[2] or ''] then setLights({ lasers = { on = true, pattern = args[2] } })
    elseif sub == 'lasers' and args[2] == 'desk' then setLights({ lasers = { colour = 'desk' } })
    elseif sub == 'lasers' and args[2] then
        if not colour(args[2]) then return reply(src, 'lasers on|off|fan|sweep|tunnel|scan|chase|desk|<colour>') end
        setLights({ lasers = { colour = args[2] } })
    elseif sub == 'haze' and (args[2] == 'off' or tonumber(args[2])) then
        setLights({ haze = args[2] == 'off' and 0 or tonumber(args[2]) / 100.0 })
    elseif sub == 'fog' and (args[2] == 'on' or args[2] == 'off') then setLights({ fog = { on = args[2] == 'on' } })
    elseif sub == 'fog' and args[2] == 'burst' then setLights({ fogBurst = tonumber(args[3]) or (Config.Fog or {}).burst or 8.0 })
    elseif sub == 'fog' and tonumber(args[2]) then setLights({ fog = { on = true, output = tonumber(args[2]) / 100.0 } })
    elseif sub == 'random' then randomLook()
    elseif sub == 'master' and tonumber(args[2]) then setLights({ master = tonumber(args[2]) / 100.0 })
    elseif sub == 'bo' then
        local a = args[2] and args[2]:lower()
        setLights({ bo = (a == 'on') or (a ~= 'off' and not current().bo) })
    elseif sub == 'bars' and (args[2] == 'on' or args[2] == 'off') then setLights({ bars = { on = args[2] == 'on' } })
    elseif sub == 'bars' and BARS[args[2] or ''] then setLights({ bars = { on = true, mode = args[2] } })
    elseif sub == 'bars' and BAR_WHERE[args[2] or ''] then setLights({ bars = { on = true, where = args[2] } })
    elseif sub == 'bars' and args[2] == 'level' and tonumber(args[3]) then setLights({ bars = { level = tonumber(args[3]) / 100.0 } })
    elseif sub == 'bars' and args[2] == 'desk' then setLights({ bars = { colour = 'desk' } })
    elseif sub == 'bars' and args[2] then
        if not colour(args[2]) then return reply(src, 'bars on|off|video|steady|chase|pulse|all|rafters|ledges|stage|level <n>|desk|<colour>') end
        setLights({ bars = { on = true, colour = args[2] } })
    elseif sub == 'preset' and args[2] then
        if not preset(args[2]:lower()) then
            local names = {}
            for _, k in ipairs(Config.LightPresetOrder or {}) do names[#names + 1] = k end
            return reply(src, 'presets: ' .. table.concat(names, ', '))
        end
    elseif sub ~= 'status' then
        return reply(src, HELP:format(Config.LightCommand))
    end
    status(src)
end, false)

-- other resources (a DJ script, a job's control panel, a goal horn) can run the lights too
exports('SetLights', function(patch) return setLights(patch) end)
exports('GetLights', function() return copy(current()) end)
exports('LightPreset', function(name) return preset(name) end)
exports('FadeLights', function(seconds) return fadeOut(seconds) end)
