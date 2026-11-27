-- SPDX-License-Identifier: MIT
-- add-generated-planets: curved ring roads, radial avenues, zone paving and
-- street lamps that make a concentric city read as rings from the air.
-- View-only (lots keep their rectangular collision); built once per ruin.
local citygen = require("sim.citygen")

local M = {}
local caches = setmetatable({}, { __mode = "k" })

local ASPHALT = { 0.50, 0.47, 0.42 }
local EDGE = { 1.00, 0.86, 0.35 }
local PLAZA = { 0.84, 0.80, 0.72 }
local ZONES = {
  { 0.78, 0.74, 0.66 }, -- core pale stone
  { 0.24, 0.46, 0.26 }, -- civic park
  { 0.66, 0.42, 0.22 }, -- market terracotta
  { 0.38, 0.46, 0.44 }, -- residential
  { 0.30, 0.30, 0.32 }, -- industrial
}

function M.parts(ruin, kit, origin)
  local fp, radii = citygen.ring_world_radii(kit, origin)
  if not fp then return {} end
  local y = (ruin.city and ruin.city.districts[1] and ruin.city.districts[1].pos[2]) or origin[2]
  local y0 = y + 2.2
  local parts = {}
  local inner = (radii[1] or 400) * 0.85
  if inner < 120 then inner = 120 end

  -- zone paving, under the roads, so each ring reads a different ground colour
  local prev = 8
  for i, R in ipairs(radii) do
    if R > prev + 20 then
      local col = ZONES[math.min(i, #ZONES)]
      parts[#parts + 1] = {
        kind = "ring", c = { fp.x, y0 - 0.15, fp.z }, rin = prev, r = R - 2, h = 0.28, seg = 64,
        color = col, emissive = 0.16,
      }
      prev = R + 2
    end
  end
  local outer = radii[#radii] or (fp.r * 0.55)
  if outer < inner + 80 then outer = inner + 80 end
  if outer > prev + 20 then
    parts[#parts + 1] = {
      kind = "ring", c = { fp.x, y0 - 0.15, fp.z }, rin = prev, r = outer + 40, h = 0.28, seg = 64,
      color = ZONES[#ZONES], emissive = 0.14,
    }
  end

  -- the centre plaza: a wide, bright paved disk
  parts[#parts + 1] = {
    kind = "cylinder", c = { fp.x, y0, fp.z }, r = inner, h = 1.1, seg = 48,
    color = PLAZA, emissive = 0.42,
  }
  parts[#parts + 1] = {
    kind = "ring", c = { fp.x, y0 + 0.45, fp.z }, rin = inner - 16, r = inner + 8, h = 0.8, seg = 48,
    color = EDGE, emissive = 0.95,
  }

  local width = 42
  for _, R in ipairs(radii) do
    if R > inner + 30 then
      parts[#parts + 1] = {
        kind = "ring", c = { fp.x, y0 + 0.2, fp.z }, rin = R - width, r = R + width, h = 0.55, seg = 64,
        color = ASPHALT, emissive = 0.48,
      }
      parts[#parts + 1] = {
        kind = "ring", c = { fp.x, y0 + 0.55, fp.z }, rin = R - width - 1.6, r = R - width + 1.2, h = 0.28, seg = 64,
        color = EDGE, emissive = 1,
      }
      parts[#parts + 1] = {
        kind = "ring", c = { fp.x, y0 + 0.55, fp.z }, rin = R + width - 1.2, r = R + width + 1.6, h = 0.28, seg = 64,
        color = EDGE, emissive = 1,
      }
    end
  end

  -- eight radial avenues, with glowing kerbs
  for a = 0, 7 do
    local ang = a * 0.785398163
    parts[#parts + 1] = {
      kind = "box",
      min = { -18, 0, inner },
      max = { 18, 0.75, outer },
      yaw = ang, pos = { fp.x, y0, fp.z },
      color = ASPHALT, emissive = 0.48,
    }
    parts[#parts + 1] = {
      kind = "box",
      min = { -19.6, 0.55, inner },
      max = { -16.8, 0.95, outer },
      yaw = ang, pos = { fp.x, y0, fp.z },
      color = EDGE, emissive = 1,
    }
    parts[#parts + 1] = {
      kind = "box",
      min = { 16.8, 0.55, inner },
      max = { 19.6, 0.95, outer },
      yaw = ang, pos = { fp.x, y0, fp.z },
      color = EDGE, emissive = 1,
    }
  end

  -- street lamps along each ring and a tighter ring on the plaza
  local function lamp(x, z)
    parts[#parts + 1] = {
      kind = "cylinder", c = { x, y0, z }, r = 0.28, h = 8.5, seg = 6,
      color = { 0.28, 0.28, 0.30 },
    }
    parts[#parts + 1] = {
      kind = "sphere", c = { x, y0 + 8.8, z }, r = 1.15, h = 1.15, seg = 6, rings = 3,
      color = { 1.0, 0.88, 0.50 }, emissive = 1,
    }
  end
  local lamp_rings = { inner * 0.72 }
  for _, R in ipairs(radii) do
    if R > inner + 30 then lamp_rings[#lamp_rings + 1] = R end
  end
  for _, R in ipairs(lamp_rings) do
    local n = (R < inner + 50) and 20 or 36
    for k = 0, n - 1 do
      local ang = k / n * 6.283185307
      lamp(fp.x + math.sin(ang) * R, fp.z + math.cos(ang) * R)
    end
  end
  -- a few lamps along each avenue
  for a = 0, 7 do
    local ang = a * 0.785398163
    local sa, ca = math.sin(ang), math.cos(ang)
    for t = 0.12, 0.95, 0.16 do
      local r = inner + (outer - inner) * t
      lamp(fp.x + sa * r, fp.z + ca * r)
    end
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

function M.warmup(ruin, kit, origin)
  if not (ruin and ruin.city and kit) then return end
  if caches[ruin] then return end
  local parts = M.parts(ruin, kit, origin or ruin.origin)
  caches[ruin] = { mesh = #parts > 0 and saucer.mesh.build({ parts = parts }) or false, n = #parts }
end

function M.reset()
  caches = setmetatable({}, { __mode = "k" })
  M._white = nil
end

return M
