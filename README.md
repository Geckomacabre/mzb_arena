# mzb_arena: Maze Bank Arena full interior

A complete, walkable interior for the Maze Bank Arena (Del Perro / La Puerta), built inside the vanilla
exterior with no changes to the outside. The entire building is open:

- **Seating bowl.** Lower and upper tiers, about 18,650 seats, 11 vomitories, a cross aisle, stairs down to the floor,
  a four-sided centre-hung video board (16:9 screens, corner LED columns, a crown and a score ring, with its own content
  for every show), an LED ribbon, banners and EXIT signs. House lights are switchable (full / dimmed).
- **Street-level concourse.** Four glazed gateways with security (metal detectors, bag tables, ticket scanners,
  queue lines), a box office, guest services, concession stands, bars, a team store, men's and women's rest rooms
  (every toilet stall's door swings open as you walk in and closes behind you),
  vending, ATMs, a canopy with downlights, and murals.
- **Event level.** A service corridor runs round the back of the lower bowl at floor level, with a tunnel onto the
  event floor on every side: the event tunnel at the stage end, a team tunnel in the middle of each long side, and a
  5 m vehicle tunnel at the far end. Along the corridor are the home and visitors' locker rooms, a training room
  (power rack on a lifting platform, dumbbell rack, benches, bikes, treatment tables), a players' lounge, the officials'
  room, first aid, staff toilets, a vehicle garage off the far-end tunnel (a hot-water fill station, the snow melt
  pit), the ice plant (compressors, chiller, receiver, control panels) and three stores. Behind the stage are the
  backstage hall, two more locker rooms (showers, WCs, lockers), medical, officials, a press conference room,
  catering, admin, offices and the security control room.
- **Production control room.** Off the arena offices, behind a keypad door with an ON AIR light: a 10 x 3 video wall
  of multiviewers with the program and preview monitors in the middle (red / green tally) and studio clocks, a front row
  of consoles (vision mixer with its T-bar, graphics, two replay positions with jog-wheel controllers) and a back row on
  a riser (director and producer, the audio console with its meter bridge), acoustic wall panels, and an equipment
  annex with a row of 19" racks under a cable tray, the engineering bench and the UPS.
- **Loading dock.** Three working roller doors on the NW loading street, each an industrial shutter with its guide
  channels, coil hood, gear motor, hand chain, push-button station, beacon, bay sign and bollards: walk or drive up to
  one and press **E** to open or close it (inside or outside). Inside: heavy pallet racking loaded with stock, the day's
  delivery on pallets, a waste corner (baler with a finished bale, dumpster, cardboard cages, bins) by the doors, the
  dock office, the house staging decks, crowd barriers, cable trunks and power distro staged by the backstage opening,
  and LED high-bays under the plaza deck.
- **Switchable shows.** Each one is a set of interior entity sets, switched live for every player:

| Show | What you get |
|---|---|
| `wrestling` | A 20 ft wrestling ring (round posts, turnbuckles, ropes, printed skirt, steel steps), entrance stage with titantron, ramp, pyro, a walk-through entrance curtain that moves when peds pass, the Gorilla position, commentary and timekeeper desks, ~1,200 floor chairs, a lighting rig and PA |
| `concert` | End stage with an LED wall, a full band backline (a detailed drum kit on a skirted riser, two guitar stacks, an 8x10 bass rig, a 2x12 combo, pedalboards, boom mics, a guitar vault and flight cases in the wings), a ground-support roof with moving heads, PA hangs, side screens, a general-admission floor with a photo pit barricade and a FOH mix riser |
| `hockey` | A 56 x 26 m ice rink (slippery: vehicles slide and players glide on it, see below): printed ice with the Maze Bank centre logo, dasher boards with a kick plate and GTA sponsor ads, glass on stanchions (taller at the ends), protective netting over the end glass, goals with nets, open player benches with doors onto the ice and glass behind them, the penalty and timekeeper boxes, the resurfacer's gate at the far end, and the board's hockey score |
| `basketball` | A printed hardwood court with its run-off, portable basket stanchions (padded base, glass backboard, rim and net, shot clock), team benches, the scorer's table with an LED front, about 1,150 floor seats (courtside rows on both sides, the ends seated to the walls) and the board's basketball score |
| `tennis` | A hard court with its run-off, the net and posts, the umpire's chair, players' chairs, line judges, sponsor boards behind the baselines, about 1,300 floor seats along both sides and at both ends, and the board's tennis score |
| `mma` | Fight night: a UFC-size octagon (9.1 m, the canvas 1.2 m up, a 1.8 m black chain-link fence, padded posts, two gates with steps and handrails, a printed canvas), the end stage with an LED wall and a walkway, a ring of cageside press and officials' tables with monitors, about 1,450 floor seats in rows out to the floor's edges, a lighting rig with moving heads and four line-array PA hangs over the cage, and the house dimmed |
| `house` | The empty arena with the house lights up |

The end-stage shows (wrestling, concert, MMA) mask off the seats behind the stage with black drapes and close the
vomitories behind them; the LED-wall stages (concert, MMA) are framed by legs and a border on a flown masking truss. The stage end's five lower sections are **telescopic**: for those shows they are stowed into
riser stacks, and the space becomes a real backstage area behind the masking, reached from the event tunnel. It has
wardrobe rails, a video village with monitors, catering, work lights and road cases. For the other shows the sections
are seated as usual.

All brands are GTA V's own, with the sponsor logos taken from the game's textures (Maze Bank, Sprunk, eCola,
Pisswasser, Cluckin' Bell, Fame or Shame, Burger Shot). The acts, teams and events are made up ("San Andreas Pro
Wrestling", "Sirens of San Andreas", the Los Santos Blizzard, SAFC, the Maze Bank Open, and so on).

## From the nosebleeds

Every show from the same seat, the back row of the upper tier.

![The empty arena, house lights up](screenshots/nosebleed_house.jpg)

| | |
|---|---|
| ![Wrestling](screenshots/nosebleed_wrestling.jpg)<br>**Wrestling** | ![Concert](screenshots/nosebleed_concert.jpg)<br>**Concert** |
| ![MMA](screenshots/nosebleed_mma.jpg)<br>**Fight night** | ![Hockey](screenshots/nosebleed_hockey.jpg)<br>**Hockey** |
| ![Basketball](screenshots/nosebleed_basketball.jpg)<br>**Basketball** | ![Tennis](screenshots/nosebleed_tennis.jpg)<br>**Tennis** |

## Requirements

- **Game build 2060 or newer** (`sv_enforceGameBuild 2060`). The interior uses vanilla props from the Diamond Casino
  Heist, After Hours and other DLC packs, and on older builds those props are missing.
- No framework or other resources. If your server runs **ox_lib**, the arena uses it for a staff menu and its
  notifications (below); without it, everything works from chat.

## Install

1. Put the `mzb_arena` folder in your `resources` folder.
2. Add it to `server.cfg`:
   ```
   ensure mzb_arena
   ```
3. Allow your staff to run the arena command:
   ```
   add_ace group.admin command.arena allow
   ```

**Other map packs.** This resource streams its own `sp1_occl_01.ymap`: Rockstar's occlusion for the area, with the
occluders that would hide the interior through the glass removed. If another resource streams the same file (for
example `cfx-gabz-mapdata`), `ensure mzb_arena` **after** it. Otherwise the arena's interior can vanish when you look
at it from outside. Our file keeps everything else in it as Rockstar shipped it.

The resource also replaces a handful of vanilla `sp1_10` files (the painted fake interior, the glass panes in front of
the gateway doors, the loading street's roller-door panels and their collision). Any other resource that replaces
these exact files will conflict with it.

`bob74_ipl` is fine: the arena removes Rockstar's Fame or Shame lobby IPL, which stood where the concourse is now.

**Lighting.** The interior ships its own time-cycle modifiers (`data/mzb_timecycle.xml`: `mzb_arena_int`,
`mzb_arena_concourse`), so the bowl and the back-of-house rooms look the same at any hour or weather. The glazed
concourse keeps its daylight, without the outdoor fog.

## Commands (ACE `command.arena`)

The quick switch, for staff on the spot:

```
/mzb wrestling        switch the show for everyone (late joiners get it too)
/mzb basketball       ... wrestling concert mma hockey basketball tennis house
/mzb list             the shows, the current one in [brackets]
/mzb status           the current show and the dock doors
/mzb dock a open      the loading street's roller doors (a | b | c | all, open | close | toggle)
```

`/mzb` also takes the aliases in `Config.ShowAliases` (`/mzb fight` is MMA, `/mzb empty` is the empty house, and so
on), suggests the show names in chat as you type, and uses the same permission as `/arena`: one ACE line covers both.
The long form still works:

```
/arena show <name>
/arena dock <a|b|c|all> <open|close|toggle>
/arena status
```

**With ox_lib** (`Config.OxLib = 'auto'`): `/mzb` or `/arena` with nothing after it opens an ox_lib menu instead:
pick the show (the one that is up is marked), open and shut the loading dock's doors, or open the light desk. What
the commands answer comes as an ox_lib notification rather than a chat line. The typed forms above work as before,
and the menu's picks are checked on the server with the same ACE. ox_lib is not a dependency: without it (or with
`Config.OxLib = false`) nothing changes. `Config.ShowLabels` has the menu's names and icons for the shows.

Every switch is logged in the server console with the player's name. A short cooldown (`Config.SwitchCooldown`)
stops a switch being spammed, since each one reloads the interior for everyone inside.

`/arenainfo` (everyone, client side) prints the interior and room you are standing in, which helps when reporting
issues.

## Exports (server)

```lua
exports.mzb_arena:SetShow('concert')        -- true / false (unknown show; aliases work too)
exports.mzb_arena:GetShow()                 -- the current show's name
exports.mzb_arena:GetShows()                -- every show's name, sorted
exports.mzb_arena:SetDock('a', 'open')      -- 'a' | 'b' | 'c' | 'all', 'open' | 'close' | 'toggle'
exports.mzb_arena:SetLights({ on = true, mode = 'strobe', colors = { 'red', 'white' }, bpm = 150, house = 'off' })
exports.mzb_arena:LightPreset('goal')       -- a Config.LightPresets name (a goal horn script can call it)
exports.mzb_arena:GetLights()               -- the desk's current state
```

The current state is public in `GlobalState.mzbShow`, `GlobalState.mzbDock` and `GlobalState.mzbLights`, so a job
script or an ox_target panel can read it.

## Light desk (ACE `command.arena`)

The arena has its own light show on top of the interior's lighting: coloured spot lights from each show's rig (the
moving heads, beams and washes of the wrestling, concert and MMA rigs) and from the house lights up in the roof (every
show, and the only ones for hockey, basketball, tennis and the empty house). Every player in the bowl sees the same
show at the same moment.

`/arenalights` opens the desk: show lights on / off, the ring lights, blackout, the house lights (the show's
setting, full, dimmed, off), the effect, the movement, up to three colours from a palette or a colour picker, the speed
in BPM (with a tap button), intensity, the aim and presets. The desk's sections fold: click a section's title to put
it away, and the desk remembers. A look is built from independent parts, as on a lighting console:

- **Effect** (the colour and level of each fixture): static, chase, strobe, pulse, rainbow, fade (a slow crossfade
  through the colours), wave (a band of light rolling round the rig), flash (the whole rig hits on the beat and dies
  away), alternate (every other fixture, swapping on the beat), bounce (a block of light running end to end), twinkle,
  random, lightning (dark, with ragged white flickers), fire (warm flicker) and police.
- **Movement** (where the beams go, with any effect): still, sweep, ballyhoo, fan (the spots open out and close in),
  nod (tilting out to the stands and back) and cross (pairs swinging across each other).
- **Aim**: floor, stage, crowd - or several at once (the fixtures take turns), e.g. floor and crowd.
- **Ring lights**: the ring truss's, the cage truss's and the concert rig's own lights (they light the ring, the cage
  and the stage, with the show lights on or off - TV lighting for the match while the rest of the rig runs the
  show). They are on by default, each in the colour the build gave it; the desk turns them off, gives them all one
  colour, or sets their level.
- **Presets**: walk-in, entrance, goal, concert, party, fight, police, TV ring, storm, inferno, hype, house up,
  blackout, reset.

It also runs from chat:

```
/arenalights on | off | blackout | status
/arenalights mode wave                (the effect)
/arenalights move fan                 (none | sweep | ballyhoo | fan | nod | cross)
/arenalights color red white          (names from Config.LightColors, or #rrggbb; up to three)
/arenalights focus floor crowd        (one to three of floor, stage, crowd)
/arenalights ring on | off
/arenalights ring color red           (one colour for all of them; ring own = each its own colour again)
/arenalights ring level 60            (0-100)
/arenalights bpm 128 | intensity 80 | house dim
/arenalights preset storm
```

The interior's own (baked) lights can't change colour in GTA; the house buttons switch them between full, dimmed and
off, and the desk's colour comes from the spot lights it draws. That is why the rigs' ring lights are drawn by the
script (`shared/rig_lights.lua`, taken from the rig models, which no longer carry them). Players with
photosensitivity: `Config.LightMaxStrobeHz` caps the strobe (0 turns it into a pulse).

## The crowd (ACE `command.arena`)

Staff can fill the house: people in the bowl's seats, in the floor chairs of the shows that have them (wrestling, MMA,
basketball, tennis) and on the concert's standing floor, a row of them on the barricade. The stage end is only seated
for the shows that seat it: the end-stage shows kill the seats behind their masking, as real ones do.

```
/arenacrowd on | off | toggle         bring the crowd in / send it home (for everyone)
/arenacrowd mood show                 doors | show | peak | cheer
/arenacrowd staff on | off | toggle   the staff and the press who come in with the crowd
/arenacrowd litter some               clean | some | trashed: what the crowd leaves in the rows and on the floor
/arenacrowd                           what the crowd is doing
/arenacrowd mine 80                   how many crowd peds YOU see: anyone may set it, it is saved on your PC
```

The desk (`/arenalights`) has the same controls in its Crowd section, with a slider for your own count.

- **Moods**: `doors` (in their seats, on their phones, a few standing about), `show` (watching: most sit, some clap
  and film), `peak` (the whole house on its feet) and `cheer` (applause). `Config.CrowdMoods` sets what each one does
  and how much of the house sits. The light desk's presets carry a mood too (`mood` in `Config.LightPresets`: Goal!
  brings the house to its feet cheering, Walk-in sits it down); `Config.CrowdPresetMoods = false` leaves the crowd
  to you.
- **How many**: the game has room for 256 peds of every kind at once, and the arena has more than seventeen thousand
  seats. Each player sees up to `Config.Crowd.MaxPeds` people (210; `/arenacrowd mine` goes up to `MaxPedsLimit`,
  240): half of them are the house, the same for everyone, filling ringside and the lower rows first with people all
  round the bowl; the other half fill the seats round wherever you are. They sit in parties of one to four, the way
  a house fills. Lower it on a busy server: other players and the street's peds count against the same 256.
- **Round the building**: with the crowd come the concourse's people (`Config.Concourse`, 163 spots from the build):
  vendors and bartenders behind the tills with fans queueing, cooks, the shops' clerks, guards at the detectors and
  in the security office, medics, cleaners, people at the lobbies' high tables. The nearest 36 are made (8 while you
  are in the bowl, so the seats get the rest).
- **Cost**: the crowd is made of local peds, so nothing is synced but its on / off and its mood, and each player only
  makes it while inside the arena. It stops making people while the game is close to its ped limit
  (`Config.Crowd.PoolLimit`), and `Config.Crowd.Collision = false` lets players walk through it. People fade in
  rather than pop up (`FadeMs`), and a show can have its own mix of peds (`Config.Crowd.ShowModels`).
- **Staff and press** come in with the crowd, 9 to 18 per show, on top of your own count: security inside the
  barricades with their backs to the action, ringside / cageside / pit photographers (their cameras flash), camera
  operators with a shoulder camera or behind a tripod camera, the concert's crew at the mixing desk, ball kids
  kneeling at the tennis net and the back corners, and officials who sit at the basketball scorer's table, in the
  tennis umpire's chair, on the line judges' chairs and at the hockey timekeeper's desk. Every spot is the build's
  and checked like the seats: a floor under it, nothing in the way, clear of the chairs, the props and the tunnels'
  mouths. Who stands there is `Config.CrowdRoles` (their peds, what they do, the camera they hold or stand behind);
  `Config.CrowdStaffEnabled = false` turns them off for good.
- **Litter**: cups, cans, wrappers, food bags and bottles at the crowd's feet, in the rows and on the floor, at the
  level staff set (`clean`, `some`, `trashed`); it stays when the crowd goes home. Each piece is picked from its spot,
  so everyone sees the same mess, and only the nearest 260 within 60 m of you are put down (`Config.Litter`).

```lua
exports.mzb_arena:SetCrowd({ on = true, mood = 'peak' })   -- any of on, mood, staff, litter
exports.mzb_arena:GetCrowd()                               -- { on, mood, staff, litter }; also GlobalState.mzbCrowd
```

The spots come from the build (`client/crowd_slots.lua`): the seats and chairs of the interior itself, each one
checked against its collision.

## Fights

Bouts in the wrestling ring and the MMA cage: watch two NPCs fight, put a card of bouts on, take on an NPC yourself,
or fight another player. The server runs every bout: it makes the NPC fighters (networked, so everyone sees the same
fight), rings the rounds and calls the result from what it sees itself, never from what a client says.

```
/arenafight                              the bout on and the card (anyone)
/arenafight challenge                    an NPC takes you on (anyone in the arena; Config.Fights.challenge)
/arenafight challenge <id>               challenge a player, who answers /arenafight accept within 30 s
/arenafight npc [in <minutes>]           staff: an NPC bout on the card (now, or at a time)
/arenafight vs <id> [in <minutes>]       staff: a player against an NPC
/arenafight pvp <id> <id> [in <minutes>] staff: player against player
/arenafight stop | clear                 staff: stop the bout on / empty the card
```

The desk has a Fights section: pick the red and blue corners (an NPC or any player in the arena), when (next, or in
1, 5 or 15 minutes), add the bout; stop it; clear the card.

- **A bout**: a walk-out (the names on the screen, the fighters to their corners: a player who is not in the ring
  at the bell forfeits), then three rounds of a minute with breaks between them (`Config.Fights.rounds`,
  `roundSeconds`, `breakSeconds`). A fighter whose health falls to `koHealth` (125 of 200) is knocked out; one out
  of the ring for ten seconds loses on a count-out; one who leaves the server forfeits; after the last round the one
  with more health left wins on points. Nobody dies: the fighters are held above the line during the rounds and the
  loser is helped up healed. Players fight with their fists only.
- **The show goes with it**: everyone in the arena gets the fight bar at the top of the screen (the names, how much
  each has left, the round and its clock, the result, the next bout on the card), the bell and the knockout. The
  light desk's presets and the crowd's mood follow the bout (`Config.Fights.presets` / `moods`: entrance for the
  walk-out, fight for the rounds, goal for the result), and a followspot that is on follows the player fighters.
- **The card**: bouts go in the order they were added; one with a time waits for it; 20 seconds between bouts
  (`gap`). Switching to another show stops the bout on (no contest) and holds the card until the ring or the cage is
  back.
- Fighting another player needs the server to let players hurt each other (most do). The building has no ped
  navmesh yet, so the NPC fighters start face to face in the ring and are held inside it.

Exports (server): `AddBout(red, blue, inMinutes)` (red / blue = `'npc'` or a server id), `StopBout()`, `GetBout()`;
the state is `GlobalState.mzbFight` (and `mzbFightCard`).

## Slippery ice

While the `hockey` show is up, the rink's surface is GTA's ice: vehicles slide on it, and on foot you keep your
momentum. You glide on when you let go, overshoot a stop and drift through turns, and a hard turn at a sprint can put
you on the ice. `Config.Ice` sets how slippery it is, the top gliding speed, and whether players can fall and how
often.

## Video on the screens (pmms and other TV scripts)

Every show's screens are one object on one render target, **`mzb_screens`**, so a single media player drives them
all: the titantron with its lower panels and wings (wrestling), the LED wall and the side screens (concert), the LED
wall (MMA), and the centre-hung board's four faces (every show). The picture and sound come from one source. With
nothing playing, the screens are clear and the show's own graphics show through.

The object sits at the centre of the arena floor. There is one model per show:

| Show | Model |
|---|---|
| `wrestling` | `mzb_screens_wrestling` |
| `concert` | `mzb_screens_concert` |
| `mma` | `mzb_screens_mma` |
| `hockey`, `basketball`, `tennis`, `house` | `mzb_screens_board` |

**pmms:** add these to `Config.models` in pmms' `config.lua`, then stand in the bowl, open pmms and pick the arena
screens:

```lua
[`mzb_screens_wrestling`] = { label = "Maze Bank Arena screens", renderTarget = "mzb_screens" },
[`mzb_screens_concert`]   = { label = "Maze Bank Arena screens", renderTarget = "mzb_screens" },
[`mzb_screens_mma`]       = { label = "Maze Bank Arena screens", renderTarget = "mzb_screens" },
[`mzb_screens_board`]     = { label = "Maze Bank Arena screens", renderTarget = "mzb_screens" },
```

Any other TV or cinema script that plays on a model through a named render target works the same way: register the
model(s) above with the render target `mzb_screens`. Switching the show swaps the screen object, so start the video
again after a switch.

## Built-in screen player (ACE `command.arena`)

The arena can play on its own screens without another resource: a YouTube video, a cycle of pictures or one
picture, on every screen of the show at once, the same moment for every player (late joiners too). Run it from the
light desk's **Screens** section (paste a link, play / pause / off, volume, picture sets) or from chat:

| Command | What it does |
|---|---|
| `/arenascreen <youtube link or id>` | play a video (watch, youtu.be, shorts, embed and live links all work) |
| `/arenascreen <picture url> [more ...]` | one picture, or a cycle of several (https only) |
| `/arenascreen images [set]` | a picture set from `Config.Media.imageSets` (no name: the show's own set) |
| `/arenascreen look <name>` | an LED-wall look drawn in step with the lights: show, pulse, colour, bars, stripes, waves |
| `/arenascreen pause` / `resume` / `off` | |
| `/arenascreen volume <0-100>` / `interval <s>` | the video's volume; seconds per picture |
| `/arenascreen status` | what is on |
| `/arenascreeninfo` | for you only: whether the screens' page loaded and is being drawn (to report a dark screen) |

The video's sound comes from the screens' browser, which is not positional: it is full in the bowl, low in the rooms
that open onto it (concourse, tunnel, backstage, stairs: `Config.Listener`) and silent outside the building.

**Picture sets** ship for every show (`html/img/`, from the arena's own boards: the house's welcome and sponsor
cards, SAPW for wrestling, the Sirens for the concert, SAFC for MMA, and a live card each for hockey, basketball and
tennis). Your own pictures go in `html/img/` and into a set in `Config.Media.imageSets` as `img/<file>`; restart the
resource.

**Looks** are drawn by the page itself from the light desk's colours, effect and speed, with the show's name or logo
over them (`show` breathes the show's artwork). The desk's presets bring one up with the lights (`screen` in `Config.LightPresets`) while the screens show a
look or nothing; `Config.Media.presetLooks = false` leaves the screens to you.

**How it is drawn:** the page is loaded from the resource's own https address and drawn over the screens' texture
(`Config.Media.method = 'replace'`). `'rendertarget'` is the older way, kept for servers where another script owns
the texture.

**Living with pmms and TV scripts:** the built-in player only touches the `mzb_screens` render target while it is
playing something. Turn it off (`/arenascreen off`) before starting pmms on the screens, or set
`Config.Media.enabled = false` to leave the screens to the other script for good.

**YouTube:** some videos refuse to play embedded (the owner turned embedding off, or age / region limits); the
screens then stay dark, and a picture cycle or a look still works.

Exports (server): `SetScreenMedia(urlOrListOfPictureUrls)`, `ScreenImageSet(name)`, `ScreenOff()`,
`ScreenPause(on)`, `ScreenVolume(0-100)`, `GetScreenMedia()`. Client: `IsScreenMediaOn()`.

## Music player (ACE `command.arena`)

Music off the light desk, heard from the show's PA speakers, with no sound resource needed (no xsound). Paste a link
in the desk's **Music** section or use chat; every player hears the same moment of the track (late joiners too):

| Command | What it does |
|---|---|
| `/arenamusic <url>` | play a direct audio file or stream (mp3, ogg, m4a, an icecast / shoutcast stream) or a YouTube link |
| `/arenamusic pause` / `resume` / `stop` | |
| `/arenamusic volume <0-100>` | the level for everyone |
| `/arenamusic status` | what is playing (anyone may ask) |
| `/arenamusic mine <0-100>` | **your own** level, for you only, kept between sessions (anyone; also the desk's "Mine" slider) |

How it sounds: each PA hang of the show is its own source in the world (`Config.Music.hangs`: the ring truss's
corners for wrestling and MMA, either side of the stage for the concert, the centre-hung board otherwise). You hear
each one from where it hangs, louder as you walk up to it and from the side it is on as you turn, and the room shapes
it: full with the arena's echo in the bowl, muffled and quieter in the rooms that open onto it (concourse, tunnel,
backstage, stairs), faint elsewhere in the building, nothing outside. Far from the arena (`Config.Music.range`) the
track is not even loaded.

**What gets the full treatment:** placing the sound at the hangs, the filter and the echo need the browser to read
the audio, which the audio's server must allow (CORS: `Access-Control-Allow-Origin`). Files and streams from servers
that do not send it still play, but with the level only; so does YouTube (the player is a hidden YouTube embed,
whose sound a page cannot touch). Plain `http://` links may be blocked by the game's browser: use `https://`.
A link that will not play is reported once to whoever started it, not to everyone.

Exports (server): `PlayMusic(url)`, `StopMusic()`, `PauseMusic(on)`, `MusicVolume(0-100)`, `GetMusic()`.

## Footsteps and reverb

Footsteps are the game's quiet ones inside the building (`Config.QuietFootsteps`), and the rooms' reverb is shorter
than before (`audio/mzb_arena_game.dat151.rel`): steps no longer ring round the hall. The arena makes no room tone
and no crowd noise of its own: play what you like through the music player.

## Followspot (ACE `command.arena`)

One or two followspots high on the bowl's long sides (`Config.FollowSpot.fixtures`), run by an operator from the
desk's **Followspot** section or chat:

| Command | What it does |
|---|---|
| `/arenaspot on` / `off` | |
| `/arenaspot follow <id \| me \| look>` | lock onto a player: a server id, yourself, or whoever is under your crosshair |
| `/arenaspot free` or the key **F7** | grab free aim: the spot follows your camera; again to let go (it stays put) |
| `/arenaspot color <name \| #rrggbb>` / `size <2-15>` / `intensity <0-100>` | |
| `/arenaspot status` | |

Locked onto a player, every client follows that player itself, so it is smooth and sends nothing over the network.
Free aim sends the operator's aim point at most 8 times a second (`Config.FollowSpot.sendRate`); the server keeps it
inside the arena and only one operator aims at a time. Players can rebind the key under Settings > Key Bindings >
FiveM ("Arena followspot").

Exports (server): `SetFollowSpot(patch)`, `FollowPlayer(serverId)`, `GetFollowSpot()`.

## More stage lights (`Config.LightRigExtra`)

The light desk runs fixtures of your own on top of the build's rig: `Config.LightRigExtra[show]` is a list of
`{ x, y, z, dx, dy, dz, g }` (world position, the direction it points at rest, the group: 1 moving head, 2 wash,
3 house light, 4 floor beam). Floor beams keep their own aim whatever the desk's aim is, and take the desk's colour
and effect. Out of the box it adds, at the stage end: moving heads half way between the build's heads on the
wrestling stage trusses, washes on the concert's wash bar, and four floor beams along the back of the stage end
(wrestling, concert, MMA), either side of the middle, shooting up and out over the floor. `Config.LightMaxFixtures`
is 40: the roof's house lights are the ones left out when a rig has more. Move or remove any of them to taste.

**Ramp lights** (`Config.RampLights`): twelve small fixtures along the wrestling ramp's two top edges, each aimed
across the ramp and a little down, so its beam lands on the ramp and whoever walks it, in the desk's colours and
effects (a chase runs from the stage to the ring), their lenses glowing so the edges read as two rows of lights.
With the show lights off they rest in `Config.RampLightIdle` (a dim blue; `false` = dark). They do not count against
`Config.LightMaxFixtures`.

## Props of your own (`Config.ShowProps`)

Vanilla props put down for a show without CodeWalker: `Config.ShowProps[show]` is a list of
`{ model, x, y, z, heading, ground = true, room = 'backstage' }` (local props, frozen, made while you are in the
arena; `ground` drops the prop onto the floor under it, `room` is the interior room it stands in when that is not the
bowl; `/arenainfo` prints where you stand). Out of the box:

- **The interview set** (wrestling, MMA): a green screen in the backstage hall, off the east wall north of the
  tunnel, with a TV camera on it and two studio lights.
- **A camera crane** on the wrestling stage deck beside the titantron, its arm up over the stage's lip towards the
  ring.

Take a line out of the list to remove a prop, or move it.

## Configuration (`shared/config.lua`)

- `Config.DefaultShow`: the show the server starts with.
- `Config.Shows`: which entity sets each show turns on. You can remove a show, or make your own mix from the sets
  listed there.
- `Config.ShutterSeconds`: how long the roller doors take to open or close.
- `Config.DockButtons`: the **E** prompt at each roller door (`false` = staff commands only).
- `Config.DockAccess`: who may use it: `false` for everyone, or an ACE such as `'command.arena'` for staff only.
- `Config.DockReach` / `Config.DockReachVehicle`: how close you must be, on foot and at the wheel (metres).
- `Config.Command`: the name of the admin command.
- `Config.QuickCommand`: the quick switch's name (`mzb`), or `false` to turn it off.
- `Config.ShowAliases`: other words the quick switch accepts for a show.
- `Config.SwitchCooldown`: seconds between two switches.
- `Config.AnnounceSwitch`: `true` tells every player in chat when the show changes.
- `Config.LightCommand` / `Config.LightAccess`: the light desk's command and who may use it (an ACE, or `false` for
  everyone).
- `Config.LightPresets` / `Config.LightColors`: the desk's presets and named colours: add your own.
- `Config.LightBrightness`, `Config.LightCone`, `Config.LightSpread`, `Config.LightMaxFixtures`,
  `Config.LightLensGlow`: how the show lights look and how many are drawn.
- `Config.LightMaxStrobeHz`: the fastest strobe (0 = no strobing).
- `Config.RingLightScale`: how bright the rigs' own ring lights are drawn (`shared/rig_lights.lua` has each one's
  place, colour and strength). `Config.RingLightGroup`, `Config.RingLightColor`, `Config.RingLightBrightness`: for a
  show without lights of its own, which of the rig's fixtures stand in (2 = the washes), their colour and brightness.
- `Config.QuietFootsteps`: the quiet footsteps inside. `Config.Concourse`: the people round the building.
- `Config.LightRooms`: the rooms the light show is drawn in.
- `Config.HouseSets`: the interior's house light sets the desk switches.
- `Config.Ice`: the hockey ice (on / off, the shows it is down for, how slippery, falls).
- `Config.CrowdCommand` / `Config.CrowdAccess`: the crowd's command and who may bring it in (an ACE, or `false` for
  everyone).
- `Config.Crowd`: how many people a player sees, the share that fills the seats near them, the ped models, whether
  they collide. `Config.CrowdMoods` / `Config.CrowdAnims`: what the crowd does in each mood.
- `Config.CrowdRoles` / `Config.CrowdStaffEnabled`: the staff and the press (their peds, what they do, their cameras).
- `Config.Litter`: the litter (how much, how near, the props).
- `Config.Fights`: the bouts (rounds, times, the knockout line, the count-out, who may challenge, the NPC fighters'
  models and names, the rings, the cues for the lights and the crowd).
- `Config.RampLights`: the wrestling ramp's lights. `Config.ShowProps`: props of your own per show.

## Notes

- There is no ped navmesh inside the building yet. Players can go everywhere, but ambient NPCs will not walk it (the
  crowd and the staff stand where they are put; the NPC fighters start face to face).
- Framework independent: plain FiveM natives only, with no ESX / QBCore / Qbox requirement.

## Changes

- **1.1.1**: the ring to size, a ramp without steps.
  - **The ring is 20 ft x 20 ft** (it was 24 ft), on round posts. The fights' corners and ring-out line
    (`Config.Fights.venues.wrestling`) follow it.
  - **The ramp is one flat slope** from the stage's lip to the floor at the barricade: the two steps at its foot are
    gone. The ramp lights (`Config.RampLights`) follow it.
  - **A camera crane** on the wrestling stage and **an interview set** (green screen, camera, lights) in the
    backstage hall, both from `Config.ShowProps`.
  - The synthesised room tone and crowd noise are gone, with `/arenaambience`, the desk's "Room" slider and
    `Config.Ambience`. The quiet footsteps stay (`Config.QuietFootsteps`), and so does the shorter reverb.
- **1.1.0**: the house fills up, and the desk runs the whole show.
  - **The crowd**: people in the bowl's seats, in the shows' floor chairs and on the concert's standing floor,
    brought in and sent home from the desk or `/arenacrowd`, in four moods (doors, show, peak, cheer). They are
    local peds: each player sees up to 210 (their own setting), half of them the house's fixed order, half in the
    seats round them. The light desk's presets set the mood with the look. Round the building: vendors, queues,
    cooks, clerks, guards, medics, cleaners and people at the lobbies' tables.
  - **Built-in screen player**: YouTube videos, picture cycles and single pictures on every video screen of the
    show, the same moment for every player (`/arenascreen`, the desk's Screens section), a picture set for every
    show, and LED-wall looks that follow the lights. It draws on the screens only while it plays, so pmms and TV
    scripts still work.
  - **Music player**: `/arenamusic <url>` or the desk's Music section, heard from the show's PA hangs, each one a
    source in the world: the room's filter and an arena echo, muffled next door, nothing outside. Files, streams and
    YouTube; every player has their own level (`/arenamusic mine`).
  - **The arena's own sound**: a room tone and the crowd's murmur (`/arenaambience`), quieter footsteps and a
    shorter reverb.
  - **Ring lights you can run**: the rigs' own lights over the ring, the cage and the stage are drawn by the desk
    now (they were always on): off, one colour, a level.
  - **Walls that stay**: about four thousand faces of the interior belonged to the room next door, and the game
    leaves another room's faces out unless you are looking through a doorway to it. From the seats that was the
    vomitories' side walls and the ad panels on the cross aisle; in the rest rooms and stairs off the lobbies a wedge
    of the dark wall over the doorway; inside the two stairs, parts of their walls; under the stands, the ring
    corridors' ceilings; from the floor, patches of the stage end's masking drape. Every face now belongs to the room
    that sees it. The corner vomitories' corridor walls are closed to the bowl's (you looked down a gap behind them).
  - **Floor gaps**: fourteen thin gaps where a floor stopped short of a wall's foot in the event level's ring
    corridors (you could see out under the building) are closed.
  - **Locker rooms**: the stretches of the two big locker rooms' walls that were the neighbouring rooms' plaster are
    tiled like the rest.
  - **ox_lib** (optional): `/mzb` or `/arena` alone opens an ox_lib menu of the shows, the dock doors and the light
    desk, and the answers are ox_lib notifications, when the server runs ox_lib. Not a dependency.
  - **Followspot**: one or two operator-run followspots (`/arenaspot`, the desk's Followspot section), locked onto
    a player or aimed by hand from the operator's camera (F7).
  - **More stage lights**: `Config.LightRigExtra` adds fixtures to a show's rig. Out of the box: six more heads on
    the wrestling stage trusses, five washes on the concert's wash bar and four floor beams at the back of the stage
    end. `Config.LightMaxFixtures` is 40.
  - **Staff and press** with the crowd: security, photographers with flashes, shoulder and tripod camera crews, the
    concert's crew, ball kids, and officials seated at the scorer's table, in the umpire's chair, on the line judges'
    chairs and at the timekeeper's desk, in every show but the empty house (`/arenacrowd staff`).
  - **Litter**: clean, some or trashed, the same for everyone (`/arenacrowd litter`, the desk).
  - **Fights** in the ring and the cage: NPC bouts, a card with times, challenge an NPC or another player; the server
    calls knockouts, count-outs, forfeits and points; a fight bar for everyone in the arena (`/arenafight`, the
    desk's Fights section).
  - **Ramp lights**: twelve fixtures along the wrestling ramp's edges, run by the desk.
  - **Props of your own** per show (`Config.ShowProps`).
  - The desk's sections fold away (click a title); it remembers which.
  - New exports: `SetCrowd`, `GetCrowd`, `SetScreenMedia`, `ScreenImageSet`, `ScreenOff`, `ScreenPause`,
    `ScreenVolume`, `GetScreenMedia`, `PlayMusic`, `StopMusic`, `PauseMusic`, `MusicVolume`, `GetMusic`,
    `SetFollowSpot`, `FollowPlayer`, `GetFollowSpot`, `AddBout`, `StopBout`, `GetBout`.
- **1.1.0** (continued): the light desk grows up.
  - Eight new effects (fade, wave, flash, alternate, bounce, twinkle, lightning, fire) and the
    movement is its own control (still, sweep, ballyhoo, fan, nod, cross), so any effect runs with any movement.
    Sweep and ballyhoo as modes still work (from chat, exports and old presets).
  - Aims combine: floor, stage and crowd in any mix, the fixtures taking turns.
  - New presets: TV ring, storm, inferno, hype. Blackout also kills the ring lights.
- **1.1.0** (continued): the event level, backstage and the gateways reworked.
  - **The Gorilla position** is rebuilt as a proper room between the event tunnel and the stage: the producers' desks
    (two seats each) along the back wall, the timekeeper's and match producer's desk at the top, the ARENA exit straight
    onto the stage stairs, and a BACKSTAGE opening on each side into the backstage areas behind the masking (they were
    walled off). Same look as before (dark wood, LED dado, the show's screens), now with a solid panel ceiling. All four
    openings (the walk-out, the entrance from the tunnel and the two BACKSTAGE ones) have the walk-through curtain,
    each wider than its opening and hung just under its head, instead of doors.
  - **Walls popping in and out**: faces that ran across two rooms (the media room's tiled wall, the locker rooms'
    walls, the reveals of every door, tunnel and vomitory, and many more) are cut at the dividing walls and doorways,
    and each piece belongs to the room it faces. The floor collision now changes room exactly at each doorway and inside
    the vomitories: standing just past a door could make the game hide the room you were standing in.
  - **The event-level ring corridor** is 3.4 m wide all the way round: the west arcs (2.0 m) are widened outwards, the
    backstage's east wall moved back to make room (on the south arc, by the locker rooms, it narrows to 2.6 m for a
    few metres). Four side hallways off the west arcs end in fixed double doors (ELECTRICAL, SECURITY, COMMS ROOM,
    PLANT ROOM); the new signs are in `mzb_tx_event`.
  - **Box office windows**: the 20 ticket windows in the facade's diagonal sections looked straight into the concourse
    through the arena's own glass and its mullions. They now have closed roller shutters (placed outside the interior,
    in `mzb_arena_milo.ymap`, so they always draw from the street).
  - The Gorilla's openings are signed (ARENA to the stage, BACKSTAGE either side).
  - **Stair landings**: the top landings of the NW and SE stairs (concourse level) were open over the flight below for
    about 1.5 m (a 4.5 m drop). A concrete parapet, 1 m high with collision, now continues the dividing wall.
  - **Bowl exits**: the floors of the passages from the bowl into the ring corridor were black matting; they are the
    corridor's concrete now.
  - **Flickering walls (z-fighting)**: wherever two surfaces lay in exactly the same plane they flickered in a sawtooth
    against each other - the black fascia band round the front of the upper tier over the concrete, the stowed seating's
    fascia, stair and seat nosings over the treads, the PA speakers' grilles, the Gorilla's LED dado, finishes in the
    toilets, locker rooms and backstage, the locker-room mirror over its tiles, the flight cases' trims and corners. The
    surface that belongs on top now sits 3-6 mm proud of the one under it (the mirror's reflection plane moved with
    it). The side hallways' door details and signs are spaced off the door and back plate the same way.
  - A 13 cm slot along one riser row of the lower seats (over the rooms under them, both sides and the east end) is
    closed: the rooms' ceilings showed through it, and from the bowl it was a black line.
  - The security control room's north wall and parts of the SE stair's shaft belonged to the neighbouring rooms.
  - The roof deck and trusses over the middle of the bowl belonged to the concourse: looking up from the floor showed
    holes to the sky. A strip of the corridor floor along the east store and the garage belonged to those rooms (a
    gap along the wall).
  - The backstage door into the NW stair is rebuilt square to the stair's angled wall (the wall ran through its frame).
  - The cream panel sticking out of the wall by the locker-room door in the backstage hall is gone, with the 1 cm
    ceiling and floor stripes along that wall.
  - Toilet stall doors no longer swing into the partitions and walls (each door has its own stops).
  - **Gateway doors**: the north, west and south entrances could not be walked through - the building's collision still
    had the facade glass across them (only the east one was open). All four are open now.
  - Mirrors: the concourse rest rooms' mirrors are reflective glass (only one live mirror per room works in GTA); the
    single-mirror rooms keep live mirrors, fixed.
  - Outside sounds: the street, the wind and the rain are no longer heard inside (`audio/mzb_arena_game.dat151.rel`
    and portal audio occlusion).
  - The interior's exit-portal count includes its mirrors, as in 1.0.2: 48 for the rebuilt interior (44 openings and
    4 mirrors).
- **1.0.2**: the interior's exit-portal count now includes its mirrors, the way Rockstar's own interiors count them
  (62 instead of 44). Preventive: no arena fault was reported, but the same miscount was involved in a client crash
  in another interior. Only `stream/interior/mzb_arena_milo.ymap` changed.
- **1.0.1**: fixed players sinking through the floor on the four corners of the bowl (the walkway between the lower and
  upper seats and the mouths of the upper-deck entrances). The collision on the curved parts was built inside out.
  Basketball is now the Los Santos Panic (purple and gold court with the team's crest) vs the Vice City Narcos, hockey
  the Los Santos Dust Devils vs the Los Santos Kings. The Arena War banners on the outside of the building
  (`xs_arena_banners_ipl`) are removed while the resource runs.

## License

Free to use on your own servers, but **not open source**. You may not sell, re-upload or redistribute this resource,
or reuse any part of it (models, textures, collision, maps, scripts) in another resource, free or paid. See
[LICENSE](LICENSE).
