-- SPDX-License-Identifier: MIT
-- Saucer size configurations (concept §3.1). Mods may override this file or
-- extend the "saucer_config" registry kind. Units: meters, seconds, Charge.
return {
  { id = "villa",   name = "Villa",   class = 4, diameter = 24.0, height = 8.0,
    speed = 34.0, accel = 1.6, turn = 1.1, hull = 1.00, shield = 1.00, tractor_class = 4, tractor_range = 45.0,
    enter_cost = 0, rooms = { "dome", "lab", "workshop", "hold", "quarters", "garden" } },
  { id = "cruiser", name = "Cruiser", class = 3, diameter = 10.0, height = 4.0,
    speed = 26.0, accel = 2.4, turn = 1.6, hull = 0.70, shield = 0.70, tractor_class = 3, tractor_range = 24.0,
    enter_cost = 5, rooms = { "cockpit", "lab", "hold" } },
  { id = "pod",     name = "Pod",     class = 2, diameter = 4.0, height = 2.0,
    speed = 18.0, accel = 3.5, turn = 2.2, hull = 0.40, shield = 0.50, tractor_class = 2, tractor_range = 14.0,
    enter_cost = 10, rooms = { "cockpit", "hold" } },
  { id = "seat",    name = "Seat",    class = 1, diameter = 1.8, height = 1.4,
    speed = 10.0, accel = 5.0, turn = 2.8, hull = 0.20, shield = 0.30, tractor_class = 1, tractor_range = 30.0,
    enter_cost = 15, rooms = { "seat", "hold" } },
  shrink_time = 0.6,
  grow_time = 1.0,
  grow_margin = 0.5,
  max_charge = 100,
  charge_regen = 2.0,      -- per second in open space
  hold_slots = 12,
}
