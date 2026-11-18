## 1. Requirements

- [x] 1.1 Low-res target: 480x270 FBO, nearest upscale, letterboxed (sx_gl.c)
- [x] 1.2 Indexed textures with palette LUT: grayscale index PNGs + palette strip texture, index 0 transparent
- [x] 1.3 Sprites and billboards: Y-axis and camera-facing billboards
- [x] 1.4 Retro effects are optional and XR-safe: vertex snap, dither and the affine (PS1-style) texture warp each toggle through `saucer.render.settings{snap, dither, affine}`; the warp is off by default and, like snapping, forced off for XR views (`sx_render_effects`, used by `sx_gl.c` and the settings query) and restored when the session ends; C test `retro_effects_xr_safe` and Lua spec "XR session starts: snapping and the affine warp are off for the headset and restored after"; shots with the warp on and off in `tools/shots/renderer.lua`

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
