-- SPDX-License-Identifier: MIT
-- Mesh recipe toolkit (concept §11.8). A recipe is { parts = {...} } where each
-- part is a primitive understood by saucer.mesh.build: box, wedge, cylinder,
-- cone, sphere, hemisphere, ring, lathe, extrude. Operations here combine and
-- transform part lists; everything is deterministic so mesh hashes are stable.
local data = require("lib.data")
local sm = saucer.math
local M = {}

local function copy(t)
  local r = {}
  for k, v in pairs(t) do
    if type(v) == "table" then r[k] = copy(v) else r[k] = v end
  end
  return r
end
M.copy = copy

function M.part(kind, t)
  local p = copy(t or {})
  p.kind = kind
  return p
end

function M.merge(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, p in ipairs(list) do out[#out + 1] = p end
  end
  return out
end

-- transform(parts, {pos=, yaw=, scale=}) -> new parts (yaw-only parent rotation)
function M.transform(parts, xf)
  local out = {}
  local yaw = xf.yaw or 0
  local s = xf.scale or 1
  local o = xf.pos or { 0, 0, 0 }
  local c, sn = sm.cos(yaw), sm.sin(yaw)
  for _, src in ipairs(parts) do
    local p = copy(src)
    local pp = p.pos or { 0, 0, 0 }
    local x, y, z = pp[1] * s, pp[2] * s, pp[3] * s
    p.pos = { x * c + z * sn + o[1], y + o[2], -x * sn + z * c + o[3] }
    p.yaw = (p.yaw or 0) + yaw
    if s ~= 1 then
      local sc = p.scale or { 1, 1, 1 }
      p.scale = { sc[1] * s, sc[2] * s, sc[3] * s }
    end
    out[#out + 1] = p
  end
  return out
end

-- mirror(parts, "x"|"z") -> originals plus mirrored copies
function M.mirror(parts, axis)
  local out = M.merge(parts)
  local i = axis == "z" and 3 or 1
  for _, src in ipairs(parts) do
    local p = copy(src)
    p.pos = p.pos or { 0, 0, 0 }
    p.pos[i] = -p.pos[i]
    p.yaw = -(p.yaw or 0)
    out[#out + 1] = p
  end
  return out
end

function M.radial_array(parts, n, phase)
  local out = {}
  for k = 0, n - 1 do
    out = M.merge(out, M.transform(parts, { yaw = (phase or 0) + sm.tau * k / n }))
  end
  return out
end

function M.linear_array(parts, n, step)
  local out = {}
  for k = 0, n - 1 do
    out = M.merge(out, M.transform(parts, { pos = { step[1] * k, step[2] * k, step[3] * k } }))
  end
  return out
end

-- recipe(id, params, seed) -> recipe table from data/base/meshes/<id>.lua
function M.recipe(id, params, seed)
  local fn = data.load("meshes/" .. id .. ".lua")
  local r = fn(params or {}, saucer.rng.new(seed or 1))
  if type(r) ~= "table" or type(r.parts) ~= "table" then error("mesh recipe " .. id .. " returned no parts") end
  return r
end

-- build(id, params, seed) -> mesh id, hash
function M.build(id, params, seed)
  return saucer.mesh.build(M.recipe(id, params, seed))
end

return M
