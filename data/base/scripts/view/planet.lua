-- SPDX-License-Identifier: MIT
-- add-generated-planets: drawing a body city's planet, moon or asteroid.
-- A single high-segment sphere is shaded in the mesh program (3D fbm on the
-- sphere normal, land/ocean/biome, day/night terminator, ocean specular). A
-- planet also gets a lit-side atmosphere rim and a thin cloud shell. The
-- near-cap is a smooth-shaded heightfield. Meshes are built once and cached
-- on the body record. Nothing here is saved.
local planet = require("sim.planet")
local sm = saucer.math

local M = {}
M.FAR_PAD = 80000
M.GLOBE_SEGS = 64
M.GLOBE_RINGS = 32
M.TERRAIN_NEAR = 5000
M.TERRAIN_MID = 11000
M.TERRAIN_FAR = 20000
M.CAP = 0.55
M.ATMO = 1.04
M.ATMO2 = 1.085
M.CLOUD = 1.025

local caches = setmetatable({}, { __mode = "k" })
local function cache(pl)
  local c = caches[pl.seed]
  if not c then
    c = {}
    caches[pl.seed] = c
  end
  return c
end

function M.cap_r(pl)
  return math.min(pl.R * M.CAP, math.max(pl.rim + 45000, 60000))
end

function M.body_id(pl)
  if pl.body == "moon" then return 1 end
  if pl.body == "asteroid" then return 2 end
  return 0
end

function M.planet_opts(pl, mode)
  return {
    c = { pl.cx, pl.cy, pl.cz },
    r = pl.R,
    seed = pl.seed,
    body = M.body_id(pl),
    heart = pl.heart or 0,
    mode = mode,
    cap = (mode == 1) and M.cap_r(pl) or 0,
    city = pl.rim or 0,
  }
end

-- one smooth sphere: colour and lighting come from the planet shader
function M.globe_parts(pl)
  return {
    {
      kind = "sphere",
      c = { pl.cx, pl.cy, pl.cz },
      r = pl.R, h = pl.R,
      seg = M.GLOBE_SEGS, rings = M.GLOBE_RINGS,
      color = { 1, 1, 1 }, emissive = 0,
    },
  }
end

function M.atmo_parts(pl)
  if pl.body ~= "planet" then return {} end
  local c = { pl.cx, pl.cy, pl.cz }
  return {
    { kind = "sphere", c = c, r = pl.R * M.ATMO, h = pl.R * M.ATMO, seg = 48, rings = 24, color = { 1, 1, 1 } },
    { kind = "sphere", c = c, r = pl.R * M.ATMO2, h = pl.R * M.ATMO2, seg = 48, rings = 24, color = { 1, 1, 1 } },
  }
end

function M.cloud_parts(pl)
  if pl.body ~= "planet" then return {} end
  local c = { pl.cx, pl.cy, pl.cz }
  return {
    { kind = "sphere", c = c, r = pl.R * M.CLOUD, h = pl.R * M.CLOUD, seg = 48, rings = 24, color = { 1, 1, 1 } },
  }
end

local function field_color(pl, x0, z0, x1, z1)
  local counts, n = {}, 0
  for j = 0, 2 do
    for i = 0, 2 do
      local x = x0 + (x1 - x0) * i / 2
      local z = z0 + (z1 - z0) * j / 2
      if not planet.in_heart(pl, x, z) then
        local k = planet.kind(pl, x, z)
        counts[k] = (counts[k] or 0) + 1
        n = n + 1
      end
    end
  end
  if (counts.ocean or 0) > 0 and (counts.land or 0) + (counts.highland or 0) + (counts.desert or 0) > 0 then
    return pl.pal.shallow or { 0.76, 0.70, 0.48 }
  end
  local best, bn = "land", 0
  for k, c in pairs(counts) do if c > bn then best, bn = k, c end end
  return planet.color(pl, (x0 + x1) / 2, (z0 + z1) / 2)
end

-- one heightfield tile, or nil if it is empty or off the cap
function M.terrain_field(pl, x0, z0, x1, z1, su, sv)
  local cap = M.cap_r(pl)
    local xc, zc = (x0 + x1) / 2, (z0 + z1) / 2
    local hd = sm.sqrt((xc - pl.cx) * (xc - pl.cx) + (zc - pl.cz) * (zc - pl.cz))
    if hd > cap then return end
    if planet.in_heart(pl, xc, zc) then return end
    if su < 1 then su = 1 end
    if su > 64 then su = 64 end
    if sv < 1 then sv = 1 end
    if sv > 64 then sv = 64 end
    local heights, colors, any = {}, {}, false
    for j = 0, sv do
      for i = 0, su do
        local x = x0 + (x1 - x0) * i / su
        local z = z0 + (z1 - z0) * j / sv
        local y = planet.height(pl, x, z)
        if y then any = true else y = pl.gy end
        local d = sm.sqrt((x - pl.cx) * (x - pl.cx) + (z - pl.cz) * (z - pl.cz))
        if d < pl.rim * 0.98 then y = pl.gy end
        heights[#heights + 1] = y
        -- per-vertex colour so neighbouring tiles share an edge colour and
        -- biome steps blend across a cell instead of sitting on a square edge
        -- average neighbouring samples so a biome edge blends across a cell
        -- instead of sitting on one triangle
        local acc = { 0, 0, 0 }
        for oj = -1, 1 do
          for oi = -1, 1 do
            local c = planet.color(pl, x + oi * 550, z + oj * 550)
            acc[1], acc[2], acc[3] = acc[1] + c[1], acc[2] + c[2], acc[3] + c[3]
          end
        end
        colors[#colors + 1] = acc[1] / 9
        colors[#colors + 1] = acc[2] / 9
        colors[#colors + 1] = acc[3] / 9
      end
    end
    if not any then return nil end
  return {
    kind = "heightfield",
    c = { x0, 0, z0 },
    u = { x1 - x0, 0, 0 },
    v = { 0, 0, z1 - z0 },
    heights = heights,
    colors = colors,
    seg = su, rings = sv,
    color = field_color(pl, x0, z0, x1, z1),
    emissive = 0.08,
  }
end

function M.terrain_tile_parts(pl, jobs)
  local parts = {}
  for _, j in ipairs(jobs) do
    local part = M.terrain_field(pl, j[1], j[2], j[3], j[4], j[5], j[6])
    if part then parts[#parts + 1] = part end
  end
  return parts
end

-- a disk of shared-vertex heightfields around the city. Heights come from the
-- same 3D noise as landing, so the ground you walk on matches what you see.
function M.terrain_parts(pl)
  local parts = {}
  local cap = M.cap_r(pl)
  local function add_field(x0, z0, x1, z1, su, sv)
    local part = M.terrain_field(pl, x0, z0, x1, z1, su, sv)
    if part then parts[#parts + 1] = part end
  end
  local rings = {
    { r0 = 0, r1 = pl.rim + 10000, s = M.TERRAIN_NEAR, sub = 8 },
    { r0 = pl.rim + 8000, r1 = pl.rim + 30000, s = M.TERRAIN_MID, sub = 8 },
    { r0 = pl.rim + 26000, r1 = cap, s = M.TERRAIN_FAR, sub = 6 },
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
          local key = math.floor(xc / 800) .. ":" .. math.floor(zc / 800)
          if not seen[key] then
            seen[key] = true
            add_field(x0, z0, x1, z1, rg.sub, rg.sub)
          end
        end
      end
    end
  end
  return parts
end

-- How many heightfield tiles one on_render may mesh. Building the whole cap
-- in one draw overruns the 50M instruction budget, the engine disables the
-- base mod, and the saucer stops flying (game tests then fail).
M.TERRAIN_PER_FRAME = 1

-- enumerate tile jobs without sampling noise (cheap enough for one frame)
function M.terrain_jobs(pl)
  local jobs, cap = {}, M.cap_r(pl)
  local rings = {
    { r0 = 0, r1 = pl.rim + 10000, s = M.TERRAIN_NEAR, sub = 8 },
    { r0 = pl.rim + 8000, r1 = pl.rim + 30000, s = M.TERRAIN_MID, sub = 8 },
    { r0 = pl.rim + 26000, r1 = cap, s = M.TERRAIN_FAR, sub = 6 },
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
        if hd >= rg.r0 and hd < rg.r1 and hd <= cap and not planet.in_heart(pl, xc, zc) then
          local key = math.floor(xc / 800) .. ":" .. math.floor(zc / 800)
          if not seen[key] then
            seen[key] = true
            jobs[#jobs + 1] = { x0, z0, x1, z1, rg.sub, rg.sub }
          end
        end
      end
    end
  end
  return jobs
end

-- build at most one expensive step per call so on_render stays under budget
local function build(pl, all)
  local c = cache(pl)
  if not c.globe then
    local gp = M.globe_parts(pl)
    c.globe = #gp > 0 and saucer.mesh.build({ parts = gp }) or false
    c.globe_n = #gp
    if not all then return c end
  end
  if not c.terrain_done then
    c.terrain_meshes = c.terrain_meshes or {}
    if all then
      local tp = M.terrain_parts(pl)
      if #tp > 0 then
        c.terrain_meshes[1] = saucer.mesh.build({ parts = tp })
        c.terrain = c.terrain_meshes[1]
        c.terrain_n = #tp
      else
        c.terrain = false
        c.terrain_n = 0
      end
      c.terrain_done = true
    else
      c.jobs = c.jobs or M.terrain_jobs(pl)
      c.job_i = c.job_i or 1
      local n, batch = 0, {}
      while c.job_i <= #c.jobs and n < M.TERRAIN_PER_FRAME do
        batch[#batch + 1] = c.jobs[c.job_i]
        c.job_i = c.job_i + 1
        n = n + 1
      end
      if #batch > 0 then
        local parts = M.terrain_tile_parts(pl, batch)
        if #parts > 0 then
          c.terrain_meshes[#c.terrain_meshes + 1] = saucer.mesh.build({ parts = parts })
          c.terrain = c.terrain or c.terrain_meshes[#c.terrain_meshes]
          c.terrain_n = (c.terrain_n or 0) + #parts
        end
      end
      if c.job_i > #c.jobs then c.terrain_done = true end
      return c
    end
  end
  if pl.body == "planet" and c.atmo == nil then
    local ap = M.atmo_parts(pl)
    c.atmo = #ap > 0 and saucer.mesh.build({ parts = ap }) or false
    local cp = M.cloud_parts(pl)
    c.clouds = #cp > 0 and saucer.mesh.build({ parts = cp }) or false
  end
  return c
end

-- call from a test script or a quiet tick: builds every mesh now
function M.warmup(pl)
  if type(pl) == "table" and pl.R then
    build(pl, true)
  else
    if type(pl) == "table" then planet.activate(pl) end
    for _, body in ipairs(planet.live()) do build(body, true) end
  end
end

function M.far_plane(cam, state)
  for _, pl in ipairs(planet.live()) do
    local dx, dy, dz = cam.pos[1] - pl.cx, cam.pos[2] - pl.cy, cam.pos[3] - pl.cz
    local dist = sm.sqrt(dx * dx + dy * dy + dz * dz)
    local need = dist + pl.R * M.ATMO2 + M.FAR_PAD
    if (cam.far or 0) < need then cam.far = need end
  end
  return cam
end

local function body_tex()
  if M._body_tex == nil then
    local ok, tex = pcall(function() return saucer.render.texture("generated/textures/planet_body.png") end)
    M._body_tex = (ok and tex) or false
  end
  return (M._body_tex ~= false and M._body_tex) or nil
end

function M.draw(v, A, state, cam)
  local st = { globes = 0, terrains = 0, parts = 0 }
  if #planet.live() == 0 and state then planet.activate(state) end
  local pal = A and A.pal and A.pal.base
  local tex = body_tex() or (A and A.tex and (A.tex.hull or A.tex.city))
  for _, pl in ipairs(planet.live()) do
    local c = build(pl)
    if c.globe then
      v:mesh(c.globe, { palette = pal, tex = tex, noshadow = true, planet = M.planet_opts(pl, 1) })
      st.globes = st.globes + 1
      st.parts = st.parts + (c.globe_n or 0)
    end
    for _, tm in ipairs(c.terrain_meshes or (c.terrain and { c.terrain } or {})) do
      v:mesh(tm, { palette = pal, tex = tex, noshadow = true })
      st.terrains = st.terrains + 1
    end
    st.parts = st.parts + (c.terrain_n or 0)
    if c.clouds then
      v:mesh(c.clouds, { palette = pal, tex = tex, unlit = true, noshadow = true, planet = M.planet_opts(pl, 3) })
      st.clouds = (st.clouds or 0) + 1
    end
    if c.atmo then
      v:mesh(c.atmo, { palette = pal, tex = tex, unlit = true, noshadow = true, planet = M.planet_opts(pl, 2) })
      st.atmo = (st.atmo or 0) + 1
    end
  end
  M.stats = st
  return st
end

function M.reset()
  caches = setmetatable({}, { __mode = "k" })
  M._body_tex = nil
end

return M
