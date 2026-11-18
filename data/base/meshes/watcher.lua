-- SPDX-License-Identifier: MIT
-- Hero mesh: the Watcher, a ceiling turret in a derelict's great halls
-- (OpenSpec add-mesh-builder). Code-generated, retro low-poly; local +z is
-- where it looks, +y is up and the ceiling plate is at y = 2.6, so the head
-- hangs about the origin. The seed is the builder civ's: it picks the number of
-- sensor fins, the bolts of the ceiling plate and the colour of the lens, so
-- every civ's Watchers look a little different and the same civ's always alike.
--   nodes:     head (turns about the vertical axis), eye (pitches, child of head)
--   collision: the head sphere, the stem and the eye's sphere; they are the same
--              for every pose, so turning or tilting a node never moves them
local kit = require("lib.meshkit")
local P = kit.part
local sm = saucer.math

local GREY, DARK, STEEL = { 0.5, 0.52, 0.58 }, { 0.22, 0.23, 0.28 }, { 0.68, 0.7, 0.76 }
local LENS = { { 1.0, 0.95, 0.7 }, { 0.7, 0.95, 1.0 }, { 1.0, 0.75, 0.7 }, { 0.8, 1.0, 0.75 } }

return function(_, rng)
  local fins, bolts = rng:int(3, 5), rng:int(6, 10)
  local glow = rng:pick(LENS)
  local parts = {}
  local function add(p) parts[#parts + 1] = p end

  -- the ceiling plate, its bolts and a three-step bellows down to the yaw collar (the fixed base)
  add(P("cylinder", { c = { 0, 2.6, 0 }, r = 1.5, h = 0.25, seg = 12, color = GREY }))
  add(P("ring", { c = { 0, 2.5, 0 }, rin = 0.4, r = 1.0, h = 0.12, seg = 12, color = DARK }))
  for k = 0, bolts - 1 do
    local a = sm.tau * k / bolts
    add(P("box", { min = { -0.07, 2.85, 1.2 }, max = { 0.07, 2.95, 1.34 }, yaw = a, color = STEEL }))
  end
  add(P("cone", { c = { 0, 1.7, 0 }, r = 0.5, r1 = 0.36, h = 0.8, seg = 8, color = DARK }))
  add(P("cone", { c = { 0, 1.1, 0 }, r = 0.36, r1 = 0.5, h = 0.6, seg = 8, color = GREY }))
  add(P("cone", { c = { 0, 0.7, 0 }, r = 0.5, r1 = 0.36, h = 0.4, seg = 8, color = DARK }))
  for k = 0, 3 do -- cable conduits down the stem
    local a = sm.tau * (k + 0.5) / 4
    add(P("box", { min = { -0.04, 0.8, 0.46 }, max = { 0.04, 2.6, 0.54 }, yaw = a, color = { 0.3, 0.32, 0.38 } }))
  end
  add(P("ring", { c = { 0, 0.62, 0 }, rin = 0.4, r = 0.78, h = 0.16, seg = 12, color = STEEL }))

  -- the head: a sphere with an equator band, sensor fins on the back and two emitter pods
  add(P("sphere", { c = { 0, 0, 0 }, r = 1.25, h = 1.25, seg = 12, rings = 3, color = GREY, node = "head" }))
  add(P("ring", { c = { 0, -0.1, 0 }, rin = 1.2, r = 1.45, h = 0.2, seg = 14, color = DARK, node = "head" }))
  add(P("ring", { c = { 0, 0.55, 0 }, rin = 0.55, r = 0.8, h = 0.1, seg = 10, color = STEEL, node = "head" }))
  for k = 0, fins - 1 do
    local a = sm.pi + (k - (fins - 1) / 2) * 0.5
    add(P("box", { min = { -0.05, 0.6, -1.65 }, max = { 0.05, 1.5, -1.0 }, yaw = a + sm.pi, color = DARK, node = "head" }))
  end
  for _, s in ipairs({ -1, 1 }) do
    add(P("box", { min = { s * 1.1 - 0.16, -0.3, -0.25 }, max = { s * 1.1 + 0.16, 0.2, 0.45 }, color = DARK, node = "head" }))
    add(P("box", { min = { s * 1.1 - 0.1, -0.15, 0.45 }, max = { s * 1.1 + 0.1, 0.05, 0.5 }, color = glow, emissive = 0.8,
                   node = "head" }))
  end

  -- the eye: a lens housing and a barrel that pitch together, a glowing iris at the front
  add(P("box", { min = { -0.5, -0.4, 0.85 }, max = { 0.5, 0.4, 1.3 }, color = DARK, node = "eye" }))
  add(P("cylinder", { c = { 0, 0, 0 }, r = 0.3, h = 0.55, seg = 8, color = STEEL, pitch = -sm.pi / 2, pos = { 0, 0, 1.3 },
                      node = "eye" }))
  add(P("ring", { c = { 0, 0, 0 }, rin = 0.26, r = 0.4, h = 0.1, seg = 8, color = DARK, pitch = -sm.pi / 2,
                  pos = { 0, 0, 1.78 }, node = "eye" }))
  add(P("box", { min = { -0.3, -0.22, 1.5 }, max = { 0.3, 0.22, 1.62 }, color = glow, emissive = 1, node = "eye" }))
  add(P("box", { min = { -0.62, -0.06, 0.95 }, max = { -0.5, 0.06, 1.2 }, color = STEEL, node = "eye" }))
  add(P("box", { min = { 0.5, -0.06, 0.95 }, max = { 0.62, 0.06, 1.2 }, color = STEEL, node = "eye" }))

  return {
    parts = parts,
    nodes = {
      head = { pivot = { 0, 0, 0 }, axis = "yaw" },
      eye = { pivot = { 0, 0, 0.95 }, parent = "head", axis = "pitch" },
    },
    collision = {
      { name = "head", shape = "sphere", c = { 0, 0, 0 }, r = 1.45 },
      { name = "stem", shape = "cylinder", c = { 0, 0.6, 0 }, r = 0.5, h = 2.3 },
      { name = "eye", shape = "sphere", c = { 0, 0, 1.25 }, r = 0.55 },
    },
    budget = { tris = 1500 },
  }
end
