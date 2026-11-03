-- mzb_arena - client: a show's cars (Config.ShowCars; server/cars.lua makes them, keeps them and takes them away:
-- they are the game's own networked vehicles, so there is nothing to draw or place here).
-- This side is the desk's CARS section (html/cars.js, on the CROWD page): it is there while the show that is up has
-- cars, says how many are down (GlobalState.mzbCars) and has the two keys - reset (fresh ones), clear (none). A press
-- goes to the server, which checks who pressed. The /arena menu has Reset the cars too (client/oxmenu.lua).
-- (1.5.0) And the driver at the cars asks to own them, so they are crushed where they are driven over (below).

-- the show has cars: its entry in Config.ShowCars has spots and models (the /arena menu asks too)
function MzbShowHasCars(show)
    local c = type(Config.ShowCars) == 'table' and Config.ShowCars[show]
    return type(c) == 'table' and type(c.spots) == 'table' and #c.spots > 0 and type(c.models) == 'table' and #c.models > 0
end

local carsNow = GlobalState.mzbCars
local function deskUpdate()
    local show = GlobalState.mzbShow or Config.DefaultShow
    local st = GlobalState.mzbCars or {}
    SendNUIMessage({ type = 'carsDesk', has = MzbShowHasCars(show), n = st.show == show and tonumber(st.n) or 0 })
end
AddEventHandler('mzb_arena:lightsDesk', deskUpdate)
AddStateBagChangeHandler('mzbShow', 'global', function() SetTimeout(0, deskUpdate) end)
AddStateBagChangeHandler('mzbCars', 'global', function(_, _, value) carsNow = value; SetTimeout(0, deskUpdate) end)

-- (1.5.0) Crushed where they are driven over. A car is wrecked in the game that owns it; the others are sent where it
-- is and six rough dents, not its shape - so a truck driving over a car another player's game owns pushed it, saw it
-- put back where its owner had it, and left it whole: the cars seemed to reset. Now the driver of a vehicle at the
-- cars asks to own the ones within `grab` m (the server lets these requests through, server/cars.lua) - unless
-- another driver at it owns it already: mid-crush it stays theirs. At most a request a second a car, and only while
-- driving at them (each request is a network event).
local function anotherDriverHas(car, grab)
    local owner = NetworkGetEntityOwner(car)
    if not owner or owner < 0 or owner == PlayerId() then return false end
    local p = GetPlayerPed(owner)
    return p ~= 0 and IsPedInAnyVehicle(p, false) and #(GetEntityCoords(p) - GetEntityCoords(car)) < grab
end

CreateThread(function()
    local asked = {}
    while true do
        local ids = type(carsNow) == 'table' and type(carsNow.ids) == 'table' and carsNow.ids or nil
        local ped = PlayerPedId()
        local veh = ids and #ids > 0 and GetVehiclePedIsIn(ped, false) or 0
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local c = type(Config.ShowCars) == 'table' and Config.ShowCars[carsNow.show] or {}
            local grab, now, at = tonumber(c.grab) or 20.0, GetGameTimer(), GetEntityCoords(veh)
            for _, id in ipairs(ids) do
                local car = NetworkDoesNetworkIdExist(id) and NetworkGetEntityFromNetworkId(id) or 0
                if car ~= 0 and car ~= veh and now - (asked[id] or -100000) >= 1000 and not NetworkHasControlOfEntity(car)
                   and #(GetEntityCoords(car) - at) < grab and not anotherDriverHas(car, grab) then
                    asked[id] = now
                    NetworkRequestControlOfEntity(car)
                end
            end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

RegisterNUICallback('cars', function(data, cb)
    cb('ok')
    if type(data) == 'table' and (data.action == 'reset' or data.action == 'clear') then
        TriggerServerEvent('mzb_arena:cars', data.action)
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (Config.CarsCommand or 'arenacars'), 'Maze Bank Arena: the show\'s cars (staff)',
        { { name = 'what', help = 'reset (take them away and put fresh ones down) | clear (take them away) | nothing: how many are down' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        TriggerEvent('chat:removeSuggestion', '/' .. (Config.CarsCommand or 'arenacars'))
    end
end)
