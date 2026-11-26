-- SPDX-License-Identifier: MIT
-- add-civ-hulls: how a civ dresses the outside of what it builds (its trader stations and its relics), read by
-- sim/hulldress.lua. Four things tell two builders apart from afar: the silhouette (a motif of big growths), the
-- surface pattern (from the civ's signature rule), the hull's material (its own material table) and its signal
-- lights (from its light model). Sizes are fractions of the hull they dress; colours linear 0..1; mods may override.
return {
  -- the silhouette motifs, in the order a roster hands them out when two civs would like the same one
  motifs = { "spines", "fins", "arches", "domes", "masts", "cage", "tendrils", "shards" },
  -- the motif a massing would like (the roster gives each civ its liking unless an earlier civ took it)
  prefer = { spine = "spines", warren = "spines", hive = "domes", cluster = "tendrils", helix = "arches",
             shell = "arches", lattice = "cage", organism = "tendrils" },
  -- per motif: elements round a station's aft crown, their reach (x the body radius R), their girth (x R)
  station = {
    spines = { n = 9, reach = 0.62, girth = 0.07 },
    fins = { n = 6, reach = 0.55, girth = 0.32 },
    arches = { n = 3, reach = 0.78, girth = 0.05 },
    domes = { n = 7, reach = 0.22, girth = 0.2 },
    masts = { n = 8, reach = 0.7, girth = 0.025 },
    cage = { n = 8, reach = 0.6, girth = 0.022 },
    tendrils = { n = 7, reach = 0.6, girth = 0.06 },
    shards = { n = 8, reach = 0.5, girth = 0.1 },
    aft = 0.55,         -- the crown stands this far behind the body's back (x the aft length), inside the box
    crest = 5,          -- smaller copies along the top of the stem (they read in a side view)
    crest_scale = 0.18, -- their size (x the crown's)
    far_glow = 0.45,    -- the far silhouette's self-light (0..1): a station far off reads in its colours, not as a shadow
    self_glow = 0.12,   -- the crown's self-light up close
  },
  -- the signature rule's surface pattern: what grows on the hull's surface spots, and how many lit marks each has
  patterns = {
    PIERCE = { kind = "studs", lit = 1 },     -- spikes through the hide, a glowing wound ring at each root
    CRUST = { kind = "crust", lit = 2 },      -- knobbed crust nodules, a few of them aglow
    PLATE = { kind = "plates", lit = 1 },     -- overlapping scale plates, a lit seam under each
    INLAY = { kind = "inlay", lit = 3 },      -- glowing lines inlaid along the plating
    ENCASE = { kind = "cells", lit = 1 },     -- hexagonal cells with a glowing heart
    FLOW = { kind = "flow", lit = 2 },        -- long glowing streaks, as if the hull ran
  },
  pattern_spots = 28,   -- surface spots a station's body carries a pattern mark on (at most)
  pattern_size = 0.05,  -- a mark's size (x R)
  -- the light model's signals (view/stationhull.lua, view/relic.lua): kind, period (ticks), how big they read
  lights = {
    chromatic = { kind = "chroma", period = 240, size = 1.0 },  -- each signal cycles the civ's lamp colours
    ripple = { kind = "ripple", period = 180, size = 0.9 },     -- waves run down the hull's length
    fogbank = { kind = "fog", period = 420, size = 1.8 },       -- big soft glows breathing slowly
    arc = { kind = "arc", period = 50, size = 0.8 },            -- sharp flashes jumping between pairs
    orbit = { kind = "orbit", period = 300, size = 1.0 },       -- lights circling the crown
    dark = { kind = "dim", period = 600, size = 0.7 },          -- a faint rim glow only (they live by touch)
  },
  -- signals: drawn out to `far` m, never smaller than min_px x distance, their colour lifted against the fog (by up to
  -- `boost` times) so a far one still reads as a light
  signal = { far = 9000, min_px = 0.02, max = 64, boost = 8 },
  -- a relic seen from beyond its near range: each big room as a hull of the civ's edge language, crowned by its motif
  relic = { edge_seg = { round = 10, chamfer = 8, fluted = 16, serrated = 5 }, motif_scale = 0.65, girth = 0.14, far = 7000,
            band = 0.08, glow = 0.25, signal = 0.16 },
}
