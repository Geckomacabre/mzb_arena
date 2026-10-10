-- mzb_arena - client: the tees on the merch stand's walls (Config.MerchShop; where each one hangs and what it is:
-- Config.MerchTees, shared/merch_tees.lua; who owns what and the till: server/shop.lua).
--   * at the stand: the tee nearest you carries a white dot and the word TEES; you pick one through ox_target or
--     qb-target (a small zone on every hanging tee) when the server runs one, else by looking at it and pressing E;
--   * trying on: your character turns its back to the wall and is held there, the camera cuts to its front, the tee
--     goes on (the stand's own drawable of the addon collection, the tee's texture, the arms and the undershirt that
--     go with a tee). Left / right show the stand's other tees, Enter buys and wears (wears one you own, takes off
--     the one you wear), Backspace or Esc leaves. The page shows what the clip shows (html/shop.js): it is display
--     only, the keys are read here;
--   * leaving: what you wear is what you kept - a tee you bought or put on - else what you came in with.
-- Only the freemode characters can wear them. The server decides every purchase; wearing what is owned and taking
-- it off are this game's own business. After each, the look is saved through illenium-appearance when the server
-- runs it (Config.MerchShop.save), and the client event mzb_arena:shop:worn (style, tee or false, drawable, texture)
-- fires for any other clothing script to hook.

local SC = Config.MerchShop or {}
if SC.enabled == false then return end

local TEES = type(Config.MerchTees) == 'table' and Config.MerchTees or {}
local MC = Config.Merch or {}
local COMP = tonumber(SC.component) or 11
local ARMS, UNDER = 3, 8
local CHEST = 0.3                  -- m from a ped's own place (its hips) up to its chest
local NEAR, MARK = 25.0, 3.0       -- m: the targets are up this close to the stand / the dot is on a tee this close
local BARE = { [COMP] = { 15, 0 }, [ARMS] = { 15, 0 }, [UNDER] = { 15, 0 } }   -- a freemode character's bare top
local MODELS = { [GetHashKey('mp_m_freemode_01')] = 'male', [GetHashKey('mp_f_freemode_01')] = 'female' }
local STYLES = 0
for _ in pairs(TEES) do STYLES = STYLES + 1 end

local T = nil                      -- trying on: { style, stand, gender, tee, before, keep, wearing, cameIn, owned,
                                   --   cash, price, cam, busy }
local zones, zonesFor = {}, nil    -- the target zones that are up, and what for ('<target script>:<style>')

local function started(name)
    return GetResourceState(name) == 'started'
end

local function styleNow()
    return (MC.styleOf or {})[GlobalState.mzbShow or Config.DefaultShow] or 'arena'
end

-- a style's stand, if it has tees on its walls
local function standOf(style)
    local s = TEES[style]
    if type(s) ~= 'table' or type(s.tees) ~= 'table' or type(s.hung) ~= 'table' or #s.hung == 0 then return nil end
    return s
end

local function priceOf(style)
    local p = type(SC.prices) == 'table' and SC.prices[style] or SC.price
    return math.max(0, math.floor(tonumber(p) or 35))
end

local function notify(msg)
    TriggerEvent('mzb_arena:notify', msg)
end

-- ------------------------------------------------------------------ what the ped wears
local function wornNow(ped)
    local w = {}
    for _, c in ipairs({ COMP, ARMS, UNDER }) do
        w[c] = { GetPedDrawableVariation(ped, c), GetPedTextureVariation(ped, c) }
    end
    return w
end

local function dress(ped, w)
    for _, c in ipairs({ COMP, ARMS, UNDER }) do
        if w[c] then SetPedComponentVariation(ped, c, w[c][1], w[c][2], 0) end
    end
end

-- the stand's tee n on the ped: false when the game has no such shirt (the clothing pack is not installed)
local function putOn(ped, t, n)
    local drawable, texture = tonumber(t.stand.drawable) or 0, n - 1
    local pack = (SC.collection or {})[t.gender]
    if SetPedCollectionComponentVariation and pack then
        -- by the pack's name: the drawable is the pack's own number, wherever the game has put the pack
        if IsPedCollectionComponentVariationValid
           and not IsPedCollectionComponentVariationValid(ped, COMP, pack, drawable, texture) then
            return false
        end
        SetPedCollectionComponentVariation(ped, COMP, pack, drawable, texture, 0)
    else
        -- an old client build: by the model's own numbering (Config.MerchShop.firstDrawable, else the pack is taken
        -- to be the last one loaded: its drawables are the model's last)
        local first = (SC.firstDrawable or {})[t.gender]
        first = tonumber(first) or (GetNumberOfPedDrawableVariations(ped, COMP) - STYLES)
        if first < 0 or not IsPedComponentVariationValid(ped, COMP, first + drawable, texture) then return false end
        SetPedComponentVariation(ped, COMP, first + drawable, texture, 0)
    end
    local fit = (SC.fit or {})[t.gender] or {}
    if fit.arms then SetPedComponentVariation(ped, ARMS, fit.arms, 0, 0) end
    if fit.undershirt then SetPedComponentVariation(ped, UNDER, fit.undershirt, 0, 0) end
    return true
end

local function same(a, b)
    return a and b and a[COMP][1] == b[COMP][1] and a[COMP][2] == b[COMP][2]
end

-- the look has changed for good (bought, put on, taken off): saved, and said to whoever wants to know
local function worn(t, n)
    local ped = PlayerPedId()
    if SC.save and started('illenium-appearance') then
        pcall(function()
            local a = exports['illenium-appearance']:getPedAppearance(ped)
            TriggerServerEvent('illenium-appearance:server:saveAppearance', a)
        end)
    end
    TriggerEvent('mzb_arena:shop:worn', t.style, n or false, GetPedDrawableVariation(ped, COMP), GetPedTextureVariation(ped, COMP))
end

-- ------------------------------------------------------------------ the page (html/shop.js)
local function status(t)
    if t.wearing == t.tee then return 'Wearing' end
    return t.owned[t.tee] and 'Owned' or 'Not owned'
end

local function hud(t)
    local tees = {}
    for i, x in ipairs(t.stand.tees) do
        tees[i] = { label = x.label, colour = x.colour, owned = t.owned[i] == true }
    end
    SendNUIMessage({ shop = { open = true, style = t.style, tee = t.tee, tees = tees, price = t.price,
                              cash = t.cash or false, status = status(t), index = t.tee, count = #tees } })
end

-- ------------------------------------------------------------------ trying on
-- out of it: the camera back, the ped let go, and on it what was kept (quick: the resource is stopping)
local function leave(quick)
    local t = T
    if not t then return end
    T = nil
    local ped = PlayerPedId()
    dress(ped, t.keep)
    if t.cam then
        RenderScriptCams(false, not quick, quick and 0 or 400, true, false)
        DestroyCam(t.cam, false)
    end
    FreezeEntityPosition(ped, false)
    SendNUIMessage({ shop = { open = false } })
end

local function show(t, n)
    local ped = PlayerPedId()
    if not putOn(ped, t, n) then return false end
    t.tee = n
    hud(t)
    return true
end

-- Enter: buy and wear what is not owned (the server's word first), wear what is, take off what is worn
local function act(t)
    local ped = PlayerPedId()
    if t.wearing == t.tee then
        -- off: back to what the player came in with - unless that is this very tee: then a bare top
        local back = same(t.before, wornNow(ped)) and BARE or t.before
        dress(ped, back)
        t.keep, t.wearing = back, nil
        worn(t, nil)
        hud(t)
    elseif t.owned[t.tee] then
        if not putOn(ped, t, t.tee) then return end         -- (on again: it may just have been taken off)
        t.keep, t.wearing = wornNow(ped), t.tee
        worn(t, t.tee)
        hud(t)
    elseif not t.busy then
        t.busy = GetGameTimer()
        TriggerServerEvent('mzb_arena:shop:buy', t.style, t.tee)
    end
end

-- one frame of it: nothing but its own keys
local function frame(t)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or styleNow() ~= t.style or SC.enabled == false then return leave() end
    DisableAllControlActions(0)
    HideHudAndRadarThisFrame()
    if t.busy and GetGameTimer() - t.busy > 5000 then t.busy = nil end      -- (an answer that never came)
    local count = #t.stand.tees
    if IsDisabledControlJustPressed(0, 174) then
        show(t, (t.tee - 2) % count + 1)
    elseif IsDisabledControlJustPressed(0, 175) then
        show(t, t.tee % count + 1)
    elseif IsDisabledControlJustPressed(0, 191) then
        act(t)
    elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200)
           or IsDisabledControlJustPressed(0, 322) then
        leave()
    end
end

-- hung = which of the stand's hanging tees was picked
local function tryOn(style, hung)
    local stand = standOf(style)
    local h = stand and stand.hung[hung]
    if T or not h or style ~= styleNow() or SC.enabled == false then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then return end
    local gender = MODELS[GetEntityModel(ped)]
    if not gender then return notify('the arena\'s shirts fit the freemode characters only') end
    local before = wornNow(ped)
    local t = { style = style, stand = stand, gender = gender, tee = h.tee, before = before, keep = before,
                owned = {}, price = priceOf(style) }
    if not putOn(ped, t, h.tee) then return notify('the arena\'s shirts are not installed on this server') end
    if same(before, wornNow(ped)) then t.cameIn = h.tee end     -- (already in this one: "Wearing" once the server says it is owned)
    T = t
    ArenaMenu.close()
    -- the ped: its back to the wall, held; the camera: in front of it at chest height and a little over, on the chest
    ClearPedTasksImmediately(ped)
    SetEntityHeading(ped, h.heading)
    FreezeEntityPosition(ped, true)
    local cc = SC.camera or {}
    local p = GetEntityCoords(ped)
    local a = math.rad(h.heading)
    local d = tonumber(cc.distance) or 2.3
    t.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(t.cam, p.x - math.sin(a) * d, p.y + math.cos(a) * d, p.z + CHEST + (tonumber(cc.height) or 0.35))
    PointCamAtCoord(t.cam, p.x, p.y, p.z + CHEST)
    SetCamFov(t.cam, tonumber(cc.fov) or 38.0)
    RenderScriptCams(true, true, 400, true, false)
    hud(t)
    TriggerServerEvent('mzb_arena:shop:open', style)
    CreateThread(function()
        while T == t do
            frame(t)
            Wait(0)
        end
    end)
end

-- what the player owns at this stand, their cash, the price (the server's, on the way in)
RegisterNetEvent('mzb_arena:shop:state', function(d)
    local t = T
    if not t or type(d) ~= 'table' or d.style ~= t.style then return end
    t.owned = {}
    for _, n in ipairs(type(d.owned) == 'table' and d.owned or {}) do t.owned[n] = true end
    t.cash, t.price = tonumber(d.cash), tonumber(d.price) or t.price
    if t.cameIn and t.owned[t.cameIn] and not t.wearing then t.wearing = t.cameIn end
    hud(t)
end)

-- the server's word on a purchase
RegisterNetEvent('mzb_arena:shop:bought', function(d)
    local t = T
    if not t or type(d) ~= 'table' or d.style ~= t.style then return end
    t.busy = nil
    if not d.ok then
        SendNUIMessage({ shop = { toast = tostring(d.why or 'the payment did not go through'), failed = true } })
        return
    end
    t.owned[d.tee] = true
    t.cash = tonumber(d.cash)
    if t.tee == d.tee then                                 -- still looking at it: it stays on
        t.keep, t.wearing = wornNow(PlayerPedId()), d.tee
        worn(t, d.tee)
    end
    SendNUIMessage({ shop = { toast = 'Purchased' } })
    PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
    hud(t)
end)

-- ------------------------------------------------------------------ the target scripts' zones
local function removeZones()
    local script = zonesFor and zonesFor:match('^(.-):')
    if script and started(script) then
        for _, z in ipairs(zones) do
            if script == 'ox_target' then
                exports.ox_target:removeZone(z)
            else
                exports['qb-target']:RemoveZone(z)
            end
        end
    end
    zones, zonesFor = {}, nil
end

local function addZones(script, style, stand)
    local reach = tonumber(SC.reach) or 1.7
    for i, h in ipairs(stand.hung) do
        local label = 'Try on: ' .. tostring((stand.tees[h.tee] or {}).label)
        local name = ('mzb_arena_tee_%d'):format(i)
        if script == 'ox_target' then
            zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = h.coords, radius = 0.28, options = {
                { name = name, icon = 'fa-solid fa-shirt', label = label, distance = reach,
                  onSelect = function() tryOn(style, i) end } } })
        else
            exports['qb-target']:AddCircleZone(name, h.coords, 0.28, { name = name, useZ = true, debugPoly = false },
                { options = { { icon = 'fas fa-shirt', label = label, action = function() tryOn(style, i) end } },
                  distance = reach })
            zones[#zones + 1] = name
        end
    end
    zonesFor = script .. ':' .. style
end

-- the middle of a stand's hanging tees
local centres = {}
local function centre(style, stand)
    if not centres[style] then
        local x, y, z = 0.0, 0.0, 0.0
        for _, h in ipairs(stand.hung) do x, y, z = x + h.coords.x, y + h.coords.y, z + h.coords.z end
        centres[style] = vector3(x / #stand.hung, y / #stand.hung, z / #stand.hung)
    end
    return centres[style]
end

-- up while the show's stand has tees and the player is at it; down when the show changes or the player goes
local atStand = false
CreateThread(function()
    while true do
        local style = styleNow()
        local stand = SC.enabled ~= false and standOf(style)
        atStand = stand and #(GetEntityCoords(PlayerPedId()) - centre(style, stand)) < NEAR or false
        local script = atStand and ((started('ox_target') and 'ox_target') or (started('qb-target') and 'qb-target'))
        local want = script and (script .. ':' .. style) or nil
        if want ~= zonesFor then
            removeZones()
            if want then addZones(script, style, stand) end
        end
        Wait(500)
    end
end)

-- ------------------------------------------------------------------ the dot on the nearest tee, the prompt
local function text(x, y, str)
    SetTextFont(4)
    SetTextScale(0.34, 0.34)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandDisplayText(x, y)
end

local function help(str)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

-- the tee the camera looks at, of the ones within reach (without a target script that is how one is picked)
local function lookedAt(stand, pos, reach)
    local cam, rot = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local fx, fy, fz = -math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx)
    local best, bestDot = nil, 0.9                         -- (within some 25 degrees of the middle of the screen)
    for i, h in ipairs(stand.hung) do
        if #(pos - h.coords) <= reach then
            local v = h.coords - cam
            local len = #v
            local dot = len > 0.01 and (v.x * fx + v.y * fy + v.z * fz) / len or 0.0
            if dot > bestDot then best, bestDot = i, dot end
        end
    end
    return best
end

CreateThread(function()
    while true do
        local wait = 300
        local stand = atStand and not T and standOf(styleNow())
        if stand then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local near, nearD
            for i, h in ipairs(stand.hung) do
                local d = #(pos - h.coords)
                if d < MARK and (not nearD or d < nearD) then near, nearD = i, d end
            end
            if near then
                wait = 0
                local picked = nil
                if not zonesFor and not IsPedInAnyVehicle(ped, false) and not ArenaMenu.isOpen() and not ArenaPed.prompted() then
                    picked = lookedAt(stand, pos, tonumber(SC.reach) or 1.7)
                end
                -- the dot: on the tee looked at, else the nearest; a hand's width off the cloth, towards the room
                local h = stand.hung[picked or near]
                local a = math.rad(h.heading)
                local x, y, z = h.coords.x - math.sin(a) * 0.06, h.coords.y + math.cos(a) * 0.06, h.coords.z
                DrawMarker(28, x, y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.03, 0.03, 0.03, 255, 255, 255, 230,
                    false, false, 2, false, nil, nil, false)
                local on, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
                if on and sx > 0.0 and sx < 0.95 and sy > 0.02 and sy < 1.0 then text(sx + 0.008, sy - 0.013, 'TEES') end
                if picked then
                    help('Press ~INPUT_CONTEXT~ to try on ' .. tostring((stand.tees[h.tee] or {}).label))
                    if IsControlJustReleased(0, 51) then tryOn(styleNow(), picked) end
                end
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    leave(true)
    removeZones()
end)
