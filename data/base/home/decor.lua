-- SPDX-License-Identifier: MIT
-- The dome as a home (OpenSpec add-home-among-stars, concept §3.3): furniture
-- you buy at traders and place anywhere on the decks, the six display slots,
-- the garden's alien seeds and how much Comfort each brings. Comfort speeds up
-- Charge regeneration (`regen_per_point`, capped at `regen_cap`). A second
-- piece of the same kind counts half, a third a quarter, and so on.
-- size = { width (x), depth (z) } in meters; h = height; mods may add kinds
-- (the mesh is built from `look` by meshes/furniture.lua).
return {
  regen_per_point = 0.02,
  regen_cap = 0.5,
  levels = {
    { at = 0, name = "Bare" },
    { at = 6, name = "Homely" },
    { at = 12, name = "Cosy" },
    { at = 20, name = "Beloved" },
  },
  -- displayed finds: a Curio counts more than anything else you keep for show
  display = { curio = 3, other = 1, unknown = 0 },
  start = { furniture = { lamp = 1 }, seeds = { glowmoss = 2 } },
  furniture = {
    { id = "lamp",       name = "Floor lamp",        price = 25,  comfort = 2, size = { 0.5, 0.5 }, h = 1.7,
      look = "lamp", color = { 0.95, 0.80, 0.45 } },
    { id = "beanbag",    name = "Beanbag",           price = 30,  comfort = 2, size = { 1.0, 1.0 }, h = 0.6,
      look = "blob", color = { 0.85, 0.35, 0.30 } },
    { id = "armchair",   name = "Reading armchair",  price = 45,  comfort = 3, size = { 1.0, 1.0 }, h = 0.95,
      look = "chair", color = { 0.35, 0.55, 0.40 } },
    { id = "rug",        name = "Round rug",         price = 20,  comfort = 1, size = { 2.0, 2.0 }, h = 0.02,
      look = "rug", color = { 0.30, 0.45, 0.65 }, walk = true },
    { id = "bookcase",   name = "Bookcase",          price = 40,  comfort = 2, size = { 1.2, 0.4 }, h = 1.9,
      look = "case", color = { 0.50, 0.34, 0.22 } },
    { id = "aquarium",   name = "Aquarium",          price = 90,  comfort = 4, size = { 1.4, 0.6 }, h = 1.2,
      look = "tank", color = { 0.35, 0.75, 0.95 } },
    { id = "telescope",  name = "Brass telescope",   price = 70,  comfort = 3, size = { 0.7, 0.7 }, h = 1.6,
      look = "scope", color = { 0.80, 0.62, 0.30 } },
    { id = "hammock",    name = "Star hammock",      price = 60,  comfort = 4, size = { 2.2, 0.9 }, h = 1.2,
      look = "hammock", color = { 0.90, 0.70, 0.40 } },
    { id = "crystal",    name = "Singing crystal",   price = 110, comfort = 5, size = { 0.6, 0.6 }, h = 1.3,
      look = "crystal", color = { 0.70, 0.55, 1.00 } },
    -- add-home-layout: wall, ceiling and on-top pieces
    { id = "poster",       name = "Travel poster",   price = 15,  comfort = 1, size = { 0.8, 0.05 }, h = 1.0,
      look = "poster", color = { 0.90, 0.60, 0.30 }, place = "wall" },
    { id = "hanging_lamp", name = "Hanging lamp",    price = 35,  comfort = 2, size = { 0.4, 0.4 }, h = 0.8,
      look = "hang", color = { 0.95, 0.85, 0.55 }, place = "ceiling" },
    { id = "figurine",     name = "Shelf figurine",  price = 20,  comfort = 1, size = { 0.2, 0.2 }, h = 0.25,
      look = "figure", color = { 0.80, 0.70, 0.50 }, place = "top" },
  },
  -- garden: a seed grows through `stages` over `minutes` of sim time while it
  -- is watered (each watering lasts `water_minutes`); a ripe plant gives its
  -- `harvest` (a kitchen ingredient) and goes back to its first stage
  seeds = {
    { id = "glowmoss",  name = "Glowmoss",       price = 8,  minutes = 30, comfort = 1, harvest = "glowcap",
      color = { 0.45, 1.00, 0.70 }, look = "moss" },
    { id = "sunvine",   name = "Oquun sunvine",  price = 14, minutes = 45, comfort = 2, harvest = "sunfruit",
      color = { 1.00, 0.80, 0.30 }, look = "vine" },
    { id = "emberleaf", name = "Velari emberleaf", price = 18, minutes = 60, comfort = 2, harvest = "velari_spice",
      color = { 1.00, 0.40, 0.25 }, look = "leaf" },
  },
  stages = { "seed", "sprout", "bloom", "ripe" },
  water_minutes = 40,
}
