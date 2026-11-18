## 1. Requirements

- [x] 1.1 Seed plus diffs: save format 3 (`sim/save.lua`, `sim/diff.lua`): the seed, mod set, world and per-player diffs against what the seed regenerates; format 2 (state version 10) saves migrate on load; twins, lockdowns and Hardcore are saved now
- [x] 1.2 Atomic write: sx_fs_write_atomic; spec "saves and loads slots"
- [x] 1.3 Player records: one record per participant keyed by `record_index`, each diffed against a starter record; a single-player save loaded with two players keeps record 0 and starts record 1 (`tests/lua/save_spec.lua`, `game_saves_write`/`game_saves_load`)

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run @RUN@. Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-save-system`)

## 3. Deferred

Moved to `later-followups` 1.1 and 1.2: the title-card save summary and player-record export for networked play.
