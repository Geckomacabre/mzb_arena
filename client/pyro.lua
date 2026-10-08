-- mzb_arena - client: the pyro (Config.Pyro, server/pyro.lua says when).
-- A cue arrives with the show it was fired for; a player near the arena runs its steps: each step sets an effect off
-- at every unit of a group, one after the other when it has a stagger. The effects are the game's own particle
-- effects (the fireworks', the Arena's fire pits, confetti): nothing burns and nobody is hurt. A looped effect (the
-- flames) is started and stopped again; a flash of light on the stage goes with the ones that have a colour.
-- A cue comes with what the desk had set for it: its size (Config.Pyro.sizes: times every effect's scale) and a
-- colour, for the effects that take one (tint).
-- The desk's Pyro section (html/pyro.js) lists the cues the show that is up can fire, in their groups.

local PY = Config.Pyro or {}
if PY.enabled == false then return end

local loops = {}                                    -- looped effects that are on: handle -> true
local flashes = {}                                  -- { x, y, z, r, g, b, until (game ms) }

local function near()
    return #(GetEntityCoords(PlayerPedId()) - Config.Screens.origin) < (PY.range or 180.0)
end

local function asset(name)
    if HasNamedPtfxAssetLoaded(name) then return true end
    RequestNamedPtfxAsset(name)
    local untilT = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(name) do
        if GetGameTimer() > untilT then
            print(('[mzb_arena] pyro: the particle asset "%s" did not load'):format(name))
            return false
        end
        Wait(0)
    end
    return true
end

-- one effect at one unit. step: the step's own scale, loop and direction; k: the cue's size; rgb: its colour
local function setOff(fx, p, step, k, rgb)
    if not asset(fx.asset) then return end
    local z = p.z + (fx.up or 0.0)
    local scale = (fx.scale or 1.0) * (step.scale or 1.0) * k
    local rx = step.down and 180.0 or 0.0
    local tint = fx.tint and rgb or nil
    local loop = step.loop or fx.loop
    UseParticleFxAsset(fx.asset)
    if loop then
        local h = StartParticleFxLoopedAtCoord(fx.name, p.x, p.y, z, rx, 0.0, 0.0, scale, false, false, false, false)
        if tint then SetParticleFxLoopedColour(h, tint[1] / 255.0, tint[2] / 255.0, tint[3] / 255.0, false) end
        loops[h] = true
        SetTimeout(math.floor(loop * 1000), function()
            if loops[h] then StopParticleFxLooped(h, false); loops[h] = nil end
        end)
    else
        if tint then SetParticleFxNonLoopedColour(tint[1] / 255.0, tint[2] / 255.0, tint[3] / 255.0) end
        StartParticleFxNonLoopedAtCoord(fx.name, p.x, p.y, z, rx, 0.0, 0.0, scale, false, false, false)
    end
    local lc = tint or fx.light
    if lc then
        flashes[#flashes + 1] = { p.x, p.y, z + (step.down and -0.6 or 0.6), lc[1], lc[2], lc[3],
                                  GetGameTimer() + math.floor((loop or 0.35) * 1000) }
    end
    if fx.sound then PlaySoundFromCoord(-1, fx.sound[1], p.x, p.y, z, fx.sound[2], false, 120.0, false) end
end

-- a step's units in the order it fires them: its pick, the list backwards, or the list
local function unitsOf(list, step)
    if type(step.pick) == 'table' then
        local out = {}
        for _, i in ipairs(step.pick) do
            if list[i] then out[#out + 1] = list[i] end
        end
        return out
    elseif step.reverse then
        local out = {}
        for i = #list, 1, -1 do out[#out + 1] = list[i] end
        return out
    end
    return list
end

-- the cues the show's units can fire, in the desk's order (the same rule as the server's)
local function cuesFor(show)
    local units, out = (PY.units or {})[show], {}
    if not units then return out end
    for _, name in ipairs(PY.order or {}) do
        local c = (PY.cues or {})[name]
        local ok = c ~= nil
        for _, step in ipairs(c and c.steps or {}) do
            if not units[step.units] or not (PY.effects or {})[step.fx] then ok = false end
        end
        if ok then out[#out + 1] = { name = name, label = c.label or name, group = c.group } end
    end
    return out
end

RegisterNetEvent('mzb_arena:pyroFire', function(name, show, opts)
    local cue = type(name) == 'string' and (PY.cues or {})[name]
    local units = (PY.units or {})[show]
    if not cue or not units or not near() then return end
    opts = type(opts) == 'table' and opts or {}
    local k = tonumber((PY.sizes or {})[opts.size]) or 1.0
    local rgb = type(opts.rgb) == 'table' and tonumber(opts.rgb[1]) and tonumber(opts.rgb[2]) and tonumber(opts.rgb[3])
        and opts.rgb or nil
    for _, step in ipairs(cue.steps or {}) do
        local fx, list = (PY.effects or {})[step.fx], units[step.units]
        if fx and list then
            CreateThread(function()
                if step.at then Wait(math.floor(step.at * 1000)) end
                for _, p in ipairs(unitsOf(list, step)) do
                    setOff(fx, p, step, k, rgb)
                    if step.stagger then Wait(math.floor(step.stagger * 1000)) end
                end
            end)
        end
    end
end)

-- the flashes: a light at each effect that has a colour, while it goes off
CreateThread(function()
    while true do
        if #flashes == 0 then
            Wait(100)
        else
            local now = GetGameTimer()
            for i = #flashes, 1, -1 do
                local f = flashes[i]
                if now > f[7] then table.remove(flashes, i)
                else DrawLightWithRange(f[1], f[2], f[3], f[4], f[5], f[6], 9.0, 6.0) end
            end
            Wait(0)
        end
    end
end)

-- ------------------------------------------------------------------ the desk's Pyro section (html/pyro.js)
local function deskUpdate()
    local colours = {}
    for name, c in pairs(Config.LightColors or {}) do colours[#colours + 1] = { name = name, rgb = c } end
    table.sort(colours, function(a, b) return a.name < b.name end)
    SendNUIMessage({ type = 'pyroDesk', cues = cuesFor(GlobalState.mzbShow or Config.DefaultShow), colours = colours })
end
AddEventHandler('mzb_arena:lightsDesk', deskUpdate)
AddStateBagChangeHandler('mzbShow', 'global', function() SetTimeout(0, deskUpdate) end)

RegisterNUICallback('pyro', function(data, cb)
    cb('ok')
    if type(data) == 'table' and type(data.cue) == 'string' then
        TriggerServerEvent('mzb_arena:pyro', data.cue, { size = data.size, colour = data.colour })
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (PY.command or 'arenapyro'), 'Maze Bank Arena: fire a pyro cue',
        { { name = 'cue', help = 'list (the cues of the show that is up) | a cue' },
          { name = 'size', help = 'small | big (optional)' }, { name = 'colour', help = 'a colour name, #rrggbb or lights (optional)' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for h in pairs(loops) do StopParticleFxLooped(h, false) end
    TriggerEvent('chat:removeSuggestion', '/' .. (PY.command or 'arenapyro'))
end)
