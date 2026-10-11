# mzb_arena_clothes

The shirts the merch stands of [mzb_arena](https://github.com/Geckomacabre/mzb_arena) sell, as clothing for the two
freemode characters: 22 tops each (11 tees and 11 tank tops, eight looks a top), in the collections `mp_m_mzbmerch`
and `mp_f_mzbmerch`. With this resource running, the tees hanging on a stand's walls can be tried on, bought and
worn. Without it the arena works all the same; the tees on the walls are then dressing and nothing is offered at them.

## Read this before you install it

**Every clothing pack adds a metadata file (`.ymt`) to the freemode character it dresses, and the game has room for
only a few of those.** How many depends on the game build. The community's measurements
([docs.gta.clothing](https://docs.gta.clothing/game-mechanics/game-limits-and-crashes)), for each of the two
characters:

| Game build | 3095 | 3258 | 3407 | 3570 | 3717 | 3889 |
|---|---|---|---|---|---|---|
| Places for clothing packs, about | 10 | 8 | 6 | 5 | 4 | 3 |

One collection too many and **every player crashes as their character is made**. The client's log ends like this:

```
SCRIPT ERROR: Error executing native 0x00a1cadd00108836 at address FiveM_b3407_GTAProcess.exe+...
```

(`0x00a1cadd00108836` is `SetPlayerModel`), followed by a null-pointer crash. The pack that goes over the limit is
not broken, and neither is the one before it: the server is out of places.

**Count before you add it.** In all your resources' `stream` folders, count the files named
`mp_m_freemode_01_<something>.ymt`, and the same for `mp_f_freemode_01_`. A plain `mp_m_freemode_01.ymt` replaces
the game's own and does not count. An `mp_creaturemetadata_<something>.ymt` counts for both characters. This pack is
one more for each.

## Install

- **Room to spare:** put the `mzb_arena_clothes` folder beside `mzb_arena` and add `ensure mzb_arena_clothes` to
  `server.cfg`. Nothing else to set.
- **No room:** leave it out, or merge its files into a clothing pack you already run (the tools that merge packs
  renumber the drawables). Then, in `mzb_arena/shared/config.lua`, set `Config.MerchShop.collection` to that pack's
  two collections, `drawableOffset` to the number of tops (jbib) that come before the arena's first in each, and
  `pack = false`.

## What is in it

- `stream/`: per character one `.ymt`, 22 drawables (`jbib_000` .. `jbib_010` the tees in the order of
  `Config.MerchTees`' stands, `jbib_011` .. `jbib_021` the same as tank tops) and eight textures for each.
- `data/`: the two shop metas (nothing for sale in them: the arena's own script sells the shirts).

Free to use on your server; see LICENSE (no resale, re-uploads or reuse of parts).
