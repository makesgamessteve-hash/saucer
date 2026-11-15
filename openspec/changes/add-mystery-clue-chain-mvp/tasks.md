## 1. Requirements

- [x] 1.1 Mystery from the universe seed: spec "builds a three Echo chain from the seed"
- [x] 1.2 Clue placement is reachable: each Echo waits in its host ruin's vault (the archive room of the kit); game test `mystery.lua` reaches all three on seed 42, slice test on seeds 1-40
- [x] 1.3 Decoding unlocks the chain (milestone 3): lab bench decode, Resonant radar marks, the Resonant vault; `mystery.lua` "derelict 2 is Resonant", "Echo II revealed the Resonant vault", "the vault opened"
- [x] 1.4 Optional mystery: mystery mode On/Hints/Off; spec "sandbox mode hides the chain"

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
