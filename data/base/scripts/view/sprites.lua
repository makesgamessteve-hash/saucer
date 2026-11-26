-- SPDX-License-Identifier: MIT
-- replace-bubble-sprites: each former bubble/orb billboard is drawn as a form that fits what
-- it is (a flare for a light, a shard for a mote, a ring for an echo, and so on). The forms
-- are procedural in the renderer (cheap on WebGL2; no palette texels).
local vec = require("lib.vec")
local sm = saucer.math
local M = {}

M.FORMS = { "disk", "flare", "spark", "ring", "shard", "streak", "chevron", "slit" }

-- a known form name? (the renderer ignores an unknown string and would fall back to a disk)
function M.is_form(name)
  for _, f in ipairs(M.FORMS) do if f == name then return true end end
  return false
end

local function tex(A)
  return A and A.tex and (A.tex.glow or A.tex.beam)
end

-- draw a procedural form at pos, size (and optional opts.height, tint, palette, sky, yaxis)
function M.draw(v, A, form, pos, size, opts)
  if not v or not form or not pos or not M.is_form(form) then return 0 end
  local t = tex(A)
  if not t then return 0 end
  opts = opts or {}
  opts.form = form
  opts.palette = opts.palette or (A.pal and A.pal.base)
  v:billboard(t, pos, size, opts)
  return 1
end

function M.light(v, A, pos, size, opts) return M.draw(v, A, "flare", pos, size, opts) end
function M.spark(v, A, pos, size, opts) return M.draw(v, A, "spark", pos, size, opts) end
function M.ring(v, A, pos, size, opts) return M.draw(v, A, "ring", pos, size, opts) end
function M.shard(v, A, pos, size, opts) return M.draw(v, A, "shard", pos, size, opts) end
function M.streak(v, A, pos, size, opts) return M.draw(v, A, "streak", pos, size, opts) end
function M.mark(v, A, pos, size, opts) return M.draw(v, A, "chevron", pos, size, opts) end
function M.slit(v, A, pos, size, opts) return M.draw(v, A, "slit", pos, size, opts) end

-- a thin emissive rod, used for a pulse travelling along a lane (aligned with `dir`)
local streak_mesh
function M.streak_mesh()
  if not streak_mesh then
    streak_mesh = saucer.mesh.build({ parts = {
      { kind = "box", min = { -0.2, -0.2, -1 }, max = { 0.2, 0.2, 1 }, color = { 1, 1, 1 }, emissive = 0.9 },
    } })
  end
  return streak_mesh
end

function M.bolt(v, A, pos, dir, len, tint)
  if not dir or not len or len < 0.1 then return 0 end
  local d = dir
  local l = vec.len(d)
  if l < 1e-4 then return 0 end
  d = vec.scale(d, 1 / l)
  local yaw = sm.atan2(d[1], d[3])
  local pitch = -sm.atan2(d[2], math.sqrt(d[1] * d[1] + d[3] * d[3]))
  v:mesh(M.streak_mesh(), { pos = pos, scale = { math.max(0.8, len * 0.06), math.max(0.8, len * 0.06), len * 0.5 },
                            yaw = yaw, pitch = pitch, ghost = true, tint = tint or { 1, 1, 1, 1 } })
  return 1
end

-- a flat disc on the floor: a sentry's pool of light (not a standing bubble)
local pool_mesh
function M.pool_mesh()
  if not pool_mesh then
    pool_mesh = saucer.mesh.build({ parts = {
      { kind = "cylinder", c = { 0, 0, 0 }, r = 1, h = 0.04, seg = 16, color = { 1, 1, 1 }, emissive = 0.7 },
    } })
  end
  return pool_mesh
end

function M.pool(v, A, pos, radius, tint)
  if not pos or not radius or radius <= 0 then return 0 end
  v:mesh(M.pool_mesh(), { pos = pos, scale = { radius, 1, radius }, ghost = true, tint = tint or { 1, 1, 1, 0.4 } })
  return 1
end

-- a tall dark figure (a hall's "shadow" phenomenon), not a dark bubble
local shade_mesh
function M.shade_mesh()
  if not shade_mesh then
    shade_mesh = saucer.mesh.build({ parts = {
      { kind = "box", min = { -0.35, 0, -0.18 }, max = { 0.35, 1.55, 0.18 }, color = { 0.03, 0.01, 0.04 } },
      { kind = "sphere", c = { 0, 1.75, 0 }, r = 0.28, h = 0.28, seg = 8, rings = 4, color = { 0.03, 0.01, 0.04 } },
    } })
  end
  return shade_mesh
end

function M.shade(v, A, pos, size, alpha)
  if not pos then return 0 end
  local s = size or 1
  v:mesh(M.shade_mesh(), { pos = pos, scale = s, ghost = true,
                           tint = { 0.02, 0.0, 0.03, math.max(0, math.min(1, alpha or 0.7)) } })
  return 1
end

-- a thin ring lying on the floor (a ripple)
local ring_mesh
function M.ring_mesh()
  if not ring_mesh then
    ring_mesh = saucer.mesh.build({ parts = {
      { kind = "ring", c = { 0, 0, 0 }, rin = 0.86, r = 1.0, h = 0.06, seg = 24, color = { 1, 1, 1 }, emissive = 0.8 },
    } })
  end
  return ring_mesh
end

function M.ripple(v, A, pos, radius, tint)
  if not pos or not radius or radius <= 0 then return 0 end
  v:mesh(M.ring_mesh(), { pos = pos, scale = radius, ghost = true, tint = tint or { 0.8, 0.5, 1.0, 0.45 } })
  return 1
end

return M
