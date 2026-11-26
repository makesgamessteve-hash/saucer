-- SPDX-License-Identifier: MIT
-- add-civ-hulls: how a civ dresses the outside of what it builds (civs/hulls.lua). A pure function of the civ (and,
-- for the motif, of the roster it belongs to): the same on every platform, never saved.
--   of(civ, seed) -> dress { id, motif, pattern, lit, palette = { plate, trim, panel, accent, glow }, lamps, light,
--                           edges, mats }
-- plus the geometry both hulls share (sim/stationhull.lua dresses a trader station with it, view/relic.lua a relic
-- seen from afar): element() grows one motif element along a direction, mark() lays one pattern mark on a surface,
-- boxes() the collision boxes along an element, signal() one of the civ's signal lights.
-- Four things tell two builders apart from afar:
--   silhouette  a motif of big growths (spines, fins, arches, domes, masts, cage, tendrils, shards); a roster hands
--               them out in order so no two of its first eight civs share one
--   pattern     what grows on the hull's surface, from the civ's signature rule (studs, crust, plates, inlay, cells, flow)
--   material    the plating's colours come from the civ's own material table (dominant, accent, rare)
--   lights      the signal lights blink by the civ's light model (chroma, ripple, fog, arc, orbit, dim)
local data = require("lib.data")
local sm = saucer.math
local M = {}

function M.kit() return data.load("civs/hulls.lua") end

-- a material's colour (as view/materials.lua's base_color: two thirds of the way from its dark end to its bright)
function M.base(id)
  local r = data.load("civs/materials.lua")[id]
  if not r then return { 0.6, 0.6, 0.6 } end
  return { (r.lo[1] + r.hi[1] * 2) / 3, (r.lo[2] + r.hi[2] * 2) / 3, (r.lo[3] + r.hi[3] * 2) / 3 }
end

-- lift a colour so its brightest channel is at least lo (a black material still reads against space)
function M.lift(c, lo)
  local mx = math.max(c[1], c[2], c[3], 0.001)
  if mx >= lo then return { c[1], c[2], c[3] } end
  local k = lo / mx
  return { c[1] * k, c[2] * k, c[3] * k }
end

-- the motifs of a roster: each civ in index order gets its massing's liking unless an earlier one took it, else the
-- first free motif in the kit's order -> { [civ id] = motif }
local by_roster = {}
function M.assign(list)
  local K = M.kit()
  local taken, out = {}, {}
  for _, civ in ipairs(list) do
    local want = K.prefer[civ.massing or ""]
    if not want or taken[want] then
      want = nil
      for _, m in ipairs(K.motifs) do
        if not taken[m] then want = m break end
      end
      want = want or K.motifs[((civ.index or 0) % #K.motifs) + 1]
    end
    taken[want] = true
    out[civ.id] = want
  end
  return out
end

-- a civ's motif: its roster's assignment when the civ is in the roster of `seed`, else its massing's liking
function M.motif(civ, seed)
  local K = M.kit()
  if seed then
    local map = by_roster[seed]
    if not map then
      map = M.assign(require("sim.civs").universe(seed))
      by_roster[seed] = map
    end
    if map[civ.id] then return map[civ.id] end
  end
  return K.prefer[civ.massing or ""] or K.motifs[((civ.index or 0) % #K.motifs) + 1]
end

local cache = {}
function M.of(civ, seed)
  civ = civ or require("sim.civs").vyrr()
  seed = seed or require("sim.civs").current()
  local key = civ.id .. ":" .. tostring(seed)
  if cache[key] then return cache[key] end
  local K = M.kit()
  local m = civ.materials or {}
  local lang = civ.language or {}
  local light = lang.light or {}
  local dom, acc, rare = m.dominant and m.dominant.id or "membrane", m.accent and m.accent.id or "chrome",
                         m.rare and m.rare.id or "amethyst"
  local plate = M.lift(M.base(dom), 0.5)
  local lamps = lang.lamp_colors or { { 0.78, 0.42, 1.0 }, { 1.0, 0.36, 0.46 }, { 0.45, 0.85, 1.0 } }
  local rule = m.signature and m.signature.rule or "PIERCE"
  local pat = K.patterns[rule] or K.patterns.PIERCE
  local lm = K.lights[light.model or "chromatic"] or K.lights.chromatic
  local d = {
    id = civ.id, motif = M.motif(civ, seed), rule = rule, pattern = pat.kind, lit = pat.lit,
    palette = { plate = plate, trim = M.lift(M.base(acc), 0.45), panel = { plate[1] * 0.45, plate[2] * 0.45, plate[3] * 0.45 },
                accent = M.lift(M.base(rare), 0.6), glow = lamps[1] },
    lamps = lamps, light = { kind = lm.kind, period = lm.period, size = lm.size, model = light.model or "chromatic" },
    edges = lang.edges or lang.edge or "round", mats = { dominant = dom, accent = acc, rare = rare },
  }
  cache[key] = d
  return d
end

-- the roll and pitch that turn a part's +y onto the unit direction d (yaw 0): +y -> (-sin roll, cos roll cos pitch,
-- cos roll sin pitch), as the engine applies roll (z), then pitch (x), then yaw (y)
function M.orient(d)
  local h = sm.sqrt(d[2] * d[2] + d[3] * d[3])
  local roll = sm.atan2(-d[1], h)
  local pitch = h > 1e-6 and sm.atan2(d[3], d[2]) or 0
  return roll, pitch
end

local function norm(v)
  local l = sm.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  if l < 1e-9 then return { 0, 1, 0 } end
  return { v[1] / l, v[2] / l, v[3] / l }
end
M.norm = norm
local function at(b, d, t) return { b[1] + d[1] * t, b[2] + d[2] * t, b[3] + d[3] * t } end
M.at = at
-- a unit vector at right angles to d
local function side(d)
  local a = math.abs(d[2]) < 0.9 and { 0, 1, 0 } or { 1, 0, 0 }
  return norm({ d[2] * a[3] - d[3] * a[2], d[3] * a[1] - d[1] * a[3], d[1] * a[2] - d[2] * a[1] })
end
M.side = side

-- one part along d from base: a +y part placed and turned
local function along(out, part, base, d)
  local roll, pitch = M.orient(d)
  part.roll, part.pitch, part.pos = roll, pitch, { base[1], base[2], base[3] }
  out[#out + 1] = part
  return part
end
M.along = along

-- grow one motif element from base along unit d, len long, girth thick -> its tip. P is the dress palette; seg the
-- roundness (fewer for the far silhouette); glow (optional) collects the lit bits on their own so a far layer can
-- keep only those
function M.element(out, motif, base, d, len, girth, P, seg, glow)
  glow = glow or out
  seg = seg or 10
  local tip = at(base, d, len)
  if motif == "spines" then
    along(out, { kind = "cone", c = { 0, 0, 0 }, r = girth, r1 = girth * 0.04, h = len, seg = seg, color = P.plate, mat = 1 }, base, d)
    along(out, { kind = "cone", c = { 0, 0, 0 }, r = girth * 1.5, r1 = girth * 0.9, h = len * 0.12, seg = seg, color = P.trim, mat = 3 }, base, d)
    glow[#glow + 1] = { kind = "sphere", c = at(base, d, len * 0.97), r = girth * 0.3, h = girth * 0.3, seg = 6, rings = 3, color = P.glow, emissive = 1 }
  elseif motif == "fins" then
    local roll, pitch = M.orient(d)
    out[#out + 1] = { kind = "wedge", min = { -girth * 0.05, 0, -girth * 0.5 }, max = { girth * 0.05, len, girth * 0.5 }, low = 0.15,
                      color = P.plate, mat = 1, roll = roll, pitch = pitch, pos = base }
    glow[#glow + 1] = { kind = "box", min = { -girth * 0.07, len * 0.1, -girth * 0.5 - girth * 0.03 },
                        max = { girth * 0.07, len * 0.96, -girth * 0.5 + girth * 0.03 }, color = P.glow, emissive = 1,
                        roll = roll, pitch = pitch, pos = base }
  elseif motif == "domes" then
    along(out, { kind = "hemisphere", c = { 0, 0, 0 }, r = girth, h = len, seg = seg + 4, rings = 4, color = P.plate, mat = 1 }, base, d)
    along(glow, { kind = "ring", c = { 0, 0, 0 }, rin = girth * 0.94, r = girth * 1.06, h = girth * 0.08, seg = seg + 4, color = P.glow, emissive = 1 }, base, d)
    tip = at(base, d, len)
  elseif motif == "masts" then
    along(out, { kind = "cylinder", c = { 0, 0, 0 }, r = girth, h = len, seg = 6, color = P.trim, mat = 3 }, base, d)
    for k = 1, 3 do -- yards across it, along x (the crown's masts stand at right angles to x)
      local p = at(base, d, len * (0.35 + 0.2 * k))
      local w = girth * (9 - 2 * k)
      out[#out + 1] = { kind = "box", min = { p[1] - w, p[2] - girth * 0.6, p[3] - girth * 0.6 },
                        max = { p[1] + w, p[2] + girth * 0.6, p[3] + girth * 0.6 }, color = P.plate, mat = 1 }
    end
    glow[#glow + 1] = { kind = "sphere", c = tip, r = girth * 2.2, h = girth * 2.2, seg = 6, rings = 3, color = P.glow, emissive = 1 }
  elseif motif == "cage" then
    along(out, { kind = "cylinder", c = { 0, 0, 0 }, r = girth, h = len, seg = 5, color = P.trim, mat = 3 }, base, d)
    glow[#glow + 1] = { kind = "sphere", c = tip, r = girth * 2.6, h = girth * 2.6, seg = 6, rings = 3, color = P.glow, emissive = 1 }
    glow[#glow + 1] = { kind = "sphere", c = at(base, d, len * 0.5), r = girth * 1.8, h = girth * 1.8, seg = 6, rings = 3, color = P.glow, emissive = 0.8 }
  elseif motif == "tendrils" then
    -- a chain of swellings curling back along -x as it goes
    local p, dir, r = { base[1], base[2], base[3] }, { d[1], d[2], d[3] }, girth
    local n = 7
    for k = 1, n do
      local step = len / n
      out[#out + 1] = { kind = "sphere", c = at(p, dir, step * 0.5), r = r * 1.15, h = step * 0.62, seg = seg, rings = 4, color = k % 2 == 0 and P.plate or P.trim,
                        mat = k % 2 == 0 and 1 or 3 }
      p = at(p, dir, step)
      dir = norm({ dir[1] - 0.16, dir[2], dir[3] })
      r = r * 0.86
    end
    tip = p
    glow[#glow + 1] = { kind = "sphere", c = p, r = girth * 0.9, h = girth * 0.9, seg = 8, rings = 4, color = P.glow, emissive = 1 }
  elseif motif == "shards" then
    along(out, { kind = "cone", c = { 0, 0, 0 }, r = girth, r1 = girth * 0.35, h = len * 0.8, seg = 4, color = P.accent, mat = 4 }, base, d)
    along(out, { kind = "cone", c = { 0, len * 0.8, 0 }, r = girth * 0.35, r1 = 0.01, h = len * 0.2, seg = 4, color = P.accent, mat = 4 }, base, d)
    along(glow, { kind = "cone", c = { 0, 0, 0 }, r = girth * 0.42, r1 = girth * 0.12, h = len * 0.86, seg = 4, color = P.glow, emissive = 0.7 }, base, d)
  else -- arches: a single strut (the crown adds the hoops); the strut's head lit
    along(out, { kind = "cylinder", c = { 0, 0, 0 }, r = girth, h = len, seg = 6, color = P.trim, mat = 3 }, base, d)
    glow[#glow + 1] = { kind = "sphere", c = tip, r = girth * 1.6, h = girth * 1.6, seg = 6, rings = 3, color = P.glow, emissive = 1 }
  end
  return tip
end

-- the collision boxes along an element (a little inside what is drawn): k cubes stepping along d, each as thick as
-- the element is there; the fins get flat boxes. Deterministic (saucer.math only), so the sim may use them.
function M.boxes(list, motif, base, d, len, girth)
  local n = math.max(2, math.min(8, math.floor(len / math.max(girth * 2, 1)) + 1))
  if motif == "domes" then
    local c = at(base, d, len * 0.4)
    local h = girth * 0.7
    list[#list + 1] = { { c[1] - h, c[2] - h, c[3] - h }, { c[1] + h, c[2] + h, c[3] + h } }
    return list
  end
  for k = 0, n - 1 do
    local t = (k + 0.5) / n
    local c = at(base, d, len * t)
    local w
    if motif == "fins" then w = girth * 0.3 * (1 - 0.6 * t)
    elseif motif == "spines" or motif == "shards" then w = girth * 0.7 * (1 - t)
    elseif motif == "tendrils" then w = girth * 0.8 * (0.86 ^ (k * 7 / n))
    else w = girth * 0.7 end
    w = math.max(w, 0.5)
    list[#list + 1] = { { c[1] - w, c[2] - w, c[3] - w }, { c[1] + w, c[2] + w, c[3] + w } }
  end
  return list
end

-- one pattern mark at p on a surface facing unit n, size big -> the parts (into out; the lit ones into glow)
function M.mark(out, glow, kind, p, n, size, P)
  glow = glow or out
  local s = side(n)
  local t = { n[2] * s[3] - n[3] * s[2], n[3] * s[1] - n[1] * s[3], n[1] * s[2] - n[2] * s[1] }
  if kind == "studs" then
    along(out, { kind = "cone", c = { 0, 0, 0 }, r = size * 0.18, r1 = 0.02, h = size * 0.9, seg = 6, color = P.trim, mat = 3 }, p, n)
    along(glow, { kind = "ring", c = { 0, 0, 0 }, rin = size * 0.2, r = size * 0.42, h = size * 0.05, seg = 10, color = P.glow, emissive = 1 }, p, n)
  elseif kind == "crust" then
    for k = 0, 2 do
      local q = at(at(p, s, (k - 1) * size * 0.35), t, ((k % 2) - 0.5) * size * 0.3)
      local lit = k < 2
      local part = { kind = "sphere", c = q, r = size * (0.22 + 0.05 * k), h = size * 0.16, seg = 7, rings = 3, color = lit and P.glow or P.panel,
                     emissive = lit and 0.7 or nil, mat = (not lit) and 1 or nil }
      if lit then glow[#glow + 1] = part else out[#out + 1] = part end
    end
  elseif kind == "plates" then
    for k = 0, 1 do
      local q = at(p, s, (k - 0.5) * size * 0.55)
      along(out, { kind = "cylinder", c = { 0, 0, 0 }, r = size * 0.36, h = size * 0.06, seg = 6, color = P.trim, mat = 3 }, at(q, n, size * 0.04 * k), n)
    end
    along(glow, { kind = "ring", c = { 0, 0, 0 }, rin = size * 0.34, r = size * 0.4, h = size * 0.03, seg = 6, color = P.glow, emissive = 1 }, p, n)
  elseif kind == "inlay" then
    for k = -1, 1 do
      local q = at(p, t, k * size * 0.25)
      local roll, pitch = M.orient(s)
      glow[#glow + 1] = { kind = "box", min = { -size * 0.06, -size * 0.7, -size * 0.06 }, max = { size * 0.06, size * 0.7, size * 0.06 },
                          color = P.glow, emissive = 1, roll = roll, pitch = pitch, pos = q }
    end
  elseif kind == "cells" then
    along(out, { kind = "ring", c = { 0, 0, 0 }, rin = size * 0.32, r = size * 0.45, h = size * 0.12, seg = 6, color = P.trim, mat = 3 }, p, n)
    along(glow, { kind = "hemisphere", c = { 0, 0, 0 }, r = size * 0.3, h = size * 0.12, seg = 6, rings = 2, color = P.glow, emissive = 0.8 }, p, n)
  else -- flow: long streaks along the surface
    for k = 0, 1 do
      local q = at(at(p, t, (k - 0.5) * size * 0.3), n, size * 0.02)
      local roll, pitch = M.orient(s)
      glow[#glow + 1] = { kind = "box", min = { -size * 0.09, -size * (0.7 - 0.2 * k), -size * 0.09 }, max = { size * 0.09, size * (0.7 - 0.2 * k), size * 0.09 },
                      color = P.glow, emissive = 0.9, roll = roll, pitch = pitch, pos = q }
    end
  end
end

-- one signal light of the dress: { p, c, kind, size, period, phase, k (its place in the run, for ripples and orbits) }
function M.signal(list, dress, p, size, k, n)
  local L = dress.light
  list[#list + 1] = { p = { p[1], p[2], p[3] }, c = dress.lamps[(k - 1) % #dress.lamps + 1], kind = L.kind, size = size * L.size,
                      period = L.period, phase = (k * 37) % L.period, k = k, n = n }
  return list[#list]
end

-- how a signal shows at a tick -> alpha 0..1 and its colour (render side: view/stationhull.lua and view/relic.lua)
function M.signal_at(l, tick, lamps)
  local per = l.period
  local t = ((tick + l.phase) % per) / per
  local kind = l.kind
  local c = l.c
  if kind == "chroma" then
    local n = #lamps
    local f = ((tick / per) + (l.k or 0) / math.max(1, l.n or 1)) % 1 * n
    local i = math.floor(f)
    local a, b = lamps[i % n + 1], lamps[(i + 1) % n + 1]
    local u = f - i
    return 0.9, { a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u }
  elseif kind == "ripple" then
    local w = ((tick / per) - (l.k or 0) / math.max(1, l.n or 1)) % 1
    return 0.25 + 0.75 * math.max(0, 1 - math.abs(w - 0.5) * 6), c
  elseif kind == "fog" then
    return 0.35 + 0.3 * (0.5 + 0.5 * sm.sin(t * sm.tau)), c
  elseif kind == "arc" then
    local pair = math.floor((l.k or 0) / 2)
    local on = (math.floor(tick / per) % math.max(1, math.floor((l.n or 2) / 2))) == pair % math.max(1, math.floor((l.n or 2) / 2))
    return on and 1 or 0.12, on and { 0.85, 0.95, 1.0 } or c
  elseif kind == "orbit" then
    local lead = math.floor((tick / per) * (l.n or 1)) % math.max(1, l.n or 1)
    local d = ((l.k or 0) - 1 - lead) % math.max(1, l.n or 1)
    return d == 0 and 1 or (d == 1 and 0.5 or 0.18), c
  end
  return 0.18 + 0.12 * (0.5 + 0.5 * sm.sin(t * sm.tau)), c   -- dim
end

-- the lift a signal at distance d needs against a fog of this density (the fog keeps exp(-density d) of it), capped
-- (e^x as (1 + x/1024)^1024: ten squarings; the sandbox has no exp)
function M.fog_lift(d, density)
  local g = 1 + (density or 0) * d / 1024
  for _ = 1, 10 do g = g * g end
  return math.min(M.kit().signal.boost, g)
end

-- a signal's billboard at distance d -> size, tint, layers: the colour at full strength (a tint above 1 does not
-- draw), the alpha up, the glow wider and stacked (glows add) as the fog would swallow it
function M.signal_look(l, d, a, c, density)
  local K = M.kit().signal
  local up = M.fog_lift(d, density)
  local mx = math.max(c[1], c[2], c[3], 0.001)
  local size = math.max(l.size, d * K.min_px) * (1 + 0.15 * (up - 1))
  return size, { c[1] / mx, c[2] / mx, c[3] / mx, math.min(1, a * up) }, math.min(3, math.floor(up / 2) + 1)
end

return M
