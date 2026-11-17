-- SPDX-License-Identifier: MIT
-- Saucer upgrades sold at trade terminals and station chandlers (OpenSpec
-- add-playtest-recs; playtest 2026-11-17 recommendation 1). Something to spend
-- on after Fold Core tier 2. Mods may override this file.
--   needs_tier: the Fold Core tier you must own first
--   price: one price per level (the list length is the number of levels)
return {
  { id = "beam_relay", name = "Helm beam relay", needs_tier = 1, price = { 180 },
    desc = "pull small finds (size S and M) straight from the helm" },
  { id = "tractor_coils", name = "Tractor coils", needs_tier = 2, price = { 200, 400 },
    desc = "the beam pulls 40% faster per level", pull = 0.4 },
  { id = "hold_racks", name = "Hold racks", needs_tier = 2, price = { 250, 500 },
    desc = "+4 hold slots per level", slots = 4 },
  { id = "shield_cells", name = "Shield cells", needs_tier = 2, price = { 220, 440 },
    desc = "shields soak 25% more per level", soak = 0.25 },
  { id = "lab_bench", name = "Second lab bench", needs_tier = 2, price = { 350 },
    desc = "the lab runs two jobs at once" },
}
