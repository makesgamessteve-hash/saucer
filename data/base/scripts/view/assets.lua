-- SPDX-License-Identifier: MIT
-- Render-side asset cache: meshes built from recipes, textures and palettes
-- loaded through the VFS. Nothing here is simulation state.
local kit = require("lib.meshkit")
local configs = require("sim.config")
local ruinm = require("sim.ruin")
local detail = require("view.detail")
local M = {}

local cache = { saucer = {}, ruin = {} }
M.cache = cache

function M.palette(name) return saucer.render.palette(name) end
function M.texture(path) return saucer.render.texture(path) end

function M.init()
  if cache.ready then return cache end
  cache.pal = {
    base = M.palette("authored/palettes/base.png"),
  }
  cache.tex = {
    hull = M.texture("generated/textures/hull_plating.png"),
    nebula = M.texture("generated/textures/nebula.png"),
    loot = M.texture("authored/sprites/loot.png"),
    echo = M.texture("authored/sprites/echo.png"),
    beam = M.texture("authored/sprites/beam.png"),
    glow = M.texture("authored/sprites/glow.png"),
    -- add-detail-pass: one wall material per derelict kit
    kit_starship = M.texture("generated/textures/kit_starship.png"),
    kit_station = M.texture("generated/textures/kit_station.png"),
    kit_city = M.texture("generated/textures/kit_city.png"),
  }
  cache.stars = saucer.mesh.build({ parts = { { kind = "stars", count = 1400, r = 900, size = 2.2, seed = 7 } } })
  cache.station = kit.build("station", {}, 11)
  cache.cache_mesh = kit.build("loot_cache", { size = 1 }, 1)
  -- milestone 3: sentries, nests and the Resonant vault (closed and open)
  cache.watcher = kit.build("sentry", { kind = "watcher" }, 1)
  cache.snatcher = kit.build("sentry", { kind = "snatcher" }, 1)
  cache.nest = kit.build("sentry", { kind = "nest" }, 1)
  cache.vault = kit.build("sentry", { kind = "vault", open = 0 }, 1)
  cache.vault_open = kit.build("sentry", { kind = "vault", open = 1 }, 1)
  for i, c in ipairs(configs.all()) do
    local hull = kit.build("saucer", { diameter = c.diameter, height = c.height, part = "hull", config = c.id }, 1)
    local dome = kit.build("saucer", { diameter = c.diameter, height = c.height, part = "dome", config = c.id }, 1)
    cache.saucer[i] = { hull = hull, dome = dome }
  end
  -- the Villa's walkable interior and its glass dome (hull-local, see saucer/interior.lua)
  cache.interior = kit.build("interior", { part = "rooms" }, 1)
  cache.glass = kit.build("interior", { part = "glass" }, 1)
  -- add-tractor-beam: the Tractor Room's floor window, the beam cone (apex at
  -- the origin, opening downward, unit height and radius) and an iris leaf
  cache.belly_glass = kit.build("interior", { part = "belly_glass" }, 1)
  cache.beam_cone = saucer.mesh.build({ parts = {
    { kind = "cone", c = { 0, -1, 0 }, r = 1, r1 = 0.02, h = 1, seg = 20, color = { 1, 1, 1 }, emissive = 1, open = true },
  } })
  cache.iris_leaf = saucer.mesh.build({ parts = {
    { kind = "box", min = { -0.4, 0, 0 }, max = { 0.4, 0.05, 0.74 }, color = { 0.55, 0.57, 0.64 } },
    { kind = "box", min = { -0.3, -0.005, 0.6 }, max = { 0.3, 0.0, 0.66 }, color = { 0.95, 0.75, 0.1 }, emissive = 0.5 },
  } })
  cache.person = kit.build("person", {}, 1)
  -- milestone 2: one mesh per fold group so rooms can pack away one by one,
  -- the sliding door leaves, and a white unit cube for live console readouts
  local fold = require("sim.fold")
  local avatar = require("sim.avatar")
  local L = avatar.layout()
  cache.groups = {}
  for _, g in ipairs(fold.groups(L)) do
    cache.groups[g.id] = kit.build("interior", { part = "group", group = g.id }, 1)
  end
  cache.doors = {}
  for i, d in ipairs(L.doors or {}) do cache.doors[i] = kit.build("interior", { part = "door", door = d.id }, 1) end
  -- add-detail-pass: the engine's spinning rotor ring and a piston, and the
  -- thruster layout the renderer hangs glow sprites on
  local rotor = { { kind = "ring", c = { 0, -0.04, 0 }, rin = 1.18, r = 1.32, h = 0.08, seg = 20, color = { 0.8, 0.62, 0.22 } } }
  for k = 0, 3 do
    local a = k * saucer.math.tau / 4
    rotor[#rotor + 1] = { kind = "box", min = { -0.09, -0.07, 1.14 }, max = { 0.09, 0.07, 1.4 }, yaw = a,
                          color = { 0.35, 0.9, 1.0 }, emissive = 1 }
  end
  cache.engine_rotor = saucer.mesh.build({ parts = rotor })
  cache.piston = saucer.mesh.build({ parts = {
    { kind = "cylinder", c = { 0, 0, 0 }, r = 0.05, h = 1.1, seg = 6, color = { 0.75, 0.78, 0.82 } },
    { kind = "box", min = { -0.1, 1.1, -0.1 }, max = { 0.1, 1.3, 0.1 }, color = { 0.8, 0.62, 0.22 } },
  } })
  cache.thrusters = require("lib.data").load("meshes/saucer.lua").THRUSTERS
  cache.unit = saucer.mesh.build({ parts = { { kind = "box", min = { -0.5, -0.5, -0.5 }, max = { 0.5, 0.5, 0.5 },
                                              color = { 1, 1, 1 }, emissive = 1 } } })
  cache.ready = true
  return cache
end

-- True 3D derelicts are drawn in chunks (one per room, one per exterior
-- solid) so the renderer can cull what is behind the camera or outside the
-- view, plus one coarse silhouette mesh per site for when it is far away
-- (render.lua picks). All keyed by the layout hash; nothing here is sim state.
local GLOW, RIB = { 0.4, 1.0, 0.8 }, { 0.42, 0.44, 0.5 }

local function overlaps(a0, a1, b0, b1, pad) return a0 < b1 + (pad or 0) and a1 > b0 - (pad or 0) end

-- is there a room sitting right on top of r (no antennas poking into it)?
local function covered(ruin, r)
  for _, q in ipairs(ruin.rooms) do
    if q.cell[2] == r.cell[2] + r.size[2] and overlaps(q.cell[1], q.cell[1] + q.size[1], r.cell[1], r.cell[1] + r.size[1])
        and overlaps(q.cell[3], q.cell[3] + q.size[3], r.cell[3], r.cell[3] + r.size[3]) then
      return true
    end
  end
  return false
end

-- decoration for one room: light strips, hall ribs, shaft rings and level
-- markers, exterior greebles. -> list of mesh parts
function M.room_decor(ruin, r, k, origin)
  local parts = {}
  local function box(mn, mx, color, extra)
    local p = { kind = "box", min = mn, max = mx, color = color, uv = 0.5 }
    if extra then p.emissive = 1 end
    parts[#parts + 1] = p
  end
  local mn, mx = ruinm.room_box(r, k, origin)
  local t = k.wall
  local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
  local hole = {}
  for _, f in ipairs(ruinm.FACES) do
    hole[ruinm.face_name(f[1], f[2])] = ruinm.face_holes(r, ruin.doors, ruin.rooms, k, origin, f[1], f[2])
  end
  local hatch = #hole["+y"] > 0
  local function clear_of(list, u0, u1, v0, v1)
    for _, h in ipairs(list) do
      if overlaps(u0, u1, h[1], h[2], 1) and overlaps(v0, v1, h[3], h[4], 1) then return false end
    end
    return true
  end
  if not hatch then
    -- ceiling light strip
    box({ cx - 0.3, mx[2] - t - 0.12, mn[3] + 1 }, { cx + 0.3, mx[2] - t, mx[3] - 1 }, GLOW, true)
  end
  if r.kind == "shaft" then
    -- rings every 12 m up the shaft with glowing level markers: reads well looking up or down
    local y = mn[2] + 8
    while y < mx[2] - 4 do
      for _, f in ipairs({ { 1, -1 }, { 1, 1 }, { 3, -1 }, { 3, 1 } }) do
        local axis, sign = f[1], f[2]
        local l = ruinm.lateral(axis)
        local name = ruinm.face_name(axis, sign)
        if clear_of(hole[name], mn[l], mx[l], y - 0.6, y + 0.6) then
          local bmn, bmx = {}, {}
          local a0 = sign < 0 and mn[axis] + t or mx[axis] - t - 1.0
          bmn[axis], bmx[axis] = a0, a0 + 1.0
          bmn[l], bmx[l] = mn[l] + t, mx[l] - t
          bmn[2], bmx[2] = y - 0.6, y + 0.6
          box(bmn, bmx, RIB)
          local gmn, gmx = { bmn[1], bmn[2], bmn[3] }, { bmx[1], bmx[2], bmx[3] }
          gmn[2], gmx[2] = y + 0.6, y + 0.85
          local mid = (mn[l] + mx[l]) / 2
          gmn[l], gmx[l] = mid - 3, mid + 3
          box(gmn, gmx, { 1.0, 0.7, 0.3 }, true)
        end
      end
      y = y + 12
    end
  elseif r.class >= (k.big or 4) then
    -- great halls: structural ribs down the walls and across the ceiling, glow strips
    local z = mn[3] + 6
    while z < mx[3] - 4 do
      if not hatch or clear_of(hole["+y"], mn[1], mx[1], z - 0.6, z + 0.6) then
        box({ mn[1] + t, mx[2] - t - 1.2, z - 0.6 }, { mx[1] - t, mx[2] - t, z + 0.6 }, RIB)
      end
      for _, side in ipairs({ -1, 1 }) do
        if clear_of(hole[side < 0 and "-x" or "+x"], z - 0.6, z + 0.6, mn[2], mx[2]) then
          local x0 = side < 0 and mn[1] + t or mx[1] - t - 1.2
          box({ x0, mn[2] + t, z - 0.6 }, { x0 + 1.2, mx[2] - t, z + 0.6 }, RIB)
          box({ x0 + (side < 0 and 1.2 or -0.1), mn[2] + 6, z - 0.15 }, { x0 + (side < 0 and 1.3 or 0), mn[2] + 14, z + 0.15 },
            GLOW, true)
        end
      end
      z = z + 8
    end
  end
  -- exterior running lights: window rows on blank outer walls and corner
  -- beacons, so a derelict reads from above, below and far away
  local win = k.window_color or { 0.55, 0.9, 1.0 }
  for _, f in ipairs({ { 1, -1 }, { 1, 1 }, { 3, -1 }, { 3, 1 } }) do
    local axis, sign = f[1], f[2]
    local l = ruinm.lateral(axis)
    local name = ruinm.face_name(axis, sign)
    if #hole[name] == 0 and (r.class >= (k.big or 4)) then
      local a0 = sign < 0 and mn[axis] - 0.25 or mx[axis]
      local rows = {}
      if r.kind == "shaft" then
        local y = mn[2] + 6
        while y < mx[2] - 4 do rows[#rows + 1] = y y = y + 8 end
      else
        rows = { mn[2] + (mx[2] - mn[2]) * 0.62 }
      end
      for _, y in ipairs(rows) do
        local u = mn[l] + 4
        while u < mx[l] - 4 do
          local bmn, bmx = {}, {}
          bmn[axis], bmx[axis] = a0, a0 + 0.25
          bmn[l], bmx[l] = u, u + 2.2
          bmn[2], bmx[2] = y, y + 1.1
          box(bmn, bmx, win, true)
          u = u + (r.kind == "shaft" and 14 or 6)
        end
      end
    end
  end
  -- belly lights: strips under the floor of big rooms (so the underside reads when you fly below)
  if r.class >= (k.big or 4) and #hole["-y"] == 0 then
    local z = mn[3] + 8
    while z < mx[3] - 6 do
      box({ mn[1] + 4, mn[2] - 0.3, z - 0.4 }, { mx[1] - 4, mn[2], z + 0.4 }, win, true)
      z = z + 16
    end
  end
  for _, cx0 in ipairs({ mn[1], mx[1] }) do
    for _, cz0 in ipairs({ mn[3], mx[3] }) do
      box({ cx0 - 0.6, mn[2] - 0.6, cz0 - 0.6 }, { cx0 + 0.6, mn[2] + 0.6, cz0 + 0.6 }, { 1, 0.3, 0.25 }, true)
      box({ cx0 - 0.5, mx[2] - 0.5, cz0 - 0.5 }, { cx0 + 0.5, mx[2] + 0.5, cz0 + 0.5 }, { 1, 1, 0.9 }, true)
    end
  end
  if not covered(ruin, r) then
    local g = kit.recipe("derelict_greeble", { w = mx[1] - mn[1], d = mx[3] - mn[3], top = mx[2] - mn[2] },
                         saucer.seed_child(ruin.seed, "greeble", r.id))
    for _, p in ipairs(kit.transform(g.parts, { pos = { cx, mn[2], cz } })) do parts[#parts + 1] = p end
  end
  return parts
end

-- exterior solid: plain block plus lit window bands (towers) or tip beacons.
-- A tower hanging under the city points its mast down (hanging = true).
function M.solid_parts(s, k, hanging)
  local mn, mx = s[1], s[2]
  local parts = { { kind = "box", min = mn, max = mx, color = k.solid_color or k.color, uv = 0.25 } }
  if s.kind == "tower" then
    -- lit floors every 6 m, a dark gap every fourth floor, and a beacon on top
    local win = k.window_color or { 1.0, 0.85, 0.5 }
    local y, n = mn[2] + 3, 0
    while y < mx[2] - 2 do
      n = n + 1
      if n % 4 ~= 0 then
        parts[#parts + 1] = { kind = "box", min = { mn[1] - 0.15, y, mn[3] - 0.15 }, max = { mx[1] + 0.15, y + 1.2, mx[3] + 0.15 },
                              color = win, emissive = 1 }
      end
      y = y + 6
    end
    local c = { (mn[1] + mx[1]) / 2, hanging and mn[2] or mx[2], (mn[3] + mx[3]) / 2 }
    local d = hanging and -1 or 1
    parts[#parts + 1] = { kind = "box", min = { c[1] - 0.25, math.min(c[2], c[2] + 9 * d), c[3] - 0.25 },
                          max = { c[1] + 0.25, math.max(c[2], c[2] + 9 * d), c[3] + 0.25 }, color = { 0.5, 0.5, 0.55 } }
    parts[#parts + 1] = { kind = "box", min = { c[1] - 0.8, math.min(c[2] + 9 * d, c[2] + 10.6 * d), c[3] - 0.8 },
                          max = { c[1] + 0.8, math.max(c[2] + 9 * d, c[2] + 10.6 * d), c[3] + 0.8 }, color = { 1, 0.3, 0.25 },
                          emissive = 1 }
  else
    local c = { (mn[1] + mx[1]) / 2, mx[2], (mn[3] + mx[3]) / 2 }
    parts[#parts + 1] = { kind = "box", min = { c[1] - 0.6, c[2], c[3] - 0.6 }, max = { c[1] + 0.6, c[2] + 1.2, c[3] + 0.6 },
                          color = { 1, 0.3, 0.2 }, emissive = 1 }
  end
  return parts
end

local function sphere_of(parts)
  local lo, hi = { 1e30, 1e30, 1e30 }, { -1e30, -1e30, -1e30 }
  for _, p in ipairs(parts) do
    for a = 1, 3 do
      if p.min and p.min[a] < lo[a] then lo[a] = p.min[a] end
      if p.max and p.max[a] > hi[a] then hi[a] = p.max[a] end
    end
  end
  local c = { (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2 }
  local dx, dy, dz = hi[1] - c[1], hi[2] - c[2], hi[3] - c[3]
  return c, saucer.math.sqrt(dx * dx + dy * dy + dz * dz) + 12 -- + greebles and antennas
end

-- -> { chunks = { { mesh, center, radius, room } ... }, lod = { mesh, center, radius } }
function M.ruin_chunks(ruin, origin)
  local hit = cache.chunks and cache.chunks[ruin.hash]
  if hit then return hit end
  cache.chunks = cache.chunks or {}
  local k = ruinm.kit_of(ruin.kit)
  local by_room = {}
  for _, r in ipairs(ruin.rooms) do by_room[r.id] = {} end
  local function add(list, b, color, uv)
    list[#list + 1] = { kind = "box", min = b[1], max = b[2], color = color, uv = uv }
  end
  for _, b in ipairs(ruin.walls) do add(by_room[b.room or 1], b, k.color, k.uv or 0.25) end
  for _, b in ipairs(ruin.debris) do add(by_room[b.room or 1], b, { 0.55, 0.45, 0.32 }, 0.5) end
  local out = { chunks = {} }
  local coarse = {}
  for _, r in ipairs(ruin.rooms) do
    local parts = by_room[r.id]
    for _, p in ipairs(M.room_decor(ruin, r, k, origin)) do parts[#parts + 1] = p end
    local c, rad = sphere_of(parts)
    out.chunks[#out.chunks + 1] = { mesh = saucer.mesh.build({ parts = parts }), center = c, radius = rad, room = r.id }
    local mn, mx = ruinm.room_box(r, k, origin)
    coarse[#coarse + 1] = { kind = "box", min = mn, max = mx, color = k.color, uv = 0.25 }
  end
  for i, s in ipairs(ruin.solids or {}) do
    local parts = M.solid_parts(s, k, detail.hanging(ruin, s, k, origin))
    local c, rad = sphere_of(parts)
    out.chunks[#out.chunks + 1] = { mesh = saucer.mesh.build({ parts = parts }), center = c, radius = rad, solid = i }
    coarse[#coarse + 1] = { kind = "box", min = s[1], max = s[2], color = k.solid_color or k.color, uv = 0.25 }
  end
  local c, rad = sphere_of(coarse)
  out.lod = { mesh = saucer.mesh.build({ parts = coarse }), center = c, radius = rad }
  -- add-detail-pass: per-chunk detail meshes are built on demand (first time
  -- the camera comes near, see M.chunk_detail); city sky bridges get a chunk
  out.ruin, out.origin, out.kit = ruin, origin, k
  if k.id == "city" then out.links = { center = c, radius = rad, links = true } end
  cache.chunks[ruin.hash] = out
  return out
end

-- the detail parts of one chunk of a chunk set (a room, a solid or the links)
function M.detail_parts(set, ch)
  if ch.links then return (detail.links(set.ruin, set.kit)) end
  if ch.solid then return (detail.solid(set.ruin, set.ruin.solids[ch.solid], ch.solid, set.kit, set.origin)) end
  return (detail.room(set.ruin, set.ruin.rooms[ch.room], set.kit, set.origin))
end

-- the chunk's detail mesh, built the first time it is asked for (false when
-- the chunk has no detail). Not sim state: only the renderer calls this.
function M.chunk_detail(set, ch)
  if ch.detail == nil then
    local parts = M.detail_parts(set, ch)
    ch.detail = #parts > 0 and saucer.mesh.build({ parts = parts }) or false
    ch.detail_parts = #parts
  end
  return ch.detail
end

-- the kit's wall material (falls back to the shared hull plating)
function M.kit_texture(A, k)
  return A.tex["kit_" .. (k and k.id or "")] or A.tex.hull
end

-- one mesh for a whole derelict (kept for mods and tools; the game draws chunks)
function M.ruin_mesh(ruin, origin)
  local m = cache.ruin[ruin.hash]
  if m then return m end
  local k = ruinm.kit_of(ruin.kit)
  local parts = {}
  for _, b in ipairs(ruin.walls) do parts[#parts + 1] = { kind = "box", min = b[1], max = b[2], color = k.color, uv = 0.25 } end
  for _, b in ipairs(ruin.debris) do
    parts[#parts + 1] = { kind = "box", min = b[1], max = b[2], color = { 0.55, 0.45, 0.32 }, uv = 0.5 }
  end
  for _, r in ipairs(ruin.rooms) do
    for _, p in ipairs(M.room_decor(ruin, r, k, origin)) do parts[#parts + 1] = p end
  end
  for _, s in ipairs(ruin.solids or {}) do
    for _, p in ipairs(M.solid_parts(s, k)) do parts[#parts + 1] = p end
  end
  m = saucer.mesh.build({ parts = parts })
  cache.ruin[ruin.hash] = m
  return m
end

return M
