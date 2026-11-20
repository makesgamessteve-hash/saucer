-- SPDX-License-Identifier: MIT
-- Landing gear and the hull hatch (OpenSpec add-dock-land-eva). Hull-local
-- metres, seconds. Mods may override this file.
return {
  -- three landing legs under the Villa (azimuth from the bow toward starboard)
  azimuth = { 0.5, 2.5944, 4.6888 },
  foot_r = 6.0,            -- the pads sit this far from the hull's axis
  leg_len = 7.2,           -- hull centre above the ground when the gear is down
  telescope = 1.4,         -- a leg reaches this much lower to meet uneven ground
  max_spread = 1.4,        -- tallest step between the feet and the centre that still lands
  max_slope_deg = 8.0,     -- same rule as an angle (legs span about 10.4 m)
  span = 10.39,
  min_up = 0.7,            -- a landing patch must face up (box top)
  range = 120,             -- the gear probes this far below the hull
  settle_speed = { 0.5, 3.0 },   -- descent speed range (m/s)
  gear_time = 2.0,         -- seconds the legs take to swing out or fold away
  lift_height = 3.0,       -- metres the saucer rises on its own at take-off
  lift_speed = 2.0,
  speed_max = 8.0,         -- m/s: faster than this and landing is refused
  clearance_margin = 0.0,
  support_every = 30,      -- ticks between checks that there is still ground under a landed hull
  -- the hull door (hull-local, aft)
  door = {
    deck = 2, sill = -9.0, width = 2.2, height = 2.4,
    flat = 1.6,            -- metres of level passage through the hull before the first tread
    rise = 0.28, tread = 0.40,
    drop_min = 1.5, drop_max = 6.5,
    open_time = 1.4, stairs_time = 2.0, min_open = 1.5,
    reach_out = 4.5,       -- a body this close to the stairs' foot opens the hatch
    close_margin = 2.5,    -- ...and keeps it open until it is this much farther
    enter = 0.9,           -- boarding: within this of the stairs' foot
    cycle_time = 1.6,      -- the airlock cycle when the suit goes on
    trigger = -8.40,       -- walking aft of this z with the hatch open takes you onto the stairs
  },
}
