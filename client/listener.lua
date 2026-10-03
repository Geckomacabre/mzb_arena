-- mzb_arena - client: where the listener is, and the server's clock. Shared by the screens' video (client/media.lua)
-- and the music player (client/music.lua).
-- MzbListener.zone is one of bowl / near / building / outside (Config.Listener), refreshed a few times a second from the
-- room the game has the player in. MzbServerNow() is the server's GetGameTimer() as seen from here: the media and the
-- music keep their positions on the server's clock (the server has no network clock of its own), so every player,
-- late joiners too, lands on the same moment.

MzbListener = { zone = 'outside', room = nil, inArena = false, level = 0.0 }

local zoneOf = {}                                         -- room hash -> bowl / near
zoneOf[GetHashKey('bowl')] = 'bowl'
for name in pairs((Config.Listener and Config.Listener.near) or {}) do zoneOf[GetHashKey(name)] = 'near' end
local roomName = {}
for _, r in ipairs(Config.Rooms or {}) do roomName[GetHashKey(r)] = r end

local function arenaId()
    local p = Config.InteriorProbe
    return GetInteriorAtCoords(p.x, p.y, p.z)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local id = arenaId()
        local zone, room = 'outside', nil
        if id ~= 0 and GetInteriorFromEntity(ped) == id then
            local key = GetRoomKeyFromEntity(ped)
            room = roomName[key]
            zone = zoneOf[key] or 'building'
        end
        MzbListener.zone, MzbListener.room, MzbListener.inArena = zone, room, zone ~= 'outside'
        MzbListener.level = ((Config.Listener and Config.Listener.level) or {})[zone] or 0.0
        Wait(250)
    end
end)

-- ------------------------------------------------------------------ the server's clock
-- A round trip to the server: the answer is taken as the server's time half way through it. Three in a row, and
-- the shortest trip wins (the least queueing, so the best guess). Again every Config.ClockResync seconds.
local offset = nil                                        -- server ms - our GetGameTimer()
local pending = {}
local seq = 0

RegisterNetEvent('mzb_arena:clock', function(n, serverMs)
    local sent = pending[n]
    if not sent or type(serverMs) ~= 'number' then return end
    pending[n] = nil
    local now = GetGameTimer()
    local rtt = now - sent.t
    if not sent.round.best or rtt < sent.round.best.rtt then
        sent.round.best = { rtt = rtt, off = serverMs + rtt / 2 - now }
    end
end)

local function measure()
    local round = {}
    for _ = 1, 3 do
        seq = seq + 1
        pending[seq] = { t = GetGameTimer(), round = round }
        TriggerServerEvent('mzb_arena:clock', seq)
        Wait(300)
    end
    Wait(700)
    pending = {}
    if round.best then offset = round.best.off end
end

-- the round trips run on their own thread; the first answer is waited for by whoever asks first (up to 3 s)
local measuring = false
local function startMeasure()
    if measuring then return end
    measuring = true
    CreateThread(function()
        measure()
        measuring = false
    end)
end

-- only while something runs on the clock (a video, a track): an idle arena asks the server nothing
local function clockNeeded()
    local m, mu = GlobalState.mzbMedia, GlobalState.mzbMusic
    return (m ~= nil and m.kind ~= nil and m.kind ~= 'off') or (mu ~= nil and mu.kind ~= nil and mu.kind ~= 'off')
end

CreateThread(function()
    while true do
        if clockNeeded() then
            startMeasure()
            Wait(math.max(10, Config.ClockResync or 60) * 1000)
        else
            Wait(2000)
        end
    end
end)

function MzbServerNow()
    if not offset then
        startMeasure()                                    -- the first one to ask starts the check
        local deadline = GetGameTimer() + 3000
        while not offset and GetGameTimer() < deadline do Wait(50) end
    end
    return GetGameTimer() + (offset or 0)
end

function MzbClockReady() return offset ~= nil end

-- a position (s) on a track / video kept on the server's clock: { start = server ms at position 0, paused, at }
function MzbTrackPos(s)
    if type(s) ~= 'table' then return 0.0 end
    if s.paused then return tonumber(s.at) or 0.0 end
    return math.max(0.0, (MzbServerNow() - (tonumber(s.start) or 0)) / 1000.0)
end
