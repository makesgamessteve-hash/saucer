-- SPDX-License-Identifier: MIT
-- Station kit: squatter halls, more ducts (see kits/starship.lua for units).
return {
  id = "station",
  cell = 4.0,
  wall = 0.5,
  big = 4,
  rooms = {
    [1] = { 1, 1, 3 },
    [4] = { 12, 6, 14 },
  },
  chamber = { 3, 1, 2 },
  doors = {
    [1] = { 2.6, 2.1 },
    [4] = { 34.0, 16.0 },
  },
  halls_min = 3,
  halls_max = 5,
  ducts_min = 1,
  ducts_max = 3,
  debris = 5,
  color = { 0.70, 0.62, 0.52 },
}
