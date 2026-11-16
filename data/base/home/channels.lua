-- SPDX-License-Identifier: MIT
-- TV channels (OpenSpec add-holodeck-home-life). A channel is picked up when
-- the saucer is within `range` meters of a source: "trader" (a trader
-- station) or a site of kit "station" / "city" (old broadcasts still loop
-- from them). Each show line comes with a gentle hint drawn from `topics`
-- (sim/tv.lua knows the topics). Mods may override or extend this file.
return {
  { id = "trader_wave", name = "Trader Wave", source = "trader", range = 2600,
    shows = { "Market Hour", "Docking Today", "Salvage Talk" },
    topics = { "demand", "lab", "kitchen", "holo" } },
  { id = "static_noir", name = "Static Noir", source = "station", range = 2400,
    shows = { "The Long Watch", "Cold Corridors", "Night Shift" },
    topics = { "sentries", "mystery", "finds" } },
  { id = "sky_garden", name = "Sky Garden", source = "city", range = 2400,
    shows = { "Spore Weather", "Garden Hour", "Songs of the Drift" },
    topics = { "mystery", "finds", "vault", "kitchen" } },
}
