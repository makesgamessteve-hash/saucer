-- SPDX-License-Identifier: MIT
-- The galaxy and the Fold Core (concept §3.4, §5.1, OpenSpec add-wider-dark).
-- Mods may override this file.
return {
  sectors = 7,              -- including home; the far end of the spine is the Heart sector
  spine = 4,                -- home -> 2 -> 3 -> Heart: the mystery follows this chain
  hop = { 8, 12 },          -- map distance between linked sectors (light years)
  civs_per_sector = { 2, 3 },
  names = { "Drift", "Reach", "Shoal", "Verge", "Hollow", "Tangle", "Lantern", "Weir", "Cinder", "Brink", "Still" },
  prefixes = { "Amber", "Quiet", "Low", "Pale", "Far", "Glass", "Iron", "Salt", "Hush", "Ember" },
  -- Fold Core tiers: how many links one jump can cross, and its Charge cost
  core = {
    { hops = 1, charge = 40 },
    { hops = 2, charge = 32, price = 450, rep = 1 },
    { hops = 3, charge = 25, price = 900, rep = 2 },
  },
  spool = 3.0,              -- seconds from the last yes to the jump
  arrival_spacing = 40,     -- meters between saucers arriving in formation
}
