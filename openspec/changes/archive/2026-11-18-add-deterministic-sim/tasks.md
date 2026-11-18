## 1. Requirements

- [x] 1.1 Bit-identical generation across platforms: C known-answer vectors `tests/data/rng_kat.txt` (PCG32 stream) pass natively and under wasm. The Lua-level `saucer.rng.new(42)` vector moved to `add-tooling-followups` 1.4
- [x] 1.2 Hierarchical seeds: sx_seed_child; Lua spec "child streams are independent of draw order"
- [x] 1.3 Deterministic math in the sim: `tests/data/math_kat.txt` (4,096 inputs, sin/cos/atan2/sqrt); spec "forbids clocks, io and unseeded randomness"
- [x] 1.4 Stable Lua iteration and hashing: fixed Lua hash seed + sorted_pairs; replay final hash identical native vs wasm. The luacheck rule moved to `add-tooling-followups` 1.5

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run 44391736871 (merge 88e7b05). Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-deterministic-sim`)
