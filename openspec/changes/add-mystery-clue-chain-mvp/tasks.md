## 1. Requirements

- [x] 1.1 Mystery from the universe seed: spec "builds a three Echo chain from the seed"
- [ ] 1.2 Clue placement is reachable (partial): Echo placed inside a reachable room; covered by slice test on seeds 1-40
- [ ] 1.3 Decoding unlocks the chain (partial): collecting Echoes completes the chain; decoding UI not yet
- [x] 1.4 Optional mystery: mystery mode On/Hints/Off; spec "sandbox mode hides the chain"

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
