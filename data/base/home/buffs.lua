-- SPDX-License-Identifier: MIT
-- Small home-comfort buffs (OpenSpec add-holodeck-home-life). A buff lasts a
-- number of sim minutes and multiplies one or more stats while it lasts;
-- several buffs multiply together. Mods may override or extend this file.
-- Stats: charge_regen (Charge per second in open space), scan_cooldown and
-- jam_cooldown (seconds until the tool is ready again), scan_reveal (how
-- long a Scanner pulse shows sentries) and hull_regen (hull repair rate).
return {
  fed    = { name = "Well fed", stats = { charge_regen = 1.5 } },
  calm   = { name = "Calm",     stats = { scan_cooldown = 0.75, jam_cooldown = 0.75 } },
  keen   = { name = "Keen",     stats = { scan_reveal = 1.5 } },
  steady = { name = "Steady",   stats = { hull_regen = 2.0 } },
}
