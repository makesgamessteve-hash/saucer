## Why

Plan phase 9. Phase 8 put relics into normal play, but every Seat branch ends in a chamber you can only fly into,
and the one lock is the reliquary's Seat-lock. Phase 9 adds short trips on foot: small pockets past crawlspaces no
saucer fits, one of which holds a hand-lock that opens a sealed chamber elsewhere in the relic. Stations should be
interesting to explore, and a few minutes on foot, out of a chamber and into a crawlspace, adds that.

## What Changes

- **Foot pockets** (`sim/relicfoot.lua`, run once per generated relic on a derived copy, so the generator's memoized
  ruin stays as generated). There are 1-3 pockets, set by the builders' body scale: tiny 3, human 2, large 2, giant 1,
  colossal 1. Each pocket opens off a Seat chamber, never a hall, the heart or the main route, through a side with no
  door.
  - The crawlspace is 8-28 m long, a 4 m tube lined down to a 1 x 1 m channel. The Seat cannot follow you in.
  - It leads to an 8 x 4 x 8 m pocket room where you can stand. The chamber floor is the ledge you step out on.
  - The walk in is at most 60 m.
- **Roles.** Each pocket room holds one thing. The hand-lock comes first when a chamber is sealed. The others are a
  Delicate find, a sentry-grid console or a lore niche, in seeded order.
- **Locks.**
  - The hand-lock seals the richest chamber holding at most 15% of the relic's value. Its shutter is solid until the
    hand-lock turns.
  - One or two more chambers get Seat-locks (`chamber = true`). Chambers with finds are picked first, then empty ones.
    With the reliquary's Seat-lock, 60-75% of the locks are Seat-locks.
  - Snatcher nests are never sealed. At most one pocket opens off a guarded (nest) chamber.
  - The main route and the heart are never behind a lock that needs you on foot.
- **On foot.**
  - The excursion reads every crawlspace and pocket room (`ruin.foot.areas`), and the HUD names them CRAWLSPACE and
    POCKET.
  - A lore niche reads out its glyphs (USE: READ THE GLYPHS). The text comes from the civ's lore, with a fallback for
    the Vyrr slice.
  - The lock messages say whether a sealed chamber opened or the reliquary did.
  - The view draws a crawlspace mouth frame for every pocket and a glow on lore niches.
- No state version bump: pockets and locks are derived from the seed. Opened hand-locks use the existing
  `state.locks`, and opened Seat-locks use `state.relic_locks`. Replays are unchanged.

## Impact

- Specs: `relic-stations` (ADDED: foot pockets, the lock mix), `on-foot` (ADDED: pocket rooms and lore niches),
  `sentries-and-tools` (ADDED: guarded pockets)
- Code: `sim/relicfoot.lua` (new), `sim/game.lua`, `sim/relic.lua`, `sim/excursion.lua`, `view/excursion.lua`
- Tests: `tests/lua/relicfoot_spec.lua`, `tests/game/relic_locks.lua` (CTest `game_relic_locks`,
  `game_relic_locks_seed7`; in the coverage runs)
