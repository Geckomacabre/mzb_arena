-- mzb_arena - server: the tees on the merch stand's walls (Config.MerchShop; trying them on: client/shop.lua).
-- What a player owns is kept here: a set of '<style>:<tee>' per licence in the resource's KVP ('mzb_tees:<licence>').
--   mzb_arena:shop:open (style)        -> mzb_arena:shop:state { style, owned = { tee ... }, cash, price }
--   mzb_arena:shop:buy (style, tee)    -> mzb_arena:shop:bought { ok, style, tee, cash } or { ok = false, ..., why }
-- A purchase names a style and a tee and nothing else: the style has to be the show's own, the tee one of its
-- eight, the player a freemode character standing at the stand's walls who does not own it yet; the price is
-- Config.MerchShop's and the money the bridge's (server/bridge.lua). Wearing a tee that is owned, and taking it
-- off, cost nothing and are the player's own game's business.

local SC = Config.MerchShop or {}
if SC.enabled == false then return end

local TEES = type(Config.MerchTees) == 'table' and Config.MerchTees or {}
local MC = Config.Merch or {}
local FREEMODE = { [GetHashKey('mp_m_freemode_01') & 0xFFFFFFFF] = true, [GetHashKey('mp_f_freemode_01') & 0xFFFFFFFF] = true }

local owned = {}                 -- [src] = { key = the KVP's, set = { ['<style>:<tee>'] = true } }, read once per player
local throttled = MzbThrottle(500)

local function styleNow()
    return (MC.styleOf or {})[GlobalState.mzbShow or Config.DefaultShow] or 'arena'
end

local function priceOf(style)
    local p = type(SC.prices) == 'table' and SC.prices[style] or SC.price
    return math.max(0, math.floor(tonumber(p) or 35))
end

-- the player's licence (their Rockstar licence: the same on every visit), or failing that their first identifier
local function identifier(src)
    local id = GetPlayerIdentifierByType(tostring(src), 'license')
    if not id or id == '' then id = GetPlayerIdentifier(tostring(src), 0) end
    return id and id ~= '' and id or nil
end

local function wardrobe(src)
    if owned[src] then return owned[src] end
    local id = identifier(src)
    if not id then return nil end
    local w = { key = 'mzb_tees:' .. id, set = {} }
    local ok, list = pcall(json.decode, GetResourceKvpString(w.key) or '[]')
    for _, k in ipairs(ok and type(list) == 'table' and list or {}) do
        if type(k) == 'string' then w.set[k] = true end
    end
    owned[src] = w
    return w
end

local function keep(w)
    local list = {}
    for k in pairs(w.set) do list[#list + 1] = k end
    table.sort(list)
    SetResourceKvp(w.key, json.encode(list))
end

-- the tees of a style a player owns, as their numbers
local function ownedOf(src, style)
    local out = {}
    local w = wardrobe(src)
    local stand = TEES[style]
    for i = 1, (w and stand) and #stand.tees or 0 do
        if w.set[style .. ':' .. i] then out[#out + 1] = i end
    end
    return out
end

-- is the player at the stand's walls? (within range of one of its hanging tees)
local function atStand(src, style, range)
    local ped = GetPlayerPed(tostring(src))
    if not ped or ped == 0 then return false, nil end
    local p = GetEntityCoords(ped)
    for _, h in ipairs(TEES[style].hung or {}) do
        local c = h.coords
        if #(vector3(p.x, p.y, p.z) - vector3(c.x, c.y, c.z)) <= range then return true, ped end
    end
    return false, ped
end

RegisterNetEvent('mzb_arena:shop:open', function(style)
    local src = source
    if type(style) ~= 'string' or not TEES[style] then return end
    TriggerClientEvent('mzb_arena:shop:state', src, { style = style, owned = ownedOf(src, style),
                                                      cash = Bridge.money(src) or false, price = priceOf(style) })
end)

RegisterNetEvent('mzb_arena:shop:buy', function(style, tee)
    local src = source
    if type(style) ~= 'string' or math.type(tee) ~= 'integer' or throttled(src) then return end
    local function no(why)
        TriggerClientEvent('mzb_arena:shop:bought', src, { ok = false, style = style, tee = tee, why = why })
    end
    local stand = TEES[style]
    if SC.enabled == false or not stand or style ~= styleNow() then return no('the stand does not have that today') end
    local t = stand.tees[tee]
    if not t then return no('the stand does not have that today') end
    local near, ped = atStand(src, style, 8.0)
    if not near then return no('come to the merch stand') end
    if not FREEMODE[GetEntityModel(ped) & 0xFFFFFFFF] then return no('the arena\'s shirts fit the freemode characters only') end
    local w = wardrobe(src)
    if not w then return no('your licence could not be read') end
    local key = style .. ':' .. tee
    if w.set[key] then return no('you own that one already') end
    local price = priceOf(style)
    local paid, err = Bridge.pay(src, price, 'Maze Bank Arena merch: ' .. t.label)
    if not paid then return no(err or 'the payment did not go through') end
    w.set[key] = true
    keep(w)
    TriggerClientEvent('mzb_arena:shop:bought', src, { ok = true, style = style, tee = tee, price = price,
                                                       cash = Bridge.money(src) or false })
end)

AddEventHandler('playerDropped', function()
    owned[source] = nil
end)
