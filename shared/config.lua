-- mzb_arena - shared configuration (generated values come from the arena build: arena_build/ar_plan.py)
Config = {}

-- the interior (for GetInteriorAtCoords): the middle of the bowl
Config.InteriorProbe = vector3(-324.31, -1968.60, 25.0)

-- the three roller doors of the NW loading street (world centre of each opening, outward normal, sill, lintel)
Config.DockDoors = {
    dock_a = { x = -387.015, y = -1884.000, nx = -0.508, ny = 0.861, z = 19.53, top = 24.54 },
    dock_b = { x = -376.060, y = -1878.700, nx = -0.367, ny = 0.930, z = 19.53, top = 24.54 },
    dock_c = { x = -364.365, y = -1875.165, nx = -0.226, ny = 0.974, z = 19.53, top = 24.54 },
}
Config.ShutterBands = 10          -- 0.5 m bands (the bottom one carries the bar)
Config.ShutterBandH = 0.5
Config.ShutterSeconds = 7.0       -- full open / close
Config.ShutterOut = -0.45         -- where the shutter hangs off the opening's plane (- = inside: in the dock's guides)
Config.DockButtons = true         -- [E] open / close at each roller door (inside or out, on foot or driving)
Config.DockAccess = false         -- false = anyone may use them; or an ACE, e.g. 'command.arena' (staff only)
Config.DockReach = 5.0            -- m from the door's middle, on foot
Config.DockReachVehicle = 10.0    -- m, at the wheel
Config.DockCooldown = 2.0         -- s between two presses on one door

-- show modes: which interior entity sets each one turns on (every set named anywhere here is managed)
-- (the build's ar_site.SHOWS says the same - keep them in step)
-- mzb_set_low_nw_seated / _stowed: the stage end's telescopic lower sections - seated, or stowed into stacks with a
-- backstage area (wardrobe, video village, catering, road cases) behind the masking for the end-stage shows
Config.Shows = {
    house     = { 'mzb_set_house_lights', 'mzb_set_low_nw_seated' },     -- the empty arena, house lights up
    wrestling = { 'mzb_set_wwe_ring', 'mzb_set_wwe_stage', 'mzb_set_wwe_floor', 'mzb_set_wwe_rig',
                  'mzb_set_mask_nw', 'mzb_set_house_lights_dim',
                  'mzb_set_low_nw_stowed' },                             -- the ring show, the house dimmed
    concert   = { 'mzb_set_nw_deck', 'mzb_set_con_stage', 'mzb_set_con_rig', 'mzb_set_con_floor',
                  'mzb_set_mask_nw', 'mzb_set_house_lights_dim',
                  'mzb_set_low_nw_stowed' },                             -- end-stage concert, standing floor
    hockey    = { 'mzb_set_hockey', 'mzb_set_hockey_board', 'mzb_set_house_lights',
                  'mzb_set_low_nw_seated' },                             -- the ice rink, boards and glass
    basketball = { 'mzb_set_basketball', 'mzb_set_basketball_board', 'mzb_set_house_lights',
                  'mzb_set_low_nw_seated' },                             -- the hardwood court, courtside seats
    tennis    = { 'mzb_set_tennis', 'mzb_set_tennis_board', 'mzb_set_house_lights',
                  'mzb_set_low_nw_seated' },                             -- the hard court, the umpire's chair
    mma       = { 'mzb_set_nw_deck', 'mzb_set_mma_stage', 'mzb_set_mma_cage', 'mzb_set_mma_floor',
                  'mzb_set_mma_rig', 'mzb_set_mask_nw', 'mzb_set_house_lights_dim',
                  'mzb_set_low_nw_stowed' },                             -- fight night: the cage, end stage
}
Config.DefaultShow = 'wrestling'

-- who may run the arena commands (ACE: add_ace group.admin command.arena allow)
Config.Command = 'arena'

-- the quick show switch: /mzb <show>  (e.g. /mzb wrestling, /mzb basketball, /mzb house; /mzb list, /mzb status).
-- Same permission as Config.Command (the ACE above). Set to false to turn it off.
Config.QuickCommand = 'mzb'

-- other words the quick command accepts for a show (add your own; the right-hand side must be a show above)
Config.ShowAliases = {
    fight = 'mma', cage = 'mma', octagon = 'mma',
    ring = 'wrestling',
    ice = 'hockey',
    hoops = 'basketball', bball = 'basketball',
    gig = 'concert', band = 'concert', music = 'concert',
    empty = 'house', off = 'house', clear = 'house',
}

-- seconds between two show switches (a switch reloads the interior's sets for everyone inside)
Config.SwitchCooldown = 3

-- tell every player in chat when the show changes (false: only the one who switched it)
Config.AnnounceSwitch = false

-- ox_lib, if the server runs it (client/oxmenu.lua): /arena or /mzb with nothing after it opens an ox_lib menu (pick the
-- show, the dock doors, the light desk) and what the commands answer comes as an ox_lib notification instead of a chat
-- line. 'auto' = when ox_lib is started; false = never (typed commands and chat, as before). The arena does not need
-- ox_lib either way: it is not a dependency.
Config.OxLib = 'auto'
-- the menu's names and icons (Font Awesome) for the shows; a show that is not here gets its own name
Config.ShowLabels = {
    house = { 'Empty house', 'building' }, wrestling = { 'Wrestling', 'hand-fist' }, concert = { 'Concert', 'music' },
    mma = { 'MMA', 'shield-halved' }, hockey = { 'Hockey', 'hockey-puck' }, basketball = { 'Basketball', 'basketball' },
    tennis = { 'Tennis', 'table-tennis-paddle-ball' },
}

-- ------------------------------------------------------------------ the light desk (client/lights.lua, server/lights.lua)
-- The arena's own light show: coloured spot lights from the show's rig (its moving heads and washes) and the house
-- lights up in the roof, the same for every player (synced to the network clock). Open the desk with /arenalights, or
-- run it from chat: /arenalights help. The baked lights of the interior stay as they are; the desk's house buttons
-- switch them between the show's setting, full, dimmed and off. A look is a colour effect (mode) and a movement (move)
-- picked independently, one or more aims (floor, stage, crowd: the fixtures take turns), and the ring lights.
Config.LightCommand = 'arenalights'
Config.LightAccess = 'command.arena'   -- who may run the lights: an ACE (default: the arena's staff ACE), false = anyone
Config.LightMaxFixtures = 40           -- spot lights drawn per frame at most (the show rigs have 24 to 36, up to 46 with
                                       -- Config.LightRigExtra; the roof's house lights are the ones left out)
Config.LightLensGlow = true            -- a small glow at each fixture's lens, so the rig itself flashes
Config.LightBrightness = 12.0          -- DrawSpotLight brightness at full intensity
Config.LightHardness = 0.0             -- DrawSpotLight roundness (0 = soft edge)
Config.LightFalloff = 1.0              -- DrawSpotLight falloff
Config.LightCone = { 9.0, 20.0, 14.0 } -- the beam's radius per fixture group: moving heads, washes, house (roof)
Config.LightSpread = 6.0               -- m: how far apart the spots land round the aim point
Config.LightMaxStrobeHz = 8.0          -- flashes per second at most in strobe mode (0 turns strobe into a pulse)
-- the rooms the show is drawn in (players elsewhere in the building don't pay for it)
Config.LightRooms = { bowl = true, concourse = true, tunnel = true, backstage = true }
Config.LightDefault = { on = false, mode = 'static', move = 'none', colors = { { 255, 255, 255 } }, bpm = 120,
                        intensity = 0.8, focus = 'floor', ring = true, ringLevel = 1.0, house = 'show', ringv = 2 }
-- the ring lights (the desk's RING LIGHTS button and its colour / level, /arenalights ring ...): the wrestling ring's,
-- the MMA cage's and the concert stage's own lights (Config.RingLights, shared/rig_lights.lua: until 1.1.0 they were
-- baked into the rigs and always on), on by default, in the colours the build gave them or one colour from the desk,
-- whether the show lights are on or not. A show without them uses its rig's washes (group 2) on their own aim.
-- RingLightScale: a baked light's intensity times this is the script's brightness.
Config.RingLightScale = 5.0
Config.RingLightGroup = 2
Config.RingLightColor = { 255, 244, 225 }
Config.RingLightBrightness = 16.0
-- named colours for chat (/arenalights color red blue) and the desk's palette
Config.LightColors = {
    white = { 255, 255, 255 }, warm = { 255, 196, 120 }, red = { 255, 24, 24 }, orange = { 255, 110, 0 },
    amber = { 255, 170, 0 }, yellow = { 255, 230, 20 }, green = { 20, 255, 60 }, cyan = { 0, 230, 255 },
    blue = { 20, 60, 255 }, purple = { 140, 30, 255 }, magenta = { 255, 20, 200 }, pink = { 255, 90, 150 },
}
-- one-touch looks (the desk's preset buttons, /arenalights preset <name>); nil fields keep what is set. mood = the
-- crowd's mood that goes with the look (Config.CrowdMoods; Config.CrowdPresetMoods = false: looks leave the crowd be);
-- screen = the video screens' look with it (Config.Media.looks; only while the screens show a look or nothing)
Config.LightPresets = {
    walkin    = { label = 'Walk-in',   on = true,  mode = 'pulse', move = 'none',    colors = { { 20, 60, 255 }, { 140, 30, 255 } }, bpm = 50,  focus = 'crowd', house = 'dim', mood = 'doors', screen = 'show' },
    entrance  = { label = 'Entrance',  on = true,  mode = 'sweep', move = 'none',    colors = { { 255, 24, 24 }, { 255, 255, 255 } }, bpm = 128, focus = 'stage', house = 'off', mood = 'peak', screen = 'pulse' },
    goal      = { label = 'Goal!',     on = true,  mode = 'strobe', move = 'none',   colors = { { 255, 24, 24 }, { 255, 255, 255 } }, bpm = 150, focus = 'floor', house = 'off', mood = 'cheer', screen = 'colour' },
    concert   = { label = 'Concert',   on = true,  mode = 'chase', move = 'none',    colors = { { 255, 20, 200 }, { 0, 230, 255 }, { 255, 255, 255 } }, bpm = 124, focus = 'stage', house = 'off', mood = 'show', screen = 'stripes' },
    party     = { label = 'Party',     on = true,  mode = 'rainbow', move = 'none',  bpm = 128, focus = 'floor', house = 'off', mood = 'peak', screen = 'bars' },
    fight     = { label = 'Fight',     on = true,  mode = 'ballyhoo', move = 'none', colors = { { 255, 255, 255 }, { 255, 24, 24 } }, bpm = 90, focus = 'floor', house = 'dim', mood = 'show', screen = 'pulse' },
    police    = { label = 'Police',    on = true,  mode = 'police', move = 'none',   bpm = 120, focus = 'floor', house = 'dim' },
    tv        = { label = 'TV ring',   on = false, ring = true, house = 'dim' },
    storm     = { label = 'Storm',     on = true,  mode = 'lightning', move = 'none', colors = { { 20, 60, 255 } }, bpm = 90, focus = { 'floor', 'crowd' }, house = 'off', screen = 'colour' },
    inferno   = { label = 'Inferno',   on = true,  mode = 'fire',     move = 'nod', bpm = 70, focus = { 'stage', 'crowd' }, house = 'off', screen = 'waves' },
    hype      = { label = 'Hype',      on = true,  mode = 'flash',    move = 'fan', colors = { { 255, 255, 255 }, { 255, 170, 0 } }, bpm = 128, focus = { 'floor', 'crowd' }, house = 'off', mood = 'peak', screen = 'bars' },
    houseup   = { label = 'House up',  on = false, house = 'full', mood = 'cheer' },
    blackout  = { label = 'Blackout',  on = false, ring = false, house = 'off' },
    reset     = { label = 'Reset',     on = false, mode = 'static', move = 'none', colors = { { 255, 255, 255 } }, bpm = 120, intensity = 0.8, focus = 'floor', ring = false, house = 'show' },
}
Config.LightPresetOrder = { 'walkin', 'entrance', 'goal', 'concert', 'party', 'fight', 'police', 'tv', 'storm', 'inferno',
                            'hype', 'houseup', 'blackout', 'reset' }
-- the interior's house light sets the desk's house buttons switch (full / dim; off = neither)
Config.HouseSets = { full = 'mzb_set_house_lights', dim = 'mzb_set_house_lights_dim' }

-- ------------------------------------------------------------------ the hockey rink's ice (client/ice.lua)
-- On foot the rink is slippery while the hockey show is up: you keep your momentum (glide, overshoot, drift through
-- turns) and a hard sprinting turn can take you off your feet. Vehicles slide on it anyway (its ICE surface).
Config.Ice = {
    enabled = true,
    shows = { hockey = true },   -- the shows with the ice down
    slide = 0.65,                -- s: how long your momentum takes to die away (more = slipperier)
    maxSpeed = 9.0,              -- m/s: the fastest you can glide
    falls = true,                -- sprinting into a sharp turn can make you fall
    fallChance = 0.35,           -- the chance per sharp sprinting turn
    fallCooldown = 4.0,          -- s between two falls
}

-- ------------------------------------------------------------------ where a listener is (client/listener.lua)
-- The screens' video sound and the music player both play in a browser, which has no idea where you stand. So the
-- client works it out: the room the game has you in, sorted into the bowl, the rooms next to it, the rest of the
-- building and outside. The two players turn their level, filter and echo from that. A room not named here counts as
-- "building" while you are inside the arena's interior.
Config.Listener = {
    near = { concourse = true, tunnel = true, backstage = true, stair_nw = true, stair_se = true,
             ring_north = true, ring_east = true, ring_south = true },   -- open onto the bowl: heard through the gaps
    level = { bowl = 1.0, near = 0.35, building = 0.06, outside = 0.0 },  -- the level in each, before distance
}
-- how clients agree on "now" with the server (whose clock the media and music positions run on): ask now and then
Config.ClockResync = 60          -- s between two clock checks (a check is three quick round trips; the best one wins)

-- ------------------------------------------------------------------ media on the video screens (client/media.lua, server/media.lua)
-- A YouTube video, a cycle of pictures or one picture on every video screen of the show, drawn by a hidden browser
-- (html/screen.html) onto the screens' render target. While nothing of ours is on, the render target is left alone,
-- so pmms or a TV script can use the same screens; when ours is on it wins. Run it from the desk's Screens section or
-- with /arenascreen <youtube url | picture url(s) | images [set] | off | pause | resume | volume n | status>.
Config.Media = {
    enabled = true,              -- false: no built-in screen player at all (leave the screens to another script)
    command = 'arenascreen',
    access = nil,                -- an ACE, false = anyone, nil = the same as the lights (Config.LightAccess)
    width = 1280, height = 720,  -- the browser's size in pixels (the picture is stretched over every screen)
    range = 160.0,               -- m from the arena's middle: the browser exists only this close, and goes further out
    volume = 0.6,                -- the video's loudness at 100% on the desk, in the bowl (the sound is not positional)
    defaultVolume = 60,          -- the desk's volume a new video starts at (0-100)
    interval = 8,                -- s per picture in a cycle (the desk / command can change it: 2-120)
    resync = 30,                 -- s between two position checks of a running video (a late or drifting one seeks)
    maxImages = 24,              -- pictures in one cycle at most
    -- how the picture gets onto the screens: 'replace' swaps the screens' texture (replaceTxd / replaceTex) for the
    -- browser's while ours is on, as the Vinewood Bowl's LED wall does; 'rendertarget' draws onto the named render
    -- target every frame, as pmms does. Back to the show's own graphics when ours is off, either way.
    method = 'replace',
    replaceTxd = 'mzb_tx_show', replaceTex = 'script_rt_mzb_screens',
    -- the browser's page. https://cfx-nui-<resource>/... gives it a web origin, which YouTube needs before it plays
    -- in an embedded player (a nui:// page gets error 153); nil = this resource's html/screen.html at that address
    pageUrl = nil,
    -- picture sets (/arenascreen images [name], the desk's set buttons): files of this resource under html/img/ or
    -- https URLs, shown in this order, Config.Media.interval seconds each. /arenascreen images with no name plays the
    -- show's own set, else 'arena'. The pictures are the arena's own graphics (the titantron, the board, the murals).
    imageSets = {
        arena = { 'img/arena_welcome.jpg', 'img/arena_coming_up.jpg', 'img/arena_sprunk.jpg', 'img/arena_fame.jpg',
                  'img/arena_ecola.jpg' },
        wrestling = { 'img/sapw_tron.jpg', 'img/sapw_live.jpg', 'img/sapw_neon.jpg', 'img/sapw_banner.jpg',
                      'img/arena_coming_up.jpg', 'img/arena_sprunk.jpg' },
        concert = { 'img/sirens_poster.jpg', 'img/sirens_live.jpg', 'img/arena_coming_up.jpg', 'img/arena_ecola.jpg' },
        mma = { 'img/safc_wall.jpg', 'img/safc_live.jpg', 'img/arena_coming_up.jpg', 'img/arena_fame.jpg' },
        hockey = { 'img/hockey_live.jpg', 'img/arena_welcome.jpg', 'img/arena_coming_up.jpg', 'img/arena_sprunk.jpg' },
        basketball = { 'img/basketball_live.jpg', 'img/arena_welcome.jpg', 'img/arena_coming_up.jpg', 'img/arena_ecola.jpg' },
        tennis = { 'img/tennis_live.jpg', 'img/arena_welcome.jpg', 'img/arena_coming_up.jpg', 'img/arena_fame.jpg' },
    },
    -- looks: LED-wall pictures the page draws itself, in step with the light desk (its colours, effect and speed):
    -- show (the show's artwork, breathing; the lights' colour over it), pulse, colour, bars, stripes, waves. The desk's
    -- look buttons, /arenascreen look <name>; the light presets carry one (screen = ...) and set it while the screens
    -- show a look or nothing (a video or pictures are never cut off).
    looks = { 'show', 'pulse', 'colour', 'bars', 'stripes', 'waves' },
    presetLooks = true,
    backdrops = { wrestling = 'img/sapw_tron.jpg', concert = 'img/sirens_poster.jpg', mma = 'img/safc_wall.jpg',
                  hockey = 'img/hockey_live.jpg', basketball = 'img/basketball_live.jpg', tennis = 'img/tennis_live.jpg',
                  house = 'img/arena_welcome.jpg' },
    logos = { wrestling = 'img/sapw_neon.jpg' },   -- the logo over a look (its black is see-through); else the title
    titles = { wrestling = 'SAPW', concert = 'SIRENS OF SAN ANDREAS', mma = 'SAFC', hockey = 'DUST DEVILS',
               basketball = 'LOS SANTOS PANIC', tennis = 'MAZE BANK OPEN', house = 'MAZE BANK ARENA' },
}

-- ------------------------------------------------------------------ the music player (client/music.lua, server/music.lua)
-- Music off the light desk, heard from the show's PA: the sound plays in this resource's own page (html/music.js),
-- which turns its level down with the distance to the nearest PA hang, pans it to where the hang is, and gives it the
-- room's sound - full and echoing in the bowl, muffled next door, faint elsewhere in the building, nothing outside.
-- Direct links to audio files and streams (mp3, ogg, m4a, icecast ...) or YouTube links. The filter and the echo need
-- the audio's server to allow it (CORS); YouTube and streams that don't get the level and nothing more.
-- Run it from the desk's Music section or /arenamusic <url | pause | resume | stop | volume n | status>; every player
-- sets their own level with /arenamusic mine <0-100> (kept between sessions).
Config.Music = {
    enabled = true,
    command = 'arenamusic',
    access = nil,                -- an ACE, false = anyone, nil = the same as the lights (Config.LightAccess)
    volume = 0.8,                -- the loudness at 100% on the desk, next to a PA hang
    defaultVolume = 70,          -- the desk's volume (0-100) when the resource starts
    range = 200.0,               -- m from the arena's middle: the audio is loaded only this close
    resync = 30,                 -- s between two position checks (a drifting player seeks back)
    -- in the bowl the track comes out of every hang below as a sound in 3D (Web Audio; not YouTube, and not an audio
    -- server that refuses CORS: those get the level only, by the distance to the nearest hang)
    refDistance = 12.0,          -- m from a hang at which its level starts to fall
    rolloff = 0.7,               -- how fast it falls past that (1 = halved at twice the distance; less = gentler)
    panning = 'HRTF',            -- 'HRTF' (left / right / behind, best on headphones) or 'equalpower' (left / right)
    minGain = 0.25,              -- the level-only players: never below this in the bowl (its far end)
    pan = 0.6,                   -- the level-only players: how far the sound pans to the hangs (0 = not at all)
    reverbSeconds = 2.4,         -- the length of the arena's echo
    -- the room's sound per Config.Listener zone: a low-pass filter (Hz) and how much echo is mixed in (0-1)
    rooms = {
        bowl = { lowpass = 20000, wet = 0.16 },
        near = { lowpass = 1100, wet = 0.18 },
        building = { lowpass = 420, wet = 0.10 },
    },
    -- the PA hangs per show (world positions from the arena's build; move them if you move the rig)
    hangs = {
        wrestling = { vector3(-335.059, -1969.540, 30.75), vector3(-323.370, -1979.349, 30.75),
                      vector3(-313.561, -1967.660, 30.75), vector3(-325.250, -1957.851, 30.75) },  -- the ring truss
        mma = { vector3(-335.059, -1969.540, 28.75), vector3(-323.370, -1979.349, 28.75),
                vector3(-313.561, -1967.660, 28.75), vector3(-325.250, -1957.851, 28.75) },
        concert = { vector3(-347.541, -1966.338, 29.70), vector3(-330.572, -1946.115, 29.70) },     -- either side of the stage
        hockey = { vector3(-324.310, -1968.600, 33.0) },                                             -- the centre-hung board
        basketball = { vector3(-324.310, -1968.600, 33.0) },
        tennis = { vector3(-324.310, -1968.600, 33.0) },
        house = { vector3(-324.310, -1968.600, 33.0) },
    },
}

-- ------------------------------------------------------------------ the arena's own sound (client/ambience.lua)
-- The building is never silent: a low room tone in every room of it, the crowd's chatter while the crowd is in and
-- its roar in the loud moods, all made by the NUI page (html/ambience.js, no files). Per Config.Listener zone: the
-- room tone's level, the crowd's level and a low-pass (Hz: the bowl heard through the concourse's walls). Per crowd
-- mood (Config.CrowdMoods): how much they chatter and how much they roar. Everyone has their own level of it on the
-- desk (Music: Room) or with /arenaambience <0-100>. quietFootsteps: the game's quiet footsteps inside the building.
Config.Ambience = {
    enabled = true,
    command = 'arenaambience',
    volume = 0.5,
    quietFootsteps = true,
    zones = {
        bowl = { tone = 0.30, walla = 1.0, lowpass = 9000 },
        near = { tone = 0.26, walla = 0.45, lowpass = 1800 },
        building = { tone = 0.20, walla = 0.10, lowpass = 500 },
    },
    moods = {
        doors = { walla = 0.9, roar = 0.0 },
        show = { walla = 0.55, roar = 0.12 },
        peak = { walla = 0.7, roar = 0.55 },
        cheer = { walla = 0.6, roar = 0.9 },
    },
}

-- ------------------------------------------------------------------ the followspot (client/spot.lua, server/spot.lua)
-- One or two operator-run followspots high on the bowl's long sides. Lock them onto a player (every client tracks that
-- ped itself, so it is smooth and costs no traffic) or aim them by hand: grab free aim with the key below and the
-- spot follows your camera (sent at most Config.FollowSpot.sendRate times a second; the others glide after it).
-- Run it from the desk's Followspot section or /arenaspot <on | off | follow <id|me|look> | free | color c | size n |
-- intensity n | status>.
Config.FollowSpot = {
    enabled = true,
    command = 'arenaspot',
    access = nil,                -- an ACE, false = anyone, nil = the same as the lights (Config.LightAccess)
    key = 'F7',                  -- grab / release free aim (players can rebind it: Settings > Key Bindings > FiveM)
    -- the lamps: just under the roof's house-light positions on the long sides (rig group 3)
    fixtures = { vector3(-334.807, -1984.162, 51.6), vector3(-313.813, -1953.038, 51.6) },
    brightness = 40.0,           -- DrawSpotLight brightness at full intensity
    hardness = 0.75,             -- a followspot has a hard edge (0 = soft)
    falloff = 1.0,
    size = 5.0,                  -- the beam's radius (degrees) a new spot starts at; the desk sets 2-15
    color = { 255, 248, 235 },   -- a warm white
    intensity = 1.0,
    sendRate = 8,                -- free aim: points a second at most
    bounds = { radius = 70.0, zMin = 15.0, zMax = 60.0 },   -- where a free-aim point may be: the arena, no further
    lookAngle = 8.0,             -- "follow look": the player nearest your crosshair within this many degrees
}

-- ------------------------------------------------------------------ more stage lights (client/lights.lua)
-- Fixtures of your own, added to the show's rig (Config.LightRig, from the build) and run by the light desk like the
-- rest: { x, y, z, dx, dy, dz, g } with g 1 a moving head, 2 a wash (the ring lights use these too), 3 a house light,
-- 4 a floor beam (it keeps its own aim, whatever the desk's aim is). The ones below light the stage end: heads and
-- washes half way between the build's fixtures on the same truss (so they hang on real steel), and four floor
-- beams along the back of the stage end, either side of the entrance, shooting up and out over the floor.
Config.LightConeFloor = 5.0            -- the floor beams' radius: narrow, a beam rather than a wash
Config.LightRigExtra = {
    wrestling = {
        { -343.987, -1956.896, 29.522, 0.140, 0.154, -0.978, 1 },   -- the stage truss
        { -345.547, -1958.796, 29.532, 0.284, 0.196, -0.939, 1 },
        { -347.169, -1960.650, 29.546, 0.236, 0.380, -0.894, 1 },
        { -336.881, -1948.424, 29.541, -0.247, -0.298, -0.922, 1 },  -- the stage truss, other side
        { -334.837, -1956.479, 28.758, 0.178, -0.476, -0.861, 1 },   -- the low truss over the ramp
        { -336.472, -1958.393, 28.737, 0.288, -0.237, -0.928, 1 },
        { -348.084, -1956.484, 21.350, 0.231, -0.194, 0.954, 4 },    -- floor beams, back of the stage
        { -346.156, -1954.186, 21.350, 0.231, -0.194, 0.954, 4 },
        { -342.299, -1949.589, 21.350, 0.231, -0.194, 0.954, 4 },
        { -340.370, -1947.291, 21.350, 0.231, -0.194, 0.954, 4 },
    },
    concert = {
        { -343.293, -1960.601, 31.777, -0.207, 0.319, -0.925, 2 },  -- the wash bar over the stage
        { -341.058, -1957.937, 31.776, -0.271, 0.246, -0.931, 2 },
        { -338.822, -1955.273, 31.777, -0.332, 0.170, -0.928, 2 },
        { -336.586, -1952.609, 31.779, -0.390, 0.094, -0.916, 2 },
        { -334.349, -1949.945, 31.784, -0.443, 0.020, -0.896, 2 },
        { -348.084, -1956.484, 21.350, 0.231, -0.194, 0.954, 4 },    -- floor beams, back of the stage
        { -346.156, -1954.186, 21.350, 0.231, -0.194, 0.954, 4 },
        { -342.299, -1949.589, 21.350, 0.231, -0.194, 0.954, 4 },
        { -340.370, -1947.291, 21.350, 0.231, -0.194, 0.954, 4 },
    },
    mma = {
        { -348.084, -1956.484, 21.350, 0.231, -0.194, 0.954, 4 },    -- floor beams, back of the stage
        { -346.156, -1954.186, 21.350, 0.231, -0.194, 0.954, 4 },
        { -342.299, -1949.589, 21.350, 0.231, -0.194, 0.954, 4 },
        { -340.370, -1947.291, 21.350, 0.231, -0.194, 0.954, 4 },
    },
}

-- the ramp lights: small fixtures along the wrestling ramp's two top edges (on its LED strips), each grazing across
-- the ramp and whoever walks down it, in the desk's colours and effects (a chase runs from the stage to the ring);
-- their lenses glow, so the edges read as two rows of lights. In the desk's looks while the show lights are on, in
-- Config.RampLightIdle while they are off; not counted in Config.LightMaxFixtures.
-- { x, y, z, dx, dy, dz, k }: k = the place along the ramp (1 = the stage end), both sides
Config.RampLightBrightness = 10.0
Config.RampLightCone = 28.0            -- the beam's radius (degrees)
Config.RampLightRange = 9.0            -- m
Config.RampLightTilt = 10.0            -- degrees down from across the ramp (their beams land on it)
Config.RampLightGlow = 6.0             -- each lens's glow on the ramp's edge ...
Config.RampLightGlowRange = 1.4        -- ... and how far it reaches (m)
Config.RampLightIdle = { 120, 170, 255, 0.45 }   -- r, g, b, level while the show lights are off (false = dark)
Config.RampLights = {
    wrestling = {
        { -340.441, -1956.866, 21.034, 0.290, 0.346, 0.892, 1 },
        { -338.667, -1954.751, 21.034, -0.290, -0.346, 0.892, 1 },
        { -339.331, -1957.798, 20.851, 0.290, 0.346, 0.892, 2 },
        { -337.556, -1955.683, 20.851, -0.290, -0.346, 0.892, 2 },
        { -338.220, -1958.730, 20.667, 0.290, 0.346, 0.892, 3 },
        { -336.446, -1956.615, 20.667, -0.290, -0.346, 0.892, 3 },
        { -337.109, -1959.662, 20.484, 0.290, 0.346, 0.892, 4 },
        { -335.335, -1957.548, 20.484, -0.290, -0.346, 0.892, 4 },
        { -335.998, -1960.594, 20.300, 0.290, 0.346, 0.892, 5 },
        { -334.224, -1958.480, 20.300, -0.290, -0.346, 0.892, 5 },
        { -334.888, -1961.526, 20.117, 0.290, 0.346, 0.892, 6 },
        { -333.113, -1959.412, 20.117, -0.290, -0.346, 0.892, 6 },
    },
}

-- ------------------------------------------------------------------ the crowd (client/crowd.lua, server/crowd.lua)
-- People in the house: the bowl's seats, the floor chairs of the shows that have them, the concert's standing floor.
-- Staff bring the crowd in, send it home and set its mood with /arenacrowd or the desk's Crowd buttons. Everyone is a
-- local ped (not networked): each player makes their own copy - the same person in the same seat doing the same
-- thing - and only while they are inside the arena. A game client can draw a couple of hundred peds, not seventeen
-- thousand seats' worth: the spots (client/crowd_slots.lua, from the build) fill in a fixed order, ringside and the
-- lower rows first, and the ones near you before the far side of the bowl.
Config.CrowdCommand = 'arenacrowd'
Config.CrowdAccess = 'command.arena'   -- who may bring the crowd in and set its mood: an ACE, false = anyone
Config.CrowdDefault = { on = false, mood = 'show', staff = true, litter = 'clean' }
Config.CrowdPresetMoods = true         -- the light desk's presets set the crowd's mood too (Config.LightPresets[...].mood)
Config.Crowd = {
    MaxPeds = 210,             -- crowd peds per player; /arenacrowd mine <n> sets it for you (saved on your PC)
    MaxPedsLimit = 240,        -- the most a player may ask for
    PoolLimit = 240,           -- no more are made while the game holds this many peds of any kind: it has room for 256
                               -- and FiveM can't raise that (increase_pool_size has no ped pool), the rest is headroom
                               -- for the players and the street outside
    DespawnDistance = 160.0,   -- m from the middle of the bowl: outside the arena and further away than this, they go
    PerTick = 5, TickMs = 50,  -- peds made per step (spread out so a crowd coming in does not hitch)
    FadeMs = 400,              -- each one fades in over this long instead of popping up (0 = they just appear)
    NearShare = 0.5,           -- this share of your people fill the seats round you, the rest the house's fixed order
    NearBoost = 0.6,           -- how far the spots near you jump the queue for that share (0 = the fixed order only) ...
    NearRadius = 45.0,         -- ... within this many metres of you, fading to nothing at the edge
    SitZ = 0.0,                -- nudge the seated people up / down (m) if they float over or sink into the seats
    Collision = true,          -- false: players walk through the crowd
    Room = 'bowl',             -- the interior room they stand in (every spot is in the bowl); false = leave it to the game
    SeatScenario = 'PROP_HUMAN_SEAT_BENCH',
    -- the entity sets that decide the stage end: its retractable lower sections are seats with SeatedSet, its upper
    -- seats are behind the drapes with MaskSet
    SeatedSet = 'mzb_set_low_nw_seated',
    MaskSet = 'mzb_set_mask_nw',
    -- a show's own mix instead of Models, e.g. ShowModels = { hockey = { 'a_m_y_stwhi_01', 'a_m_m_hillbilly_01' } }
    ShowModels = {},
    -- an arena crowd: a mix of everyone (repeats = more of them)
    Models = {
        'a_m_y_hipster_01', 'a_m_y_hipster_02', 'a_m_y_hipster_03', 'a_f_y_hipster_01', 'a_f_y_hipster_02',
        'a_f_y_hipster_03', 'a_f_y_hipster_04', 'a_m_y_skater_01', 'a_m_y_skater_02', 'a_f_y_skater_01',
        'a_m_y_vinewood_01', 'a_m_y_vinewood_02', 'a_m_y_vinewood_03', 'a_m_y_vinewood_04', 'a_f_y_vinewood_01',
        'a_f_y_vinewood_02', 'a_f_y_vinewood_03', 'a_f_y_vinewood_04', 'a_m_y_genstreet_01', 'a_m_y_genstreet_02',
        'a_m_y_stwhi_01', 'a_m_y_stwhi_02', 'a_m_y_downtown_01', 'a_m_y_beachvesp_01', 'a_m_y_beachvesp_02',
        'a_m_y_eastsa_01', 'a_m_y_eastsa_02', 'a_f_y_eastsa_01', 'a_f_y_eastsa_03', 'a_m_y_soucent_01',
        'a_m_y_latino_01', 'a_m_y_ktown_01', 'a_m_y_polynesian_01', 'a_f_y_indian_01', 'a_m_y_indian_01',
        'a_f_y_clubcust_01', 'a_f_y_clubcust_02', 'a_m_y_clubcust_01', 'a_m_y_clubcust_02', 'a_f_y_beach_01',
        'a_m_y_beach_01', 'a_m_y_beach_03', 'a_m_y_runner_01', 'a_m_y_hippy_01', 'a_f_y_hippie_01',
        'a_m_m_salton_01', 'a_m_y_salton_01', 'a_m_m_hillbilly_01', 'a_m_y_gay_01', 'a_m_m_mlcrisis_01',
        'a_f_y_tourist_01', 'a_m_m_tourist_01', 'a_m_y_bevhills_01', 'a_f_y_bevhills_02', 'a_f_y_scdressy_01',
        'a_f_m_bevhills_01', 'a_m_m_bevhills_01', 'a_f_y_genhot_01', 'a_m_o_genstreet_01', 'a_f_m_downtown_01',
    },
}

-- the animations the crowd uses (all from the base game): { dict, clip [, flag] [, f = female] }
-- flag 1 = loop (default), 49 = loop the upper body only
Config.CrowdAnims = {
    handsup   = { 'anim@amb@nightclub@lazlow@hi_dancefloor@', 'crowddance_hi_11_handup_laz' },
    handsup2  = { 'anim@amb@nightclub@lazlow@hi_dancefloor@', 'dancecrowd_li_15_handup_laz' },
    shimmy    = { 'anim@amb@nightclub@lazlow@hi_dancefloor@', 'dancecrowd_li_11_hu_shimmy_laz' },
    facedj    = { 'anim@amb@nightclub_island@dancers@crowddance_facedj@', 'mi_dance_facedj_17_v2_male^4',
                  f = { 'anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity', 'hi_dance_facedj_09_v2_female^1' } },
    facedj2   = { 'anim@amb@nightclub_island@dancers@crowddance_facedj@', 'mi_dance_facedj_15_v2_male^4',
                  f = { 'anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity', 'hi_dance_facedj_09_v2_female^3' } },
    facedjhu  = { 'anim@amb@nightclub_island@dancers@crowddance_facedj@', 'hi_dance_facedj_hu_15_v2_male^5' },
    facedjhu2 = { 'anim@amb@nightclub_island@dancers@crowddance_facedj@', 'hi_dance_facedj_hu_17_male^5' },
    groove    = { 'anim@amb@nightclub_island@dancers@crowddance_groups@groupd@', 'mi_dance_crowd_13_v2_male^1' },
    sway      = { 'anim@amb@nightclub@mini@dance@dance_solo@male@var_b@', 'low_center',
                  f = { 'anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', 'low_center' } },
    bounce    = { 'anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', 'high_center',
                  f = { 'anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', 'high_center' } },
    clap      = { 'amb@world_human_cheering@male_a', 'base' },
    slowclap  = { 'anim@mp_player_intupperslow_clap', 'idle_a', 49 },
    horns     = { 'anim@mp_player_intincarrockstd@ps@', 'idle_a', 49 },
    airguitar = { 'anim@mp_player_intcelebrationfemale@air_guitar', 'air_guitar' },
    crossarms = { 'amb@world_human_hang_out_street@female_arms_crossed@idle_a', 'idle_a' },
    -- the staff's (Config.CrowdRoles)
    guard     = { 'anim@amb@nightclub@peds@', 'rcmme_amanda1_stand_loop_cop' },
    desklean  = { 'anim@amb@board_room@diagram_blueprints@', 'idle_01_amy_skater_01' },
    shouldercam = { 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman', 49 },
    kneel     = { 'amb@medic@standing@kneel@base', 'base' },
}

-- what the crowd does per mood: { action, weight }; an action is a Config.CrowdAnims key or a scenario ('s:NAME').
--   sit    the share of the people with a seat who sit in it (1 = everyone, 0 = the whole house on its feet)
--   seats  what the ones on their feet do, standing in their row
--   floor  what the standing floor does (the concert's general admission and the people on its barricade)
-- doors: finding their seats, waiting. show: watching. peak: the big moment. cheer: applause.
Config.CrowdMoods = {
    doors = {
        sit = 0.9,
        seats = { { 's:WORLD_HUMAN_STAND_MOBILE', 3 }, { 's:WORLD_HUMAN_HANG_OUT_STREET', 2 }, { 's:WORLD_HUMAN_DRINKING', 2 },
                  { 's:WORLD_HUMAN_STAND_IMPATIENT', 1 }, { 'crossarms', 1 } },
        floor = { { 's:WORLD_HUMAN_STAND_MOBILE', 3 }, { 's:WORLD_HUMAN_HANG_OUT_STREET', 3 }, { 's:WORLD_HUMAN_DRINKING', 3 },
                  { 'crossarms', 2 }, { 'sway', 1 } },
    },
    show = {
        sit = 0.85,
        seats = { { 'clap', 3 }, { 's:WORLD_HUMAN_MOBILE_FILM_SHOCKING', 3 }, { 's:WORLD_HUMAN_CHEERING', 2 },
                  { 'crossarms', 1 }, { 'sway', 1 } },
        floor = { { 'facedj', 3 }, { 'facedj2', 2 }, { 'groove', 2 }, { 'handsup2', 2 }, { 'horns', 2 },
                  { 's:WORLD_HUMAN_CHEERING', 2 }, { 's:WORLD_HUMAN_MOBILE_FILM_SHOCKING', 2 }, { 'airguitar', 1 } },
    },
    peak = {
        sit = 0.0,
        seats = { { 's:WORLD_HUMAN_CHEERING', 4 }, { 'clap', 3 }, { 'handsup2', 2 }, { 'bounce', 2 },
                  { 's:WORLD_HUMAN_MOBILE_FILM_SHOCKING', 2 }, { 'horns', 1 } },
        floor = { { 'facedjhu', 3 }, { 'facedjhu2', 3 }, { 'handsup', 3 }, { 'handsup2', 2 }, { 'shimmy', 2 },
                  { 'horns', 2 }, { 'airguitar', 1 }, { 's:WORLD_HUMAN_MOBILE_FILM_SHOCKING', 1 } },
    },
    cheer = {
        sit = 0.25,
        seats = { { 's:WORLD_HUMAN_CHEERING', 3 }, { 'clap', 3 }, { 'slowclap', 2 }, { 's:WORLD_HUMAN_MOBILE_FILM_SHOCKING', 1 } },
        floor = { { 's:WORLD_HUMAN_CHEERING', 4 }, { 'clap', 3 }, { 'handsup2', 2 }, { 'slowclap', 1 },
                  { 's:WORLD_HUMAN_MOBILE_FILM_SHOCKING', 1 } },
    },
}
Config.CrowdMoodOrder = { 'doors', 'show', 'peak', 'cheer' }   -- the desk's mood buttons, in this order

-- ------------------------------------------------------------------ the staff and the press (client/crowd.lua)
-- They come in with the crowd: security inside the barricades with their backs to the action, photographers (their
-- cameras flash), camera operators (a shoulder camera, or behind a tripod camera), crew, ball kids, and officials who
-- sit at the scorer's table, in the umpire's chair, on the line judges' chairs and at the timekeeper's desk. Where
-- they stand comes from the build (Config.CrowdStaff in client/crowd_slots.lua, per show); who stands there is set
-- here, per role:
--   models  the peds (one is picked per spot, the same on every client)
--   acts    what they do: { action, weight } as in Config.CrowdMoods (a Config.CrowdAnims key or 's:SCENARIO')
--   prop    held once their act has started: { model, ped bone, x, y, z, rx, ry, rz }
--   stand   put down in front of them: { model, how far ahead (m), the model's origin over the floor (m), its turn
--           from their heading (deg) } - the tripod camera's lens is its -y, so it turns 180 to face where they do
-- Whoever has a seat on their spot sits in it (Config.Crowd.SeatScenario, nudged by Config.Crowd.SitZ like the crowd).
-- The staff do not count against a player's own crowd size (a show has 9 to 18 of them); /arenacrowd mine 0 hides
-- them too. Staff send them home with /arenacrowd staff off (the desk's STAFF button); false here: never.
Config.CrowdStaffEnabled = true

-- ------------------------------------------------------------------ fights (client/fights.lua, server/fights.lua)
-- Bouts in the wrestling ring and the MMA cage: watch two NPCs fight, put a card of bouts on (one after another, or
-- at a time), take on an NPC yourself, or fight another player. The server runs every bout: it makes the NPC fighters
-- (networked, so everyone sees the same fight; the client they belong to throws their punches), rings the bell, and
-- calls the knockout from the fighters' health. Nobody dies: a fighter whose health falls to koHealth is down, and
-- the loser gets up healed. A fighter out of the ring for countOut seconds loses; after the last round the one with
-- more health left wins. The crowd and the lights go with it (moods / presets below), and the fight bar at the top of
-- the screen shows everyone in the arena the names, their health, the round and the clock.
--   staff:  /arenafight npc [in <min>] | vs <id> [in <min>] | pvp <id> <id> [in <min>] | stop | clear | card,
--           or the desk's Fights section
--   anyone: /arenafight challenge (an NPC) | challenge <id> (a player, who answers /arenafight accept) | status
-- Fighting another player needs the server to let players hurt each other (most do). The building has no ped navmesh
-- yet: the NPCs start face to face in the ring and are held inside it.
Config.Fights = {
    enabled = true,
    command = 'arenafight',
    access = nil,                -- who runs the card: an ACE, false = anyone, nil = the same as the lights
    challenge = true,            -- anyone may challenge an NPC or another player (false: staff only)
    rounds = 3, roundSeconds = 60, breakSeconds = 15,
    introSeconds = 12,           -- the walk-out: the names on the screen, the fighters to their corners
    overSeconds = 10,            -- the winner celebrates, the loser is helped up
    gap = 20,                    -- s between two bouts of the card
    koHealth = 125,              -- down at this much health (players have 200 and die under 100; the NPCs get 200)
    reach = 1.6,                 -- m: an NPC fighter walks at the other one until this close, then throws punches
    countOut = 10,               -- s out of the ring before a fighter loses
    inviteSeconds = 30,          -- s to answer a challenge
    cooldown = 30,               -- s between two challenges from one player
    maxCard = 10,                -- bouts on the card at most
    followspot = true,           -- a followspot that is on follows the player fighters (Config.FollowSpot)
    presets = { intro = 'entrance', round = 'fight', over = 'goal' },   -- light presets (Config.LightPresets); false: none
    moods = { intro = 'peak', round = 'show', over = 'cheer' },          -- the crowd's (Config.CrowdMoods); false: none
    sounds = { bell = { 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET' }, ko = { 'Bed', 'WastedSounds' } },
    anims = {
        warmup = { 'anim@mp_player_intcelebrationmale@shadow_boxing', 'shadow_boxing' },
        win = { 'rcmfanatic1celebrate', 'celebrate' },
        down = { 'combat@damage@writhe', 'writhe_loop' },
    },
    models = { 'a_m_y_musclbeac_01', 'a_m_y_musclbeac_02', 'u_m_y_babyd', 'u_m_y_imporage', 'a_m_y_beach_02',
               'g_m_y_mexgoon_02', 's_m_y_robber_01', 'g_m_y_ballaeast_01' },
    names = { 'The Vinewood Viper', 'Big Mike Sandoval', 'Rocco "Hammer" Bianchi', 'El Toro', 'Kid Dynamite',
              'The Butcher of Banning', 'Iron Ivan', 'Dutch Van Dam', 'Smooth Tony Lu', 'Mad Dog Marlowe',
              'The Rancho Rocket', 'Big Steve Okafor' },
    -- where they fight, per show: a square of half side `half` or a circle of `radius` round the arena's middle
    -- (Config.ArenaFrame), the canvas height, and the corners { u, v } in the arena's frame (u along it, v across)
    venues = {
        wrestling = { shape = 'square', half = 3.4, z = 20.77, red = { -2.6, -2.6 }, blue = { 2.6, 2.6 } },
        mma = { shape = 'circle', radius = 4.1, z = 20.75, red = { -3.2, 0.0 }, blue = { 3.2, 0.0 } },
    },
}

-- ------------------------------------------------------------------ props of your own (client/props.lua)
-- Vanilla props put down for a show without CodeWalker: { model, x, y, z, heading [, ground = true] }. x y z is where
-- the model's own origin goes (CreateObjectNoOffset); ground = true sets it down on the floor under it instead. Local
-- props, frozen, made while you are in the arena; /arenainfo prints where you stand. Two ready to try (take the --
-- off): a camera crane on the wrestling stage deck's +v side, its arm along the arena (turn it 180 if the camera end
-- faces the titantron), and a green screen for interviews - pick its place in the media room or backstage.
Config.ShowProps = {
    -- wrestling = {
    --     { 'prop_dolly_02', -336.218, -1946.076, 21.05, 320.0, ground = true },     -- the movie set's camera crane
    --     { 'prop_ld_greenscreen_01', x, y, z, heading, ground = true },             -- 5.5 x 4.2 x 3.2 m
    -- },
}

-- ------------------------------------------------------------------ litter (client/litter.lua)
-- What a crowd leaves behind: cups, cans, wrappers, food bags and bottles in the rows and on the floor. Staff set how
-- much from the desk's Crowd section or /arenacrowd litter <clean|some|trashed>; it stays when the crowd goes home.
-- It lies at the crowd's own spots (client/crowd_slots.lua) of the show that is up, each piece picked from its spot,
-- so everyone sees the same mess ("some" is always part of "trashed"). Local props, frozen and without collision;
-- only the nearest Max of them within Radius of you are put down.
Config.Litter = {
    enabled = true,
    Radius = 60.0,              -- m from you
    Max = 260,                  -- pieces at most per player
    Share = { some = 0.07, trashed = 0.28 },   -- the share of the spots with something at their feet
    PerTick = 12,               -- pieces put down per step of 50 ms
    -- { model, weight, its origin over the floor (m) - from the game's own bounds, so nothing floats or sinks }
    Models = {
        { 'ng_proc_sodacup_01a', 4, 0.0 }, { 'ng_proc_sodacup_02a', 4, 0.0 }, { 'prop_plastic_cup_02', 3, 0.086 },
        { 'ng_proc_sodacan_01a', 2, 0.0 }, { 'prop_ecola_can', 2, 0.064 }, { 'ng_proc_beerbottle_01a', 2, 0.0 },
        { 'ng_proc_paper_burger01a', 3, 0.003 }, { 'prop_cs_burger_01', 1, 0.035 }, { 'ng_proc_food_bag01a', 2, 0.001 },
        { 'ng_proc_paper_01a', 3, 0.0 }, { 'prop_rub_litter_05', 2, 0.0 }, { 'prop_rub_litter_09', 1, 0.045 },
        { 'prop_food_bs_tray_01', 1, 0.0 },
    },
}
Config.CrowdRoles = {
    security = { models = { 's_m_m_security_01', 's_m_m_highsec_01', 's_m_m_bouncer_01' },
                 acts = { { 's:WORLD_HUMAN_GUARD_STAND', 2 }, { 'guard', 2 }, { 'crossarms', 1 } } },
    photo    = { models = { 'a_m_m_paparazzi_01', 'u_m_y_paparazzi' }, acts = { { 's:WORLD_HUMAN_PAPARAZZI', 1 } } },
    shoulder = { models = { 's_m_y_grip_01', 's_m_m_gaffer_01' }, acts = { { 'shouldercam', 1 } },
                 prop = { 'prop_v_cam_01', 28422, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 } },
    camera   = { models = { 's_m_y_grip_01', 's_m_m_gaffer_01' }, acts = { { 'desklean', 1 } } },   -- at a set's camera
    tvcam    = { models = { 's_m_y_grip_01', 's_m_m_gaffer_01' }, acts = { { 'desklean', 1 } },
                 stand = { 'prop_tv_cam_02', 1.05, 1.006, 180.0 } },
    crew     = { models = { 's_m_y_grip_01', 's_m_m_lathandy_01', 's_m_m_gaffer_01' },
                 acts = { { 'crossarms', 2 }, { 's:WORLD_HUMAN_CLIPBOARD', 1 }, { 's:WORLD_HUMAN_STAND_MOBILE', 1 } } },
    ballkid  = { models = { 'a_m_y_runner_01', 'a_f_y_runner_01', 'a_m_y_runner_02' }, acts = { { 'kneel', 1 } } },
    official = { models = { 'a_m_y_business_01', 'a_m_y_business_02', 'a_f_y_business_01', 'a_m_m_business_01' },
                 acts = { { 'crossarms', 1 } } },
    -- the concourse's (Config.CrowdConcourse; crowd = true: the crowd's own mix, Config.Crowd.Models)
    vendor    = { models = { 's_m_y_busboy_01', 's_f_y_shop_low', 's_m_y_waiter_01', 's_f_y_shop_mid' },
                  acts = { { 's:WORLD_HUMAN_STAND_IMPATIENT', 2 }, { 'crossarms', 1 } } },
    bartender = { models = { 's_m_y_barman_01', 's_f_y_bartender_01' },
                  acts = { { 's:WORLD_HUMAN_STAND_IMPATIENT', 2 }, { 'crossarms', 1 } } },
    cook      = { models = { 's_m_m_linecook' }, acts = { { 's:PROP_HUMAN_BBQ', 1 } } },
    clerk     = { models = { 's_f_y_shop_mid', 's_f_y_shop_low', 's_m_y_busboy_01' },
                  acts = { { 's:WORLD_HUMAN_STAND_IMPATIENT', 2 }, { 'crossarms', 1 } } },
    medic     = { models = { 's_m_m_paramedic_01', 's_f_y_scrubs_01' },
                  acts = { { 's:WORLD_HUMAN_CLIPBOARD', 1 }, { 'crossarms', 1 } } },
    janitor   = { models = { 's_m_m_janitor' }, acts = { { 's:WORLD_HUMAN_JANITOR', 1 } } },
    fan       = { crowd = true, acts = { { 's:WORLD_HUMAN_STAND_MOBILE', 3 }, { 's:WORLD_HUMAN_STAND_IMPATIENT', 2 },
                                         { 's:WORLD_HUMAN_DRINKING', 2 }, { 's:WORLD_HUMAN_HANG_OUT_STREET', 2 },
                                         { 'crossarms', 1 } } },
}

-- the people on the concourse (Config.CrowdConcourse in client/crowd_slots.lua, from the build): vendors and
-- bartenders behind the tills with their queues, cooks in the kitchens, the shops' clerks, guards at the security
-- office and the gateway checkpoints, medics, cleaners, people at the lobbies' high tables. They come in with the
-- crowd - the ones nearest you, MaxPeds at most within Radius (FromBowl while you are in the bowl: the seats get the
-- peds) - and the staff among them go home with the staff.
Config.Concourse = { enabled = true, MaxPeds = 36, FromBowl = 8, Radius = 45.0 }
