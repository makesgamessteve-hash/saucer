-- SPDX-License-Identifier: MIT
-- Drawing a running holodeck program (OpenSpec add-holodeck-home-life). The
-- program's props (sim/holo.lua scene) become one mesh per scene, built by
-- one builder per prop kind below; mods can use any of these kinds, or
-- kind = "parts" with raw meshkit parts. Two kinds are drawn live instead:
-- "ruin_model" (a hologram of a derelict you explored, with your route
-- replayed along it) and "sun" (a glowing disc). The holodeck grid shows
-- through wherever you come close to the edge of the simulated space.
local holo = require("sim.holo")
local vec = require("lib.vec")
local sm = saucer.math
local M = {}

local GRID = { 0.95, 0.75, 0.25 }

local function box(x0, y0, z0, x1, y1, z1, color, emissive)
  return { kind = "box", min = { x0, y0, z0 }, max = { x1, y1, z1 }, color = color, emissive = emissive }
end
local function cyl(x, y, z, r, h, color, seg, emissive)
  return { kind = "cylinder", c = { x, y, z }, r = r, h = h, seg = seg or 8, color = color, emissive = emissive }
end
local function sphere(x, y, z, r, color, sx, sy, sz, emissive)
  return { kind = "sphere", c = { 0, 0, 0 }, r = r, h = r, seg = 8, rings = 3, color = color, emissive = emissive,
           pos = { x, y, z }, scale = { sx or 1, sy or 1, sz or 1 } }
end
local function shade(c, f) return { c[1] * f, c[2] * f, c[3] * f } end

M.B = {}
local B = M.B
function B.plane(out, q)
  local w, d = q.w or 10, q.d or 10
  out[#out + 1] = box(q.at[1] - w / 2, (q.y or 0) - 0.05, q.at[2] - d / 2, q.at[1] + w / 2, q.y or 0, q.at[2] + d / 2,
                      q.color or { 0.8, 0.75, 0.6 }, q.emissive)
end
function B.palm(out, q)
  local x, z, h = q.at[1], q.at[2], q.h or 5
  local lean = q.lean or 0.25
  local yaw = q.yaw or 0
  local n = 6
  local tx, tz = 0, 0
  for k = 0, n - 1 do
    local f = k / n
    local ox, oz = sm.sin(yaw) * lean * h * f * f, sm.cos(yaw) * lean * h * f * f
    out[#out + 1] = cyl(x + ox, h * f, z + oz, 0.2 - 0.08 * f, h / n + 0.02, k % 2 == 0 and { 0.55, 0.4, 0.25 } or
                        { 0.48, 0.35, 0.22 }, 6)
    tx, tz = ox, oz
  end
  local top = { x + tx, h, z + tz }
  for k = 0, 6 do
    local a = k * sm.tau / 7 + (q.spin or 0)
    out[#out + 1] = { kind = "wedge", min = { -0.35, -0.04, 0 }, max = { 0.35, 0.04, 2.4 }, low = 0.1,
                      color = k % 2 == 0 and { 0.2, 0.55, 0.22 } or { 0.25, 0.62, 0.25 }, pos = top, yaw = a, pitch = 0.35 }
  end
  out[#out + 1] = sphere(top[1], top[2] - 0.1, top[3], 0.3, { 0.4, 0.3, 0.15 })
end
function B.rock(out, q)
  local r = q.r or 0.8
  out[#out + 1] = sphere(q.at[1], (q.y or 0) + r * 0.3, q.at[2], r, q.color or { 0.5, 0.48, 0.45 }, 1.2, 0.7, 1.0)
end
function B.umbrella(out, q)
  local x, z = q.at[1], q.at[2]
  out[#out + 1] = cyl(x, 0, z, 0.04, 2.3, { 0.9, 0.9, 0.9 }, 6)
  local c = q.color or { 0.95, 0.35, 0.3 }
  out[#out + 1] = { kind = "cone", c = { x, 2.0, z }, r = 1.5, r1 = 0.05, h = 0.55, seg = 10, color = c }
  out[#out + 1] = { kind = "cone", c = { x, 2.01, z }, r = 1.52, r1 = 1.2, h = 0.12, seg = 10, color = { 1, 1, 1 } }
end
function B.deckchair(out, q)
  local x, z, yaw = q.at[1], q.at[2], q.yaw or 0
  local c = q.color or { 0.25, 0.55, 0.85 }
  out[#out + 1] = { kind = "box", min = { -0.35, 0.25, -0.9 }, max = { 0.35, 0.32, 0.2 }, color = c, pos = { x, 0, z }, yaw = yaw }
  out[#out + 1] = { kind = "box", min = { -0.35, 0.0, -0.05 }, max = { 0.35, 0.07, 0.9 }, color = c, pos = { x, 0.3, z },
                    yaw = yaw, pitch = -0.9 }
  for _, s in ipairs({ -0.36, 0.33 }) do
    out[#out + 1] = { kind = "box", min = { s, 0, -0.9 }, max = { s + 0.03, 0.3, 0.2 }, color = { 0.85, 0.75, 0.55 },
                      pos = { x, 0, z }, yaw = yaw }
  end
end
function B.towel(out, q)
  out[#out + 1] = { kind = "box", min = { -0.45, 0, -0.9 }, max = { 0.45, 0.02, 0.9 }, color = q.color or { 0.95, 0.85, 0.3 },
                    pos = { q.at[1], 0.01, q.at[2] }, yaw = q.yaw or 0 }
end
function B.tree(out, q)
  local x, z, h = q.at[1], q.at[2], q.h or 5
  out[#out + 1] = cyl(x, 0, z, 0.22, h * 0.6, { 0.4, 0.28, 0.18 }, 7)
  local c = q.color or { 0.25, 0.5, 0.22 }
  out[#out + 1] = sphere(x, h * 0.7, z, h * 0.3, c, 1, 0.85, 1)
  out[#out + 1] = sphere(x + h * 0.15, h * 0.58, z - h * 0.1, h * 0.22, shade(c, 1.15), 1, 0.8, 1)
  out[#out + 1] = sphere(x - h * 0.14, h * 0.62, z + h * 0.12, h * 0.2, shade(c, 0.85), 1, 0.8, 1)
end
function B.pine(out, q)
  local x, z, h = q.at[1], q.at[2], q.h or 6
  out[#out + 1] = cyl(x, 0, z, 0.18, h * 0.3, { 0.38, 0.26, 0.16 }, 6)
  local c = q.color or { 0.14, 0.38, 0.22 }
  for k = 0, 2 do
    out[#out + 1] = { kind = "cone", c = { x, h * (0.2 + k * 0.24), z }, r = h * (0.26 - k * 0.06), r1 = 0.02, h = h * 0.42,
                      seg = 8, color = shade(c, 1 + k * 0.12) }
  end
end
function B.bush(out, q)
  local r = q.r or 0.6
  out[#out + 1] = sphere(q.at[1], r * 0.6, q.at[2], r, q.color or { 0.25, 0.55, 0.25 }, 1.2, 0.8, 1.1)
end
function B.flower(out, q)
  out[#out + 1] = cyl(q.at[1], 0, q.at[2], 0.015, 0.3, { 0.3, 0.6, 0.3 }, 4)
  out[#out + 1] = sphere(q.at[1], 0.32, q.at[2], 0.07, q.color or { 1, 0.5, 0.8 }, 1, 0.6, 1, 0.3)
end
function B.log(out, q)
  out[#out + 1] = { kind = "cylinder", c = { 0, -1.2, 0 }, r = 0.28, h = 2.4, seg = 8, color = { 0.42, 0.3, 0.2 },
                    pos = { q.at[1], 0.28, q.at[2] }, yaw = q.yaw or 0, pitch = 1.5708 }
  out[#out + 1] = { kind = "box", min = { -0.3, 0.5, -1.0 }, max = { 0.3, 0.56, 1.0 }, color = { 0.3, 0.55, 0.25 },
                    pos = { q.at[1], 0, q.at[2] }, yaw = q.yaw or 0 }
end
function B.water(out, q)
  local w, d = q.w or 40, q.d or 40
  out[#out + 1] = box(q.at[1] - w / 2, (q.y or 0) - 0.3, q.at[2] - d / 2, q.at[1] + w / 2, q.y or -0.05, q.at[2] + d / 2,
                      q.color or { 0.1, 0.45, 0.65 }, q.emissive or 0.15)
end
function B.pillar(out, q)
  local x, z, h = q.at[1], q.at[2], q.h or 4
  local c = q.color or { 0.6, 0.62, 0.7 }
  out[#out + 1] = cyl(x, 0, z, q.r or 0.4, h, c, 8)
  out[#out + 1] = cyl(x, h, z, (q.r or 0.4) * 1.3, 0.25, shade(c, 0.8), 8)
  for k = 1, 3 do
    out[#out + 1] = cyl(x, h * k / 4, z, (q.r or 0.4) * 1.03, 0.08, q.glow or { 0.4, 1, 0.9 }, 8, 1)
  end
end
function B.obelisk(out, q)
  local x, z, h = q.at[1], q.at[2], q.h or 5
  local c = q.color or { 0.2, 0.22, 0.3 }
  out[#out + 1] = { kind = "cone", c = { x, 0, z }, r = 0.8, r1 = 0.35, h = h, seg = 4, color = c }
  out[#out + 1] = { kind = "cone", c = { x, h, z }, r = 0.35, r1 = 0.0, h = 0.6, seg = 4, color = q.glow or { 0.4, 1, 0.9 },
                    emissive = 1 }
  for k = 1, 5 do
    out[#out + 1] = { kind = "cone", c = { x, h * k / 6, z }, r = 0.82 - 0.45 * k / 6 + 0.02, r1 = 0.82 - 0.45 * k / 6 + 0.02,
                      h = 0.05, seg = 4, color = q.glow or { 0.4, 1, 0.9 }, emissive = 1 }
  end
  out[#out + 1] = cyl(x, 0, z, 1.6, 0.15, shade(c, 1.4), 12)
end
function B.ring(out, q)
  -- a vertical ring gate facing +z (or yaw), centre at height y
  -- built from glowing beads in the plane facing yaw (no rotation order to get wrong)
  local r = q.r or 1.5
  local yaw = q.yaw or 0
  local rx, rz = saucer.math.cos(yaw), -saucer.math.sin(yaw)
  local n = 18
  for k = 0, n - 1 do
    local a = k * 6.2832 / n
    local u, w = saucer.math.cos(a) * r, saucer.math.sin(a) * r
    out[#out + 1] = sphere(q.at[1] + rx * u, (q.y or 2) + w, q.at[2] + rz * u, 0.13, q.color or GRID, 1, 1, 1, 1)
  end
end
function B.tower(out, q)
  local x, z, h, w = q.at[1], q.at[2], q.h or 10, q.w or 2
  local c = q.color or { 0.35, 0.3, 0.45 }
  out[#out + 1] = box(x - w / 2, 0, z - w / 2, x + w / 2, h, z + w / 2, c)
  for k = 1, math.floor(h / 1.5) do
    out[#out + 1] = box(x - w / 2 - 0.01, k * 1.5 - 0.3, z - w / 2 + 0.2, x + w / 2 + 0.01, k * 1.5, z + w / 2 - 0.2,
                        q.glow or { 1, 0.8, 0.4 }, 0.8)
  end
  out[#out + 1] = { kind = "cone", c = { x, h, z }, r = w * 0.7, r1 = 0.05, h = w, seg = 6, color = shade(c, 1.3) }
end
function B.lantern(out, q)
  out[#out + 1] = cyl(q.at[1], 0, q.at[2], 0.04, q.h or 1.6, { 0.25, 0.25, 0.28 }, 5)
  out[#out + 1] = box(q.at[1] - 0.14, (q.h or 1.6), q.at[2] - 0.14, q.at[1] + 0.14, (q.h or 1.6) + 0.32, q.at[2] + 0.14,
                      q.color or { 1, 0.8, 0.45 }, 1)
end
function B.crystal(out, q)
  local h = q.h or 1.5
  out[#out + 1] = { kind = "cone", c = { q.at[1], 0, q.at[2] }, r = h * 0.22, r1 = 0.0, h = h, seg = 5,
                    color = q.color or { 0.5, 0.9, 1 }, emissive = 0.8, yaw = q.yaw or 0 }
end
function B.plinth(out, q)
  local r = q.r or 1.2
  out[#out + 1] = cyl(q.at[1], 0, q.at[2], r, q.h or 0.8, q.color or { 0.2, 0.2, 0.26 }, 16)
  out[#out + 1] = cyl(q.at[1], q.h or 0.8, q.at[2], r * 1.02, 0.04, GRID, 16, 1)
end
function B.stream(out, q)
  local w, d = q.w or 2, q.d or 20
  out[#out + 1] = { kind = "box", min = { -w / 2, -0.04, -d / 2 }, max = { w / 2, 0.005, d / 2 }, color = { 0.25, 0.55, 0.75 },
                    emissive = 0.3, pos = { q.at[1], 0, q.at[2] }, yaw = q.yaw or 0 }
end
function B.bench(out, q)
  local yaw = q.yaw or 0
  out[#out + 1] = { kind = "box", min = { -0.9, 0.42, -0.22 }, max = { 0.9, 0.48, 0.22 }, color = q.color or { 0.55, 0.38, 0.24 },
                    pos = { q.at[1], 0, q.at[2] }, yaw = yaw }
  for _, s in ipairs({ -0.75, 0.7 }) do
    out[#out + 1] = { kind = "box", min = { s, 0, -0.2 }, max = { s + 0.05, 0.42, 0.2 }, color = { 0.3, 0.3, 0.32 },
                      pos = { q.at[1], 0, q.at[2] }, yaw = yaw }
  end
end
function B.arch(out, q)
  -- the holodeck's exit arch (always at the start of the space)
  local x, z = q.at[1], q.at[2]
  out[#out + 1] = box(x - 0.85, 0, z - 0.1, x - 0.7, 2.6, z + 0.1, { 0.15, 0.15, 0.18 })
  out[#out + 1] = box(x + 0.7, 0, z - 0.1, x + 0.85, 2.6, z + 0.1, { 0.15, 0.15, 0.18 })
  out[#out + 1] = box(x - 0.85, 2.45, z - 0.1, x + 0.85, 2.6, z + 0.1, { 0.15, 0.15, 0.18 })
  out[#out + 1] = box(x - 0.72, 0, z - 0.11, x - 0.68, 2.44, z + 0.11, GRID, 1)
  out[#out + 1] = box(x + 0.68, 0, z - 0.11, x + 0.72, 2.44, z + 0.11, GRID, 1)
  out[#out + 1] = box(x - 0.72, 2.42, z - 0.11, x + 0.72, 2.46, z + 0.11, GRID, 1)
  out[#out + 1] = box(x - 0.68, 0.0, z - 0.02, x + 0.68, 2.42, z + 0.02, { 0.04, 0.04, 0.06 })
end
function B.parts(out, q)
  local kit = require("lib.meshkit")
  for _, p in ipairs(kit.transform(q.parts or {}, { pos = { q.at[1], q.y or 0, q.at[2] }, yaw = q.yaw or 0 })) do
    out[#out + 1] = p
  end
end

-- the prop list as meshkit parts (unknown kinds and live kinds draw nothing here)
function M.parts(sc)
  local out = {}
  for _, q in ipairs(sc.props) do
    local b = B[q.kind]
    if b and q.at then b(out, q) end
  end
  local a = holo.arch(sc.size)
  B.arch(out, { at = a })
  return out
end

-- the grid: walls of the simulated space (shown near the edge) and the floor
function M.grid_parts(size)
  local out = {}
  local n = math.floor(size * 2 / 1)
  for k = 0, n do
    local t = -size + k * (2 * size) / n
    for _, s in ipairs({ -1, 1 }) do
      out[#out + 1] = box(t - 0.02, 0, s * size - 0.02, t + 0.02, size * 1.2, s * size + 0.02, GRID, 1)
      out[#out + 1] = box(s * size - 0.02, 0, t - 0.02, s * size + 0.02, size * 1.2, t + 0.02, GRID, 1)
    end
  end
  for j = 1, math.floor(size * 1.2) do
    for _, s in ipairs({ -1, 1 }) do
      out[#out + 1] = box(-size, j - 0.02, s * size - 0.02, size, j + 0.02, s * size + 0.02, GRID, 1)
      out[#out + 1] = box(s * size - 0.02, j - 0.02, -size, s * size + 0.02, j + 0.02, size, GRID, 1)
    end
  end
  return out
end

local cache = { scene = {}, grid = {} }
M.cache = cache

function M.scene_mesh(sc)
  local m = cache.scene[sc]
  if m then return m end
  m = saucer.mesh.build({ parts = M.parts(sc) })
  cache.scene[sc] = m
  return m
end

function M.grid_mesh(size)
  local m = cache.grid[size]
  if m then return m end
  m = saucer.mesh.build({ parts = M.grid_parts(size) })
  cache.grid[size] = m
  return m
end

-- how near the edge of the space the eye is: 1 at the wall, 0 from 2.5 m in
function M.edge(size, pos)
  local d = size - math.max(math.abs(pos[1]), math.abs(pos[3]))
  return vec.clamp(1 - d / 2.5, 0, 1)
end

-- a derelict you explored as a tabletop hologram, your route replayed on it
function M.ruin_model(v, A, state, host, q, tick)
  local game = require("sim.game")
  local assets = require("view.assets")
  local site = state.sector.sites[q.site]
  local r = site and game.ruin(q.site)
  if not r then return 0 end
  local lo, hi = table.unpack(game.site_bounds(q.site))
  local c = { (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2 }
  local ext = math.max(hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3])
  local s = (q.fit or 6) / ext
  local base = { q.at[1], (q.y or 1) + (hi[2] - lo[2]) * s / 2, q.at[2] }
  local set = assets.ruin_chunks(r, site.pos)
  local n = 0
  local pos = { base[1] - c[1] * s, base[2] - c[2] * s, base[3] - c[3] * s }
  for _, ch in ipairs(set.chunks) do
    v:mesh(ch.mesh, { pos = pos, scale = s, ghost = true, tint = { 0.35, 0.9, 1, 0.45 } })
    n = n + 1
  end
  local trail = host.trails and host.trails[tostring(q.site)]
  local pts = trail and trail.pts or {}
  local function to_model(w) return { base[1] + (w[1] - c[1]) * s, base[2] + (w[2] - c[2]) * s, base[3] + (w[3] - c[3]) * s } end
  for i = 1, #pts, math.max(1, #pts // 80) do
    v:billboard(A.tex.glow, to_model(pts[i]), 0.12, { palette = A.pal.base, tint = { 1, 0.8, 0.3, 0.8 } })
    n = n + 1
  end
  for _, mk in ipairs(trail and trail.marks or {}) do
    v:billboard(A.tex.loot, to_model(mk), 0.3, { palette = A.pal.base, tint = { 0.6, 1, 0.6, 1 } })
    n = n + 1
  end
  if #pts > 1 then
    -- the replay: a little saucer glides along your route, ten seconds a lap
    local f = (tick % 600) / 600 * (#pts - 1)
    local i = math.floor(f) + 1
    local a, b = pts[i], pts[math.min(#pts, i + 1)]
    local t = f - math.floor(f)
    local w = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
    v:mesh(A.saucer[1].hull, { pos = to_model(w), scale = math.max(s * 4, 0.02), ghost = true,
                               tint = { 1, 0.85, 0.4, 0.9 } })
    v:billboard(A.tex.glow, to_model(w), 0.35, { palette = A.pal.base, tint = { 1, 0.9, 0.5, 1 } })
    n = n + 1
  end
  return n
end

-- render(v, state, p): the camera, sky, the scene and live props
function M.render(v, state, p)
  local assets = require("view.assets")
  local A = assets.init()
  local host = holo.host(state, p)
  if not host or not host.holo_run then return 0 end
  local run = host.holo_run
  local pr = holo.program(run.id) or {}
  local sc = holo.scene(state, host, run)
  local look = pr.look or {}
  local eye, yaw, pitch = holo.viewpoint(state, p)
  v:camera({ pos = eye, yaw = yaw, pitch = pitch, fov = 75, near = 0.05, far = 600 })
  local sky = look.sky or { 0.4, 0.6, 0.9 }
  v:fog({ color = look.fog or sky, density = look.density or 0.02, clear = sky, light = look.light or { 0.4, 0.8, 0.3 },
          ambient = look.ambient or 0.6 })
  if look.stars then v:mesh(A.stars, { pos = eye, sky = true }) end
  v:mesh(M.scene_mesh(sc), {})
  local n = 1
  for _, q in ipairs(sc.props) do
    if q.kind == "sun" then
      v:billboard(A.tex.glow, { q.at[1], q.y or 30, q.at[2] }, q.r or 30, { palette = A.pal.base, tint = q.color or { 1, 0.85, 0.5, 1 } })
      n = n + 1
    elseif q.kind == "ruin_model" then
      n = n + M.ruin_model(v, A, state, host, q, state.tick)
    elseif q.kind == "glyph" then
      local bob = 0.2 * sm.sin((state.tick % 3600) * 0.03 + q.at[1])
      v:billboard(A.tex.echo, { q.at[1], (q.y or 2) + bob, q.at[2] }, q.r or 0.6, { palette = A.pal.base, tint = q.color })
      n = n + 1
    end
  end
  -- rings still ahead glow brighter; the next one pulses
  if p.holo_run.craft then
    for i, g in ipairs(sc.gates) do
      if i >= p.holo_run.gate then
        local pulse = i == p.holo_run.gate and (0.7 + 0.3 * sm.sin(state.tick * 0.2)) or 0.35
        v:billboard(A.tex.glow, { g[1], g[2], g[3] }, (g.r or 1.5) * 0.6, { palette = A.pal.base, tint = { 1, 0.85, 0.3, pulse } })
        n = n + 1
      end
    end
    local c = p.holo_run.craft
    v:mesh(A.saucer[c.size].hull, { pos = c.pos, yaw = c.yaw, roll = c.bank or 0, tex = A.tex.hull, palette = A.pal.base })
    n = n + 1
  end
  -- other people in the same program
  for _, o in ipairs(state.players) do
    if o ~= p and o.holo_run and holo.host(state, o) == host and o.holo_run.body then
      v:mesh(A.person, { pos = o.holo_run.body.pos, yaw = o.holo_run.body.yaw })
      n = n + 1
    end
  end
  -- the grid shimmers through near the edge of the simulated space
  local e = M.edge(sc.size, eye)
  if e > 0 then
    v:mesh(M.grid_mesh(sc.size), { ghost = true, tint = { 1, 0.85, 0.4, 0.25 + 0.6 * e } })
    n = n + 1
  end
  return n
end

return M
