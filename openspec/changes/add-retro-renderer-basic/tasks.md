## 1. Requirements

- [x] 1.1 Low-res target: 480x270 FBO, nearest upscale, letterboxed (sx_gl.c)
- [x] 1.2 Indexed textures with palette LUT: grayscale index PNGs + palette strip texture, index 0 transparent
- [x] 1.3 Sprites and billboards: Y-axis and camera-facing billboards
- [ ] 1.4 Retro effects are optional and XR-safe (partial): vertex snap off in XR, dither toggle via saucer.render.settings; affine warp not implemented

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
