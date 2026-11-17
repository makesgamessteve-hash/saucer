## 1. Hull mending

- [x] 1.1 `hull.regen(ship, dt, open_space)`: the hull mends at `hull_regen` per second in open space after `shield_delay`
- [x] 1.2 Steady (`hull_regen` buff stat) doubles it through the scaled time step
- [x] 1.3 Fold Retreat message points at slow mending and the trade terminal
- [x] 1.4 Unit tests in `tests/lua/loop_spec.lua` and `tests/lua/homelife_spec.lua`
