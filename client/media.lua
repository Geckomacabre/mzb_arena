-- mzb_arena - client: media on the video screens (GlobalState.mzbMedia, server/media.lua).
-- A hidden browser (a DUI) shows html/screen.html - a YouTube player, or pictures - and its picture is drawn every
-- frame onto the named render target of the show's screen model (Config.Screens, client/main.lua spawns it), so every
-- screen of the show plays it. Only while something of ours is on and the player is in the building: otherwise the
-- render target is released and the browser destroyed, so another media script can have the screens.
-- The browser's sound is not positional: its volume follows where the listener is (client/listener.lua).

local M = Config.Media or {}
local S = GlobalState.mzbMedia or { kind = 'off' }
local RT = Config.Screens and Config.Screens.renderTarget or 'mzb_screens'
local TXD = 'mzb_media'

local dui, txn, txd = nil, nil, nil
local texCount = 0
local ownTarget = false              -- we registered the render target (so it is ours to release)
local sentRev = nil                  -- the item the browser has

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

local function destroy()
    releaseTarget()
    if dui then DestroyDui(dui) end
    dui, txn, sentRev = nil, nil, nil
end

-- the browser and its texture. Each new browser gets a texture of its own name: a runtime texture is bound to the
-- browser it was made from, and the dictionary is made once.
local function create()
    local url = ('nui://%s/html/screen.html'):format(GetCurrentResourceName())
    dui = CreateDui(url, M.width or 1280, M.height or 720)
    local deadline = GetGameTimer() + 5000
    while not IsDuiAvailable(dui) and GetGameTimer() < deadline do Wait(50) end
    if not txd then txd = CreateRuntimeTxd(TXD) end
    texCount = texCount + 1
    txn = 'mzb_media_' .. texCount
    CreateRuntimeTextureFromDuiHandle(txd, txn, GetDuiHandle(dui))
    sentRev = nil
end

-- hand the browser the item and where it should be now (on the server's clock: client/listener.lua)
local function sync(full)
    if not dui then return end
    local pos = MzbTrackPos(S)
    if full then
        post({ type = 'load', media = S, pos = pos })
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

-- the browser exists while ours is on and the player is near; every so often it is told where it should be
CreateThread(function()
    local lastSync = 0
    while true do
        if on() and near() then
            if not dui then create() end
            local now = GetGameTimer()
            if dui and sentRev ~= S.rev and IsDuiAvailable(dui) then
                sync(true)
                lastSync = now
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
            local v = (S.volume or 0) / 100.0 * (M.volume or 0.6) * (MzbListener and MzbListener.level or 0.0)
            v = math.floor(v * 100 + 0.5) / 100
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

-- the picture: every frame onto the screens' render target, while the player can see a screen (in the building)
CreateThread(function()
    while true do
        local show = GlobalState.mzbShow or Config.DefaultShow
        local model = Config.Screens.models[show]
        if dui and txn and model and MzbListener and MzbListener.inArena then
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

-- ------------------------------------------------------------------ the desk's Screens section (html/media.js)
local function setNames()
    local names = {}
    for k in pairs(M.imageSets or {}) do names[#names + 1] = k end
    table.sort(names)
    return names
end

AddEventHandler('mzb_arena:lightsDesk', function()
    SendNUIMessage({ type = 'media', media = S, enabled = M.enabled == true, sets = setNames() })
end)

RegisterNUICallback('media', function(data, cb)
    if type(data) == 'table' then TriggerServerEvent('mzb_arena:media', data) end
    cb('ok')
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
