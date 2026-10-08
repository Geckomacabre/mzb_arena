-- mzb_arena - client: fights (GlobalState.mzbFight / mzbFightCard, server/fights.lua).
--   * the NPC fighters this client owns (the game hands every networked ped to one client): their health at the
--     walk-out, their manners, their part of the bout - warm up in the corner, fight the other one, back to the corner
--     between rounds, celebrate or go down. Whichever client owns them next picks it up from the state;
--   * the player as a fighter: healed at the walk-out, fists only, kept alive through the rounds (a bout is lost at
--     Config.Fights.koHealth, never the life), helped up afterwards;
--   * for everyone in the arena: the fight bar at the top of the screen (html/fights.js), the bell, the knockout.
-- The server decides everything that counts (who is down, who is out of the ring, who won); nothing here is trusted.

local FC = Config.Fights or {}
if FC.enabled == false then return end

local F = GlobalState.mzbFight or { state = 'idle' }
local CARD = GlobalState.mzbFightCard or {}
local gotAt, cardAt = GetGameTimer(), GetGameTimer()   -- when F / CARD arrived (their times count from then)
local AF = Config.ArenaFrame
local CA, SA = math.cos(AF.ang), math.sin(AF.ang)
local UNARMED = GetHashKey('WEAPON_UNARMED')
local KO = FC.koHealth or 125
local applied, retaskAt = {}, {}   -- [ped] = the part of the bout last given to it here / when to check its fight
local here = false                 -- inside the arena: the bar shows, the bell is heard

local function world(u, v)
    return AF.x + u * CA - v * SA, AF.y + u * SA + v * CA
end

local function other(c)
    return c == 'red' and 'blue' or 'red'
end

local function venue()
    return (FC.venues or {})[F.show or ''] or nil
end

local function fighterPed(f)
    if not f then return 0 end
    if f.kind == 'player' then
        local p = GetPlayerFromServerId(f.src or -1)
        return p ~= -1 and GetPlayerPed(p) or 0
    end
    if f.net and NetworkDoesNetworkIdExist(f.net) then
        local e = NetworkGetEntityFromNetworkId(f.net)
        if e ~= 0 and DoesEntityExist(e) then return e end
    end
    return 0
end

local function myCorner()
    local me = GetPlayerServerId(PlayerId())
    for _, c in ipairs({ 'red', 'blue' }) do
        local f = F[c]
        if f and f.kind == 'player' and f.src == me then return c end
    end
    return nil
end

local function ownedNpc(c)
    local f = F[c]
    if not f or f.kind ~= 'npc' then return 0 end
    local ped = fighterPed(f)
    if ped ~= 0 and NetworkGetEntityOwner(ped) == PlayerId() then return ped end
    return 0
end

local function playAnim(ped, a)
    if not a or not DoesAnimDictExist(a[1]) then return false end
    RequestAnimDict(a[1])
    local untilT = GetGameTimer() + 3000
    while not HasAnimDictLoaded(a[1]) do
        if GetGameTimer() > untilT then return false end
        Wait(0)
    end
    TaskPlayAnim(ped, a[1], a[2], 4.0, 4.0, -1, a[3] or 1, 0.0, false, false, false)
    return true
end

local function sound(s)
    if s then PlaySoundFrontend(-1, s[1], s[2], true) end
end

-- ------------------------------------------------------------------ the NPC fighters this client owns
-- In a round they are steered by hand: the game's combat task paths over the navmesh, and there is none in the
-- building (they stood in their corners). Straight at the other one until within reach, then straight into melee;
-- again whenever they drift apart, fall, or the melee lets go.
local REACH = FC.reach or 1.6

local function fightStep(ped, target)
    if target == 0 or not DoesEntityExist(target) or IsEntityDead(ped) then return end
    if IsPedRagdoll(ped) or IsPedGettingUp(ped) then return end
    local p, q = GetEntityCoords(ped), GetEntityCoords(target)
    local dx, dy = q.x - p.x, q.y - p.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d > REACH then
        local k = (d - 0.9) / d
        TaskGoStraightToCoord(ped, p.x + dx * k, p.y + dy * k, q.z, d > 4.0 and 2.0 or 1.4, 4000,
            GetHeadingFromVector_2d(dx, dy), 0.2)
    elseif not IsPedInMeleeCombat(ped) then
        ClearPedTasks(ped)
        TaskPutPedDirectlyIntoMelee(ped, target, 0.0, -1.0, 0.0, 0)
    end
end

local function drive(ped, c)
    local v = venue()
    local anims = FC.anims or {}
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)             -- always fights
    SetPedCombatAttributes(ped, 5, true)              -- with fists, whatever the other has
    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedSuffersCriticalHits(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedKeepTask(ped, true)
    if v then                                          -- held inside the ring / the cage
        SetPedSphereDefensiveArea(ped, AF.x, AF.y, v.z, v.shape == 'circle' and (v.radius or 4.0) or (v.half or 2.8),
            false, false)
    end
    if F.state == 'intro' then
        -- the walk-out: full health (only now - a client that takes them over mid-bout keeps what they have left)
        SetEntityMaxHealth(ped, 200)
        SetEntityHealth(ped, 200)
        RemoveAllPedWeapons(ped, true)
        ClearPedTasks(ped)
        playAnim(ped, anims.warmup)
    elseif F.state == 'round' then
        ClearPedTasks(ped)
        fightStep(ped, fighterPed(F[other(c)]))
        retaskAt[ped] = GetGameTimer() + 400
    elseif F.state == 'break' then
        local p = v and v[c] or { 0.0, 0.0 }
        local x, y = world(p[1], p[2])
        ClearPedTasks(ped)
        TaskGoStraightToCoord(ped, x, y, v and v.z or AF.z, 1.0, 12000,
            math.deg(math.atan(-(AF.x - x), AF.y - y)) % 360.0, 0.5)
    elseif F.state == 'over' then
        ClearPedTasks(ped)
        if F.winner == c then
            playAnim(ped, anims.win)
        elseif F.winner and F.winner ~= 'draw' then
            SetPedToRagdoll(ped, 3500, 3500, 0, false, false, false)
            local id = F.id
            CreateThread(function()
                Wait(3600)
                if F.id == id and DoesEntityExist(ped) and NetworkGetEntityOwner(ped) == PlayerId() then
                    playAnim(ped, anims.down)
                end
            end)
        end
    end
end

CreateThread(function()
    while true do
        if F.state ~= 'idle' and F.id then
            local key = F.id .. ':' .. F.state .. ':' .. (F.round or 0)
            for _, c in ipairs({ 'red', 'blue' }) do
                local ped = ownedNpc(c)
                if ped ~= 0 then
                    if applied[ped] ~= key then
                        applied[ped] = key
                        drive(ped, c)
                    elseif F.state == 'round' and GetGameTimer() > (retaskAt[ped] or 0) then
                        -- still at it? closer if they drifted apart, back into melee if it let go
                        retaskAt[ped] = GetGameTimer() + 400
                        fightStep(ped, fighterPed(F[other(c)]))
                    end
                end
            end
        elseif next(applied) then
            applied, retaskAt = {}, {}
        end
        Wait(100)
    end
end)

-- ------------------------------------------------------------------ the player as a fighter; nobody dies
local lastKey = nil

local function onState()
    local key = (F.id or 0) .. ':' .. (F.state or 'idle') .. ':' .. (F.round or 0)
    if key == lastKey then return end
    lastKey = key
    local sounds = FC.sounds or {}
    if here then
        if F.state == 'round' then sound(sounds.bell) end
        if F.state == 'over' then sound(F.how == 'KO' and sounds.ko or sounds.bell) end
    end
    local mine = myCorner()
    if not mine then return end
    local ped = PlayerPedId()
    if F.state == 'intro' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        SetCurrentPedWeapon(ped, UNARMED, true)
    elseif F.state == 'over' then
        if F.how == 'KO' and F.winner ~= mine and F.winner ~= 'draw' then
            SetPedToRagdoll(ped, 4000, 4000, 0, false, false, false)
        end
        CreateThread(function()                            -- helped up: full health again
            Wait(5000)
            local p = PlayerPedId()
            if not IsEntityDead(p) then SetEntityHealth(p, GetEntityMaxHealth(p)) end
        end)
    end
end

-- every frame while this client has a fighter: fists only for the player; the health floor in the rounds (the server
-- sees them fall to koHealth and calls the knockout before anyone could die)
CreateThread(function()
    while true do
        local mine = F.state ~= 'idle' and F.state ~= 'over' and myCorner()
        local npcR = F.state == 'round' and ownedNpc('red') or 0
        local npcB = F.state == 'round' and ownedNpc('blue') or 0
        if mine or npcR ~= 0 or npcB ~= 0 then
            local floor = KO - 8
            if mine then
                local ped = PlayerPedId()
                if GetSelectedPedWeapon(ped) ~= UNARMED then SetCurrentPedWeapon(ped, UNARMED, true) end
                DisableControlAction(0, 37, true)              -- the weapon wheel
                if F.state == 'round' and not IsEntityDead(ped) and GetEntityHealth(ped) < floor then
                    SetEntityHealth(ped, floor)
                end
            end
            for _, p in ipairs({ npcR, npcB }) do
                if p ~= 0 and GetEntityHealth(p) < floor then SetEntityHealth(p, floor) end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- ------------------------------------------------------------------ the fight bar (html/fights.js)
local function side(f, me)
    if not f then return nil end
    local ped, hp = fighterPed(f), nil
    if ped ~= 0 then hp = math.max(0.0, math.min(1.0, (GetEntityHealth(ped) - KO) / (200 - KO))) end
    return { name = f.name, hp = hp, you = f.kind == 'player' and f.src == me }
end

CreateThread(function()
    local shown = false
    while true do
        local ped = PlayerPedId()
        local id = MzbInterior()
        here = id ~= 0 and GetInteriorFromEntity(ped) == id
        local on = FC.hud ~= false and here and (F.state ~= 'idle' or CARD[1] ~= nil)
        if on then
            local now, me = GetGameTimer(), GetPlayerServerId(PlayerId())
            local nxt = CARD[1] and { red = CARD[1].red, blue = CARD[1].blue,
                                      inS = CARD[1].inS and math.max(0, CARD[1].inS - (now - cardAt) // 1000) or nil }
            SendNUIMessage({ type = 'fight', state = F.state, red = side(F.red, me), blue = side(F.blue, me),
                             round = F.round, rounds = F.rounds, winner = F.winner, how = F.how, next = nxt,
                             left = F.left and math.max(0, F.left - (now - gotAt)) or 0 })
            shown = true
        elseif shown then
            SendNUIMessage({ type = 'fight', hide = true })
            shown = false
        end
        Wait(on and 250 or 1000)
    end
end)

-- ------------------------------------------------------------------ the state, the desk
local function deskUpdate()
    SendNUIMessage({ type = 'fightDesk', fight = F, card = CARD })
end

AddStateBagChangeHandler('mzbFight', 'global', function(_, _, value)
    F, gotAt = value or { state = 'idle' }, GetGameTimer()
    deskUpdate()
    onState()
end)

AddStateBagChangeHandler('mzbFightCard', 'global', function(_, _, value)
    CARD, cardAt = value or {}, GetGameTimer()
    deskUpdate()
end)

AddEventHandler('mzb_arena:lightsDesk', deskUpdate)          -- the desk opens (client/lights.lua)

RegisterNUICallback('fight', function(data, cb)
    cb('ok')
    if type(data) == 'table' then TriggerServerEvent('mzb_arena:fight', data) end
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (FC.command or 'arenafight'), 'Maze Bank Arena: fights in the ring / cage',
        { { name = 'what', help = 'status | challenge [id] | accept   (staff: npc | vs <id> | pvp <id> <id> [in <min>] | stop | clear)' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SendNUIMessage({ type = 'fight', hide = true })
    TriggerEvent('chat:removeSuggestion', '/' .. (FC.command or 'arenafight'))
end)
