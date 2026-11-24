## 1. Fix

- [x] 1.1 `home.doors_step`: move toward the goal and stop on it (the `else` branch pushed an open door shut every tick)
- [x] 1.2 Hysteresis (`door_close_margin`), minimum open time (`door_min_open`), `door_goal`/`door_hold` state
- [x] 1.3 `home.solids(L, p, bodies)`: never solid under an overlapping body (host, guests, visitors)
- [x] 1.4 Eased drawing of the leaf (`home.door_ease`); state version 12; replays re-recorded

## 2. Tests

- [x] 2.1 `tests/lua/home_spec.lua`: sliding doors are stable at the trigger edge (sway, hold, bounds, ease, overlap, audio, bathroom, guest)
- [x] 2.2 `tests/game/home.lua`: dither on the trigger edge with real command frames; no flapping
