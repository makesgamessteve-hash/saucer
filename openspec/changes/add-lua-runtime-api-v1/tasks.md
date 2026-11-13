## 1. Requirements

- [x] 1.1 Lifecycle hooks: on_init/on_tick/on_event/on_render/on_restore
- [x] 1.2 Instruction budget: fixture mod greedy is cut off; 3 strikes disables
- [x] 1.3 Render cannot mutate the sim: read-only state proxy + test-mode state-hash guard

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
