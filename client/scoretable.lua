-- mzb_arena - client: the basketball floor's scorer's table with the game's real score and its time left (the user,
-- 2026-11-06: "make it a non static image similar to what we did in the stream server so it counts points and shows
-- the time left"). Its picture (gtb_mzb_score_basketball, on the table's face and on the shot clocks over the
-- backboards) is swapped for a hidden browser's (a DUI) showing html/scoretable.html - the same picture with the
-- game's names, score, period and clock on it - while the show is up, the player is near and a game is kept: by
-- gk_basketball (its court's board in GlobalState, Config.ScoreTable.feed) or by any other script through the
-- server's export SetScoreTable (server/scoretable.lua: that one wins while it is set). Otherwise the table keeps its
-- picture and no browser runs.

local T = Config.ScoreTable or {}
local PAGE = ('nui://%s/html/scoretable.html'):format(GetCurrentResourceName())
local TXD = 'mzb_scoretable'
local dui, txd, made = nil, nil, 0
local sent, sentAt = nil, 0

local function mmss(s)
    s = math.max(0, math.floor((tonumber(s) or 0) + 0.5))
    return ('%d:%02d'):format(s // 60, s % 60)
end

local function feedOn()
    local f = T.feed
    return f and f.resource and GetResourceState(f.resource) == 'started'
end

-- what the table says now, or nil (its picture): a script's own over the feed's
function MzbScoreTableBoard()
    local own = GlobalState.mzbScoreTable
    if type(own) == 'table' then return own end
    if not feedOn() then return nil end
    local f = GlobalState[T.feed.bag]
    f = type(f) == 'table' and f or { state = 'lobby' }             -- (no game on the court yet: 0 - 0)
    local period, clock = 'PRE-GAME', ''
    if f.state == 'countdown' then
        period, clock = 'TIP-OFF', mmss(f.countdown)
    elseif f.state == 'live' then
        if f.clock then period, clock = 'TIME', mmss(f.clock)
        elseif (tonumber(f.limit) or 0) > 0 then period = ('FIRST TO %d'):format(f.limit)
        else period = 'LIVE' end
    elseif f.state == 'ended' then
        period = 'FINAL'
    end
    local labels, teams = type(f.labels) == 'table' and f.labels or {}, T.teams or {}
    return { home = teams.home or labels.home or 'Home', away = teams.away or labels.away or 'Away',
             homeScore = f.home or 0, awayScore = f.away or 0, period = period, clock = clock }
end

local function wanted()
    if T.enabled == false or (GlobalState.mzbShow or Config.DefaultShow) ~= (T.show or 'basketball') then return nil end
    local a = Config.ArenaFrame
    if #(GetEntityCoords(PlayerPedId()) - vector3(a.x, a.y, a.z)) > (T.range or 150.0) then return nil end
    return MzbScoreTableBoard()
end

local function make()
    local d = CreateDui(PAGE, T.width or 1024, T.height or 512)
    local giveUp = GetGameTimer() + 5000
    while not IsDuiAvailable(d) and GetGameTimer() < giveUp do Wait(50) end
    if not txd then txd = CreateRuntimeTxd(TXD) end
    made = made + 1                                  -- (a runtime texture is bound to the browser it was made from)
    local name = 'page_' .. made
    CreateRuntimeTextureFromDuiHandle(txd, name, GetDuiHandle(d))
    AddReplaceTexture(T.txd or 'mzb_tx_basketball', T.texture or 'gtb_mzb_score_basketball', TXD, name)
    dui, sent = d, nil
end

local function drop()
    if not dui then return end
    RemoveReplaceTexture(T.txd or 'mzb_tx_basketball', T.texture or 'gtb_mzb_score_basketball')
    DestroyDui(dui)
    dui, sent = nil, nil
end

-- the board to the page: when it changes, and again every few seconds (a message before the page listened is lost)
local function say(b)
    local s = json.encode(b)
    if s ~= sent or GetGameTimer() - sentAt > 3000 then
        SendDuiMessage(dui, s)
        sent, sentAt = s, GetGameTimer()
    end
end

CreateThread(function()
    while true do
        local b = wanted()
        if b and not dui then make() end
        if not b and dui then drop() end
        if b and dui then say(b) end
        Wait(dui and 500 or 2000)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then drop() end
end)
