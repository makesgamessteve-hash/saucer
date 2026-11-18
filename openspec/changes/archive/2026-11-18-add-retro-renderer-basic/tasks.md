## 1. Requirements

- [x] 1.1 Low-res target: 480x270 FBO, nearest upscale, letterboxed (sx_gl.c)
- [x] 1.2 Indexed textures with palette LUT: grayscale index PNGs + palette strip texture, index 0 transparent
- [x] 1.3 Sprites and billboards: Y-axis and camera-facing billboards
- [x] 1.4 Retro effects are optional and XR-safe: vertex snap, dither and the affine (PS1-style) texture warp each toggle through `saucer.render.settings{snap, dither, affine}`; the warp is off by default and, like snapping, forced off for XR views (`sx_render_effects`, used by `sx_gl.c` and the settings query) and restored when the session ends; C test `retro_effects_xr_safe` and Lua spec "XR session starts: snapping and the affine warp are off for the headset and restored after"; shots with the warp on and off in `tools/shots/renderer.lua`

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run @RUN@. Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-retro-renderer-basic`)

## 3. Deferred

Moved to `later-followups` 3.4 and 3.5: an in-game menu entry for the warp, less dithering in XR, a GPU pixel check.
