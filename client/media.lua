-- mzb_arena - client: media on the video screens (GlobalState.mzbMedia, server/media.lua).
-- A hidden browser (a DUI) shows html/screen.html - a YouTube player, pictures, or a look it draws itself in step with
-- the light desk - and its picture goes onto every screen of the show's screen model (Config.Screens, client/main.lua
-- spawns it): by swapping the screens' texture for the browser's (Config.Media.method 'replace', the default), or by
-- drawing onto their named render target every frame ('rendertarget'). Only while something of ours is on and the
-- player is in the building: otherwise the swap / the render target is let go and the browser destroyed, so another
-- media script can have the screens. Off and dark (the desk's Off: S.black) needs no browser: a black texture goes
-- over the show's own graphics. The page is loaded from https://cfx-nui-<resource>/ so YouTube sees a web origin.
-- The browser's sound is not positional: its volume follows where the listener is (client/listener.lua).
-- A camera feed (S.kind 'feed': /arenascreen look) is another player's view of the game: that player's own page
-- (html/feed.js, in the NUI page that is always loaded) takes the game's picture and sends it to the screens' page
-- of every player near the arena, PC to PC; this script passes the two pages' handshake to the server and back, and
-- tells the page of the player who is the camera to start and stop.
-- /arenascreeninfo says what the player is doing on your side (chat and F8).

local M = Config.Media or {}
local S = GlobalState.mzbMedia or { kind = 'off' }
local RT = Config.Screens and Config.Screens.renderTarget or 'mzb_screens'
local TXD = 'mzb_media'

local dui, txn, txd = nil, nil, nil
local texCount = 0
local ownTarget = false              -- we registered the render target (so it is ours to release)
local replaced = false               -- the texture the screens' own is swapped for (the browser's or the black one)
local lastSet = 0                    -- when it was last swapped in
local blackName = nil                -- the black texture, once made
local pageReady = false              -- the page said it is listening (html/screen.js: screenReady)
local sentRev = nil                  -- the item the browser has
local METHOD = M.method or 'replace'
local FD = M.feed or {}
local function me() return GetPlayerServerId(PlayerId()) end
local watching = nil                 -- the feed this player's screens asked the camera for (its rev)
local camera                         -- (this player's page starts / stops being the camera: defined below)
local PAGE = M.pageUrl or ('https://cfx-nui-%s/html/screen.html'):format(GetCurrentResourceName())

local function on() return M.enabled and S and S.kind and S.kind ~= 'off' end

local function near()
    return #(GetEntityCoords(PlayerPedId()) - Config.Screens.origin) < (M.range or 160.0)
end

local function post(msg)
    if dui then SendDuiMessage(dui, json.encode(msg)) end
end

local function releaseTarget()
    if ownTarget and IsNamedRendertargetRegistered(RT) then ReleaseNamedRendertarget(RT) end
    ownTarget = false
end

local function unreplace()
    if replaced then
        RemoveReplaceTexture(M.replaceTxd or 'mzb_tx_show', M.replaceTex or 'script_rt_mzb_screens')
        SetStreamedTextureDictAsNoLongerNeeded(M.replaceTxd or 'mzb_tx_show')
    end
    replaced = false
end

local function swap(name)
    if not replaced then RequestStreamedTextureDict(M.replaceTxd or 'mzb_tx_show', false) end
    AddReplaceTexture(M.replaceTxd or 'mzb_tx_show', M.replaceTex or 'script_rt_mzb_screens', TXD, name)
    replaced, lastSet = name, GetGameTimer()
end

-- off and dark (the desk's Off, /arenascreen off, a blackout: S.black): the screens are black over the show's own
-- graphics while the player is in the arena - unless another script has taken the screens' render target
local function blackTexture()
    if not blackName then
        if not txd then txd = CreateRuntimeTxd(TXD) end
        local t = CreateRuntimeTexture(txd, 'mzb_media_black', 4, 4)
        for x = 0, 3 do
            for y = 0, 3 do SetRuntimeTexturePixel(t, x, y, 0, 0, 0, 255) end
        end
        CommitRuntimeTexture(t)
        blackName = 'mzb_media_black'
    end
    return blackName
end

local function dark()
    return M.enabled and M.offBlack ~= false and S and S.kind == 'off' and S.black == true
        and MzbListener and MzbListener.inArena and (ownTarget or not IsNamedRendertargetRegistered(RT))
end

local function destroy()
    if METHOD == 'replace' and dark() then swap(blackTexture()) else unreplace() end   -- (no flash of the graphics between)
    if METHOD ~= 'rendertarget' or not dark() then releaseTarget() end
    -- these screens were showing a camera feed that is still on (the player walked off): its camera is told
    if watching and S.kind == 'feed' and S.rev == watching then
        TriggerServerEvent('mzb_arena:feedSignal', watching, 'view', 0, { t = 'bye' })
    end
    watching = nil
    if dui then DestroyDui(dui) end
    dui, txn, sentRev, pageReady = nil, nil, nil, false
end

-- the browser and its texture. Each new browser gets a texture of its own name: a runtime texture is bound to the
-- browser it was made from, and the dictionary is made once.
local function create()
    dui = CreateDui(PAGE, M.width or 1280, M.height or 720)
    local deadline = GetGameTimer() + 5000
    while not IsDuiAvailable(dui) and GetGameTimer() < deadline do Wait(50) end
    if not txd then txd = CreateRuntimeTxd(TXD) end
    texCount = texCount + 1
    txn = 'mzb_media_' .. texCount
    CreateRuntimeTextureFromDuiHandle(txd, txn, GetDuiHandle(dui))
    sentRev = nil
end

-- the browser's own sound: none unless Config.Media.sound = 'screen' (a video's sound comes from the arena's speakers
-- through the music player, or not at all). With 'screen': the desk's volume, and the listener's place (full in the
-- bowl, low next door, nothing outside)
local function level()
    if (M.sound or 'speakers') ~= 'screen' then return 0.0 end
    local v = (S.volume or 0) / 100.0 * (M.volume or 0.6) * (MzbListener and MzbListener.level or 0.0)
    return math.floor(v * 100 + 0.5) / 100
end

-- a look needs the light desk's state and the show (its artwork, its title): sent with the item and when they change.
-- A show without artwork of its own (the big-floor shows) has the empty house's, and its title
local function lookInfo()
    local show = GlobalState.mzbShow or Config.DefaultShow
    return { type = 'lights', lights = GlobalState.mzbLights or Config.LightDefault, now = GetNetworkTime(), show = show,
             backdrop = MzbShowEntry(M.backdrops, show), logo = (M.logos or {})[show], title = MzbShowEntry(M.titles, show) }
end

-- hand the browser the item and where it should be now (on the server's clock: client/listener.lua)
local function sync(full)
    if not dui then return end
    local pos = MzbTrackPos(S, S.kind == 'youtube')              -- (a video is told when its start is still to come)
    if full then
        post(lookInfo())
        local feed = nil
        if S.kind == 'feed' then
            feed, watching = { ice = FD.ice or {}, relayOnly = FD.relayOnly == true }, S.rev
        end
        post({ type = 'load', media = S, pos = pos, fade = MzbFadeLeft(S), feed = feed })
        post({ type = 'volume', volume = level() })              -- with it: a page that missed the first one is silent
        sentRev = S.rev
    else
        post({ type = 'sync', pos = pos, paused = S.paused == true })
    end
end

local needSync = false
AddStateBagChangeHandler('mzbMedia', 'global', function(_, _, value)
    local before = S
    S = value or { kind = 'off' }
    -- a new item is loaded by the thread below (it sees the new rev); pause / resume / interval / loop go to the
    -- browser now, and the position is checked again. A looped video that starts again (S.loops) comes with where
    -- it is - before its new start - so the page goes back to its beginning and holds there, dark, until then
    if dui and on() and S.rev == (before and before.rev) then
        local again = S.kind == 'youtube' and S.loops ~= (before and before.loops)
        post({ type = 'state', media = S, pos = again and MzbTrackPos(S, true) or nil, fade = MzbFadeLeft(S) })
        needSync = true
    end
    SendNUIMessage({ type = 'media', media = S })                -- the desk's Screens section (html/media.js)
    camera()
end)

-- the browser exists while ours is on and the player is near; every so often it is told where it should be. A new
-- item is sent three more times over the next seconds: the browser can be up before its page listens, and a message
-- sent then is lost (the page takes the same item again as a position check, nothing more).
CreateThread(function()
    local lastSync, again, againAt = 0, 0, 0
    while true do
        if on() and near() then
            if not dui then create() end
            local now = GetGameTimer()
            if dui and sentRev ~= S.rev and IsDuiAvailable(dui) then
                sync(true)
                lastSync, again, againAt = now, 3, now + 1500
            elseif dui and again > 0 and now >= againAt then
                sync(true)
                lastSync, again, againAt = now, again - 1, now + 2000
            elseif dui and (needSync or (S.kind ~= 'image' and not S.paused
                and now - lastSync > (M.resync or 30) * 1000)) then
                needSync = false
                sync(false)
                lastSync = now
            end
        elseif dui then
            destroy()
        end
        Wait(500)
    end
end)

-- the sound: the desk's volume, the listener's place (full in the bowl, low next door, nothing outside)
CreateThread(function()
    local lastVol = -1
    while true do
        if dui then
            local v = level()
            if v ~= lastVol then
                post({ type = 'volume', volume = v })
                lastVol = v
            end
        else
            lastVol = -1
        end
        Wait(250)
    end
end)

-- the looks follow the lights: the desk's state goes to the page as it changes, and every few seconds (a page that
-- missed one, a show switched)
AddStateBagChangeHandler('mzbLights', 'global', function()
    if dui and S.kind == 'look' then post(lookInfo()) end
end)

CreateThread(function()
    while true do
        if dui and S.kind == 'look' then post(lookInfo()) end
        Wait(3000)
    end
end)

-- the picture, the 'replace' way: the screens' texture is swapped for the browser's while the player is in the
-- building (and set again now and then: the screens' model may have streamed in after the first swap)
CreateThread(function()
    while METHOD == 'replace' do
        local want = nil
        if dui and txn and MzbListener and MzbListener.inArena then
            want = txn
        elseif dark() or (replaced and replaced == blackName and on() and MzbListener and MzbListener.inArena) then
            want = blackTexture()                                -- dark, and dark still while the next item's browser comes up
        end
        if want then
            if replaced ~= want or GetGameTimer() - lastSet > 5000 then swap(want) end
        elseif replaced then
            unreplace()
        end
        Wait(500)
    end
end)

-- the picture, the 'rendertarget' way: every frame onto the screens' render target, while the player can see a screen
CreateThread(function()
    while true do
        local show = GlobalState.mzbShow or Config.DefaultShow
        local model = MzbShowEntry(Config.Screens.models, show)        -- (the empty house's board, for a show without one)
        local black = METHOD == 'rendertarget' and not dui and model and dark()
        if METHOD == 'rendertarget' and model and MzbListener and MzbListener.inArena and ((dui and txn) or black) then
            if not IsNamedRendertargetRegistered(RT) then
                RegisterNamedRendertarget(RT, false)
                ownTarget = true
            end
            local h = GetHashKey(model)
            if not IsNamedRendertargetLinked(h) then LinkNamedRendertarget(h) end
            local id = GetNamedRendertargetRenderId(RT)
            SetTextRenderId(id)
            SetScriptGfxDrawOrder(4)
            SetScriptGfxDrawBehindPausemenu(true)
            if black then DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 255)
            else DrawSprite(TXD, txn, 0.5, 0.5, 1.0, 1.0, 0.0, 255, 255, 255, 255) end
            SetTextRenderId(GetDefaultScriptRendertargetRenderId())
            Wait(0)
        else
            if ownTarget and not dui then releaseTarget() end
            Wait(300)
        end
    end
end)

-- the page is listening (it loads a moment after the browser is made): whatever was sent before is sent again
RegisterNUICallback('screenReady', function(_, cb)
    cb('ok')
    pageReady = true
    sentRev = nil
end)

-- ------------------------------------------------------------------ a camera feed (S.kind 'feed')
local camRev = nil                   -- the feed this player's own page is the camera of
local camState = nil                 -- what that page says it is doing (html/feed.js: feedState)

local function isCam()
    return M.enabled and FD.enabled ~= false and S.kind == 'feed' and S.cam == me()
end

-- this player's page starts or stops being the camera, as the state says
function camera()
    if isCam() then
        if camRev ~= S.rev then
            camRev, camState = S.rev, nil
            SendNUIMessage({ type = 'feed', action = 'start', rev = S.rev, command = M.command or 'arenascreen',
                             config = { ice = FD.ice or {}, relayOnly = FD.relayOnly == true, width = FD.width or 640,
                                        fps = FD.fps or 24, bitrate = FD.bitrate or 700, flip = FD.flip == true } })
        end
    elseif camRev then
        camRev, camState = nil, nil
        SendNUIMessage({ type = 'feed', action = 'stop' })
    end
end

CreateThread(function()
    while true do
        camera()
        Wait(1000)
    end
end)

-- the camera's own radar and HUD are in the picture the page takes: hidden while it is live
CreateThread(function()
    while true do
        if camRev and FD.hideHud ~= false then
            HideHudAndRadarThisFrame()
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- the camera's page is (again) there: it is told again
RegisterNUICallback('feedReady', function(_, cb)
    cb('ok')
    camRev = nil
end)

RegisterNUICallback('feedState', function(data, cb)
    cb('ok')
    if type(data) == 'table' and data.rev == camRev then camState = data end
end)

-- the handshake between the camera's page and a watcher's screens: either page hands its part to this script, the
-- server passes it on (and checks it), and it comes back here for the other page
RegisterNUICallback('feedSignal', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or S.kind ~= 'feed' or data.rev ~= S.rev or type(data.msg) ~= 'table' then return end
    TriggerServerEvent('mzb_arena:feedSignal', data.rev, data.role, tonumber(data.to) or 0, data.msg)   -- (to: the camera's page names its watcher)
end)

RegisterNetEvent('mzb_arena:feedSignal', function(rev, role, from, msg)
    if S.kind ~= 'feed' or rev ~= S.rev or type(msg) ~= 'table' then return end
    if role == 'cam' then
        post({ type = 'feed', msg = msg })                               -- from the camera, for this player's screens
    elseif role == 'view' and camRev == rev then
        SendNUIMessage({ type = 'feed', action = 'signal', from = from, msg = msg })   -- from a watcher, for the camera
    end
end)

local function feedLine()
    if S.kind ~= 'feed' then return '' end
    if camRev ~= S.rev then return (' | camera: %s'):format(tostring(S.camName)) end
    local st = camState
    if not st then return ' | you are the camera: the page has not answered yet' end
    return (' | you are the camera: %s, %dx%d, %d of %d screens connected'):format(
        st.capturing and 'taking the picture' or ('NOT taking the picture' .. (st.error and (' - ' .. tostring(st.error):sub(1, 80)) or '')),
        tonumber(st.width) or 0, tonumber(st.height) or 0, tonumber(st.connected) or 0, tonumber(st.viewers) or 0)
end

RegisterCommand('arenascreeninfo', function()
    local msg = ('screens: %s | browser %s | page %s | %s | method %s | in the arena %s | %s'):format(
        S.kind == 'look' and ('look ' .. tostring(S.look)) or (S.kind == 'off' and S.black and 'off (dark)') or tostring(S.kind),
        dui and (IsDuiAvailable(dui) and 'up' or 'made, not up') or 'none', pageReady and 'listening' or 'not heard from',
        txn and ('texture ' .. txn) or 'no texture', METHOD, tostring(MzbListener and MzbListener.inArena),
        METHOD == 'replace' and ('swap ' .. (replaced and (replaced == blackName and 'ON (black)' or 'ON') or 'off')) or ('render target ' ..
            (IsNamedRendertargetRegistered(RT) and 'registered' or 'not registered'))) .. feedLine()
    print('[mzb_arena] ' .. msg .. ' | ' .. PAGE)
    TriggerEvent('chat:addMessage', { args = { 'screens', msg } })
end, false)

-- ------------------------------------------------------------------ the desk's Screens section (html/media.js)
local function setNames()
    local names = {}
    for k in pairs(M.imageSets or {}) do names[#names + 1] = k end
    table.sort(names)
    return names
end

AddEventHandler('mzb_arena:lightsDesk', function()
    SendNUIMessage({ type = 'media', media = S, enabled = M.enabled == true, sets = setNames(), looks = M.looks or {},
                     feed = FD.enabled ~= false })
end)

RegisterNUICallback('media', function(data, cb)
    if type(data) == 'table' then TriggerServerEvent('mzb_arena:media', data) end
    cb('ok')
end)

-- a video's length, as the screens' page learns it: the server switches the screens off when it is over
-- (server/media.lua believes whoever put the video on, or staff). The one who put it on says so at once, the others
-- only if nobody has after a moment
RegisterNUICallback('screenLength', function(data, cb)
    cb('ok')
    local rev, len = type(data) == 'table' and data.rev, type(data) == 'table' and tonumber(data.len)
    if not len or rev ~= S.rev or S.kind ~= 'youtube' or S.len then return end
    if S.by == me() then return TriggerServerEvent('mzb_arena:mediaLength', rev, len) end
    SetTimeout(1500 + math.random(0, 2500), function()
        if S.rev == rev and S.kind == 'youtube' and not S.len then TriggerServerEvent('mzb_arena:mediaLength', rev, len) end
    end)
end)

-- the screens' page could not play the item (html/screen.js): the one who put it on is told, once per item -
-- everyone else just sees the screens stay dark
local told = nil
RegisterNUICallback('screenError', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or data.rev ~= S.rev or told == S.rev then return end
    told = S.rev
    if S.by == GetPlayerServerId(PlayerId()) then
        TriggerEvent('chat:addMessage', { args = { 'screens', 'that will not play: ' .. tostring(data.msg or '?'):sub(1, 120) } })
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. (M.command or 'arenascreen'), 'Maze Bank Arena: media on the video screens (staff)',
        { { name = 'what', help = 'youtube url | picture url(s) | images [set] | look (your view, live) | look <player id> | look off | look <name> | off (dark) | own (the show\'s graphics) | fade [seconds] | pause | resume | loop [on|off] (a video) | volume <0-100> | interval <s> | status' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    destroy()
    if camRev then SendNUIMessage({ type = 'feed', action = 'stop' }) end
end)

-- other resources: is the built-in player on the screens right now (so a media script can stay off them)
exports('IsScreenMediaOn', function() return on() == true end)
