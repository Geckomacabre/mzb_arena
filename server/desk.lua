-- mzb_arena - server: the event desk (Config.EventDesk; the ped and its menu: client/desk.lua).
-- The race's sign-up at the desk is the race's own (server/race.lua: mzb_arena:raceJoin / raceLeave / raceStart).
-- This is the desk's "Set up a fight": a pick comes in as mzb_arena:deskFight { action = 'npc' | 'player' (id = a
-- server id) | 'accept' } and goes to the fights' own challenge and accept (server/fights.lua: what /arenafight
-- challenge and accept do, with their checks - the cooldown, who is on the card already, Config.Fights.challenge).
-- Checked here: the player is at the desk, the show has a ring or a cage, and Config.EventDesk.fights.

local DC = Config.EventDesk or {}
if DC.enabled == false then return end

local FC = Config.Fights or {}
local throttled = MzbThrottle(500)

RegisterNetEvent('mzb_arena:deskFight', function(d)
    local src = source
    if type(d) ~= 'table' or throttled(src) then return end
    if FC.enabled == false then return MzbNotify(src, 'there are no fights at this arena') end
    if type(DC.ped) == 'table' and not MzbNear(src, DC.ped.coords, 8.0) then
        return MzbNotify(src, 'come to the event desk')
    end
    if not (FC.venues or {})[GlobalState.mzbShow or Config.DefaultShow] then
        return MzbNotify(src, 'there is no ring or cage up at this show')
    end
    if DC.fights == 'staff' and not MzbAllowed(src, FC.access) then
        return MzbNotify(src, 'fights are set up by the arena\'s staff')
    end
    if d.action == 'npc' then
        MzbFightChallenge(src)
    elseif d.action == 'player' and math.type(d.id) == 'integer' then
        MzbFightChallenge(src, d.id)
    elseif d.action == 'accept' then
        MzbFightAccept(src)
    end
end)
