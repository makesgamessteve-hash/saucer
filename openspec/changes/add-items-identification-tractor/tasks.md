## 1. Requirements

- [x] 1.1 Deterministic items: spec "each player gets an own, reproducible instance"
- [ ] 1.2 Identification (partial, milestone 3): lab bench, `30 s × tier`, unknown labels until identified (`trade.lua` "the bench identified the item"); installing modules is deferred
- [x] 1.3 Echoes are not sellable (milestone 3): Echoes sit in the hold, never hot; `trade.lua` "the Echo is not for sale"; `items.losable` never returns Echoes, so Fold Retreat and Snatchers cannot take them; installing waits for modules

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
