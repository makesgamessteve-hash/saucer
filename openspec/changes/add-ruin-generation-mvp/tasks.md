## 1. Requirements

- [x] 1.1 Kit-based modular ruins: starship + station kits (data/base/kits)
- [x] 1.2 Size-gated mission graph: spec "size locks never increase along the mission chain"
- [x] 1.3 Reachability validation: saucer.procgen.reachable; spec "every room is reachable at its size"
- [ ] 1.4 Generation budget (partial): up to 8 retries then fixed fallback layout; time budget not measured

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
