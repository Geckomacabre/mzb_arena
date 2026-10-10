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
-- mzb_set_low_front_seated / _stowed: the lower tier's front seven rows are a set of their own (since 1.2.0) - seated
-- in every show there was before, or folded back all round for the shows that need the bigger floor (70.6 x 40.6 m
-- instead of 60 x 30 m). With them folded, mzb_set_low_nw_back is the stage end's telescopic sections with only
-- rows 8 to 20 out. A show that names neither of the two front sets (a show of your own from before 1.2.0) is given
-- the seated rows by the scripts, so it keeps rows 1 to 7.
-- mzb_set_merch_<style>: the lobby merch stand dressed for the show (its shirts, its posters); what the stand's
-- seller has for sale goes by the same style (Config.Merch).
Config.Shows = {
    house     = { 'mzb_set_house_lights', 'mzb_set_low_nw_seated',
                  'mzb_set_low_front_seated', 'mzb_set_merch_arena' },   -- the empty arena, house lights up
    wrestling = { 'mzb_set_wwe_ring', 'mzb_set_wwe_stage', 'mzb_set_wwe_floor', 'mzb_set_wwe_rig',
                  'mzb_set_mask_nw', 'mzb_set_house_lights_dim',
                  'mzb_set_low_nw_stowed', 'mzb_set_low_front_seated',
                  'mzb_set_merch_wrestling' },                           -- the ring show, the house dimmed
    concert   = { 'mzb_set_nw_deck', 'mzb_set_con_stage', 'mzb_set_con_rig', 'mzb_set_con_floor',
                  'mzb_set_mask_nw', 'mzb_set_house_lights_dim',
                  'mzb_set_low_nw_stowed', 'mzb_set_low_front_seated',
                  'mzb_set_merch_concert' },                             -- end-stage concert, standing floor
    hockey    = { 'mzb_set_hockey', 'mzb_set_hockey_board', 'mzb_set_house_lights',
                  'mzb_set_low_nw_seated', 'mzb_set_low_front_seated',
                  'mzb_set_merch_hockey' },                              -- the ice rink, boards and glass
    basketball = { 'mzb_set_basketball', 'mzb_set_basketball_board', 'mzb_set_house_lights',
                  'mzb_set_low_nw_seated', 'mzb_set_low_front_seated',
                  'mzb_set_merch_basketball' },                          -- the hardwood court, courtside seats
    tennis    = { 'mzb_set_tennis', 'mzb_set_tennis_board', 'mzb_set_house_lights',
                  'mzb_set_low_nw_seated', 'mzb_set_low_front_seated',
                  'mzb_set_merch_tennis' },                              -- the hard court, the umpire's chair
    mma       = { 'mzb_set_nw_deck', 'mzb_set_mma_stage', 'mzb_set_mma_cage', 'mzb_set_mma_floor',
                  'mzb_set_mma_rig', 'mzb_set_mask_nw', 'mzb_set_house_lights_dim',
                  'mzb_set_low_nw_stowed', 'mzb_set_low_front_seated',
                  'mzb_set_merch_mma' },                                 -- fight night: the cage, end stage
    -- the bigger floor's shows (the front rows folded back all round; no stage, no ring, no floor chairs). floor is
    -- the big floor with nothing on it and the house lights up: for an event of your own (a car show, a drift night)
    floor     = { 'mzb_set_house_lights',
                  'mzb_set_low_front_stowed', 'mzb_set_low_nw_back',
                  'mzb_set_merch_arena' },                               -- the open floor
    monster   = { 'mzb_set_monster', 'mzb_set_house_lights',
                  'mzb_set_low_front_stowed', 'mzb_set_low_nw_back',
                  'mzb_set_merch_monster' },                             -- the monster truck show: clay floor, the painted jump
    motocross = { 'mzb_set_motocross', 'mzb_set_house_lights',
                  'mzb_set_low_front_stowed', 'mzb_set_low_nw_back',
                  'mzb_set_merch_motocross' },                           -- arenacross: a dirt track of jumps, whoops and berms
    karting   = { 'mzb_set_karting', 'mzb_set_house_lights',
                  'mzb_set_low_front_stowed', 'mzb_set_low_nw_back',
                  'mzb_set_merch_racing' },                              -- kart circuit: the Grand Prix, with a flyover
    sprint    = { 'mzb_set_sprint', 'mzb_set_house_lights',
                  'mzb_set_low_front_stowed', 'mzb_set_low_nw_back',
                  'mzb_set_merch_racing' },                              -- kart circuit: the Sprint
    oval      = { 'mzb_set_oval', 'mzb_set_house_lights',
                  'mzb_set_low_front_stowed', 'mzb_set_low_nw_back',
                  'mzb_set_merch_racing' },                              -- kart circuit: the Oval, banked ends
    skatepark = { 'mzb_set_skate_park', 'mzb_set_skate_vert', 'mzb_set_skate_dress', 'mzb_set_house_lights',
                  'mzb_set_low_front_stowed', 'mzb_set_low_nw_back',
                  'mzb_set_merch_skatepark' },                           -- the skate park: park course and vert ramp
}
-- What the scripts look up per show - the screens' model, the light rig and its aim, the speakers, the screens'
-- artwork - a show without an entry of its own takes from the empty house: the centre-hung board and the roof's
-- house lights (client/interior.lua: MzbShowEntry). The big-floor shows rely on that, and so can a show of yours.
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
    bigfloor = 'floor', open = 'floor', openfloor = 'floor',
    monstertrucks = 'monster', trucks = 'monster',
    kart = 'karting', karts = 'karting', gp = 'karting',
    skate = 'skatepark',
    mx = 'motocross', arenacross = 'motocross', dirtbikes = 'motocross',
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
    tennis = { 'Tennis', 'table-tennis-paddle-ball' }, floor = { 'Open floor', 'expand' },
    monster = { 'Monster trucks', 'truck-monster' }, motocross = { 'Arenacross', 'motorcycle' },
    karting = { 'Karting: Grand Prix', 'flag-checkered' },
    sprint = { 'Karting: Sprint', 'stopwatch' }, oval = { 'Karting: Oval', 'rotate' },
    skatepark = { 'Skate park', 'person-skating' },
}

-- ------------------------------------------------------------------ the light desk (client/lights.lua, server/lights.lua)
-- The arena's own light show: coloured spot lights from the show's rig (its moving heads and washes) and the house
-- lights up in the roof, the same for every player (synced to the network clock). Open the desk with /arenalights, or
-- run it from chat: /arenalights help. The baked lights of the interior stay as they are; the desk's house buttons
-- switch them between the show's setting, full, dimmed and off. A look is a colour effect (mode) and a movement (move)
-- picked independently, one or more aims (floor, stage, crowd: the fixtures take turns), and the ring lights.
Config.LightCommand = 'arenalights'
Config.LightDeskKey = ''               -- a key that opens the desk (e.g. 'F6'); '' = none until a player binds one in
                                       -- the game's settings (Key Bindings > FiveM > "Maze Bank Arena: open the desk")
Config.LightAccess = 'command.arena'   -- who may run the lights: an ACE (default: the arena's staff ACE), false = anyone
Config.LightMaxFixtures = 40           -- spot lights drawn per frame at most (the show rigs have 24 to 38, up to 48 with
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
                        intensity = 0.8, focus = 'floor', ring = true, ringLevel = 1.0, house = 'show', ringv = 2,
                        follow = 'off' }
-- the lights follow the music (the desk's "Follow the music", /arenalights follow <off|on|tempo|colour>). Each
-- player's own game listens to the track it is playing (html/follow.js, on the music player's sound: the kick drum's
-- hits make the beat) and looks at the picture of the video it comes from (a YouTube track, or the screens' video
-- while its sound comes from the speakers) for its two or three main colours. tempo: the effects run on the music's
-- beat instead of the Speed slider; colour: the colour slots are the picture's colours. Where there is nothing to
-- follow - no track, a pause, a file without a picture - the desk's own speed and colours stay.
Config.LightFollow = {
    enabled = true,
    punch = 0.35,                -- 0..1: how far the rig dips between two hits (0: only the effect shows the beat)
    dynamics = 0.25,             -- 0..1: how far a quiet passage dims the rig
    colours = 3,                 -- colour slots taken from the picture at most (1-3)
    minBpm = 80,                 -- the tempo found is kept in minBpm .. twice that (a 70 bpm song runs at 140)
    sensitivity = 1.0,           -- over 1: softer hits count as the beat too; under 1: only the hard ones
}
-- the ring lights (the desk's RING LIGHTS button and its colour / level, /arenalights ring ...): the wrestling ring's,
-- the MMA cage's and the concert stage's own lights (Config.RingLights, shared/rig_lights.lua: until 1.1.0 they were
-- baked into the rigs and always on), on by default, in the colours the build gave them or one colour from the desk,
-- whether the show lights are on or not. A show without them uses its rig's washes (group 2) on their own aim.
-- The glow off the video wall onto the stage goes with them (Config.StageGlow, shared/stage_lights.lua). The moving
-- heads on the wrestling stage's trusses (Config.StageLights, the same file) are show lights: both were baked into
-- the stage until 1.1.2, always on in red, white and blue.
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
-- screen = the video screens' look with it (Config.Media.looks, or 'off' = dark, 'own' = the show's own graphics;
-- only while the screens show a look or nothing)
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
    blackout  = { label = 'Blackout',  on = false, ring = false, house = 'off', screen = 'off' },
    reset     = { label = 'Reset',     on = false, mode = 'static', move = 'none', colors = { { 255, 255, 255 } }, bpm = 120, intensity = 0.8, focus = 'floor', ring = false, house = 'show', follow = 'off', screen = 'own' },
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
-- The music plays in a browser, which has no idea where you stand. So the client works it out: the room the game has
-- you in, sorted into the bowl, the rooms next to it, the rest of the building and outside. The music player takes
-- the walls' filter and its level through them from that (the speakers themselves it places from the camera). A room
-- not named here counts as "building" while you are inside the arena's interior.
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
-- with /arenascreen <youtube url | picture url(s) | images [set] | look [player id] | off | pause | resume |
-- loop [on|off] | volume n | status>.
Config.Media = {
    enabled = true,              -- false: no built-in screen player at all (leave the screens to another script)
    command = 'arenascreen',
    access = nil,                -- an ACE, false = anyone, nil = the same as the lights (Config.LightAccess)
    width = 1280, height = 720,  -- the browser's size in pixels (the picture is stretched over every screen)
    range = 160.0,               -- m from the arena's middle: the browser exists only this close, and goes further out
    -- a video's sound: 'speakers' = from the arena's speakers, through the music player (Config.Music: the same
    -- video plays there for its sound, started at the same moment; its level is the music's); 'screen' = the
    -- browser's own sound, which is not placed in the room (the same in both ears
    -- wherever you stand; the two settings below are its level); 'off' = videos are silent
    sound = 'speakers',
    volume = 0.6,                -- 'screen' only: the video's loudness at 100% on the desk, in the bowl
    defaultVolume = 60,          -- 'screen' only: the desk's volume a new video starts at (0-100)
    -- a new video starts this many seconds after the Play: every player's game has it loaded by then, so it starts
    -- at its start for all of them together (0: at once - the first second or so is lost while it loads)
    leadIn = 2.5,
    -- Loop: a video that comes to its end starts again from its beginning, for every player together (after the
    -- same lead-in; its sound from the speakers with it), instead of being switched off. This is what a new video
    -- starts with; the desk's Loop and /arenascreen loop [on|off] change it for the one that is on. Pictures go
    -- round anyway, and a look or a camera feed has no end
    loop = false,
    fade = 3.0,                  -- s a fade-out takes (the desk's Fade out; /arenascreen fade [seconds])
    -- a video that stops takes the show lights out with it: faded out with the picture (Fade out), or over
    -- lightsFade seconds when it is switched off or comes to its end (0 = cut). A video that has ended is switched
    -- off: the screens go to Off instead of sitting on its last frame (a looped one starts again: the screens stay
    -- on and the lights as they are). false: the lights are left as they are
    lightsOut = true,
    lightsFade = 2.0,
    -- Off (the desk's button, /arenascreen off, a blackout) makes the screens dark: a black picture over the show's
    -- own graphics. "Own graphics" (/arenascreen own) lets go of them again, as the arena starts. false: Off is the
    -- show's own graphics, as before 1.2 (set this if another media script should get the screens at Off)
    offBlack = true,
    interval = 8,                -- s per picture in a cycle (the desk / command can change it: 2-120)
    resync = 30,                 -- s between two position checks of a running video (a late or drifting one seeks)
    maxImages = 24,              -- pictures in one cycle at most
    -- how the picture gets onto the screens: 'replace' swaps the screens' texture (replaceTxd / replaceTex) for the
    -- browser's while ours is on, as the Vinewood Bowl's LED wall does; 'rendertarget' draws onto the named render
    -- target every frame, as pmms does. Back to the show's own graphics when ours lets go, either way.
    method = 'replace',
    replaceTxd = 'mzb_tx_show', replaceTex = 'script_rt_mzb_screens',
    -- the browser's page. https://cfx-nui-<resource>/... gives it a web origin, which YouTube needs before it plays
    -- in an embedded player (a nui:// page gets error 153); nil = this resource's html/screen.html at that address
    pageUrl = nil,
    -- picture sets (/arenascreen images [name], the desk's set buttons): files of this resource under html/img/ or
    -- https URLs, shown in this order, Config.Media.interval seconds each. /arenascreen images with no name plays the
    -- show's own set, else 'arena' (the big-floor shows have no pictures of their own yet: they get the arena's).
    -- The pictures are the arena's own graphics (the titantron, the board, the murals).
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
    -- a look's artwork and title per show; a show that is not named here (the big-floor shows: there is no artwork
    -- for them yet) gets the house's
    backdrops = { wrestling = 'img/sapw_tron.jpg', concert = 'img/sirens_poster.jpg', mma = 'img/safc_wall.jpg',
                  hockey = 'img/hockey_live.jpg', basketball = 'img/basketball_live.jpg', tennis = 'img/tennis_live.jpg',
                  house = 'img/arena_welcome.jpg' },
    logos = { wrestling = 'img/sapw_neon.jpg' },   -- the logo over a look (its black is see-through); else the title
    titles = { wrestling = 'SAPW', concert = 'SIRENS OF SAN ANDREAS', mma = 'SAFC', hockey = 'DUST DEVILS',
               basketball = 'LOS SANTOS PANIC', tennis = 'MAZE BANK OPEN', house = 'MAZE BANK ARENA' },
    -- a camera feed: a player's own view of the game, live on the screens (/arenascreen look = yours, /arenascreen
    -- look <player id> = theirs, the desk's "My camera"; /arenascreen look off, which the player whose view it is may
    -- always type). The camera's game sends its picture (the game's own: no chat, no phone, no menus) straight to
    -- every player near the arena, PC to PC (WebRTC, as the phones' video calls do), so the server carries none of
    -- it - and so the camera's PC and each watcher's learn each other's IP address, as in any peer-to-peer call.
    -- With a TURN server in ice and relayOnly = true the picture goes through that server and they do not.
    feed = {
        enabled = true,
        others = true,           -- staff may put another player's view on (that player is told and can take it off)
        width = 640,             -- the picture's width in pixels (its height follows the camera's screen)
        fps = 24,
        bitrate = 700,           -- kbit/s to each watcher at most (the camera's upload is this times the watchers)
        maxViewers = 16,         -- players who get the picture at most; the others see the show's artwork
        hideHud = true,          -- the camera's own radar and HUD are hidden while it is live (they are in the picture)
        flip = false,            -- true if the picture comes out upside down on your game build
        -- how the two PCs find each other: a STUN server (it only tells a PC its own public address). Add a TURN
        -- server ({ urls = 'turn:host:3478', username = '...', credential = '...' }) for players whose routers will
        -- not let them connect directly
        ice = { { urls = 'stun:stun.l.google.com:19302' } },
        relayOnly = false,       -- true: only through the TURN server(s) in ice - no player learns another's address
    },
}

-- ------------------------------------------------------------------ the music player (client/music.lua, server/music.lua)
-- Music off the light desk, heard from the arena's speakers and in no other way: every speaker of the show that is up
-- is a source in the world (html/music.js, Web Audio). You hear each one from where it hangs - nearer is louder, left
-- is left, behind is behind - through the walls from the rooms next to the bowl, with the arena's reverb and the slap
-- off its far end. Nothing is ever played "flat": the page takes the YouTube player's sound (or the audio file's)
-- into its own sound graph, and a track whose sound it cannot take in stays silent and is reported.
-- Links: YouTube, and direct audio files and streams (mp3, ogg, opus, wav, flac, icecast ...). Nothing else is needed
-- on the server. (Should a game update stop the page reaching the YouTube player: relay.enabled below has the server
-- fetch the audio instead, which needs yt-dlp and Deno on the server machine and, on newer server builds, the line
-- add_unsafe_child_process_permission "mzb_arena"  in server.cfg.)
-- Run it from the desk's Music section or /arenamusic <url | pause | resume | stop | loop [on|off] | volume n |
-- status>; every player sets their own level with /arenamusic mine <0-100> (kept between sessions).
Config.Music = {
    enabled = true,
    command = 'arenamusic',
    access = nil,                -- an ACE, false = anyone, nil = the same as the lights (Config.LightAccess)
    volume = 0.8,                -- the loudness at 100% on the desk, next to a speaker
    -- how many times louder the whole of it is turned up after the speakers, the walls, the reverb and the echo (so
    -- their balance stays as it is): 1 = as before the setting, 2 = twice the level (+6 dB), 3 = +9.5 dB. A limiter
    -- behind it holds the loudest peaks, so a hot track gets denser instead of crackling. The screens' video sound
    -- goes the same way (Config.Media.sound = 'speakers')
    boost = 2.0,
    defaultVolume = 70,          -- the desk's volume (0-100) when the resource starts
    range = 200.0,               -- m from the arena's middle: the audio is loaded only this close
    resync = 30,                 -- s between two position checks (a drifting player seeks back)
    -- a new track starts this many seconds after the Play: every player's game has it loaded by then, so nobody
    -- loses its first second (0: at once)
    leadIn = 2.5,
    -- Loop: a track that comes to its end starts again from its beginning, for every player together (after the
    -- same lead-in). This is what a new track starts with; the desk's Loop and /arenamusic loop [on|off] change it
    -- for the one that is playing. A stream has no end to start again from
    loop = false,
    fade = 3.0,                  -- s a fade-out takes (the desk's Fade out; /arenamusic fade [seconds])
    refDistance = 12.0,          -- m from a speaker at which its level starts to fall
    rolloff = 0.7,               -- how fast it falls past that (1 = halved at twice the distance; less = gentler)
    panning = 'HRTF',            -- 'HRTF' (left / right / behind, best on headphones) or 'equalpower' (left / right)
    -- the arena's sound on top of the speakers: a reverb (its length, the gap before it starts) and one echo off the
    -- far end (its delay, how much of it comes round again, its level). echo = false: the reverb only
    reverbSeconds = 3.0,
    preDelay = 0.035,
    echo = { delay = 0.21, feedback = 0.3, level = 0.2 },
    farWet = 0.8,                -- how much more reverb you get far from every speaker (0 = the same everywhere)
    -- per Config.Listener zone: the walls' low-pass filter (Hz) and how much reverb is mixed in (0-1)
    rooms = {
        bowl = { lowpass = 20000, wet = 0.34 },
        near = { lowpass = 1100, wet = 0.3 },
        building = { lowpass = 420, wet = 0.2 },
    },
    -- the server's fetcher (server/relay.js), off unless enabled: the server fetches every track itself (YouTube with
    -- yt-dlp) and hands it to the players from its own HTTP port
    relay = {
        enabled = false,
        ytdlp = nil,             -- the full path of yt-dlp if it is not in <resource>/bin or on the PATH
        deno = nil,              -- the full path of Deno if it is not in <resource>/bin or on the PATH
        ytdlpArgs = nil,         -- more arguments for it, e.g. { '--cookies', 'C:/yt/cookies.txt' }
        maxMB = 100,             -- the biggest file it fetches
        maxMinutes = 90,         -- the longest YouTube video
        timeout = 180,           -- s to fetch a track before giving up
        allowLan = false,        -- true: links into this server's own network (192.168.x.x, localhost) are fetched too
        keepHours = 24,          -- fetched tracks stay in the cache this long (the system's temp folder, or this
                                 -- resource's music_cache folder on a server that lets it write nowhere else)
        cacheMB = 600,           -- ... and the cache stays under this size
    },
    -- the speakers per show (world positions from the arena's build; move them if you move the rig). A speaker is a
    -- vector3, or { vector3, gain } for a quieter one; { vector3, gain, room = '<room>', ref = m } is a speaker in a
    -- room of its own: heard only in that room, as it is (no walls, no arena reverb). A show that is not listed
    -- (the big-floor shows: floor, monster, motocross, karting, sprint, oval, skatepark) plays from the house's: the
    -- centre-hung board
    speakers = {
        wrestling = { vector3(-335.059, -1969.540, 30.75), vector3(-323.370, -1979.349, 30.75),      -- the line arrays
                      vector3(-313.561, -1967.660, 30.75), vector3(-325.250, -1957.851, 30.75) },    -- under the ring truss
        mma = { vector3(-335.059, -1969.540, 28.75), vector3(-323.370, -1979.349, 28.75),
                vector3(-313.561, -1967.660, 28.75), vector3(-325.250, -1957.851, 28.75) },
        concert = { vector3(-347.541, -1966.338, 29.70), vector3(-330.572, -1946.115, 29.70),         -- the PA hangs
                    { vector3(-345.294, -1962.415, 19.88), 0.3 }, { vector3(-343.044, -1959.734, 19.88), 0.3 },   -- the subs
                    { vector3(-340.794, -1957.053, 19.88), 0.3 }, { vector3(-338.544, -1954.372, 19.88), 0.3 },   -- under the
                    { vector3(-336.295, -1951.690, 19.88), 0.3 }, { vector3(-334.045, -1949.009, 19.88), 0.3 },   -- stage's lip
                    { vector3(-347.811, -1955.381, 21.95), 0.2 }, { vector3(-341.525, -1947.889, 21.75), 0.2 },   -- the band's
                    { vector3(-338.650, -1945.863, 21.45), 0.2 } },                                               -- backline
        hockey = { vector3(-324.310, -1968.600, 33.0) },                                              -- the centre-hung board
        basketball = { vector3(-324.310, -1968.600, 33.0) },
        tennis = { vector3(-324.310, -1968.600, 33.0) },
        house = { vector3(-324.310, -1968.600, 33.0) },
        -- every show: the production control room's monitors
        all = { { vector3(-299.419, -2023.022, 20.78), 0.5, room = 'admin', ref = 2.5 },
                { vector3(-288.786, -2031.944, 20.78), 0.5, room = 'admin', ref = 2.5 },
                { vector3(-289.700, -2024.663, 21.22), 0.5, room = 'admin', ref = 2.5 },
                { vector3(-286.214, -2027.588, 21.22), 0.5, room = 'admin', ref = 2.5 } },
    },
}

-- ------------------------------------------------------------------ footsteps (client/footsteps.lua)
-- The game's quiet footsteps while you are inside the building (false: the game's own).
Config.QuietFootsteps = true

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
        { -340.441, -1956.866, 21.019, 0.290, 0.346, 0.892, 1 },
        { -338.667, -1954.751, 21.019, -0.290, -0.346, 0.892, 1 },
        { -339.139, -1957.958, 20.762, 0.290, 0.346, 0.892, 2 },
        { -337.365, -1955.844, 20.762, -0.290, -0.346, 0.892, 2 },
        { -337.837, -1959.051, 20.504, 0.290, 0.346, 0.892, 3 },
        { -336.063, -1956.937, 20.504, -0.290, -0.346, 0.892, 3 },
        { -336.535, -1960.144, 20.246, 0.290, 0.346, 0.892, 4 },
        { -334.760, -1958.030, 20.246, -0.290, -0.346, 0.892, 4 },
        { -335.232, -1961.237, 19.989, 0.290, 0.346, 0.892, 5 },
        { -333.458, -1959.122, 19.989, -0.290, -0.346, 0.892, 5 },
        { -333.930, -1962.329, 19.731, 0.290, 0.346, 0.892, 6 },
        { -332.156, -1960.215, 19.731, -0.290, -0.346, 0.892, 6 },
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
    -- ... and the bigger floor's: with FrontStowedSet the lower tier's front rows are folded back all round (nobody
    -- sits there), with BackSet the stage end's retractable sections have only the rows behind those out
    FrontStowedSet = 'mzb_set_low_front_stowed',
    BackSet = 'mzb_set_low_nw_back',
    -- which rows those are: a seat's depth is how far it is from the event floor's outline (FloorEdge: a rounded
    -- rectangle about the arena's middle - half its length, half its width, its corners' radius, m), and the front
    -- rows are the seats less than FrontDepth deep: rows 1 to 7 (row 7 is 5.8 m in, row 8 6.65 m)
    FloorEdge = { halfL = 30.0, halfW = 15.0, r = 8.5 },
    FrontDepth = 6.2,
    -- rows a show keeps closed: no crowd in a seat less than this deep (m). The truck show has tarps over rows 8
    -- to 10 (row 10 is 8.35 m in, row 11 9.2 m). A show that is not named here closes none
    ClosedDepth = { monster = 8.75 },
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
    pyro = { intro = 'entrance', over = 'finale' },                      -- pyro cues (Config.Pyro.cues); false: none
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
        wrestling = { shape = 'square', half = 2.8, z = 20.77, red = { -2.0, -2.0 }, blue = { 2.0, 2.0 } },   -- the 20 ft ring
        mma = { shape = 'circle', radius = 4.1, z = 20.75, red = { -3.2, 0.0 }, blue = { 3.2, 0.0 } },
    },
}

-- ------------------------------------------------------------------ pyro (client/pyro.lua, server/pyro.lua)
-- The pyro of the shows with a stage (wrestling, concert, MMA), fired from the desk's Pyro section or
-- /arenapyro <cue | list> [small | big] [colour]: flames, sparks, comets and smoke from the stage's lip, sparks and
-- flames down the ramp and on the ring posts (the cage's posts), fireworks, a waterfall and a rain of sparks from
-- overhead, confetti and money over the ring. Every player in the arena sees a cue at the same moment; it is the
-- game's own particle effects (no damage, no fire). A cue is a list of steps:
--   { units = '<a group below>', fx = '<an effect below>', at = s after the cue starts, stagger = s between one unit
--     and the next, pick = { the units to use, in that order } / reverse = true (the listed order backwards),
--     scale = times the effect's own, loop = s (instead of the effect's), down = true (pointing down) }
-- A cue a show has no units for is not offered for that show. label / group = its button on the desk.
-- An effect: its particle asset and name (checked against the game's files), its scale, loop = s (a looped effect:
-- started, then stopped after that long), up = m above the unit, light = { r, g, b } (a flash while it goes off),
-- tint = true (it takes the colour picked on the desk), sound = { name, set } (a game sound played from where it
-- goes off; none by default). The sizes are first guesses: change them here.
Config.Pyro = {
    enabled = true,
    command = 'arenapyro',
    access = nil,                -- an ACE, false = anyone, nil = the same as the lights (Config.LightAccess)
    cooldown = 1.5,              -- s between two cues
    range = 180.0,               -- m from the arena's middle: only players this close run a cue
    sizes = { small = 0.6, normal = 1.0, big = 1.5 },    -- the desk's Small / Normal / Big: times every effect's scale
    units = {
        wrestling = {
            flames = { vector3(-342.169, -1956.747, 22.00), vector3(-339.084, -1953.070, 22.00) },   -- the flame units either side of the ramp's head
            mortars = { vector3(-347.339, -1963.375, 21.41), vector3(-333.455, -1946.828, 21.41),
                        vector3(-345.796, -1961.536, 21.41), vector3(-334.998, -1948.667, 21.41),
                        vector3(-344.254, -1959.698, 21.41), vector3(-336.540, -1950.505, 21.41),
                        vector3(-342.711, -1957.859, 21.41), vector3(-338.083, -1952.344, 21.41) },   -- the mortars along the stage's lip, from the outside in
            ramp = { vector3(-340.441, -1956.866, 21.01), vector3(-338.667, -1954.751, 21.01),
                     vector3(-339.139, -1957.958, 20.75), vector3(-337.365, -1955.844, 20.75),
                     vector3(-337.837, -1959.051, 20.49), vector3(-336.063, -1956.937, 20.49),
                     vector3(-336.535, -1960.144, 20.24), vector3(-334.760, -1958.030, 20.24),
                     vector3(-335.232, -1961.237, 19.98), vector3(-333.458, -1959.122, 19.98),
                     vector3(-333.930, -1962.329, 19.72), vector3(-332.156, -1960.215, 19.72) },   -- the ramp's two edges, from the stage down to the floor
            posts = { vector3(-328.621, -1968.977, 22.28), vector3(-324.687, -1964.289, 22.28),
                      vector3(-323.933, -1972.911, 22.28), vector3(-319.999, -1968.223, 22.28) },   -- the ring posts' tops
            over = { vector3(-346.429, -1959.178, 28.55), vector3(-341.929, -1953.816, 28.55),
                     vector3(-337.430, -1948.454, 28.55) },   -- three points over the stage
            truss = { vector3(-347.714, -1960.710, 28.55), vector3(-345.786, -1958.412, 28.55),
                      vector3(-343.857, -1956.114, 28.55), vector3(-341.929, -1953.816, 28.55),
                      vector3(-340.001, -1951.518, 28.55), vector3(-338.072, -1949.220, 28.55),
                      vector3(-336.144, -1946.921, 28.55) },   -- a line across over the stage's front
            above = { vector3(-328.536, -1968.970, 28.55), vector3(-324.680, -1964.374, 28.55),
                      vector3(-323.940, -1972.826, 28.55), vector3(-320.084, -1968.230, 28.55),
                      vector3(-324.310, -1968.600, 28.55) },   -- over the ring
            confetti = { vector3(-328.536, -1968.970, 28.55), vector3(-324.680, -1964.374, 28.55),
                         vector3(-323.940, -1972.826, 28.55), vector3(-320.084, -1968.230, 28.55),
                         vector3(-344.637, -1959.376, 26.05), vector3(-336.923, -1950.184, 26.05) },
        },
        concert = {
            flames = { vector3(-346.412, -1961.803, 21.15), vector3(-334.842, -1948.014, 21.15),
                       vector3(-342.555, -1957.207, 21.15), vector3(-338.698, -1952.610, 21.15) },   -- along the stage's lip, in front of the band
            mortars = { vector3(-347.339, -1963.375, 21.15), vector3(-333.455, -1946.828, 21.15),
                        vector3(-345.796, -1961.536, 21.15), vector3(-334.998, -1948.667, 21.15),
                        vector3(-344.254, -1959.698, 21.15), vector3(-336.540, -1950.505, 21.15),
                        vector3(-342.711, -1957.859, 21.15), vector3(-338.083, -1952.344, 21.15) },
            over = { vector3(-345.922, -1960.908, 31.90), vector3(-340.780, -1954.780, 31.90),
                     vector3(-335.638, -1948.652, 31.90) },   -- under the roof's front truss
            truss = { vector3(-346.565, -1961.674, 31.90), vector3(-344.637, -1959.376, 31.90),
                      vector3(-342.708, -1957.078, 31.90), vector3(-340.780, -1954.780, 31.90),
                      vector3(-338.852, -1952.482, 31.90), vector3(-336.923, -1950.184, 31.90),
                      vector3(-334.995, -1947.886, 31.90) },
            above = { vector3(-336.716, -1964.717, 30.00), vector3(-330.289, -1957.056, 30.00),
                      vector3(-330.588, -1969.859, 30.00), vector3(-324.160, -1962.199, 30.00),
                      vector3(-330.438, -1963.458, 30.00) },   -- over the standing floor
            confetti = { vector3(-336.716, -1964.717, 30.00), vector3(-330.289, -1957.056, 30.00),
                         vector3(-330.588, -1969.859, 30.00), vector3(-324.160, -1962.199, 30.00),
                         vector3(-344.637, -1959.376, 31.50), vector3(-336.923, -1950.184, 31.50) },
        },
        mma = {
            flames = { vector3(-343.198, -1957.973, 21.15), vector3(-338.056, -1951.844, 21.15) },   -- either side of the walkway's head
            mortars = { vector3(-347.339, -1963.375, 21.15), vector3(-333.455, -1946.828, 21.15),
                        vector3(-345.796, -1961.536, 21.15), vector3(-334.998, -1948.667, 21.15),
                        vector3(-344.254, -1959.698, 21.15), vector3(-336.540, -1950.505, 21.15),
                        vector3(-342.711, -1957.859, 21.15), vector3(-338.083, -1952.344, 21.15) },
            ramp = { vector3(-339.414, -1957.819, 19.60), vector3(-337.550, -1955.598, 19.60),
                     vector3(-337.805, -1959.169, 19.60), vector3(-335.941, -1956.948, 19.60),
                     vector3(-336.196, -1960.519, 19.60), vector3(-334.332, -1958.297, 19.60),
                     vector3(-334.588, -1961.869, 19.60), vector3(-332.724, -1959.647, 19.60),
                     vector3(-332.979, -1963.219, 19.60), vector3(-331.115, -1960.997, 19.60),
                     vector3(-331.370, -1964.568, 19.60), vector3(-329.506, -1962.347, 19.60) },   -- the walkway's two edges, from the stage to the cage
            posts = { vector3(-319.513, -1970.113, 22.70), vector3(-319.848, -1966.277, 22.70),
                      vector3(-322.797, -1963.803, 22.70), vector3(-326.633, -1964.138, 22.70),
                      vector3(-329.107, -1967.087, 22.70), vector3(-328.772, -1970.923, 22.70),
                      vector3(-325.823, -1973.397, 22.70), vector3(-321.987, -1973.062, 22.70) },   -- the cage's posts
            over = { vector3(-346.429, -1959.178, 28.55), vector3(-341.929, -1953.816, 28.55),
                     vector3(-337.430, -1948.454, 28.55) },
            truss = { vector3(-347.714, -1960.710, 28.55), vector3(-345.786, -1958.412, 28.55),
                      vector3(-343.857, -1956.114, 28.55), vector3(-341.929, -1953.816, 28.55),
                      vector3(-340.001, -1951.518, 28.55), vector3(-338.072, -1949.220, 28.55),
                      vector3(-336.144, -1946.921, 28.55) },
            above = { vector3(-328.536, -1968.970, 28.55), vector3(-324.680, -1964.374, 28.55),
                      vector3(-323.940, -1972.826, 28.55), vector3(-320.084, -1968.230, 28.55),
                      vector3(-324.310, -1968.600, 28.55) },   -- over the cage
            confetti = { vector3(-328.536, -1968.970, 28.55), vector3(-324.680, -1964.374, 28.55),
                         vector3(-323.940, -1972.826, 28.55), vector3(-320.084, -1968.230, 28.55),
                         vector3(-344.637, -1959.376, 26.05), vector3(-336.923, -1950.184, 26.05) },
        },
    },
    effects = {
        flame    = { asset = 'scr_xs_pits', name = 'scr_xs_fire_pit', scale = 0.5, loop = 1.4, light = { 255, 140, 40 } },
        longburn = { asset = 'scr_xs_pits', name = 'scr_xs_fire_pit_long', scale = 0.5, loop = 3.0, light = { 255, 140, 40 } },
        blue     = { asset = 'scr_xs_pits', name = 'scr_xs_sf_pit', scale = 0.5, loop = 1.4, light = { 90, 170, 255 } },
        gerb     = { asset = 'scr_indep_fireworks', name = 'scr_indep_firework_fountain', scale = 0.5, tint = true, light = { 255, 220, 170 } },
        comet    = { asset = 'scr_indep_fireworks', name = 'scr_indep_firework_trailburst', scale = 0.6, tint = true, light = { 255, 230, 200 } },
        burst    = { asset = 'scr_indep_fireworks', name = 'scr_indep_firework_starburst', scale = 0.8, tint = true, light = { 255, 240, 220 } },
        shot     = { asset = 'scr_indep_fireworks', name = 'scr_indep_firework_shotburst', scale = 0.7, tint = true, light = { 255, 240, 220 } },
        shell    = { asset = 'proj_xmas_firework', name = 'scr_firework_xmas_burst_rgw', scale = 0.3, light = { 255, 240, 220 } },
        spiral   = { asset = 'proj_xmas_firework', name = 'scr_firework_xmas_spiral_burst_rgw', scale = 0.3, light = { 255, 240, 220 } },
        crackle  = { asset = 'proj_xmas_firework', name = 'scr_firework_xmas_repeat_burst_rgw', scale = 0.3, light = { 255, 240, 220 } },
        sparkler = { asset = 'scr_ih_club', name = 'scr_ih_club_sparkler', scale = 2.5, loop = 5.0, light = { 255, 230, 180 } },
        smoke    = { asset = 'scr_ba_club', name = 'scr_ba_club_smoke_machine', scale = 1.2, loop = 3.0 },
        puff     = { asset = 'scr_rcbarry2', name = 'scr_clown_appears', scale = 1.0 },
        confetti = { asset = 'scr_xs_celebration', name = 'scr_xs_confetti_burst', scale = 1.6 },
        money    = { asset = 'scr_xs_celebration', name = 'scr_xs_money_rain', scale = 1.2, loop = 6.0 },
    },
    -- the desk's buttons, in this order (a new group starts where the cues' group changes)
    order = { 'flames', 'firewall', 'blueflames', 'longburn', 'gerbs', 'chase', 'sweep', 'smoke',
              'ramp', 'rampfire', 'posts', 'postfire', 'sparklers',
              'burst', 'shells', 'crackle', 'waterfall', 'sparkrain', 'puffs', 'confetti', 'money',
              'entrance', 'bighit', 'rapid', 'winner', 'inferno', 'finale' },
    cues = {
        flames     = { label = 'Flames',      group = 'Stage', steps = { { units = 'flames', fx = 'flame' } } },
        firewall   = { label = 'Fire wall',   group = 'Stage', steps = { { units = 'mortars', fx = 'flame', scale = 0.8 } } },
        blueflames = { label = 'Blue flames', group = 'Stage', steps = { { units = 'flames', fx = 'blue' } } },
        longburn   = { label = 'Long burn',   group = 'Stage', steps = { { units = 'flames', fx = 'longburn' } } },
        gerbs      = { label = 'Sparks',      group = 'Stage', steps = { { units = 'mortars', fx = 'gerb' } } },
        chase      = { label = 'Chase',       group = 'Stage', steps = { { units = 'mortars', fx = 'comet', stagger = 0.12 } } },
        sweep      = { label = 'Sweep',       group = 'Stage', steps = { { units = 'mortars', fx = 'comet', stagger = 0.1,
                                                                         pick = { 1, 3, 5, 7, 8, 6, 4, 2 } } } },   -- one end to the other
        smoke      = { label = 'Smoke',       group = 'Stage', steps = { { units = 'flames', fx = 'smoke' } } },
        ramp       = { label = 'Ramp sparks', group = 'Ramp and ring', steps = { { units = 'ramp', fx = 'gerb', stagger = 0.09 } } },
        rampfire   = { label = 'Ramp flames', group = 'Ramp and ring', steps = { { units = 'ramp', fx = 'flame', scale = 0.5, loop = 1.0, stagger = 0.09 } } },
        posts      = { label = 'Post sparks', group = 'Ramp and ring', steps = { { units = 'posts', fx = 'gerb' } } },
        postfire   = { label = 'Post flames', group = 'Ramp and ring', steps = { { units = 'posts', fx = 'flame', scale = 0.6 } } },
        sparklers  = { label = 'Sparklers',   group = 'Ramp and ring', steps = { { units = 'posts', fx = 'sparkler' } } },
        burst      = { label = 'Burst',       group = 'Overhead', steps = { { units = 'over', fx = 'burst', stagger = 0.25 } } },
        shells     = { label = 'Fireworks',   group = 'Overhead', steps = { { units = 'over', fx = 'shell', stagger = 0.3 },
                                                                            { units = 'above', fx = 'spiral', at = 0.9, stagger = 0.25 } } },
        crackle    = { label = 'Crackle',     group = 'Overhead', steps = { { units = 'above', fx = 'crackle', stagger = 0.2 } } },
        waterfall  = { label = 'Waterfall',   group = 'Overhead', steps = { { units = 'truss', fx = 'gerb', down = true } } },
        sparkrain  = { label = 'Spark rain',  group = 'Overhead', steps = { { units = 'above', fx = 'gerb', down = true, stagger = 0.1 } } },
        puffs      = { label = 'Smoke puffs', group = 'Overhead', steps = { { units = 'over', fx = 'puff', stagger = 0.2 } } },
        confetti   = { label = 'Confetti',    group = 'Overhead', steps = { { units = 'confetti', fx = 'confetti', stagger = 0.1 } } },
        money      = { label = 'Money rain',  group = 'Overhead', steps = { { units = 'above', fx = 'money' } } },
        entrance   = { label = 'Entrance',    group = 'Sequences',
                       steps = { { units = 'flames', fx = 'flame' },
                                 { units = 'mortars', fx = 'comet', at = 0.3, stagger = 0.1 },
                                 { units = 'over', fx = 'burst', at = 1.3, stagger = 0.2 },
                                 { units = 'ramp', fx = 'gerb', at = 1.8, stagger = 0.09 } } },
        bighit     = { label = 'Big hit',     group = 'Sequences',
                       steps = { { units = 'flames', fx = 'flame' }, { units = 'mortars', fx = 'comet' },
                                 { units = 'over', fx = 'burst' } } },
        rapid      = { label = 'Rapid fire',  group = 'Sequences',
                       steps = { { units = 'mortars', fx = 'comet', stagger = 0.07 },
                                 { units = 'mortars', fx = 'comet', stagger = 0.07, at = 0.7, reverse = true },
                                 { units = 'mortars', fx = 'comet', stagger = 0.07, at = 1.4 } } },
        winner     = { label = 'Winner',      group = 'Sequences',
                       steps = { { units = 'posts', fx = 'gerb' },
                                 { units = 'above', fx = 'shell', at = 0.5, stagger = 0.2 },
                                 { units = 'confetti', fx = 'confetti', at = 1.0, stagger = 0.1 },
                                 { units = 'above', fx = 'money', at = 1.2 } } },
        inferno    = { label = 'Inferno',     group = 'Sequences',
                       steps = { { units = 'mortars', fx = 'flame', scale = 0.8 }, { units = 'flames', fx = 'longburn' },
                                 { units = 'posts', fx = 'flame', scale = 0.6, at = 0.3 },
                                 { units = 'ramp', fx = 'flame', scale = 0.5, loop = 1.0, at = 0.6, stagger = 0.09 } } },
        finale     = { label = 'Finale',      group = 'Sequences',
                       steps = { { units = 'flames', fx = 'flame' },
                                 { units = 'mortars', fx = 'gerb' },
                                 { units = 'posts', fx = 'gerb', at = 0.4 },
                                 { units = 'mortars', fx = 'comet', at = 1.0, stagger = 0.08 },
                                 { units = 'over', fx = 'shot', at = 1.8, stagger = 0.15 },
                                 { units = 'over', fx = 'burst', at = 2.6, stagger = 0.15 },
                                 { units = 'flames', fx = 'flame', at = 3.0 },
                                 { units = 'confetti', fx = 'confetti', at = 3.2, stagger = 0.1 } } },
    },
}

-- ------------------------------------------------------------------ props of your own (client/props.lua)
-- Vanilla props put down for a show without CodeWalker: { model, x, y, z, heading [, ground = true] }. x y z is where
-- the model's own origin goes (CreateObjectNoOffset); ground = true sets it down on the floor under it instead. Local
-- props, frozen, made while you are in the arena; /arenainfo prints where you stand. room = the interior room a prop
-- stands in when that is not the bowl. Out of the box:
--   * the interview set in the backstage hall (wrestling and MMA): a green screen (the arena's own prop,
--     mzb_bh_green_screen: 3.5 m wide, 2.4 m high, its cloth swept out over the floor) standing off the east wall
--     north of the tunnel, a TV camera on it and two studio lights. The subject stands on the cloth, facing the hall
--   * a camera crane (the movie set's) on the wrestling stage deck, right of the titantron as the house sees it, its
--     arm up over the stage's lip towards the ring
Config.ShowProps = {
    wrestling = {
        { 'prop_dolly_02', -336.218, -1946.076, 21.273, 320.0 },                                -- the camera crane
        { 'mzb_bh_green_screen', -360.177, -1926.168, 19.556, 50.0, room = 'backstage' },
        { 'prop_tv_cam_02', -364.505, -1922.537, 20.562, 50.0, room = 'backstage' },
        { 'prop_studio_light_02', -364.508, -1925.341, 19.734, 90.1, room = 'backstage' },
        { 'prop_studio_light_02', -361.744, -1922.047, 19.734, 9.9, room = 'backstage' },
    },
    mma = {
        { 'mzb_bh_green_screen', -360.177, -1926.168, 19.556, 50.0, room = 'backstage' },
        { 'prop_tv_cam_02', -364.505, -1922.537, 20.562, 50.0, room = 'backstage' },
        { 'prop_studio_light_02', -364.508, -1925.341, 19.734, 90.1, room = 'backstage' },
        { 'prop_studio_light_02', -361.744, -1922.047, 19.734, 9.9, room = 'backstage' },
    },
}

-- What stands in the store rooms while its show is NOT up: the two basket units, folded down (the arena's own prop,
-- mzb_bb_hoop_stowed: the unit off the court with its mast lowered and the shot clock off, 6.9 m long, 2.25 m high;
-- its origin is on the floor under its base, its board end is +y), side by side in the east store.
-- { model, x, y, z, heading, room = the interior room, unless = the show (or { shows }) that has it out on the floor }
Config.StowedProps = {
    { 'mzb_bb_hoop_stowed', -292.050, -1964.301, 19.556, 230.0, room = 'east_store', unless = 'basketball' },
    { 'mzb_bb_hoop_stowed', -290.282, -1962.195, 19.556, 230.0, room = 'east_store', unless = 'basketball' },
}

-- ------------------------------------------------------------------ cars on the floor (server/cars.lua)
-- Real cars for a show to wreck: the game's own vehicles, made by the server (so every player sees the same cars in
-- the same state) - out of the box the truck show's six, side by side on the deck between the jump's two lips. They
-- come with their show and go with it. Staff put fresh ones down after the trucks have flattened them with
-- /arenacars reset and take them away with /arenacars clear, or with the Cars buttons on the desk's Show tab.
--   models  a model per spot is picked at random (no two the same while the list is long enough)
--   spots   where they stand: vector4(x, y, z, heading). z is where the car's middle goes, about half a metre over
--           the surface it stands on: a car is made just over the floor and settles onto it (made any lower, its
--           wheels would be in the floor). The truck show's deck is at 20.75
--   locked  their doors are locked: they are there to be driven over, not driven off
--   type    what the models are, for the server that makes them: 'automobile' unless said ('bike', 'trailer' ...)
--   range   m from the arena's middle: the cars are put down once a player is this close (80 unless said) - see
--           server/cars.lua for why not before
--   delay   s between the show coming up and its cars (4 unless said): the players' games set the jump up first
-- Config.ShowCars = false, or no entry for a show: no cars.
Config.CarsCommand = 'arenacars'
Config.CarsAccess = nil                -- who may reset and clear them: an ACE, false = anyone, nil = the same as the
                                       -- lights (Config.LightAccess)
Config.ShowCars = {
    monster = {
        models = { 'emperor2', 'tornado3', 'voodoo2', 'emperor', 'ingot', 'regina', 'asea', 'premier', 'stanier', 'primo' },
        spots = { vector4(-328.715, -1964.904, 21.250, 320.0), vector4(-326.953, -1966.382, 21.250, 140.0),
                  vector4(-325.191, -1967.861, 21.250, 320.0), vector4(-323.429, -1969.339, 21.250, 140.0),
                  vector4(-321.667, -1970.818, 21.250, 320.0), vector4(-319.905, -1972.296, 21.250, 140.0) },
        locked = true,
    },
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

-- ------------------------------------------------------------------ the event desk (client/desk.lua, server/desk.lua)
-- An event official with a clipboard at the floor end of the tunnel: walk up and talk to them (ox_target or qb-target
-- when the server runs one, else [E]). What they offer goes by the show that is up: a show with a race track
-- (Config.Races, shared/races.lua: the kart circuits, the truck show, arenacross) has the race's sign-up; a show
-- with a ring or a cage (Config.Fights.venues) has "Set up a fight", which is /arenafight challenge and accept
-- behind a menu; the others have nothing to sign up for. The ped is a local one, there while you are within 60 m.
--   ped       model, coords = vector4(x, y, the floor's z, heading), scenario; room = '<interior room>' if the game
--             does not find the room itself (the ped stays unseen)
Config.EventDesk = {
    enabled = true,
    ped = { model = 's_m_m_highsec_01', coords = vector4(-308.63, -1951.86, 19.55, 140.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
    distance = 2.2,          -- how close to talk
    -- who may set up a fight at the desk: 'anyone' or 'staff' (the fight card's staff: Config.Fights.access).
    -- Config.Fights.challenge = false turns challenges off for everyone but staff, here as in chat
    fights = 'anyone',
}

-- ------------------------------------------------------------------ racing (client/race.lua, server/race.lua)
-- A race on the track of the show that is up (Config.Races: the grid, the checkpoints, the laps, the vehicles - made
-- with the tracks, shared/races.lua). One race at a time, run by the server: the first to join at the event desk
-- opens the sign-up, which closes after `signup` seconds or when that player starts it; everyone is put on the grid
-- in the order they joined, in a kart (a truck, a dirt bike) of the track's own, held until the countdown is over.
-- The server counts the checkpoints (only the next one in order, and only with the racer near it), keeps the
-- positions and the times, and classifies whoever has not finished `dnf` seconds after the winner as DNF. Out of the
-- vehicle for 15 seconds, dead, or gone from the server: retired. Afterwards the vehicles are taken away and the
-- racers stand at the desk again. Another show coming up cancels the race.
--   staff: /arenarace start (close the sign-up and go) | cancel | status
Config.Race = {
    enabled = true,
    command = 'arenarace',
    access = nil,            -- who may run /arenarace start and cancel: an ACE, false = anyone, nil = the same as the lights
    signup = 45,             -- seconds the sign-up stays open after the first entrant (the entrant can start it early)
    countdown = 5,
    minPlayers = 1,
    dnf = 240,               -- seconds after the winner finishes before everyone else is classified DNF
    timeout = 900,           -- seconds a race may run at most (nobody finishing: everyone is classified DNF)
    fee = 0, prize = 0,      -- money through the bridge below; 0 = none
    returnTo = nil,          -- where racers are put when it ends; nil = back at the desk
                             -- (a place of your own: vector4(x, y, the floor's z, heading))
}

-- ------------------------------------------------------------------ merch (client/merch.lua, server/merch.lua)
-- The seller at the lobby's merch stand (the stand itself is dressed per show: the mzb_set_merch_<style> entity sets
-- in Config.Shows). Talking to them lists what the show that is up has for sale; the server looks the item and its
-- price up here itself, takes the money and hands the item over through the bridge (server/bridge.lua), which uses
-- the first of these the server runs: qbx_core (items through ox_inventory), qb-core, es_extended, ox_inventory on
-- its own (its 'money' item), or none of them. With none, only a price of 0 can be bought and nothing is handed
-- over (the player is told they have it): set the prices to 0, or run a framework. Money is cash.
-- Every item named here has to exist in your inventory (README.md, "Merch", has the list and an ox_inventory
-- snippet); one that does not is not sold and the money goes back.
Config.Merch = {
    enabled = true,
    ped = { model = 'a_f_y_hipster_02', coords = vector4(-277.83, -2033.38, 28.95, 320.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    distance = 2.2,
    -- what a stand sells, by the stand's style (a show's style: see styleOf). item = the inventory item's name
    styleOf = { wrestling = 'wrestling', concert = 'concert', mma = 'mma', hockey = 'hockey', basketball = 'basketball',
                tennis = 'tennis', monster = 'monster', karting = 'racing', sprint = 'racing', oval = 'racing',
                skatepark = 'skatepark', motocross = 'motocross', house = 'arena', floor = 'arena' },
    -- the stand's name per style (the menu's title); a show that is not in styleOf has the arena's stand
    titles = { wrestling = 'SAPW', concert = 'Sirens of San Andreas - The Neon Coast Tour', mma = 'SAFC - Vespucci Vengeance',
               hockey = 'Los Santos Blizzard', basketball = 'LS Panic', tennis = 'Maze Bank Open', monster = 'Monster Mayhem',
               racing = 'Maze Bank Grand Prix', skatepark = 'Los Santos Open', motocross = 'Arenacross',
               arena = 'Maze Bank Arena' },
    items = {
        wrestling = {                                    -- San Andreas Pro Wrestling
            { item = 'mzb_tee_sapw', label = 'SAPW Tee', price = 35 },
            { item = 'mzb_cap_sapw', label = 'SAPW Cap', price = 25 },
            { item = 'mzb_finger_sapw', label = 'SAPW Foam Finger', price = 15 },
            { item = 'mzb_poster_sapw', label = 'SAPW Poster', price = 12 },
            { item = 'mzb_programme_sapw', label = 'SAPW Programme', price = 10 },
            { item = 'mzb_belt_sapw', label = 'SAPW Replica Title Belt', price = 150 },
        },
        concert = {                                      -- Sirens of San Andreas - The Neon Coast Tour
            { item = 'mzb_tee_sirens', label = 'Sirens of San Andreas Tour Tee', price = 40 },
            { item = 'mzb_hoodie_sirens', label = 'Neon Coast Tour Hoodie', price = 70 },
            { item = 'mzb_cap_sirens', label = 'Sirens of San Andreas Cap', price = 25 },
            { item = 'mzb_poster_sirens', label = 'Neon Coast Tour Poster', price = 15 },
            { item = 'mzb_programme_sirens', label = 'Neon Coast Tour Programme', price = 12 },
            { item = 'mzb_glowstick_sirens', label = 'Neon Coast Glow Stick', price = 8 },
        },
        mma = {                                          -- SAFC - Vespucci Vengeance
            { item = 'mzb_tee_safc', label = 'SAFC Tee', price = 35 },
            { item = 'mzb_cap_safc', label = 'SAFC Cap', price = 25 },
            { item = 'mzb_gloves_safc', label = 'SAFC Replica Gloves', price = 60 },
            { item = 'mzb_poster_safc', label = 'Vespucci Vengeance Poster', price = 12 },
            { item = 'mzb_programme_safc', label = 'Vespucci Vengeance Programme', price = 10 },
        },
        hockey = {                                       -- Los Santos Blizzard
            { item = 'mzb_jersey_blizzard', label = 'Los Santos Blizzard Jersey', price = 90 },
            { item = 'mzb_tee_blizzard', label = 'Los Santos Blizzard Tee', price = 35 },
            { item = 'mzb_cap_blizzard', label = 'Los Santos Blizzard Cap', price = 25 },
            { item = 'mzb_finger_blizzard', label = 'Los Santos Blizzard Foam Finger', price = 15 },
            { item = 'mzb_puck_blizzard', label = 'Los Santos Blizzard Puck', price = 18 },
            { item = 'mzb_programme_blizzard', label = 'Los Santos Blizzard Programme', price = 10 },
        },
        basketball = {                                   -- LS Panic
            { item = 'mzb_jersey_panic', label = 'LS Panic Jersey', price = 85 },
            { item = 'mzb_tee_panic', label = 'LS Panic Tee', price = 35 },
            { item = 'mzb_cap_panic', label = 'LS Panic Cap', price = 25 },
            { item = 'mzb_finger_panic', label = 'LS Panic Foam Finger', price = 15 },
            { item = 'mzb_ball_panic', label = 'LS Panic Mini Basketball', price = 20 },
            { item = 'mzb_programme_panic', label = 'LS Panic Programme', price = 10 },
        },
        tennis = {                                       -- Maze Bank Open
            { item = 'mzb_tee_mbopen', label = 'Maze Bank Open Tee', price = 35 },
            { item = 'mzb_visor_mbopen', label = 'Maze Bank Open Visor', price = 22 },
            { item = 'mzb_towel_mbopen', label = 'Maze Bank Open Towel', price = 30 },
            { item = 'mzb_ball_mbopen', label = 'Maze Bank Open Souvenir Ball', price = 15 },
            { item = 'mzb_programme_mbopen', label = 'Maze Bank Open Programme', price = 10 },
        },
        monster = {                                      -- Monster Mayhem
            { item = 'mzb_tee_mayhem', label = 'Monster Mayhem Tee', price = 35 },
            { item = 'mzb_cap_mayhem', label = 'Monster Mayhem Cap', price = 25 },
            { item = 'mzb_finger_mayhem', label = 'Monster Mayhem Foam Finger', price = 15 },
            { item = 'mzb_poster_mayhem', label = 'Monster Mayhem Poster', price = 12 },
            { item = 'mzb_programme_mayhem', label = 'Monster Mayhem Programme', price = 10 },
            { item = 'mzb_tee_mudflaps', label = 'SHOW ME YOUR MUDFLAPS Tee', price = 35 },
            { item = 'mzb_tee_thrillbilly', label = 'Thrillbilly Mud Club Tee', price = 35 },
        },
        racing = {                                       -- Maze Bank Grand Prix (the three kart circuits)
            { item = 'mzb_tee_gp', label = 'Maze Bank Grand Prix Tee', price = 35 },
            { item = 'mzb_cap_gp', label = 'Maze Bank Grand Prix Cap', price = 25 },
            { item = 'mzb_flag_gp', label = 'Maze Bank Grand Prix Chequered Flag', price = 15 },
            { item = 'mzb_poster_gp', label = 'Maze Bank Grand Prix Poster', price = 12 },
            { item = 'mzb_programme_gp', label = 'Maze Bank Grand Prix Programme', price = 10 },
            { item = 'mzb_tee_mudflaps', label = 'SHOW ME YOUR MUDFLAPS Tee', price = 35 },
            { item = 'mzb_tee_thrillbilly', label = 'Thrillbilly Mud Club Tee', price = 35 },
        },
        skatepark = {                                    -- Los Santos Open
            { item = 'mzb_tee_lsopen', label = 'Los Santos Open Tee', price = 35 },
            { item = 'mzb_hoodie_lsopen', label = 'Los Santos Open Hoodie', price = 65 },
            { item = 'mzb_cap_lsopen', label = 'Los Santos Open Cap', price = 25 },
            { item = 'mzb_deck_lsopen', label = 'Los Santos Open Skate Deck', price = 80 },
            { item = 'mzb_stickers_lsopen', label = 'Los Santos Open Sticker Pack', price = 8 },
            { item = 'mzb_poster_lsopen', label = 'Los Santos Open Poster', price = 12 },
        },
        motocross = {                                    -- Arenacross
            { item = 'mzb_tee_arenacross', label = 'Arenacross Tee', price = 35 },
            { item = 'mzb_jersey_arenacross', label = 'Arenacross Race Jersey', price = 60 },
            { item = 'mzb_cap_arenacross', label = 'Arenacross Cap', price = 25 },
            { item = 'mzb_poster_arenacross', label = 'Arenacross Poster', price = 12 },
            { item = 'mzb_programme_arenacross', label = 'Arenacross Programme', price = 10 },
            { item = 'mzb_tee_mudflaps', label = 'SHOW ME YOUR MUDFLAPS Tee', price = 35 },
            { item = 'mzb_tee_thrillbilly', label = 'Thrillbilly Mud Club Tee', price = 35 },
        },
        arena = {                                        -- Maze Bank Arena (the empty house, the open floor)
            { item = 'mzb_tee_arena', label = 'Maze Bank Arena Tee', price = 30 },
            { item = 'mzb_hoodie_arena', label = 'Maze Bank Arena Hoodie', price = 60 },
            { item = 'mzb_cap_arena', label = 'Maze Bank Arena Cap', price = 25 },
            { item = 'mzb_finger_arena', label = 'Maze Bank Arena Foam Finger', price = 15 },
            { item = 'mzb_mug_arena', label = 'Maze Bank Arena Mug', price = 14 },
            { item = 'mzb_keyring_arena', label = 'Maze Bank Arena Keyring', price = 6 },
        },
    },
}

-- ------------------------------------------------------------------ the tees on the stand's walls (client/shop.lua, server/shop.lua)
-- Every tee hanging on the merch stand's gridwalls can be tried on and bought (Config.MerchTees, shared/merch_tees.lua:
-- the eight tees of each stand and where each one hangs, made with the stands). Walk up to one - ox_target or
-- qb-target when the server runs one, else a prompt - and the camera cuts to the front of your character wearing it,
-- the wall behind: the arrows show the stand's other tees, Enter buys and wears (wears one you own, takes off the one
-- you wear), Backspace leaves. A tee you only tried goes back to what you had on.
-- The shirts are addon clothing for the two freemode characters (stream/clothes): the top (component 11), one
-- drawable per stand, a texture per tee. What a player owns is kept by the server, per licence (the resource's KVP);
-- the money is the bridge's (server/bridge.lua, see Config.Merch).
Config.MerchShop = {
    enabled = true,
    price = 35,                       -- a tee; prices = { monster = 40 } overrides per style
    prices = {},
    component = 11,
    collection = { male = 'mp_m_mzbmerch', female = 'mp_f_mzbmerch' },
    -- what goes with a tee so the arms and the neck are right: what the game's own shop data puts with the two
    -- tees these are made from (his plain crew neck, her tuner tee). Not seen in game yet - if an arm or a neck
    -- shows through, these are the numbers to change
    fit = { male = { arms = 0, undershirt = 15 }, female = { arms = 14, undershirt = 2 } },
    -- only if the collection natives are missing on an old client build: the first of the pack's drawables in the
    -- model's own numbering (nil = assume the pack is the last one loaded)
    firstDrawable = { male = nil, female = nil },
    -- the cuts a design comes in. A cut's drawable in the pack is the stand's own number (Config.MerchTees) plus
    -- `offset`; `word` replaces "Tee" in the design's name; price and fit are the tee's unless given. Up / down in
    -- the try-on switches cut. A cut the installed pack does not have is simply not offered.
    cuts = {
        { id = 'tee', title = 'T-Shirts', word = 'Tee', offset = 0 },
        { id = 'tank', title = 'Tank Tops', word = 'Tank', offset = 11, price = 29,
          fit = { male = { arms = 5, undershirt = 15 }, female = { arms = 11, undershirt = 3 } } },   -- (the game's own, as the tee's)
    },
    reach = 1.7,                      -- how close to a hanging tee
    camera = { distance = 2.3, height = 0.35, fov = 38.0 },
    save = true,                      -- after a purchase / wear / remove, ask the server's clothing script to save the look
    -- who draws the try-on. 'auto': on a server with vice_hud the HUD does - its shop panel, its prompts, and its
    -- wallet as the only money on the screen - else this resource's page, which then shows the cash itself.
    -- 'own': always this resource's page (the cash is still left to vice_hud's wallet when that runs)
    hud = 'auto',
    store = 'Maze Bank Arena',        -- the store's name over the category
}
