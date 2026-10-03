-- mzb_arena - client: the followspot (GlobalState.mzbSpot, server/spot.lua).
-- Drawn like the light desk's spots (client/lights.lua): a DrawSpotLight per lamp of Config.FollowSpot.fixtures,
-- every frame while the spot is on and the player is in the bowl or a room that opens onto it. Locked onto a player,
-- every client follows that ped itself; aimed by hand, the operator's points arrive a few times a second and the beam
-- glides after them. The operator grabs / releases free aim with a key (RegisterKeyMapping) and sees their own aim at
-- once.

local FS = Config.FollowSpot or {}
local S = GlobalState.mzbSpot
local goal = nil                      -- where the beam should be (vector3)
local cur = nil                       -- where it is (it glides to goal)
local grabbing = false

AddStateBagChangeHandler('mzbSpot', 'global', function(_, _, value)
    S = value
    -- someone else took free aim (or the spot follows a player now): let go
    if grabbing and (not S or S.aim ~= 'point' or S.by ~= GetPlayerServerId(PlayerId())) then grabbing = false end
    if S and S.aim == 'point' and S.point and not grabbing then
        goal = vector3(S.point.x + 0.0, S.point.y + 0.0, S.point.z + 0.0)
    end
    SendNUIMessage({ type = 'spotDesk', spot = S })
end)

RegisterNetEvent('mzb_arena:spotPoint', function(x, y, z)
    if type(x) == 'number' and type(y) == 'number' and type(z) == 'number' and not grabbing then
        goal = vector3(x, y, z)
    end
end)

local function pedOf(serverId)
    if serverId == GetPlayerServerId(PlayerId()) then return PlayerPedId() end
    local p = GetPlayerFromServerId(serverId)
    if p == -1 then return 0 end
    return GetPlayerPed(p)
end

-- the camera's forward vector
local function camForward()
    local r = GetFinalRenderedCamRot(2)
    local x, z = math.rad(r.x), math.rad(r.z)
    return vector3(-math.sin(z) * math.cos(x), math.cos(z) * math.cos(x), math.sin(x))
end

-- what the operator's camera looks at (world, vehicles, peds, objects), 150 m at most
local function aimPoint()
    local from = GetFinalRenderedCamCoord()
    local to = from + camForward() * 150.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 2 + 4 + 16,
        PlayerPedId(), 7)
    local _, hit, pos = GetShapeTestResult(ray)
    if hit == 1 or hit == true then return pos end
    return nil
end

-- the player nearest the crosshair (within Config.FollowSpot.lookAngle degrees), not yourself
local function lookedAt()
    local from, fwd = GetFinalRenderedCamCoord(), camForward()
    local best, bestAng = nil, math.rad(FS.lookAngle or 8.0)
    local me = PlayerId()
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= me then
            local ped = GetPlayerPed(p)
            local d = GetEntityCoords(ped) - from
            local len = #d
            if len > 1.0 and len < 150.0 then
                local dot = (d.x * fwd.x + d.y * fwd.y + d.z * fwd.z) / len
                local ang = math.acos(math.max(-1.0, math.min(1.0, dot)))
                if ang < bestAng then best, bestAng = GetPlayerServerId(p), ang end
            end
        end
    end
    return best
end

local function say(msg) TriggerEvent('chat:addMessage', { args = { 'spot', msg } }) end

-- ------------------------------------------------------------------ the beam
local visible = { bowl = true, near = true }

CreateThread(function()
    while true do
        if FS.enabled and S and S.on and visible[MzbListener.zone] then
            if S.aim == 'player' then
                local ped = pedOf(S.target)
                if ped ~= 0 and DoesEntityExist(ped) then
                    local p = GetEntityCoords(ped)
                    goal = vector3(p.x, p.y, p.z - 0.2)          -- the middle of the body: the beam covers head to feet
                end
            end
            if goal then
                local dt = math.min(GetFrameTime(), 0.1)
                cur = cur and (cur + (goal - cur) * math.min(1.0, dt * (grabbing and 20.0 or 8.0))) or goal
                local c = S.color or FS.color or { 255, 248, 235 }
                local bright = (FS.brightness or 40.0) * (S.intensity or 1.0)
                for _, f in ipairs(FS.fixtures or {}) do
                    local d = cur - f
                    local len = #d
                    if len > 0.5 then
                        local n = d / len
                        DrawSpotLight(f.x, f.y, f.z, n.x, n.y, n.z, c[1], c[2], c[3], len + 10.0, bright,
                            FS.hardness or 0.75, S.size or 5.0, FS.falloff or 1.0)
                        if Config.LightLensGlow then
                            DrawLightWithRange(f.x + n.x * 0.5, f.y + n.y * 0.5, f.z + n.z * 0.5, c[1], c[2], c[3], 1.6, 3.0 * (S.intensity or 1.0))
                        end
                    end
                end
            end
            Wait(0)
        else
            cur = nil
            Wait(250)
        end
    end
end)

-- ------------------------------------------------------------------ free aim (the operator)
CreateThread(function()
    local lastSent, lastPos = 0, nil
    local gap = math.floor(1000 / math.max(1, FS.sendRate or 8))
    while true do
        if grabbing then
            local p = aimPoint()
            if p then
                goal = p
                local now = GetGameTimer()
                if now - lastSent >= gap and (not lastPos or #(p - lastPos) > 0.05) then
                    TriggerServerEvent('mzb_arena:spotPoint', p.x, p.y, p.z)
                    lastSent, lastPos = now, p
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function grab()
    if not FS.enabled then return end
    if grabbing then
        grabbing = false
        say('free aim released: the spot stays where it is')
        return
    end
    grabbing = true
    TriggerServerEvent('mzb_arena:spot', { on = true, aim = 'point' })   -- the server checks you may
    say('free aim: the spot follows your camera (press again to let go)')
    CreateThread(function()                              -- not handed the spot within 2 s: not allowed
        Wait(2000)
        if grabbing and not (S and S.aim == 'point' and S.by == GetPlayerServerId(PlayerId())) then
            grabbing = false
            say('you are not allowed to run the followspot')
        end
    end)
end

RegisterCommand('arenaspotaim', grab, false)
RegisterKeyMapping('arenaspotaim', 'Arena followspot: grab / release free aim', 'keyboard', FS.key or 'F7')

local function follow(id)
    if not id then return say('nobody under your crosshair') end
    TriggerServerEvent('mzb_arena:spot', { on = true, aim = 'player', target = id })
    grabbing = false
end

-- /arenaspot: free and follow look run here (they need your camera); the rest goes to the server
RegisterCommand(FS.command or 'arenaspot', function(_, args)
    local sub = args[1] and args[1]:lower()
    if sub == 'free' then return grab() end
    if sub == 'follow' and args[2] == 'look' then return follow(lookedAt()) end
    TriggerServerEvent('mzb_arena:spotCmd', { args[1], args[2], args[3] })
end, false)

-- ------------------------------------------------------------------ the desk's Followspot section (html/spot.js)
AddEventHandler('mzb_arena:lightsDesk', function()
    SendNUIMessage({ type = 'spotDesk', spot = S, enabled = FS.enabled == true })
end)

-- the players in the arena, for the desk's list (asked by the desk while it is open)
RegisterNUICallback('spotPlayers', function(_, cb)
    local list = {}
    for _, p in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(p)
        if GetInteriorFromEntity(ped) ~= 0 and GetInteriorFromEntity(ped) == GetInteriorFromEntity(PlayerPedId()) then
            list[#list + 1] = { id = GetPlayerServerId(p), name = GetPlayerName(p) }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    cb(list)
end)

RegisterNUICallback('spot', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    if data.action == 'free' then
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'close' })                   -- the desk closes: free aim needs the camera
        if not grabbing then grab() end
    elseif data.action == 'look' then
        follow(lookedAt())
    else
        TriggerServerEvent('mzb_arena:spot', data.patch)
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (FS.command or 'arenaspot'), 'Maze Bank Arena: the followspot (staff)',
        { { name = 'what', help = 'on | off | follow <id|me|look> | free | color <c> | size <2-15> | intensity <0-100> | status' } })
end)
