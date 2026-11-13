## 1. Requirements

- [ ] 1.1 Bit-identical generation across platforms (partial): C known-answer vectors `tests/data/rng_kat.txt` (PCG32 stream) pass natively and under wasm; Lua-level `saucer.rng.new(42)` vector still to add
- [x] 1.2 Hierarchical seeds: sx_seed_child; Lua spec "child streams are independent of draw order"
- [x] 1.3 Deterministic math in the sim: `tests/data/math_kat.txt` (4,096 inputs, sin/cos/atan2/sqrt); spec "forbids clocks, io and unseeded randomness"
- [ ] 1.4 Stable Lua iteration and hashing (partial): fixed Lua hash seed + sorted_pairs; replay final hash identical native vs wasm; luacheck rule not yet in CI

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
