-- SPDX-License-Identifier: MIT
-- add-generated-planets: a seeded sphere under every body city (planet, moon or asteroid).
-- The city's street is tangent to the sphere; a rim around the megacity is flattened so the
-- existing lots sit flush. Height, colour and kind are pure functions of the city's seed.
-- Nothing here is saved: the same ruin always produces the same body.
local citymega = require("sim.citymega")
local ruinm = require("sim.ruin")
local sm = saucer.math

local M = {}

-- radius ranges, metres, by body (the megacity is 16-21 km across, so even an asteroid is a
-- large rock). undercity: metres of clearance under the street for the warren before the crust.
M.RADIUS = { planet = { 100000, 140000 }, moon = { 50000, 80000 }, asteroid = { 24000, 34000 } }
M.UNDERCITY = 56
M.AIR_TOP = 8000
M.CELL = 800          -- collision tiles, metres
M.KEEP = 2400         -- a ship streams tiles this far
M.CRUST = 80          -- thickness of streamed surface boxes

local live = {}       -- planets of the current sector
local boxes = {}      -- [key] = physics id

local function u32(n)
  n = n & 0xffffffff
  n = (n ~ ((n << 13) & 0xffffffff)) & 0xffffffff
  n = (n ~ (n >> 17)) & 0xffffffff
  n = (n ~ ((n << 5) & 0xffffffff)) & 0xffffffff
  return n
end
local function hash2(ix, iz, seed)
  return u32(ix * 374761393 + iz * 668265263 + seed * 2654435761)
end
local function hash3(ix, iy, iz, seed)
  return u32(ix * 374761393 + iy * 668265263 + iz * 1274126177 + seed * 2654435761)
end
-- value noise in 0..1
local function vnoise(x, z, seed)
  local x0, z0 = math.floor(x), math.floor(z)
  local fx, fz = x - x0, z - z0
  local function g(i, j) return (hash2(i, j, seed) % 10007) / 10006 end
  local a, b, c, d = g(x0, z0), g(x0 + 1, z0), g(x0, z0 + 1), g(x0 + 1, z0 + 1)
  local u, v = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
end
local function fbm(pl, x, z, scale, octaves)
  local n, a, f, s = 0, 1, 1, 0
  for i = 1, octaves or 3 do
    n = n + a * vnoise((x - pl.cx) / scale * f, (z - pl.cz) / scale * f, pl.seeds[i] or pl.seed)
    s = s + a
    a, f = a * 0.5, f * 2
  end
  return n / s
end
M._fbm = fbm

-- 3D value-noise fbm on a direction (the unit-sphere normal). Used for land
-- masses so coasts are organic, not a planar xz or lat/lon grid.
local function vnoise3(x, y, z, seed)
  local x0, y0, z0 = math.floor(x), math.floor(y), math.floor(z)
  local fx, fy, fz = x - x0, y - y0, z - z0
  local function g(i, j, k) return (hash3(i, j, k, seed) % 10007) / 10006 end
  local u, v, w = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
  local n000, n100 = g(x0, y0, z0), g(x0 + 1, y0, z0)
  local n010, n110 = g(x0, y0 + 1, z0), g(x0 + 1, y0 + 1, z0)
  local n001, n101 = g(x0, y0, z0 + 1), g(x0 + 1, y0, z0 + 1)
  local n011, n111 = g(x0, y0 + 1, z0 + 1), g(x0 + 1, y0 + 1, z0 + 1)
  local x00 = n000 + (n100 - n000) * u
  local x10 = n010 + (n110 - n010) * u
  local x01 = n001 + (n101 - n001) * u
  local x11 = n011 + (n111 - n011) * u
  local y0v = x00 + (x10 - x00) * v
  local y1v = x01 + (x11 - x01) * v
  return y0v + (y1v - y0v) * w
end
local function fbm3(pl, dir, freq, octaves)
  local n, a, s = 0, 1, 0
  local px, py, pz = dir[1] * freq, dir[2] * freq, dir[3] * freq
  for i = 1, octaves or 5 do
    n = n + a * vnoise3(px, py, pz, pl.seeds[i] or pl.seed)
    s = s + a
    a = a * 0.5
    px, py, pz = px * 2.07, py * 2.07, pz * 2.07
  end
  return n / s
end
M._fbm3 = fbm3

function M.dir_of(pl, x, z)
  local sy = M.sphere_y(pl, x, z) or pl.gy
  local dx, dy, dz = x - pl.cx, sy - pl.cy, z - pl.cz
  local l = sm.sqrt(dx * dx + dy * dy + dz * dz)
  if l < 1e-9 then return { 0, 1, 0 } end
  return { dx / l, dy / l, dz / l }
end

local function lerp(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function shade(c, k) return { math.max(0, math.min(1, c[1] * k)), math.max(0, math.min(1, c[2] * k)), math.max(0, math.min(1, c[3] * k)) } end

-- the body's record for city ruin r (optional mega plan, for a tighter rim). Pure.
function M.of(r, plan)
  if not (r and r.city) then return nil end
  local kit = ruinm.kit_of(r.kit)
  local spec = kit and kit.city
  if not spec then return nil end
  local body = spec.body
  local range = M.RADIUS[body] or M.RADIUS.planet
  local fr = (plan and plan.frame) or citymega.frame(r)
  local rng = saucer.rng.new(saucer.seed_child(r.seed, "planet", 0))
  local R = rng:int(range[1], range[2])
  local rim
  if plan and plan.span then
    rim = plan.span / 2 + 2000
  else
    rim = math.max(fr.ext[1], fr.ext[3]) / 2 + 9000
  end
  if rim > R * 0.45 then rim = R * 0.45 end
  -- keep the sector's other sites, the station and the arrival in open space: the body
  -- wraps the sides and the far side of the city, and leaves a bay toward the origin
  local reach = sm.sqrt(fr.cx * fr.cx + fr.cz * fr.cz) - math.max(fr.ext[1], fr.ext[3]) / 2 - 400
  local heart = math.max(2000, reach)
  if plan and plan.heart then heart = plan.heart end
  local seeds = { rng:int(1, 1e8), rng:int(1, 1e8), rng:int(1, 1e8), rng:int(1, 1e8) }
  local pal
  if body == "moon" then
    pal = {
      land = { 0.58 + rng:float() * 0.08, 0.56, 0.52 },
      highland = { 0.72, 0.70, 0.66 },
      maria = { 0.30, 0.30, 0.33 },
      crater = { 0.42, 0.41, 0.38 },
      ice = { 0.86, 0.86, 0.88 },
    }
  elseif body == "asteroid" then
    pal = {
      land = { 0.40 + rng:float() * 0.08, 0.32, 0.24 },
      highland = { 0.52, 0.42, 0.32 },
      maria = { 0.22, 0.18, 0.14 },
      crater = { 0.28, 0.22, 0.16 },
      ice = { 0.55, 0.50, 0.42 },
    }
  else
    pal = {
      ocean = { 0.08, 0.22 + rng:float() * 0.08, 0.55 },
      shallow = { 0.12, 0.48, 0.58 },
      land = { 0.28 + rng:float() * 0.1, 0.50, 0.20 },
      desert = { 0.62, 0.48, 0.20 },
      highland = { 0.48, 0.40, 0.30 },
      ice = { 0.90, 0.94, 0.98 },
    }
  end
  return {
    body = body, seed = r.seed, seeds = seeds, R = R,
    cx = fr.cx, cy = fr.y - R, cz = fr.cz, gy = fr.y, rim = rim, heart = heart,
    pal = pal, sea = 0.42 + rng:float() * 0.08,
    hill = (body == "asteroid") and 420 or (body == "moon" and 280 or 380),
    undercity = M.UNDERCITY, style = r.city.style, kit = kit,
  }
end

-- the sphere's upper surface at (x, z), or nil past the limb
function M.sphere_y(pl, x, z)
  local dx, dz = x - pl.cx, z - pl.cz
  local h2 = pl.R * pl.R - dx * dx - dz * dz
  if h2 <= 0 then return nil end
  return pl.cy + sm.sqrt(h2)
end

-- land-mass 0..1 (city rim is forced to land so the lots always sit on ground)
function M.land(pl, x, z)
  local n = fbm3(pl, M.dir_of(pl, x, z), 3.4, 5)
  local hd = sm.sqrt((x - pl.cx) * (x - pl.cx) + (z - pl.cz) * (z - pl.cz))
  if hd < pl.rim + 3000 then
    local t = math.max(0, (hd - pl.rim) / 3000)
    n = n + (1 - t) * 0.55
  end
  return n
end

-- surface kind at (x, z)
function M.kind(pl, x, z)
  local hd = sm.sqrt((x - pl.cx) * (x - pl.cx) + (z - pl.cz) * (z - pl.cz))
  if hd >= pl.R then return "space" end
  -- the city sits at the local north pole; ice lives at the far (south) pole
  if pl.body == "planet" then
    local cy = ((M.sphere_y(pl, x, z) or pl.gy) - pl.cy) / pl.R
    if cy < -0.70 then return "ice" end
    local land = M.land(pl, x, z)
    if land < pl.sea then return (land > pl.sea - 0.06) and "shallow" or "ocean" end
    local dir = M.dir_of(pl, x, z)
    local h = fbm3(pl, dir, 9.0, 3)
    if h > 0.72 then return "highland" end
    if fbm3(pl, { dir[1] + 0.17, dir[2], dir[3] - 0.09 }, 6.0, 2) > 0.68 then return "desert" end
    return "land"
  end
  -- moon / asteroid: maria (lowlands) and craters
  local dir = M.dir_of(pl, x, z)
  local n = fbm3(pl, dir, 4.2, 4)
  if n < 0.38 then return "maria" end
  local c = fbm3(pl, dir, 14.0, 2)
  if c > 0.82 then return "crater" end
  if n > 0.72 then return "highland" end
  return "land"
end

function M.color(pl, x, z)
  local k = M.kind(pl, x, z)
  local pal = pl.pal
  local col = pal[k] or pal.land
  local j = 0.92 + 0.16 * fbm(pl, x + 400, z + 200, 1800, 2)
  return shade(col, j)
end

-- upper surface height at (x, z): sphere, flattened across the city rim, plus relief
function M.height(pl, x, z)
  local sy = M.sphere_y(pl, x, z)
  if not sy then return nil end
  local hd = sm.sqrt((x - pl.cx) * (x - pl.cx) + (z - pl.cz) * (z - pl.cz))
  local y = sy
  if hd < pl.rim then
    local t = hd / pl.rim
    t = t * t * (3 - 2 * t)
    y = pl.gy + (sy - pl.gy) * t
  end
  local kind = M.kind(pl, x, z)
  local n = (fbm(pl, x, z, 3500, 3) - 0.5) * 2
  if kind == "ocean" then
    y = y - 40
  elseif kind == "shallow" then
    y = y - 12
  elseif kind == "crater" then
    y = y - pl.hill * 0.45 * math.max(0, fbm(pl, x, z, 900, 2) - 0.4)
  elseif kind == "highland" then
    y = y + pl.hill * (0.35 + 0.65 * math.max(0, n))
  elseif kind == "maria" then
    y = y + n * pl.hill * 0.15
  else
    y = y + n * pl.hill * 0.45
  end
  -- the city plateau itself stays at street level (relief starts at the rim)
  if hd < pl.rim * 0.92 then
    local t = hd / (pl.rim * 0.92)
    t = t * t
    y = pl.gy + (y - pl.gy) * t
  end
  return y
end

-- the open-space bay toward the sector's heart (other sites, the station, the arrival)
function M.in_heart(pl, x, z)
  return sm.sqrt(x * x + z * z) < (pl.heart or 0)
end

-- landing / collision surface under (x, y, z): the upper ground outside the city, or the
-- crust under the warren inside the rim. nil if the point is in the city's own volume
-- or in the sector-heart bay (those stay in open space).
function M.support_of(pl, x, y, z)
  if M.in_heart(pl, x, z) then return nil end
  local surf = M.height(pl, x, z)
  if not surf then return nil end
  local hd = sm.sqrt((x - pl.cx) * (x - pl.cx) + (z - pl.cz) * (z - pl.cz))
  if hd > pl.rim then return surf end
  local crust = pl.gy - (pl.undercity or M.UNDERCITY)
  if y < crust + 6 then return math.min(surf, crust) end
  return nil
end

function M.inside(pl, x, y, z)
  local dx, dy, dz = x - pl.cx, y - pl.cy, z - pl.cz
  return dx * dx + dy * dy + dz * dz < pl.R * pl.R
end

-- is pos in the body's air (over the disk, below AIR_TOP, not past the limb)?
function M.in_air(pl, pos)
  if M.in_heart(pl, pos[1], pos[3]) then return false end
  local hd = sm.sqrt((pos[1] - pl.cx) * (pos[1] - pl.cx) + (pos[3] - pl.cz) * (pos[3] - pl.cz))
  if hd > pl.R * 0.92 then return false end
  local surf = M.height(pl, pos[1], pos[3])
  if not surf then return false end
  return pos[2] < pl.gy + M.AIR_TOP and pos[2] > surf - 200
end

-- the live planets of the current sector (set by M.activate)
function M.live() return live end

function M.activate(state)
  live = {}
  if not (state and state.sector and state.sector.sites) then return live end
  local game = require("sim.game")
  for i, site in ipairs(state.sector.sites) do
    if site.city then
      local r = game.ruin(i)
      if r and r.city then
        local pl = M.of(r, game.mega_plan(state, i))
        if pl then
          pl.site = i
          live[#live + 1] = pl
        end
      end
    end
  end
  return live
end

function M.clear()
  live = {}
  if saucer.physics and saucer.physics.remove then
    for k, id in pairs(boxes) do saucer.physics.remove(id) end
  end
  boxes = {}
end

-- first live body that has a surface at (x, z), and that height
function M.at(x, z)
  for _, pl in ipairs(live) do
    local y = M.height(pl, x, z)
    if y then return pl, y end
  end
end

function M.support(x, y, z)
  for _, pl in ipairs(live) do
    local s = M.support_of(pl, x, y, z)
    if s then return pl, s end
  end
end

function M.over(pos)
  for _, pl in ipairs(live) do
    if M.in_air(pl, pos) then return pl end
  end
end

-- push a hull up out of the body. -> new pos or the same table
function M.clamp(pos, hh)
  local pl, y = M.support(pos[1], pos[2], pos[3])
  if pl and pos[2] - (hh or 0) < y then
    return { pos[1], y + (hh or 0), pos[3] }
  end
  return pos
end

-- hide the camera-locked gas-giant billboard when this sector already has a planet body
function M.hide_sky_billboard()
  for _, pl in ipairs(live) do
    if pl.body == "planet" then return true end
  end
  return false
end

-- stream coarse surface boxes around every ship (outside the city rim)
function M.sync(state)
  M.activate(state)
  if not (saucer.physics and saucer.physics.add_box) then return end
  local want = {}
  for _, p in ipairs(state.players or {}) do
    local pos = p.ship and p.ship.pos
    if pos then
      for _, pl in ipairs(live) do
        local x0 = math.floor((pos[1] - M.KEEP) / M.CELL)
        local x1 = math.floor((pos[1] + M.KEEP) / M.CELL)
        local z0 = math.floor((pos[3] - M.KEEP) / M.CELL)
        local z1 = math.floor((pos[3] + M.KEEP) / M.CELL)
        for iz = z0, z1 do
          for ix = x0, x1 do
            local x, z = (ix + 0.5) * M.CELL, (iz + 0.5) * M.CELL
            local hd = sm.sqrt((x - pl.cx) * (x - pl.cx) + (z - pl.cz) * (z - pl.cz))
            if hd > pl.rim + M.CELL * 0.4 and hd < pl.R - M.CELL and not M.in_heart(pl, x, z) then
              local y = M.height(pl, x, z)
              if y then
                local key = pl.site .. ":" .. ix .. ":" .. iz
                want[key] = { { x - M.CELL * 0.5, y - M.CRUST, z - M.CELL * 0.5 },
                              { x + M.CELL * 0.5, y, z + M.CELL * 0.5 } }
              end
            end
          end
        end
      end
    end
  end
  for k, id in pairs(boxes) do
    if not want[k] then
      saucer.physics.remove(id)
      boxes[k] = nil
    end
  end
  for k, b in pairs(want) do
    if not boxes[k] then boxes[k] = saucer.physics.add_box(b[1], b[2], 1) end
  end
end

return M
