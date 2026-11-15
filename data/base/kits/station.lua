-- SPDX-License-Identifier: MIT
-- Station kit: stacked decks, tall shafts, more ducts and long trusses
-- reaching out in every direction (see kits/starship.lua for units).
return {
  id = "station",
  cell = 4.0,
  wall = 0.5,
  big = 4,
  grid = { 80, 72, 110 },
  rooms = {
    [1] = { 1, 1, 4 },
    [4] = { 14, 8, 16 },
  },
  wing = { 12, 8, 12 },
  shaft = { 10, 30, 10 },
  chamber = { 3, 1, 2 },
  doors = {
    [1] = { 2.6, 2.1 },
    [4] = { 34.0, 20.0 },
  },
  halls_min = 3,
  halls_max = 5,
  shafts_min = 1,
  shafts_max = 2,
  wings_min = 2,
  wings_max = 3,
  ducts_min = 1,
  ducts_max = 3,
  jitter = 1,
  level_jitter = 2,
  min_span = 18,
  min_levels = 2,
  solids = { kind = "truss", min = 4, max = 8, w = { 1, 3 }, h = { 6, 20 } },
  debris = 5,
  color = { 0.70, 0.62, 0.52 },
  solid_color = { 0.55, 0.5, 0.44 },
}
