## 1. Requirements

- [ ] 1.1 Assets beside the binary (partial): data/ copied beside the binary, error texture on missing paths; web fetches every file listed in data/index.json at startup (no bundle) rather than lazily on demand
- [x] 1.2 Load order and override: C test `modset_scan_and_resolve`, game test tests/game/mods.lua (override of saucer/configs.lua, cycle report)
- [x] 1.3 Script sandbox: per-mod env, no io/os; spec "forbids clocks, io and unseeded randomness"
- [x] 1.4 API versioning: fixture mod bad_api is reported and skipped
- [x] 1.5 Mods declare asset licenses: `license_code` / `license_assets` parsed from mod.lua

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
