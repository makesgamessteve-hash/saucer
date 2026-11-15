# Change: One sector loop (milestone 3)

## Why
After milestone 2 the Villa is a home, but nothing you bring back is worth
anything and nothing in a derelict pushes back. Milestone 3 of
`docs/ROADMAP.md` closes the loop for one sector: loot → identify → sell,
with sentries, non-lethal failure and an optional mystery to finish.

## What Changes
- Items carry `uid`, tier, civ, category and an identified flag. Until
  identified they show as "Unknown <Civ> <Category> T<tier>" (`sim/items.lua`).
- Lab bench (`sim/lab.lua`): a job queue. Identify costs 3 Charge and takes
  30 s × tier. Decoding an Echo takes 20 s. Jobs run in the Villa only
  (they pause while folded) and keep running in flight.
- Trader (`sim/trade.lua`, `economy/economy.lua`): docking within 150 m;
  the trade terminal sells hold items at
  base × tier_mult × (1+Σaffix) × civ_rarity × demand × 0.6 (identified) or
  0.4 (unidentified, no affix premium). Demand per (category, civ) drops
  0.05 per sale (floor 0.5) and recovers 0.01 per sim minute (cap 1.5).
  It also sells Charge refills and hull repair. Every transaction saves.
- Sim clock (`sim/clock.lua`): sim minutes from ticks plus skipped time
  (sleeping skips 8 hours).
- Sentries (`sim/sentry.lua`, `sentries/sentries.lua`): Watchers (ceiling
  turrets in great halls, cone + size band, stun bolts) and Snatchers (duct
  crawlers, Seat-only 3 s siphon, nest). States Dormant → Alert (≥ 0.75 s)
  → Locked → Disabled (12 s). The tutorial derelict is unguarded.
- Tools: Scanner (2 Charge, 5 s cooldown, reveals sentries for 10 s) and
  Jammer (8 Charge, 10 s cooldown, 15 m cone plus a 3 m all-round pulse,
  Disabled for 12 s; a fresh pulse restarts a Disabled sentry's timer).
  Touch gets a JAM button (`SX_TOUCH_JAM`).
- Shields, hull and Fold Retreat (`sim/hull.lua`): bolts drain shields then
  hull; at hull 0 the saucer folds to the last trader as the Villa, hot
  items stay behind as a cache; banked cargo, Echoes, the Curio and credits
  are never lost.
- Mystery (`sim/mystery.lua`): Who → Where → Key. Each Echo unlocks once the
  previous one is decoded and becomes a hold item. Decoding Where reveals the
  Resonant vault in open space; carrying the Key there opens it: a unique
  Curio and the teaser "The signal continues beyond the fold."
- Save diffs now also hold traders' demand, the clock, nests, caches, the
  vault and each player's credits, lab queue and hold uids. Sentry state is
  rebuilt Dormant on load.
- Rendering and HUD: code-generated Watcher, Snatcher, nest and vault meshes
  (`meshes/sentry.lua`), state lights, Scanner cones, bolts, radar marks for
  Resonant sites, the vault, caches and scanned sentries; HUD hull/shield,
  credits, lab progress, sentry alarm and latch bar.
- Game tests `trade.lua`, `sentries.lua`, `mystery.lua`; spec file
  `tests/lua/loop_spec.lua`; screenshot tour `tools/shots/m3.lua`.

## Impact
- Affected specs: one-sector-loop (new); completes parts of trading,
  sentries-and-tools, hazards-and-failure, mystery and
  items-and-identification (see their tasks).
- Affected code: `data/base/scripts/sim/{items,lab,trade,clock,hull,sentry,
  mystery,game,home,save,sector,ship,tractor,autopilot}.lua`,
  `scripts/view/{render,hud,assets}.lua`, `meshes/sentry.lua`,
  `economy/economy.lua`, `sentries/sentries.lua`, `input/default.lua`,
  `engine/src/core/sx_touch.h`.
- Determinism: the sim version is now 4 and
  `tests/replays/slice_seed42.srep` was re-recorded (seed 42, 9825 ticks,
  final hash `991cafdf44162b7e`). `sentries.lua` and `mystery.lua` were
  also run with `--restore-every-tick` and matched.
- Deferred: trader stock and modules, grid consoles, on-foot Snatchers,
  Suit Charge.
