# Change: Live-in interior (milestone 2)

## Why
After milestone 1 the Villa is a set you walk through rather than a home you
use. The helm desk blocks the view in flight, folding is a uniform scale,
nothing can be used except the helm, and the game starts already standing.
Milestone 2 of `docs/ROADMAP.md` makes the interior something you live in.

## What Changes
- Wake-up start: every player wakes up beside their bed. A title card
  offers "Get up" and "Load saved game", driven with the move stick and Use
  on keyboard, gamepad and touch.
- Sliding doors for the bedroom and bathroom. They open as a body comes
  near and are solid while mostly closed.
- Furniture Use through a station table in `saucer/interior.lua` with
  handlers in `sim/home.lua`: kitchen (well fed, ×1.5 Charge regeneration
  for five sim minutes), shower, engine console readout, lab bench (a place
  for milestone 3 identification), trade terminal (a place for milestone 3
  trading), and bed (sleep until morning: refill Charge and save; or load).
- Panels (`sim/panel.lua`): a small deterministic menu system in the sim
  state (kind, selection) that systems register rows with.
- Helm console: a low desk with a radar well and two angled wing screens
  showing live Charge, hull, shield, hold slots and the size ladder, kept
  below the pilot's sight line.
- The fold is a packing (`sim/fold.lua`): the 11 room groups pack one after
  another, farthest from the pilot first. Each flattens, then slides into
  fold-space. The hull keeps its size during the room phase, then shrinks
  about the eye. Unfolding reverses this. Shrink takes 1.5 s and grow 1.8 s
  (concept v0.5).
- Save and load (`sim/save.lua`): seed, mod list, world diffs and
  per-player records written through `saucer.save` (atomic write). Loading
  rebuilds the universe from the seed and lays the diffs over it. A
  different mod set needs a second confirmation.
- Engine: `--windowed` runs a `--script` in a real window, for screenshot
  tours (`tools/shots/m2.lua`).

## Impact
- Affected specs: saucer-interior, saucer-configurations, persistence
- Affected code: `data/base/saucer/interior.lua`, `saucer/configs.lua`,
  `scripts/sim/{game,home,panel,fold,save,avatar,mystery,ship,autopilot}.lua`,
  `scripts/view/{render,hud,assets}.lua`, `meshes/interior.lua`,
  `engine/src/core/sx_engine.c`, `engine/src/platform/sx_sdl_main.c`
- Determinism: the sim version is now 3, and `tests/replays/slice_seed42.srep`
  was re-recorded. Loading reads the user's save file inside the sim step.
  That is deterministic for a given file, and the committed replays never
  load.
