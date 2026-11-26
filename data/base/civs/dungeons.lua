-- SPDX-License-Identifier: MIT
-- add-civ-dungeons (plan phase 6, design civs-and-relics §3.2), vary-relic-room-plans:
-- each massing archetype lays its relic out by its own room grammar. sim/relicgen.lua copies the relic kit's warren
-- (kits/relic.lua `dungeon`) and overrides it with the civ's archetype below, then with its body scale. The slice's
-- Vyrr pin `layout = "warren"` and keep the kit's rectangular lattice. Every other archetype now also names a
-- `pattern` (sim/relicpat.lua) that places halls in a spiral, rings, shells, a helix, a Sierpinski gasket, an
-- H-tree, a diamond or a recursive spine, with the heart in the reserved centre, so the room-plan map is no longer
-- a filled rectangle.
return {
  archetypes = {
    -- a spiral gullet into the heart, with short organ branches off it
    organism = { pattern = "spiral", lattice = { 3, 5 }, levels = 3, nodes = { 18, 24 }, loops = 0.05, vertical = 0.3,
                 chambers = { 12, 28 } },
    -- a crystalline diamond / octahedral ring around the heart, dense with loops, square halls
    lattice = { pattern = "diamond", lattice = { 3, 3 }, levels = 4, nodes = { 26, 32 }, loops = 0.8, vertical = 0.7,
                square = true },
    -- spherical shells: rings whose radius follows a sphere (wider at the equator)
    shell = { pattern = "shells", lattice = { 4, 3 }, levels = 3, nodes = { 20, 28 }, loops = 0.45, vertical = 0.35,
              mask = "ring" },
    -- nested circular rings around the heart, with spokes (mask stays for the styled-kit test)
    ring = { pattern = "rings", lattice = { 4, 4 }, levels = 3, nodes = { 14, 20 }, loops = 0.6, vertical = 0.15,
             mask = "ring", chambers = { 12, 30 } },
    -- a conical helix: rooms climb around the heart, the radius growing with height (a spiral from above)
    helix = { pattern = "helix", lattice = { 2, 2 }, levels = 6, nodes = { 16, 22 }, loops = 0.35, vertical = 0.9,
              chambers = { 12, 30 } },
    -- a Sierpinski right-triangle gasket of small cells; the heart sits in the largest removed square
    hive = { pattern = "sierpinski", lattice = { 4, 4 }, levels = 3, nodes = { 24, 30 }, loops = 0.4, vertical = 0.4,
             small = true, chambers = { 22, 36 } },
    -- recursive H-tree modules around the heart, joined by long corridors
    cluster = { pattern = "htree", lattice = { 3, 4 }, levels = 3, nodes = { 14, 20 }, loops = 0.1, vertical = 0.3,
                pitch = 56, chambers = { 12, 30 } },
    -- a long, slightly curved axis with recursive side wings; the heart sits in the middle
    spine = { pattern = "spine", lattice = { 2, 6 }, levels = 4, nodes = { 22, 28 }, loops = 0.2, vertical = 0.4 },
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
  grid = { 520, 240, 520 },     -- room to build a centred, patterned relic in (cells)
}
