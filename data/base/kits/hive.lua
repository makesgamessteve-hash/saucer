-- SPDX-License-Identifier: MIT
-- Hive kit (OpenSpec add-wider-dark): the newest kit, an organic hive grown
-- by organic and modular civs. Many low, wide brood halls stacked in tiers
-- and joined by short, fat shafts, lots of ducts (so lots of Snatchers and
-- caches), and round brood pods clinging to the outside (solids "pod").
-- Same grammar as the other kits (sim/ruin.lua); only the numbers differ.
return {
  id = "hive",
  -- no material of its own yet: the organic city wall and floor, tinted amber
  texture = "city",
  floor_texture = "station",
  cell = 4.0,
  wall = 0.6,
  big = 4,
  grid = { 96, 64, 96 },   -- 384 x 256 x 384 m
  rooms = {
    [1] = { 1, 1, 3 },     -- a brood duct: one Seat wide, 12 m long
    [4] = { 18, 7, 18 },   -- brood hall: 72 x 28 x 72 m, low and wide
  },
  wing = { 15, 7, 12 },
  shaft = { 11, 18, 11 },  -- a fat tier shaft: 44 x 72 x 44 m
  chamber = { 3, 1, 3 },
  doors = {
    [0] = { 1.0, 1.0 },
    [1] = { 2.6, 2.1 },
    [4] = { 30.0, 19.0 },
  },
  halls_min = 3,
  halls_max = 5,
  shafts_min = 2,
  shafts_max = 3,
  wings_min = 1,
  wings_max = 3,
  ducts_min = 2,
  ducts_max = 4,
  jitter = 3,
  level_jitter = 2,
  min_span = 16,
  min_levels = 3,
  solids = { kind = "pod", min = 6, max = 12, w = { 3, 6 }, h = { 3, 6 } },
  foot = { crawl_len = { 2, 3 }, crawl = { 1.0, 1.0 }, chamber = { 2, 1, 2 }, strong = { 3, 1, 3 } },
  debris = 5,
  color = { 0.86, 0.80, 0.62 },   -- resin amber over the kit wall texture
  uv = 0.2,
  solid_color = { 0.62, 0.50, 0.30 },
  window_color = { 1.0, 0.65, 0.25 },
  floor_tint = { 0.9, 0.75, 0.5 },
}
