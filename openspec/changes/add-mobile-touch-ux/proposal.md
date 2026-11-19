## Why

A mobile UX review of the web build (2026-11-19, at 320x568, 360x640, 390x844 and 768x1024, portrait
and landscape) found that the touch controls were laid out for one fixed 480x270 image:

- The controls were hit-tested in window coordinates but drawn inside the letterboxed image, so on
  a phone in portrait the buttons drew in a thin band in the middle while the fingers hit elsewhere.
- Buttons were sized as a fraction of the image (about 30-40 CSS px on a phone), below the 44-48 px
  minimum target, with 4-6 px gaps.
- The notch and home-indicator safe areas were ignored, the status text, log, hints and title
  card drew under the controls, and nothing re-laid the controls out on a rotation.
- The page could still pull-to-refresh, pinch-zoom, double-tap-zoom and long-press select.
- The stick had no deadzone, a fixed base and no way to tell a button on cooldown or unavailable.

## What Changes

- MODIFIED `touch-controls`: Virtual controls on touch screens: the web build fills the window
  (`--fill`), the low-res target follows the window's shape, and the controls are laid out in
  CSS px from `min(w, h)`: a target `u = clamp(0.14·min, 48, 72)`, gaps `max(8, 0.18u)` and a margin
  `max(16, 0.25u)`, inside the safe area, re-laid out on resize and rotation.
- MODIFIED `touch-controls`: Forgiving, readable touch controls: a floating stick with a 12% radial
  deadzone whose base follows the thumb past the rim; a second finger on an owned stick or slider
  looks instead; the slop is half a gap.
- ADDED `touch-controls`: HUD clear of the touch controls (status, the "what Use does" prompt, the
  log and context hint in a clear column, the title card).
- ADDED `touch-controls`: Touch control states (pressed, active, cooldown with seconds left,
  unavailable).
- ADDED `touch-controls`: No browser gestures over the game (pull-to-refresh, zoom, swipe, select).

## Impact

- Engine: `sx_touch.c/h` (layout, fit, deadzone), `sx_sdl_main.c` (finger mapping, relayout,
  `saucer_set_safe_area`), `sx_gl.c` (fill quad), `sx_engine.c` (`--fill`), `sx_script.c`
  (layout fields, `saucer.test.touch_metrics`).
- Lua HUD (`view/hud.lua`) and the web shell (`web/shell.html`).
- No change to the simulation, command frames, saves or replays; desktop and the default
  (letterboxed) mode keep the 480x270 image.
