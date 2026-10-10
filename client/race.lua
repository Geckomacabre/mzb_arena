-- mzb_arena - client: the race (GlobalState.mzbRace, server/race.lua; the tracks: Config.Races, shared/races.lua).
-- The server runs it; this is one racer's side of it:
--   * to the grid (mzb_arena:raceGrid): the track's vehicle - the first of its models this game build has, else a
--     fallback - made on the racer's grid slot with the racer in it, held there until the countdown is over;
--   * round the track: the next checkpoint as a marker and a blip (the line is a chequered one), passed when the
--     racer is within its radius and at its height (the Grand Prix's bridge crosses a lane 2.6 m under it) - the
--     server is told, and counts it only if it is the next one; position, lap and time at the bottom of the screen;
--   * off the track: finished, DNF, retired (out of the vehicle for 15 s, or dead), or the race called off - the
--     vehicle is taken away and the racer stands at the event desk again (Config.Race.returnTo).
-- Nothing here decides a result: the server does (the places, the times, who is out).

local RC = Config.Race or {}
if RC.enabled == false then return end

local TRACKS = type(Config.Races) == 'table' and Config.Races or {}
local OUT_SECONDS = 15           -- out of the vehicle this long: retired
local Z_REACH = 2.0              -- m over / under a checkpoint that still counts

local S, gotAt = GlobalState.mzbRace or { state = 'idle' }, GetGameTimer()
local R = nil                    -- this racer's race: { id, track, slot, countdown, goAt (this game's ms), state =
                                 --   'grid' | 'racing' | 'over', veh, done, total, order (the standings), outSince,
                                 --   marker, blip, note (the big line), result }

AddStateBagChangeHandler('mzbRace', 'global', function(_, _, value)
    S, gotAt = value or { state = 'idle' }, GetGameTimer()
end)

-- (client/desk.lua) the race as the server has it: `left` counted down from when it came, `me` = this player's id
function MzbRaceState()
    local s = {}
    for k, v in pairs(S) do s[k] = v end
    s.left = math.max(0, (tonumber(S.left) or 0) - (GetGameTimer() - gotAt))
    s.me = GetPlayerServerId(PlayerId())
    return s
end

local function clock(ms)
    return ('%d:%04.1f'):format(ms // 60000, (ms % 60000) / 1000.0)
end

local function sound(name)
    PlaySoundFrontend(-1, name, 'HUD_MINI_GAME_SOUNDSET', true)
end

-- ------------------------------------------------------------------ the vehicle
local function pickModel(track)
    for _, names in ipairs({ track.vehicles or {}, track.fallback or {} }) do
        for _, name in ipairs(names) do
            local h = GetHashKey(name)
            if IsModelInCdimage(h) and IsModelAVehicle(h) then return h end
        end
    end
    return nil
end

local function makeVehicle(track, slot)
    local model = pickModel(track)
    local g = track.grid[slot]
    if not model or not g then return nil end
    RequestModel(model)
    local untilT = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > untilT then return nil end
        Wait(0)
    end
    local veh = CreateVehicle(model, g.x, g.y, g.z, g.w, true, false)
    SetModelAsNoLongerNeeded(model)
    if not veh or veh == 0 then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetEntityHeading(veh, g.w)
    SetVehicleOnGroundProperly(veh)
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    FreezeEntityPosition(veh, true)                        -- held on the grid until the countdown is over
    -- a full tank for whichever fuel script the server runs (the game's own level, the decorator the older ones
    -- read, the state bag the newer ones read), and the keys for qb-vehiclekeys; any other script can take it from
    -- the event below
    SetVehicleFuelLevel(veh, 100.0)
    if DecorIsRegisteredAsType('_FUEL_LEVEL', 1) then DecorSetFloat(veh, '_FUEL_LEVEL', 100.0) end
    Entity(veh).state:set('fuel', 100.0, true)
    local plate = GetVehicleNumberPlateText(veh)
    if GetResourceState('qb-vehiclekeys') == 'started' then TriggerEvent('vehiclekeys:client:SetOwner', plate) end
    TriggerEvent('mzb_arena:raceVehicle', veh, plate)
    return veh
end

-- ------------------------------------------------------------------ the checkpoints
local function clearMarker(my)
    if my.marker then DeleteCheckpoint(my.marker) end
    if my.blip and DoesBlipExist(my.blip) then RemoveBlip(my.blip) end
    my.marker, my.blip = nil, nil
end

-- the checkpoint after the n passed so far, and whether it is the line
local function nextCp(my)
    local cps = my.track.checkpoints
    local i = my.done % #cps + 1
    return cps[i], i == #cps, cps[i % #cps + 1]
end

local function setMarker(my)
    clearMarker(my)
    if my.done >= my.total then return end
    local cp, line, after = nextCp(my)
    local r = tonumber(my.track.radius) or 4.0
    -- a cylinder with an arrow to the one after it; the line: chequered, and white instead of yellow
    my.marker = CreateCheckpoint(line and 4 or 0, cp.x, cp.y, cp.z - 0.5, after.x, after.y, after.z, r * 2.0,
        line and 255 or 250, line and 255 or 200, line and 255 or 30, 110, 0)
    SetCheckpointCylinderHeight(my.marker, 2.0, 2.0, r)
    my.blip = AddBlipForCoord(cp.x, cp.y, cp.z)
    SetBlipSprite(my.blip, line and 38 or 1)
    SetBlipColour(my.blip, line and 0 or 5)
    SetBlipScale(my.blip, 0.8)
end

-- ------------------------------------------------------------------ off the track
-- where a racer is put afterwards: Config.Race.returnTo, else in front of the event desk's official
local function returnPoint()
    local to = RC.returnTo
    if to then return to.x, to.y, to.z, to.w or 0.0 end
    local d = (Config.EventDesk or {}).ped
    local c = type(d) == 'table' and d.coords
    if not c then return nil end
    local h = math.rad(c.w or 0.0)
    return c.x - math.sin(h) * 1.6, c.y + math.cos(h) * 1.6, c.z, ((c.w or 0.0) + 180.0) % 360.0
end

-- the vehicle goes, the racer stands at the desk again. quick = the resource is stopping: no fade, no waiting
local function leaveTrack(my, quick)
    if my.left then return end
    my.left = true
    if R == my then R = nil end
    clearMarker(my)
    local ped = PlayerPedId()
    local x, y, z, h = returnPoint()
    local move = x and not IsEntityDead(ped)                -- (the dead are left to the ambulance)
    if move and not quick then
        DoScreenFadeOut(250)
        Wait(300)
    end
    if my.veh and DoesEntityExist(my.veh) then
        SetEntityAsMissionEntity(my.veh, true, true)
        DeleteEntity(my.veh)
    end
    my.veh = nil
    if move then
        SetEntityCoords(ped, x, y, z, false, false, false, false)
        SetEntityHeading(ped, h)
        if not quick then DoScreenFadeIn(400) end
    end
end

-- ------------------------------------------------------------------ the screen
local function text(x, y, scale, str, r, g, b)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandDisplayText(x, y)
end

local function place(my)
    local me = GetPlayerServerId(PlayerId())
    for i, e in ipairs(my.order or {}) do
        if e.src == me then return i, #my.order end
    end
    return my.slot, math.max(my.slot, #(S.racers or {}))    -- (before the first standings: the grid's order)
end

local function hud(my, now)
    local cps = #my.track.checkpoints
    local pos, of = place(my)
    local lap = math.min(my.track.laps, my.done // cps + 1)
    local t = my.result and my.result.time or math.max(0, now - my.goAt)
    text(0.5, 0.905, 0.55, ('P %d/%d      LAP %d/%d      %s'):format(pos, of, lap, my.track.laps, clock(t)), 255, 255, 255)
    if my.note and now < my.noteUntil then
        text(0.5, 0.36, my.noteScale or 1.0, my.note, 255, 220, 60)
    end
    if my.outSince then
        text(0.5, 0.46, 0.6, ('Back on it: %d s'):format(math.max(0, OUT_SECONDS - (now - my.outSince) // 1000)), 255, 90, 90)
    end
end

local function note(my, str, seconds, scale)
    my.note, my.noteUntil, my.noteScale = str, GetGameTimer() + seconds * 1000, scale
end

-- ------------------------------------------------------------------ a race, frame by frame
local function retire(my)
    if my.state == 'over' then return end
    my.state = 'over'
    clearMarker(my)
    TriggerServerEvent('mzb_arena:raceLeave')              -- the server answers with raceDone: off the track then
end

local function frame(my, now)
    local ped = PlayerPedId()
    if my.state == 'grid' then
        local left = my.goAt - now
        if left <= 0 then
            my.state = 'racing'
            if my.veh then FreezeEntityPosition(my.veh, false) end
            note(my, 'GO', 1.5, 2.0)
            sound('GO')
        else
            local n = math.ceil(left / 1000)
            if n <= my.countdown and n ~= my.shown then
                my.shown = n
                note(my, tostring(n), 1.0, 2.0)
                sound('3_2_1')
            end
        end
    elseif my.state == 'racing' then
        local cp, line = nextCp(my)
        local p = GetEntityCoords(ped)
        local dx, dy = p.x - cp.x, p.y - cp.y
        local r = tonumber(my.track.radius) or 4.0
        if now >= (my.holdUntil or 0) and dx * dx + dy * dy <= r * r and math.abs(p.z - cp.z) <= Z_REACH then
            my.done = my.done + 1
            TriggerServerEvent('mzb_arena:raceCp', my.done)
            sound(line and 'CHECKPOINT_PERFECT' or 'CHECKPOINT_NORMAL')
            if my.done >= my.total then
                my.state = 'over'                          -- over the line for the last time: the server's word next
                clearMarker(my)
            else
                if line then note(my, ('LAP %d'):format(my.done // #my.track.checkpoints + 1), 2.0, 1.2) end
                setMarker(my)
            end
        end
        -- dead, or out of the vehicle for too long (a rider who came off has that long to get back on): retired
        if IsEntityDead(ped) or not my.veh or not DoesEntityExist(my.veh) then
            retire(my)
        elseif not IsPedInVehicle(ped, my.veh, false) then
            my.outSince = my.outSince or now
            if now - my.outSince > OUT_SECONDS * 1000 then retire(my) end
        else
            my.outSince = nil
        end
    end
    -- the server has no such race any more and this game was not told (a restart of the script's server side)
    if S.id ~= my.id or S.state == 'idle' then
        my.lostSince = my.lostSince or now
        if now - my.lostSince > 3000 then return leaveTrack(my) end
    else
        my.lostSince = nil
    end
    hud(my, now)
end

RegisterNetEvent('mzb_arena:raceGrid', function(d)
    if type(d) ~= 'table' or R then return end
    local track = TRACKS[d.show]
    local slot = tonumber(d.slot)
    if type(track) ~= 'table' or not slot or not track.grid[slot] then return end
    -- when the countdown is over, on this game's own clock: from the server's (the clock the screens and the
    -- music keep time on, client/listener.lua) while that is known, else from how long is left
    local goIn = tonumber(d.goIn) or 8000
    if MzbClockReady() and tonumber(d.goAt) then goIn = d.goAt - MzbServerNow() end
    local my = { id = d.id, track = track, slot = slot, countdown = tonumber(d.countdown) or 5, state = 'grid',
                 goAt = GetGameTimer() + math.max(0, goIn), done = 0, total = track.laps * #track.checkpoints }
    R = my
    ArenaMenu.close()
    my.veh = makeVehicle(track, slot)
    if R ~= my then                                        -- called off while the model loaded
        if my.veh and DoesEntityExist(my.veh) then DeleteEntity(my.veh) end
        return
    end
    if not my.veh then
        TriggerEvent('mzb_arena:notify', 'your vehicle could not be made: you are out of this race')
        R = nil
        return TriggerServerEvent('mzb_arena:raceLeave')
    end
    TriggerServerEvent('mzb_arena:raceVehicle', NetworkGetNetworkIdFromEntity(my.veh))
    setMarker(my)
    note(my, track.label, 3.0, 1.2)
    CreateThread(function()
        while R == my do
            frame(my, GetGameTimer())
            Wait(0)
        end
    end)
end)

RegisterNetEvent('mzb_arena:raceStandings', function(id, order)
    if R and R.id == id and type(order) == 'table' then R.order = order end
end)

-- the server did not count a checkpoint (out of step): where this racer is, as the server has it
RegisterNetEvent('mzb_arena:raceSync', function(id, done)
    local my = R
    if not my or my.id ~= id or type(done) ~= 'number' or my.state ~= 'racing' or done == my.done then return end
    my.done = math.max(0, math.min(my.total - 1, math.floor(done)))
    my.holdUntil = GetGameTimer() + 500                    -- (not counted again at once: the server has to see them there)
    setMarker(my)
end)

-- this racer's race is over: { place, time, of } | { out = 'dnf' | 'retired' } | { cancelled = why }
RegisterNetEvent('mzb_arena:raceDone', function(id, d)
    if type(d) ~= 'table' then return end
    local my = R
    if d.cancelled then
        TriggerEvent('mzb_arena:notify', 'the race is off: ' .. tostring(d.cancelled))
    end
    if not my or my.id ~= id or my.leaving then return end
    my.leaving, my.state, my.outSince = true, 'over', nil
    clearMarker(my)
    local hold = 2000
    if d.place then
        my.result = d
        note(my, ('FINISHED   P %d/%d   %s'):format(d.place, d.of or 1, clock(tonumber(d.time) or 0)), 6.0, 1.0)
        sound('CHECKPOINT_PERFECT')
        hold = 6000
    elseif d.out then
        note(my, d.out == 'dnf' and 'DID NOT FINISH' or 'RETIRED', 3.0, 1.0)
    else
        note(my, 'RACE OFF', 3.0, 1.0)
    end
    CreateThread(function()
        Wait(hold)                                         -- a moment to roll out past the line
        leaveTrack(my)
    end)
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (RC.command or 'arenarace'), 'Maze Bank Arena: the race on the show\'s track',
        { { name = 'what', help = 'status   (staff: start | cancel)' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if R then leaveTrack(R, true) end
    TriggerEvent('chat:removeSuggestion', '/' .. (RC.command or 'arenarace'))
end)
