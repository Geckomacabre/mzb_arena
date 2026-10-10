-- mzb_arena - client: which interior is the arena (MzbInterior), and the show standing in it - the interior's entity
-- sets, kept the way the show wants them

-- ------------------------------------------------------------------ which interior is the arena
-- MzbInterior() -> id (0 = none), ready. Every script here that puts something into the arena asks this.
-- It is the interior the game has at Config.InteriorProbe - unless the player stands in a different interior inside
-- the arena's walls: then that one is the arena, and standing in it counts as ready. The second half is the guard for
-- joining again with the game left open (after a server restart): the probe can then keep answering with an interior
-- that never becomes ready, and everything that waits for it - the show's pieces, the crowd, the props - stays away.
local P = Config.InteriorProbe
local F = Config.ArenaFrame or { x = P.x, y = P.y, z = P.z - 5.45, ang = 0.0 }
local FC, FS = math.cos(F.ang), math.sin(F.ang)
-- the building in the arena's own frame (u along it, v across, h over the event floor): the interior's box in
-- stream/interior/mzb_arena.ytyp and 6 m
local BOX = Config.InteriorBox or { u0 = -110.0, u1 = 97.0, v = 67.0, h0 = -7.0, h1 = 51.0 }

local function inBuilding(c)
    local dx, dy = c.x - F.x, c.y - F.y
    local u, v, h = dx * FC + dy * FS, -dx * FS + dy * FC, c.z - F.z
    return u > BOX.u0 and u < BOX.u1 and v > -BOX.v and v < BOX.v and h > BOX.h0 and h < BOX.h1
end

-- the interior at the probe, the interior the player is in (0 = none) and whether that is inside the building
local function interiors()
    local ped = PlayerPedId()
    local mine = GetInteriorFromEntity(ped)
    return GetInteriorAtCoords(P.x, P.y, P.z), mine, mine ~= 0 and inBuilding(GetEntityCoords(ped))
end

function MzbInterior()
    local id, mine, inside = interiors()
    if inside and mine ~= id then id = mine end
    if id == 0 then return 0, false end
    return id, mine == id or (IsInteriorReady(id) and true or false)
end

-- ------------------------------------------------------------------ the show (interior entity sets)
-- Since 1.2.0 the lower tier's front seven rows are a set of their own: seated, or folded back for the bigger floor.
-- A show that names neither - a config kept from before 1.2.0, a show of the owner's own - is given the seated rows
-- here, in Config.Shows itself: it keeps rows 1 to 7 and the padded wall, instead of a tier that starts at row 8
-- over an open wall. This is the first client script, so everything after it (the sets below, the crowd's seats)
-- reads the completed lists; the server does the same to its own copy (server/main.lua).
for _, sets in pairs(Config.Shows) do
    local front = false
    for _, s in ipairs(sets) do
        if s == 'mzb_set_low_front_seated' or s == 'mzb_set_low_front_stowed' then front = true end
    end
    if not front then sets[#sets + 1] = 'mzb_set_low_front_seated' end
end

local managed = {}                 -- every set a show or the house lights name
for _, sets in pairs(Config.Shows) do
    for _, s in ipairs(sets) do managed[s] = true end
end
for _, s in pairs(Config.HouseSets or {}) do managed[s] = true end

-- the sets a show wants on, with the light desk's house buttons (client/lights.lua): the show's own house light set,
-- or full / dimmed / off
local function wanted(name)
    local sets = Config.Shows[name]
    if not sets then return nil end
    local on = {}
    for _, s in ipairs(sets) do on[s] = true end
    local house = (GlobalState.mzbLights or {}).house or 'show'
    local hs = Config.HouseSets or {}
    if house ~= 'show' then
        for _, s in pairs(hs) do on[s] = nil end
        if hs[house] then on[hs[house]] = true end
    end
    -- sets another resource asked to have left out (the server's HideSets export: it brings a ring or a stage of
    -- its own and ours would stand in it)
    for _, s in ipairs(GlobalState.mzbHideSets or {}) do on[s] = nil end
    return on
end

local function isOn(id, s)
    local a = IsInteriorEntitySetActive(id, s)
    return a == true or a == 1
end

local function matches(id, on)
    for s in pairs(managed) do
        if isOn(id, s) ~= (on[s] == true) then return false end
    end
    return true
end

local function set(id, on)
    for s in pairs(managed) do
        local a = isOn(id, s)
        if on[s] and not a then
            ActivateInteriorEntitySet(id, s)
        elseif a and not on[s] then
            DeactivateInteriorEntitySet(id, s)
        end
    end
    RefreshInterior(id)
end

local function applyShow(name)
    local on = wanted(name)
    local id = MzbInterior()
    if on and id ~= 0 then set(id, on) end
end

AddStateBagChangeHandler('mzbShow', 'global', function(_, _, value)
    Wait(0)
    applyShow(value)
end)

AddStateBagChangeHandler('mzbHideSets', 'global', function()
    Wait(0)
    applyShow(GlobalState.mzbShow or Config.DefaultShow)
end)

-- (client/lights.lua: the desk's house setting changed)
function MzbReapplyShow()
    Wait(0)
    applyShow(GlobalState.mzbShow or Config.DefaultShow)
end

-- The interior streams in and out, and its sets can be lost without a word (the game making the interior again
-- under the number it had; joining again with the game left open). Once a second: an interior seen ready for the
-- first time gets the show, and one that has it is compared with the show and put right when a set is missing or
-- left over. An interior that does not keep the sets is left alone after three tries, with a line in F8.
CreateThread(function()
    local done, lastShow, tries = 0, nil, 0
    while true do
        local id, ready = MzbInterior()
        local show = GlobalState.mzbShow or Config.DefaultShow
        local on = wanted(show)
        if id == 0 then
            done = 0
        elseif on and ready then
            if id ~= done or show ~= lastShow then tries = 0 end
            local ok = matches(id, on)
            if id ~= done or (not ok and tries < 3) then
                set(id, on)
                done = id
                if matches(id, on) then
                    tries = 0
                else
                    tries = tries + 1
                    if tries == 3 then
                        print(('[mzb_arena] interior %d does not keep the sets of "%s" - send /arenainfo'):format(id, show))
                    end
                end
            elseif ok then
                tries = 0
            end
        end
        lastShow = show
        Wait(1000)
    end
end)

-- What a per-show table has for a show, or what it has for the empty house: the screens' model, the light rig and
-- its aim, the speakers and the screens' artwork are looked up through this. A show such a table does not name -
-- the big-floor shows (floor, monster, motocross, karting, sprint, oval, skatepark), a show of the owner's own - is then
-- screened, lit and heard as the empty house is: the centre-hung board and the roof's house lights.
function MzbShowEntry(t, show)
    if type(t) ~= 'table' then return nil end
    local v = t[show]
    if v == nil then v = t.house end
    return v
end

-- (client/main.lua's /arenainfo) the interiors as the game has them and the show's sets on the arena's
function MzbShowStatus()
    local probe, mine, inside = interiors()
    local id, ready = MzbInterior()
    local show = GlobalState.mzbShow or Config.DefaultShow
    local n, have = 0, 0
    for s in pairs(wanted(show) or {}) do
        n = n + 1
        if id ~= 0 and isOn(id, s) then have = have + 1 end
    end
    return ('interior %d (arena %d, at the probe %d%s, ready %s) | show %s, %d of %d sets on'):format(mine, id, probe,
        (mine ~= 0 and not inside) and ', outside the building' or '', tostring(ready), tostring(show), have, n)
end

-- /arenareset: take the show's pieces down and set them up again, on your own screen only - for an arena that stands
-- bare or half set although /arenainfo counts every set on
RegisterCommand('arenareset', function()
    CreateThread(function()
        local id = MzbInterior()
        local on = wanted(GlobalState.mzbShow or Config.DefaultShow)
        local msg = 'you are not at the arena'
        if id ~= 0 and on then
            set(id, {})
            Wait(500)
            set(id, on)
            msg = 'the show was set up again: ' .. MzbShowStatus()
        end
        print('[mzb_arena] ' .. msg)
        TriggerEvent('chat:addMessage', { args = { 'arena', msg } })
    end)
end, false)
