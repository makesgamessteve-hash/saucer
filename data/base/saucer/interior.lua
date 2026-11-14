-- SPDX-License-Identifier: MIT
-- Villa interior layout (concept §3.3, v0.4), in hull-local meters: +z points
-- to the helm (forward), y is up, the hull centre is the origin. The same table
-- drives walking collision (sim/avatar.lua) and the code-generated interior
-- meshes (meshes/interior.lua), so what you see is what you bump into.
-- Furniture boxes are { x0, z0, x1, z1 } on a deck; h is the visible height.
-- solid = false means decoration you can walk through (rugs, the helm chair).
return {
  body_radius = 0.3,
  eye = 1.62,
  walk_speed = 3.2,
  run_factor = 1.7,
  turn = 2.4,
  look = 1.8,
  pitch_limit = 1.35,
  step = 0.6,               -- largest floor height change one step can take
  decks = {
    { id = "dome",  name = "Dome deck",  floor = 0.6,  radius = 10.0, ceiling = 6.2 },
    { id = "lower", name = "Lower deck", floor = -3.0, radius = 8.8,  ceiling = 0.3 },
  },
  dome = { radius = 10.6, height = 5.6 },
  -- straight stair along x: the low end opens onto the lower deck, the high end onto the dome deck
  stairs = { low = -3.0, high = 3.5, z0 = -6.0, z1 = -4.4, steps = 12 },
  helm = { seat = { 0, 0.6, 7.2 }, stand = { 0, 0.6, 5.7 }, use_radius = 1.9 },
  spawn = { pos = { -2.0, 0.6, -1.0 }, yaw = 0.0 },
  rooms = {
    { deck = 1, name = "Helm",        box = { -3.5, 5.0, 3.5, 10 } },
    { deck = 1, name = "Kitchen",     box = { 2.5, -4.0, 10, 5.0 } },
    { deck = 1, name = "Living room", box = { -10, -4.0, -2.5, 5.0 } },
    { deck = 1, name = "Stairs",      box = { -3.0, -6.0, 3.5, -4.4 } },
    { deck = 2, name = "Stairs",      box = { -3.0, -6.0, 3.5, -4.4 } },
    { deck = 2, name = "Bedroom",     box = { 0.1, 0.9, 10, 10 } },
    { deck = 2, name = "Bathroom",    box = { -10, 0.9, -0.1, 10 } },
    { deck = 2, name = "Engine room", box = { -10, -10, 10, 0.9 } },
  },
  furniture = {
    -- dome deck: helm
    { deck = 1, kind = "console", box = { -1.6, 8.5, 1.6, 9.2 }, h = 0.85, color = { 0.30, 0.32, 0.40 } },
    { deck = 1, kind = "chair",   box = { -0.5, 6.8, 0.5, 7.6 }, h = 1.1, color = { 0.85, 0.45, 0.20 }, solid = false },
    -- kitchen (+x side)
    { deck = 1, kind = "counter", box = { 7.0, -3.5, 8.0, 2.5 }, h = 0.95, color = { 0.92, 0.90, 0.86 } },
    { deck = 1, kind = "counter", box = { 3.6, -1.4, 5.0, 1.4 }, h = 0.95, color = { 0.55, 0.38, 0.25 } },
    { deck = 1, kind = "fridge",  box = { 6.0, 3.3, 7.4, 4.3 }, h = 2.0, color = { 0.82, 0.86, 0.90 } },
    { deck = 1, kind = "stool",   box = { 2.7, -0.9, 3.2, -0.4 }, h = 0.7, color = { 0.25, 0.25, 0.3 }, solid = false },
    { deck = 1, kind = "stool",   box = { 2.7, 0.4, 3.2, 0.9 }, h = 0.7, color = { 0.25, 0.25, 0.3 }, solid = false },
    -- living room (-x side)
    { deck = 1, kind = "rug",     box = { -7.0, -2.6, -3.4, 2.4 }, h = 0.02, color = { 0.55, 0.25, 0.35 }, solid = false },
    { deck = 1, kind = "sofa",    box = { -8.0, -3.0, -7.0, 2.5 }, h = 0.85, color = { 0.25, 0.45, 0.70 } },
    { deck = 1, kind = "table",   box = { -5.6, -1.2, -4.4, 0.8 }, h = 0.45, color = { 0.45, 0.30, 0.20 } },
    { deck = 1, kind = "armchair",box = { -5.6, 2.7, -4.4, 3.9 }, h = 0.9, color = { 0.25, 0.45, 0.70 } },
    { deck = 1, kind = "plant",   box = { -7.1, -5.6, -6.3, -4.8 }, h = 1.6, color = { 0.25, 0.65, 0.30 } },
    { deck = 1, kind = "plant",   box = { 5.6, -6.6, 6.4, -5.8 }, h = 1.4, color = { 0.25, 0.65, 0.30 } },
    -- stair rails on the dome deck (sides and the far low end)
    { deck = 1, kind = "rail", box = { -3.0, -6.1, 3.5, -6.0 }, h = 1.0, color = { 0.6, 0.62, 0.7 } },
    { deck = 1, kind = "rail", box = { -3.0, -4.4, 3.5, -4.3 }, h = 1.0, color = { 0.6, 0.62, 0.7 } },
    { deck = 1, kind = "rail", box = { -3.1, -6.1, -3.0, -4.3 }, h = 1.0, color = { 0.6, 0.62, 0.7 } },
    -- lower deck: stair side walls and the wall under the top landing
    { deck = 2, kind = "wall", box = { -3.0, -6.2, 3.5, -6.0 }, h = 3.3, color = { 0.62, 0.60, 0.56 } },
    { deck = 2, kind = "wall", box = { -3.0, -4.4, 3.5, -4.2 }, h = 3.3, color = { 0.62, 0.60, 0.56 } },
    { deck = 2, kind = "wall", box = { 3.5, -6.2, 3.7, -4.2 }, h = 3.3, color = { 0.62, 0.60, 0.56 } },
    -- lower deck partitions: bedroom (+x) and bathroom (-x) at the front, engine room aft
    { deck = 2, kind = "wall", box = { -9.0, 0.7, -3.4, 0.9 }, h = 3.3, color = { 0.70, 0.68, 0.62 } },
    { deck = 2, kind = "wall", box = { -2.0, 0.7, 2.0, 0.9 }, h = 3.3, color = { 0.70, 0.68, 0.62 } },
    { deck = 2, kind = "wall", box = { 3.4, 0.7, 9.0, 0.9 }, h = 3.3, color = { 0.70, 0.68, 0.62 } },
    { deck = 2, kind = "wall", box = { -0.1, 0.9, 0.1, 9.0 }, h = 3.3, color = { 0.70, 0.68, 0.62 } },
    -- bedroom
    { deck = 2, kind = "bed",      box = { 3.0, 3.0, 6.0, 5.8 }, h = 0.55, color = { 0.90, 0.88, 0.80 } },
    { deck = 2, kind = "box",      box = { 1.4, 5.0, 2.4, 5.8 }, h = 0.6, color = { 0.45, 0.30, 0.20 } },
    { deck = 2, kind = "wardrobe", box = { 5.4, 1.2, 7.0, 2.2 }, h = 2.2, color = { 0.50, 0.34, 0.22 } },
    { deck = 2, kind = "rug",      box = { 1.5, 1.8, 3.4, 6.5 }, h = 0.02, color = { 0.35, 0.30, 0.55 }, solid = false },
    -- bathroom
    { deck = 2, kind = "shower",   box = { -6.4, 2.6, -4.8, 4.2 }, h = 2.2, color = { 0.6, 0.85, 1.0 } },
    { deck = 2, kind = "box",      box = { -2.7, 5.6, -2.0, 6.3 }, h = 0.45, color = { 0.95, 0.95, 0.95 } },
    { deck = 2, kind = "counter",  box = { -4.4, 1.0, -3.0, 1.6 }, h = 0.9, color = { 0.95, 0.95, 0.95 } },
    { deck = 2, kind = "tub",      box = { -5.4, 5.4, -2.6, 6.8 }, h = 0.6, color = { 0.95, 0.95, 0.98 } },
    -- engine room
    { deck = 2, kind = "engine",   circle = { 0, -1.8, 1.1 }, h = 3.3, color = { 0.3, 0.9, 1.0 } },
    { deck = 2, kind = "console",  box = { 4.4, -3.2, 6.2, -1.6 }, h = 1.2, color = { 0.30, 0.32, 0.40 } },
    { deck = 2, kind = "box",      box = { -6.6, -3.4, -4.6, -1.4 }, h = 1.6, color = { 0.45, 0.40, 0.30 } },
  },
}
