-- SPDX-License-Identifier: MIT
-- The station's hangar bay and its tractor beam (OpenSpec add-dock-land-eva).
-- World metres relative to the trader's `pos`, the dock anchor: the hangar cell is fixed, the tip of a
-- station arm (data/base/station/hull.lua, OpenSpec add-huge-stations) whose megastructure reaches away
-- toward -x. Mods may override.
return {
  -- the cell: x from the back wall (toward the station) to the open front (the force field), z side to side
  back_x = 38, front_x = 100, half_w = 34, floor_y = 10, height = 24, wall = 1.5,
  pad = { 70, 0 },          -- pad centre (x, z)
  yaw = 1.5707963,          -- the saucer rests nose-out: the hull door faces the back wall
  door = { half = 1.6, height = 3.4 },   -- the station door in the back wall (centred on z = 0)
  -- capture: inside this radius of the mouth, slow enough, in front of the bay
  mouth_x = 112,            -- the point the beam tows the saucer to first
  capture_r = 160,         -- add-huge-stations: the beam reaches far enough to catch you as the station fills the view
  capture_speed = 35,
  guide_speed = 11,         -- m/s along the tow
  guide_min = 8, guide_max = 22,
  approach_x = 10,          -- m above the pad where the tow hands over to the settle
  cancel_dot = 0.5,         -- pulling away: thrust this much along "out of the bay"
  cancel_hold = 0.8,        -- ...for this long
  recapture = 40,           -- after a cancel the saucer must leave the capture radius by this much first
  clamp_time = 0.9,
  release_speed = 6,        -- m/s: the beam carries the saucer out to the mouth at lift-off
  release_reach = 30,       -- ...and lets go this far past the front
}
