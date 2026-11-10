-- mzb_arena - client: paintball (GlobalState.mzbPaintball; the match is the server's, server/paintball.lua).
-- What this player's game does in it: put them where the server says (their start box, held for the countdown; their
-- dead box once they are out), hand them the marker and turn every shot of theirs down to a scratch (Config.Paintball
-- .damage; ox_inventory's weapons put away by its own switch while they play), keep the marker in their hands, tell
-- the server who hit them when a ball does (the game's damage event, seen on the one who is hit), leave paint where
-- their balls land (the game's paint splatter in their team's colour; the server passes it on to the others), and
-- draw the score. Everything goes back as it was when the match ends, they leave it, or the resource stops.

local PB = Config.Paintball or {}
if PB.enabled == false then return end

local S = GlobalState.mzbPaintball
local me = nil                        -- this player's entry in the match: { team, name, out }
local armed = false                   -- the marker handed out, the damage turned down
local was = nil                       -- the marker's damage modifier before
local health0, armour0 = nil, nil     -- this player's health and armour when they were handed the marker
local lastImpact = nil                -- the game's last weapon impact for this player that has been used (or was old)
local splats = {}
local HASH = GetHashKey(PB.weapon or 'WEAPON_CERAMICPISTOL')
if not IsWeaponValid(HASH) then HASH = GetHashKey(PB.fallback or 'WEAPON_PISTOL') end   -- a game build without it
local PAINT = 1030                    -- the game's decal type: splatters_paint
local myId = nil

local function say(msg) TriggerEvent('chat:addMessage', { args = { 'paintball', msg } }) end
local function teamOf(t) return (PB.teams or {})[t] or {} end

local function mine()
    if not S or not S.players then return nil end
    myId = myId or GetPlayerServerId(PlayerId())
    return S.players[tostring(myId)] or S.players[myId]
end

AddStateBagChangeHandler('mzbPaintball', 'global', function(_, _, value)
    S = value
    me = mine()
end)

-- ox_inventory, when it runs: its own weapons put away and its weapon check stood down while this player plays
local function inventory(on)
    if GetResourceState('ox_inventory') ~= 'started' then return end
    if on then TriggerEvent('ox_inventory:disarm', true) end
    pcall(function() exports.ox_inventory:weaponWheel(on) end)
end

-- what the game says this player's last weapon impact was (nil: none)
local function impactNow(ped)
    local ok, c = GetPedLastWeaponImpactCoord(ped)
    if ok and c then return c end
    return nil
end

-- a ball does not hurt: health and armour back, no blood, and the game's record of the weapon that did it wiped, so a
-- medical script that asks the game what hit the player (qbx_medical, qb-ambulancejob) finds nothing to wound them with
local function unhurt(ped)
    local max = GetEntityMaxHealth(ped)
    if GetEntityHealth(ped) < max then SetEntityHealth(ped, max) end
    if armour0 and GetPedArmour(ped) < armour0 then SetPedArmour(ped, armour0) end
    ClearPedBloodDamage(ped)
    ClearEntityLastWeaponDamage(ped)
end

local function arm(team)
    local ped = PlayerPedId()
    if not armed then
        inventory(true)
        was = GetWeaponDamageModifier(HASH)
        health0, armour0 = GetEntityHealth(ped), GetPedArmour(ped)
        lastImpact = impactNow(ped)                      -- a shot from before the match is not one of this match's
    end
    armed = true
    GiveWeaponToPed(ped, HASH, PB.ammo or 250, false, true)
    SetPedAmmo(ped, HASH, PB.ammo or 250)
    -- a suppressor where the marker takes one: a marker's pop, not a gunshot (dispatch scripts such as ps-dispatch
    -- leave a silenced weapon alone, and fewer people hear it)
    for _, c in ipairs(PB.components or {}) do
        local ch = GetHashKey(c)
        if DoesWeaponTakeWeaponComponent(HASH, ch) then GiveWeaponComponentToPed(ped, HASH, ch) end
    end
    SetCurrentPedWeapon(ped, HASH, true)
    local tint = (PB.tints or {})[team]
    if tint then SetPedWeaponTintIndex(ped, HASH, tint) end
    -- the marker's own modifier only: the shooter's game works out the damage, and the player's modifier (which the
    -- game keeps at 0.1 or more) would multiply it down to nothing the game reports. Set again every frame (below)
    SetWeaponDamageModifier(HASH, PB.damage or 0.1)
    SetPedSuffersCriticalHits(ped, false)                -- (a head shot would still have been a kill)
    -- for other resources on this server: this player is playing paintball (their gunfire is a game's)
    if LocalPlayer then LocalPlayer.state:set('mzbPaintball', team, true) end
end

local function disarm()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    if not armed then return end
    armed = false
    RemoveWeaponFromPed(ped, HASH)
    SetWeaponDamageModifier(HASH, was or 1.0)
    SetPedSuffersCriticalHits(ped, true)
    SetPedCanSwitchWeapon(ped, true)
    -- the health they came with (the match kept them whole; it is no free cure)
    ClearEntityLastWeaponDamage(ped)
    if health0 and not IsEntityDead(ped) and GetEntityHealth(ped) > health0 then SetEntityHealth(ped, health0) end
    health0, armour0 = nil, nil
    if LocalPlayer then LocalPlayer.state:set('mzbPaintball', false, true) end
    inventory(false)
end

-- ------------------------------------------------------------------ the server's word
RegisterNetEvent('mzb_arena:pbPlace', function(s, hold)
    if type(s) ~= 'table' then return end
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, s.x + 0.0, s.y + 0.0, s.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, s.h + 0.0)
    FreezeEntityPosition(ped, hold == true)              -- held in the start box for the countdown
end)

RegisterNetEvent('mzb_arena:pbArm', function(team)
    if team ~= 'red' and team ~= 'blue' then return end
    arm(team)
    PlaySoundFrontend(-1, '3_2_1', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('mzb_arena:pbGo', function()
    FreezeEntityPosition(PlayerPedId(), false)
    PlaySoundFrontend(-1, 'GO', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('mzb_arena:pbOut', function(victim, by, vname, bname, team, left)
    myId = myId or GetPlayerServerId(PlayerId())
    if victim == myId then
        PlaySoundFrontend(-1, 'LOSER', 'HUD_AWARDS', true)
        say(('you are OUT - %s got you: in your dead box until the round is over'):format(tostring(bname)))
    else
        if by == myId then PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true) end
        say(('%s got %s - %d left on %s'):format(tostring(bname), tostring(vname), tonumber(left) or 0,
            teamOf(team).label or tostring(team)))
    end
end)

RegisterNetEvent('mzb_arena:pbEnd', function()
    disarm()
end)

-- ------------------------------------------------------------------ the paint
local function splat(pos, n, team)
    local c = teamOf(team).colour or { 255, 255, 255 }
    local side = vector3(n.y, -n.x, 0.0)
    if #side < 0.1 then side = vector3(1.0, 0.0, 0.0) end
    local s = 0.22 + math.random() * 0.22
    local d = AddDecal(PAINT, pos.x, pos.y, pos.z, -n.x, -n.y, -n.z, side.x, side.y, side.z, s, s, c[1] / 255.0,
        c[2] / 255.0, c[3] / 255.0, 1.0, 300.0, false, false, false)
    if d and d ~= 0 then
        splats[#splats + 1] = d
        if #splats > 150 then RemoveDecal(table.remove(splats, 1)) end
    end
end

RegisterNetEvent('mzb_arena:pbSplat', function(x, y, z, nx, ny, nz, team)
    for _, v in ipairs({ x, y, z, nx, ny, nz }) do
        if type(v) ~= 'number' or v ~= v then return end
    end
    splat(vector3(x, y, z), vector3(nx, ny, nz), team)
end)

-- the impact of the shot just fired: the game's last one for this player, unless it is the one already used (a shot's
-- own impact may come a frame after the shot)
local function newImpact(ped)
    local c = impactNow(ped)
    if not c or (lastImpact and #(c - lastImpact) < 0.005) then return nil end
    lastImpact = c
    return c
end

-- where this player's ball landed (c), and the face it landed on (a ray from the camera to the impact)
local function landed(ped, c)
    local from = GetFinalRenderedCamCoord()
    local d = c - from
    local len = #d
    if len < 0.3 or len > 120.0 then return nil end
    local to = c + d / len * 0.3
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, ped, 7)
    local _, hit, pos, n = GetShapeTestResult(ray)
    if hit == 1 or hit == true then return pos, n end
    return nil
end

-- ------------------------------------------------------------------ hits
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or not armed or type(args) ~= 'table' then return end
    local ped = PlayerPedId()
    if args[1] ~= ped then return end
    unhurt(ped)
    if not me or me.out or not S or S.state ~= 'live' then return end
    local attacker = args[2]
    if not attacker or attacker == 0 or not IsPedAPlayer(attacker) then return end
    local p = NetworkGetPlayerIndexFromPed(attacker)
    if not p or p == -1 then return end
    TriggerServerEvent('mzb_arena:pbHit', GetPlayerServerId(p), args[7])
end)

-- ------------------------------------------------------------------ while playing
local function text(s, x, y, scale, c)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(c[1], c[2], c[3], 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(s)
    EndTextCommandDisplayText(x, y)
end

local function standing(team)
    local n = 0
    for _, p in pairs(S.players or {}) do if p.team == team and not p.out then n = n + 1 end end
    return n
end

CreateThread(function()
    local lastSplat, shownAt, shownLeft = 0, 0, 0
    local shotAt = nil                                    -- a shot whose impact is still to come
    while true do
        local live = S and S.state ~= nil and S.state ~= 'idle'
        local watching = live and (me ~= nil or MzbListener.zone == 'bowl')
        if armed or watching then
            local ped = PlayerPedId()
            if armed then
                if GetSelectedPedWeapon(ped) ~= HASH then SetCurrentPedWeapon(ped, HASH, true) end
                SetPedCanSwitchWeapon(ped, false)
                SetWeaponDamageModifier(HASH, PB.damage or 0.1)
                local now = GetGameTimer()
                if not me or me.out or S.state ~= 'live' then
                    DisablePlayerFiring(PlayerId(), true)
                    shotAt, lastImpact = nil, impactNow(ped) or lastImpact
                else
                    if IsPedShooting(ped) then shotAt = now end
                    if shotAt then
                        local c = newImpact(ped)
                        if c then
                            shotAt = nil
                            local pos, n = landed(ped, c)
                            if pos and now - lastSplat > 90 then
                                lastSplat = now
                                splat(pos, n, me.team)
                                TriggerServerEvent('mzb_arena:pbSplat', pos.x, pos.y, pos.z, n.x, n.y, n.z)
                            end
                        elseif now - shotAt > 300 then
                            shotAt = nil                  -- into the air: nothing to paint
                        end
                    end
                end
                if GetEntityHealth(ped) < GetEntityMaxHealth(ped) or (armour0 and GetPedArmour(ped) < armour0) then
                    unhurt(ped)
                end
            end
            if watching then
                if S.left ~= shownLeft then shownLeft, shownAt = S.left, GetGameTimer() end
                local secs = math.max(0, math.floor(((S.left or 0) - (GetGameTimer() - shownAt)) / 1000))
                local r, b = teamOf('red'), teamOf('blue')
                local sc = S.score or { red = 0, blue = 0 }
                local line = ('%s %d  :  %d %s'):format(r.label or 'RED', sc.red or 0, sc.blue or 0, b.label or 'BLUE')
                text(line, 0.5, 0.03, 0.62, { 255, 255, 255 })
                local what = S.state == 'signup' and ('sign-up: %d s - %d v %d'):format(secs, standing('red'), standing('blue'))
                    or S.state == 'countdown' and ('round %d starts in %d'):format(S.round or 1, secs + 1)
                    or S.state == 'live' and ('round %d | %d:%02d | %d v %d standing'):format(S.round or 1, secs // 60,
                        secs % 60, standing('red'), standing('blue'))
                    or S.state == 'between' and ('round %d is over'):format(S.round or 1)
                    or S.state == 'over' and (S.last or 'the match is over') or ''
                text(what, 0.5, 0.075, 0.42, { 230, 230, 230 })
                if me then
                    local c = teamOf(me.team).colour or { 255, 255, 255 }
                    text(me.out and 'OUT' or ('you: ' .. (teamOf(me.team).label or me.team)), 0.5, 0.105, 0.42,
                        me.out and { 255, 80, 80 } or c)
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ------------------------------------------------------------------ the referees' table, the command
CreateThread(function()
    Wait(1600)
    local d = PB.desk
    if d and MzbTarget and MzbArenaToWorld then
        MzbTarget.add('paintball', { coords = MzbArenaToWorld(d.u, d.v, d.z), size = vector3(2.0, 1.6, 1.6),
            label = d.label or 'Join paintball', icon = d.icon or 'paintbrush', distance = d.distance or 2.0,
            enabled = function() return (GlobalState.mzbShow or Config.DefaultShow) == (PB.show or 'paintball') end,
            onUse = function() TriggerServerEvent('mzb_arena:pbJoin') end })
    end
    TriggerEvent('chat:addSuggestion', '/' .. (PB.command or 'arenapaintball'), 'Maze Bank Arena: paintball',
        { { name = 'what', help = 'status | join [red|blue] | leave | start [map] [wins] | stop (staff)' } })
end)

RegisterCommand(PB.command or 'arenapaintball', function(_, args)
    TriggerServerEvent('mzb_arena:pbCmd', { args[1], args[2], args[3] })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    disarm()
    for _, d in ipairs(splats) do RemoveDecal(d) end
end)
