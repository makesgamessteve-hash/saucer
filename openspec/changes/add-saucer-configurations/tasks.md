## 1. Requirements

- [x] 1.1 Size configurations: data/base/saucer/configs.lua; concept v0.4 cut the sizes to Villa and Seat (see `add-walkable-saucer-interior`); spec "has two sizes: the Villa with rooms and the one-seat car"
- [x] 1.2 Shrink always succeeds with Charge: spec "folding to the Seat costs 20 Charge, unfolding half that" (v0.4 costs)
- [x] 1.3 Grow requires clearance: spec "blocks unfolding without clearance, keeps Charge and says where" + ghost hull
- [ ] 1.4 Interior folding: the Villa interior folds away in the Seat and back (`add-walkable-saucer-interior`); lab bench not built yet
- [x] 1.5 Tractor size limit: spec "refuses too-big items"

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
