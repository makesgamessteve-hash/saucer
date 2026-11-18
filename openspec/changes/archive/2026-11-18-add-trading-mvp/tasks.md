## 1. Requirements

- [x] 1.1 Price formula and demand (milestone 3): `sim/trade.lua`, `economy/economy.lua`; game test `trade.lua` "identified offer matches the formula", "unidentified offer", "demand dropped by 0.05", "demand recovered while sleeping"; spec "prices, saturates and recovers demand"
- [x] 1.2 Buy and sell at a trader: docking, the trade terminal, selling, Charge refills and hull repair, each saved at once (`trade.lua` "the sale saved the game"); trader stock: each trader shelves three saucer modules (`trade.stock` / `buy_stock`, identified and quirk-free, restocked every four clock hours, a sold slot saved in `state.traders[i].sold`). Tests: `tests/lua/gameplay_gaps_spec.lua` "a trader's shelf of modules"

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run 44391736871 (merge 88e7b05). Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-trading-mvp`)
