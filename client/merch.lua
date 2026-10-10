-- mzb_arena - client: the merch stand's seller (Config.Merch; a ped to talk to: client/peds.lua). Talking to them
-- lists what the show that is up has for sale - the items of its style, with their prices - and a pick asks the
-- server for that item by name (server/merch.lua: it looks the price up itself, takes the money and hands the item
-- over, or says why not). The list here is only what the player is shown.

local MC = Config.Merch or {}
if MC.enabled == false or type(MC.ped) ~= 'table' then return end

local PICK = 'mzb_arena:merchPick'

local function open()
    local style = (MC.styleOf or {})[GlobalState.mzbShow or Config.DefaultShow] or 'arena'
    local items = (MC.items or {})[style]
    local opts = {}
    for _, it in ipairs(type(items) == 'table' and items or {}) do
        local price = math.max(0, math.floor(tonumber(it.price) or 0))
        opts[#opts + 1] = { title = it.label or it.item, icon = 'shirt', event = PICK, args = { item = it.item },
                            description = price > 0 and ('$%d'):format(price) or 'Free' }
    end
    if #opts == 0 then opts[1] = { title = 'Sold out', icon = 'box-open' } end
    ArenaMenu.open({ id = 'mzb_arena_merch', title = ((MC.titles or {})[style] or 'Maze Bank Arena') .. ' merch',
                     options = opts })
end

AddEventHandler(PICK, function(a)
    if type(a) == 'table' and type(a.item) == 'string' then TriggerServerEvent('mzb_arena:merchBuy', a.item) end
end)

ArenaPed.add({ id = 'merch', model = MC.ped.model, coords = MC.ped.coords, scenario = MC.ped.scenario, room = MC.ped.room,
               distance = MC.distance, label = 'Browse the merch', icon = 'shirt', onUse = open,
               enabled = function() return MC.enabled ~= false end })
