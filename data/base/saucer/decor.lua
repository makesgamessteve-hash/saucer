-- SPDX-License-Identifier: MIT
-- Villa detail props (OpenSpec add-detail-pass), in hull-local meters like
-- saucer/interior.lua. These are visual only: nothing here is read by the sim
-- or by walking collision, so adding or moving a prop never changes a hash.
-- `at` = { x, z } on the deck; each prop lands in the fold group of the room
-- it stands in (sim/fold.lua group_of), so it packs away with that room.
-- Builders live in meshes/props.lua; extra fields are builder parameters.
return {
  -- kitchen (+x): stove and oven, sink, backsplash and wall cabinets,
  -- microwave, coffee machine, island dressing and pendant lamps
  { deck = 1, kind = "stove",      at = { 7.5, -2.0 } },
  { deck = 1, kind = "sink",       at = { 7.5, 1.0 } },
  { deck = 1, kind = "cabinets",   at = { 7.85, -0.5 } },
  { deck = 1, kind = "microwave",  at = { 7.6, 2.1 } },
  { deck = 1, kind = "coffee",     at = { 7.5, -3.1 } },
  { deck = 1, kind = "fruit_bowl", at = { 4.3, 0.55 } },
  { deck = 1, kind = "board",      at = { 4.3, -0.75 } },
  { deck = 1, kind = "pendant",    at = { 4.3, 0.7 } },
  { deck = 1, kind = "pendant",    at = { 4.3, -0.7 } },
  { deck = 1, kind = "fridge_dressing", at = { 6.7, 3.3 } },
  { deck = 1, kind = "pot_plant",  at = { 7.55, 2.85 }, top = 0.95 },
  -- living room (-x): cushions and a throw on the sofa, floor lamp, side
  -- table, bookshelf, a holo projector on the coffee table, a big leafy plant
  { deck = 1, kind = "cushions",   at = { -7.6, -0.25 } },
  { deck = 1, kind = "floor_lamp", at = { -8.4, -3.5 } },
  { deck = 1, kind = "side_table", at = { -7.5, 3.15 } },
  { deck = 1, kind = "bookshelf",  at = { -7.6, -4.15 }, seed = 3 },
  { deck = 1, kind = "holo",       at = { -5.0, -0.2 }, top = 0.45 },
  { deck = 1, kind = "bush",       at = { -8.6, 2.2 } },
  { deck = 1, kind = "armchair_throw", at = { -5.0, 3.3 } },
  -- helm: a row of buttons along the desk edge and switch banks on the wings
  { deck = 1, kind = "helm_buttons", at = { 0, 9.15 } },
  -- lab: specimen jars on the bench, a crate stack by the cargo hatch
  { deck = 1, kind = "jars",       at = { -4.7, -7.25 }, top = 0.95 },
  { deck = 1, kind = "crates",     at = { 6.8, -6.2 }, seed = 5 },
  { deck = 1, kind = "terminal_text", at = { 5.4, -7.19 } },
  -- bedroom: pillows, folded throw and reading lights, nightstand lamp,
  -- wardrobe doors, a painting on the partition, a plant
  { deck = 2, kind = "bed_dressing", at = { 4.5, 4.4 } },
  { deck = 2, kind = "table_lamp", at = { 1.9, 5.4 }, top = 0.6 },
  { deck = 2, kind = "wardrobe_doors", at = { 6.2, 2.2 } },
  { deck = 2, kind = "painting",   at = { 0.12, 4.5 } },
  { deck = 2, kind = "pot_plant",  at = { 7.2, 3.6 }, top = 0, big = true },
  -- bathroom: basin and mirror, toilet tank, towel rail, floor tiles
  { deck = 2, kind = "basin",      at = { -3.7, 1.3 } },
  { deck = 2, kind = "mirror",     at = { -3.7, 0.92 } },
  { deck = 2, kind = "toilet",     at = { -2.35, 5.95 } },
  { deck = 2, kind = "towel_rail", at = { -0.22, 3.6 } },
  { deck = 2, kind = "tub_tap",    at = { -4.0, 6.75 } },
  { deck = 2, kind = "tiles",      at = { -4.0, 3.0 }, box = { -6.8, 1.0, -0.4, 5.2 } },
  -- engine room: pipes from the core to the walls, coolant tanks, a battery
  -- bank with charge bars, a monitor over the console, floor grating, the
  -- hazard ring round the core (its spinning rotors are drawn by view/render.lua)
  { deck = 2, kind = "engine_ring", at = { 0, -1.8 } },
  { deck = 2, kind = "pipes",      at = { 0, -2.0 } },
  { deck = 2, kind = "tank",       at = { -7.3, -4.4 } },
  { deck = 2, kind = "tank",       at = { 7.1, -4.7 } },
  { deck = 2, kind = "tank",       at = { -6.2, -5.9 } },
  { deck = 2, kind = "battery_bars", at = { -4.58, -5.0 } },
  { deck = 2, kind = "monitor",    at = { 5.3, -1.55 } },
  { deck = 2, kind = "grating",    at = { 0, -6.5 }, box = { -6.0, -8.0, 6.0, -6.4 } },
}
