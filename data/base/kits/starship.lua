-- SPDX-License-Identifier: MIT
-- Starship kit: room footprints per size class on the 4 m grid, door openings
-- per class (width, height in meters). Doors sit on the room floor.
return {
  id = "starship",
  cell = 4.0,
  wall = 0.5,
  rooms = {               -- [class] = { w, h, d } in cells
    [1] = { 1, 1, 2 },
    [2] = { 2, 1, 3 },
    [3] = { 4, 2, 4 },
    [4] = { 8, 3, 8 },
  },
  doors = {
    [1] = { 2.6, 2.1 },
    [2] = { 5.6, 2.9 },
    [3] = { 12.5, 5.8 },
    [4] = { 27.0, 10.0 },
  },
  rooms_min = 4,
  rooms_max = 7,
  branches = 2,
  debris = 3,
  color = { 0.62, 0.66, 0.74 },
}
