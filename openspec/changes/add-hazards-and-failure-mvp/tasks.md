## 1. Requirements

- [x] 1.1 The dome is safe (milestone 3): `sim/hull.lua` changes ship shields and hull only; the person under the dome is never touched
- [x] 1.2 Hot and banked items: slice.lua "fresh loot is hot until we leave the site", "loot banked after leaving"
- [x] 1.3 Fold Retreat (milestone 3): `hull.retreat`; `sentries.lua` "Fold Retreat at hull 0", "a cache with the hot items sits in the derelict", "recovered the cache"
- [x] 1.4 Non-lethal damage (milestone 3): only shields, hull and (later) Suit Charge; hull 0 is a Fold Retreat, never game over

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
