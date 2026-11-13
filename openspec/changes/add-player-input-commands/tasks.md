## 1. Requirements

- [x] 1.1 Devices claimed by players: C test `input_actions_claims_pads` (auto-claim, join offers, co-op join)
- [x] 1.2 Command frames are the only sim input: replays drive the sim from frames only; tests/replays/slice_seed42.srep
- [x] 1.3 Per-player rebinding: bindings_pN.txt per player; Lua spec "rebinds and persists"
- [x] 1.4 Virtual controls on touch screens: sx_touch.c; tests/game/boot.lua touch stick + shrink button
- [x] 1.5 Auto-hover: C test `touch_widgets` (slider release returns 0)

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
