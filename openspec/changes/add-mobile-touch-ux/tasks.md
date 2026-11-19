## 1. Layout

- [x] 1.1 `sx_touch_layout(t, metrics)`: sizes from `min(w, h)` in CSS px, gaps, margin, safe area, portrait and landscape arrangements (`touch_layout_resolutions` in `tests/c/test_core.c`)
- [x] 1.2 `sx_touch_fit_target`: the low-res target follows the window's shape (`touch_fit_and_slop`)
- [x] 1.3 Keep-outs for the status block, the top band and the crosshair; a clear message column (`touch_layout_resolutions`)
- [x] 1.4 Re-layout on resize, rotation and safe-area changes in `sx_sdl_main.c`; fingers mapped onto the image

## 2. Input

- [x] 2.1 Floating stick with a radial deadzone and a following base (`touch_stick_deadzone_and_follow`)
- [x] 2.2 One finger owns a stick or slider; a second finger looks; slop is half a gap (`touch_widgets`, `touch_polish`)

## 3. HUD

- [x] 3.1 Status, prompts, log, context hint and title card clear of the controls at the eight reference sizes (`tests/lua/touch_ux_spec.lua`: "keeps the walk/helm HUD off the controls", "stacks over the log in the clear column", "keeps the title card clear")
- [x] 3.2 Pressed, active, cooldown and unavailable states (`touch_ux_spec.lua`: "shows cooldowns, an unavailable decoy, an active beam and the altitude", "lights a pressed button and nudges its label")
- [x] 3.3 Title menu entries wrap and the nav line breaks instead of being cut off, at all eight sizes (`touch_ux_spec.lua`: "shows every title menu entry and the nav in full", "wraps a long menu row and splits a narrow centred line")

## 4. Web shell

- [x] 4.1 `--fill`, `viewport-fit=cover`, safe-area probe, `touch-action: none`, `overscroll-behavior: none`, gesture/dblclick/contextmenu/selectstart suppressed (`test_engine.c` parses `--fill`; checked in headless Chromium screenshots)
