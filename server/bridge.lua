-- mzb_arena - server: money and items for the race (its fee and prize) and the merch stand, through whatever the
-- server runs. Looked for in this order, each time it is asked (so the start order does not matter):
--   qbx_core (items through ox_inventory) | qb-core | es_extended (items through ox_inventory when it runs)
--   | ox_inventory on its own (its 'money' item) | none of them: standalone
--   Bridge.name()                       which of them it is: 'qbx' | 'qb' | 'esx' | 'ox' | 'standalone'
--   Bridge.money(src)                   the player's cash (nil: nobody can say)
--   Bridge.pay(src, amount, reason)     take it: true, or false and why not
--   Bridge.reward(src, amount, reason)  hand it over (a prize, a refund): true when it went
--   Bridge.give(src, item, count, label)  the item into their inventory: true, or false and why not (an item the
--                                       inventory does not know, no room for it)
-- Standalone there is no money and no inventory: a price of 0 is paid, any other is not, and an item is "given" by
-- saying so (the caller tells the player what they have). Nothing here is a dependency; every call into another
-- resource is guarded, so one that changes its exports costs a purchase, not the script.

Bridge = {}

local NO_BRIDGE = 'this server has no money bridge: set the prices to 0 or run a framework'

local function started(name)
    return GetResourceState(name) == 'started'
end

function Bridge.name()
    if started('qbx_core') then return 'qbx' end
    if started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    if started('ox_inventory') then return 'ox' end
    return 'standalone'
end

-- a call into another resource: its answer, or nil when it threw (said once per message in the console)
local said = {}
local function try(f, ...)
    local ok, a, b = pcall(f, ...)
    if ok then return a, b end
    local msg = tostring(a)
    if not said[msg] then
        said[msg] = true
        print('[mzb_arena] bridge: ' .. msg)
    end
    return nil
end

local function qbPlayer(src)
    return try(function() return exports['qb-core']:GetCoreObject().Functions.GetPlayer(src) end)
end

local function esxPlayer(src)
    return try(function() return exports.es_extended:getSharedObject().GetPlayerFromId(src) end)
end

-- ------------------------------------------------------------------ money (cash)
function Bridge.money(src)
    local kind = Bridge.name()
    if kind == 'qbx' then
        return tonumber(try(function() return exports.qbx_core:GetMoney(src, 'cash') end))
    elseif kind == 'qb' then
        local p = qbPlayer(src)
        return p and tonumber(p.PlayerData.money.cash) or nil
    elseif kind == 'esx' then
        local p = esxPlayer(src)
        return p and tonumber(try(function() return p.getMoney() end)) or nil
    elseif kind == 'ox' then
        return tonumber(try(function() return exports.ox_inventory:GetItemCount(src, 'money') end))
    end
    return nil
end

function Bridge.pay(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local kind = Bridge.name()
    if kind == 'standalone' then return false, NO_BRIDGE end
    local have = Bridge.money(src)
    if not have then return false, 'your money could not be read' end
    if have < amount then return false, ('you need $%d in cash'):format(amount) end
    local ok
    if kind == 'qbx' then
        ok = try(function() return exports.qbx_core:RemoveMoney(src, 'cash', amount, reason) end)
    elseif kind == 'qb' then
        local p = qbPlayer(src)
        ok = p and try(function() return p.Functions.RemoveMoney('cash', amount, reason) end)
    elseif kind == 'esx' then
        local p = esxPlayer(src)
        -- (removeMoney answers nothing: the cash is read again to see that it went)
        if p and try(function() p.removeMoney(amount, reason) return true end) then
            ok = (Bridge.money(src) or have) <= have - amount
        end
    elseif kind == 'ox' then
        ok = try(function() return exports.ox_inventory:RemoveItem(src, 'money', amount) end)
    end
    if ok then return true end
    return false, 'the payment did not go through'
end

function Bridge.reward(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local kind = Bridge.name()
    if kind == 'qbx' then
        return try(function() return exports.qbx_core:AddMoney(src, 'cash', amount, reason) end) and true or false
    elseif kind == 'qb' then
        local p = qbPlayer(src)
        return p and try(function() return p.Functions.AddMoney('cash', amount, reason) end) and true or false
    elseif kind == 'esx' then
        local p = esxPlayer(src)
        return p and try(function() p.addMoney(amount, reason) return true end) and true or false
    elseif kind == 'ox' then
        return try(function() return exports.ox_inventory:AddItem(src, 'money', amount) end) and true or false
    end
    return false
end

-- ------------------------------------------------------------------ items
-- through ox_inventory: the item has to be one of its items, and there has to be room for it
local function oxGive(src, item, count)
    if not try(function() return exports.ox_inventory:Items(item) end) then
        return false, ('the item %s is not in the server\'s inventory'):format(item)
    end
    if try(function() return exports.ox_inventory:CanCarryItem(src, item, count) end) == false then
        return false, 'you cannot carry that'
    end
    if try(function() return exports.ox_inventory:AddItem(src, item, count) end) then return true end
    return false, 'it could not be put in your inventory'
end

function Bridge.give(src, item, count, label)
    count = math.max(1, math.floor(tonumber(count) or 1))
    local kind = Bridge.name()
    if kind == 'standalone' then return true end
    if type(item) ~= 'string' or item == '' then return false, 'no such item' end
    if kind == 'ox' or ((kind == 'qbx' or kind == 'esx') and started('ox_inventory')) then
        return oxGive(src, item, count)
    elseif kind == 'qbx' then
        return false, 'qbx_core keeps its items in ox_inventory, which is not running'
    elseif kind == 'qb' then
        local known = try(function() return exports['qb-core']:GetCoreObject().Shared.Items[item] end)
        if not known then return false, ('the item %s is not in the server\'s inventory'):format(item) end
        local p = qbPlayer(src)
        if p and try(function() return p.Functions.AddItem(item, count) end) then return true end
        return false, 'you cannot carry that'
    elseif kind == 'esx' then
        local p = esxPlayer(src)
        if not p then return false, 'it could not be put in your inventory' end
        if not try(function() return exports.es_extended:getSharedObject().GetItemLabel(item) end) then
            return false, ('the item %s is not in the server\'s inventory'):format(item)
        end
        if try(function() return p.canCarryItem(item, count) end) == false then return false, 'you cannot carry that' end
        if try(function() p.addInventoryItem(item, count) return true end) then return true end
        return false, 'it could not be put in your inventory'
    end
    return false, (label or item) .. ' could not be handed over'
end
