-- SPDX-License-Identifier: MIT
-- Build budgets of the recipes that are bigger than a hero mesh (OpenSpec
-- add-mesh-builder, "Build budget and cache"). A hero mesh (a Watcher, a
-- Snatcher, a cockpit prop, the station...) has at most 3000 triangles and
-- builds in 5 ms on desktop (20 ms on the web). These recipes build whole
-- hulls or rooms and are listed with their own ceilings, a little above what
-- they use today, so any growth fails a test instead of creeping in. A recipe
-- may also carry its own `budget = { tris = n }`. Mods may override this file.
return {
  saucer = { tris = 6000, ms = 30, ms_web = 120 },    -- the Villa's hull and the pocket coin (4.8k and 5.0k triangles)
  interior = { tris = 28000, ms = 120, ms_web = 480 }, -- the Villa's walkable rooms, one mesh (22.3k triangles)
}
