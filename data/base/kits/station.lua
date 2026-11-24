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
    [0] = { 1.0, 1.0 },   -- add-on-foot-excursions: a crawlspace mouth (on foot only)
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
  foot = { crawl_len = { 2, 4 }, crawl = { 1.0, 1.0 }, chamber = { 2, 1, 2 }, strong = { 3, 1, 3 } },
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
    -- add-alien-stations: the alien wing off the market's far wall (sim/stationgen.lua alien_wing): passages
    -- (straight or doglegged) and chambers of five looks, named and coloured by the station's family
    alien = {
      chambers = { 6, 8 },
      size = { 6, 10 },        -- chamber sides in cells
      passage = { 1, 3 },      -- passage legs in cells
      passage_w = 2,
      passage_h = 6.0,
      hall_h = { 10, 16 },
      shaft_h = { 36, 54 },    -- vertical shafts, ledges climbing their walls
      names = {
        coral = { passage = "Gullet passage", atrium = "Spore atrium", shaft = "Tide shaft", brood = "Brood hall",
                  garden = "Polyp garden", shrine = "Chitin shrine" },
        crystal = { passage = "Prism passage", atrium = "Geode atrium", shaft = "Resonance shaft", brood = "Seed vault",
                    garden = "Crystal garden", shrine = "Echo shrine" },
        spiral = { passage = "Coil passage", atrium = "Whorl atrium", shaft = "Spiral shaft", brood = "Nautilus brood",
                   garden = "Tendril garden", shrine = "Helix shrine" },
        shells = { passage = "Gyre passage", atrium = "Orrery", shaft = "Gyre shaft", brood = "Shell nursery",
                   garden = "Stillwater garden", shrine = "Stone circle" },
      },
      -- the inside's colours per family: walls, floor, growth (trim), glow and accent
      colors = {
        coral = { wall = { 0.62, 0.42, 0.46 }, floor = { 0.36, 0.24, 0.26 }, trim = { 0.5, 0.3, 0.36 }, glow = { 0.35, 1.0, 0.9 },
                  accent = { 1.0, 0.45, 0.75 } },
        crystal = { wall = { 0.42, 0.44, 0.6 }, floor = { 0.22, 0.22, 0.32 }, trim = { 0.3, 0.32, 0.46 }, glow = { 0.55, 0.9, 1.0 },
                    accent = { 0.8, 0.55, 1.0 } },
        spiral = { wall = { 0.6, 0.48, 0.32 }, floor = { 0.34, 0.26, 0.16 }, trim = { 0.46, 0.33, 0.18 }, glow = { 1.0, 0.8, 0.3 },
                   accent = { 0.55, 1.0, 0.4 } },
        shells = { wall = { 0.6, 0.6, 0.7 }, floor = { 0.3, 0.3, 0.38 }, trim = { 0.42, 0.42, 0.55 }, glow = { 0.5, 0.75, 1.0 },
                   accent = { 1.0, 0.82, 0.45 } },
      },
    },
  },
}
