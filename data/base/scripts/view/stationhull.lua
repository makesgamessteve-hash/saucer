-- SPDX-License-Identifier: MIT
-- Drawing a trader station's outside (OpenSpec add-huge-stations). Render-only: reads the sector and the
-- layout of sim/stationhull.lua, writes nothing to the state. Each layer of a layout is one static mesh,
-- built the first time it is wanted and kept (by layout hash). Levels of detail by distance to the hull's
-- bounding box: a silhouette from afar, the hull and rings nearer, the greebles, trusses and windows
-- closest. The rings turn about the x axis; the hull and the hangar cell stand still. Beacons blink as
-- billboards within range, and a chase of lights runs down the approach corridor toward the bay.
local sh = require("sim.stationhull")
local dock = require("sim.dock")
local vec = require("lib.vec")
local sm = saucer.math
local M = {}

M.TINT = { 1.45, 1.45, 1.45, 1 }   -- plating is lit up so the hull reads against the dark (the fog and the dim sun swallow it otherwise)
M.stats = { draws = 0, tris = 0, lights = 0 }   -- of the last draw call, for tests and tools
local cache = {}
local cache_order = {}

local LAYERS = { "core", "detail", "ring", "ringd", "far" }

-- the meshes of a layout, built on first use (a layer that is not asked for is not built)
-- lazy (the frame loop): at most one build per frame (M.budget), the layout's triangles count as one, so a station
-- shows up over a few frames instead of costing one long one; returns nothing for a layer that is not built yet
M.budget = 1
function M.mesh(L, layer, lazy, plain)
  local ent = cache[L.hash]
  if not ent then
    ent = { tris = {} }
    cache[L.hash] = ent
    cache_order[#cache_order + 1] = L.hash
    if #cache_order > 6 then
      local old = table.remove(cache_order, 1)
      for _, id in pairs(cache[old] or {}) do
        if type(id) == "number" then saucer.mesh.free(id) end
      end
      cache[old] = nil
    end
  end
  local key = plain and (layer .. "_plain") or layer
  local id = ent[key]
  if not id then
    if lazy then
      if M.budget <= 0 then return nil end
      M.budget = M.budget - 1
      if not sh.parts_ready(L) then
        sh.parts(L)
        return nil
      end
    end
    local parts = sh.parts(L)[layer]
    if plain then -- add-civ-hulls: the same parts on the plain slot (another civ's materials hold the view)
      local copy = {}
      for i, q in ipairs(parts) do
        local c = {}
        for k, v in pairs(q) do c[k] = v end
        c.mat = nil
        copy[i] = c
      end
      parts = copy
    end
    local mesh = saucer.mesh.build({ parts = parts })
    ent[key] = mesh
    ent.tris[key] = saucer.mesh.info(mesh).triangles
    id = mesh
  end
  return id, ent.tris[key]
end

-- triangles of every layer of a layout (builds them all: tests and tools)
function M.layer_tris(L)
  local out = {}
  for _, layer in ipairs(LAYERS) do
    local _, t = M.mesh(L, layer)
    out[layer] = t
  end
  return out
end

function M.free_all()
  for _, ent in pairs(cache) do
    for _, id in pairs(ent) do
      if type(id) == "number" then saucer.mesh.free(id) end
    end
  end
  cache, cache_order = {}, {}
end

-- distance from a point to an axis-aligned box (0 inside)
local function box_dist(p, lo, hi)
  local s = 0
  for k = 1, 3 do
    local d = math.max(lo[k] - p[k], 0, p[k] - hi[k])
    s = s + d * d
  end
  return sm.sqrt(s)
end
M.box_dist = box_dist

-- which level of detail at distance d from the station's box -> "far" | "hull" | "detail"
function M.level(L, d)
  local lod = sh.kit().lod
  local k = L.class == "outpost" and 0.35 or 1.0
  if d > lod.far * k then return "far" end
  if d > lod.detail * k then return "hull" end
  return "detail"
end

local function blink_on(l, tick)
  if l.kind == "steady" then return true end
  local t = (tick + l.phase) % l.period
  if l.kind == "strobe" then return t < 3 or (t > 9 and t < 12) end
  if l.kind == "pulse" then return t < l.period * 0.6 end
  return t < l.period * 0.22
end

-- the lights near the camera: blinking beacons of the hull, nearest first, at most lod.max_lights
function M.beacons(v, A, L, origin, cam, tick)
  local lod = sh.kit().lod
  local list = {}
  for _, l in ipairs(L.lights) do
    local dx, dy, dz = origin[1] + l.p[1] - cam.pos[1], origin[2] + l.p[2] - cam.pos[2], origin[3] + l.p[3] - cam.pos[3]
    local d2 = dx * dx + dy * dy + dz * dz
    if d2 < lod.lights * lod.lights and blink_on(l, tick) then list[#list + 1] = { l, d2 } end
  end
  table.sort(list, function(a, b) return a[2] < b[2] end)
  local n = 0
  for i = 1, math.min(#list, lod.max_lights) do
    local l = list[i][1]
    local d = sm.sqrt(list[i][2])
    local size = math.max(l.size * 2, math.min(60, d * 0.02 * l.size))
    v:billboard(A.tex.glow, { origin[1] + l.p[1], origin[2] + l.p[2], origin[3] + l.p[3] }, size,
                { palette = A.pal.base, tint = { l.c[1], l.c[2], l.c[3], 0.9 } })
    n = n + 1
  end
  return n
end

-- add-civ-hulls: the builder's signal lights (sim/hulldress.lua): out to the kit's signal range, blinking by the civ's
-- light model, never smaller than a few thousandths of their distance so a station reads from kilometres away
function M.signals(v, A, L, origin, cam, tick)
  local list = L.signals
  if not list or #list == 0 then return 0 end
  local hd = require("sim.hulldress")
  local K = hd.kit().signal
  local n = 0
  for _, l in ipairs(list) do
    local p = { origin[1] + l.p[1], origin[2] + l.p[2], origin[3] + l.p[3] }
    local d = vec.dist(p, cam.pos)
    if d < K.far and n < K.max then
      local a, c = hd.signal_at(l, tick, L.lamps or { l.c })
      local size = math.max(l.size, d * K.min_px * (l.size > 0 and 1 or 0))
      v:billboard(A.tex.glow, p, size, { palette = A.pal.base, tint = { c[1], c[2], c[3], a } })
      n = n + 1
    end
  end
  return n
end

-- the approach corridor: two rows of lights out of the cell's mouth, a bright chase running toward the dock
function M.approach_lights(state, idx)
  local T = dock.tune()
  local H = sh.kit().approach
  local bay = dock.bay(state, idx)
  local out = {}
  local n = math.floor(H.length / H.step)
  local y = bay.lo[2] + T.height / 2
  for i = 1, n do
    local x = bay.hi[1] + 6 + (i - 1) * H.step
    for _, s in ipairs({ -1, 1 }) do
      out[#out + 1] = { pos = { x, y + s * 0, bay.pad[3] + s * (H.half_w + 0.012 * (x - bay.hi[1])) }, i = i, s = s }
    end
  end
  return out
end

function M.approach(v, A, state, idx, cam, tick)
  local H = sh.kit().approach
  local bay = dock.bay(state, idx)
  local lod = sh.kit().lod
  if vec.dist(cam.pos, bay.mouth) > H.length + lod.lights then return 0 end
  local lights = M.approach_lights(state, idx)
  local cycle = H.length + 4 * H.step
  local head = (tick * H.speed / 60) % cycle           -- the chase's front, measured from the far end
  local n = 0
  for _, l in ipairs(lights) do
    local from_far = (#lights / 2 - l.i) * H.step
    local lit = ((head - from_far) % cycle) < 3 * H.step
    local a = lit and 0.95 or 0.28
    local size = lit and 7 or 3.5
    v:billboard(A.tex.glow, l.pos, size, { palette = A.pal.base, tint = lit and { 1, 0.85, 0.3, a } or { 0.4, 0.9, 1, a } })
    n = n + 1
  end
  return n
end

-- draw every trader's station; returns the draw count
function M.draw(v, A, state, cam, tick)
  local n = 0
  M.budget = 1
  local stats = { draws = 0, tris = 0, lights = 0, levels = {} }
  local list = state.sector.traders or { state.sector.trader }
  tick = tick or state.tick
  for idx, tr in ipairs(list) do
    local L = sh.for_trader(state, idx)
    local p = tr.pos
    local e = L.info.extent
    local d = box_dist(cam.pos, { p[1] + e.lo[1], p[2] + e.lo[2], p[3] + e.lo[3] }, { p[1] + e.hi[1], p[2] + e.hi[2], p[3] + e.hi[3] })
    local level = M.level(L, d)
    -- the fog is dark: lift the plating with the distance so a far station still reads (capped)
    local k = math.min(3.2, M.TINT[1] * (1 + 0.0005 * d + 0.5 * (0.0005 * d) ^ 2))
    local tint = { k, k, k, 1 }
    stats.levels[idx] = level
    -- add-civ-hulls: the station's plating shades as its builder's materials, unless a relic of another civ holds the
    -- view's material slots this frame (then its plain twin draws)
    local civ = L.civ_rec
    local held = require("view.relic").claimed
    local plain = civ == nil or (held ~= nil and held ~= civ)
    if civ and not held and level ~= "far" and v.materials then
      local matv = require("view.materials")
      matv.apply(v, civ, tick / 60, v.xr, matv.sky(state))
      require("view.relic").claimed = civ
    end
    local function draw(layer, opts)
      local id, tris = M.mesh(L, layer, true, plain and civ ~= nil and layer ~= "far")
      if not id then return end
      opts.tint = tint
      v:mesh(id, opts)
      stats.draws = stats.draws + 1
      stats.tris = stats.tris + tris
    end
    if level == "far" then
      draw("far", { pos = p })
    else
      local ang = tick * sh.kit().spin
      local rp = { p[1] + L.spin_pos[1], p[2] + L.spin_pos[2], p[3] + L.spin_pos[3] }
      draw("core", { pos = p })
      draw("ring", { pos = rp, pitch = ang })
      if level == "detail" then
        draw("detail", { pos = p })
        draw("ringd", { pos = rp, pitch = ang })
      end
      stats.lights = stats.lights + M.beacons(v, A, L, p, cam, tick)
    end
    stats.signals = (stats.signals or 0) + M.signals(v, A, L, p, cam, tick)
    stats.lights = stats.lights + M.approach(v, A, state, idx, cam, tick)
    n = n + 1
  end
  M.stats = stats
  return stats.draws
end

return M
