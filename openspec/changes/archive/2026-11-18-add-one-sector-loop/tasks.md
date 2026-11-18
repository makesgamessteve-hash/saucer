## 1. Concept

- [x] 1.1 concept.md v0.6 notes (lab queue, trader formula, sentries and leash, Jammer pulse, Fold Retreat, the vault) and §16 changes

## 2. Requirements

- [x] 2.1 Lab bench queue: `sim/lab.lua`, `sim/items.lua`; game test `trade.lua` "the bench identified the item", "decoded Echo I"; spec `loop_spec.lua` "queues, pauses in the Seat…"
- [x] 2.2 Trade terminal: `sim/trade.lua`; `trade.lua` "the Echo is not for sale", "the sale saved the game"; spec "lists offers only when docked…"
- [x] 2.3 Sentry placement and leash: `sentry.layout`; `trade.lua` "the tutorial derelict is unguarded"; `sentries.lua` "still in the site with hot cargo"
- [x] 2.4 Jammer pulse: `sentry.jam`; `sentries.lua` "Snatcher jammed in its nest", "Snatcher jammed again"
- [x] 2.5 Resonant vault: `mystery.open_vault/curio`, `game.world_step`; `mystery.lua` "the vault opened", "the unique Curio is in the hold", "the teaser"
- [x] 2.6 Milestone 3 save diffs: `sim/save.lua`; `trade.lua` "credits restored", "trader demand restored"; `mystery.lua` "chain, vault and Curio restored"

## 3. Verification

- [x] 3.1 Lua specs, C unit tests and game tests pass; coverage ≥ 95 % (C and Lua)
- [x] 3.2 `tests/replays/slice_seed42.srep` re-recorded (sim version 4)
- [x] 3.3 CI green on linux-gcc, linux-clang, windows-msvc, emscripten and lint (main run @RUN@); Pages deployed (https://makesgamessteve-hash.github.io/saucer/)
