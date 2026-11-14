-- SPDX-License-Identifier: MIT
-- Starship kit (concept §5.4, v0.4): derelicts are huge, so their halls take a
-- whole Villa; only ducts and the caches behind them need the Seat.
-- Room footprints are in 4 m cells { w, h, d } per size class; doors are
-- { width, height } in meters and sit on the room floor.
return {
  id = "starship",
  cell = 4.0,
  wall = 0.5,
  big = 4,                 -- class of the great halls (the Villa's class)
  rooms = {
    [1] = { 1, 1, 3 },     -- duct: one Seat wide
    [4] = { 14, 6, 16 },   -- great hall: 56 x 24 x 64 m
  },
  chamber = { 3, 1, 3 },   -- class-1 cache room at the end of some ducts
  doors = {
    [1] = { 2.6, 2.1 },
    [4] = { 34.0, 16.0 },
  },
  halls_min = 3,
  halls_max = 4,
  ducts_min = 1,
  ducts_max = 2,
  debris = 3,
  color = { 0.62, 0.66, 0.74 },
}
