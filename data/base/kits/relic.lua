-- SPDX-License-Identifier: MIT
-- add-relic-stations: the relic kit. A relic station is not grown room by room like a derelict (sim/ruin.lua):
-- sim/relicgen.lua lays out its spine of hub halls, trunks and the Core from the size classes below (in 4 m
-- cells) and returns the ruin table shape, so beams, saves, maps and physics treat it like any derelict.
-- Doors: [1] the Seat port (2.6 x 2.1 m), [4] the XL maw and every Villa aperture (34 x 20 m).
return {
  id = "relic",
  relic = true,
  cell = 4.0,
  wall = 0.5,
  big = 4,
  grid = { 64, 32, 250 },       -- 256 x 128 x 1000 m of space to build in
  rooms = {
    [1] = { 1, 1, 4 },
    [4] = { 24, 12, 24 },
  },
  doors = {
    [0] = { 1.0, 1.0 },
    [1] = { 2.6, 2.1 },
    [4] = { 34.0, 20.0 },
  },
  spine = {
    maw = { 14, 8, 10 },        -- the entrance vestibule: 56 x 32 x 40 m behind a 34 x 20 m maw
    hall = { 24, 12, 24 },      -- hub hall: 96 x 48 x 96 m
    trunk = { 10, 6, 40 },      -- trunk corridor: 40 x 24 x 160 m
    core = { 32, 16, 32 },      -- the Core: 128 x 64 x 128 m
    halls = 3,
    lung = 2,                   -- the hall that breathes (and holds the Seat port and four fold bays)
    plague = 3,                 -- the hall the plague left necrotic
    passage = { 12, 8 },        -- the Seat branch: cells out of the lung hall, then cells after its elbow (80 m)
    reliquary = { 3, 2, 3 },    -- 12 x 8 x 12 m
    port_rise = 3,              -- the port sits this many cells above the hall floor (by the bay markers)
  },
  bay = { size = 11, marker_y = 13.0 },   -- 44 m square fold bays; the Seat marker 13 m over the floor
  loot = { hall_finds = 6, reliquary_finds = 3, hall_size = { 2, 3 }, idol_value = 1800 },
  debris = 0,
  color = { 0.80, 0.70, 0.78 },
  uv = 0.125,
  solid_color = { 0.4, 0.32, 0.4 },
}
