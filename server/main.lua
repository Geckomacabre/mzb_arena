-- mzb_arena - server: the arena's shared state (GlobalState, synced to every client incl. late joiners)
--   GlobalState.mzbDock = { dock_a = bool, dock_b = bool, dock_c = bool }   (true = open)
--   GlobalState.mzbShow = '<show name>'                                   (Config.Shows)
-- Commands (ACE command.arena - add_ace group.admin command.arena allow):
--   /arena show <name>              switch the show (entity sets) for everyone
--   /arena dock <a|b|c|all> <open|close|toggle>
--   /arena status
--   /mzb <show>                     the quick switch (Config.QuickCommand): /mzb wrestling, /mzb basketball ...
--   /mzb list | /mzb status | /mzb dock <a|b|c|all> <open|close|toggle>
-- With ox_lib running (Config.OxLib): /arena or /mzb alone opens its menu on the player's screen, and the answers are
-- its notifications. The menu's picks come back as mzb_arena:menuPick and are checked here like the typed commands.

-- is ox_lib there to draw the menu and the notifications? (optional: without it, chat)
local function oxOn()
    return Config.OxLib and GetResourceState('ox_lib') == 'started'
end

local function initState()
    if GlobalState.mzbDock == nil then
        GlobalState.mzbDock = { dock_a = false, dock_b = false, dock_c = false }
    end
    if GlobalState.mzbShow == nil or Config.Shows[GlobalState.mzbShow] == nil then
        GlobalState.mzbShow = Config.DefaultShow
    end
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then initState() end
end)

local function reply(src, msg)
    if src == 0 then
        print('[mzb_arena] ' .. msg)
    elseif oxOn() then
        TriggerClientEvent('mzb_arena:notify', src, msg)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'arena', msg } })
    end
end

local function showNames()
    local names = {}
    for k in pairs(Config.Shows) do names[#names + 1] = k end
    table.sort(names)
    return names
end

-- a show's name from what was typed: the show itself or one of Config.ShowAliases (any case)
local function resolveShow(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower()
    if Config.Shows[name] then return name end
    local alias = Config.ShowAliases and Config.ShowAliases[name]
    if alias and Config.Shows[alias] then return alias end
    return nil
end

local lastSwitch = -1000000

-- switch the show for everyone; src 0 = the console or a script (no cooldown). Returns true when it switched.
local function switchShow(src, typed)
    local show = resolveShow(typed)
    if not show then
        reply(src, ('unknown show "%s" - one of: %s'):format(tostring(typed), table.concat(showNames(), ', ')))
        return false
    end
    if show == GlobalState.mzbShow then
        reply(src, 'the arena is already set up for ' .. show)
        return false
    end
    local now = GetGameTimer()
    if src ~= 0 and now - lastSwitch < (Config.SwitchCooldown or 0) * 1000 then
        reply(src, 'the crew is still changing over - try again in a moment')
        return false
    end
    lastSwitch = now
    GlobalState.mzbShow = show
    local who = src == 0 and 'console' or (GetPlayerName(src) or ('player ' .. src))
    print(('[mzb_arena] %s switched the show to %s'):format(who, show))
    if Config.AnnounceSwitch then
        TriggerClientEvent('chat:addMessage', -1, { args = { 'arena', 'Maze Bank Arena is now set up for ' .. show } })
    elseif src ~= 0 then
        reply(src, 'show: ' .. show)
    end
    return true
end

local function setDock(which, action)
    local doors = GlobalState.mzbDock or {}
    local list = which == 'all' and { 'dock_a', 'dock_b', 'dock_c' } or { 'dock_' .. which }
    for _, k in ipairs(list) do
        if Config.DockDoors[k] == nil then return false end
        if action == 'open' then doors[k] = true
        elseif action == 'close' then doors[k] = false
        else doors[k] = not doors[k] end
    end
    GlobalState.mzbDock = doors
    return true
end

local function status(src)
    local d = GlobalState.mzbDock or {}
    reply(src, ('show %s | dock a %s b %s c %s'):format(tostring(GlobalState.mzbShow),
        d.dock_a and 'open' or 'shut', d.dock_b and 'open' or 'shut', d.dock_c and 'open' or 'shut'))
end

local function dock(src, which, action)
    if not which or not setDock(which, action or 'toggle') then
        return reply(src, 'dock <a|b|c|all> <open|close|toggle>')
    end
    reply(src, 'dock ' .. which .. ' ' .. (action or 'toggle'))
end

-- the [E] prompt at the doors (client, Config.DockButtons): a known door, the player really next to it, allowed by
-- Config.DockAccess (false = anyone, else an ACE), no faster than Config.DockCooldown per door
local lastDock = {}
RegisterNetEvent('mzb_arena:dockButton', function(name)
    local src = source
    if not Config.DockButtons or type(name) ~= 'string' then return end
    local d = Config.DockDoors[name]
    if not d then return end
    if Config.DockAccess and not IsPlayerAceAllowed(tostring(src), Config.DockAccess) then
        return TriggerClientEvent('chat:addMessage', src, { args = { 'arena', 'this door is staff only' } })
    end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local p = GetEntityCoords(ped)
    if #(vector2(p.x, p.y) - vector2(d.x, d.y)) > Config.DockReachVehicle + 2.0 or math.abs(p.z - d.z) > 5.0 then
        return
    end
    local now = GetGameTimer()
    if now - (lastDock[name] or -1000000) < (Config.DockCooldown or 2.0) * 1000 then return end
    lastDock[name] = now
    local doors = GlobalState.mzbDock or {}
    doors[name] = not doors[name]
    GlobalState.mzbDock = doors
end)

-- the ox_lib menu on a player's screen (client/oxmenu.lua); false when there is no ox_lib (or it is the console)
local function openMenu(src)
    if src == 0 or not oxOn() then return false end
    TriggerClientEvent('mzb_arena:menu', src, { show = GlobalState.mzbShow, shows = showNames() })
    return true
end

-- a pick in the menu: the same permission and the same checks as the typed commands
RegisterNetEvent('mzb_arena:menuPick', function(d)
    local src = source
    if type(d) ~= 'table' then return end
    if not IsPlayerAceAllowed(tostring(src), 'command.' .. Config.Command) then
        return reply(src, 'you are not allowed to change the arena')
    end
    if d.kind == 'show' and type(d.name) == 'string' then
        switchShow(src, d.name)
    elseif d.kind == 'dock' and type(d.which) == 'string' then
        local which = d.which:lower()
        if which ~= 'a' and which ~= 'b' and which ~= 'c' and which ~= 'all' then return end
        local action = (d.action == 'open' or d.action == 'close') and d.action or 'toggle'
        dock(src, which, action)
    end
end)

RegisterCommand(Config.Command, function(src, args)
    local sub = args[1] and args[1]:lower()
    if sub == 'show' and args[2] then
        return switchShow(src, args[2])
    elseif sub == 'dock' and args[2] then
        return dock(src, args[2], args[3])
    elseif sub == 'status' then
        return status(src)
    elseif not sub and openMenu(src) then
        return
    end
    reply(src, '/' .. Config.Command .. ' show <name> | /' .. Config.Command .. ' dock <a|b|c|all> <open|close|toggle> | /'
        .. Config.Command .. ' status')
end, true)

-- the quick switch: same permission as the main command (its ACE), checked here so one ACE line covers both
if Config.QuickCommand then
    RegisterCommand(Config.QuickCommand, function(src, args)
        if src ~= 0 and not IsPlayerAceAllowed(tostring(src), 'command.' .. Config.Command) then
            return reply(src, 'you are not allowed to change the arena')
        end
        local a = args[1] and args[1]:lower()
        if not a and openMenu(src) then return end
        if not a or a == 'list' or a == 'help' then
            local out = {}
            for _, n in ipairs(showNames()) do
                out[#out + 1] = n == GlobalState.mzbShow and ('[' .. n .. ']') or n
            end
            return reply(src, ('/%s <show>: %s'):format(Config.QuickCommand, table.concat(out, '  ')))
        elseif a == 'status' then
            return status(src)
        elseif a == 'dock' then
            return dock(src, args[2], args[3])
        end
        switchShow(src, a)
    end, false)
end

-- other resources (a job script, ox_target panels ...) can drive the arena too
exports('SetShow', function(name)
    local show = resolveShow(name)
    if not show then return false end
    GlobalState.mzbShow = show
    return true
end)
exports('GetShow', function() return GlobalState.mzbShow end)
exports('GetShows', function() return showNames() end)
exports('SetDock', function(which, action) return setDock(which, action) end)
