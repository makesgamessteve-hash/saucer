## Why

After the mobile touch rework the phone layout showed eleven buttons, a stick and a slider at once
(MAP, -SZ, +SZ, BST, DEC, JAM, SCN, GRP, BM, USE, UP/LFT/DN). Most of them do nothing most of the
time: the beam needs something lined up, the grapple needs a derelict on foot, the jammer and decoy
need a sentry, and a size change needs room. The clutter covered the scene in portrait and made the
two buttons used all the time (USE, boost) harder to find.

## What Changes

- ADDED `touch-controls`: a MORE button (where MAP was) opens a tray of every action (map, scan,
  decoy, jam, shrink, grow, grapple, beam, boost, use); a pick or a tap outside closes it.
- ADDED `touch-controls`: context buttons in fixed slots that show only when they would act:
  beam (lock / at the beam console / pulling), grapple (on foot in a derelict), jam and decoy
  (a sentry alarm or a clamp; decoy also needs stock outside home), shrink and grow (the size change
  would go through here, worked out by the same check as the real request).
- ADDED `touch-controls`: nothing appears, disappears or moves under a pressing finger; the change
  waits until the slot is free. A new button fades in over 9 frames (~150 ms) with a short pulse.
- Always visible: the stick, the lift slider, USE (most-used action) and boost (core movement).
- Lua: `saucer.input.touch_context(t)`, `saucer.input.touch_tray(open)`, and per-widget `group`,
  `shown`, `wanted`, `age` in `touch_layout()`; `ship.check` and `game.can_resize` as pure checks.

## Impact

- Affected specs: `touch-controls`
- Affected code: `engine/src/core/sx_touch.{c,h}`, `engine/src/core/sx_script.c`,
  `data/base/scripts/view/hud.lua`, `data/base/scripts/sim/{game,ship}.lua`, tests.
