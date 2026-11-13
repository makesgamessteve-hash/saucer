## 1. Requirements

- [x] 1.1 Size configurations: data/base/saucer/configs.lua; spec "has four sizes from Villa to Seat"
- [x] 1.2 Shrink always succeeds with Charge: spec "Villa to Seat costs 5+10+15 Charge"
- [x] 1.3 Grow requires clearance: spec "blocks growing without clearance and keeps Charge" + ghost hull
- [ ] 1.4 Interior folding: dome interior not in milestone 1
- [x] 1.5 Tractor size limit: spec "refuses too-big items"

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
