-- SPDX-License-Identifier: MIT
-- Saucer size configurations (concept §3.1, v0.4). Mods may override this file.
-- Units: meters, seconds, Charge. Index 1 is the largest; higher index = smaller.
-- pilot_eye: where the pilot's eyes sit in hull-local space (+z forward). A
-- size change keeps that point fixed in the world: the saucer reconfigures
-- around the person flying it.
return {
  { id = "villa", name = "Villa", class = 4, diameter = 26.0, height = 12.0,
    speed = 40.0, accel = 1.6, turn = 1.0, hull = 1.00, shield = 1.00, tractor_class = 4, tractor_range = 45.0,
    enter_cost = 0, interior = true, pilot_eye = { 0, 1.95, 7.2 },
    rooms = { "dome", "kitchen", "living", "helm", "bedroom", "bathroom", "engine", "tractor", "holodeck" },
    -- add-tractor-beam: the belly beam. A cone straight down the hull's down
    -- axis from the emitter; run from the Tractor Room's console (console = true)
    beam = { emitter = { 0, -5.75, 0 }, half_angle = 0.35, min = 3.0, pull_speed = 7.0, shrink = 0.12,
             still = 1.5, level = 0.07, yaw_tol = 0.26, console = true, trim_speed = 3.0, trim_turn = 0.35 } },
  { id = "seat", name = "Seat", class = 1, diameter = 1.8, height = 1.4,
    speed = 12.0, accel = 5.0, turn = 2.8, hull = 0.20, shield = 0.30, tractor_class = 1, tractor_range = 10.0,
    enter_cost = 20, interior = false, pilot_eye = { 0, 0.45, -0.1 },
    rooms = { "seat" },
    -- the Seat's mini beam: short, weak (class 1), fired straight from the seat
    beam = { emitter = { 0, -0.7, 0 }, half_angle = 0.5, min = 0.1, pull_speed = 4.0, shrink = 0.35,
             still = 1.0, level = 0.07, yaw_tol = 0.35, console = false } },
  shrink_time = 1.5,       -- v0.5: rooms pack away one by one (0.75 s), then the hull shrinks
  grow_time = 1.8,         -- v0.5: the hull grows (0.9 s), then the rooms unpack
  grow_margin = 0.5,
  max_charge = 100,
  charge_regen = 2.0,      -- per second in open space
  hold_slots = 12,
}
