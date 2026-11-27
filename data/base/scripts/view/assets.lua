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

-- the rig of a recipe, built once per (recipe, params, seed) -> rig (see lib/meshkit.lua)
function M.rig(A, id, params, seed)
  -- nested tables, not a built key: the renderer asks for every sentry every frame
  local a = A.rigs[id]
  if not a then a = {}; A.rigs[id] = a end
  local kind = params.kind or ""
  local b = a[kind]
  if not b then b = {}; a[kind] = b end
  local r = b[seed]
  if not r then
    r = kit.rig(id, params, seed)
    b[seed] = r
  end
  return r
end

function M.palette(name) return saucer.render.palette(name) end

-- add-presentation-packaging: every texture of the art pass (see tools/artpipe)
M.ART_TEXTURES = {
  "mat_wood", "mat_fabric", "mat_tile", "mat_floor", "mat_metal", "mat_panel",
  "floor_starship", "floor_station", "floor_city", "station_hall",
  "nebula_b", "planet", "galaxy",
  "folk_1", "folk_2", "folk_3", "folk_4", "sign_food", "sign_scrap", "sign_gems", "sign_bar", "glyphs", "title_emblem",
}
M.MATS = { "wood", "fabric", "tile", "floor", "metal", "panel" }

-- a recipe whose parts carry mat tags -> the mesh of the untagged parts and a
-- list of { mat = name, mesh = id } (one mesh per material that is used)
function M.split_mats(recipe)
  local by, base = {}, {}
  for _, p in ipairs(recipe.parts) do
    if p.mat then
      by[p.mat] = by[p.mat] or {}
      local list = by[p.mat]
      list[#list + 1] = p
    else
      base[#base + 1] = p
    end
  end
  local mats = {}
  for _, m in ipairs(M.MATS) do
    if by[m] then mats[#mats + 1] = { mat = m, mesh = saucer.mesh.build({ parts = by[m] }) } end
  end
  return saucer.mesh.build({ parts = base }), mats
end
function M.texture(path, opts) return saucer.render.texture(path, opts) end

function M.init()
  if cache.ready then return cache end
  cache.pal = {
    base = M.palette("authored/palettes/base.png"),
  }
  -- add-presentation-packaging: the art pass palettes (one 256-colour row each)
  cache.pal.interior = M.palette("authored/palettes/interior.png")
  cache.pal.kits = M.palette("authored/palettes/kits.png")
  cache.pal.sky = M.palette("authored/palettes/sky.png")
  cache.pal.sprites = M.palette("authored/palettes/sprites.png")
  cache.tex = {
    hull = M.texture("generated/textures/hull_plating.png"),
    nebula = M.texture("generated/textures/nebula.png"),
    loot = M.texture("authored/sprites/loot.png"),
    echo = M.texture("authored/sprites/echo.png"),
    beam = M.texture("authored/sprites/beam.png"),
    -- soft: a leftover disk fallback (fix-glow: palette texels read as dark blocks). New draws go through
    -- view/sprites.lua with an explicit form (flare, shard, ring, ...).
    glow = M.texture("authored/sprites/glow.png", { soft = true }),
    -- add-detail-pass: one wall material per derelict kit
    kit_starship = M.texture("generated/textures/kit_starship.png"),
    kit_station = M.texture("generated/textures/kit_station.png"),
    kit_city = M.texture("generated/textures/kit_city.png"),
  }
  for _, id in ipairs(M.ART_TEXTURES) do cache.tex[id] = M.texture("generated/textures/" .. id .. ".png") end
  cache.decal = saucer.mesh.build({ parts = { { kind = "box", min = { 0, 0, 0 }, max = { 1, 1, 0.02 }, color = { 1, 1, 1 },
                                                uv = 1, emissive = 0.6 } } })
  cache.stars = saucer.mesh.build({ parts = { { kind = "stars", count = 1400, r = 900, size = 2.2, seed = 7 } } })
  cache.cache_mesh = kit.build("loot_cache", { size = 1 }, 1)
  -- milestone 3: sentries, nests and the Resonant vault (closed and open)
  -- add-mesh-builder: rigs (a base mesh, named nodes to animate, declared collision volumes); the
  -- builder civ's glyph is the seed, so each civ has its own Watchers and Snatchers (M.rig)
  cache.rigs = {}
  cache.watcher = M.rig(cache, "watcher", {}, 1)
  cache.snatcher = M.rig(cache, "snatcher", {}, 1)
  cache.lever = M.rig(cache, "cockpit", { kind = "lever" }, 1)
  cache.orb = M.rig(cache, "cockpit", { kind = "orb" }, 1)
  cache.nest = kit.build("sentry", { kind = "nest" }, 1)
  cache.vault = kit.build("sentry", { kind = "vault", open = 0 }, 1)
  cache.vault_open = kit.build("sentry", { kind = "vault", open = 1 }, 1)
  -- add-wider-dark: the Clamp (a squat grabber with four claws), the Lockdown
  -- node, a door seal (a unit slab scaled to the door), a decoy, a gift
  -- capsule and the Heart's core
  local claws = { { kind = "sphere", c = { 0, 0, 0 }, r = 1.3, h = 1.3, seg = 10, rings = 3, color = { 0.42, 0.36, 0.3 } },
                  { kind = "ring", c = { 0, -0.2, 0 }, rin = 1.0, r = 1.55, h = 0.3, seg = 14, color = { 0.9, 0.5, 0.1 },
                    emissive = 0.7 } }
  for k = 0, 3 do
    local a = k * saucer.math.tau / 4
    local x, z = math.sin(a) * 1.4, math.cos(a) * 1.4
    claws[#claws + 1] = { kind = "box", min = { x - 0.18, -1.8, z - 0.18 }, max = { x + 0.18, -0.2, z + 0.18 },
                          color = { 0.6, 0.55, 0.5 } }
  end
  cache.clamp = saucer.mesh.build({ parts = claws })
  cache.lockdown = saucer.mesh.build({ parts = {
    { kind = "cylinder", c = { 0, -1, 0 }, r = 0.7, h = 2, seg = 8, color = { 0.35, 0.36, 0.42 } },
    { kind = "ring", c = { 0, 0.3, 0 }, rin = 0.75, r = 1.05, h = 0.25, seg = 12, color = { 1, 0.25, 0.2 }, emissive = 0.8 },
    { kind = "sphere", c = { 0, 1.1, 0 }, r = 0.35, h = 0.35, seg = 8, rings = 2, color = { 1, 0.3, 0.2 }, emissive = 1 },
  } })
  -- add-home-among-stars: the Warden - a tall armoured hunter with a red eye ring
  cache.warden = saucer.mesh.build({ parts = {
    { kind = "cylinder", c = { 0, -2.2, 0 }, r = 1.6, h = 3.4, seg = 8, color = { 0.28, 0.27, 0.33 } },
    { kind = "sphere", c = { 0, 1.4, 0 }, r = 1.5, h = 1.1, seg = 10, rings = 3, color = { 0.4, 0.38, 0.45 } },
    { kind = "ring", c = { 0, 1.2, 0 }, rin = 1.45, r = 1.9, h = 0.35, seg = 16, color = { 1, 0.15, 0.1 }, emissive = 1 },
    { kind = "box", min = { -2.4, -0.6, -0.25 }, max = { -1.5, 0.4, 0.25 }, color = { 0.55, 0.5, 0.45 } },
    { kind = "box", min = { 1.5, -0.6, -0.25 }, max = { 2.4, 0.4, 0.25 }, color = { 0.55, 0.5, 0.45 } },
  } })
  cache.seal = saucer.mesh.build({ parts = {
    { kind = "box", min = { 0, 0, 0 }, max = { 1, 1, 1 }, color = { 1, 0.3, 0.2 }, emissive = 0.8 },
  } })
  cache.decoy = saucer.mesh.build({ parts = {
    { kind = "sphere", c = { 0, 0, 0 }, r = 0.6, h = 0.25, seg = 10, rings = 2, color = { 0.7, 0.75, 0.85 } },
    { kind = "ring", c = { 0, -0.05, 0 }, rin = 0.5, r = 0.9, h = 0.1, seg = 12, color = { 0.4, 0.9, 1 }, emissive = 1 },
  } })
  cache.gift = saucer.mesh.build({ parts = {
    { kind = "box", min = { -0.6, -0.6, -0.6 }, max = { 0.6, 0.6, 0.6 }, color = { 0.85, 0.3, 0.55 } },
    { kind = "box", min = { -0.65, -0.12, -0.65 }, max = { 0.65, 0.12, 0.65 }, color = { 1, 0.85, 0.3 }, emissive = 0.6 },
  } })
  cache.heart_core = saucer.mesh.build({ parts = {
    { kind = "sphere", c = { 0, 0, 0 }, r = 3.2, h = 3.2, seg = 14, rings = 5, color = { 0.95, 0.25, 0.45 }, emissive = 0.9 },
    { kind = "ring", c = { 0, 0, 0 }, rin = 4.2, r = 5.0, h = 0.3, seg = 24, color = { 1, 0.75, 0.4 }, emissive = 1 },
  } })
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
  -- add-pocket-station-visits: station folk (one mesh per species) and your hand
  cache.npc = {}
  for i, sp in ipairs(require("sim.stationgen").folk().species) do
    cache.npc[i] = kit.build("npc", { skin = sp.skin, suit = sp.suit, head = sp.head, tall = sp.tall, glow = sp.glow }, i)
  end
  cache.hand = kit.build("hand", {}, 1)
  -- milestone 2: one mesh per fold group so rooms can pack away one by one,
  -- the sliding door leaves, and a white unit cube for live console readouts
  local fold = require("sim.fold")
  local avatar = require("sim.avatar")
  local L = avatar.layout()
  cache.groups = {}
  cache.group_mats = {}
  for _, g in ipairs(fold.groups(L)) do
    cache.groups[g.id], cache.group_mats[g.id] = M.split_mats(kit.recipe("interior", { part = "group", group = g.id }, 1))
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
  -- add-on-foot-excursions: the strongroom shutter, a hand-lock coupling and
  -- a grid console (all facing +z, sized in meters; the shutter is a unit slab)
  cache.foot = M.foot_meshes()
  cache.ready = true
  return cache
end

-- add-on-foot-excursions: code-built props for the on-foot features
function M.foot_parts()
  local DARK, PLATE, HAZ, BRASS = { 0.2, 0.22, 0.26 }, { 0.5, 0.52, 0.56 }, { 0.95, 0.72, 0.12 }, { 0.78, 0.6, 0.25 }
  local shutter = { { kind = "box", min = { -0.5, -0.5, -0.5 }, max = { 0.5, 0.5, 0.5 }, color = PLATE } }
  for k = 0, 4 do
    local y = -0.42 + k * 0.2
    shutter[#shutter + 1] = { kind = "box", min = { -0.48, y, -0.52 }, max = { 0.48, y + 0.06, 0.52 },
                              color = k % 2 == 0 and HAZ or DARK }
  end
  local lock = {
    { kind = "box", min = { -0.45, -0.45, -0.08 }, max = { 0.45, 0.45, 0.0 }, color = DARK },
    { kind = "box", min = { -0.38, -0.38, 0.0 }, max = { 0.38, 0.38, 0.04 }, color = PLATE },
    { kind = "cylinder", c = { 0, -0.06, 0.1 }, r = 0.08, h = 0.12, seg = 8, color = BRASS },
  }
  -- the coupling's wheel: a square rim and two spokes
  for _, b in ipairs({ { -0.28, 0.24, 0.28, 0.28 }, { -0.28, -0.28, 0.28, -0.24 }, { -0.28, -0.28, -0.24, 0.28 },
                       { 0.24, -0.28, 0.28, 0.28 }, { -0.02, -0.28, 0.02, 0.28 }, { -0.28, -0.02, 0.28, 0.02 } }) do
    lock[#lock + 1] = { kind = "box", min = { b[1], b[2], 0.1 }, max = { b[3], b[4], 0.16 }, color = BRASS }
  end
  local console = {
    { kind = "box", min = { -0.45, -0.55, -0.25 }, max = { 0.45, 0.35, 0.25 }, color = DARK },
    { kind = "box", min = { -0.4, 0.35, -0.2 }, max = { 0.4, 0.42, 0.22 }, color = PLATE },
    { kind = "box", min = { -0.35, 0.42, -0.15 }, max = { 0.35, 0.82, -0.1 }, color = { 0.15, 0.5, 0.45 }, emissive = 0.8 },
    { kind = "box", min = { -0.3, 0.38, 0.05 }, max = { -0.18, 0.46, 0.17 }, color = { 0.9, 0.2, 0.15 }, emissive = 1 },
    { kind = "box", min = { -0.06, 0.38, 0.05 }, max = { 0.06, 0.46, 0.17 }, color = HAZ, emissive = 1 },
    { kind = "box", min = { 0.18, 0.38, 0.05 }, max = { 0.3, 0.46, 0.17 }, color = { 0.3, 0.9, 0.4 }, emissive = 1 },
  }
  return { shutter = shutter, lock = lock, console = console }
end

function M.foot_meshes()
  local out = {}
  local parts = M.foot_parts()
  for _, k in ipairs({ "shutter", "lock", "console" }) do out[k] = saucer.mesh.build({ parts = parts[k] }) end
  return out
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
    if extra then p.emissive, p.light = 1, true end
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
  if ruin.city then M.undercity_decor(ruin, r, k, mn, mx, parts) end
  if not covered(ruin, r) then
    local g = kit.recipe("derelict_greeble", { w = mx[1] - mn[1], d = mx[3] - mn[3], top = mx[2] - mn[2] },
                         saucer.seed_child(ruin.seed, "greeble", r.id))
    for _, p in ipairs(kit.transform(g.parts, { pos = { cx, mn[2], cz } })) do parts[#parts + 1] = p end
  end
  return parts
end

-- a small integer hash of three numbers: the same everywhere, for patterns that must not change
function M.hash3(a, b, c)
  local x = (math.floor(a) * 73856093) ~ (math.floor(b) * 19349663) ~ (math.floor(c) * 83492791)
  x = x ~ (x >> 13)
  return x & 0x7fffffff
end

-- add-cities-2: the undercity is wet or wild. A flooded kit (planet): the second and third levels and every
-- tunnel (the canals, lamps along their walls) hold water; the first level is overgrown. An overgrown kit
-- (moon): moss and vines from the first level down. All a function of the room, so identical every visit.
function M.undercity_decor(ruin, r, k, mn, mx, parts)
  local mode = ruinm.kit_of(ruin.kit).city.undercity
  if not mode or (not r.level and not r.tunnel) or ((r.level or 0) > -1 and not r.tunnel) then return end
  local w = k.wall
  local floor = mn[2] + w
  local seed = M.hash3(mn[1], mn[2], mn[3])
  local function rnd(i) return ((seed >> (i * 3)) ~ (seed * (i + 1))) % 1000 / 1000 end
  if mode == "flooded" and ((r.level or 0) <= -2 or r.tunnel) then
    local depth = r.tunnel and 1.6 or 2.6
    parts[#parts + 1] = { kind = "box", min = { mn[1] + w, floor, mn[3] + w }, max = { mx[1] - w, floor + depth, mx[3] - w },
                          color = { 0.07, 0.26, 0.42 }, emissive = 0.45 }
    local z = mn[3] + w + 3 + rnd(1) * 4
    while z < mx[3] - w - 2 do
      parts[#parts + 1] = { kind = "box", min = { mn[1] + w + 1, floor + depth, z }, max = { mx[1] - w - 1, floor + depth + 0.08, z + 0.35 },
                            color = { 0.35, 0.75, 0.95 }, emissive = 1 }
      z = z + 6 + rnd(2) * 6
    end
    if r.tunnel then
      -- canal lamps on the walls, lit with the district's grid
      local long = (mx[1] - mn[1]) > (mx[3] - mn[3]) and 1 or 3
      local o = long == 1 and 3 or 1
      local u = mn[long] + 6
      while u < mx[long] - 4 do
        for _, side in ipairs({ mn[o] + w, mx[o] - w - 0.3 }) do
          local lo, hi = { 0, floor + depth + 1.2, 0 }, { 0, floor + depth + 2.2, 0 }
          lo[long], hi[long] = u, u + 0.9
          lo[o], hi[o] = side, side + 0.3
          parts[#parts + 1] = { kind = "box", min = lo, max = hi, color = k.accent or { 1, 0.8, 0.4 }, emissive = 1, light = true }
        end
        u = u + 14
      end
    end
  end
  if (mode == "overgrown" or r.level == -1) and not r.tunnel then
    local n = 7 + math.floor(rnd(3) * 8)
    for i = 1, n do
      local x = mn[1] + w + 2 + rnd(i * 2) * math.max(1, mx[1] - mn[1] - 2 * w - 6)
      local z = mn[3] + w + 2 + rnd(i * 2 + 1) * math.max(1, mx[3] - mn[3] - 2 * w - 6)
      local s = 1.2 + rnd(i + 20) * 2.4
      local g = 0.35 + rnd(i + 40) * 0.35
      parts[#parts + 1] = { kind = "box", min = { x, floor, z }, max = { x + s * 1.4, floor + s, z + s * 1.4 }, color = { 0.12, g, 0.16 } }
      if i % 3 == 0 then
        local hang = 3 + rnd(i + 60) * 7
        parts[#parts + 1] = { kind = "box", min = { x, mx[2] - w - hang, z }, max = { x + 0.35, mx[2] - w, z + 0.35 }, color = { 0.1, g * 0.9, 0.14 } }
        parts[#parts + 1] = { kind = "box", min = { x - 0.2, mx[2] - w - hang - 0.4, z - 0.2 }, max = { x + 0.55, mx[2] - w - hang + 0.2, z + 0.55 },
                              color = { 1, 0.5, 0.9 }, emissive = 1 }
      end
    end
  end
end

-- exterior solid: plain block plus lit window bands (towers) or tip beacons.
-- A tower hanging under the city points its mast down (hanging = true).
M.ROLE_COLOR = {
  core = { 0.78, 0.72, 0.62 },
  civic = { 0.50, 0.42, 0.58 },
  market = { 0.66, 0.42, 0.22 },
  residential = { 0.38, 0.48, 0.46 },
  industrial = { 0.32, 0.31, 0.30 },
  spaceport = { 0.40, 0.44, 0.52 },
}

function M.solid_parts(s, k, hanging)
  local mn, mx = s[1], s[2]
  local role_col = s.role and M.ROLE_COLOR[s.role]
  local parts = { { kind = "box", min = mn, max = mx, color = role_col or k.solid_color or k.color, uv = 0.25 } }
  if s.kind == "pod" then
    -- add-wider-dark: a brood pod swells out of its block, a lit seam round its middle
    local c = { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
    local r = math.min(mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3]) * 0.62
    parts[#parts + 1] = { kind = "sphere", c = c, r = r, h = r, seg = 10, rings = 3, color = k.solid_color or k.color }
    parts[#parts + 1] = { kind = "ring", c = c, rin = r * 0.98, r = r * 1.08, h = 0.25, seg = 12,
                          color = { 1.0, 0.62, 0.2 }, emissive = 0.9 }
  elseif s.kind == "pad" then
    -- add-dock-land-eva: a rooftop landing pad: a lit square border and a centre cross
    local lx, lz = mx[1] - mn[1], mx[3] - mn[3]
    local y0, y1 = mx[2], mx[2] + 0.05
    local amber = { 1.0, 0.75, 0.15 }
    local m = math.min(lx, lz) * 0.12
    parts[1].color = { 0.30, 0.31, 0.36 }
    local function strip(a, b) parts[#parts + 1] = { kind = "box", min = a, max = b, color = amber, emissive = 0.9, uv = 0.25 } end
    strip({ mn[1] + m, y0, mn[3] + m }, { mx[1] - m, y1, mn[3] + m + 0.5 })
    strip({ mn[1] + m, y0, mx[3] - m - 0.5 }, { mx[1] - m, y1, mx[3] - m })
    strip({ mn[1] + m, y0, mn[3] + m }, { mn[1] + m + 0.5, y1, mx[3] - m })
    strip({ mx[1] - m - 0.5, y0, mn[3] + m }, { mx[1] - m, y1, mx[3] - m })
    local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
    strip({ cx - m, y0, cz - 0.4 }, { cx + m, y1, cz + 0.4 })
    strip({ cx - 0.4, y0, cz - m }, { cx + 0.4, y1, cz + m })
  elseif s.kind == "tower" then
    -- add-cities: a tier of a civ-styled tower: window patterns by face and floor (lit parts are
    -- `light`, switched per district), a ledge, roof greebles, a lit sign on the base, a mast on the apex
    local win = k.window_color or { 1.0, 0.85, 0.5 }
    local accent = k.accent or win
    local lx, lz, hgt = mx[1] - mn[1], mx[3] - mn[3], mx[2] - mn[2]
    local base = role_col or k.solid_color or k.color
    local shade = 0.9 + 0.1 * ((s.tier or 1) % 2)
    parts[1].color = { base[1] * shade, base[2] * shade, base[3] * shade }
    local step = hgt > 120 and 9 or 6
    local y, n = mn[2] + 3, 0
    while y < mx[2] - 2 and n < 26 do
      n = n + 1
      if n % 4 ~= 0 then
        for f = 0, 3 do
          local len = f < 2 and lx or lz
          local nw = math.max(1, math.floor(len / 9))
          for w = 0, nw - 1 do
            -- most windows stay lit so a fresh city is not dark at street level;
            -- a smaller set stay switchable so the restore-wave still has a visible lift
            local hv = M.hash3(mn[1] + f * 7 + w * 131, y, mn[3] + w) % 100
            local chance = (s.role == "residential") and 78 or 68
            if hv < chance then
              local u0 = (w + 0.5) / nw * len - 2.2
              local lo, hi
              if f < 2 then
                local z0 = f == 0 and mn[3] - 0.15 or mx[3] - 0.15
                lo, hi = { mn[1] + u0, y, z0 }, { mn[1] + u0 + 4.4, y + 2.0, z0 + 0.3 }
              else
                local x0 = f == 2 and mn[1] - 0.15 or mx[1] - 0.15
                lo, hi = { x0, y, mn[3] + u0 }, { x0 + 0.3, y + 2.0, mn[3] + u0 + 4.4 }
              end
              parts[#parts + 1] = { kind = "box", min = lo, max = hi, color = win, emissive = 1,
                                    light = (hv < 18) or nil }
            end
          end
        end
      end
      y = y + step
    end
    -- the ledge at the top of the tier, and roof greebles
    parts[#parts + 1] = { kind = "box", min = { mn[1] - 0.4, mx[2] - 0.7, mn[3] - 0.4 }, max = { mx[1] + 0.4, mx[2] + 0.2, mx[3] + 0.4 },
                          color = { base[1] * 0.6, base[2] * 0.6, base[3] * 0.65 } }
    local hg = M.hash3(mx[1], mx[2], mx[3])
    for i = 0, 2 do
      local gx = mn[1] + 2 + ((hg >> (i * 5)) % 100) / 100 * math.max(0.1, lx - 6)
      local gz = mn[3] + 2 + ((hg >> (i * 5 + 2)) % 100) / 100 * math.max(0.1, lz - 6)
      local gh = 1 + (hg >> (i * 3)) % 3
      parts[#parts + 1] = { kind = "box", min = { gx, mx[2] + 0.2, gz }, max = { gx + 2.5, mx[2] + 0.2 + gh, gz + 2.5 },
                            color = { base[1] * 0.5, base[2] * 0.5, base[3] * 0.55 } }
    end
    -- a lit sign high on the base tier: a panel in the civ's accent with white bars for its letters
    if (s.tier or 1) == 1 and hgt > 24 and hg % 3 ~= 0 then
      local f = hg % 4
      local sw = math.min(12, (f < 2 and lx or lz) * 0.6)
      local sy = mn[2] + math.min(32, hgt * 0.6)
      local mid = f < 2 and (mn[1] + mx[1]) / 2 or (mn[3] + mx[3]) / 2
      local function at(u0, u1, y0, y1, depth, color)
        if f == 0 then return { kind = "box", min = { mid + u0, y0, mn[3] - depth }, max = { mid + u1, y1, mn[3] }, color = color, emissive = 1, light = true }
        elseif f == 1 then return { kind = "box", min = { mid + u0, y0, mx[3] }, max = { mid + u1, y1, mx[3] + depth }, color = color, emissive = 1, light = true }
        elseif f == 2 then return { kind = "box", min = { mn[1] - depth, y0, mid + u0 }, max = { mn[1], y1, mid + u1 }, color = color, emissive = 1, light = true }
        end
        return { kind = "box", min = { mx[1], y0, mid + u0 }, max = { mx[1] + depth, y1, mid + u1 }, color = color, emissive = 1, light = true }
      end
      parts[#parts + 1] = at(-sw / 2, sw / 2, sy, sy + 4, 0.6, accent)
      for b = 0, 4 do
        if (hg >> (b + 7)) & 1 == 1 then
          parts[#parts + 1] = at(-sw / 2 + 0.8 + b * (sw - 1.6) / 5, -sw / 2 + 0.8 + (b + 0.7) * (sw - 1.6) / 5, sy + 0.7, sy + 3.3, 0.9, { 1, 1, 1 })
        end
      end
    end
    if s.apex then
      local c = { (mn[1] + mx[1]) / 2, hanging and mn[2] or mx[2], (mn[3] + mx[3]) / 2 }
      local d = hanging and -1 or 1
      parts[#parts + 1] = { kind = "box", min = { c[1] - 0.25, math.min(c[2], c[2] + 9 * d), c[3] - 0.25 },
                            max = { c[1] + 0.25, math.max(c[2], c[2] + 9 * d), c[3] + 0.25 }, color = { 0.5, 0.5, 0.55 } }
      parts[#parts + 1] = { kind = "box", min = { c[1] - 0.8, math.min(c[2] + 9 * d, c[2] + 10.6 * d), c[3] - 0.8 },
                            max = { c[1] + 0.8, math.max(c[2] + 9 * d, c[2] + 10.6 * d), c[3] + 0.8 }, color = { 1, 0.3, 0.25 },
                            emissive = 1, light = true }
    end
    -- add-generated-planets: each ring's buildings have their own roof dress
    if s.role == "civic" and s.apex then
      local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
      local rr = math.min(mx[1] - mn[1], mx[3] - mn[3]) * 0.48
      parts[#parts + 1] = { kind = "hemisphere", c = { cx, mx[2], cz }, r = rr, h = rr * 0.95, seg = 12, rings = 5,
                            color = { 0.62, 0.50, 0.70 } }
      -- a low arched collar so civic halls read as domes-and-arches from the street
      parts[#parts + 1] = { kind = "cylinder", c = { cx, mn[2], cz }, r = rr * 1.05, h = 4.2, seg = 12,
                            color = { 0.58, 0.50, 0.64 } }
    elseif s.role == "market" and (s.tier or 1) == 1 then
      local aw = { 0.88, 0.48, 0.18 }
      local y0, y1 = mn[2] + 3.2, mn[2] + 5.8
      parts[#parts + 1] = { kind = "box", min = { mn[1] - 3.4, y0, mn[3] - 3.4 }, max = { mx[1] + 3.4, y1, mn[3] + 0.5 },
                            color = aw, emissive = 0.22 }
      parts[#parts + 1] = { kind = "box", min = { mn[1] - 3.4, y0, mx[3] - 0.5 }, max = { mx[1] + 3.4, y1, mx[3] + 3.4 },
                            color = aw, emissive = 0.22 }
      parts[#parts + 1] = { kind = "box", min = { mn[1] - 3.4, y0, mn[3] - 3.4 }, max = { mn[1] + 0.5, y1, mx[3] + 3.4 },
                            color = aw, emissive = 0.22 }
      parts[#parts + 1] = { kind = "box", min = { mx[1] - 0.5, y0, mn[3] - 3.4 }, max = { mx[1] + 3.4, y1, mx[3] + 3.4 },
                            color = aw, emissive = 0.22 }
      parts[#parts + 1] = { kind = "box", min = { mn[1] - 0.15, y1 - 0.2, mn[3] - 0.15 }, max = { mx[1] + 0.15, y1 + 0.2, mx[3] + 0.15 },
                            color = { 1.0, 0.78, 0.28 }, emissive = 0.95 }
    elseif s.role == "industrial" and (s.tier or 1) == 1 then
      local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
      parts[#parts + 1] = { kind = "cylinder", c = { mn[1] + 3, mx[2], mn[3] + 3 }, r = 2.6, h = 11, seg = 10,
                            color = { 0.38, 0.36, 0.34 } }
      parts[#parts + 1] = { kind = "cylinder", c = { mx[1] - 5, mx[2], mn[3] + 3 }, r = 2.0, h = 16, seg = 10,
                            color = { 0.28, 0.28, 0.30 } }
      parts[#parts + 1] = { kind = "sphere", c = { mx[1] - 4, mn[2] + 5, mx[3] - 4 }, r = 4.2, h = 4.2, seg = 8, rings = 4,
                            color = { 0.42, 0.32, 0.22 } }
      -- a simple crane arm
      parts[#parts + 1] = { kind = "box", min = { cx - 0.4, mx[2], cz - 0.4 }, max = { cx + 0.4, mx[2] + 10, cz + 0.4 },
                            color = { 0.7, 0.45, 0.15 } }
      parts[#parts + 1] = { kind = "box", min = { cx - 0.35, mx[2] + 9.2, cz - 0.35 }, max = { cx + 11, mx[2] + 10.2, cz + 0.35 },
                            color = { 0.7, 0.45, 0.15 } }
    elseif s.role == "spaceport" and s.apex then
      local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
      local pr = math.min(mx[1] - mn[1], mx[3] - mn[3]) * 0.35
      parts[#parts + 1] = { kind = "cylinder", c = { cx, mx[2], cz }, r = pr, h = 0.4, seg = 12,
                            color = { 0.35, 0.38, 0.44 } }
    end
  elseif s.kind == "crown" then
    local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
    local h = mx[2] - mn[2]
    local r = math.min(mx[1] - mn[1], mx[3] - mn[3]) / 2
    parts[1] = { kind = "cylinder", c = { cx, mn[2], cz }, r = r * 0.55, h = h * 0.18, seg = 14,
                 color = { 0.72, 0.68, 0.58 } }
    parts[#parts + 1] = { kind = "cone", c = { cx, mn[2] + h * 0.16, cz }, r = r * 0.42, r1 = r * 0.05, h = h * 0.74, seg = 14,
                          color = { 0.88, 0.80, 0.55 } }
    parts[#parts + 1] = { kind = "sphere", c = { cx, mn[2] + h * 0.93, cz }, r = r * 0.18, h = r * 0.18, seg = 10, rings = 5,
                          color = { 1.0, 0.88, 0.35 }, emissive = 1 }
  elseif s.kind == "rail" or s.kind == "pylon" or s.kind == "liftpost" then
    -- add-cities-2: transit. The rail deck has lit edges, a pylon a lit collar, a lift post a lit stripe every 24 m.
    local acc = k.accent or { 1, 0.8, 0.4 }
    parts[1].color = { 0.28, 0.3, 0.36 }
    if s.kind == "rail" then
      local long = (mx[1] - mn[1]) > (mx[3] - mn[3]) and 1 or 3
      local o = long == 1 and 3 or 1
      for _, side in ipairs({ 0, 1 }) do
        local lo, hi = { mn[1], mn[2] - 0.2, mn[3] }, { mx[1], mn[2] + 0.2, mx[3] }
        lo[o] = side == 0 and mn[o] - 0.05 or mx[o] - 0.35
        hi[o] = side == 0 and mn[o] + 0.35 or mx[o] + 0.05
        parts[#parts + 1] = { kind = "box", min = lo, max = hi, color = acc, emissive = 1, light = true }
      end
    elseif s.kind == "pylon" then
      parts[#parts + 1] = { kind = "box", min = { mn[1] - 0.2, mx[2] - 4, mn[3] - 0.2 }, max = { mx[1] + 0.2, mx[2] - 2.5, mx[3] + 0.2 }, color = acc,
                            emissive = 1, light = true }
    else
      local y = mn[2] + 12
      while y < mx[2] - 4 do
        parts[#parts + 1] = { kind = "box", min = { mn[1] - 0.1, y, mn[3] - 0.1 }, max = { mx[1] + 0.1, y + 1.2, mx[3] + 0.1 }, color = acc,
                              emissive = 1, light = true }
        y = y + 24
      end
    end
  elseif s.kind == "platform" or s.kind == "bridge" then
    -- lit edge strips: a plaza or a sky-bridge reads from afar at night
    local acc = k.accent or { 1, 0.8, 0.4 }
    local y1 = mx[2] + 0.05
    parts[#parts + 1] = { kind = "box", min = { mn[1], y1, mn[3] }, max = { mx[1], y1 + 0.3, mn[3] + 0.5 }, color = acc, emissive = 1, light = true }
    parts[#parts + 1] = { kind = "box", min = { mn[1], y1, mx[3] - 0.5 }, max = { mx[1], y1 + 0.3, mx[3] }, color = acc, emissive = 1, light = true }
    parts[#parts + 1] = { kind = "box", min = { mn[1], y1, mn[3] }, max = { mn[1] + 0.5, y1 + 0.3, mx[3] }, color = acc, emissive = 1, light = true }
    parts[#parts + 1] = { kind = "box", min = { mx[1] - 0.5, y1, mn[3] }, max = { mx[1], y1 + 0.3, mx[3] }, color = acc, emissive = 1, light = true }
  else
    local c = { (mn[1] + mx[1]) / 2, mx[2], (mn[3] + mx[3]) / 2 }
    parts[#parts + 1] = { kind = "box", min = { c[1] - 0.6, c[2], c[3] - 0.6 }, max = { c[1] + 0.6, c[2] + 1.2, c[3] + 0.6 },
                          color = { 1, 0.3, 0.2 }, emissive = 1 }
  end
  return parts
end

local BEACON = { spaceport = { 0.9, 0.95, 1 }, reactor = { 1, 0.45, 0.2 }, archive = { 0.4, 0.9, 1 }, foundry = { 1, 0.75, 0.25 },
  garden = { 0.45, 1, 0.5 }, palace = { 1, 0.5, 0.9 } }

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
-- a centred unit cube, drawn scaled and tinted (trains, lift cabins): dark, or emissive for lit strips
function M.unit_box(emissive)
  cache.unitbox = cache.unitbox or {}
  local key = emissive and "e" or "d"
  if not cache.unitbox[key] then
    cache.unitbox[key] = saucer.mesh.build({ parts = { { kind = "box", min = { -0.5, -0.5, -0.5 }, max = { 0.5, 0.5, 0.5 },
      color = { 1, 1, 1 }, emissive = emissive and 1 or nil, uv = 0.5 } } })
  end
  return cache.unitbox[key]
end

-- add-cities: a city's kit wearing its civ's light colours (the kit table itself is shared and untouched)
function M.styled_kit(ruin)
  local k = ruinm.kit_of(ruin.kit)
  local st = ruin.city and ruin.city.style
  if not st then return k end
  return setmetatable({ window_color = st.window, accent = st.accent }, { __index = k })
end

-- split off the parts that are lights (windows, signs, strips), which a city switches per district
local function split_lights(parts)
  local main, lights = {}, {}
  for _, p in ipairs(parts) do
    if p.light then lights[#lights + 1] = p else main[#main + 1] = p end
  end
  return main, lights
end

-- the lights mesh of a chunk, built the first time its district is lit (nil when it has none)
function M.chunk_lights(ch)
  if ch.light_parts and ch.lights == nil then
    ch.lights = #ch.light_parts > 0 and saucer.mesh.build({ parts = ch.light_parts }) or false
    ch.light_parts = nil
  end
  return ch.lights or nil
end

-- add-cities-2: the windows and lights of a skyline district, built when the camera comes near it; a handful
-- stay built (the oldest is freed first), so flying along the ring never piles up meshes
M.OUTER_LIVE = 8
local outer_live = {}
function M.outer_detail(set, d)
  local dm = set.districts[d]
  if dm.near then return dm.near end
  local main, lights = {}, {}
  for _, i in ipairs(dm.solids) do
    local s = set.ruin.solids[i]
    local m, l = split_lights(M.solid_parts(s, set.kit, detail.hanging(set.ruin, s, set.kit, set.origin)))
    for _, p in ipairs(m) do main[#main + 1] = p end
    for _, p in ipairs(l) do lights[#lights + 1] = p end
  end
  dm.near = { mesh = saucer.mesh.build({ parts = main }), lights = #lights > 0 and saucer.mesh.build({ parts = lights }) or nil }
  outer_live[#outer_live + 1] = dm
  while #outer_live > M.OUTER_LIVE do
    local old = table.remove(outer_live, 1)
    saucer.mesh.free(old.near.mesh)
    if old.near.lights then saucer.mesh.free(old.near.lights) end
    old.near = nil
  end
  return dm.near
end

function M.ruin_chunks(ruin, origin)
  local hit = cache.chunks and cache.chunks[ruin.hash]
  if hit then return hit end
  cache.chunks = cache.chunks or {}
  local k = M.styled_kit(ruin)
  local by_room = {}
  for _, r in ipairs(ruin.rooms) do by_room[r.id] = {} end
  local function add(list, b, color, uv)
    list[#list + 1] = { kind = "box", min = b[1], max = b[2], color = color, uv = uv }
  end
  -- add-presentation-packaging: floor and ceiling slabs (thin in y, wide in
  -- x and z) go into a per-room floor mesh drawn with the kit's floor art
  local floors = {}
  for _, r in ipairs(ruin.rooms) do floors[r.id] = {} end
  for _, b in ipairs(ruin.walls) do
    local dx, dy, dz = b[2][1] - b[1][1], b[2][2] - b[1][2], b[2][3] - b[1][3]
    if dy * 3 < math.min(dx, dz) then add(floors[b.room or 1], b, k.floor_color or { 0.82, 0.82, 0.82 }, k.floor_uv or 0.125)
    else add(by_room[b.room or 1], b, k.color, k.uv or 0.25) end
  end
  for _, b in ipairs(ruin.debris) do add(by_room[b.room or 1], b, { 0.55, 0.45, 0.32 }, 0.5) end
  local out = { chunks = {} }
  local coarse = {}
  -- add-cities: a city's coarse silhouette is also kept per district, so a far district costs one draw
  local dparts, dglow = {}, {}
  local function dpart(d, b)
    if not ruin.city then return end
    local g = dparts[d or 0] or { parts = {}, mn = { 1e9, 1e9, 1e9 }, mx = { -1e9, -1e9, -1e9 } }
    dparts[d or 0] = g
    g.parts[#g.parts + 1] = b
    for a = 1, 3 do
      g.mn[a] = math.min(g.mn[a], b.min[a])
      g.mx[a] = math.max(g.mx[a], b.max[a])
    end
  end
  for _, r in ipairs(ruin.rooms) do
    local parts = by_room[r.id]
    for _, p in ipairs(M.room_decor(ruin, r, k, origin)) do parts[#parts + 1] = p end
    local lights
    if ruin.city then parts, lights = split_lights(parts) end
    local c, rad = sphere_of(parts)
    local fl = floors[r.id]
    out.chunks[#out.chunks + 1] = { light_parts = lights, district = r.district, mesh = saucer.mesh.build({ parts = parts }), center = c, radius = rad, room = r.id,
                                    floor = #fl > 0 and saucer.mesh.build({ parts = fl }) or nil,
                                    glyphs = M.room_glyphs(r, k, origin) }
    local mn, mx = ruinm.room_box(r, k, origin)
    coarse[#coarse + 1] = { kind = "box", min = mn, max = mx, color = k.color, uv = 0.25 }
    dpart(r.district, coarse[#coarse])
  end
  local skyi = {}
  for i, s in ipairs(ruin.solids or {}) do
    local sd = not s.global and (s.district or (s.room and ruin.rooms[s.room] and ruin.rooms[s.room].district)) or nil
    if s.outer then
      -- the skyline ring: coarse boxes and a far glow only; windows and lights are built when the camera is near
      skyi[sd] = skyi[sd] or {}
      skyi[sd][#skyi[sd] + 1] = i
      coarse[#coarse + 1] = { kind = "box", min = s[1], max = s[2], color = k.solid_color or k.color, uv = 0.25 }
      dpart(sd, coarse[#coarse])
      if s.apex then
        local gp = dglow[sd] or {}
        dglow[sd] = gp
        local cxm, czm = (s[1][1] + s[2][1]) / 2, (s[1][3] + s[2][3]) / 2
        gp[#gp + 1] = { kind = "box", min = { cxm - 2.5, s[2][2] - 14, czm - 2.5 }, max = { cxm + 2.5, s[2][2] + 6, czm + 2.5 }, color = k.window_color, emissive = 1 }
      end
      if s.tier == 1 then
        local gp = dglow[sd] or {}
        dglow[sd] = gp
        local yy = s[1][2] + (s[2][2] - s[1][2]) * 0.55
        gp[#gp + 1] = { kind = "box", min = { s[1][1] - 0.4, yy, s[1][3] - 0.4 }, max = { s[2][1] + 0.4, yy + 6, s[2][3] + 0.4 }, color = k.window_color, emissive = 1 }
      end
      goto continue
    end
    local parts = M.solid_parts(s, k, detail.hanging(ruin, s, k, origin))
    local lights
    if ruin.city then parts, lights = split_lights(parts) end
    local c, rad = sphere_of(parts)
    out.chunks[#out.chunks + 1] = { light_parts = lights, district = sd, mesh = saucer.mesh.build({ parts = parts }), center = c, radius = rad, solid = i,
                                    fall = ruin.city and require("sim.cities").fall_tick(ruin, s) or nil }
    -- the far glow of a lit district: one band and a beacon per tower
    if ruin.city and s.kind == "tower" and s.apex then
      local gp = dglow[sd or 0] or {}
      dglow[sd or 0] = gp
      local cxm, czm = (s[1][1] + s[2][1]) / 2, (s[1][3] + s[2][3]) / 2
      gp[#gp + 1] = { kind = "box", min = { cxm - 2.5, s[2][2] - 14, czm - 2.5 }, max = { cxm + 2.5, s[2][2] + 6, czm + 2.5 }, color = k.window_color, emissive = 1 }
    end
    if ruin.city and s.kind == "tower" and s.tier == 1 then
      local gp = dglow[sd or 0] or {}
      dglow[sd or 0] = gp
      local yy = s[1][2] + (s[2][2] - s[1][2]) * 0.55
      gp[#gp + 1] = { kind = "box", min = { s[1][1] - 0.4, yy, s[1][3] - 0.4 }, max = { s[2][1] + 0.4, yy + 6, s[2][3] + 0.4 }, color = k.window_color, emissive = 1 }
    end
    if not s.fall then -- (a sky-bridge that may fall is not in the far silhouette)
      coarse[#coarse + 1] = { kind = "box", min = s[1], max = s[2], color = k.solid_color or k.color, uv = 0.25 }
      dpart(sd, coarse[#coarse])
    end
    ::continue::
  end
  for d, g in pairs(dparts) do
    if d ~= 0 then
      local c, rad = sphere_of(g.parts)
      out.districts = out.districts or {}
      out.districts[d] = { mesh = saucer.mesh.build({ parts = g.parts }), center = c, radius = rad, mn = g.mn, mx = g.mx,
                           glow = dglow[d] and #dglow[d] > 0 and saucer.mesh.build({ parts = dglow[d] }) or nil,
                           outer = skyi[d] ~= nil or nil, solids = skyi[d] }
    end
  end
  -- add-cities: a light pillar over every landmark district, to find them from afar
  if ruin.city then
    local top = origin[2] + k.grid[2] * k.cell - 10
    out.beacons = {}
    for _, pd in ipairs(ruin.city.districts) do
      local col = BEACON[pd.kind]
      if col then
        local y0 = pd.pos[2] + 30
        out.beacons[pd.id] = { center = { pd.pos[1], (y0 + top) / 2, pd.pos[3] }, radius = (top - y0) / 2 + 4,
          mesh = saucer.mesh.build({ parts = { { kind = "box", min = { pd.pos[1] - 1.5, y0, pd.pos[3] - 1.5 },
            max = { pd.pos[1] + 1.5, top, pd.pos[3] + 1.5 }, color = col, emissive = 1 } } }) }
      end
    end
  end
  -- add-cities-2: a ring of far skyline beyond the last district (planet: seen through the haze), one mesh
  local spec = ruin.city and k.city
  if spec and spec.horizon then
    local hrng = saucer.rng.new(saucer.seed_child(ruin.seed, "horizon", 0))
    local ext = { k.grid[1] * k.cell, k.grid[3] * k.cell }
    local cx, cz = origin[1] + ext[1] / 2, origin[3] + ext[2] / 2
    local hp = {}
    local base = math.max(ext[1], ext[2]) / 2 + 500
    for n = 1, 150 do
      local a = (n + hrng:float()) / 150 * saucer.math.tau
      local rr = base + hrng:int(0, 2200)
      local w, h = hrng:int(30, 120), hrng:int(60, 420)
      local x, z = cx + saucer.math.sin(a) * rr, cz + saucer.math.cos(a) * rr
      local y0 = origin[2]
      hp[#hp + 1] = { kind = "box", min = { x - w / 2, y0, z - w / 2 }, max = { x + w / 2, y0 + h, z + w / 2 }, color = k.solid_color, uv = 0.25 }
      if hrng:int(1, 100) <= 60 then
        hp[#hp + 1] = { kind = "box", min = { x - w / 2 - 0.5, y0 + h * 0.6, z - w / 2 - 0.5 }, max = { x + w / 2 + 0.5, y0 + h * 0.6 + 3, z + w / 2 + 0.5 },
                        color = k.window_color, emissive = 1 }
      end
    end
    out.horizon = { mesh = saucer.mesh.build({ parts = hp }) }
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
  -- add-wider-dark: a kit may borrow another kit's material (tinted by its colours)
  return A.tex["kit_" .. (k and (k.texture or k.id) or "")] or A.tex.hull
end

-- add-presentation-packaging: a decal quad (cache.decal is a unit square in
-- x/y facing +z, its texture spanning it once) centred at c, facing yaw
function M.decal(v, A, tex, pal, c, yaw, w, h, tint)
  local cy, sy = saucer.math.cos(yaw), saucer.math.sin(yaw)
  v:mesh(A.decal, { pos = { c[1] - cy * w / 2, c[2] - h / 2, c[3] + sy * w / 2 }, yaw = yaw, scale = { w, h, 1 },
                    tex = tex, palette = pal, tint = tint })
end

-- glyph inscriptions high on the door-less walls of a big room ->
-- list of { c = centre, yaw =, w = size }
M.GLYPH_FACES = { { "+x", 1, 1, -1.5708 }, { "-x", 1, -1, 1.5708 }, { "+z", 3, 1, 3.14159 }, { "-z", 3, -1, 0 } }
function M.room_glyphs(r, k, origin)
  local out = {}
  if r.class < (k.big or 4) or r.kind == "shaft" then return out end
  local mn, mx = ruinm.room_box(r, k, origin)
  local h = mx[2] - mn[2]
  local w = math.min(9, h * 0.28)
  for _, f in ipairs(M.GLYPH_FACES) do
    if not (r.faces and r.faces[f[1]]) and #out < 2 then
      local axis, sign = f[2], f[3]
      local c = { (mn[1] + mx[1]) / 2, mx[2] - w / 2 - 1.5, (mn[3] + mx[3]) / 2 }
      c[axis] = (sign > 0 and mx[axis] - k.wall - 0.05) or (mn[axis] + k.wall + 0.05)
      out[#out + 1] = { c = c, yaw = f[4], w = w }
    end
  end
  return out
end

-- add-presentation-packaging: the kit's floor material (nil: none)
function M.floor_texture(A, k)
  return A.tex["floor_" .. (k and (k.floor_texture or k.texture or k.id) or "")]
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
