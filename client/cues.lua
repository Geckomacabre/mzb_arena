-- mzb_arena - client: the desk's cue lists (1.5.0, server/cues.lua). The desk's Cues tab gets the show's list when the
-- desk opens and again when a list is edited or the show changes while it is open; its edits, GO and Auto next go to
-- the server, which checks them.
local CQ = Config.Cues or {}

local function words(kind)
    local k = CQ.kinds or {}
    return k[kind] or k.default or {}
end

-- what a cue can bring: every light look, and the show's pyro cues
local function choices()
    local presets = {}
    for _, k in ipairs(Config.LightPresetOrder or {}) do
        local p = (Config.LightPresets or {})[k]
        if p then presets[#presets + 1] = { id = k, label = p.label or k } end
    end
    local pyro, PY = {}, Config.Pyro or {}
    for _, k in ipairs(PY.order or {}) do
        local c = (PY.cues or {})[k]
        if c then pyro[#pyro + 1] = { id = k, label = c.label or k } end
    end
    return presets, pyro
end

RegisterNetEvent('mzb_arena:cues', function(data)
    if type(data) ~= 'table' then return end
    local presets, pyro = choices()
    SendNUIMessage({ type = 'cues', kind = data.kind, list = data.list or {}, words = words(data.kind),
                     state = GlobalState.mzbCues, presets = presets, pyro = pyro })
end)

-- the desk opens: the show's list
AddEventHandler('mzb_arena:lightsDesk', function()
    TriggerServerEvent('mzb_arena:cuesGet')
end)

-- where the list is, and the list itself when it was edited or the show changed
local lastRev, lastKind = nil, nil
AddStateBagChangeHandler('mzbCues', 'global', function(_, _, value)
    if type(value) ~= 'table' then return end
    SendNUIMessage({ type = 'cuesState', state = value })
    if MzbDeskOpen and MzbDeskOpen() and (value.rev ~= lastRev or value.kind ~= lastKind) then
        TriggerServerEvent('mzb_arena:cuesGet')
    end
    lastRev, lastKind = value.rev, value.kind
end)

RegisterNUICallback('cues', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    if data.action == 'save' and type(data.list) == 'table' then
        TriggerServerEvent('mzb_arena:cuesSave', data.list)
    elseif data.action == 'go' then
        TriggerServerEvent('mzb_arena:cuesGo', (data.how == 'back' and 'back') or tonumber(data.how) or 'next')
    elseif data.action == 'auto' then
        TriggerServerEvent('mzb_arena:cuesAuto', data.on == true)
    end
end)
