-- SPDX-License-Identifier: MIT
-- The station's hangar bay and its tractor beam (OpenSpec add-dock-land-eva).
-- World metres relative to the trader station's centre, which spins; the bay
-- is a fixed cell on a gantry above the ring and does not. Mods may override.
return {
  -- the cell: x from the back wall (toward the station) to the open front (the force field), z side to side
  back_x = 38, front_x = 88, half_w = 20, floor_y = 10, height = 22, wall = 1.5,
  pad = { 67, 0 },          -- pad centre (x, z)
  yaw = 1.5707963,          -- the saucer rests nose-out: the hull door faces the back wall
  door = { half = 1.6, height = 3.4 },   -- the station door in the back wall (centred on z = 0)
  -- capture: inside this radius of the mouth, slow enough, in front of the bay
  mouth_x = 100,            -- the point the beam tows the saucer to first
  capture_r = 75,
  capture_speed = 35,
  guide_speed = 7,          -- m/s along the tow
  guide_min = 7, guide_max = 16,
  approach_x = 10,          -- m above the pad where the tow hands over to the settle
  cancel_dot = 0.5,         -- pulling away: thrust this much along "out of the bay"
  cancel_hold = 0.8,        -- ...for this long
  recapture = 40,           -- after a cancel the saucer must leave the capture radius by this much first
  clamp_time = 0.9,
  release_speed = 6,        -- m/s: the beam carries the saucer out to the mouth at lift-off
  release_reach = 30,       -- ...and lets go this far past the front
}
