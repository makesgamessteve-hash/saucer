-- SPDX-License-Identifier: MIT
-- The outside of a trader station (OpenSpec add-huge-stations, add-alien-stations): a multi-kilometre alien
-- megastructure that grows off the fixed hangar cell (saucer/dock.lua) along the cell's back axis, -x from
-- the dock anchor (the trader's `pos`). Every station is built by one alien architecture family picked from
-- its seed; sim/stationhull.lua turns a class, a seed and a family into its parts, solids and lights.
-- Sizes in meters, colours linear 0..1. Ranges are { lo, hi } picked from the seed; mods may override.
return {
  classes = {
    -- a trader port: a long stem out of the hangar cell, the family's body, and growths behind it
    port = {
      scale = 1.0,
      radius = { 860, 1040 },    -- the body's reach off the axis (the hull's half width)
      stem = { 520, 680 },       -- from the hangar cell's back wall to the body's front
      body = { 1000, 1280 },     -- the body's length along the axis
      aft = { 260, 420 },        -- growths behind the body
      pods = { 7, 10 },          -- docking pods off the stem, each with a lit iris mouth
      monoliths = { 4, 7 },      -- floating glyph slabs round the stem
      cocoons = { 5, 8 },        -- clusters of cocoons on the stem and body
      branches = { 11, 15 },     -- the family's big growths (tendrils, shards, helix turns, shells)
      detail = 1.0,
    },
    -- a city's trader outpost: the same grammar at a quarter of the size
    outpost = {
      scale = 0.25,
      radius = { 215, 260 },
      stem = { 130, 170 },
      body = { 250, 320 },
      aft = { 65, 105 },
      pods = { 2, 4 },
      monoliths = { 1, 2 },
      cocoons = { 2, 3 },
      branches = { 6, 8 },
      detail = 0.5,
    },
  },
  -- the alien architecture families: each names the palettes it may wear and its lamp colours inside
  families = {
    { id = "coral", name = "Reef", palettes = { "chitin", "coral", "verdigris" },
      lamps = { { 1.0, 0.35, 0.75 }, { 0.3, 1.0, 0.85 }, { 0.95, 0.7, 0.3 } } },
    { id = "crystal", name = "Lattice", palettes = { "obsidian", "nacre", "glacier" },
      lamps = { { 0.45, 0.85, 1.0 }, { 0.75, 0.5, 1.0 }, { 0.92, 0.95, 1.0 } } },
    { id = "spiral", name = "Helix", palettes = { "amber", "verdigris", "chitin" },
      lamps = { { 1.0, 0.7, 0.25 }, { 0.55, 1.0, 0.35 }, { 1.0, 0.45, 0.3 } } },
    { id = "shells", name = "Gyre", palettes = { "nacre", "obsidian", "amber" },
      lamps = { { 0.4, 0.6, 1.0 }, { 1.0, 0.82, 0.4 }, { 0.6, 1.0, 0.95 } } },
  },
  -- hull palettes: plating, trim (darker growth), panel (seams), accent (markings), glow (irises, glyphs, lights)
  palettes = {
    chitin = { plate = { 0.46, 0.33, 0.4 }, trim = { 0.3, 0.2, 0.27 }, panel = { 0.2, 0.13, 0.18 },
               accent = { 0.95, 0.35, 0.7 }, glow = { 0.55, 1.0, 0.75 } },
    coral = { plate = { 0.78, 0.47, 0.42 }, trim = { 0.55, 0.3, 0.32 }, panel = { 0.36, 0.2, 0.22 },
              accent = { 1.0, 0.85, 0.5 }, glow = { 0.35, 1.0, 0.95 } },
    verdigris = { plate = { 0.32, 0.52, 0.46 }, trim = { 0.2, 0.34, 0.3 }, panel = { 0.13, 0.22, 0.2 },
                  accent = { 1.0, 0.6, 0.22 }, glow = { 0.8, 1.0, 0.3 } },
    obsidian = { plate = { 0.25, 0.23, 0.32 }, trim = { 0.15, 0.13, 0.2 }, panel = { 0.1, 0.09, 0.14 },
                 accent = { 0.65, 0.35, 1.0 }, glow = { 1.0, 0.45, 0.95 } },
    nacre = { plate = { 0.76, 0.74, 0.84 }, trim = { 0.5, 0.48, 0.62 }, panel = { 0.34, 0.32, 0.44 },
              accent = { 0.4, 0.75, 1.0 }, glow = { 0.55, 0.95, 1.0 } },
    glacier = { plate = { 0.55, 0.7, 0.8 }, trim = { 0.34, 0.46, 0.56 }, panel = { 0.2, 0.28, 0.36 },
                accent = { 0.95, 0.95, 1.0 }, glow = { 0.6, 0.85, 1.0 } },
    amber = { plate = { 0.66, 0.46, 0.24 }, trim = { 0.42, 0.28, 0.14 }, panel = { 0.26, 0.17, 0.09 },
              accent = { 0.35, 0.9, 1.0 }, glow = { 1.0, 0.82, 0.32 } },
  },
  lod = {
    far = 1400,     -- beyond this distance from the hull's bounding box only the silhouette is drawn
    detail = 420,   -- nearer than this the growth detail, glyphs and irises are drawn too
    lights = 1100,  -- blinking beacons and approach lights within this range
    max_lights = 40,
  },
  spin = 0.0012,    -- radians per sim tick the spinning layer turns (the hull and the hangar cell stand still)
  -- the approach corridor out of the hangar mouth: pairs of lights, a chase running toward the dock
  approach = { length = 420, step = 30, half_w = 20, speed = 90 },
  budget = { core = 40000, detail = 90000, far = 6000 },   -- triangles
}
