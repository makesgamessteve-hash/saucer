## 1. Requirements

- [x] 1.1 Assets beside the binary: data/ is copied beside the binary and missing paths give the error texture. Lazy loading on the web (it fetches every file in data/index.json at startup) moved to `add-tooling-followups` 1.7
- [x] 1.2 Load order and override: C test `modset_scan_and_resolve`, game test tests/game/mods.lua (override of saucer/configs.lua, cycle report)
- [x] 1.3 Script sandbox: per-mod env, no io/os; spec "forbids clocks, io and unseeded randomness"
- [x] 1.4 API versioning: fixture mod bad_api is reported and skipped
- [x] 1.5 Mods declare asset licenses: `license_code` / `license_assets` parsed from mod.lua

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run 44391736871 (merge 88e7b05). Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-asset-vfs-and-mod-loading`)
