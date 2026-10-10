-- mzb_arena - client: the people in the arena you can talk to (the event desk's official: client/desk.lua, the merch
-- stand's seller: client/merch.lua) and the small menu they open.
--   ArenaPed.add{ id, model, coords = vector4(x, y, the floor's z, heading), scenario, room, distance, label, icon,
--                 onUse = function() ... end, enabled = function() return true end }
--   ArenaMenu.open{ id, title, options = { { title, description, icon, disabled, event, args } ... } }
--   ArenaMenu.close()
-- A ped is a local one (not networked): made while the player is within 60 m of its spot, frozen, invincible, deaf to
-- what goes on round it, and taken away again further off or when the resource stops. You talk to it through
-- ox_target if the server runs it, else qb-target, else a prompt and [E] within `distance`.
-- The menu is an ox_lib context menu when the server runs ox_lib (Config.OxLib); without it, a numbered list on the
-- left of the screen: the number keys pick, Backspace shuts it. Either way a pick is a client event with the option's
-- args (an option without an event is a line to read) - what a pick asks for is checked by the server.

ArenaPed, ArenaMenu = {}, {}

local SPAWN, DESPAWN = 60.0, 75.0
local list = {}                    -- what add was given, plus: ped (while it stands there), target (the resource)
local promptAt = -10000            -- when a ped's [E] prompt was last on the screen

local function started(name)
    return GetResourceState(name) == 'started'
end

local function oxOn()
    return Config.OxLib and started('ox_lib')
end

local function loadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local untilT = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > untilT then return false end
        Wait(0)
    end
    return true
end

local function use(p)
    local now = GetGameTimer()
    if not p.onUse or now - (p.usedAt or -10000) < 500 then return end
    p.usedAt = now
    p.onUse()
end

-- ------------------------------------------------------------------ the peds
local function addTarget(p)
    local name = 'mzb_arena_' .. p.id
    if started('ox_target') then
        exports.ox_target:addLocalEntity(p.ped, { { name = name, icon = 'fa-solid fa-' .. (p.icon or 'comment'),
            label = p.label, distance = p.distance, onSelect = function() use(p) end } })
        p.target = 'ox_target'
    elseif started('qb-target') then
        exports['qb-target']:AddTargetEntity(p.ped, { options = { { icon = 'fas fa-' .. (p.icon or 'comment'),
            label = p.label, action = function() use(p) end } }, distance = p.distance })
        p.target = 'qb-target'
    end
end

local function remove(p)
    local ped = p.ped
    if not ped then return end
    if p.target and started(p.target) then
        if p.target == 'ox_target' then
            exports.ox_target:removeLocalEntity(ped, 'mzb_arena_' .. p.id)
        else
            exports['qb-target']:RemoveTargetEntity(ped)
        end
    end
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    p.ped, p.target = nil, nil
end

local function spawn(p)
    local model = GetHashKey(p.model)
    if not loadModel(model) then return end
    local c = p.coords
    local ped = CreatePed(4, model, c.x, c.y, c.z, c.w, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then return end
    SetEntityHeading(ped, c.w)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanBeTargetted(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    if p.room then                                         -- (a ped the game does not find the room of stays unseen)
        local id = MzbInterior()
        if id ~= 0 then ForceRoomForEntity(ped, id, GetHashKey(p.room)) end
    end
    if p.scenario then TaskStartScenarioInPlace(ped, p.scenario, 0, true) end
    p.ped = ped
    addTarget(p)
end

function ArenaPed.add(p)
    if type(p) ~= 'table' or type(p.coords) ~= 'vector4' and type(p.coords) ~= 'table' then return false end
    p.distance = tonumber(p.distance) or 2.2
    p.label = p.label or 'Talk'
    list[#list + 1] = p
    return true
end

-- there within 60 m, gone further off (once a second)
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i = 1, #list do
            local p = list[i]
            local c = p.coords
            local dist = #(pos - vector3(c.x, c.y, c.z))
            local on = not p.enabled or p.enabled()
            if p.ped and (not on or dist > DESPAWN or not DoesEntityExist(p.ped)) then
                remove(p)
            elseif not p.ped and on and dist < SPAWN then
                spawn(p)
            end
        end
        Wait(1000)
    end
end)

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

-- the prompt and [E], for a ped no target script has (on foot: at the wheel E is the horn)
CreateThread(function()
    while true do
        local wait = 500
        local me = PlayerPedId()
        local pos = GetEntityCoords(me)
        for i = 1, #list do
            local p = list[i]
            if p.ped and not (p.target and started(p.target)) and not ArenaMenu.isOpen() then
                local c = p.coords
                if #(pos - vector3(c.x, c.y, c.z + 1.0)) < p.distance and not IsPedInAnyVehicle(me, false) then
                    wait = 0
                    promptAt = GetGameTimer()
                    help('~INPUT_PICKUP~ ' .. p.label)
                    if IsControlJustReleased(0, 38) then use(p) end
                end
            end
        end
        Wait(wait)
    end
end)

-- is a ped's [E] prompt up? (client/shop.lua: a tee's own prompt waits - E is the key of both)
function ArenaPed.prompted()
    return GetGameTimer() - promptAt < 150
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = 1, #list do remove(list[i]) end
end)

-- ------------------------------------------------------------------ the menu
local PER_PAGE = 8
local KEYS = { 157, 158, 160, 164, 165, 159, 161, 162, 163 }    -- the number keys 1 to 9
local menu = nil                   -- the list on screen: { title, options, page, at = where it was opened }
local drawing = false

function ArenaMenu.isOpen()
    return menu ~= nil
end

function ArenaMenu.close()
    menu = nil
end

local function line(x, y, scale, str, r, g, b)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(str:sub(1, 96))
    EndTextCommandDisplayText(x, y)
end

local function pick(o)
    menu = nil
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    if o.event then TriggerEvent(o.event, o.args) end
end

-- one frame of the list: its page drawn, its keys read
local function drawMenu(m)
    local pages = math.max(1, math.ceil(#m.options / PER_PAGE))
    local y = 0.30
    line(0.02, y, 0.55, m.title .. (pages > 1 and ('  (%d/%d)'):format(m.page + 1, pages) or ''), 255, 255, 255)
    y = y + 0.042
    local n, picks = 0, {}
    for i = m.page * PER_PAGE + 1, math.min(#m.options, (m.page + 1) * PER_PAGE) do
        local o = m.options[i]
        local text = o.title .. (o.description and ('  -  ' .. o.description) or '')
        if o.event and not o.disabled then
            n = n + 1
            picks[n] = o
            line(0.02, y, 0.4, ('%d   %s'):format(n, text), 240, 240, 240)
        else
            line(0.02, y, 0.4, '     ' .. text, 160, 160, 160)
        end
        y = y + 0.03
    end
    line(0.02, y + 0.008, 0.33, (pages > 1 and '9   More     ' or '') .. 'Backspace   Close', 160, 160, 160)
    for k = 1, 9 do DisableControlAction(0, KEYS[k], true) end
    DisableControlAction(0, 177, true)
    for k = 1, n do
        if IsDisabledControlJustPressed(0, KEYS[k]) then return pick(picks[k]) end
    end
    if pages > 1 and IsDisabledControlJustPressed(0, KEYS[9]) then m.page = (m.page + 1) % pages end
    if IsDisabledControlJustPressed(0, 177) or #(GetEntityCoords(PlayerPedId()) - m.at) > 4.0 then menu = nil end
end

function ArenaMenu.open(m)
    if type(m) ~= 'table' or type(m.options) ~= 'table' then return end
    if oxOn() then
        local opts = {}
        for i, o in ipairs(m.options) do
            opts[i] = { title = o.title, description = o.description, icon = o.icon, disabled = o.disabled,
                        event = o.event, args = o.args, readOnly = not o.event or nil }
        end
        exports.ox_lib:registerContext({ id = m.id, title = m.title, options = opts })
        exports.ox_lib:showContext(m.id)
        return
    end
    local mine = { title = m.title or 'Maze Bank Arena', options = m.options, page = 0,
                   at = GetEntityCoords(PlayerPedId()) }
    menu = mine
    if drawing then return end                             -- the list that is up shows the new one from its next frame
    drawing = true
    CreateThread(function()
        while menu do
            drawMenu(menu)
            Wait(0)
        end
        drawing = false
    end)
end
