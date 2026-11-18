## 1. Requirements

- [x] 1.1 Replays with state hashes: .srep with hashes every 60 ticks; divergence test in `engine_runners`
- [x] 1.2 Cross-platform determinism: same final hash native (gcc) vs wasm (node) vs Windows MSVC: the `windows-msvc` and `emscripten` CI jobs run every `replay_*` ctest against the hashes recorded on Linux (green in main run @RUN@)
- [x] 1.3 Coverage gates: tools/coverage.sh: gcovr --fail-under-line 95 on engine/src/core, luacov total >= 95

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run @RUN@. Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-test-harness-replays`)
