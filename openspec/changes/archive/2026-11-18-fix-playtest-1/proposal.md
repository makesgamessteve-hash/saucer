## Why

The 2026-11-17 playtest (docs/playtest/2026-11-17.md) found that the hull
never mends on its own. The Steady buff (Sunfruit omelette, Hull-plate stout)
promises that "the hull mends twice as fast" and the home-life spec says buffs
scale hull regen, but only shields recharged, so Steady did nothing. A player
who folds back at hull 30 with no credits also had no way to mend the hull
except selling something.

## What Changes

- ADDED `hazards-and-failure`: Hull mending. In open space the hull mends
  slowly (0.1 points a second, after the same no-hit delay as shields);
  Steady doubles it. Inside a site nothing mends. After a Fold Retreat a
  message says so and points at the trade terminal for an instant repair.

## Impact

- Code: `sim/hull.lua`, `sim/game.lua`, `sentries/sentries.lua` (`hull_regen`).
- Replays and saves are unaffected in format; hull values in open space now rise.
