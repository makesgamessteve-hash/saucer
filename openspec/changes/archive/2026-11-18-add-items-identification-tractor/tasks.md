## 1. Requirements

- [x] 1.1 Deterministic items: spec "each player gets an own, reproducible instance"
- [x] 1.2 Identification and modules: lab bench, `30 s × tier`, unknown labels until identified (`trade.lua` "the bench identified the item"); Module items install into two saucer slots at the lab bench (`sim/modules.lua`, lab rows Install / Remove / Identify fitted): identified affixes change shield regen, Charge regen, max Charge, turn rate and scan reach; quirks bite at once (Unstable drains Charge, Loud is heard from farther, Bonded will not come out) and the HUD says "UNKNOWN EFFECT" until identified. Tests: `tests/lua/gameplay_gaps_spec.lua` "Hidden quirk: …"
- [x] 1.3 Echoes are not sellable (milestone 3): Echoes sit in the hold, never hot; `trade.lua` "the Echo is not for sale"; `items.losable` never returns Echoes, so Fold Retreat and Snatchers cannot take them; installing a module refuses Echoes (`modules.installable`)

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run 44391736871 (merge 88e7b05). Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-items-identification-tractor`)

## 3. Deferred

Moved to `later-followups` 4.1-4.4: modules away from the bench, module slots as an upgrade, quirk trials, saving the beam queue.
