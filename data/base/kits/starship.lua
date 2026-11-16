-- SPDX-License-Identifier: MIT
-- Starship kit (concept §5.4, v0.6 true 3D): derelicts are huge in every
-- direction. Great halls and vertical shafts take the whole Villa; wings
-- branch off sideways, above and below; only ducts and the caches behind
-- them need the Seat. Room footprints are in 4 m cells { w, h, d } per size
-- class; doors are { width, height } in meters (side doors sit on the higher
-- floor, floor/ceiling hatches are width x width squares).
return {
  id = "starship",
  cell = 4.0,
  wall = 0.5,
  big = 4,                 -- class of the great halls (the Villa's class)
  grid = { 72, 60, 120 },  -- 288 x 240 x 480 m of space to build in
  rooms = {
    [1] = { 1, 1, 4 },     -- duct: one Seat wide, 16 m long (vertical when it leaves through a floor)
    [4] = { 16, 8, 20 },   -- great hall: 64 x 32 x 80 m
  },
  wing = { 14, 7, 14 },    -- side hall: 56 x 28 x 56 m
  shaft = { 10, 26, 10 },  -- vertical shaft: 40 x 104 x 40 m
  chamber = { 3, 1, 3 },   -- class-1 cache room at the end of some ducts
  doors = {
    [1] = { 2.6, 2.1 },
    [4] = { 34.0, 20.0 },
  },
  halls_min = 3,
  halls_max = 4,
  shafts_min = 1,
  shafts_max = 2,
  wings_min = 1,
  wings_max = 2,
  ducts_min = 1,
  ducts_max = 2,
  jitter = 2,              -- lateral offset between neighbouring rooms (cells)
  level_jitter = 3,        -- extra floor offset between side-by-side rooms (cells)
  min_span = 14,           -- the layout must span at least 56 m vertically
  min_levels = 2,          -- and put big rooms on at least two floor levels
  solids = { kind = "spine", min = 2, max = 5, w = { 2, 4 }, h = { 3, 10 } },
  debris = 3,
  color = { 0.80, 0.86, 0.92 },  -- multiplies the kit wall texture (add-detail-pass)
  uv = 0.25,                 -- texture repeats per meter on walls
  solid_color = { 0.48, 0.5, 0.58 },
}
