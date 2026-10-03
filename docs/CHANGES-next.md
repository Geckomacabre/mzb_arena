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
