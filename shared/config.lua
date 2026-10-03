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
Config.LightMaxFixtures = 32           -- spot lights drawn per frame at most (the show rigs have 24 to 36)
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
