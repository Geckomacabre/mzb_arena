-- mzb_arena - server: the pyro's cues (Config.Pyro; client/pyro.lua fires them).
-- A cue is checked here (it exists, the show that is up has the units it needs, whoever asked may, not too soon after
-- the last one) and then sent to every player; each one near the arena fires it on its own.
--   /arenapyro <cue> [small|big] [colour]   fire a cue (Config.Pyro.cues), at a size, in a colour (a name from
--                                           Config.LightColors, #rrggbb, or "lights": the show lights' first colour)
--   /arenapyro list                         the cues of the show that is up

local PY = Config.Pyro or {}
local last = -100000

local function show() return GlobalState.mzbShow or Config.DefaultShow end

-- the cues the show's units can fire, in the desk's order
local function cuesFor(s)
    local units, out = (PY.units or {})[s], {}
    if not units then return out end
    for _, name in ipairs(PY.order or {}) do
        local c = (PY.cues or {})[name]
        local ok = c ~= nil
        for _, step in ipairs(c and c.steps or {}) do
            if not units[step.units] or not (PY.effects or {})[step.fx] then ok = false end
        end
        if ok then out[#out + 1] = name end
    end
    return out
end

-- what a cue goes off with, from the desk / chat / an export: { size = 'small' | 'normal' | 'big',
-- colour = a name from Config.LightColors | '#rrggbb' | 'lights' | { r, g, b } } -> { size, rgb } for the clients
local function options(o)
    local out = {}
    if type(o) ~= 'table' then return out end
    if type(o.size) == 'string' and (PY.sizes or {})[o.size] then out.size = o.size end
    local c = o.colour or o.color
    if c == 'lights' then
        local cs = (GlobalState.mzbLights or {}).colors
        if type(cs) == 'table' and type(cs[1]) == 'table' then out.rgb = { cs[1][1], cs[1][2], cs[1][3] } end
    elseif type(c) == 'string' and #c <= 16 then
        local named = (Config.LightColors or {})[c:lower()]
        local hex = c:match('^#?(%x%x%x%x%x%x)$')
        if named then out.rgb = { named[1], named[2], named[3] }
        elseif hex then out.rgb = { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) } end
    elseif type(c) == 'table' and tonumber(c[1]) and tonumber(c[2]) and tonumber(c[3]) then
        out.rgb = {}
        for i = 1, 3 do out.rgb[i] = math.floor(math.max(0, math.min(255, tonumber(c[i])))) end
    end
    return out
end

-- fire a cue: true, or false and why not
local function fire(name, opts)
    if not PY.enabled then return false, 'the pyro is off (Config.Pyro.enabled)' end
    local s = show()
    local have = cuesFor(s)
    if #have == 0 then return false, ('the %s show has no pyro'):format(tostring(s)) end
    local known = false
    for _, n in ipairs(have) do known = known or n == name end
    if not known then return false, 'cues: ' .. table.concat(have, '  ') end
    local now = GetGameTimer()
    if now - last < (PY.cooldown or 1.5) * 1000 then return false, 'the pyro is reloading' end
    last = now
    TriggerClientEvent('mzb_arena:pyroFire', -1, name, s, options(opts))
    return true
end

function MzbPyro(name) return fire(name) end          -- the fights' cues (server/fights.lua)

local function allowed(src) return MzbAllowed(src, PY.access) end

local function command(src, args)
    local name = args[1] and tostring(args[1]):lower()
    if not name or name == 'list' then
        local have = cuesFor(show())
        return MzbReply(src, 'pyro', #have > 0 and ('cues: ' .. table.concat(have, '  ')) or 'this show has no pyro')
    end
    if not allowed(src) then return MzbReply(src, 'pyro', 'you are not allowed to fire the pyro') end
    local opts = {}
    for i = 2, 3 do                                      -- a size and a colour, in either order
        local a = args[i] and tostring(args[i]):lower()
        if a and (PY.sizes or {})[a] then opts.size = a elseif a then opts.colour = a end
    end
    local ok, err = fire(name, opts)
    MzbReply(src, 'pyro', ok and ('fired: ' .. name) or err)
end

RegisterCommand(PY.command or 'arenapyro', function(src, args) command(src, args) end, false)

-- the desk's buttons
local throttled = MzbThrottle(300)
RegisterNetEvent('mzb_arena:pyro', function(name, opts)
    local src = source
    if throttled(src) or type(name) ~= 'string' or #name > 32 or not allowed(src) then return end
    local ok, err = fire(name, opts)
    if not ok and err then MzbReply(src, 'pyro', err) end
end)

-- other resources: an entrance script, a title win
exports('Pyro', function(name, opts) return fire(tostring(name), opts) end)
exports('PyroCues', function() return cuesFor(show()) end)
