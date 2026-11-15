-- SPDX-License-Identifier: MIT
-- Saucer size configurations (concept §3.1, v0.4). Mods may override this file.
-- Units: meters, seconds, Charge. Index 1 is the largest; higher index = smaller.
-- pilot_eye: where the pilot's eyes sit in hull-local space (+z forward). A
-- size change keeps that point fixed in the world: the saucer reconfigures
-- around the person flying it.
return {
  { id = "villa", name = "Villa", class = 4, diameter = 26.0, height = 12.0,
    speed = 30.0, accel = 1.6, turn = 1.0, hull = 1.00, shield = 1.00, tractor_class = 4, tractor_range = 45.0,
    enter_cost = 0, interior = true, pilot_eye = { 0, 1.95, 7.2 },
    rooms = { "dome", "kitchen", "living", "helm", "bedroom", "bathroom", "engine" } },
  { id = "seat", name = "Seat", class = 1, diameter = 1.8, height = 1.4,
    speed = 10.0, accel = 5.0, turn = 2.8, hull = 0.20, shield = 0.30, tractor_class = 1, tractor_range = 10.0,
    enter_cost = 20, interior = false, pilot_eye = { 0, 0.45, -0.1 },
    rooms = { "seat" } },
  shrink_time = 1.5,       -- v0.5: rooms pack away one by one (0.75 s), then the hull shrinks
  grow_time = 1.8,         -- v0.5: the hull grows (0.9 s), then the rooms unpack
  grow_margin = 0.5,
  max_charge = 100,
  charge_regen = 2.0,      -- per second in open space
  hold_slots = 12,
}
