-- mzb_arena - server: the light desk's state (GlobalState.mzbLights, synced to every client incl. late joiners)
--   GlobalState.mzbLights = { on, mode, move, colors = { {r, g, b} x 1..3 }, bpm, intensity (0..1),
--                             focus (one of floor / stage / crowd, or a list of them), ring, house,
--                             follow (off / both / tempo / colour: the lights follow the music, Config.LightFollow),
--                             fade ({ at = server ms, dur = s }: the show lights are fading out, off when they are
--                             down; switching them on or off ends it) }
-- Who may change it: Config.LightAccess (an ACE; false = anyone). The desk (NUI) and chat both land in setLights.
--   /arenalights                   open the desk
--   /arenalights on | off | blackout | status | help
--   /arenalights fade [seconds]    the show lights fade out, then off (a video that stops does this: Config.Media.lightsOut)
--   /arenalights mode <static|chase|strobe|pulse|rainbow|sweep|ballyhoo|random|police|fade|wave|flash|alternate|
--                      twinkle|lightning|fire|bounce>       the colour effect
--   /arenalights move <none|sweep|ballyhoo|fan|nod|cross>    the beams' movement (combines with any mode)
--   /arenalights color <name|#rrggbb> [second] [third]
--   /arenalights bpm <30-240> | intensity <0-100> | house <show|full|dim|off>
--   /arenalights follow <off|on|tempo|colour>   the effects run on the music's beat and / or in the video's colours
--   /arenalights focus <floor|stage|crowd> [more ...]      several: the fixtures take turns (e.g. focus floor crowd)
--   /arenalights ring <on|off|color <c>|level <0-100>|own> the ring lights (the rig's own, on by default): off, a
--                                                          colour for all of them, their level, back to their own colours
--   /arenalights preset <name>     (Config.LightPresets)

local MODES = { static = true, chase = true, strobe = true, pulse = true, rainbow = true, sweep = true,
                ballyhoo = true, random = true, police = true, fade = true, wave = true, flash = true,
                alternate = true, twinkle = true, lightning = true, fire = true, bounce = true }
local MOVES = { none = true, sweep = true, ballyhoo = true, fan = true, nod = true, cross = true }
local FOCUS = { floor = true, stage = true, crowd = true }
local HOUSE = { show = true, full = true, dim = true, off = true }
local FOLLOW = { off = 'off', both = 'both', on = 'both', tempo = 'tempo', colour = 'colour', color = 'colour' }

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
    end
    if tonumber(patch.bpm) then out.bpm = math.floor(math.max(30, math.min(240, tonumber(patch.bpm)))) end
    if tonumber(patch.intensity) then out.intensity = math.max(0.0, math.min(1.0, tonumber(patch.intensity))) end
    if type(patch.colors) == 'table' then
        local cs = {}
        for i = 1, math.min(3, #patch.colors) do
            local c = colour(patch.colors[i])
            if c then cs[#cs + 1] = c end
        end
        if #cs > 0 then out.colors = cs end
    end
    return out
end

local function current()
    return GlobalState.mzbLights or copy(Config.LightDefault)
end

local function setLights(patch)
    GlobalState.mzbLights = sanitize(patch, current())
    return true
end

local function preset(name)
    local p = Config.LightPresets and Config.LightPresets[name]
    if not p then return false end
    setLights(p)
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
    if dur < 0.1 then return setLights({ on = false }) end
    local at = GetGameTimer()
    cur.fade = { at = at, dur = dur }
    GlobalState.mzbLights = cur
    SetTimeout(math.floor(dur * 1000) + 100, function()
        local now = current()
        if now.fade and now.fade.at == at then setLights({ on = false }) end
    end)
    return true
end

-- (server/media.lua: a video that stops)
MzbLightsOut = fadeOut

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
    reply(src, ('show lights %s | mode %s | move %s | colours %s | %d bpm | intensity %d%% | aim %s | ring lights %s | house %s | follow the music: %s')
        :format(l.on and (l.fade and 'ON (fading out)' or 'ON') or 'off', l.mode, l.move or 'none', table.concat(cs, ' '), l.bpm,
            math.floor(l.intensity * 100 + 0.5), fo, ring, l.house, l.follow or 'off'))
end

local HELP = '/%s [on|off|fade [s]|blackout|status] | mode <m> | move <none|sweep|ballyhoo|fan|nod|cross> | color <c> [c2] [c3] | ' ..
             'bpm <n> | intensity <0-100> | focus <floor|stage|crowd> [more] | ring <on|off|color <c>|level <n>|own> | ' ..
             'house <show|full|dim|off> | follow <off|on|tempo|colour> | preset <name>'

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
