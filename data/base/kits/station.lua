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
  color = { 0.84, 0.86, 0.90 },  -- multiplies the kit wall texture (add-detail-pass)
  uv = 0.125,                 -- texture repeats per meter on walls
  solid_color = { 0.55, 0.5, 0.44 },
  -- add-pocket-station-visits: the walkable inside of a trader station
  -- (sim/stationgen.lua). Sizes in cells of walk.cell meters: a concourse
  -- spine with the arrival hangar at its start, a market hall, a bar down a
  -- narrow passage and a second hangar at the far end or off a side passage.
  walk = {
    cell = 4.0,
    spine = { w = 2, len = { 9, 12 }, h = 7.0 },
    passage = { w = 1, len = { 1, 2 }, h = 4.5 },
    hangar = { w = { 9, 10 }, d = { 9, 10 }, h = 20.0 },
    market = { w = { 6, 7 }, d = { 5, 6 }, h = 11.0, stalls = { 4, 5 } },
    bar = { w = { 4, 5 }, d = { 4, 5 }, h = 5.0, tables = { 2, 3 } },
    door_h = 4.0,
    pad_y = 7.2,            -- where a growing Villa's hull centre sits above the hangar floor
    bay_dist = 85,          -- meters from the station's centre to the second hangar's space door
    walkers = { 3, 5 },     -- people strolling the concourse
  },
}
