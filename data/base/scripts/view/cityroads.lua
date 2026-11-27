-- SPDX-License-Identifier: MIT
-- add-generated-planets: curved ring roads and radial avenues that make a
-- concentric city read as rings from the air. View-only (lots keep their
-- rectangular collision); built once per ruin and cached.
local citygen = require("sim.citygen")

local M = {}
local caches = setmetatable({}, { __mode = "k" })

local ASPHALT = { 0.42, 0.40, 0.36 }
local EDGE = { 0.92, 0.82, 0.35 }
local PLAZA = { 0.42, 0.40, 0.38 }

function M.parts(ruin, kit, origin)
  local fp, radii = citygen.ring_world_radii(kit, origin)
  if not fp then return {} end
  local y = (ruin.city and ruin.city.districts[1] and ruin.city.districts[1].pos[2]) or origin[2]
  -- a low deck just above the street so lots stay walkable
  local y0 = y + 1.1
  local parts = {}
  -- the centre plaza: a wide paved disk
  local inner = (radii[1] or 400) * 0.45
  if inner < 80 then inner = 80 end
  parts[#parts + 1] = {
    kind = "cylinder", c = { fp.x, y0, fp.z }, r = inner, h = 0.45, seg = 48,
    color = PLAZA, emissive = 0.04,
  }
  -- a small ring at the plaza rim
  parts[#parts + 1] = {
    kind = "ring", c = { fp.x, y0 + 0.2, fp.z }, rin = inner - 6, r = inner + 2, h = 0.35, seg = 48,
    color = EDGE, emissive = 0.85,
  }
  local width = 36
  for i, R in ipairs(radii) do
    if R > inner + 40 then
      parts[#parts + 1] = {
        kind = "ring", c = { fp.x, y0 + 0.15, fp.z }, rin = R - width, r = R + width, h = 0.5, seg = 64,
        color = ASPHALT, emissive = 0.18,
      }
      parts[#parts + 1] = {
        kind = "ring", c = { fp.x, y0 + 0.4, fp.z }, rin = R - width - 1.2, r = R - width + 1.0, h = 0.2, seg = 64,
        color = EDGE, emissive = 0.9,
      }
      parts[#parts + 1] = {
        kind = "ring", c = { fp.x, y0 + 0.4, fp.z }, rin = R + width - 1.0, r = R + width + 1.2, h = 0.2, seg = 64,
        color = EDGE, emissive = 0.9,
      }
    end
  end
  -- eight radial avenues: a long box along +z, yawed around the city centre
  local outer = radii[#radii] or (fp.r * 0.55)
  if outer < inner + 80 then outer = inner + 80 end
  for a = 0, 7 do
    local ang = a * 0.785398163
    parts[#parts + 1] = {
      kind = "box",
      min = { -16, 0, inner },
      max = { 16, 0.7, outer },
      yaw = ang,
      pos = { fp.x, y0, fp.z },
      color = ASPHALT, emissive = 0.18,
    }
    -- lit kerbs
    parts[#parts + 1] = {
      kind = "box",
      min = { -17.4, 0.5, inner },
      max = { -15.0, 0.85, outer },
      yaw = ang, pos = { fp.x, y0, fp.z },
      color = EDGE, emissive = 0.9,
    }
    parts[#parts + 1] = {
      kind = "box",
      min = { 15.0, 0.5, inner },
      max = { 17.4, 0.85, outer },
      yaw = ang, pos = { fp.x, y0, fp.z },
      color = EDGE, emissive = 0.9,
    }
  end
  return parts
end

function M.draw(v, A, ruin, set, cam)
  if not (ruin and ruin.city) then return 0 end
  local c = caches[ruin]
  if not c then
    local kit = set and set.kit or nil
    if not kit then return 0 end
    local parts = M.parts(ruin, kit, set.origin or ruin.origin)
    c = { mesh = #parts > 0 and saucer.mesh.build({ parts = parts }) or false, n = #parts }
    caches[ruin] = c
  end
  if not c.mesh then return 0 end
  local pal = A and A.pal and A.pal.base
  local tex = A and A.tex and (A.tex.city or A.tex.hull)
  if M._white == nil then
    local ok, t = pcall(function() return saucer.render.texture("generated/textures/planet_body.png") end)
    M._white = (ok and t) or false
  end
  v:mesh(c.mesh, { palette = pal, tex = (M._white ~= false and M._white) or tex })
  return c.n
end

function M.reset()
  caches = setmetatable({}, { __mode = "k" })
  M._white = nil
end

return M
