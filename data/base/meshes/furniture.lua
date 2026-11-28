-- SPDX-License-Identifier: MIT
-- Hero meshes for the dome-home (OpenSpec add-home-among-stars): one recipe
-- per furniture `look` in home/decor.lua (centred on the origin, on the floor,
-- facing +z, sized by the piece's size and height), the garden's plants per
-- growth stage, and the small trophy that stands for a displayed find.
-- Pure functions of their inputs: the same def always gives the same mesh.
local props = require("lib.data").load("meshes/props.lua")
local kit = require("lib.meshkit")
local P = kit.part
local box, cyl = props.box, props.cyl
local M = {}

local function darker(c, f) return { c[1] * f, c[2] * f, c[3] * f } end
local WARM, DARK, STEEL, GLASS = { 1.0, 0.85, 0.55 }, { 0.16, 0.16, 0.2 }, { 0.62, 0.66, 0.72 }, { 0.55, 0.85, 1.0 }

local LOOK = {}
function LOOK.lamp(d)
  return { cyl(0, 0, 0, 0.22, 0.05, 10, DARK), cyl(0, 0.05, 0, 0.03, d.h - 0.4, 6, STEEL),
           P("cone", { c = { 0, d.h - 0.4, 0 }, r = 0.28, r1 = 0.14, h = 0.35, seg = 10, color = d.color, emissive = 0.8 }) }
end
function LOOK.blob(d)
  local w = d.size[1] / 2
  return { P("sphere", { c = { 0, 0.32, 0 }, r = w, h = 0.34, seg = 10, rings = 4, color = d.color }) }
end
function LOOK.chair(d)
  local w, dd = d.size[1] / 2, d.size[2] / 2
  return { box(-w, 0, -dd, w, 0.42, dd, d.color), box(-w, 0.42, -dd, w, d.h, -dd + 0.2, darker(d.color, 0.85)),
           box(-w, 0.42, -dd, -w + 0.15, 0.65, dd, darker(d.color, 0.9)), box(w - 0.15, 0.42, -dd, w, 0.65, dd, darker(d.color, 0.9)) }
end
function LOOK.rug(d)
  return { cyl(0, 0, 0, d.size[1] / 2, 0.02, 16, d.color), cyl(0, 0.005, 0, d.size[1] / 2 - 0.25, 0.02, 16, darker(d.color, 1.3)) }
end
function LOOK.case(d)
  local w, dd = d.size[1] / 2, d.size[2] / 2
  local out = { box(-w, 0, -dd, w, d.h, -dd + 0.04, d.color), box(-w, 0, -dd, -w + 0.04, d.h, dd, d.color),
                box(w - 0.04, 0, -dd, w, d.h, dd, d.color) }
  for k = 0, 4 do
    local y = k * (d.h - 0.04) / 4
    out[#out + 1] = box(-w, y, -dd, w, y + 0.04, dd, d.color)
    if k < 4 then
      for b = 0, 5 do
        local x = -w + 0.08 + b * (2 * w - 0.16) / 6
        local col = ({ { 0.7, 0.2, 0.2 }, { 0.2, 0.4, 0.7 }, { 0.8, 0.7, 0.3 }, { 0.3, 0.6, 0.35 } })[(b + k) % 4 + 1]
        out[#out + 1] = box(x, y + 0.04, -dd + 0.06, x + 0.12, y + 0.3 + (b % 2) * 0.06, dd - 0.04, col)
      end
    end
  end
  return out
end
function LOOK.tank(d)
  local w, dd = d.size[1] / 2, d.size[2] / 2
  local out = { box(-w, 0, -dd, w, 0.55, dd, DARK),
                box(-w + 0.03, 0.55, -dd + 0.03, w - 0.03, d.h - 0.05, dd - 0.03, d.color, 0.5),
                box(-w, d.h - 0.05, -dd, w, d.h, dd, DARK) }
  for k = 0, 3 do
    out[#out + 1] = box(-w + 0.25 + k * 0.28, 0.75 + (k % 2) * 0.18, -0.05, -w + 0.37 + k * 0.28, 0.83 + (k % 2) * 0.18,
                        0.05, { 1.0, 0.55 + k * 0.1, 0.2 }, 0.8)
  end
  return out
end
function LOOK.scope(d)
  local out = {}
  for k = 0, 2 do
    local a = k * 2.0944
    out[#out + 1] = props.tube({ 0, 0, 0 }, { saucer.math.sin(a) * 0.3, 0, saucer.math.cos(a) * 0.3 }, 0.02, d.color, 4)
    out[#out + 1] = props.tube({ saucer.math.sin(a) * 0.3, 0, saucer.math.cos(a) * 0.3 }, { 0, 1.0, 0 }, 0.025, d.color, 6)
  end
  out[#out + 1] = props.tube({ 0, 0.95, -0.35 }, { 0, 1.45, 0.45 }, 0.09, d.color, 10)
  out[#out + 1] = props.tube({ 0, 1.42, 0.4 }, { 0, 1.5, 0.52 }, 0.1, GLASS, 10, 0.6)
  return out
end
function LOOK.hammock(d)
  local w = d.size[1] / 2
  return { props.tube({ -w, 0, 0 }, { -w, d.h, 0 }, 0.05, STEEL, 6), props.tube({ w, 0, 0 }, { w, d.h, 0 }, 0.05, STEEL, 6),
           props.bar({ -w + 0.05, d.h - 0.1, 0 }, { 0, 0.55, 0 }, 0.8, 0.04, d.color),
           props.bar({ 0, 0.55, 0 }, { w - 0.05, d.h - 0.1, 0 }, 0.8, 0.04, d.color) }
end
function LOOK.poster(d)
  local w, h = d.size[1] / 2, d.h
  return { box(-w, 0, -0.02, w, h, 0.02, d.color),
           box(-w + 0.04, 0.08, -0.025, w - 0.04, h - 0.08, -0.01, darker(d.color, 1.2)) }
end
function LOOK.hang(d)
  local r = d.size[1] / 2
  return { cyl(0, d.h - 0.08, 0, 0.03, 0.08, 8, STEEL),
           P("cone", { c = { 0, 0.1, 0 }, r = r, r1 = r * 0.4, h = d.h - 0.2, seg = 10, color = d.color, emissive = 0.7 }),
           P("sphere", { c = { 0, 0.12, 0 }, r = r * 0.35, h = 0.12, seg = 8, rings = 3, color = WARM, emissive = 1 }) }
end
function LOOK.figure(d)
  local r = d.size[1] / 2
  return { cyl(0, 0, 0, r * 1.1, 0.03, 8, DARK),
           P("sphere", { c = { 0, 0.1, 0 }, r = r * 0.7, h = 0.08, seg = 8, rings = 3, color = d.color }),
           P("cone", { c = { 0, 0.16, 0 }, r = r * 0.45, r1 = 0.01, h = d.h - 0.16, seg = 6, color = darker(d.color, 0.85) }) }
end
function LOOK.crystal(d)
  return { cyl(0, 0, 0, 0.28, 0.12, 8, DARK),
           P("cone", { c = { 0, 0.12, 0 }, r = 0.18, r1 = 0, h = d.h - 0.12, seg = 6, color = d.color, emissive = 0.9 }),
           P("cone", { c = { 0.12, 0.12, 0.05 }, r = 0.08, r1 = 0, h = 0.6, seg = 5, color = d.color, emissive = 0.9 }),
           P("cone", { c = { -0.1, 0.12, -0.08 }, r = 0.07, r1 = 0, h = 0.45, seg = 5, color = d.color, emissive = 0.9 }) }
end
M.LOOK = LOOK

function M.furniture(def)
  local f = LOOK[def.look] or function(d)
    local w, dd = d.size[1] / 2, d.size[2] / 2
    return { box(-w, 0, -dd, w, d.h, dd, d.color) }
  end
  return { parts = f(def) }
end

-- a plant on a bed at growth stage 1..4 (1 = seed: a few dots of green)
function M.plant(seed, stage)
  local c = seed.color
  local out = {}
  if stage <= 1 then
    for k = 0, 2 do out[#out + 1] = box(-0.2 + k * 0.2, 0, -0.03, -0.16 + k * 0.2, 0.05, 0.01, { 0.35, 0.7, 0.3 }) end
    return { parts = out }
  end
  local h = ({ 0.25, 0.55, 0.8 })[stage - 1]
  for k = 0, 2 do
    local x = -0.35 + k * 0.35
    out[#out + 1] = P("cone", { c = { x, 0, 0 }, r = 0.14, r1 = 0, h = h, seg = 6, color = { 0.3, 0.7, 0.35 } })
    if stage >= 3 then
      out[#out + 1] = P("sphere", { c = { x, h * 0.85, 0 }, r = 0.09 + (stage - 3) * 0.04, h = 0.08, seg = 6, rings = 2,
                                    color = c, emissive = seed.look == "moss" and 0.9 or 0.3 })
    end
  end
  return { parts = out }
end

-- the trophy standing for a displayed find (tinted per category by the view)
function M.trophy()
  return { parts = {
    P("sphere", { c = { 0, 0.22, 0 }, r = 0.16, h = 0.16, seg = 8, rings = 3, color = { 1, 1, 1 }, emissive = 0.4 }),
    P("cone", { c = { 0, 0, 0 }, r = 0.12, r1 = 0.05, h = 0.1, seg = 6, color = { 0.8, 0.8, 0.85 } }),
    box(-0.03, 0.3, -0.03, 0.03, 0.5, 0.03, { 1, 1, 1 }, 0.6),
  } }
end

return M
