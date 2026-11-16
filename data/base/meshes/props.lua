-- SPDX-License-Identifier: MIT
-- Villa detail props (OpenSpec add-detail-pass): one builder per decor kind in
-- saucer/decor.lua, plus shared helpers (tubes between two points, rotated
-- struts) used by meshes/interior.lua and meshes/saucer.lua. Pure functions of
-- their inputs: the same layout always gives the same parts and mesh hash.
local kit = require("lib.meshkit")
local sm = saucer.math
local P = kit.part
local M = {}

local function box(x0, y0, z0, x1, y1, z1, color, emissive)
  return P("box", { min = { x0, y0, z0 }, max = { x1, y1, z1 }, color = color, emissive = emissive })
end
M.box = box
local function cyl(x, y, z, r, h, seg, color, emissive)
  return P("cylinder", { c = { x, y, z }, r = r, h = h, seg = seg or 8, color = color, emissive = emissive })
end
M.cyl = cyl

-- a round tube (or a square strut when seg = 4) from point a to point b
function M.tube(a, b, r, color, seg, emissive)
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local len = sm.sqrt(dx * dx + dy * dy + dz * dz)
  local pitch = sm.atan2(sm.sqrt(dx * dx + dz * dz), dy)
  local yaw = sm.atan2(dx, dz)
  return P("cylinder", { c = { 0, 0, 0 }, r = r, h = len, seg = seg or 8, color = color, emissive = emissive,
                         pitch = pitch, yaw = yaw, pos = { a[1], a[2], a[3] } })
end
-- a flat bar from a to b: w wide (sideways), t thick (along `up`, default world y)
function M.bar(a, b, w, t, color, emissive)
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local len = sm.sqrt(dx * dx + dy * dy + dz * dz)
  local pitch = sm.atan2(sm.sqrt(dx * dx + dz * dz), dy)
  local yaw = sm.atan2(dx, dz)
  return P("box", { min = { -w / 2, 0, -t / 2 }, max = { w / 2, len, t / 2 }, color = color, emissive = emissive,
                    pitch = pitch, yaw = yaw, pos = { a[1], a[2], a[3] } })
end

local STEEL, DARK, WHITE = { 0.62, 0.66, 0.72 }, { 0.14, 0.15, 0.18 }, { 0.9, 0.88, 0.84 }
local WARM, CYAN, GREEN = { 1.0, 0.82, 0.5 }, { 0.35, 0.9, 1.0 }, { 0.3, 1.0, 0.6 }

local B = {}
M.BUILD = B

function B.stove(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + 0.95
  out[#out + 1] = box(x - 0.42, t, z - 0.6, x + 0.42, t + 0.02, z + 0.6, DARK)
  for i, p in ipairs({ { -0.2, -0.3 }, { 0.2, -0.3 }, { -0.2, 0.3 }, { 0.2, 0.3 } }) do
    out[#out + 1] = P("ring", { c = { x + p[1], t + 0.02, z + p[2] }, rin = 0.08, r = 0.15, h = 0.015, seg = 10,
                                color = i == 2 and { 1.0, 0.35, 0.15 } or { 0.35, 0.35, 0.38 }, emissive = i == 2 and 1 or nil })
  end
  -- knobs and the oven door on the front (-x) face of the counter
  for k = 0, 3 do
    out[#out + 1] = box(x - 0.53, t - 0.14, z - 0.45 + k * 0.3, x - 0.5, t - 0.08, z - 0.39 + k * 0.3, STEEL)
  end
  out[#out + 1] = box(x - 0.52, y + 0.15, z - 0.5, x - 0.5, y + 0.7, z + 0.5, { 0.08, 0.08, 0.1 }, 0.25)
  out[#out + 1] = box(x - 0.55, y + 0.62, z - 0.4, x - 0.52, y + 0.66, z + 0.4, STEEL)
end
function B.sink(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + 0.95
  out[#out + 1] = box(x - 0.35, t - 0.004, z - 0.4, x + 0.35, t + 0.006, z + 0.4, STEEL)
  out[#out + 1] = box(x - 0.28, t + 0.006, z - 0.33, x + 0.28, t + 0.008, z + 0.33, { 0.3, 0.33, 0.38 })
  out[#out + 1] = cyl(x + 0.38, t, z, 0.03, 0.32, 6, STEEL)
  out[#out + 1] = box(x + 0.12, t + 0.29, z - 0.025, x + 0.41, t + 0.33, z + 0.025, STEEL)
end
function B.cabinets(out, d, y)
  local x, z = d.at[1], d.at[2]
  local z0, z1 = -3.4, 2.4
  -- tiled backsplash from the counter top up to the cabinets
  out[#out + 1] = box(x + 0.15, y + 0.95, z0, x + 0.25, y + 1.65, z1, { 0.35, 0.58, 0.62 })
  for k = 0, 5 do
    out[#out + 1] = box(x + 0.14, y + 1.1 + k * 0.09, z0, x + 0.15, y + 1.11 + k * 0.09, z1, { 0.75, 0.8, 0.82 })
  end
  out[#out + 1] = box(x - 0.25, y + 1.65, z0, x + 0.25, y + 2.35, z1, WHITE)
  local n = 5
  for k = 0, n do
    local zz = z0 + (z1 - z0) * k / n
    out[#out + 1] = box(x - 0.27, y + 1.67, zz - 0.012, x - 0.25, y + 2.33, zz + 0.012, { 0.55, 0.52, 0.48 })
    if k < n then
      out[#out + 1] = box(x - 0.29, y + 1.72, zz + 0.1, x - 0.27, y + 1.9, zz + 0.13, STEEL)
    end
  end
  -- warm strip light under the cabinets
  out[#out + 1] = box(x - 0.2, y + 1.62, z0 + 0.1, x - 0.1, y + 1.65, z1 - 0.1, WARM, 1)
end
function B.microwave(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + 0.95
  out[#out + 1] = box(x - 0.3, t, z - 0.28, x + 0.35, t + 0.36, z + 0.28, { 0.22, 0.23, 0.26 })
  out[#out + 1] = box(x - 0.31, t + 0.06, z - 0.22, x - 0.3, t + 0.3, z + 0.08, { 0.1, 0.3, 0.25 }, 0.4)
  out[#out + 1] = box(x - 0.31, t + 0.24, z + 0.12, x - 0.3, t + 0.3, z + 0.24, GREEN, 1)
end
function B.coffee(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + 0.95
  out[#out + 1] = box(x - 0.15, t, z - 0.15, x + 0.25, t + 0.45, z + 0.15, { 0.6, 0.15, 0.12 })
  out[#out + 1] = box(x - 0.2, t + 0.3, z - 0.12, x - 0.15, t + 0.38, z + 0.12, DARK)
  out[#out + 1] = cyl(x - 0.06, t, z, 0.05, 0.1, 8, WHITE)
  out[#out + 1] = box(x - 0.16, t + 0.4, z + 0.05, x - 0.15, t + 0.43, z + 0.1, { 1, 0.3, 0.2 }, 1)
end
function B.fruit_bowl(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + 0.95
  out[#out + 1] = P("cone", { c = { x, t, z }, r = 0.1, r1 = 0.22, h = 0.09, seg = 10, color = { 0.85, 0.82, 0.75 } })
  for i, c in ipairs({ { 0.9, 0.2, 0.15 }, { 1.0, 0.6, 0.1 }, { 0.5, 0.85, 0.2 }, { 0.95, 0.85, 0.2 } }) do
    local a = i * 1.7
    out[#out + 1] = P("sphere", { c = { x + sm.sin(a) * 0.08, t + 0.12, z + sm.cos(a) * 0.08 }, r = 0.065, h = 0.065,
                                  seg = 6, rings = 2, color = c })
  end
end
function B.board(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + 0.95
  out[#out + 1] = box(x - 0.2, t, z - 0.28, x + 0.2, t + 0.025, z + 0.28, { 0.7, 0.5, 0.3 })
  out[#out + 1] = box(x - 0.02, t + 0.025, z - 0.2, x + 0.02, t + 0.035, z + 0.05, STEEL)
  out[#out + 1] = box(x - 0.025, t + 0.025, z + 0.05, x + 0.025, t + 0.045, z + 0.18, DARK)
  for k = 0, 2 do
    out[#out + 1] = box(x + 0.06, t + 0.025, z - 0.22 + k * 0.05, x + 0.14, t + 0.05, z - 0.19 + k * 0.05, { 0.95, 0.5, 0.15 })
  end
end
function B.pendant(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = cyl(x, y + 2.05, z, 0.012, 2.8, 4, DARK)
  out[#out + 1] = P("cone", { c = { x, y + 1.8, z }, r = 0.28, r1 = 0.07, h = 0.28, seg = 10, color = { 0.2, 0.45, 0.4 } })
  out[#out + 1] = P("sphere", { c = { x, y + 1.82, z }, r = 0.09, h = 0.09, seg = 6, rings = 2, color = WARM, emissive = 1 })
end
function B.fridge_dressing(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = box(x - 0.7, y + 1.25, z - 0.03, x + 0.7, y + 1.28, z, { 0.5, 0.52, 0.56 })
  out[#out + 1] = box(x + 0.25, y + 1.35, z - 0.03, x + 0.5, y + 1.48, z, { 0.2, 0.7, 1.0 }, 1)
  for i, c in ipairs({ { 1, 0.3, 0.3 }, { 1, 0.85, 0.2 }, { 0.3, 0.8, 0.4 } }) do
    out[#out + 1] = box(x - 0.5 + i * 0.14, y + 1.5 + (i % 2) * 0.12, z - 0.025, x - 0.42 + i * 0.14, y + 1.58 + (i % 2) * 0.12, z,
                        c)
  end
  out[#out + 1] = box(x - 0.3, y + 1.45, z - 0.022, x - 0.02, y + 1.72, z - 0.01, { 0.95, 0.95, 0.85 })
end
function B.pot_plant(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + (d.top or 0)
  local s = d.big and 2.2 or 1
  out[#out + 1] = P("cone", { c = { x, t, z }, r = 0.07 * s, r1 = 0.1 * s, h = 0.14 * s, seg = 8, color = { 0.75, 0.42, 0.28 } })
  for i = 0, 4 do
    local a = i * sm.tau / 5
    out[#out + 1] = P("sphere", { c = { x + sm.sin(a) * 0.06 * s, t + (0.2 + (i % 2) * 0.07) * s, z + sm.cos(a) * 0.06 * s },
                                  r = 0.08 * s, h = 0.11 * s, seg = 6, rings = 2, color = { 0.2, 0.55 + 0.05 * i, 0.25 } })
  end
end
function B.cushions(out, d, y)
  local x, z = d.at[1], d.at[2]
  local cols = { { 0.95, 0.6, 0.2 }, { 0.92, 0.88, 0.78 }, { 0.2, 0.65, 0.6 } }
  for i = 1, 3 do
    local zz = z + (i - 2) * 1.6
    out[#out + 1] = P("box", { min = { -0.1, 0, -0.33 }, max = { 0.1, 0.42, 0.33 }, color = cols[i],
                               pos = { x, y + 0.47, zz }, yaw = (i - 2) * 0.15, roll = -0.18 })
  end
  -- a plaid throw over the sofa back
  out[#out + 1] = box(x - 0.42, y + 0.5, z - 1.25, x - 0.12, y + 0.88, z - 0.55, { 0.7, 0.2, 0.2 })
  for k = 0, 2 do
    out[#out + 1] = box(x - 0.43, y + 0.5, z - 1.18 + k * 0.22, x - 0.11, y + 0.88, z - 1.12 + k * 0.22, { 0.95, 0.85, 0.6 })
  end
end
function B.floor_lamp(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = cyl(x, y, z, 0.2, 0.04, 10, DARK)
  out[#out + 1] = cyl(x, y + 0.04, z, 0.025, 1.5, 6, STEEL)
  out[#out + 1] = P("cone", { c = { x, y + 1.5, z }, r = 0.32, r1 = 0.2, h = 0.36, seg = 10, color = { 0.95, 0.85, 0.65 },
                              emissive = 0.6, open = true })
  out[#out + 1] = P("sphere", { c = { x, y + 1.62, z }, r = 0.1, h = 0.1, seg = 6, rings = 2, color = WARM, emissive = 1 })
end
function B.side_table(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = cyl(x, y, z, 0.06, 0.48, 6, { 0.45, 0.3, 0.2 })
  out[#out + 1] = cyl(x, y + 0.48, z, 0.3, 0.04, 12, { 0.55, 0.38, 0.24 })
  B.table_lamp(out, { at = { x + 0.08, z - 0.05 }, top = 0.52 }, y)
  for k = 0, 2 do
    out[#out + 1] = box(x - 0.22, y + 0.52 + k * 0.045, z - 0.05 + k * 0.02, x - 0.02, y + 0.56 + k * 0.045, z + 0.18 + k * 0.02,
                        ({ { 0.2, 0.4, 0.8 }, { 0.8, 0.3, 0.25 }, { 0.9, 0.8, 0.4 } })[k + 1])
  end
end
function B.table_lamp(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + (d.top or 0)
  out[#out + 1] = cyl(x, t, z, 0.08, 0.03, 8, DARK)
  out[#out + 1] = cyl(x, t + 0.03, z, 0.015, 0.25, 4, STEEL)
  out[#out + 1] = P("cone", { c = { x, t + 0.24, z }, r = 0.15, r1 = 0.09, h = 0.16, seg = 8, color = { 0.95, 0.85, 0.65 },
                              emissive = 0.7, open = true })
  out[#out + 1] = P("sphere", { c = { x, t + 0.3, z }, r = 0.05, h = 0.05, seg = 6, rings = 2, color = WARM, emissive = 1 })
end
function B.bookshelf(out, d, y)
  local x, z = d.at[1], d.at[2]
  local w, h, dd = 2.0, 1.9, 0.38
  local x0, x1, z0, z1 = x - w / 2, x + w / 2, z - dd / 2, z + dd / 2
  local wood = { 0.48, 0.32, 0.2 }
  out[#out + 1] = box(x0, y, z0, x0 + 0.05, y + h, z1, wood)
  out[#out + 1] = box(x1 - 0.05, y, z0, x1, y + h, z1, wood)
  out[#out + 1] = box(x0, y, z0, x1, y + h, z0 + 0.03, { 0.36, 0.24, 0.15 })
  local rng = saucer.rng.new(d.seed or 1)
  local cols = { { 0.75, 0.2, 0.2 }, { 0.2, 0.4, 0.75 }, { 0.85, 0.7, 0.3 }, { 0.3, 0.6, 0.35 }, { 0.9, 0.88, 0.8 },
                 { 0.45, 0.25, 0.55 } }
  for s = 0, 4 do
    local sy = y + 0.05 + s * 0.45
    out[#out + 1] = box(x0, sy - 0.04, z0, x1, sy, z1, wood)
    if s < 4 then
      local bx = x0 + 0.08
      while bx < x1 - 0.2 do
        local bw = 0.04 + rng:float() * 0.05
        local bh = 0.24 + rng:float() * 0.14
        if rng:int(1, 9) == 1 then
          bx = bx + 0.18 -- a gap, sometimes with a trinket in it
          if rng:int(0, 1) == 1 then
            out[#out + 1] = P("sphere", { c = { bx - 0.09, sy + 0.08, (z0 + z1) / 2 }, r = 0.07, h = 0.07, seg = 6, rings = 2,
                                          color = { 0.3, 0.7, 0.9 } })
          end
        else
          out[#out + 1] = box(bx, sy, z0 + 0.06, bx + bw, sy + bh, z1 - 0.04, cols[rng:int(1, #cols)])
          bx = bx + bw + 0.008
        end
      end
    end
  end
end
function B.holo(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + (d.top or 0.45)
  out[#out + 1] = cyl(x, t, z, 0.12, 0.04, 10, DARK)
  out[#out + 1] = P("cone", { c = { x, t + 0.04, z }, r = 0.04, r1 = 0.26, h = 0.42, seg = 10, color = CYAN, emissive = 0.6,
                              open = true })
  out[#out + 1] = P("sphere", { c = { x, t + 0.36, z }, r = 0.1, h = 0.1, seg = 8, rings = 3, color = { 0.5, 0.9, 1 },
                                emissive = 1 })
  out[#out + 1] = box(x + 0.2, t, z - 0.25, x + 0.42, t + 0.012, z - 0.05, { 0.9, 0.3, 0.35 })
  out[#out + 1] = cyl(x - 0.3, t, z + 0.3, 0.045, 0.1, 8, WHITE)
end
function B.bush(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = cyl(x, y, z, 0.32, 0.45, 10, { 0.8, 0.78, 0.72 })
  for i = 0, 6 do
    local a = i * 2.4
    local r = i == 0 and 0 or 0.25
    out[#out + 1] = P("sphere", { c = { x + sm.sin(a) * r, y + 0.85 + (i % 3) * 0.28, z + sm.cos(a) * r }, r = 0.32, h = 0.36,
                                  seg = 7, rings = 3, color = { 0.18, 0.5 + 0.04 * (i % 3), 0.24 } })
  end
end
function B.armchair_throw(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = P("box", { min = { -0.25, 0, -0.08 }, max = { 0.25, 0.4, 0.08 }, color = { 0.95, 0.75, 0.3 },
                             pos = { x - 0.2, y + 0.46, z }, yaw = 0.3, roll = -0.2 })
end
function B.helm_buttons(out, d, y)
  local z = d.at[2]
  local cols = { GREEN, { 1, 0.75, 0.25 }, CYAN, { 1, 0.3, 0.3 } }
  for k = 0, 15 do
    local x = -0.95 + k * 0.127
    out[#out + 1] = box(x, y + 0.32, z - 0.03, x + 0.07, y + 0.335, z + 0.02, cols[k % 4 + 1], (k % 3 == 0) and 1 or 0.4)
  end
  for _, s in ipairs({ -1, 1 }) do
    local x = s * 2.0
    for k = 0, 5 do
      out[#out + 1] = box(x - 0.2 + (k % 3) * 0.14, y + 0.12, 8.4 + (k // 3) * 0.12, x - 0.12 + (k % 3) * 0.14, y + 0.15,
                          8.47 + (k // 3) * 0.12, cols[(k + (s > 0 and 2 or 0)) % 4 + 1], 1)
    end
  end
end
function B.jars(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + (d.top or 0.95)
  local cols = { { 0.4, 1, 0.6 }, { 0.9, 0.5, 1 }, { 1, 0.8, 0.3 }, { 0.4, 0.8, 1 } }
  for i = 0, 3 do
    local xx = x - 1.05 + i * 0.16 + (i >= 2 and 1.7 or 0)
    out[#out + 1] = cyl(xx, t, z, 0.055, 0.2, 8, cols[i + 1], 0.5)
    out[#out + 1] = cyl(xx, t + 0.2, z, 0.06, 0.03, 8, STEEL)
  end
end
function B.crates(out, d, y)
  local x, z = d.at[1], d.at[2]
  local rng = saucer.rng.new(d.seed or 1)
  local h = 0
  for i = 1, 3 do
    local s = 0.55 - i * 0.08
    local yaw = (rng:float() - 0.5) * 0.5
    out[#out + 1] = P("box", { min = { -s / 2, 0, -s / 2 }, max = { s / 2, s, s / 2 }, color = { 0.55, 0.45, 0.3 },
                               pos = { x, y + h, z }, yaw = yaw })
    out[#out + 1] = P("box", { min = { -s / 2 - 0.01, s * 0.4, -s / 2 - 0.01 }, max = { s / 2 + 0.01, s * 0.6, s / 2 + 0.01 },
                               color = { 0.85, 0.65, 0.2 }, pos = { x, y + h, z }, yaw = yaw })
    h = h + s
  end
end
function B.terminal_text(out, d, y)
  local x, z = d.at[1], d.at[2]
  for k = 0, 4 do
    local w = 0.25 + ((k * 37) % 5) * 0.08
    out[#out + 1] = box(x - 0.6, y + 1.18 - k * 0.045, z - 0.006, x - 0.6 + w, y + 1.2 - k * 0.045, z, { 0.25, 0.12, 0.02 })
  end
end
function B.bed_dressing(out, d, y)
  local x, z = d.at[1], d.at[2]
  -- two pillows instead of one bolster, a folded throw at the foot, reading lights
  for _, s in ipairs({ -1, 1 }) do
    out[#out + 1] = P("box", { min = { -0.55, 0, -0.22 }, max = { 0.55, 0.16, 0.22 }, color = { 0.98, 0.97, 0.94 },
                               pos = { x + s * 0.7, y + 0.6, z + 0.95 }, yaw = s * 0.06, pitch = -0.15 })
    out[#out + 1] = box(x + s * 1.1 - 0.12, y + 0.85, z + 1.33, x + s * 1.1 + 0.12, y + 0.95, z + 1.36, WARM, 1)
  end
  out[#out + 1] = box(x - 1.46, y + 0.6, z - 1.3, x + 1.46, y + 0.66, z - 0.85, { 0.95, 0.75, 0.25 })
  out[#out + 1] = box(x - 1.47, y + 0.6, z - 1.15, x + 1.47, y + 0.665, z - 1.05, { 0.75, 0.3, 0.2 })
  -- duvet stripes
  for k = 0, 2 do
    out[#out + 1] = box(x - 1.46, y + 0.6, z - 0.6 + k * 0.4, x + 1.46, y + 0.605, z - 0.5 + k * 0.4, { 0.45, 0.6, 0.9 })
  end
end
function B.wardrobe_doors(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = box(x - 0.012, y + 0.05, z, x + 0.012, y + 2.15, z + 0.02, { 0.3, 0.2, 0.12 })
  for _, s in ipairs({ -1, 1 }) do
    out[#out + 1] = box(x + s * 0.08 - 0.015, y + 0.9, z, x + s * 0.08 + 0.015, y + 1.3, z + 0.05, STEEL)
  end
end
function B.painting(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = box(x, y + 1.0, z - 0.9, x + 0.04, y + 2.0, z + 0.9, { 0.75, 0.6, 0.3 })
  out[#out + 1] = box(x + 0.04, y + 1.07, z - 0.83, x + 0.05, y + 1.93, z + 0.83, { 0.06, 0.08, 0.22 })
  out[#out + 1] = P("cylinder", { c = { 0, 0, 0 }, r = 0.28, h = 0.01, seg = 12, color = { 0.95, 0.55, 0.3 }, roll = -sm.pi / 2,
                                  pos = { x + 0.05, y + 1.5, z + 0.3 } })
  out[#out + 1] = P("ring", { c = { 0, 0, 0 }, rin = 0.34, r = 0.42, h = 0.01, seg = 12, color = { 0.9, 0.85, 0.7 }, roll = -sm.pi / 2,
                              pos = { x + 0.052, y + 1.5, z + 0.3 } })
  for k = 0, 5 do
    out[#out + 1] = box(x + 0.051, y + 1.15 + (k * 0.13) % 0.7, z - 0.75 + k * 0.11, x + 0.056, y + 1.17 + (k * 0.13) % 0.7,
                        z - 0.73 + k * 0.11, { 1, 1, 0.9 }, 1)
  end
end
function B.basin(out, d, y)
  local x, z, t = d.at[1], d.at[2], y + 0.9
  out[#out + 1] = P("cone", { c = { x, t, z }, r = 0.18, r1 = 0.26, h = 0.1, seg = 12, color = { 0.97, 0.97, 0.98 } })
  out[#out + 1] = cyl(x, t + 0.1, z, 0.2, 0.004, 12, { 0.5, 0.75, 0.9 })
  out[#out + 1] = cyl(x, t, z - 0.25, 0.025, 0.25, 6, STEEL)
  out[#out + 1] = box(x - 0.02, t + 0.22, z - 0.26, x + 0.02, t + 0.25, z - 0.1, STEEL)
end
function B.mirror(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = box(x - 0.62, y + 1.15, z, x + 0.62, y + 2.05, z + 0.03, { 0.5, 0.52, 0.56 })
  out[#out + 1] = box(x - 0.56, y + 1.2, z + 0.03, x + 0.56, y + 2.0, z + 0.035, { 0.7, 0.85, 0.95 }, 0.35)
  out[#out + 1] = box(x - 0.5, y + 2.1, z, x + 0.5, y + 2.16, z + 0.06, { 1, 0.95, 0.85 }, 1)
end
function B.toilet(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = box(x + 0.32, y + 0.3, z - 0.3, x + 0.5, y + 0.8, z + 0.3, { 0.95, 0.95, 0.95 })
  out[#out + 1] = box(x - 0.35, y + 0.45, z - 0.3, x + 0.32, y + 0.5, z + 0.3, { 0.85, 0.85, 0.88 })
  out[#out + 1] = box(x + 0.4, y + 0.8, z - 0.05, x + 0.46, y + 0.82, z + 0.05, STEEL)
end
function B.towel_rail(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = box(x - 0.03, y + 1.25, z - 0.6, x + 0.03, y + 1.29, z + 0.6, STEEL)
  local cols = { { 0.3, 0.7, 0.75 }, { 0.95, 0.95, 0.9 }, { 0.95, 0.6, 0.3 } }
  for i = 1, 3 do
    local zz = z - 0.6 + i * 0.32
    out[#out + 1] = box(x - 0.07, y + 0.7 + (i % 2) * 0.1, zz - 0.13, x + 0.07, y + 1.3, zz + 0.13, cols[i])
  end
end
function B.tub_tap(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = cyl(x, y + 0.6, z, 0.03, 0.2, 6, STEEL)
  out[#out + 1] = box(x - 0.02, y + 0.76, z - 0.2, x + 0.02, y + 0.79, z, STEEL)
end
local function tiles(out, d, y, size, a, b, deckR)
  local bx = d.box
  local i = 0
  local zz = bx[2]
  while zz < bx[4] - 1e-6 do
    local xx = bx[1]
    while xx < bx[3] - 1e-6 do
      local far = sm.sqrt(math.max(xx * xx, (xx + size) ^ 2) + math.max(zz * zz, (zz + size) ^ 2))
      if far < deckR and (i + math.floor((zz - bx[2]) / size + 0.5)) % 2 == 0 then
        out[#out + 1] = box(xx + 0.02, y, zz + 0.02, xx + size - 0.02, y + 0.006, zz + size - 0.02, a)
      elseif far < deckR and b then
        out[#out + 1] = box(xx + 0.02, y, zz + 0.02, xx + size - 0.02, y + 0.004, zz + size - 0.02, b)
      end
      xx = xx + size
      i = i + 1
    end
    i = 0
    zz = zz + size
  end
end
function B.tiles(out, d, y) tiles(out, d, y, 0.8, { 0.62, 0.8, 0.85 }, nil, 8.7) end
function B.grating(out, d, y) tiles(out, d, y, 0.8, { 0.3, 0.31, 0.34 }, { 0.38, 0.39, 0.42 }, 8.7) end
function B.engine_ring(out, d, y)
  local x, z = d.at[1], d.at[2]
  for k = 0, 15 do
    local a0 = k * sm.tau / 16
    out[#out + 1] = P("box", { min = { -0.3, 0, 1.3 }, max = { 0.3, 0.012, 1.75 }, yaw = a0, pos = { x, y, z },
                               color = k % 2 == 0 and { 0.95, 0.75, 0.1 } or { 0.1, 0.1, 0.1 } })
  end
  -- piston housings either side of the core (the rods move: view/render.lua)
  for _, s in ipairs({ -1, 1 }) do
    out[#out + 1] = cyl(x + s * 1.55, y, z, 0.13, 0.9, 8, { 0.3, 0.32, 0.38 })
    out[#out + 1] = cyl(x + s * 1.55, y + 2.6, z, 0.13, 0.7, 8, { 0.3, 0.32, 0.38 })
  end
  -- glowing conduits up the core housing and a pulse window at eye height
  for k = 0, 5 do
    local a = k * sm.tau / 6 + 0.26
    out[#out + 1] = P("box", { min = { -0.05, 0, 0.98 }, max = { 0.05, 3.3, 1.06 }, yaw = a, pos = { x, y, z },
                               color = { 0.3, 0.32, 0.38 } })
  end
end
function B.pipes(out, d, y)
  local ceil = y + 3.05
  local PIPE, FL = { 0.55, 0.5, 0.4 }, { 0.75, 0.6, 0.25 }
  local runs = {
    { { 1.0, ceil, -1.8 }, { 3.6, ceil, -0.5 }, drop = true }, -- the holodeck is aft of x = 4
    { { -1.0, ceil, -1.8 }, { -8.3, ceil, -1.8 }, drop = true },
    { { 0.7, ceil - 0.3, -2.6 }, { 3.6, ceil - 0.3, -3.9 }, drop = true },
    { { -0.7, ceil - 0.3, -2.6 }, { -5.0, ceil - 0.3, -6.9 }, drop = true },
    { { 0.0, ceil - 0.15, -0.7 }, { 0.0, ceil - 0.15, 0.6 } },
  }
  for _, r in ipairs(runs) do
    local a, b = r[1], r[2]
    out[#out + 1] = M.tube(a, b, 0.11, PIPE, 8)
    local dx, dz = b[1] - a[1], b[3] - a[3]
    local len = sm.sqrt(dx * dx + dz * dz)
    local n = math.floor(len / 1.4)
    for k = 1, n do
      local t = k / (n + 1)
      local p = { a[1] + dx * t, a[2], a[3] + dz * t }
      local q = { a[1] + dx * (t + 0.03), a[2], a[3] + dz * (t + 0.03) }
      out[#out + 1] = M.tube(p, q, 0.15, FL, 8)
    end
    if r.drop then
      out[#out + 1] = M.tube({ b[1], y, b[3] }, b, 0.11, PIPE, 8)
      out[#out + 1] = P("sphere", { c = b, r = 0.14, h = 0.14, seg = 8, rings = 2, color = FL })
      -- a valve wheel at hand height
      out[#out + 1] = P("ring", { c = { 0, 0, 0 }, rin = 0.17, r = 0.22, h = 0.04, seg = 10, color = { 0.85, 0.2, 0.15 },
                                  pos = { b[1], y + 1.3, b[3] } })
    end
  end
  -- cable tray along the ceiling, from the core to the stairs
  out[#out + 1] = box(-2.6, ceil + 0.08, -4.15, 3.2, ceil + 0.14, -3.8, { 0.4, 0.42, 0.46 })
  for k = 0, 3 do
    out[#out + 1] = box(-2.6, ceil + 0.03, -4.12 + k * 0.08, 3.2, ceil + 0.07, -4.08 + k * 0.08,
                        ({ { 0.8, 0.2, 0.2 }, { 0.2, 0.5, 0.9 }, { 0.9, 0.8, 0.2 }, { 0.2, 0.2, 0.2 } })[k + 1])
  end
end
function B.tank(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = cyl(x, y, z, 0.48, 2.2, 12, { 0.5, 0.6, 0.65 })
  out[#out + 1] = P("hemisphere", { c = { x, y + 2.2, z }, r = 0.48, h = 0.25, seg = 12, rings = 2, color = { 0.5, 0.6, 0.65 } })
  for k = 0, 2 do
    out[#out + 1] = cyl(x, y + 0.3 + k * 0.75, z, 0.5, 0.06, 12, { 0.3, 0.32, 0.36 })
  end
  -- a gauge window showing the coolant level
  local a = sm.atan2(-x, -z)
  out[#out + 1] = P("box", { min = { -0.08, 0.4, 0.47 }, max = { 0.08, 1.9, 0.52 }, yaw = a, pos = { x, y, z },
                             color = { 0.05, 0.1, 0.12 } })
  out[#out + 1] = P("box", { min = { -0.05, 0.45, 0.5 }, max = { 0.05, 1.45, 0.53 }, yaw = a, pos = { x, y, z },
                             color = CYAN, emissive = 1 })
  out[#out + 1] = M.tube({ x, y + 2.4, z }, { x, y + 3.3, z }, 0.08, { 0.55, 0.5, 0.4 }, 6)
end
function B.battery_bars(out, d, y)
  local x, z = d.at[1], d.at[2]
  for k = 0, 4 do
    out[#out + 1] = box(x, y + 0.25 + k * 0.25, z - 0.6, x + 0.02, y + 0.4 + k * 0.25, z + 0.6,
                        k < 4 and GREEN or { 0.2, 0.25, 0.2 }, k < 4 and 1 or 0)
  end
  out[#out + 1] = box(x, y + 1.45, z - 0.2, x + 0.02, y + 1.55, z + 0.2, { 1, 0.3, 0.2 }, 1)
  out[#out + 1] = M.tube({ x - 1.0, y + 1.6, z - 0.4 }, { x - 1.0, y + 3.3, z - 0.4 }, 0.05, DARK, 6)
  out[#out + 1] = M.tube({ x - 0.6, y + 1.6, z + 0.4 }, { x - 0.6, y + 3.3, z + 0.4 }, 0.05, { 0.8, 0.2, 0.2 }, 6)
end
function B.monitor(out, d, y)
  local x, z = d.at[1], d.at[2]
  out[#out + 1] = box(x - 0.8, y + 1.2, z - 0.06, x + 0.8, y + 2.0, z + 0.04, DARK)
  out[#out + 1] = box(x - 0.74, y + 1.26, z - 0.07, x + 0.74, y + 1.94, z - 0.06, { 0.02, 0.08, 0.06 }, 0.6)
  for k = 0, 9 do
    local h = 0.1 + ((k * 53) % 7) * 0.06
    out[#out + 1] = box(x - 0.68 + k * 0.13, y + 1.32, z - 0.075, x - 0.6 + k * 0.13, y + 1.32 + h, z - 0.07, GREEN, 1)
  end
  out[#out + 1] = box(x - 0.68, y + 1.8, z - 0.075, x + 0.2, y + 1.84, z - 0.07, { 1, 0.75, 0.3 }, 1)
  out[#out + 1] = box(x - 0.05, y + 0.85, z - 0.02, x + 0.05, y + 1.2, z + 0.02, STEEL)
end

-- parts for one decor entry (unknown kinds draw nothing)
function M.build(out, d, y)
  local b = B[d.kind]
  if b then b(out, d, y) end
  return out
end

return M
