-- SPDX-License-Identifier: MIT
-- Villa interior layout (concept §3.3, v0.4), in hull-local meters: +z points
-- to the helm (forward), y is up, the hull centre is the origin. The same table
-- drives walking collision (sim/avatar.lua) and the code-generated interior
-- meshes (meshes/interior.lua), so what you see is what you bump into.
-- Furniture boxes are { x0, z0, x1, z1 } on a deck; h is the visible height.
-- solid = false means decoration you can walk through (rugs, the helm chair).
-- Rooms double as fold groups: when the saucer folds to the Seat each room
-- packs away on its own, farthest from the player first (sim/fold.lua).
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
    -- add-tractor-beam: the belly pod under the lower deck, right above the emitter
    { id = "belly", name = "Tractor deck", floor = -5.2, radius = 4.9, ceiling = -3.3 },
  },
  dome = { radius = 10.6, height = 5.6 },
  -- straight stair along x: the low end opens onto the lower deck, the high end onto the dome deck
  stairs = { low = -3.0, high = 3.5, z0 = -6.0, z1 = -4.4, steps = 12 },
  -- add-tractor-beam: a steep ship's stair from the engine room down into the
  -- belly (low = x of the bottom end, high = x of the top end; it runs inward)
  belly_stairs = { low = -3.9, high = -7.3, z0 = -3.0, z1 = -1.7, steps = 9, lo = 3, hi = 2 },
  -- the Tractor Room: a floor window (radius `window`) round the beam hatch
  -- (radius `hatch`) right over the emitter; at the console you sit in the
  -- operator's sling seat over the glass and look straight down (`eye`, `yaw`
  -- and `pitch` are hull-local and relative to the hull's heading)
  tractor = { window = 1.9, hatch = 0.7, eye = { 1.1, -4.0, 0 }, yaw = -1.5708, pitch = -1.3 },
  helm = { seat = { 0, 0.6, 7.2 }, stand = { 0, 0.6, 5.7 }, use_radius = 1.9 },
  -- you wake up in the bedroom, sitting on the edge of the bed (milestone 2)
  spawn = { pos = { 2.4, -3.0, 4.0 }, yaw = -1.5708 },
  wake = { eye = { 3.3, -1.95, 4.2 }, yaw = -0.3, pitch = 0.04 },
  -- Use spots (milestone 2): stand within `radius` of `pos` on `deck` and
  -- press Use. `kind` picks the behaviour in sim/home.lua; `label` is the HUD hint.
  stations = {
    { id = "lab",     kind = "lab",     deck = 1, pos = { -4.7, 0.6, -5.85 }, radius = 1.1, room = "Lab",
      label = "USE: LAB BENCH" },
    { id = "trade",   kind = "trade",   deck = 1, pos = { 5.4, 0.6, -5.85 }, radius = 1.1, room = "Lab",
      label = "USE: TRADE TERMINAL" },
    { id = "kitchen", kind = "kitchen", deck = 1, pos = { 6.2, 0.6, 0.0 }, radius = 1.1, room = "Kitchen",
      label = "USE: COOK A MEAL" },
    { id = "bed",     kind = "bed",     deck = 2, pos = { 2.4, -3.0, 4.0 }, radius = 1.1, room = "Bedroom",
      label = "USE: SLEEP / LOAD" },
    { id = "shower",  kind = "shower",  deck = 2, pos = { -3.9, -3.0, 3.4 }, radius = 1.0, room = "Bathroom",
      label = "USE: SHOWER" },
    { id = "engine",  kind = "engine",  deck = 2, pos = { 0.0, -3.0, -0.3 }, radius = 1.0, room = "Engine room",
      label = "USE: ENGINE CONSOLE" },
    { id = "tractor", kind = "tractor", deck = 3, pos = { 2.6, -5.2, 0.0 }, radius = 1.2, room = "Tractor room",
      label = "USE: BEAM CONSOLE" },
    -- add-holodeck-home-life: the holodeck's control panel beside its arch,
    -- the TV (watched from the sofa) and the living room bookshelf
    { id = "holodeck", kind = "holodeck", deck = 2, pos = { 3.2, -3.0, -3.15 }, radius = 1.0, room = "Engine room",
      label = "USE: HOLODECK" },
    { id = "tv",       kind = "tv",       deck = 1, pos = { -6.55, 0.6, -0.2 }, radius = 1.2, room = "Living room",
      label = "USE: WATCH TV" },
    { id = "books",    kind = "books",    deck = 1, pos = { -7.0, 0.6, -3.45 }, radius = 1.0, room = "Living room",
      label = "USE: BOOKSHELF" },
    -- add-home-among-stars: the trophy plinths either side of the helm walk,
    -- the planner (place and buy furniture) and the garden behind the stairwell
    { id = "display1", kind = "display", slot = 1, deck = 1, pos = { -4.2, 0.6, 5.3 }, radius = 0.8, room = "Living room",
      label = "USE: DISPLAY SLOT" },
    { id = "display2", kind = "display", slot = 2, deck = 1, pos = { -5.6, 0.6, 4.3 }, radius = 0.8, room = "Living room",
      label = "USE: DISPLAY SLOT" },
    { id = "display3", kind = "display", slot = 3, deck = 1, pos = { -2.6, 0.6, 6.5 }, radius = 0.8, room = "Helm",
      label = "USE: DISPLAY SLOT" },
    { id = "display4", kind = "display", slot = 4, deck = 1, pos = { 4.2, 0.6, 5.3 }, radius = 0.8, room = "Kitchen",
      label = "USE: DISPLAY SLOT" },
    { id = "display5", kind = "display", slot = 5, deck = 1, pos = { 5.4, 0.6, 4.6 }, radius = 0.6, room = "Kitchen",
      label = "USE: DISPLAY SLOT" },
    { id = "display6", kind = "display", slot = 6, deck = 1, pos = { 2.6, 0.6, 6.5 }, radius = 0.8, room = "Helm",
      label = "USE: DISPLAY SLOT" },
    { id = "planner", kind = "planner", deck = 1, pos = { -2.4, 0.6, 3.2 }, radius = 0.9, room = "Living room",
      label = "USE: HOME PLANNER" },
    -- add-dock-land-eva: the hull hatch in the aft wall of the lower deck
    { id = "hatch", kind = "hatch", deck = 2, pos = { 0.0, -3.0, -7.4 }, radius = 1.7, room = "Engine room",
      label = "USE: HULL HATCH" },
    { id = "garden", kind = "garden", deck = 1, pos = { 0.3, 0.6, -6.6 }, radius = 1.6, room = "Lab",
      label = "USE: GARDEN" },
  },
  -- add-home-among-stars: display slots (plinth centre and top), garden beds
  -- ({ x0, z0, x1, z1 }) and where furniture may not go (stair openings, the
  -- walk to the helm). See home/decor.lua for what can be placed.
  display = {
    { at = { -4.2, 6.2 }, top = 1.05 }, { at = { -6.2, 5.0 }, top = 1.05 }, { at = { -2.7, 7.5 }, top = 1.05 },
    { at = { 4.2, 6.2 }, top = 1.05 }, { at = { 6.2, 5.2 }, top = 1.05 }, { at = { 2.7, 7.5 }, top = 1.05 },
  },
  garden = {
    { box = { -2.9, -8.2, -1.6, -7.2 } }, { box = { -1.3, -8.2, 0.0, -7.2 } },
    { box = { 0.6, -8.2, 1.9, -7.2 } }, { box = { 2.2, -8.2, 3.5, -7.2 } },
  },
  keep_clear = {
    { deck = 1, box = { -1.2, 2.0, 1.6, 10 } },      -- the walk from the dome to the helm
    { deck = 1, box = { -3.2, -6.3, 4.6, -4.2 } },   -- the stairwell and its top
    { deck = 2, box = { -4.2, -6.3, 3.8, -4.2 } },
    { deck = 2, box = { -8.0, -3.4, -3.6, -1.4 } },  -- the belly stair
  },
  -- add-holodeck-home-life: where you sit or stand while doing things at home
  -- (hull-local eye, yaw relative to the hull). The holodeck's arch spans
  -- z0..z1 in its wall at x; `inside` is where you stand when a program ends.
  sofa = { eye = { -7.15, 1.72, -0.2 }, yaw = 1.5708, pitch = -0.06 },
  shelf = { eye = { -7.0, 2.2, -3.3 }, yaw = 3.1416, pitch = -0.12 },
  stove = { eye = { 6.3, 2.2, -1.2 }, yaw = 2.2, pitch = -0.55, pot = { 7.45, 1.62, -2.0 } },
  holodeck = { x = 4.0, z0 = -2.7, z1 = -1.3, inside = { 5.0, -3.0, -2.0 }, inside_yaw = -1.5708,
               room = { 4.1, -6.9, 8.6, 0.7 } },
  tv = { screen = { -3.025, 1.87, -0.2 }, w = 2.0, h = 1.1 },
  -- sliding doors on the lower-deck partitions: open on their own when a body
  -- comes within `reach` (fix-bedroom-door: and stay open until every body is
  -- past reach + door_close_margin and door_min_open seconds have gone by),
  -- solid while less than `solid_below` open
  doors = {
    { id = "bedroom",  deck = 2, box = { 2.0, 0.7, 3.4, 0.9 }, reach = 2.0, room = "Bedroom" },
    { id = "bathroom", deck = 2, box = { -3.4, 0.7, -2.0, 0.9 }, reach = 2.0, room = "Bathroom" },
  },
  door_speed = 3.0,          -- open fraction per second
  door_solid_below = 0.75,
  door_close_margin = 0.5,   -- m beyond `reach` before an open door starts to close
  door_min_open = 0.8,       -- s a door stays open once it has been triggered
  -- walking graph for scripted runs (autopilot.walk_to): hull-local points and links
  nav = {
    nodes = {
      helm = { 0, 0.6, 5.7 }, dome = { 1.0, 0.6, 2.5 }, aft = { 1.0, 0.6, -3.6 }, stair_top_in = { 4.2, 0.6, -3.6 },
      stair_top = { 4.2, 0.6, -5.2 }, stair_mid = { 3.3, 0.6, -5.2 }, stair_low = { -2.8, -3.0, -5.2 },
      stair_foot = { -3.6, -3.0, -5.2 }, engine_w = { -3.6, -3.0, -3.6 }, engine_e = { 2.7, -3.0, -3.6 },
      bed_door_s = { 2.7, -3.0, -0.4 }, bed_door_n = { 2.7, -3.0, 1.6 }, bath_door_s = { -2.7, -3.0, -0.4 },
      bath_door_n = { -2.7, -3.0, 1.6 },
      belly_top = { -7.6, -3.0, -3.5 }, belly_in = { -7.6, -3.0, -2.35 }, belly_low = { -3.6, -5.2, -2.35 },
      belly_mid = { 0.2, -5.2, -2.2 }, belly_side = { 2.6, -5.2, -1.6 }, tractor = { 2.6, -5.2, 0.0 },
      lab_in = { -4.7, 0.6, -3.6 }, trade_in = { 5.4, 0.6, -3.6 }, kitchen_in = { 6.2, 0.6, -2.6 },
      lab = { -4.7, 0.6, -5.85 }, trade = { 5.4, 0.6, -5.85 }, kitchen = { 6.2, 0.6, 0.0 },
      bed = { 2.4, -3.0, 4.0 }, shower = { -3.9, -3.0, 3.4 }, engine = { 0.0, -3.0, -0.3 }, living = { -3.2, 0.6, 1.5 },
      holodeck = { 3.2, -3.0, -3.15 }, holo_arch = { 3.3, -3.0, -2.0 }, holo_in = { 5.2, -3.0, -2.0 },
      living_s = { -6.4, 0.6, 1.5 }, tv = { -6.55, 0.6, -0.2 }, books = { -7.0, 0.6, -3.45 },
      planner = { -2.4, 0.6, 3.2 }, display1 = { -4.2, 0.6, 5.3 }, display4 = { 4.2, 0.6, 5.3 },
      display3 = { -2.6, 0.6, 6.5 }, display2 = { -5.6, 0.6, 4.3 }, display5 = { 5.4, 0.6, 4.6 }, display6 = { 2.6, 0.6, 6.5 }, trade_w = { 4.0, 0.6, -6.5 }, garden = { 0.3, 0.6, -6.6 },
      hatch_a = { -3.6, -3.0, -6.9 }, hatch = { 0.0, -3.0, -7.4 }, hatch_out = { 0.0, -3.0, -8.3 },
    },
    links = {
      { "helm", "dome" }, { "dome", "aft" }, { "dome", "living" }, { "aft", "stair_top_in" },
      { "stair_top_in", "stair_top" }, { "stair_top", "stair_mid" }, { "stair_mid", "stair_low" },
      { "stair_low", "stair_foot" }, { "stair_foot", "engine_w" }, { "engine_w", "engine_e" },
      { "engine_e", "bed_door_s" }, { "bed_door_s", "bed_door_n" }, { "bed_door_n", "bed" },
      { "engine_w", "bath_door_s" }, { "bath_door_s", "bath_door_n" }, { "bath_door_n", "shower" },
      { "bed_door_s", "engine" }, { "bath_door_s", "engine" }, { "aft", "lab_in" }, { "lab_in", "lab" }, { "aft", "trade_in" },
      { "stair_top_in", "trade_in" }, { "trade_in", "trade" }, { "aft", "kitchen_in" }, { "kitchen_in", "kitchen" },
      { "bath_door_s", "bed_door_s" },
      { "engine_w", "belly_top" }, { "belly_top", "belly_in" }, { "belly_in", "belly_low" }, { "belly_low", "belly_mid" },
      { "belly_mid", "belly_side" }, { "belly_side", "tractor" },
      { "engine_e", "holodeck" }, { "holodeck", "holo_arch" }, { "holo_arch", "holo_in" },
      { "living", "living_s" }, { "living_s", "tv" }, { "lab_in", "books" },
      { "dome", "planner" }, { "planner", "display1" }, { "dome", "display4" }, { "dome", "display3" },
      { "dome", "display6" }, { "stair_foot", "hatch_a" }, { "hatch_a", "hatch" }, { "hatch", "hatch_out" }, { "display1", "display2" }, { "display4", "display5" }, { "trade", "trade_w" }, { "trade_w", "garden" },
    },
  },
  rooms = {
    { deck = 1, name = "Helm",        box = { -3.5, 5.0, 3.5, 10 } },
    { deck = 1, name = "Kitchen",     box = { 2.5, -4.0, 10, 5.0 } },
    { deck = 1, name = "Living room", box = { -10, -4.0, -2.5, 5.0 } },
    { deck = 1, name = "Stairs",      box = { -3.0, -6.0, 3.5, -4.4 } },
    { deck = 1, name = "Lab",         box = { -10, -10, 10, -4.0 } },
    { deck = 2, name = "Stairs",      box = { -3.0, -6.0, 3.5, -4.4 } },
    { deck = 2, name = "Bedroom",     box = { 0.1, 0.9, 10, 10 } },
    { deck = 2, name = "Bathroom",    box = { -10, 0.9, -0.1, 10 } },
    { deck = 2, name = "Holodeck",    box = { 4.0, -10, 10, 0.7 } },
    { deck = 2, name = "Engine room", box = { -10, -10, 10, 0.9 } },
    { deck = 3, name = "Tractor room", box = { -10, -10, 10, 10 } },
  },
  furniture = {
    -- dome deck: helm. A low desk well below the pilot's eye line, with two
    -- angled wing screens to the sides (milestone 2: it no longer fills the view)
    { deck = 1, kind = "helm_desk", box = { -1.1, 9.1, 1.1, 9.45 }, h = 0.32, color = { 0.30, 0.32, 0.40 } },
    { deck = 1, kind = "helm_wing", box = { -2.3, 8.3, -1.7, 9.2 }, h = 0.8, color = { 0.30, 0.32, 0.40 }, side = -1 },
    { deck = 1, kind = "helm_wing", box = { 1.7, 8.3, 2.3, 9.2 }, h = 0.8, color = { 0.30, 0.32, 0.40 }, side = 1 },
    { deck = 1, kind = "chair",   box = { -0.5, 6.8, 0.5, 7.6 }, h = 1.1, color = { 0.85, 0.45, 0.20 }, solid = false },
    -- dome deck aft: the lab bench (left) and the trade terminal (right)
    { deck = 1, kind = "lab_bench", box = { -6.0, -7.4, -3.4, -6.6 }, h = 0.95, color = { 0.80, 0.82, 0.86 } },
    { deck = 1, kind = "terminal",  box = { 4.6, -7.4, 6.2, -6.6 }, h = 1.3, color = { 0.30, 0.32, 0.40 } },
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
    -- add-home-among-stars: six display plinths and the four garden beds
    { deck = 1, kind = "plinth",  box = { -4.5, 5.9, -3.9, 6.5 }, h = 1.05, color = { 0.86, 0.84, 0.80 } },
    { deck = 1, kind = "plinth",  box = { -6.5, 4.7, -5.9, 5.3 }, h = 1.05, color = { 0.86, 0.84, 0.80 } },
    { deck = 1, kind = "plinth",  box = { -3.0, 7.2, -2.4, 7.8 }, h = 1.05, color = { 0.86, 0.84, 0.80 } },
    { deck = 1, kind = "plinth",  box = { 3.9, 5.9, 4.5, 6.5 }, h = 1.05, color = { 0.86, 0.84, 0.80 } },
    { deck = 1, kind = "plinth",  box = { 5.9, 4.9, 6.5, 5.5 }, h = 1.05, color = { 0.86, 0.84, 0.80 } },
    { deck = 1, kind = "plinth",  box = { 2.4, 7.2, 3.0, 7.8 }, h = 1.05, color = { 0.86, 0.84, 0.80 } },
    { deck = 1, kind = "planter", box = { -2.9, -8.2, -1.6, -7.2 }, h = 0.5, color = { 0.42, 0.30, 0.22 } },
    { deck = 1, kind = "planter", box = { -1.3, -8.2, 0.0, -7.2 }, h = 0.5, color = { 0.42, 0.30, 0.22 } },
    { deck = 1, kind = "planter", box = { 0.6, -8.2, 1.9, -7.2 }, h = 0.5, color = { 0.42, 0.30, 0.22 } },
    { deck = 1, kind = "planter", box = { 2.2, -8.2, 3.5, -7.2 }, h = 0.5, color = { 0.42, 0.30, 0.22 } },
    { deck = 1, kind = "plant",   box = { 6.8, -5.8, 7.6, -5.0 }, h = 1.4, color = { 0.25, 0.65, 0.30 } },
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
    { deck = 2, kind = "console",  box = { -1.0, 0.12, 1.0, 0.68 }, h = 1.2, color = { 0.30, 0.32, 0.40 } },
    { deck = 2, kind = "box",      box = { -6.2, -5.6, -4.6, -4.4 }, h = 1.6, color = { 0.45, 0.40, 0.30 } },
    -- add-holodeck-home-life: the Holodeck behind its arch (starboard aft): the
    -- partition with the arch opening, the arch frame, the control panel
    { deck = 2, kind = "holo_wall", box = { 3.9, -7.4, 4.1, -2.7 }, h = 3.3, color = { 0.16, 0.16, 0.2 } },
    { deck = 2, kind = "holo_wall", box = { 3.9, -1.3, 4.1, 0.7 }, h = 3.3, color = { 0.16, 0.16, 0.2 } },
    { deck = 2, kind = "holo_arch", box = { 3.85, -2.75, 4.15, -1.25 }, h = 2.6, color = { 0.95, 0.75, 0.25 }, solid = false },
    { deck = 2, kind = "holo_panel", box = { 3.62, -3.55, 3.9, -2.8 }, h = 1.5, color = { 0.24, 0.24, 0.3 } },
    -- living room: the TV on its low stand, facing the sofa across the table
    { deck = 1, kind = "tv",       box = { -3.25, -1.3, -2.8, 0.9 }, h = 0.55, color = { 0.30, 0.22, 0.16 } },
    -- add-tractor-beam: rails round the belly stairwell (engine room, port side)
    { deck = 2, kind = "rail", box = { -7.3, -3.1, -3.9, -3.0 }, h = 1.0, color = { 0.6, 0.62, 0.7 } },
    { deck = 2, kind = "rail", box = { -7.3, -1.7, -3.9, -1.6 }, h = 1.0, color = { 0.6, 0.62, 0.7 } },
    { deck = 2, kind = "rail", box = { -4.0, -3.1, -3.9, -1.6 }, h = 1.0, color = { 0.6, 0.62, 0.7 } },
    -- the Tractor Room: the operator's sling seat out over the glass between two
    -- console arms, the cargo lift tube over the hatch, and the hold racks
    { deck = 3, kind = "beam_seat", box = { 1.2, -0.3, 1.8, 0.3 }, h = 1.0, color = { 0.85, 0.45, 0.20 }, solid = false },
    { deck = 3, kind = "beam_arm",  box = { 1.25, 0.45, 1.85, 0.75 }, h = 0.85, color = { 0.30, 0.32, 0.40 }, side = 1 },
    { deck = 3, kind = "beam_arm",  box = { 1.25, -0.75, 1.85, -0.45 }, h = 0.85, color = { 0.30, 0.32, 0.40 }, side = -1 },
    { deck = 3, kind = "cargo_tube", circle = { 0, 0, 0.7 }, h = 1.9, color = { 0.55, 0.85, 1.0 } },
    { deck = 3, kind = "hold_rack", box = { -1.5, 3.9, 1.5, 4.4 }, h = 1.8, color = { 0.36, 0.38, 0.44 } },
    { deck = 3, kind = "hold_rack", box = { -1.5, -4.4, 1.5, -3.9 }, h = 1.8, color = { 0.36, 0.38, 0.44 } },
  },
}
