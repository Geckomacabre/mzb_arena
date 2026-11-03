-- mzb_arena - client: the arena's menu and notifications through ox_lib, when the server runs it (Config.OxLib).
-- /arena or /mzb with nothing after it: the server sends mzb_arena:menu and this draws an ox_lib context menu - the
-- shows (the one that is up is marked), Reset the cars while the show has some (1.5.0), the loading dock's doors, the
-- light desk. A pick goes back to the server as mzb_arena:menuPick, which checks the staff ACE itself: the menu
-- decides nothing.
-- ox_lib is reached through its exports, not @ox_lib/init.lua, so the resource starts without it.

local function oxOn()
    return Config.OxLib and GetResourceState('ox_lib') == 'started'
end

local function showLabel(name)
    local l = Config.ShowLabels and Config.ShowLabels[name]
    if l then return l[1], l[2] end
    return name:sub(1, 1):upper() .. name:sub(2), 'masks-theater'
end

RegisterNetEvent('mzb_arena:notify', function(msg)
    if type(msg) ~= 'string' then return end
    if oxOn() then
        exports.ox_lib:notify({ title = 'Maze Bank Arena', description = msg, type = 'inform' })
    else
        TriggerEvent('chat:addMessage', { args = { 'arena', msg } })
    end
end)

RegisterNetEvent('mzb_arena:menu', function(d)
    if type(d) ~= 'table' or type(d.shows) ~= 'table' or not oxOn() then return end
    local shows = {}
    for _, name in ipairs(d.shows) do
        local label, icon = showLabel(name)
        local up = name == d.show
        shows[#shows + 1] = { title = label, icon = icon, disabled = up,
            description = up and 'The arena is set up for this now' or 'Set the arena up for ' .. label:lower(),
            serverEvent = 'mzb_arena:menuPick', args = { kind = 'show', name = name } }
    end
    -- (1.5.0) the show's cars (Config.ShowCars: the truck show's) back as new, while the show that is up has them
    local up = d.show or Config.DefaultShow
    if MzbShowHasCars and MzbShowHasCars(up) then
        local st = GlobalState.mzbCars or {}
        local n = st.show == up and tonumber(st.n) or 0
        shows[#shows + 1] = { title = 'Reset the cars', icon = 'car-burst',
            description = n > 0 and ('The %d on the floor taken away, fresh ones put down'):format(n) or 'Fresh cars put down',
            serverEvent = 'mzb_arena:menuPick', args = { kind = 'cars', action = 'reset' } }
    end
    shows[#shows + 1] = { title = 'Loading dock doors', icon = 'warehouse', menu = 'mzb_arena_dock', arrow = true,
        description = 'The three roller doors on the loading street' }
    shows[#shows + 1] = { title = 'Light desk', icon = 'sliders', event = 'mzb_arena:menuDesk',
        description = 'Lights, crowd, screens, music, followspot, fights' }

    local doors = {}
    local state = GlobalState.mzbDock or {}
    for _, k in ipairs({ 'a', 'b', 'c' }) do
        local open = state['dock_' .. k] == true
        doors[#doors + 1] = { title = 'Door ' .. k:upper(), icon = open and 'door-open' or 'door-closed',
            description = open and 'Open: shut it' or 'Shut: open it',
            serverEvent = 'mzb_arena:menuPick', args = { kind = 'dock', which = k, action = open and 'close' or 'open' } }
    end
    doors[#doors + 1] = { title = 'Open all', icon = 'arrow-up',
        serverEvent = 'mzb_arena:menuPick', args = { kind = 'dock', which = 'all', action = 'open' } }
    doors[#doors + 1] = { title = 'Shut all', icon = 'arrow-down',
        serverEvent = 'mzb_arena:menuPick', args = { kind = 'dock', which = 'all', action = 'close' } }

    exports.ox_lib:registerContext({
        { id = 'mzb_arena_menu', title = 'Maze Bank Arena', options = shows },
        { id = 'mzb_arena_dock', title = 'Loading dock doors', menu = 'mzb_arena_menu', options = doors },
    })
    exports.ox_lib:showContext('mzb_arena_menu')
end)

-- the menu's "Light desk": the desk's own command, so its permission is the server's as ever
AddEventHandler('mzb_arena:menuDesk', function()
    ExecuteCommand(Config.LightCommand)
end)
