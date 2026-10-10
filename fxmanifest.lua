fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'gecko'
description 'mzb_arena - the Maze Bank Arena with a full interior: seating bowl, street-level concourse (concessions, rest rooms, security, merch), event level (tunnel, backstage, locker rooms, production control room, loading dock behind working roller doors), switchable shows (wrestling, concert, MMA, hockey, basketball, tennis, and on a bigger floor monster trucks, arenacross, three kart circuits and a skate park), a synced light desk with a crowd, staff and press, a screen player, a music player and a followspot, fights in the ring and the cage, races on the tracks signed up for at an event desk, a merch stand with tees to try on and buy, and slippery ice'
version '1.3.1'

this_is_a_map 'yes'

-- no dependencies (ox_lib is used for the staff menu and notifications when the server runs it: Config.OxLib;
-- ox_target or qb-target for the event desk and the merch stand, and qbx_core / qb-core / es_extended / ox_inventory
-- for their money and items, when the server runs one: server/bridge.lua).
-- Servers running a map pack that also streams sp1_occl_01.ymap (e.g. cfx-gabz-mapdata):
-- ensure mzb_arena AFTER it in server.cfg (see README.md)

data_file 'DLC_ITYP_REQUEST' 'stream/interior/mzb_arena.ytyp'
-- the interior's audio: every room is sealed from the street, the weather and the rain (audio/mzb_arena_game.dat151.rel);
-- the portal occlusion (stream/interior/<occlusion hash>.ymt) muffles what is outside through the doors and glass
data_file 'AUDIO_GAMEDATA' 'audio/mzb_arena_game.dat'
-- the interior's own time cycle: no daylight / outdoor fog inside the closed rooms, none of the fog in the concourse
data_file 'TIMECYCLEMOD_FILE' 'data/mzb_timecycle.xml'
-- the merch stand's tees as clothing for the two freemode characters (stream/clothes: jbib, a drawable a stand, a
-- texture a tee; client/shop.lua puts them on)
data_file 'SHOP_PED_APPAREL_META_FILE' 'data/mp_m_freemode_01_mp_m_mzbmerch.meta'
data_file 'SHOP_PED_APPAREL_META_FILE' 'data/mp_f_freemode_01_mp_f_mzbmerch.meta'
files { 'data/mzb_timecycle.xml', 'data/mp_m_freemode_01_mp_m_mzbmerch.meta', 'data/mp_f_freemode_01_mp_f_mzbmerch.meta',
        'audio/mzb_arena_game.dat151.rel', 'html/index.html', 'html/style.css', 'html/app.js',
        'html/media.js', 'html/feed.js', 'html/music.js', 'html/follow.js', 'html/spot.js', 'html/crowd.css', 'html/crowd.js',
        'html/pyro.js', 'html/cars.js', 'html/fold.js', 'html/tabs.js', 'html/fights.css', 'html/fights.js', 'html/shop.css',
        'html/shop.js', 'html/screen.html', 'html/screen.js', 'html/img/*', 'html/img/tees/*' }

shared_scripts { 'shared/config.lua', 'shared/races.lua', 'shared/merch_tees.lua', 'shared/generated.lua',
                 'shared/rig_lights.lua', 'shared/stage_lights.lua' }
client_scripts { 'client/interior.lua', 'client/main.lua', 'client/oxmenu.lua', 'client/lights.lua', 'client/ice.lua',
                 'client/listener.lua', 'client/media.lua', 'client/music.lua', 'client/footsteps.lua', 'client/spot.lua',
                 'client/crowd_slots.lua', 'client/crowd.lua', 'client/litter.lua', 'client/fights.lua', 'client/props.lua',
                 'client/pyro.lua', 'client/cars.lua', 'client/peds.lua', 'client/race.lua', 'client/desk.lua',
                 'client/merch.lua', 'client/shop.lua' }
-- server/relay.js runs in the server's own JavaScript runtime (no packages) and does nothing unless
-- Config.Music.relay.enabled: then it fetches the music player's tracks (YouTube through yt-dlp, see README.md) and
-- serves them to the players' pages over the server's HTTP port
server_scripts { 'server/main.lua', 'server/lights.lua', 'server/clock.lua', 'server/media.lua', 'server/music.lua',
                 'server/relay.js', 'server/spot.lua', 'server/crowd.lua', 'server/pyro.lua', 'server/fights.lua',
                 'server/cars.lua', 'server/bridge.lua', 'server/desk.lua', 'server/race.lua', 'server/merch.lua',
                 'server/shop.lua' }

-- the light desk (/arenalights)
ui_page 'html/index.html'

-- left open under Cfx.re asset escrow so owners can configure the arena
escrow_ignore { 'shared/config.lua' }
