-- mzb_arena - client: the press boxes (Config.PressBox, built into the interior by arena_build/ar_press.py): the sound
-- board in each opens the light desk, the same as typing /arenalights (the server checks who may).
--   MzbTarget.add(id, { coords = vector3, size = vector3 (along the arena, across it, up), label, icon, distance,
--                       onUse = function() ... end })    a zone in the arena's frame turn
--   MzbTarget.remove(id)
-- A zone is an ox_target box zone if the server runs ox_target, else a qb-target one, else a prompt and [E] within
-- `distance` of its middle. client/spot.lua puts the followspots' zones down through it too.

MzbTarget = {}

local PB = Config.PressBox or {}
local AF = Config.ArenaFrame
local AC, AS = math.cos(AF.ang), math.sin(AF.ang)
local HEADING = math.deg(AF.ang)                 -- the arena's u axis as a heading of a zone's length
local zones = {}                                 -- id -> { def, kind, handle }

local function started(name) return GetResourceState(name) == 'started' end

-- the arena frame (u along, v across, z over the event floor) -> the world
function MzbArenaToWorld(u, v, z)
    return vector3(AF.x + u * AC - v * AS, AF.y + u * AS + v * AC, AF.z + z)
end

local function use(z)
    local now = GetGameTimer()
    if now - (z.usedAt or -10000) < 500 then return end
    z.usedAt = now
    if z.def.onUse then z.def.onUse() end
end

function MzbTarget.add(id, def)
    MzbTarget.remove(id)
    local z = { def = def }
    local s = def.size or vector3(1.0, 1.0, 1.0)
    local can = def.enabled and function() return def.enabled() end or nil   -- (only while it is there to use)
    if started('ox_target') then
        z.kind = 'ox_target'
        z.handle = exports.ox_target:addBoxZone({ coords = def.coords, size = s, rotation = HEADING,
            options = { { name = 'mzb_arena_' .. id, icon = 'fa-solid fa-' .. (def.icon or 'hand'), label = def.label,
                          distance = def.distance, canInteract = can, onSelect = function() use(z) end } } })
    elseif started('qb-target') then
        z.kind = 'qb-target'
        z.handle = 'mzb_arena_' .. id
        -- (PolyZone's box: its length lies along the box's own y, its width along x - so across the arena, then along)
        exports['qb-target']:AddBoxZone(z.handle, def.coords, s.y, s.x, { name = z.handle, heading = HEADING,
            minZ = def.coords.z - s.z / 2, maxZ = def.coords.z + s.z / 2, debugPoly = false },
            { options = { { icon = 'fas fa-' .. (def.icon or 'hand'), label = def.label, canInteract = can,
                            action = function() use(z) end } },
              distance = def.distance })
    else
        z.kind = 'prompt'
    end
    zones[id] = z
end

function MzbTarget.remove(id)
    local z = zones[id]
    if not z then return end
    if z.kind == 'ox_target' and started('ox_target') then exports.ox_target:removeZone(z.handle)
    elseif z.kind == 'qb-target' and started('qb-target') then exports['qb-target']:RemoveZone(z.handle) end
    zones[id] = nil
end

-- no target script: [E] at the nearest zone within its reach
CreateThread(function()
    while true do
        local best, bestD = nil, nil
        local p = GetEntityCoords(PlayerPedId())
        for _, z in pairs(zones) do
            if z.kind == 'prompt' and (not z.def.enabled or z.def.enabled()) then
                local d = #(p - z.def.coords)
                if d < (z.def.distance or 1.5) + 0.6 and (not bestD or d < bestD) then best, bestD = z, d end
            end
        end
        if best then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ ' .. (best.def.label or ''))
            EndTextCommandDisplayHelp(0, false, false, -1)
            if IsControlJustReleased(0, 38) then use(best) end
            Wait(0)
        else
            Wait(next(zones) and 250 or 1000)
        end
    end
end)

-- ------------------------------------------------------------------ the sound boards
CreateThread(function()
    if PB.enabled == false then return end
    Wait(1500)                                   -- (the target resources start first on most servers)
    for i, d in ipairs(PB.desks or {}) do
        MzbTarget.add('pressdesk' .. i, { coords = MzbArenaToWorld(d.u, d.v, d.z), size = PB.deskSize,
            label = PB.label or 'Open the light desk', icon = PB.icon or 'sliders', distance = PB.distance or 1.8,
            onUse = function()
                if MzbDeskOpen and MzbDeskOpen() then return end
                ExecuteCommand(Config.LightCommand)
            end })
    end
end)

-- ------------------------------------------------------------------ the boxes are the bowl's room
-- (2026-11-10) the bowl's floor was cut out under the boxes, so the first floor below them is the concourse's: the game
-- can put a player (and their camera) standing in a box in the concourse room, and from there the bowl is drawn only
-- through its doorways - the far crowd, the centre board gone, the light washed out. While the player is inside a box
-- (ar_press.CUT and the same turned for box B, a little over) they and the camera are held in the bowl
local BOX = PB.box or { u = 5.30, v0 = 46.55, v1 = 51.95, z0 = 17.9, z1 = 23.5 }
local function inBox(p)
    local dx, dy = p.x - AF.x, p.y - AF.y
    local u, v, z = dx * AC + dy * AS, -dx * AS + dy * AC, p.z - AF.z
    v = math.abs(v)
    return math.abs(u) < BOX.u and v > BOX.v0 and v < BOX.v1 and z > BOX.z0 and z < BOX.z1
end
CreateThread(function()
    if PB.enabled == false or not MzbHoldRoom then return end
    local bowl = GetHashKey('bowl')
    while true do
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        if inBox(p) then
            local id = MzbInterior()
            if id and id ~= 0 then MzbHoldRoom(id, bowl, 1000, p, true, true) end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(zones) do MzbTarget.remove(id) end
end)
