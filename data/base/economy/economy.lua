-- SPDX-License-Identifier: MIT
-- Trading numbers (concept §7). Mods may override this file.
-- price = base[type] x tier_mult[tier] x (1 + sum of affix values) x civ_rarity
--         x demand(category, civ) x sell_ratio (identified / unidentified)
return {
  tier_mult = { 1.0, 1.4, 1.9, 2.6, 3.5 },
  civ_rarity = { velari = 1.0, oquun = 1.3 },
  sell_ratio = { identified = 0.6, unidentified = 0.4 },
  demand = {
    start = 1.0,
    drop = 0.05,          -- per matching sale
    floor = 0.5,
    recover = 0.01,       -- per sim minute
    cap = 1.5,
  },
  dock_range = 150,       -- meters from the trader station
  charge_price = 1,       -- credits per Charge point
  repair_price = 2,       -- credits per hull point
  identify_charge = 3,    -- Charge per item queued at the lab bench
  identify_seconds = 30,  -- x tier
  decode_seconds = 20,    -- an Echo at the lab bench
}
