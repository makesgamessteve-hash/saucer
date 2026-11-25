-- SPDX-License-Identifier: MIT
-- add-civ-dungeons (plan phase 6, design civs-and-relics §3.2): each massing archetype lays its relic out by its own
-- room grammar. sim/relicgen.lua copies the relic kit's warren (kits/relic.lua `dungeon`) and overrides it with the
-- civ's archetype below, then with its body scale. The slice's Vyrr pin `layout = "warren"` and keep the kit's.
return {
  archetypes = {
    -- branching like veins: a long gullet, few loops, organ halls off it
    organism = { lattice = { 3, 5 }, levels = 3, nodes = { 18, 24 }, loops = 0.05, vertical = 0.3, chambers = { 12, 28 } },
    -- a crystalline 3D grid: dense, many loops, square halls at nodes
    lattice = { lattice = { 3, 3 }, levels = 4, nodes = { 26, 32 }, loops = 0.8, vertical = 0.7, square = true },
    -- nested rings: wide and shallow, loops round the rim
    shell = { lattice = { 4, 3 }, levels = 3, nodes = { 20, 28 }, loops = 0.45, vertical = 0.35, mask = "ring" },
    -- rooms round a ring: a hollow square of halls on three levels
    ring = { lattice = { 4, 4 }, levels = 3, nodes = { 14, 20 }, loops = 0.6, vertical = 0.15, mask = "ring", chambers = { 12, 30 } },
    -- a spiral round a tall shaft: a narrow footprint over many levels
    helix = { lattice = { 2, 2 }, levels = 6, nodes = { 16, 22 }, loops = 0.35, vertical = 0.9, chambers = { 12, 30 } },
    -- a dense foam of small cells and many Seat warrens
    hive = { lattice = { 4, 4 }, levels = 3, nodes = { 24, 30 }, loops = 0.4, vertical = 0.4, small = true,
             chambers = { 22, 36 } },
    -- separate modules joined by long corridors
    cluster = { lattice = { 3, 4 }, levels = 3, nodes = { 14, 20 }, loops = 0.1, vertical = 0.3, pitch = 56,
                chambers = { 12, 30 } },
    -- one long axis with side wings and levels
    spine = { lattice = { 2, 6 }, levels = 4, nodes = { 22, 28 }, loops = 0.2, vertical = 0.4 },
  },
  -- body scale: hall sizes (cells; >= 14, the 54 m hall minimum; <= 24, so a fold bay stays by its Seat port), fewer
  -- Seat chambers for big bodies, the heart (>= 32, the 128 m Core minimum); tiny bodies allow more Seat chambers
  scales = {
    tiny = { hall_w = { 14, 14, 18 }, chambers_add = 4, heart = { 96, 32, 96 } },
    human = {},
    large = { hall_w = { 14, 18, 24 } },
    giant = { hall_w = { 18, 24, 24 }, chambers = { 10, 22 }, heart = { 130, 46, 130 } },
    colossal = { hall_w = { 24, 24 }, chambers = { 8, 20 }, heart = { 140, 52, 140 } },
  },
  hall_h = { [14] = 8, [18] = 10, [24] = 12, [30] = 14 },
  tries = 16,                   -- a styled relic may take more tries than the slice's warren
  grid = { 420, 200, 520 },     -- room to build a styled relic in (cells)
}
