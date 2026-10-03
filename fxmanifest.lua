fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'gecko'
description 'mzb_arena - the Maze Bank Arena with a full interior: seating bowl, street-level concourse (concessions, rest rooms, security, merch), event level (tunnel, backstage, locker rooms, production control room, loading dock behind working roller doors), switchable shows (wrestling, concert, MMA, hockey, basketball, tennis), a synced light desk and slippery ice'
version '1.1.0'

this_is_a_map 'yes'

-- no dependencies. Servers running a map pack that also streams sp1_occl_01.ymap (e.g. cfx-gabz-mapdata):
-- ensure mzb_arena AFTER it in server.cfg (see README.md)

data_file 'DLC_ITYP_REQUEST' 'stream/interior/mzb_arena.ytyp'
-- the interior's audio: every room is sealed from the street, the weather and the rain (audio/mzb_arena_game.dat151.rel);
-- the portal occlusion (stream/interior/<occlusion hash>.ymt) muffles what is outside through the doors and glass
data_file 'AUDIO_GAMEDATA' 'audio/mzb_arena_game.dat'
-- the interior's own time cycle: no daylight / outdoor fog inside the closed rooms, none of the fog in the concourse
data_file 'TIMECYCLEMOD_FILE' 'data/mzb_timecycle.xml'
files { 'data/mzb_timecycle.xml', 'audio/mzb_arena_game.dat151.rel', 'html/index.html', 'html/style.css', 'html/app.js',
        'html/media.js', 'html/music.js', 'html/spot.js', 'html/screen.html', 'html/screen.js', 'html/img/*' }

shared_scripts { 'shared/config.lua', 'shared/generated.lua' }
client_scripts { 'client/main.lua', 'client/lights.lua', 'client/ice.lua', 'client/listener.lua', 'client/media.lua', 'client/music.lua', 'client/spot.lua' }
server_scripts { 'server/main.lua', 'server/lights.lua', 'server/clock.lua', 'server/media.lua', 'server/music.lua', 'server/spot.lua' }

-- the light desk (/arenalights)
ui_page 'html/index.html'

-- left open under Cfx.re asset escrow so owners can configure the arena
escrow_ignore { 'shared/config.lua' }
