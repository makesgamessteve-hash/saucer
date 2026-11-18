-- SPDX-License-Identifier: MIT
-- Collision volumes declared by mesh recipes (OpenSpec add-mesh-builder,
-- "Declared collision and named nodes"). A recipe lists its shapes in the
-- recipe's own frame (+z forward, +y up); the sim places them with a pose
-- { pos = {x, y, z}, yaw = a } and asks distances. Only these shapes are ever
-- used for collision, never the render geometry. Pure functions: no state.
--   { shape = "sphere",   c = {x, y, z}, r = r }
--   { shape = "box",      min = {x, y, z}, max = {x, y, z} }
--   { shape = "cylinder", c = {x, y, z} (base centre), r = r, h = height }   (vertical axis)
local sm = saucer.math
local M = {}

M.SHAPES = { sphere = true, box = true, cylinder = true }

-- a world point in the recipe's frame
local function localize(xf, p)
  local o, yaw = xf.pos or { 0, 0, 0 }, xf.yaw or 0
  local dx, dy, dz = p[1] - o[1], p[2] - o[2], p[3] - o[3]
  if yaw == 0 then return dx, dy, dz end
  local c, s = sm.cos(yaw), sm.sin(yaw)
  return c * dx - s * dz, dy, s * dx + c * dz
end
M.localize = localize

local function sq(a) return a * a end
local function clampd(v, lo, hi) if v < lo then return lo - v elseif v > hi then return v - hi end return 0 end

-- distance from point p to the surface of one volume (0 when inside)
function M.dist(vol, xf, p)
  local x, y, z = localize(xf, p)
  local sh = vol.shape
  if sh == "sphere" then
    local c = vol.c
    local d = sm.sqrt(sq(x - c[1]) + sq(y - c[2]) + sq(z - c[3])) - vol.r
    return d > 0 and d or 0
  elseif sh == "box" then
    local dx, dy, dz = clampd(x, vol.min[1], vol.max[1]), clampd(y, vol.min[2], vol.max[2]), clampd(z, vol.min[3], vol.max[3])
    return sm.sqrt(dx * dx + dy * dy + dz * dz)
  elseif sh == "cylinder" then
    local c = vol.c
    local radial = sm.sqrt(sq(x - c[1]) + sq(z - c[3])) - vol.r
    if radial < 0 then radial = 0 end
    local dy = clampd(y, c[2], c[2] + vol.h)
    return sm.sqrt(radial * radial + dy * dy)
  end
  error("unknown collision shape " .. tostring(sh))
end

-- nearest volume of a list -> distance, index (nil, nil for an empty list)
function M.nearest(vols, xf, p)
  local best, bi
  for i, v in ipairs(vols or {}) do
    local d = M.dist(v, xf, p)
    if not best or d < best then best, bi = d, i end
  end
  return best, bi
end

function M.inside(vols, xf, p)
  local d = M.nearest(vols, xf, p)
  return d ~= nil and d <= 0
end

-- a list's volumes must be well formed: known shapes, finite positive sizes
function M.check(vols)
  for i, v in ipairs(vols or {}) do
    if not M.SHAPES[v.shape] then return false, "volume " .. i .. ": unknown shape " .. tostring(v.shape) end
    if v.shape == "box" then
      for k = 1, 3 do
        if not (v.min and v.max and v.min[k] < v.max[k]) then return false, "volume " .. i .. ": empty box" end
      end
    else
      if not (v.c and v.r and v.r > 0) then return false, "volume " .. i .. ": no radius" end
      if v.shape == "cylinder" and not (v.h and v.h > 0) then return false, "volume " .. i .. ": no height" end
    end
  end
  return true
end

-- the box that holds a whole list -> min, max (nil for an empty list)
function M.bounds(vols)
  local mn, mx
  for _, v in ipairs(vols or {}) do
    local a, b
    if v.shape == "box" then a, b = v.min, v.max
    elseif v.shape == "sphere" then
      a = { v.c[1] - v.r, v.c[2] - v.r, v.c[3] - v.r }
      b = { v.c[1] + v.r, v.c[2] + v.r, v.c[3] + v.r }
    else
      a = { v.c[1] - v.r, v.c[2], v.c[3] - v.r }
      b = { v.c[1] + v.r, v.c[2] + v.h, v.c[3] + v.r }
    end
    if not mn then mn, mx = { a[1], a[2], a[3] }, { b[1], b[2], b[3] }
    else
      for k = 1, 3 do
        if a[k] < mn[k] then mn[k] = a[k] end
        if b[k] > mx[k] then mx[k] = b[k] end
      end
    end
  end
  return mn, mx
end

return M
