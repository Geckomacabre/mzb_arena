# Changes for the next version (fold into the README's changelog at merge)

## Built-in screen player
- New: YouTube videos, picture cycles and single pictures on every video screen of the show, synced for every player
  (late joiners land on the same moment). The light desk has a Screens section; `/arenascreen`; server exports
  `SetScreenMedia`, `ScreenImageSet`, `ScreenOff`, `ScreenPause`, `ScreenVolume`, `GetScreenMedia`, client export
  `IsScreenMediaOn`.
- Draws on `mzb_screens` only while it plays, and releases the render target when off, so pmms and TV scripts still
  work; `Config.Media.enabled = false` turns it off for good.
- The video's volume follows where the listener is (bowl / next door / building / outside: `Config.Listener`).
- New files: `client/listener.lua`, `client/media.lua`, `server/clock.lua`, `server/media.lua`, `html/screen.html`,
  `html/screen.js`, `html/media.js`, `html/img/`. Config: `Config.Listener`, `Config.ClockResync`, `Config.Media`.

## Music player
- New: a music player on the light desk (Music section) and `/arenamusic <url | pause | resume | stop | volume n |
  status>`, heard from the show's PA hangs (`Config.Music.hangs`): level by distance, stereo pan, the room's filter
  and a generated arena echo (Web Audio), full in the bowl, muffled next door, nothing outside. Files, streams and
  YouTube; without CORS (and on YouTube) the level only. Synced on the server's clock; a late joiner lands mid-track.
- Each player's own level: `/arenamusic mine <0-100>` or the desk's Mine slider, kept with KVP.
- A dead link or a refused play() is reported once, to whoever started the track.
- Server exports `PlayMusic`, `StopMusic`, `PauseMusic`, `MusicVolume`, `GetMusic`.
- The screen player now takes its position from the same server clock as the music (no extra event).
- New files: `client/music.lua`, `server/music.lua`, `html/music.js`. Config: `Config.Music`.

## Followspot
- New: one or two operator-run followspots high on the bowl's long sides (`Config.FollowSpot`). Lock onto a player
  (server id, yourself, or whoever is under your crosshair: every client tracks the ped itself) or grab free aim with
  a key (default F7, `RegisterKeyMapping`): the operator's camera point goes to the server at most 8 times a second,
  is checked to lie inside the arena and passed on to the players near it, who glide the beam after it.
- Desk Followspot section (on / off, follow a player in the arena, looked at, free aim, size, intensity, colour),
  `/arenaspot`, server exports `SetFollowSpot`, `FollowPlayer`, `GetFollowSpot`.
- New files: `client/spot.lua`, `server/spot.lua`, `html/spot.js`. Config: `Config.FollowSpot`.

## More stage lights
- New: `Config.LightRigExtra[show]` adds fixtures to the show's rig without touching the build's file; merged in
  client/lights.lua in group order (house lights last, so they are what `Config.LightMaxFixtures` leaves out).
- New fixture group 4, floor beams: they keep their own aim (`Config.LightConeFloor` sets their beam).
- Out of the box: 6 heads on the wrestling stage trusses, 5 washes on the concert wash bar, 4 floor beams at the back
  of the stage end for wrestling, concert and MMA. `Config.LightMaxFixtures` 32 -> 40.
