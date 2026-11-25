## 1. Collision
- [x] 1.1 Spin shapes from xring, blob, limb and the Gyre's rings, in the layout pass (spore and splinter loops too)
- [x] 1.2 `spin_push`: into the layer's frame by the tick's angle, out of every overlapped shape, back to the world
- [x] 1.3 The flight mover applies it and counts it as blocked

## 2. Tests
- [x] 2.1 tests/lua/stationhull_spec.lua: shapes for every family (layout = mesh pass), nearest points, the push at a
      turned tick, nothing far away, a saucer stopped by the layer
