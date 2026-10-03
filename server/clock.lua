-- mzb_arena - server: the clock the screens' video and the music player keep their positions on (client/listener.lua)
-- The server has no network clock, so a client asks for GetGameTimer() and times the round trip itself.

local last = {}

RegisterNetEvent('mzb_arena:clock', function(n)
    local src = source
    if type(n) ~= 'number' or n ~= n or n < 0 or n > 2 ^ 31 then return end
    local now = GetGameTimer()
    -- a check is three asks 300 ms apart; anything much faster is not a clock check
    if now - (last[src] or -100000) < 150 then return end
    last[src] = now
    TriggerClientEvent('mzb_arena:clock', src, math.floor(n), now)
end)

AddEventHandler('playerDropped', function() last[source] = nil end)

-- a position kept on this clock: { start = ms at position 0, paused, at = the position while paused }
function MzbTrackPos(s)
    if type(s) ~= 'table' then return 0.0 end
    if s.paused then return tonumber(s.at) or 0.0 end
    return math.max(0.0, (GetGameTimer() - (tonumber(s.start) or 0)) / 1000.0)
end

-- who may run the screens / music: their own ACE setting, or the light desk's
function MzbAllowed(src, access)
    if access == nil then access = Config.LightAccess end
    return src == 0 or not access or IsPlayerAceAllowed(tostring(src), access)
end

-- one throttle table per feature: true when src asked less than ms ago
function MzbThrottle(ms)
    local t = {}
    AddEventHandler('playerDropped', function() t[source] = nil end)
    return function(src)
        local now = GetGameTimer()
        if now - (t[src] or -100000) < ms then return true end
        t[src] = now
        return false
    end
end

function MzbReply(src, tag, msg)
    if src == 0 then
        print('[mzb_arena] ' .. msg)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { tag, msg } })
    end
end
