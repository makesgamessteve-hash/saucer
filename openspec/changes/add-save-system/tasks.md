## 1. Requirements

- [x] 1.1 Seed plus diffs: save format 3 (`sim/save.lua`, `sim/diff.lua`): the seed, mod set, world and per-player diffs against what the seed regenerates; format 2 (state version 10) saves migrate on load; twins, lockdowns and Hardcore are saved now
- [x] 1.2 Atomic write: sx_fs_write_atomic; spec "saves and loads slots"
- [x] 1.3 Player records: one record per participant keyed by `record_index`, each diffed against a starter record; a single-player save loaded with two players keeps record 0 and starts record 1 (`tests/lua/save_spec.lua`, `game_saves_write`/`game_saves_load`)

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
