## 1. Requirements

- [x] 1.1 Fixed simulation tick: sx_ticks_for_frame + C test `ticks_for_frame`; render alpha passed to on_render
- [x] 1.2 Headless mode: `saucer_headless` / `saucer --headless`; ctest game_* and `engine_runners`
- [ ] 1.3 Supported platforms (partial): Linux gcc/clang and emscripten verified locally; Windows MSVC job defined in CI but not yet run

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
