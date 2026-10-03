-- mzb_arena - client: media on the video screens (GlobalState.mzbMedia, server/media.lua).
-- A hidden browser (a DUI) shows html/screen.html - a YouTube player, pictures, or a look it draws itself in step with
-- the light desk - and its picture goes onto every screen of the show's screen model (Config.Screens, client/main.lua
-- spawns it): by swapping the screens' texture for the browser's (Config.Media.method 'replace', the default), or by
-- drawing onto their named render target every frame ('rendertarget'). Only while something of ours is on and the
-- player is in the building: otherwise the swap / the render target is let go and the browser destroyed, so another
-- media script can have the screens. The page is loaded from https://cfx-nui-<resource>/ so YouTube sees a web origin.
-- The browser's sound is not positional: its volume follows where the listener is (client/listener.lua).
-- /arenascreeninfo says what the player is doing on your side (chat and F8).

local M = Config.Media or {}
local S = GlobalState.mzbMedia or { kind = 'off' }
local RT = Config.Screens and Config.Screens.renderTarget or 'mzb_screens'
local TXD = 'mzb_media'

local dui, txn, txd = nil, nil, nil
local texCount = 0
local ownTarget = false              -- we registered the render target (so it is ours to release)
local replaced = false               -- the screens' texture is swapped for the browser's
local pageReady = false              -- the page said it is listening (html/screen.js: screenReady)
local sentRev = nil                  -- the item the browser has
local METHOD = M.method or 'replace'
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

local function destroy()
    releaseTarget()
    unreplace()
    if dui then DestroyDui(dui) end
    dui, txn, sentRev, pageReady = nil, nil, nil, false
end

-- the browser and its texture. Each new browser gets a texture of its own name: a runtime texture is bound to the
-- browser it was made from, and the dictionary is made once.
local function create()
    if METHOD == 'replace' then RequestStreamedTextureDict(M.replaceTxd or 'mzb_tx_show', false) end
    dui = CreateDui(PAGE, M.width or 1280, M.height or 720)
    local deadline = GetGameTimer() + 5000
    while not IsDuiAvailable(dui) and GetGameTimer() < deadline do Wait(50) end
    if not txd then txd = CreateRuntimeTxd(TXD) end
    texCount = texCount + 1
    txn = 'mzb_media_' .. texCount
    CreateRuntimeTextureFromDuiHandle(txd, txn, GetDuiHandle(dui))
    sentRev = nil
end

-- the sound's level: the desk's volume, and the listener's place (full in the bowl, low next door, nothing outside)
local function level()
    local v = (S.volume or 0) / 100.0 * (M.volume or 0.6) * (MzbListener and MzbListener.level or 0.0)
    return math.floor(v * 100 + 0.5) / 100
end

-- a look needs the light desk's state and the show (its artwork, its title): sent with the item and when they change
local function lookInfo()
    local show = GlobalState.mzbShow or Config.DefaultShow
    return { type = 'lights', lights = GlobalState.mzbLights or Config.LightDefault, now = GetNetworkTime(), show = show,
             backdrop = (M.backdrops or {})[show], logo = (M.logos or {})[show], title = (M.titles or {})[show] }
end

-- hand the browser the item and where it should be now (on the server's clock: client/listener.lua)
local function sync(full)
    if not dui then return end
    local pos = MzbTrackPos(S)
    if full then
        post(lookInfo())
        post({ type = 'load', media = S, pos = pos })
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
    -- a new item is loaded by the thread below (it sees the new rev); pause / resume / interval go to the browser
    -- now, and the position is checked again
    if dui and on() and S.rev == (before and before.rev) then
        post({ type = 'state', media = S })
        needSync = true
    end
    SendNUIMessage({ type = 'media', media = S })                -- the desk's Screens section (html/media.js)
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
    local lastSet = 0
    while METHOD == 'replace' do
        if dui and txn and MzbListener and MzbListener.inArena then
            if not replaced or GetGameTimer() - lastSet > 5000 then
                AddReplaceTexture(M.replaceTxd or 'mzb_tx_show', M.replaceTex or 'script_rt_mzb_screens', TXD, txn)
                replaced, lastSet = true, GetGameTimer()
            end
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
        local model = Config.Screens.models[show]
        if METHOD == 'rendertarget' and dui and txn and model and MzbListener and MzbListener.inArena then
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
            DrawSprite(TXD, txn, 0.5, 0.5, 1.0, 1.0, 0.0, 255, 255, 255, 255)
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

RegisterCommand('arenascreeninfo', function()
    local msg = ('screens: %s | browser %s | page %s | %s | method %s | in the arena %s | %s'):format(
        S.kind == 'look' and ('look ' .. tostring(S.look)) or tostring(S.kind),
        dui and (IsDuiAvailable(dui) and 'up' or 'made, not up') or 'none', pageReady and 'listening' or 'not heard from',
        txn and ('texture ' .. txn) or 'no texture', METHOD, tostring(MzbListener and MzbListener.inArena),
        METHOD == 'replace' and ('swap ' .. (replaced and 'ON' or 'off')) or ('render target ' ..
            (IsNamedRendertargetRegistered(RT) and 'registered' or 'not registered')))
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
    SendNUIMessage({ type = 'media', media = S, enabled = M.enabled == true, sets = setNames(), looks = M.looks or {} })
end)

RegisterNUICallback('media', function(data, cb)
    if type(data) == 'table' then TriggerServerEvent('mzb_arena:media', data) end
    cb('ok')
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
        { { name = 'what', help = 'youtube url | picture url(s) | images [set] | off | pause | resume | volume <0-100> | interval <s> | status' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then destroy() end
end)

-- other resources: is the built-in player on the screens right now (so a media script can stay off them)
exports('IsScreenMediaOn', function() return on() == true end)
