## 1. Art pass

- [x] 1.1 Grok Imagine sources logged in `art/prompts/log.jsonl` with sidecars and xAI output terms
- [x] 1.2 artpipe: material, kit floor, sky, sprite, sign, glyph and emblem recipes; four new palettes; `artpipe lint` clean
- [x] 1.3 Villa materials, derelict floors and glyphs, station walls/floor/ceiling, crowd and signs, sky backdrops, title emblem
- [x] 1.4 Before/after screenshot tour `tools/shots/m6.lua`

## 2. Audio pass

- [x] 2.1 Synthesized loops and one-shots with sidecars
- [x] 2.2 Looping voices with handles: play/set/stop in the engine and the SDL mixer
- [x] 2.3 `view/audio.lua` director: fx, events, loop levels and fades

## 3. XR and touch

- [x] 3.1 Comfort filter and `snap_left` / `snap_right` actions; sim snap of 30 degrees
- [x] 3.2 Comfort vignette, seated/standing reference spaces, web shell buttons
- [x] 3.3 Tracked hands and the wrist panel
- [x] 3.4 Touch slop, held highlights, floating stick, lift level, labels, haptics

## 4. Packaging

- [x] 4.1 Release workflow: Windows zip, Linux tarball, web zip, smoke tests, GitHub Release
- [x] 4.2 Tag v0.1.0

## 5. Verification

- [x] 5.1 `tests/lua/presentation_spec.lua`, `tests/game/xr.lua` (standing and seated sessions), C unit tests for the filter and touch
- [x] 5.2 Replays unchanged; coverage at least 95% for C and Lua
- [x] 5.3 README, ROADMAP and concept updated
