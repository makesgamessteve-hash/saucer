-- SPDX-License-Identifier: MIT
-- Small 3-vector helpers. Vectors are plain {x, y, z} arrays so they serialize.
local sm = saucer.math
local M = {}

function M.new(x, y, z) return { x or 0, y or 0, z or 0 } end
function M.copy(a) return { a[1], a[2], a[3] } end
function M.add(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
function M.sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
function M.scale(a, s) return { a[1] * s, a[2] * s, a[3] * s } end
function M.dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
function M.len(a) return sm.sqrt(M.dot(a, a)) end
function M.dist(a, b) return M.len(M.sub(a, b)) end
function M.norm(a)
  local l = M.len(a)
  if l == 0 then return { 0, 0, 0 } end
  return M.scale(a, 1 / l)
end
-- yaw 0 faces +z; positive yaw turns toward +x.
function M.fwd(yaw) return { sm.sin(yaw), 0, sm.cos(yaw) } end
function M.right(yaw) return { -sm.cos(yaw), 0, sm.sin(yaw) } end
-- full aim direction from yaw and pitch (pitch > 0 looks up)
function M.aim(yaw, pitch)
  local cp = sm.cos(pitch)
  return { sm.sin(yaw) * cp, sm.sin(pitch), sm.cos(yaw) * cp }
end
function M.clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end
-- axis-aligned box overlap for saucer hulls: center, radius, half height
function M.hulls_overlap(pa, ra, ha, pb, rb, hb, margin)
  margin = margin or 0
  return math.abs(pa[1] - pb[1]) < ra + rb + margin and math.abs(pa[2] - pb[2]) < ha + hb + margin
    and math.abs(pa[3] - pb[3]) < ra + rb + margin
end

return M
