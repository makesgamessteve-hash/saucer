-- SPDX-License-Identifier: MIT
-- The outside of a trader station (OpenSpec add-huge-stations): a kilometre-scale megastructure that
-- hangs off the fixed hangar cell (saucer/dock.lua) along the cell's back axis, -x from the dock anchor
-- (the trader's `pos`). sim/stationhull.lua turns a class and a seed into its parts, solids and lights.
-- Sizes in meters, colours linear 0..1. Ranges are { lo, hi } picked from the seed; mods may override.
return {
  classes = {
    -- a hub station: a visitor arm to a hub, one or two spinning rings, docking arms, arrays, masts and cargo
    port = {
      radius = { 400, 560 },     -- the big ring's radius
      arm = { 330, 440 },        -- from the hangar cell's back wall to the hub drum's front
      hub_r = { 60, 80 },
      hub_len = { 130, 180 },
      rings = { 1, 2 },
      spokes = { 6, 8 },
      arms = { 6, 9 },           -- docking arms off the visitor arm, each ending in a pod with a lit mouth
      drums = { 3, 6 },          -- habitat drums on the outer rim
      masts = { 3, 5 },
      wings = { 1, 2 },          -- pairs of solar wings on the aft spine
      cargo = { 2, 4 },          -- cargo racks on the aft spine
      aft = { 260, 340 },        -- the aft spine behind the hub
      window_rows = 3,
      detail = 1.0,
    },
    -- a city's trader outpost: the same grammar, a tenth of the size
    outpost = {
      radius = { 90, 130 },
      arm = { 80, 110 },
      hub_r = { 18, 24 },
      hub_len = { 40, 55 },
      rings = { 1, 1 },
      spokes = { 4, 6 },
      arms = { 2, 4 },
      drums = { 1, 3 },
      masts = { 1, 2 },
      wings = { 1, 1 },
      cargo = { 1, 2 },
      aft = { 70, 100 },
      window_rows = 2,
      detail = 0.6,
    },
  },
  -- hull palettes: plating, trim, panel (darker seams), accent (stripes, cargo), glow (windows and lights)
  palettes = {
    { name = "sandstone", plate = { 0.72, 0.66, 0.58 }, trim = { 0.5, 0.46, 0.42 }, panel = { 0.42, 0.38, 0.35 },
      accent = { 0.9, 0.5, 0.15 }, glow = { 1.0, 0.82, 0.45 } },
    { name = "steel", plate = { 0.58, 0.62, 0.7 }, trim = { 0.38, 0.4, 0.46 }, panel = { 0.3, 0.32, 0.38 },
      accent = { 0.2, 0.7, 0.9 }, glow = { 0.7, 0.95, 1.0 } },
    { name = "moss", plate = { 0.52, 0.6, 0.5 }, trim = { 0.34, 0.4, 0.34 }, panel = { 0.26, 0.31, 0.27 },
      accent = { 0.95, 0.8, 0.2 }, glow = { 0.85, 1.0, 0.6 } },
    { name = "bone", plate = { 0.82, 0.8, 0.75 }, trim = { 0.55, 0.54, 0.52 }, panel = { 0.45, 0.44, 0.44 },
      accent = { 0.85, 0.2, 0.2 }, glow = { 1.0, 0.95, 0.8 } },
    { name = "violet", plate = { 0.6, 0.55, 0.68 }, trim = { 0.4, 0.36, 0.48 }, panel = { 0.3, 0.27, 0.38 },
      accent = { 0.95, 0.4, 0.8 }, glow = { 1.0, 0.75, 0.95 } },
  },
  lod = {
    far = 1100,     -- beyond this distance from the hull's bounding box only the silhouette is drawn
    detail = 380,   -- nearer than this the greebles, trusses and windows are drawn too
    lights = 900,   -- blinking beacons and approach lights within this range
    max_lights = 40,
  },
  spin = 0.0016,    -- radians per sim tick the rings turn (the hull and the hangar cell stand still)
  -- the approach corridor out of the hangar mouth: pairs of lights, a chase running toward the dock
  approach = { length = 420, step = 30, half_w = 20, speed = 90 },
  budget = { core = 20000, detail = 60000, far = 4000 },   -- triangles
}
