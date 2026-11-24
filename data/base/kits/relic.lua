-- SPDX-License-Identifier: MIT
-- add-relic-stations: the relic kit. A relic station is not grown room by room like a derelict (sim/ruin.lua):
-- sim/relicgen.lua lays out its warren of halls, trunks, shafts, Seat chambers and the heart hall from the sizes
-- below (in 4 m cells) and returns the ruin table shape, so beams, saves, maps and physics treat it like any derelict.
-- Doors: [1] the Seat port (2.6 x 2.1 m), [4] the XL maw and every Villa aperture (34 x 20 m).
return {
  id = "relic",
  relic = true,
  cell = 4.0,
  wall = 0.5,
  big = 4,
  grid = { 140, 80, 300 },      -- 560 x 320 x 1200 m of space to build in
  rooms = {
    [1] = { 1, 1, 4 },
    [4] = { 24, 12, 24 },
  },
  doors = {
    [0] = { 1.0, 1.0 },
    [1] = { 2.6, 2.1 },
    [4] = { 34.0, 20.0 },
  },
  -- add-relic-dungeons: the warren archetype. Halls sit on a lattice of nodes (pitch cells apart, level_h cells
  -- between floors); trunk corridors join neighbours on a level, shafts join a node to the one above. The maw opens
  -- into the top level's first row, the heart hall lies past the last row and is entered from the lowest level.
  dungeon = {
    lattice = { 3, 4 },         -- nodes across (x) and along (z)
    levels = 4,
    origin = { 70, 4, 24 },     -- the centre of node (0, 0) on level 0 (cells); its floor on y
    pitch = 40,                 -- cells between node centres (160 m)
    level_h = 18,               -- cells between level floors (72 m)
    nodes = { 22, 28 },         -- how many lattice nodes hold a hall
    loops = 0.3,                -- chance each extra neighbour pair gets a corridor too (loops)
    vertical = 0.45,            -- weight of growing up or down a level against along it
    hall_w = { 14, 18, 24 },    -- hall widths and depths (56, 72, 96 m): saucer-size halls to big ones
    hall_h = { [14] = 8, [18] = 10, [24] = 12 },
    trunk = { 10, 6 },          -- corridor cross-section: 40 x 24 m
    shaft = 10,                 -- shaft cross-section: 40 x 40 m
    heart = { 120, 40, 120 },   -- the heart hall: 480 x 160 x 480 m
    heart_gap = 16,             -- cells of corridor from the last row to the heart
    heart_doors = 0.5,          -- chance each extra lowest-level last-row hall also opens into the heart
    engine = { 20, 20 },        -- the heart's engine: a solid column this many cells across (x, z), floor to ceiling
    maw = { 14, 8, 10 },        -- the entrance vestibule: 56 x 32 x 40 m behind a 34 x 20 m maw
    chambers = { 15, 30 },      -- Seat chambers in all
    out = { 4, 9 },             -- a Seat passage's cells out of its hall
    elbow = { 3, 6 },           -- cells after its elbow
    chamber = { 3, 2, 3 },      -- a Seat chamber: 12 x 8 x 12 m
    pad = 6,                    -- cells a Seat branch keeps from a big space (its hide lobes swell up to 20 m)
  },
  -- the locked reliquary's branch off the lung hall: cells out, cells after the elbow (80 m), the reliquary
  passage = { 12, 8 },
  reliquary = { 3, 2, 3 },
  port_rise = 3,                -- a Seat port sits this many cells above its hall's floor (by the bay markers)
  bay = { size = 11, marker_y = 13.0 },   -- 44 m square fold bays; the Seat marker 13 m over the floor
  loot = { hall_share = 0.4, reliquary_finds = 3, chamber_finds = { 1, 2 }, hall_size = { 2, 3 }, idol_value = 1800 },
  debris = 0,
  color = { 0.80, 0.70, 0.78 },
  uv = 0.125,
  solid_color = { 0.4, 0.32, 0.4 },
}
