-- mzb_arena - client: the event desk (Config.EventDesk): an official to talk to (client/peds.lua), whose menu goes by
-- the show that is up:
--   * a show with a track (Config.Races): the race - join, leave, start it now (the first on the list), and who has
--     signed up (GlobalState.mzbRace, server/race.lua);
--   * a show with a ring or a cage (Config.Fights.venues): set up a fight - take on an NPC, challenge a player
--     nearby, accept a challenge, the card. These are the fights' own challenge and accept (server/fights.lua),
--     reached through the server's desk (server/desk.lua);
--   * any other show: nothing to sign up for.
-- A pick is a request: the server checks every one of them.

local DC = Config.EventDesk or {}
if DC.enabled == false or type(DC.ped) ~= 'table' then return end

local RC = Config.Race or {}
local FC = Config.Fights or {}
local TRACKS = type(Config.Races) == 'table' and Config.Races or {}
local PICK = 'mzb_arena:deskPick'

local function show() return GlobalState.mzbShow or Config.DefaultShow end

local function showLabel(name)
    local l = Config.ShowLabels and Config.ShowLabels[name]
    return l and l[1] or name
end

-- ------------------------------------------------------------------ the race
local function raceOptions(track, opts)
    local s = MzbRaceState()
    local racers = type(s.racers) == 'table' and s.racers or {}
    local what = ('%s, %d laps'):format(track.label, track.laps)
    local fee, prize = tonumber(RC.fee) or 0, tonumber(RC.prize) or 0
    local money = (fee > 0 and (' Entry $%d.'):format(fee) or '') .. (prize > 0 and (' The winner takes $%d.'):format(prize) or '')
    local mine = false
    for _, r in ipairs(racers) do
        if r.src == s.me then mine = true end
    end
    if s.state == 'idle' or s.state == nil then
        opts[#opts + 1] = { title = ('Join the race (%s)'):format(what), icon = 'flag-checkered', event = PICK,
            args = { kind = 'race', action = 'join' },
            description = ('You open the sign-up: %d s, or until you start it.%s'):format(tonumber(RC.signup) or 45, money) }
    elseif s.state == 'signup' then
        local left = ('The start is in %d s.'):format(math.ceil(s.left / 1000))
        if mine then
            if s.host == s.me then
                opts[#opts + 1] = { title = 'Start now', icon = 'play', event = PICK, args = { kind = 'race', action = 'start' },
                    description = 'Close the sign-up: everyone to the grid' }
            end
            opts[#opts + 1] = { title = 'Leave the race', icon = 'right-from-bracket', event = PICK,
                args = { kind = 'race', action = 'leave' }, description = left }
        else
            local full = #racers >= #track.grid
            opts[#opts + 1] = { title = ('Join the race (%s)'):format(what), icon = 'flag-checkered', event = PICK,
                args = { kind = 'race', action = 'join' }, disabled = full,
                description = full and 'The grid is full' or (left .. money) }
        end
    else
        opts[#opts + 1] = { title = ('A race is on (%s)'):format(what), icon = 'flag-checkered',
            description = 'The sign-up opens again when it is over' }
    end
    if s.state == 'signup' then
        for i, r in ipairs(racers) do
            opts[#opts + 1] = { title = ('Grid %d: %s'):format(i, tostring(r.name)), icon = 'user' }
        end
    end
    if type(s.last) == 'string' then
        opts[#opts + 1] = { title = 'Last race', description = s.last, icon = 'trophy' }
    end
end

-- ------------------------------------------------------------------ fights
-- the players near enough to be asked: { id = server id, name }
local function nearby()
    local out = {}
    local me, pos = PlayerId(), GetEntityCoords(PlayerPedId())
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= me and #(GetEntityCoords(GetPlayerPed(pl)) - pos) < 40.0 then
            out[#out + 1] = { id = GetPlayerServerId(pl), name = GetPlayerName(pl) }
        end
    end
    return out
end

local function fightOptions(opts)
    local where = show() == 'mma' and 'cage' or 'ring'
    local f = GlobalState.mzbFight or {}
    opts[#opts + 1] = { title = 'Set up a fight: take on an NPC', icon = 'hand-fist', event = PICK,
        args = { kind = 'fight', action = 'npc' }, description = 'You go on the card: be in the ' .. where .. ' at the bell' }
    opts[#opts + 1] = { title = 'Set up a fight: challenge a player', icon = 'people-arrows', event = PICK,
        args = { kind = 'fight', action = 'players' }, description = 'Someone near you; they have to accept' }
    opts[#opts + 1] = { title = 'Accept a challenge', icon = 'handshake', event = PICK,
        args = { kind = 'fight', action = 'accept' } }
    opts[#opts + 1] = { title = 'The card', icon = 'list', event = PICK, args = { kind = 'fight', action = 'card' },
        description = (f.state and f.state ~= 'idle' and f.red and f.blue)
            and ('On now: %s vs %s'):format(tostring(f.red.name), tostring(f.blue.name)) or 'The bout on and the ones to come' }
    if DC.fights == 'staff' then
        opts[#opts + 1] = { title = 'Fights are set up by the arena\'s staff', icon = 'lock' }
    end
end

-- ------------------------------------------------------------------ the menu
local function open()
    local name = show()
    local opts = {}
    local track = RC.enabled ~= false and TRACKS[name]
    local ring = FC.enabled ~= false and (FC.venues or {})[name]
    if type(track) == 'table' then raceOptions(track, opts) end
    if ring then fightOptions(opts) end
    if #opts == 0 then
        opts[1] = { title = ('Nothing to sign up for at this show (%s)'):format(showLabel(name)), icon = 'circle-info',
            description = 'Races are signed up for here at a show with a track, fights at one with a ring or a cage' }
    end
    ArenaMenu.open({ id = 'mzb_arena_desk', title = 'Event desk', options = opts })
end

AddEventHandler(PICK, function(a)
    if type(a) ~= 'table' then return end
    if a.kind == 'race' then
        if a.action == 'join' then
            TriggerServerEvent('mzb_arena:raceJoin')
            SetTimeout(700, function()                     -- the list again, with you on it (and "Start now")
                local s = MzbRaceState()
                if s.state == 'signup' and not ArenaMenu.isOpen() then open() end
            end)
        elseif a.action == 'leave' then
            TriggerServerEvent('mzb_arena:raceLeave')
        elseif a.action == 'start' then
            TriggerServerEvent('mzb_arena:raceStart')
        end
    elseif a.kind == 'fight' then
        if a.action == 'players' then
            local opts = {}
            for _, p in ipairs(nearby()) do
                opts[#opts + 1] = { title = tostring(p.name), icon = 'user', event = PICK,
                    args = { kind = 'fight', action = 'player', id = p.id }, description = 'Challenge them' }
            end
            if #opts == 0 then opts[1] = { title = 'Nobody else is near the desk', icon = 'user-slash' } end
            ArenaMenu.open({ id = 'mzb_arena_desk_players', title = 'Challenge a player', options = opts })
        elseif a.action == 'card' then
            ExecuteCommand(FC.command or 'arenafight')     -- (anyone may ask for the card)
        elseif a.action == 'npc' or a.action == 'accept' or (a.action == 'player' and a.id) then
            TriggerServerEvent('mzb_arena:deskFight', { action = a.action, id = a.id })
        end
    end
end)

ArenaPed.add({ id = 'desk', model = DC.ped.model, coords = DC.ped.coords, scenario = DC.ped.scenario, room = DC.ped.room,
               distance = DC.distance, label = 'Talk to the event desk', icon = 'clipboard-list', onUse = open,
               enabled = function() return DC.enabled ~= false end })
