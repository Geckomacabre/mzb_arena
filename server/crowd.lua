-- mzb_arena - server: the crowd's state (GlobalState.mzbCrowd, synced to every client incl. late joiners)
--   GlobalState.mzbCrowd = { on = true | false, mood = 'doors' | 'show' | 'peak' | 'cheer' (Config.CrowdMoods),
--                            staff = true | false (the staff and the press come in with the crowd),
--                            litter = 'clean' | 'some' | 'trashed' (what lies in the rows and on the floor) }
-- Who may change it: Config.CrowdAccess (an ACE; false = anyone). The desk (NUI), chat and the exports all land in
-- setCrowd. The people themselves are each client's own (client/crowd.lua): nothing but this state is synced.
--   /arenacrowd                    what the crowd is doing, and how many of them you see
--   /arenacrowd on | off | toggle  bring the crowd in / send it home
--   /arenacrowd mood <doors|show|peak|cheer>
--   /arenacrowd staff on | off | toggle   the staff and the press (security, photographers, camera crews, officials)
--   /arenacrowd litter clean | some | trashed
--   /arenacrowd mine <n>           how many crowd peds YOU see (anyone may; saved on the player's PC)

local LITTER = { clean = true, some = true, trashed = true }

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

local function current()
    return GlobalState.mzbCrowd or copy(Config.CrowdDefault)
end

-- a patch from the desk / chat / an export, checked field by field against the current state
local function sanitize(patch, cur)
    local out = { on = cur.on == true, mood = cur.mood, staff = cur.staff ~= false,
                  litter = LITTER[cur.litter] and cur.litter or 'clean' }
    if type(patch) ~= 'table' then return out end
    if patch.on ~= nil then out.on = patch.on == true end
    if patch.staff ~= nil then out.staff = patch.staff == true end
    if LITTER[patch.litter] then out.litter = patch.litter end
    if type(patch.mood) == 'string' and Config.CrowdMoods[patch.mood] then out.mood = patch.mood end
    return out
end

local function setCrowd(patch)
    GlobalState.mzbCrowd = sanitize(patch, current())
    return true
end

-- (server/lights.lua: a light preset that carries a mood - the house reacts with the lights)
function MzbCrowdMood(mood)
    if Config.CrowdPresetMoods ~= false and current().mood ~= mood then setCrowd({ mood = mood }) end
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    local cur = GlobalState.mzbCrowd
    if type(cur) ~= 'table' or not Config.CrowdMoods[cur.mood] then
        GlobalState.mzbCrowd = copy(Config.CrowdDefault)
    end
end)

local function allowed(src)
    return src == 0 or not Config.CrowdAccess or IsPlayerAceAllowed(tostring(src), Config.CrowdAccess)
end

local function reply(src, msg)
    if src == 0 then
        print('[mzb_arena] ' .. msg)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'crowd', msg } })
    end
end

-- the desk sends a patch per touch; a player may not flood it
local last = {}
local function throttled(src)
    local now = GetGameTimer()
    if now - (last[src] or -100000) < 200 then return true end
    last[src] = now
    return false
end

AddEventHandler('playerDropped', function() last[source] = nil end)

RegisterNetEvent('mzb_arena:crowd', function(patch)
    local src = source
    if not allowed(src) or throttled(src) then return end
    setCrowd(patch)
end)

local function moodNames()
    local names = {}
    for _, k in ipairs(Config.CrowdMoodOrder or {}) do
        if Config.CrowdMoods[k] then names[#names + 1] = k end
    end
    return names
end

local function status(src)
    local c = current()
    reply(src, ('the crowd is %s | mood %s | staff %s | litter %s'):format(c.on and 'IN' or 'out', tostring(c.mood),
        Config.CrowdStaffEnabled == false and 'none' or c.staff ~= false and 'on' or 'off', c.litter or 'clean'))
end

RegisterCommand(Config.CrowdCommand, function(src, args)
    local sub = args[1] and args[1]:lower()
    -- your own count is yours to set: no permission needed, nothing synced
    if sub == 'mine' then
        if src == 0 then return reply(src, 'mine is a player setting (run it in game)') end
        local n = tonumber(args[2])
        if args[2] and not n then
            return reply(src, ('/%s mine <0-%d>'):format(Config.CrowdCommand, Config.Crowd.MaxPedsLimit or 220))
        end
        return TriggerClientEvent('mzb_arena:crowdMine', src, n)
    end
    if not sub or sub == 'status' then
        status(src)
        if src ~= 0 then TriggerClientEvent('mzb_arena:crowdMine', src) end
        return
    end
    if not allowed(src) then return reply(src, 'you are not allowed to run the arena crowd') end
    if sub == 'on' or sub == 'in' then setCrowd({ on = true })
    elseif sub == 'off' or sub == 'out' then setCrowd({ on = false })
    elseif sub == 'toggle' then setCrowd({ on = not current().on })
    elseif sub == 'mood' and args[2] and Config.CrowdMoods[args[2]:lower()] then setCrowd({ mood = args[2]:lower() })
    elseif sub == 'staff' and (args[2] == 'on' or args[2] == 'off' or args[2] == 'toggle') then
        setCrowd({ staff = args[2] == 'on' or (args[2] == 'toggle' and current().staff == false) })
    elseif sub == 'litter' and LITTER[(args[2] or ''):lower()] then setCrowd({ litter = args[2]:lower() })
    else
        return reply(src, ('/%s on | off | toggle | mood <%s> | staff <on|off|toggle> | litter <clean|some|trashed> | ' ..
                           'status | mine <0-%d>')
            :format(Config.CrowdCommand, table.concat(moodNames(), '|'), Config.Crowd.MaxPedsLimit or 220))
    end
    status(src)
end, false)

-- other resources (a match script, an event timer, a job's control panel) can run the crowd too
exports('SetCrowd', function(patch) return setCrowd(patch) end)
exports('GetCrowd', function() return copy(current()) end)
