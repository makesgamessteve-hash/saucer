-- SPDX-License-Identifier: MIT
-- add-generated-planets: drawing a body city's planet, moon or asteroid.
-- A faceted globe (lat/lon plates, coloured by sim/planet.lua) and a near-cap
-- of terrain tiles around the city. Meshes are built once and cached on the body
-- record. Nothing here is saved.
local planet = require("sim.planet")
local sm = saucer.math

local M = {}
M.FAR_PAD = 80000          -- metres past the limb for the camera far plane
M.GLOBE_RINGS = 18
M.GLOBE_SEGS = 32
M.TERRAIN_NEAR = 2800      -- tile size near the city, metres
M.TERRAIN_FAR = 7000
M.CAP = 0.55               -- the detailed cap is this fraction of R (capped below)
M.ATMO = 1.05              -- atmosphere sphere scale

local caches = setmetatable({}, { __mode = "k" })
local function cache(pl)
  local c = caches[pl.seed]
  if not c then
    c = {}
    caches[pl.seed] = c
  end
  return c
end

-- a point on the sphere for colatitude theta, azimuth phi
local function sph(pl, theta, phi)
  local s, c = sm.sin(theta), sm.cos(theta)
  return {
    pl.cx + pl.R * s * sm.sin(phi),
    pl.cy + pl.R * c,
    pl.cz + pl.R * s * sm.cos(phi),
  }
end

-- should this globe tile be left to the terrain cap? (city-facing upper cap)
local function on_cap(pl, p, cap_r)
  local dy = p[2] - pl.gy
  if dy < -pl.R * 0.15 then return false end
  local hd = sm.sqrt((p[1] - pl.cx) * (p[1] - pl.cx) + (p[3] - pl.cz) * (p[3] - pl.cz))
  return hd < cap_r
end

function M.cap_r(pl)
  return math.min(pl.R * M.CAP, math.max(pl.rim + 45000, 60000))
end

-- coloured faceted globe, with a hole for the near cap
function M.globe_parts(pl)
  local parts = {}
  local cap = M.cap_r(pl)
  local rings, segs = M.GLOBE_RINGS, M.GLOBE_SEGS
  for i = 0, rings - 1 do
    local t0 = i / rings * sm.pi
    local t1 = (i + 1) / rings * sm.pi
    for j = 0, segs - 1 do
      local p0 = j / segs * sm.tau
      local p1 = (j + 1) / segs * sm.tau
      local a, b, c, d = sph(pl, t0, p0), sph(pl, t0, p1), sph(pl, t1, p0), sph(pl, t1, p1)
      local mid = { (a[1] + b[1] + c[1] + d[1]) / 4, (a[2] + b[2] + c[2] + d[2]) / 4, (a[3] + b[3] + c[3] + d[3]) / 4 }
      if not on_cap(pl, mid, cap) and not planet.in_heart(pl, mid[1], mid[3]) then
        local col = planet.color(pl, mid[1], mid[3])
        -- a box spanning the four corners: a retro facet with a little thickness
        local mn = { math.min(a[1], b[1], c[1], d[1]), math.min(a[2], b[2], c[2], d[2]), math.min(a[3], b[3], c[3], d[3]) }
        local mx = { math.max(a[1], b[1], c[1], d[1]), math.max(a[2], b[2], c[2], d[2]), math.max(a[3], b[3], c[3], d[3]) }
        for k = 1, 3 do
          if mx[k] - mn[k] < pl.R * 0.01 then
            local midk = (mn[k] + mx[k]) / 2
            mn[k], mx[k] = midk - pl.R * 0.005, midk + pl.R * 0.005
          end
        end
        parts[#parts + 1] = { kind = "box", min = mn, max = mx, color = col, emissive = 0.55 }
      end
    end
  end
  return parts
end

-- a disk of terrain boxes around the city (the cap). Finer near the rim, coarser farther out.
function M.terrain_parts(pl)
  local parts = {}
  local cap = M.cap_r(pl)
  local function add_tile(x0, z0, x1, z1)
    local xc, zc = (x0 + x1) / 2, (z0 + z1) / 2
    local hd = sm.sqrt((xc - pl.cx) * (xc - pl.cx) + (zc - pl.cz) * (zc - pl.cz))
    if hd > cap then return end
    if planet.in_heart(pl, xc, zc) then return end
    local y = planet.height(pl, xc, zc)
    if not y then return end
    local col = planet.color(pl, xc, zc)
    -- under the city plateau, start the tile a little below the street so foundations win
    local top = y
    local bot = math.min(y - 70, pl.gy - (hd < pl.rim and (pl.undercity + 8) or 70))
    if hd < pl.rim * 0.98 then
      top = pl.gy
      bot = pl.gy - 8
    end
    parts[#parts + 1] = { kind = "box", min = { x0, bot, z0 }, max = { x1, top, z1 }, color = col, emissive = 0.22 }
  end
  -- three rings of tiles: city-adjacent, mid, outer cap
  local rings = {
    { r0 = 0, r1 = pl.rim + 6000, s = M.TERRAIN_NEAR },
    { r0 = pl.rim + 5000, r1 = pl.rim + 25000, s = 4500 },
    { r0 = pl.rim + 22000, r1 = cap, s = M.TERRAIN_FAR },
  }
  local seen = {}
  for _, rg in ipairs(rings) do
    local s = rg.s
    local i0 = math.floor((pl.cx - rg.r1) / s) - 1
    local i1 = math.floor((pl.cx + rg.r1) / s) + 1
    local k0 = math.floor((pl.cz - rg.r1) / s) - 1
    local k1 = math.floor((pl.cz + rg.r1) / s) + 1
    for iz = k0, k1 do
      for ix = i0, i1 do
        local x0, z0, x1, z1 = ix * s, iz * s, (ix + 1) * s, (iz + 1) * s
        local xc, zc = (x0 + x1) / 2, (z0 + z1) / 2
        local hd = sm.sqrt((xc - pl.cx) * (xc - pl.cx) + (zc - pl.cz) * (zc - pl.cz))
        if hd >= rg.r0 and hd < rg.r1 then
          local key = math.floor(xc / 400) .. ":" .. math.floor(zc / 400)
          if not seen[key] then
            seen[key] = true
            add_tile(x0, z0, x1, z1)
          end
        end
      end
    end
  end
  return parts
end

function M.atmo_parts(pl)
  if pl.body ~= "planet" then return {} end
  local tint = { 0.45, 0.62, 0.88 }
  return {
    { kind = "sphere", c = { pl.cx, pl.cy, pl.cz }, r = pl.R * M.ATMO, h = pl.R * M.ATMO,
      seg = 20, rings = 10, color = tint },
  }
end

local function build(pl)
  local c = cache(pl)
  if not c.globe then
    local gp = M.globe_parts(pl)
    c.globe = #gp > 0 and saucer.mesh.build({ parts = gp }) or false
    c.globe_n = #gp
  end
  if not c.terrain then
    local tp = M.terrain_parts(pl)
    c.terrain = #tp > 0 and saucer.mesh.build({ parts = tp }) or false
    c.terrain_n = #tp
  end
  if pl.body == "planet" and c.atmo == nil then
    local ap = M.atmo_parts(pl)
    c.atmo = #ap > 0 and saucer.mesh.build({ parts = ap }) or false
  end
  return c
end

-- the far plane needed to keep the whole body on screen
function M.far_plane(cam, state)
  for _, pl in ipairs(planet.live()) do
    local dx, dy, dz = cam.pos[1] - pl.cx, cam.pos[2] - pl.cy, cam.pos[3] - pl.cz
    local dist = sm.sqrt(dx * dx + dy * dy + dz * dz)
    local need = dist + pl.R * M.ATMO + M.FAR_PAD
    if (cam.far or 0) < need then cam.far = need end
  end
  return cam
end

-- draw every live body. -> stats { globes, terrains, parts }
function M.draw(v, A, state, cam)
  local st = { globes = 0, terrains = 0, parts = 0 }
  -- make sure the sector's bodies are live even if a test skipped game.rebuild's sync
  if #planet.live() == 0 and state then planet.activate(state) end
  for _, pl in ipairs(planet.live()) do
    local c = build(pl)
    local pal = A and A.pal and A.pal.base
    local tex = A and A.tex and (A.tex.hull or A.tex.city)
    if c.globe then
      v:mesh(c.globe, { palette = pal, tex = tex })
      st.globes = st.globes + 1
      st.parts = st.parts + (c.globe_n or 0)
    end
    if c.terrain then
      v:mesh(c.terrain, { palette = pal, tex = tex })
      st.terrains = st.terrains + 1
      st.parts = st.parts + (c.terrain_n or 0)
    end
    if c.atmo then
      v:mesh(c.atmo, { palette = pal, ghost = true, tint = { 0.5, 0.7, 1, 0.16 } })
      st.atmo = (st.atmo or 0) + 1
    end
  end
  M.stats = st
  return st
end

-- tests: drop the cache
function M.reset()
  caches = setmetatable({}, { __mode = "k" })
end

return M
