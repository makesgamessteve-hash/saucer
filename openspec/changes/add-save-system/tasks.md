## 1. Requirements

- [ ] 1.1 Seed plus diffs: saucer.save slots exist; seed+diff save format not yet
- [x] 1.2 Atomic write: sx_fs_write_atomic; spec "saves and loads slots"
- [ ] 1.3 Player records: not yet

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
