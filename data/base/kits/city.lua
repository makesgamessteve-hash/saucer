-- SPDX-License-Identifier: MIT
-- City kit (v0.6 true 3D): a floating alien city that sprawls vertically.
-- Plazas (great halls) at many levels, tall tower shafts between them, and
-- solid towers standing on top and hanging below (see kits/starship.lua).
return {
  id = "city",
  cell = 4.0,
  wall = 0.5,
  big = 4,
  grid = { 110, 90, 120 },  -- 440 x 360 x 480 m
  rooms = {
    [1] = { 1, 1, 4 },
    [4] = { 20, 7, 20 },     -- plaza: 80 x 28 x 80 m
  },
  wing = { 14, 7, 16 },
  shaft = { 9, 34, 9 },      -- tower shaft: 36 x 136 x 36 m
  chamber = { 3, 1, 3 },
  doors = {
    [1] = { 2.6, 2.1 },
    [4] = { 34.0, 20.0 },
  },
  halls_min = 4,
  halls_max = 5,
  shafts_min = 2,
  shafts_max = 3,
  wings_min = 2,
  wings_max = 4,
  ducts_min = 2,
  ducts_max = 3,
  jitter = 2,
  level_jitter = 1,
  min_span = 24,
  min_levels = 3,
  solids = { kind = "tower", min = 24, max = 36, w = { 3, 6 }, h = { 12, 48 } },
  debris = 4,
  color = { 0.56, 0.62, 0.70 },
  solid_color = { 0.36, 0.40, 0.50 },
  window_color = { 1.0, 0.82, 0.45 },
}
