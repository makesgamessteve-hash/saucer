## Why

The ten-run playtest of 2026-11-17 (docs/playtest/2026-11-17.md) ended with
eleven prioritised recommendations: nothing to spend on after Fold Core T2,
the lab's single queue causing most dead air, no warning before folding into
danger a Villa can't survive, nothing pointing at the Seat in guarded sites,
15 s of walking per find, a pickpocket on every visit, free Fold Retreats, a
Warden that switches off for good at the grid console, co-op that never needs
two players, an overloaded X key with HUD text running off screen, and story
items sold to the scrap dealer without a word.

## What Changes

- ADDED `saucer-upgrades`: five upgrades at trade terminals and station
  chandlers (helm beam relay; after Fold Core T2: tractor coils, hold racks,
  shield cells, a second lab bench), 180-500 c a level, 2.5k c in all.
- ADDED `items-and-identification`: decodes jump the Identify queue; the
  second bench runs two jobs at once.
- ADDED `fold-jumps`: a fold warning (soft gate) the first time you fold
  deeper than you have been; co-op fold readiness ("ready to fold").
- ADDED `sentries-and-tools`: the first Watcher lock on a Villa gives a Seat
  tip, and entering a guarded site in the Villa names the Watchers.
- ADDED `tractor-beam`: the helm beam relay pulls size S/M finds from the helm.
- ADDED `station-visits`: the pickpocket works the first visit, then a 25%
  roll per visit with two quiet visits after a strike (sure after six).
- ADDED `hazards-and-failure`: a tow bill for Fold Retreats at danger 2+
  (60/120 c, credits first, then Charge; never lethal).
- ADDED `sentries-advanced`: the Warden stays awake at half speed when the
  grid is down, and wakes no Snatchers then.
- ADDED `coop-local`: twin vaults (one saucer holds the shutter anchor, the
  other beams; both get a prize), party requests (three items from at least
  two players, everyone is paid).
- ADDED `player-input` / `touch-controls`: the grapple has its own key (Y,
  D-pad up, right-half 0, touch GRP); the Shroud key no longer grapples.
- ADDED `hud-readability`: wrapped messages with repeats folded and the most
  urgent first, one ordered centre alert stack, control hints for the current
  mode only, no overprinting on foot.
- ADDED `trading`: story items (data cores, holodeck modules) warn before a
  sale; a second pick sells.

## Impact

- Code: new `sim/upgrades.lua`, `sim/twin.lua`, `economy/upgrades.lua`;
  `sim/game.lua`, `lab.lua`, `trade.lua`, `requests.lua`, `coop.lua`,
  `galaxy.lua`, `hull.lua`, `sentry.lua`, `warden.lua`, `excursion.lua`,
  `visit.lua`, `tractor.lua`, `autopilot.lua`, `view/hud.lua`, `render.lua`,
  `xr.lua`; `input/default.lua`; `engine/src/core/sx_touch.[ch]`.
- State version 10. Replays `tests/replays/*.srep` re-recorded (the command
  frame gains the `grapple` button; the sim changed).
- Playtest harness (`tools/playtest/`) buys upgrades, reads the warnings,
  holds and beams twin vaults; before/after numbers in
  `docs/playtest/2026-11-17-after.md`.
