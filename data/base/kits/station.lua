-- SPDX-License-Identifier: MIT
return {
  id = "station",
  cell = 4.0,
  wall = 0.5,
  rooms = {
    [1] = { 1, 1, 1 },
    [2] = { 3, 1, 3 },
    [3] = { 5, 2, 5 },
    [4] = { 8, 3, 8 },
  },
  doors = {
    [1] = { 2.6, 2.1 },
    [2] = { 5.6, 2.9 },
    [3] = { 12.5, 5.8 },
    [4] = { 27.0, 10.0 },
  },
  rooms_min = 5,
  rooms_max = 8,
  branches = 3,
  debris = 5,
  color = { 0.70, 0.62, 0.52 },
}
