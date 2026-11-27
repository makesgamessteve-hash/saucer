-- SPDX-License-Identifier: MIT
-- add-generated-planets: drawing a body city's planet, moon or asteroid.
-- A smooth spherical globe (tessellated patches whose corners sit on the
-- sphere, plus a soft atmosphere rim) and a near-cap of bilinear terrain
-- patches around the city. Meshes are built once and cached on the body
-- record. Nothing here is saved.
local planet = require("sim.planet")
local sm = saucer.math

local M = {}
M.FAR_PAD = 80000          -- metres past the limb for the camera far plane
M.GLOBE_RINGS = 36         -- colatitude bands: a round limb at this density
M.GLOBE_SEGS = 64          -- azimuth slices
M.GLOBE_SUB = 2            -- patch subdivisions (smooth bulge, cheap)
M.TERRAIN_NEAR = 1600      -- tile size near the city, metres
M.TERRAIN_FAR = 5600
M.CAP = 0.55               -- the detailed cap is this fraction of R (capped below)
M.ATMO = 1.04              -- inner atmosphere shell
M.ATMO2 = 1.08             -- outer soft rim

local caches = setmetatable({}, { __mode = "k" })
local function cache(pl)
  local c = caches[pl.seed]
  if not c then
    c = {}
    caches[pl.seed] = c
  end
  return c
end

local function vsub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function vadd(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
local function vscale(a, s) return { a[1] * s, a[2] * s, a[3] * s } end
local function vlen(a) return sm.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) end
local function vnorm(a)
  local l = vlen(a)
  return l > 1e-9 and vscale(a, 1 / l) or a
end
local function cross(a, b)
  return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end

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

-- a smooth spherical quad: corners on the sphere, bulge to the surface, slight
-- overlap so micro-gaps between parallelograms do not show.
local function globe_patch(pl, a, b, c, mid, col)
  local u, v = vsub(b, a), vsub(c, a)
  local n = vnorm(cross(u, v))
  local from = { mid[1] - pl.cx, mid[2] - pl.cy, mid[3] - pl.cz }
  if dot(n, from) < 0 then n = vscale(n, -1) end
  local target = vadd({ pl.cx, pl.cy, pl.cz }, vscale(vnorm(from), pl.R))
  local h = dot(vsub(target, mid), n)
  if h < 0 then h = 0 end
  local e = 0.03
  local c0 = vadd(a, vadd(vscale(u, -e), vscale(v, -e)))
  return {
    kind = "patch", c = c0, u = vscale(u, 1 + 2 * e), v = vscale(v, 1 + 2 * e),
    h = h, seg = M.GLOBE_SUB, rings = M.GLOBE_SUB, color = col, emissive = 0.55,
  }
end

-- coloured smooth globe, with a hole for the near cap and the sector-heart bay
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
        parts[#parts + 1] = globe_patch(pl, a, b, c, mid, planet.color(pl, mid[1], mid[3]))
      end
    end
  end
  return parts
end

-- a disk of sloped terrain patches around the city (the cap). Finer near the
-- rim, coarser farther out. No vertical sides: neighbouring tiles overlap a
-- little so the ground reads as a continuous surface.
function M.terrain_parts(pl)
  local parts = {}
  local cap = M.cap_r(pl)
  local function add_tile(x0, z0, x1, z1)
    local xc, zc = (x0 + x1) / 2, (z0 + z1) / 2
    local hd = sm.sqrt((xc - pl.cx) * (xc - pl.cx) + (zc - pl.cz) * (zc - pl.cz))
    if hd > cap then return end
    if planet.in_heart(pl, xc, zc) then return end
    local y00 = planet.height(pl, x0, z0)
    local y10 = planet.height(pl, x1, z0)
    local y01 = planet.height(pl, x0, z1)
    local yc = planet.height(pl, xc, zc)
    if not (y00 and y10 and y01 and yc) then return end
    -- under the city plateau, keep a thin flush slab so foundations win
    if hd < pl.rim * 0.98 then
      y00, y10, y01, yc = pl.gy, pl.gy, pl.gy, pl.gy
    end
    -- two overlapping sloped patches (00-10-01 and 10-11-01) so the four
    -- corner heights all sit on the surface; a small overlap hides the join.
    local col = planet.color(pl, xc, zc)
    local ox = (x1 - x0) * 0.04
    local oz = (z1 - z0) * 0.04
    local function plate(ax, ay, az, ux, uy, uz, vx, vy, vz)
      parts[#parts + 1] = {
        kind = "patch", c = { ax, ay, az }, u = { ux, uy, uz }, v = { vx, vy, vz },
        h = 0, seg = 1, rings = 1, color = col, emissive = 0.22,
      }
    end
    -- one sloped parallelogram per cell (the fourth corner is bilinear from
    -- three heights; neighbouring tiles overlap so seams stay hidden)
    plate(x0 - ox, y00, z0 - oz, (x1 + ox) - (x0 - ox), y10 - y00, 0, 0, y01 - y00, (z1 + oz) - (z0 - oz))
  end
  -- three rings of tiles: city-adjacent, mid, outer cap
  local rings = {
    { r0 = 0, r1 = pl.rim + 6000, s = M.TERRAIN_NEAR },
    { r0 = pl.rim + 5000, r1 = pl.rim + 25000, s = 3200 },
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
  local c = { pl.cx, pl.cy, pl.cz }
  -- two high-segment shells: a tighter haze and a softer outer rim, so the
  -- limb reads as a smooth circle rather than a faceted edge
  return {
    { kind = "sphere", c = c, r = pl.R * M.ATMO, h = pl.R * M.ATMO, seg = 48, rings = 24, color = tint },
    { kind = "sphere", c = c, r = pl.R * M.ATMO2, h = pl.R * M.ATMO2, seg = 48, rings = 24, color = tint },
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
    local need = dist + pl.R * M.ATMO2 + M.FAR_PAD
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
    -- a flat albedo: hull plating would stamp a panel on every globe tile
    if M._body_tex == nil then
      local ok, tex = pcall(function() return saucer.render.texture("generated/textures/planet_body.png") end)
      M._body_tex = (ok and tex) or false
    end
    local tex = (M._body_tex ~= false and M._body_tex) or (A and A.tex and (A.tex.hull or A.tex.city))
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
      v:mesh(c.atmo, { palette = pal, ghost = true, tint = { 0.55, 0.75, 1, 0.22 } })
      st.atmo = (st.atmo or 0) + 1
    end
  end
  M.stats = st
  return st
end

-- tests: drop the cache
function M.reset()
  caches = setmetatable({}, { __mode = "k" })
  M._body_tex = nil
end

return M
