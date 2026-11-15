## 1. Concept

- [x] 1.1 concept.md v0.5 notes (wake-up, doors, Use, helm console, packing fold, 1.5 s / 1.8 s), §3.1 timings, §16 changes and the spec text

## 2. Requirements

- [x] 2.1 Wake-up start and title panel: `sim/home.lua`, `sim/panel.lua`, HUD panel; specs "wakes every player up in the bedroom…", "navigates the title card…"; game tests `home.lua`, `boot.lua` (touch Use gets up)
- [x] 2.2 Sliding doors: `interior.lua` doors, `home.doors_step/solids`, door meshes; spec "slides doors open near them…"; `home.lua` walks through the bedroom door
- [x] 2.3 Furniture Use: stations in `interior.lua`, `home.USE`; spec "lets you use the kitchen, shower, engine, lab and trade terminal", "sleeps (refill and save) only outside derelicts"; `home.lua`
- [x] 2.4 Helm console: `helm_desk`, `helm_wing` meshes, `render.console` (radar, bars, hold pips, size ladder); screenshot `docs/shots/helm_console.png`
- [x] 2.5 Packing fold: `sim/fold.lua`, `render.rooms`, `render.pose` hull phase; specs "folds the saucer around the pilot during size changes", "keeps rooms out or packed…"; game test `fold.lua`; screenshots `fold_packing*.png`
- [x] 2.6 Timing 1.5 s / 1.8 s in `saucer/configs.lua`
- [x] 2.7 Save/load: `sim/save.lua`, `mystery.progress/restore`; spec "loads only for player 1…"; `home.lua` sleep → load (also `--restore-every-tick`)
- [x] 2.8 `--windowed` engine option and `tools/shots/m2.lua` screenshot tour

## 3. Verification

- [x] 3.1 Lua specs, C unit tests and game tests pass; coverage ≥ 95 % (C and Lua)
- [x] 3.2 `tests/replays/slice_seed42.srep` re-recorded (sim version 3)
- [ ] 3.3 CI green on linux-gcc, linux-clang, windows-msvc, emscripten and lint; Pages deployed
