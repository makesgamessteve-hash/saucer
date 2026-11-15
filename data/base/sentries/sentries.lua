-- SPDX-License-Identifier: MIT
-- Sentry types (concept §8.2-8.3). Robots only, nothing lethal: Watchers
-- drain shields then hull; Snatchers steal one hot item from a Seat.
-- Mods may override this file.
return {
  alert_time = 0.75,      -- at least this long in Alert before Locked
  lose_time = 1.0,        -- out of sight this long: back to Dormant
  disabled_time = 12.0,   -- Jammer reboot
  watcher = {
    range = 100, half_angle = 0.62, sweep = 0.9, sweep_period = 9.0,
    -- size band by the civ's body scale: it ignores anything smaller (the Seat is class 1)
    band = { human = { 2, 4 }, tiny = { 2, 4 } },
    fire_every = 1.6, bolt_speed = 18, bolt_life = 5.0, bolt_damage = 9, bolt_radius = 0.4,
  },
  snatcher = {
    sense = 22, chase_speed = 7.5, patrol_speed = 2.0, flee_speed = 9.0, latch_time = 3.0, latch_dist = 1.6,
    give_up = 34,
  },
  scanner = { charge = 2, cooldown = 5.0, reveal = 10.0 },
  jammer = { charge = 8, cooldown = 10.0, range = 15.0, half_angle = 0.6, near = 3.0 }, -- near: all-round pulse radius
  shield_regen = 4.0,     -- per second, after shield_delay without hits
  shield_delay = 4.0,
}
