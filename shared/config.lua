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
                        intensity = 0.8, focus = 'floor', ring = false, house = 'show' }
-- the ring lights (the desk's RING LIGHTS button, /arenalights ring on): the show rig's washes over the ring / cage /
-- stage (rig group 2) light it white on their own aim, whether the show lights are on or not
Config.RingLightGroup = 2
Config.RingLightColor = { 255, 244, 225 }
Config.RingLightBrightness = 16.0
-- named colours for chat (/arenalights color red blue) and the desk's palette
Config.LightColors = {
    white = { 255, 255, 255 }, warm = { 255, 196, 120 }, red = { 255, 24, 24 }, orange = { 255, 110, 0 },
    amber = { 255, 170, 0 }, yellow = { 255, 230, 20 }, green = { 20, 255, 60 }, cyan = { 0, 230, 255 },
    blue = { 20, 60, 255 }, purple = { 140, 30, 255 }, magenta = { 255, 20, 200 }, pink = { 255, 90, 150 },
}
-- one-touch looks (the desk's preset buttons, /arenalights preset <name>); nil fields keep what is set
Config.LightPresets = {
    walkin    = { label = 'Walk-in',   on = true,  mode = 'pulse', move = 'none',    colors = { { 20, 60, 255 }, { 140, 30, 255 } }, bpm = 50,  focus = 'crowd', house = 'dim' },
    entrance  = { label = 'Entrance',  on = true,  mode = 'sweep', move = 'none',    colors = { { 255, 24, 24 }, { 255, 255, 255 } }, bpm = 128, focus = 'stage', house = 'off' },
    goal      = { label = 'Goal!',     on = true,  mode = 'strobe', move = 'none',   colors = { { 255, 24, 24 }, { 255, 255, 255 } }, bpm = 150, focus = 'floor', house = 'off' },
    concert   = { label = 'Concert',   on = true,  mode = 'chase', move = 'none',    colors = { { 255, 20, 200 }, { 0, 230, 255 }, { 255, 255, 255 } }, bpm = 124, focus = 'stage', house = 'off' },
    party     = { label = 'Party',     on = true,  mode = 'rainbow', move = 'none',  bpm = 128, focus = 'floor', house = 'off' },
    fight     = { label = 'Fight',     on = true,  mode = 'ballyhoo', move = 'none', colors = { { 255, 255, 255 }, { 255, 24, 24 } }, bpm = 90, focus = 'floor', house = 'dim' },
    police    = { label = 'Police',    on = true,  mode = 'police', move = 'none',   bpm = 120, focus = 'floor', house = 'dim' },
    tv        = { label = 'TV ring',   on = false, ring = true, house = 'dim' },
    storm     = { label = 'Storm',     on = true,  mode = 'lightning', move = 'none', colors = { { 20, 60, 255 } }, bpm = 90, focus = { 'floor', 'crowd' }, house = 'off' },
    inferno   = { label = 'Inferno',   on = true,  mode = 'fire',     move = 'nod', bpm = 70, focus = { 'stage', 'crowd' }, house = 'off' },
    hype      = { label = 'Hype',      on = true,  mode = 'flash',    move = 'fan', colors = { { 255, 255, 255 }, { 255, 170, 0 } }, bpm = 128, focus = { 'floor', 'crowd' }, house = 'off' },
    houseup   = { label = 'House up',  on = false, house = 'full' },
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
    -- picture sets for /arenascreen images [name]: https URLs, or files of this resource under html/img/ (add them to
    -- the folder; fxmanifest.lua already ships everything in it). A set is shown in this order, Config.Media.interval
    -- seconds each.
    imageSets = {
        -- default = { 'img/sponsor1.png', 'img/sponsor2.png', 'https://example.com/poster.jpg' },
    },
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
    refDistance = 12.0,          -- m from the nearest hang at which the level starts to fall
    minGain = 0.3,               -- the level never falls below this in the room (the far end of the bowl)
    pan = 0.6,                   -- how far the sound pans left / right to the hangs (0 = not at all, 1 = fully)
    reverbSeconds = 3.2,         -- the length of the arena's echo
    -- the room's sound per Config.Listener zone: a low-pass filter (Hz) and how much echo is mixed in (0-1)
    rooms = {
        bowl = { lowpass = 20000, wet = 0.30 },
        near = { lowpass = 1100, wet = 0.22 },
        building = { lowpass = 420, wet = 0.12 },
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
        { -348.084, -1956.484, 20.550, 0.231, -0.194, 0.954, 4 },    -- floor beams, back of the stage
        { -346.156, -1954.186, 20.550, 0.231, -0.194, 0.954, 4 },
        { -342.299, -1949.589, 20.550, 0.231, -0.194, 0.954, 4 },
        { -340.370, -1947.291, 20.550, 0.231, -0.194, 0.954, 4 },
    },
    concert = {
        { -343.293, -1960.601, 31.777, -0.207, 0.319, -0.925, 2 },  -- the wash bar over the stage
        { -341.058, -1957.937, 31.776, -0.271, 0.246, -0.931, 2 },
        { -338.822, -1955.273, 31.777, -0.332, 0.170, -0.928, 2 },
        { -336.586, -1952.609, 31.779, -0.390, 0.094, -0.916, 2 },
        { -334.349, -1949.945, 31.784, -0.443, 0.020, -0.896, 2 },
        { -348.084, -1956.484, 20.550, 0.231, -0.194, 0.954, 4 },    -- floor beams, back of the stage
        { -346.156, -1954.186, 20.550, 0.231, -0.194, 0.954, 4 },
        { -342.299, -1949.589, 20.550, 0.231, -0.194, 0.954, 4 },
        { -340.370, -1947.291, 20.550, 0.231, -0.194, 0.954, 4 },
    },
    mma = {
        { -348.084, -1956.484, 20.550, 0.231, -0.194, 0.954, 4 },    -- floor beams, back of the stage
        { -346.156, -1954.186, 20.550, 0.231, -0.194, 0.954, 4 },
        { -342.299, -1949.589, 20.550, 0.231, -0.194, 0.954, 4 },
        { -340.370, -1947.291, 20.550, 0.231, -0.194, 0.954, 4 },
    },
}
