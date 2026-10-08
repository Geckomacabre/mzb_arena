-- mzb_arena - client: the litter (GlobalState.mzbCrowd.litter: 'clean' | 'some' | 'trashed', server/crowd.lua).
--   * it lies at the crowd's spots of the show that is up (client/crowd.lua's MzbCrowdSpots: the bowl's rows, the
--     stage end when the show seats it, the floor's chairs or standing floor): in the row in front of a seat, on the
--     floor round a chair, among the standing crowd;
--   * whether a spot has a piece, which one, where exactly and which way it lies all come from the spot itself, so
--     every player sees the same mess, and the pieces of 'some' are among those of 'trashed';
--   * local props, frozen and without collision; only the nearest Config.Litter.Max within Config.Litter.Radius of
--     you are put down, and only while you are inside the arena.

local LT = Config.Litter or {}
local ST = GlobalState.mzbCrowd or Config.CrowdDefault
local roomKey = Config.Crowd.Room and GetHashKey(Config.Crowd.Room) or nil

local pieces = {}            -- [spot index] = object
local spots, spotsFor = {}, nil   -- the litter's spots for spotsFor = show .. level: { x, y, z, heading, model, lift }
local dirty = true

local function hash(a, b)                                   -- as client/crowd.lua's: the same picks on every client
    local h = (a * 2654435761) ~ (b * 40503) ~ 0x5bd1e995
    h = (h ~ (h >> 13)) * 1274126177
    return (h ~ (h >> 16)) & 0x7fffffff
end

local function rand(a, b)
    return (hash(a, b) % 100000) / 100000.0
end

local function weighted(pool, r)
    local total = 0.0
    for _, e in ipairs(pool) do total = total + e[2] end
    local x = r * total
    for _, e in ipairs(pool) do
        x = x - e[2]
        if x < 0.0 then return e end
    end
    return pool[#pool]
end

-- the pieces for a show at a level: one per chosen spot, a little off it along the row / round the chair
local function pick(show, level)
    local share = (LT.Share or {})[level] or 0.0
    local out = {}
    if share <= 0.0 or not MzbCrowdSpots or #(LT.Models or {}) == 0 then return out end
    for _, s in ipairs(MzbCrowdSpots(show)) do
        if rand(s.id, 71) < share then
            local h = math.rad(s[4])
            local fx, fy = -math.sin(h), math.cos(h)        -- the way the spot faces ...
            local ax, ay = fy, -fx                          -- ... and along the row
            local along = (rand(s.id, 73) - 0.5) * 0.44
            local fwd = (rand(s.id, 79) - 0.5) * (s.seat and 0.24 or 0.6)
            local m = weighted(LT.Models, rand(s.id, 83))
            out[#out + 1] = { s[1] + ax * along + fx * fwd, s[2] + ay * along + fy * fwd, s[3], rand(s.id, 89) * 360.0,
                              GetHashKey(m[1]), m[3] or 0.0 }
        end
    end
    return out
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local untilT = GetGameTimer() + 3000
    while not HasModelLoaded(model) do
        if GetGameTimer() > untilT then return false end
        Wait(0)
    end
    return true
end

local function put(i, interior)
    local p = spots[i]
    pieces[i] = false                                       -- tried (a model that will not load is not tried again)
    if not loadModel(p[5]) then return end
    -- the floor under it: the tread / the floor's cover where the collision is in, else the spot's own height
    local z = p[3]
    local found, gz = GetGroundZFor_3dCoord(p[1], p[2], z + 0.4, false)
    if found and math.abs(gz - z) < 0.3 then z = gz end
    local o = CreateObjectNoOffset(p[5], p[1], p[2], z + p[6] + 0.003, false, false, false)
    SetModelAsNoLongerNeeded(p[5])
    if not o or o == 0 then return end
    SetEntityHeading(o, p[4])
    FreezeEntityPosition(o, true)
    SetEntityCollision(o, false, false)
    if roomKey and interior ~= 0 then ForceRoomForEntity(o, interior, roomKey) end
    pieces[i] = o
end

local function remove(i)
    local o = pieces[i]
    if o and DoesEntityExist(o) then DeleteEntity(o) end
    pieces[i] = nil
end

local function removeAll()
    for i in pairs(pieces) do remove(i) end
end

AddStateBagChangeHandler('mzbCrowd', 'global', function(_, _, value)
    ST = value or Config.CrowdDefault
    dirty = true
end)

CreateThread(function()
    if LT.enabled == false then return end
    local present, lastPos, wanted, order = false, nil, {}, {}
    while true do
        local level = ST.litter or 'clean'
        local ped = PlayerPedId()
        local me = GetEntityCoords(ped)
        local id = 0
        if level ~= 'clean' then
            local ready
            id, ready = MzbInterior()
            if ready and GetInteriorFromEntity(ped) == id then
                present = true
            elseif not ready or #(me - Config.InteriorProbe) > (Config.Crowd.DespawnDistance or 160.0) then
                present = false
            end
        else
            present = false
        end
        if not present then
            if next(pieces) then removeAll() end
            dirty = true
            Wait(750)
        else
            -- another show or level: other pieces
            local key = (GlobalState.mzbShow or Config.DefaultShow) .. '/' .. level
            if key ~= spotsFor then
                removeAll()
                spots, spotsFor = pick(GlobalState.mzbShow or Config.DefaultShow, level), key
                dirty = true
            end
            -- the nearest Max within Radius: picked again when something changed or you have moved a few metres
            if dirty or #(me - lastPos) > 5.0 then
                local r2 = (LT.Radius or 60.0) ^ 2
                local near = {}
                for i, p in ipairs(spots) do
                    local dx, dy, dz = p[1] - me.x, p[2] - me.y, p[3] - me.z
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 < r2 then near[#near + 1] = { i, d2 } end
                end
                table.sort(near, function(a, b) return a[2] < b[2] end)
                wanted, order = {}, {}
                for k = 1, math.min(#near, LT.Max or 260) do
                    wanted[near[k][1]] = true
                    order[k] = near[k][1]
                end
                for i in pairs(pieces) do
                    if not wanted[i] then remove(i) end
                end
                lastPos, dirty = me, false
            end
            local budget = LT.PerTick or 12                -- the nearest first
            for _, i in ipairs(order) do
                if budget <= 0 then break end
                if pieces[i] == nil then
                    put(i, id)
                    budget = budget - 1
                end
            end
            Wait(50)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then removeAll() end
end)
