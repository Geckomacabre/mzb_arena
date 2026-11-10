-- mzb_arena - client: props put down by script while you are in the arena, local objects, frozen:
--   * Config.ConcourseProps (from the build, client/crowd_slots.lua): every show - the SE lobby's pop-up merch stands;
--   * Config.EveryShowProps (the owner's own): props in every show - the interview set's green screen. A show switch
--     leaves them standing;
--   * Config.ShowProps[show] (the owner's own): vanilla props for a show without CodeWalker - a camera crane, anything.
--     Another show takes them away;
--   * Config.StowedProps: what stands in the store rooms while its show is NOT up (the basket units, folded down).
-- A prop's room = the interior room it is forced into (room = 'concourse'; default Config.Crowd.Room, the bowl).

local defaultRoom = Config.Crowd and Config.Crowd.Room or nil
local made, madeFor = {}, nil
local always = nil                    -- Config.EveryShowProps once put down (they stay through a show switch)

local function remove(list)
    for _, o in ipairs(list or {}) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
end

local function clear()
    remove(made)
    made, madeFor = {}, nil
end

-- is `show` the one (or one of the ones) a stowed prop is out on the floor for?
local function inUse(unless, show)
    if type(unless) == 'table' then
        for _, s in ipairs(unless) do
            if s == show then return true end
        end
        return false
    end
    return unless == show
end

local function put(p, interior, into)
    local m = GetHashKey(p[1])
    if not IsModelInCdimage(m) then
        print(('[mzb_arena] props: there is no model "%s"'):format(tostring(p[1])))
        return
    end
    RequestModel(m)
    local untilT = GetGameTimer() + 5000
    while not HasModelLoaded(m) do
        if GetGameTimer() > untilT then return end
        Wait(0)
    end
    local o = CreateObjectNoOffset(m, p[2], p[3], p[4], false, false, false)
    SetModelAsNoLongerNeeded(m)
    if not o or o == 0 then return end
    SetEntityHeading(o, p[5] or 0.0)
    if p.ground then PlaceObjectOnGroundProperly(o) end
    FreezeEntityPosition(o, true)
    local room = p.room or defaultRoom
    if room and interior ~= 0 then MzbPutInRoom(o, interior, GetHashKey(room)) end
    into = into or made
    into[#into + 1] = o
end

CreateThread(function()
    while true do
        local show = GlobalState.mzbShow or Config.DefaultShow
        local id, ready = MzbInterior()
        local here = ready and GetInteriorFromEntity(PlayerPedId()) == id
        if here and not always then
            always = {}
            for _, p in ipairs(Config.EveryShowProps or {}) do put(p, id, always) end
        end
        if here and madeFor ~= show then
            clear()
            for _, p in ipairs(Config.ConcourseProps or {}) do put(p, id) end
            for _, p in ipairs((Config.ShowProps or {})[show] or {}) do put(p, id) end
            for _, p in ipairs(Config.StowedProps or {}) do
                if not inUse(p.unless, show) then put(p, id) end
            end
            madeFor = show
        elseif not here and (madeFor or always) and #(GetEntityCoords(PlayerPedId()) - Config.InteriorProbe) > 160.0 then
            clear()
            remove(always)
            always = nil
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        clear()
        remove(always)
    end
end)
