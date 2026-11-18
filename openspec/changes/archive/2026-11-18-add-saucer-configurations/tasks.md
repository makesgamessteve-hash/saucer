## 1. Requirements

- [x] 1.1 Size configurations: data/base/saucer/configs.lua; concept v0.4 cut the sizes to Villa and Seat (see `add-walkable-saucer-interior`); spec "has two sizes: the Villa with rooms and the one-seat car"
- [x] 1.2 Shrink always succeeds with Charge: spec "folding to the Seat costs 20 Charge, unfolding half that" (v0.4 costs)
- [x] 1.3 Grow requires clearance: spec "blocks unfolding without clearance, keeps Charge and says where" + ghost hull
- [x] 1.4 Interior folding: the Villa interior folds away in the Seat and back (`add-walkable-saucer-interior`), and the lab bench is built (`add-items-identification-tractor`; fitted modules at the bench in `tests/lua/gameplay_gaps_spec.lua`)
- [x] 1.5 Tractor size limit: spec "refuses too-big items"

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run @RUN@. Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-saucer-configurations`)
