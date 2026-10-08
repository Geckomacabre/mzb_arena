-- mzb_arena - client: a show's cars (Config.ShowCars; server/cars.lua makes them, keeps them and takes them away:
-- they are the game's own networked vehicles, so there is nothing to draw or place here).
-- This side is the desk's Cars section (html/cars.js, on the Show tab): it is there while the show that is up has
-- cars, says how many are down (GlobalState.mzbCars) and has the two buttons - fresh ones, none. A press goes to the
-- server, which checks who pressed.

local function hasCars(show)
    local c = type(Config.ShowCars) == 'table' and Config.ShowCars[show]
    return type(c) == 'table' and type(c.spots) == 'table' and #c.spots > 0 and type(c.models) == 'table' and #c.models > 0
end

local function deskUpdate()
    local show = GlobalState.mzbShow or Config.DefaultShow
    local st = GlobalState.mzbCars or {}
    SendNUIMessage({ type = 'carsDesk', has = hasCars(show), n = st.show == show and tonumber(st.n) or 0 })
end
AddEventHandler('mzb_arena:lightsDesk', deskUpdate)
AddStateBagChangeHandler('mzbShow', 'global', function() SetTimeout(0, deskUpdate) end)
AddStateBagChangeHandler('mzbCars', 'global', function() SetTimeout(0, deskUpdate) end)

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
