## 1. Requirements

- [x] 1.1 Replays with state hashes: .srep with hashes every 60 ticks; divergence test in `engine_runners`
- [ ] 1.2 Cross-platform determinism (partial): same final hash native (gcc) vs wasm (node); MSVC still to be checked in CI
- [x] 1.3 Coverage gates: tools/coverage.sh: gcovr --fail-under-line 95 on engine/src/core, luacov total >= 95

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
