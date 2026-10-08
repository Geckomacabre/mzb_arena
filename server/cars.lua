-- mzb_arena - server: the cars a show has standing on its floor (Config.ShowCars: the truck show's six, side by side
-- on the deck between the jump's lips, there to be driven over).
--   GlobalState.mzbCars = { show = '<the show they stand for>' (nil: none are down), n = how many are down }
-- They are the game's own vehicles, made here (CreateVehicleServerSetter: OneSync), so every player sees the same
-- cars in the same state, wrecked or not. This script keeps their handles and takes them away again: when the show
-- changes, when the resource stops, and before fresh ones are put down.
--   /arenacars            how many are down
--   /arenacars reset      take them away and put fresh ones down (after the trucks have flattened them)
--   /arenacars clear      take them away (they come back with reset, or the next time the show comes up)
-- Who may: Config.CarsAccess (an ACE; nil = the light desk's, false = anyone). The desk's Cars buttons (Show tab) and
-- the exports land in the same two functions.

local CARS = type(Config.ShowCars) == 'table' and Config.ShowCars or {}
local LOCKED = 2                 -- the game's door lock state for "locked": nobody gets in

local cars = {}                  -- the vehicles that are down: { veh = its handle, made = when (ms), locked = its doors are }
local carsFor = nil              -- the show they stand for
local upShow, upSince = nil, 0   -- the show that is up, and since when (ms) as far as this script has seen
local cleared = false            -- staff took them away: none until a reset, or the show coming up again
local lastPut = -100000

-- a show's cars: its entry in Config.ShowCars, if it has somewhere to put them and something to put there
local function configFor(show)
    local c = CARS[show]
    if type(c) ~= 'table' or type(c.spots) ~= 'table' or #c.spots == 0 then return nil end
    if type(c.models) ~= 'table' or #c.models == 0 then return nil end
    return c
end

local function show() return GlobalState.mzbShow or Config.DefaultShow end

local published = nil
local function publish()
    local key = tostring(carsFor) .. '/' .. #cars
    if key == published then return end
    published = key
    GlobalState.mzbCars = { show = carsFor, n = #cars }
end

local function remove()
    for _, c in ipairs(cars) do
        if DoesEntityExist(c.veh) then DeleteEntity(c.veh) end
    end
    cars, carsFor = {}, nil
    publish()
end

-- Is a player at the arena? The cars are only put down while one is. A vehicle the server makes with nobody near
-- is nobody's: no game has it, so nothing stands it on its wheels or locks its doors (the lock is asked of the game
-- that owns the car), and it becomes the first player's to come within sight of the building from wherever they
-- are - whose game may not have the arena's floor and the jump loaded yet, for the cars to stand on. So the cars
-- wait until a player is this close (range: in or at the building), and the thread below looks again every second
-- for as long as the show is up.
local function someoneNear(range)
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped and ped ~= 0 and #(GetEntityCoords(ped) - Config.Screens.origin) < range then return true end
    end
    return false
end

local function rangeOf(c) return tonumber(c.range) or 80.0 end

-- fresh cars on the show's spots (the ones before are taken away first): how many were made
local function put(name, c)
    remove()
    -- a model per spot, picked at random: the list is shuffled and dealt out, so no two cars are the same while it
    -- is long enough
    local models = {}
    for i, m in ipairs(c.models) do models[i] = m end
    for i = #models, 2, -1 do
        local j = math.random(i)
        models[i], models[j] = models[j], models[i]
    end
    for i, p in ipairs(c.spots) do
        local model = models[(i - 1) % #models + 1]
        local ok, veh = pcall(CreateVehicleServerSetter, GetHashKey(model), c.type or 'automobile', p.x, p.y, p.z, p.w or 0.0)
        if not ok then
            -- the server makes entities only with OneSync on: said here, and not tried again until a reset or the
            -- show coming up again (the show counts as having had its cars)
            print('[mzb_arena] cars: the server could not make a vehicle (OneSync has to be on): ' .. tostring(veh))
            break
        end
        if veh and veh ~= 0 then
            -- kept when the last player near them walks away: they go with the show, not with whoever was there
            SetEntityOrphanMode(veh, 2)
            cars[#cars + 1] = { veh = veh, model = model, made = GetGameTimer() }
        end
    end
    carsFor, lastPut = name, GetGameTimer()
    publish()
    return #cars
end

-- the cars come with their show and go with it; their doors are locked once a game has them
CreateThread(function()
    while true do
        Wait(1000)
        local now, name = GetGameTimer(), show()
        local c = configFor(name)
        if carsFor and carsFor ~= name then remove() end      -- another show: the last one's cars go
        if name ~= upShow then upShow, upSince, cleared = name, now, false end
        -- put down a moment after the show comes up (the players' games set the jump up first: a car made before
        -- that would drop through where it is going to be), once a player is at the arena. Also when the resource
        -- starts with the show already up
        if c and not carsFor and not cleared and now - upSince >= (tonumber(c.delay) or 4.0) * 1000
           and someoneNear(rangeOf(c)) then
            put(name, c)
        end
        if carsFor then
            -- a car something else has removed (a clean-up script, a staff tool) is no longer one of ours (not
            -- asked of one just made: its handle is not let go of on the word of its first moments)
            for i = #cars, 1, -1 do
                if now - cars[i].made > 3000 and not DoesEntityExist(cars[i].veh) then table.remove(cars, i) end
            end
            publish()
            -- the doors: locking is done by the game that owns the car, so it is asked for once one does, and
            -- again until the lock is seen to have taken - then the car is left alone (a keys script may open it)
            if c and c.locked then
                for _, car in ipairs(cars) do
                    if not car.locked and DoesEntityExist(car.veh) then
                        if GetVehicleDoorLockStatus(car.veh) == LOCKED then
                            car.locked = true
                        elseif (NetworkGetEntityOwner(car.veh) or -1) > 0 then
                            SetVehicleDoorsLocked(car.veh, LOCKED)
                        end
                    end
                end
            end
        end
    end
end)

-- take the show's cars away and put fresh ones down: true and what happened, or false and why not
local function reset()
    local name = show()
    local c = configFor(name)
    if not c then return false, ('the %s show has no cars'):format(tostring(name)) end
    if GetGameTimer() - lastPut < 2000 then return false, 'the crew is still putting the cars down' end
    cleared = false
    if not someoneNear(rangeOf(c)) then
        remove()                                             -- nobody is there: fresh ones the moment somebody is
        return true, 'the cars are gone; fresh ones go down as soon as a player is at the arena'
    end
    local n = put(name, c)
    if n == 0 then return false, 'the cars could not be made (the server console says why)' end
    return true, ('%d fresh cars are down'):format(n)
end

-- take them away: they stay away until a reset, or the show coming up again
local function clear()
    local n = #cars
    remove()
    cleared = true
    return true, n > 0 and ('%d cars taken away'):format(n) or 'no cars are down'
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then GlobalState.mzbCars = { n = 0 } end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then remove() end
end)

-- ------------------------------------------------------------------ chat, the desk, other resources
local function allowed(src) return MzbAllowed(src, Config.CarsAccess) end

local function status(src)
    local name = show()
    if not configFor(name) then return MzbReply(src, 'cars', ('the %s show has no cars'):format(tostring(name))) end
    MzbReply(src, 'cars', ('%s: %d cars down%s | /%s reset (fresh ones) | clear'):format(name, #cars,
        (#cars == 0 and not cleared) and ' (they go down once a player is at the arena)' or '',
        Config.CarsCommand or 'arenacars'))
end

RegisterCommand(Config.CarsCommand or 'arenacars', function(src, args)
    if not allowed(src) then return MzbReply(src, 'cars', 'you are not allowed to run the arena\'s cars') end
    local sub = args[1] and tostring(args[1]):lower()
    local _, msg
    if sub == 'reset' or sub == 'fresh' then _, msg = reset()
    elseif sub == 'clear' or sub == 'off' then _, msg = clear()
    else return status(src) end
    MzbReply(src, 'cars', msg)
end, false)

-- the desk's buttons
local throttled = MzbThrottle(500)
RegisterNetEvent('mzb_arena:cars', function(action)
    local src = source
    if throttled(src) or (action ~= 'reset' and action ~= 'clear') or not allowed(src) then return end
    local _, msg
    if action == 'reset' then _, msg = reset() else _, msg = clear() end
    MzbReply(src, 'cars', msg)
end)

-- other resources: a show script that wants the cars back between two runs
exports('ResetCars', function() return reset() end)
exports('ClearCars', function() return clear() end)
exports('GetCars', function()
    local out = {}
    for i, c in ipairs(cars) do out[i] = c.veh end
    return out
end)
