-- SPDX-License-Identifier: MIT
-- Hero mesh: the Snatcher, a small duct-crawling thief (OpenSpec
-- add-mesh-builder). Code-generated, retro low-poly. Local +z is forward, y up,
-- the body is about half a metre across. The seed is the builder civ's: it
-- picks the leg joints' tilt and the colour of the sensor.
--   nodes:     claws (the front pincers; pitch opens and closes them),
--              eye (the sensor stalk; yaw sweeps it)
--   collision: a body sphere and a flat box under the belly (the same in every pose)
local kit = require("lib.meshkit")
local P = kit.part
local sm = saucer.math

local BODY, DARK, PLATE = { 0.45, 0.4, 0.5 }, { 0.22, 0.23, 0.28 }, { 0.62, 0.58, 0.68 }
local SENSE = { { 1.0, 0.95, 0.7 }, { 1.0, 0.55, 0.45 }, { 0.6, 1.0, 0.8 } }

return function(_, rng)
  local splay = 0.25 + rng:float() * 0.2
  local glow = rng:pick(SENSE)
  local parts = {}
  local function add(p) parts[#parts + 1] = p end

  -- the shell, a belly plate and a rear intake
  add(P("sphere", { c = { 0, 0, 0 }, r = 0.5, h = 0.38, seg = 10, rings = 3, color = BODY }))
  add(P("ring", { c = { 0, -0.08, 0 }, rin = 0.38, r = 0.54, h = 0.1, seg = 10, color = PLATE }))
  add(P("box", { min = { -0.22, -0.2, -0.45 }, max = { 0.22, -0.05, 0.1 }, color = DARK }))
  add(P("box", { min = { -0.14, 0.14, -0.5 }, max = { 0.14, 0.26, -0.3 }, color = DARK }))
  add(P("box", { min = { -0.1, 0.18, -0.52 }, max = { 0.1, 0.22, -0.5 }, color = glow, emissive = 0.7 }))

  -- four jointed legs: a thigh out and down, a shin that splays out to the foot
  for _, s in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
    local x, z = s[1] * 0.35, s[2] * 0.3
    add(P("box", { min = { x - 0.06, -0.4, z - 0.06 }, max = { x + 0.06, -0.02, z + 0.06 }, color = DARK }))
    add(P("box", { min = { x - 0.07, -0.5, z - 0.07 }, max = { x + 0.07, -0.38, z + 0.07 }, color = PLATE }))
    add(P("box", { min = { x * (1 + splay) - 0.05, -0.58, z * (1 + splay) - 0.05 },
                   max = { x * (1 + splay) + 0.05, -0.34, z * (1 + splay) + 0.05 }, color = DARK }))
  end

  -- the front pincers (node claws): two jaws and a lit palm
  add(P("box", { min = { -0.17, -0.1, 0.42 }, max = { 0.17, 0.08, 0.5 }, color = PLATE, node = "claws" }))
  for _, s in ipairs({ -1, 1 }) do
    add(P("box", { min = { s * 0.11 - 0.04, -0.07, 0.5 }, max = { s * 0.11 + 0.04, 0.05, 0.78 }, color = DARK, node = "claws" }))
    add(P("box", { min = { s * 0.09 - 0.02, -0.04, 0.78 }, max = { s * 0.09 + 0.02, 0.02, 0.9 }, color = PLATE, node = "claws" }))
  end

  -- the sensor stalk on top (node eye)
  add(P("cylinder", { c = { 0, 0.3, 0.1 }, r = 0.03, h = 0.2, seg = 6, color = DARK, node = "eye" }))
  add(P("box", { min = { -0.18, 0.5, 0.0 }, max = { 0.18, 0.64, 0.26 }, color = DARK, node = "eye" }))
  add(P("box", { min = { -0.12, 0.54, 0.26 }, max = { 0.12, 0.6, 0.3 }, color = glow, emissive = 1, node = "eye" }))

  return {
    parts = parts,
    nodes = {
      claws = { pivot = { 0, 0, 0.42 }, axis = "pitch" },
      eye = { pivot = { 0, 0.3, 0.1 }, axis = "yaw" },
    },
    collision = {
      { name = "body", shape = "sphere", c = { 0, 0, 0 }, r = 0.58 },
      { name = "legs", shape = "box", min = { -0.62, -0.6, -0.55 }, max = { 0.62, -0.05, 0.55 } },
    },
    budget = { tris = 700 },
  }
end
