-- mzb_arena - server: the merch stand's till (Config.Merch; the seller and the list: client/merch.lua).
-- A purchase comes in as mzb_arena:merchBuy with an item's name and nothing else. What it costs and whether the
-- stand has it at all is looked up here, in Config.Merch.items for the style of the show that is up - never taken
-- from the player's game - and the player has to be standing at the stand. The money and the item go through the
-- bridge (server/bridge.lua); an item that cannot be handed over (the inventory does not know it, no room) is not
-- sold: the money goes back.

local MC = Config.Merch or {}
if MC.enabled == false then return end

local throttled = MzbThrottle(750)

-- what the stand has today: the items of the show's style (a show without one: the arena's own)
local function stock()
    local style = (MC.styleOf or {})[GlobalState.mzbShow or Config.DefaultShow] or 'arena'
    local items = (MC.items or {})[style]
    return type(items) == 'table' and items or {}
end

RegisterNetEvent('mzb_arena:merchBuy', function(name)
    local src = source
    if type(name) ~= 'string' or #name > 64 or throttled(src) then return end
    if type(MC.ped) == 'table' and not MzbNear(src, MC.ped.coords, 6.0) then
        return MzbNotify(src, 'come to the merch stand')
    end
    local entry
    for _, it in ipairs(stock()) do
        if type(it) == 'table' and it.item == name then entry = it break end
    end
    if not entry then return MzbNotify(src, 'the stand does not have that today') end
    local label = entry.label or entry.item
    local price = math.max(0, math.floor(tonumber(entry.price) or 0))
    local paid, err = Bridge.pay(src, price, 'Maze Bank Arena merch: ' .. label)
    if not paid then return MzbNotify(src, err or 'the payment did not go through') end
    local got, why = Bridge.give(src, entry.item, 1, label)
    if not got then
        Bridge.reward(src, price, 'Maze Bank Arena merch: money back')
        return MzbNotify(src, ('%s: %s%s'):format(label, why or 'it could not be handed over',
            price > 0 and ' - you have your money back' or ''))
    end
    MzbNotify(src, price > 0 and ('you bought: %s ($%d)'):format(label, price) or ('yours: %s'):format(label))
end)
