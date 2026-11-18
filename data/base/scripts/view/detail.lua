-- SPDX-License-Identifier: MIT
-- Derelict detail generators (OpenSpec add-detail-pass). For one room, one
-- exterior solid or a whole site they return mesh parts: wall panels and
-- greebles, pipes and conduits, ceiling beams, lit strips, glyph decals and
-- signage, hatch frames, torn sections, floating debris, hanging cables,
-- floor props (crates, machinery, consoles, alien furniture), city plazas
-- with planters, fountains, obelisks, broken columns and overgrowth, tower
-- window grids and roofs, sky bridges, station truss lattices and ship spine
-- ribs and nozzles.
--
-- Everything is a pure function of the ruin's seed and layout (one child seed
-- per room or solid), so the same seed always gives the same detail. It is
-- visual only: nothing here is read by the sim or by collision, and it keeps
-- out of doorways, hatch shafts and loot slots. Each room, solid and site has
-- a part budget (M.BUDGET) so web builds stay fast; view/render.lua only
-- draws detail near the camera.
local ruinm = require("sim.ruin")
local sm = saucer.math
local M = {}

M.BUDGET = { big = 520, shaft = 380, small = 120, solid = 140, links = 240 }

-- per-kit look; a kit file can override any of these with `detail = { ... }`
M.STYLES = {
  starship = {
    metal = { 0.40, 0.45, 0.52 }, dark = { 0.16, 0.18, 0.22 }, pipe = { 0.52, 0.5, 0.44 }, accent = { 0.35, 1.0, 0.8 },
    glyph = { 0.5, 0.9, 1.0 }, hazard = { 0.95, 0.75, 0.15 }, crate = { 0.38, 0.44, 0.5 }, torn = 45, float = 10,
    cables = 3, furniture = "pods",
  },
  station = {
    metal = { 0.52, 0.46, 0.4 }, dark = { 0.2, 0.17, 0.14 }, pipe = { 0.62, 0.36, 0.2 }, accent = { 1.0, 0.6, 0.25 },
    glyph = { 1.0, 0.82, 0.4 }, hazard = { 1.0, 0.7, 0.1 }, crate = { 0.6, 0.48, 0.3 }, torn = 35, float = 8,
    cables = 4, furniture = "bunks",
  },
  city = {
    metal = { 0.58, 0.6, 0.64 }, dark = { 0.22, 0.24, 0.28 }, pipe = { 0.46, 0.5, 0.48 }, accent = { 1.0, 0.85, 0.5 },
    glyph = { 0.55, 1.0, 0.7 }, hazard = { 0.9, 0.8, 0.5 }, crate = { 0.5, 0.48, 0.42 }, torn = 25, float = 6,
    cables = 1, furniture = "plaza", overgrowth = 75, green = { 0.22, 0.55, 0.26 },
  },
  -- add-wider-dark: the hive, resin and brood pods
  hive = {
    metal = { 0.62, 0.48, 0.28 }, dark = { 0.24, 0.16, 0.08 }, pipe = { 0.7, 0.52, 0.22 }, accent = { 1.0, 0.65, 0.15 },
    glyph = { 1.0, 0.75, 0.3 }, hazard = { 1.0, 0.5, 0.1 }, crate = { 0.55, 0.4, 0.2 }, torn = 20, float = 4,
    cables = 2, furniture = "pods", overgrowth = 55, green = { 0.75, 0.5, 0.15 },
  },
}

function M.style(k)
  local s = {}
  for key, v in pairs(M.STYLES[k.style or k.id] or M.STYLES.starship) do s[key] = v end
  for key, v in pairs(k.detail or {}) do s[key] = v end
  return s
end

local function scale(c, f) return { c[1] * f, c[2] * f, c[3] * f } end
local function overlaps(a0, a1, b0, b1) return a0 < b1 and a1 > b0 end

-- a part list with a hard cap: adds are dropped once the budget is used up
local function sink(limit)
  local s = { parts = {}, limit = limit, dropped = 0 }
  function s.add(p)
    if #s.parts >= s.limit then
      s.dropped = s.dropped + 1
      return false
    end
    s.parts[#s.parts + 1] = p
    return true
  end
  function s.full() return #s.parts >= s.limit end
  function s.box(mn, mx, color, emissive)
    return s.add({ kind = "box", min = mn, max = mx, color = color, emissive = emissive })
  end
  return s
end
M.sink = sink

-- a cylinder (or a 4-sided strut) from a to b
local function tube(a, b, r, color, seg, emissive)
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local len = sm.sqrt(dx * dx + dy * dy + dz * dz)
  return { kind = "cylinder", c = { 0, 0, 0 }, r = r, h = len, seg = seg or 6, color = color, emissive = emissive,
           pitch = sm.atan2(sm.sqrt(dx * dx + dz * dz), dy), yaw = sm.atan2(dx, dz), pos = { a[1], a[2], a[3] } }
end
M.tube = tube
local function bar(a, b, w, color)
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local len = sm.sqrt(dx * dx + dy * dy + dz * dz)
  return { kind = "box", min = { -w / 2, 0, -w / 2 }, max = { w / 2, len, w / 2 }, color = color,
           pitch = sm.atan2(sm.sqrt(dx * dx + dz * dz), dy), yaw = sm.atan2(dx, dz), pos = { a[1], a[2], a[3] } }
end
M.bar = bar

function M.budget_of(r, k)
  if r.kind == "shaft" then return M.BUDGET.shaft end
  if r.class >= (k.big or 4) then return M.BUDGET.big end
  return M.BUDGET.small
end

-- room context: boxes, holes per face, keep-out boxes, the rng and the sink
local SIDES = { { 1, -1 }, { 1, 1 }, { 3, -1 }, { 3, 1 } }
local function context(ruin, r, k, origin)
  local c = { ruin = ruin, r = r, k = k, st = M.style(k), big = r.class >= (k.big or 4) }
  c.mn, c.mx = ruinm.room_box(r, k, origin)
  local t = k.wall
  c.imn = { c.mn[1] + t, c.mn[2] + t, c.mn[3] + t }
  c.imx = { c.mx[1] - t, c.mx[2] - t, c.mx[3] - t }
  c.holes = {}
  for _, f in ipairs(ruinm.FACES) do
    c.holes[ruinm.face_name(f[1], f[2])] = ruinm.face_holes(r, ruin.doors, ruin.rooms, k, origin, f[1], f[2])
  end
  c.rng = saucer.rng.new(saucer.seed_child(ruin.seed, "detail", r.id))
  c.out = sink(M.budget_of(r, k))
  -- keep-outs: door corridors, hatch columns and loot slots stay clear
  local keep = {}
  local depth = c.big and 16 or 5
  for _, f in ipairs(SIDES) do
    local axis, sign = f[1], f[2]
    local l = ruinm.lateral(axis)
    for _, h in ipairs(c.holes[ruinm.face_name(axis, sign)]) do
      local a, b = {}, {}
      if sign < 0 then a[axis], b[axis] = c.mn[axis] - 1, c.imn[axis] + depth
      else a[axis], b[axis] = c.imx[axis] - depth, c.mx[axis] + 1 end
      a[l], b[l] = h[1] - 1.5, h[2] + 1.5
      a[2], b[2] = h[3] - 1, h[4] + 1
      keep[#keep + 1] = { a, b }
    end
  end
  for _, name in ipairs({ "-y", "+y" }) do
    for _, h in ipairs(c.holes[name]) do
      keep[#keep + 1] = { { h[1] - 2.5, c.mn[2] - 1, h[3] - 2.5 }, { h[2] + 2.5, c.mx[2] + 1, h[4] + 2.5 } }
    end
  end
  for _, s in ipairs(ruin.slots or {}) do
    if s.room == r.id then
      keep[#keep + 1] = { { s.pos[1] - 3, s.pos[2] - 3, s.pos[3] - 3 }, { s.pos[1] + 3, s.pos[2] + 3, s.pos[3] + 3 } }
    end
  end
  if r.echo_pos then
    local e = r.echo_pos
    keep[#keep + 1] = { { e[1] - 3, e[2] - 3, e[3] - 3 }, { e[1] + 3, e[2] + 3, e[3] + 3 } }
  end
  c.keep = keep
  return c
end
M.context = context

-- is a world box clear of every keep-out?
local function clear(c, a, b)
  for _, q in ipairs(c.keep) do
    if overlaps(a[1], b[1], q[1][1], q[2][1]) and overlaps(a[2], b[2], q[1][2], q[2][2])
        and overlaps(a[3], b[3], q[1][3], q[2][3]) then
      return false
    end
  end
  return true
end
M.clear = clear

-- is the face's (u, v) rectangle clear of its door holes (with padding)?
local function face_clear(c, f, u0, u1, v0, v1, pad)
  pad = pad or 0.5
  for _, h in ipairs(c.holes[ruinm.face_name(f[1], f[2])]) do
    if overlaps(u0, u1, h[1] - pad, h[2] + pad) and overlaps(v0, v1, h[3] - pad, h[4] + pad) then return false end
  end
  return true
end

-- a box against side face f: lateral u0..u1, height v0..v1, depth d0..d1
-- measured inward from the inner wall surface (negative = outside the hull)
local function wall_box(c, f, u0, u1, v0, v1, d0, d1)
  local axis, sign = f[1], f[2]
  local l = ruinm.lateral(axis)
  local a, b = {}, {}
  if sign < 0 then a[axis], b[axis] = c.imn[axis] + d0, c.imn[axis] + d1
  else a[axis], b[axis] = c.imx[axis] - d1, c.imx[axis] - d0 end
  a[l], b[l] = u0, u1
  a[2], b[2] = v0, v1
  return a, b
end

-- is face f of room r open to space (no room or solid right behind it)?
local function exposed(c, f)
  local axis, sign = f[1], f[2]
  local r = c.r
  for _, q in ipairs(c.ruin.rooms) do
    if q.id ~= r.id then
      local touch = sign > 0 and q.cell[axis] == r.cell[axis] + r.size[axis] or q.cell[axis] + q.size[axis] == r.cell[axis]
      local ok = touch
      for a = 1, 3 do
        if a ~= axis and not overlaps(q.cell[a], q.cell[a] + q.size[a], r.cell[a], r.cell[a] + r.size[a]) then ok = false end
      end
      if ok then return false end
    end
  end
  for _, s in ipairs(c.ruin.solids or {}) do
    local face = sign > 0 and c.mx[axis] or c.mn[axis]
    local sface = sign > 0 and s[1][axis] or s[2][axis]
    if math.abs(face - sface) < 0.01 then
      local ok = true
      for a = 1, 3 do
        if a ~= axis and not overlaps(s[1][a], s[2][a], c.mn[a], c.mx[a]) then ok = false end
      end
      if ok then return false end
    end
  end
  return true
end
M.exposed = exposed

local function lat_range(c, f)
  local l = ruinm.lateral(f[1])
  return c.imn[l], c.imx[l]
end

-- 1. wall panels and greebles: raised plates in a loose grid, a few with lights
local function wall_panels(c)
  local rng, st, out = c.rng, c.st, c.out
  local step = c.big and 7 or 3
  local h = c.imx[2] - c.imn[2]
  local rows = c.big and math.min(6, math.floor(h / 6)) or 1
  for _, f in ipairs(SIDES) do
    local u0, u1 = lat_range(c, f)
    local u = u0 + 1 + rng:float() * 2
    while u < u1 - step * 0.6 and not out.full() do
      for row = 1, rows do
        if rng:int(1, 100) <= 55 then
          local w = step * (0.4 + rng:float() * 0.45)
          local v0 = c.imn[2] + (c.big and (2 + (row - 1) * (h - 4) / rows) or 0.6) + rng:float() * 1.2
          local ph = c.big and (1.5 + rng:float() * 3.5) or (0.6 + rng:float() * 1.0)
          local v1 = math.min(v0 + ph, c.imx[2] - 0.5)
          if v1 > v0 + 0.3 and face_clear(c, f, u, u + w, v0, v1) then
            local d = c.big and (0.15 + rng:float() * 0.45) or (0.06 + rng:float() * 0.12)
            local col = scale(st.metal, 0.8 + rng:float() * 0.45)
            local a, b = wall_box(c, f, u, u + w, v0, v1, 0, d)
            out.box(a, b, col)
            if rng:int(1, 100) <= 30 then
              local s = c.big and 0.35 or 0.12
              local la, lb = wall_box(c, f, u + w * 0.5 - s, u + w * 0.5 + s, v1 - s * 2.5, v1 - s * 0.5, d, d + 0.05)
              out.box(la, lb, rng:int(0, 1) == 0 and st.accent or { 1, 0.35, 0.25 }, 1)
            elseif rng:int(1, 100) <= 35 then
              -- vent slats
              for k = 0, 2 do
                local vv = v0 + (v1 - v0) * (0.25 + k * 0.2)
                local sa, sb = wall_box(c, f, u + w * 0.15, u + w * 0.85, vv, vv + (v1 - v0) * 0.08, d, d + 0.06)
                out.box(sa, sb, st.dark)
              end
            end
          end
        end
      end
      u = u + step
    end
  end
end

-- 2. pipes and conduits: horizontal runs along one or two walls with brackets
local function pipes(c)
  local rng, st, out = c.rng, c.st, c.out
  local n = c.big and rng:int(1, 3) or rng:int(0, 1)
  for _ = 1, n do
    local f = SIDES[rng:int(1, 4)]
    local axis = f[1]
    local l = ruinm.lateral(axis)
    local r = c.big and (0.25 + rng:float() * 0.35) or 0.1
    local v = c.big and c.imn[2] + 3 + rng:float() * math.max(1, (c.imx[2] - c.imn[2]) - 6) or c.imx[2] - 0.35
    local d = r + (c.big and 0.3 or 0.08)
    local u0, u1 = lat_range(c, f)
    -- split the run around door holes
    local cuts = { { u0 + 0.5, u1 - 0.5 } }
    for _, h in ipairs(c.holes[ruinm.face_name(f[1], f[2])]) do
      if v + r > h[3] - 0.5 and v - r < h[4] + 0.5 then
        local nxt = {}
        for _, s in ipairs(cuts) do
          if h[1] - 0.8 > s[1] then nxt[#nxt + 1] = { s[1], math.min(s[2], h[1] - 0.8) } end
          if h[2] + 0.8 < s[2] then nxt[#nxt + 1] = { math.max(s[1], h[2] + 0.8), s[2] } end
        end
        cuts = nxt
      end
    end
    local twin = c.big and rng:int(0, 1) == 1
    for _, s in ipairs(cuts) do
      if s[2] - s[1] > 2 then
        for k = 0, twin and 1 or 0 do
          local vv = v + k * (r * 2.6)
          local pa = wall_box(c, f, s[1], s[1], vv, vv, d, d)
          local qa = wall_box(c, f, s[2], s[2], vv, vv, d, d)
          out.add(tube(pa, qa, r, k == 0 and st.pipe or scale(st.pipe, 0.8), 6))
        end
        local u = s[1] + 1.5
        while u < s[2] - 1 do
          local a, b = wall_box(c, f, u - 0.15, u + 0.15, v - r - 0.1, v + r * (twin and 3.6 or 1) + 0.1, 0, d + r)
          out.box(a, b, st.dark)
          u = u + (c.big and 4 or 2.5)
        end
      end
    end
  end
end

-- 3. lit strips where the walls meet the floor (and the ceiling in big rooms)
local function strips(c)
  local st, out = c.st, c.out
  for _, f in ipairs(SIDES) do
    local u0, u1 = lat_range(c, f)
    local ys = c.big and { c.imn[2] + 0.3, c.imx[2] - 1.0 } or { c.imn[2] + 0.15 }
    for _, y in ipairs(ys) do
      local u = u0 + 0.3
      local h = c.big and 0.25 or 0.08
      -- walk along the wall, breaking at holes
      local spans = { { u, u1 - 0.3 } }
      for _, hole in ipairs(c.holes[ruinm.face_name(f[1], f[2])]) do
        if y + h > hole[3] and y < hole[4] then
          local nxt = {}
          for _, s in ipairs(spans) do
            if hole[1] - 0.3 > s[1] then nxt[#nxt + 1] = { s[1], math.min(s[2], hole[1] - 0.3) } end
            if hole[2] + 0.3 < s[2] then nxt[#nxt + 1] = { math.max(s[1], hole[2] + 0.3), s[2] } end
          end
          spans = nxt
        end
      end
      for _, s in ipairs(spans) do
        if s[2] - s[1] > 0.5 then
          local a, b = wall_box(c, f, s[1], s[2], y, y + h, 0, c.big and 0.12 or 0.04)
          out.box(a, b, st.accent, 1)
        end
      end
    end
  end
end

-- 4. glyph decals: a dark plate with a random grid of lit cells; and a
-- glyph sign over every side door
local function glyph(c, f, u, v, cell, cols, rows)
  local rng, st, out = c.rng, c.st, c.out
  local a, b = wall_box(c, f, u, u + cell * cols, v, v + cell * rows, 0, 0.06)
  out.box(a, b, st.dark)
  for i = 0, cols - 1 do
    for j = 0, rows - 1 do
      if rng:int(1, 100) <= 45 then
        local ga, gb = wall_box(c, f, u + i * cell + cell * 0.15, u + (i + 1) * cell - cell * 0.15, v + j * cell + cell * 0.15,
                                v + (j + 1) * cell - cell * 0.15, 0.06, 0.09)
        out.box(ga, gb, st.glyph, 1)
      end
    end
  end
end
local function glyphs(c)
  local rng = c.rng
  local cell = c.big and 0.7 or 0.12
  for _, f in ipairs(SIDES) do
    for _, h in ipairs(c.holes[ruinm.face_name(f[1], f[2])]) do
      local cols = math.max(3, math.floor((h[2] - h[1]) / cell * 0.5))
      local v = h[4] + (c.big and 1.5 or 0.15)
      if v + cell * 2 < c.imx[2] - 0.2 then glyph(c, f, (h[1] + h[2]) / 2 - cols * cell / 2, v, cell, cols, 2) end
    end
  end
  local n = c.big and rng:int(1, 3) or rng:int(0, 1)
  for _ = 1, n do
    local f = SIDES[rng:int(1, 4)]
    local u0, u1 = lat_range(c, f)
    local cols, rows = rng:int(3, 6), rng:int(2, 4)
    local w = cols * cell
    local u = u0 + 1 + rng:float() * math.max(0, (u1 - u0) - w - 2)
    local v = c.imn[2] + (c.big and 4 + rng:float() * 6 or 1.2)
    if v + rows * cell < c.imx[2] - 0.3 and face_clear(c, f, u, u + w, v, v + rows * cell, 1) then glyph(c, f, u, v, cell, cols, rows) end
  end
end

-- 5. hatch frames: hazard-striped frames round side doors, lit rims round hatches
local function hatches(c)
  local st, out = c.st, c.out
  for _, f in ipairs(SIDES) do
    for _, h in ipairs(c.holes[ruinm.face_name(f[1], f[2])]) do
      local w = c.big and 1.0 or 0.12
      local d = c.big and 0.6 or 0.1
      for _, side in ipairs({ { h[1] - w, h[1] }, { h[2], h[2] + w } }) do
        local n = c.big and 6 or 2
        local seg = (h[4] - h[3]) / n
        for k = 0, n - 1 do
          local a, b = wall_box(c, f, side[1], side[2], h[3] + k * seg, h[3] + (k + 1) * seg, -0.02, d)
          out.box(a, b, k % 2 == 0 and st.hazard or st.dark)
        end
      end
      if h[4] + w < c.imx[2] then
        local a, b = wall_box(c, f, h[1] - w, h[2] + w, h[4], h[4] + w, -0.02, d)
        out.box(a, b, st.dark)
        local la, lb = wall_box(c, f, h[1], h[2], h[4] + w * 0.35, h[4] + w * 0.65, d, d + 0.05)
        out.box(la, lb, st.accent, 1)
      end
    end
  end
  for _, name in ipairs({ "-y", "+y" }) do
    for _, h in ipairs(c.holes[name]) do
      local y = name == "-y" and c.imn[2] or c.imx[2] - 0.3
      local w = c.big and 1.2 or 0.15
      out.box({ h[1] - w, y, h[3] - w }, { h[2] + w, y + 0.3, h[3] }, st.hazard)
      out.box({ h[1] - w, y, h[4] }, { h[2] + w, y + 0.3, h[4] + w }, st.hazard)
      out.box({ h[1] - w, y, h[3] }, { h[1], y + 0.3, h[4] }, st.dark)
      out.box({ h[2], y, h[3] }, { h[2] + w, y + 0.3, h[4] }, st.dark)
      out.box({ h[1] - w, y + 0.3, h[3] - w * 0.5 }, { h[2] + w, y + 0.36, h[3] - w * 0.3 }, st.accent, 1)
    end
  end
end

-- 6. beams: ceiling beams across smaller rooms and wings
local function beams(c)
  local st, out = c.st, c.out
  if c.r.kind == "shaft" then return end
  local along = (c.imx[1] - c.imn[1]) > (c.imx[3] - c.imn[3]) and 1 or 3
  local across = along == 1 and 3 or 1
  local step = c.big and 10 or 3
  local depth = c.big and 1.4 or 0.2
  local a0 = c.imn[along] + step / 2
  while a0 < c.imx[along] - 1 do
    local mn, mx = {}, {}
    mn[along], mx[along] = a0 - (c.big and 0.5 or 0.1), a0 + (c.big and 0.5 or 0.1)
    mn[across], mx[across] = c.imn[across], c.imx[across]
    mn[2], mx[2] = c.imx[2] - depth, c.imx[2]
    local blocked = false
    for _, h in ipairs(c.holes["+y"]) do
      if overlaps(mn[1], mx[1], h[1] - 1, h[2] + 1) and overlaps(mn[3], mx[3], h[3] - 1, h[4] + 1) then blocked = true end
    end
    if not blocked then out.box(mn, mx, scale(st.metal, 0.75)) end
    a0 = a0 + step
  end
end

-- 7. cables: sagging from the ceiling in big rooms and shafts
local function cables(c)
  local rng, st, out = c.rng, c.st, c.out
  if not c.big then return end
  local n = rng:int(1, st.cables or 2)
  for _ = 1, n do
    local p = { c.imn[1] + 3 + rng:float() * (c.imx[1] - c.imn[1] - 6), c.imx[2] - 0.2,
                c.imn[3] + 3 + rng:float() * (c.imx[3] - c.imn[3] - 6) }
    local q = { p[1] + (rng:float() - 0.5) * 24, p[2], p[3] + (rng:float() - 0.5) * 24 }
    q[1] = math.max(c.imn[1] + 1, math.min(c.imx[1] - 1, q[1]))
    q[3] = math.max(c.imn[3] + 1, math.min(c.imx[3] - 1, q[3]))
    local sag = 2 + rng:float() * 5
    local pts = {}
    for i = 0, 6 do
      local t = i / 6
      pts[#pts + 1] = { p[1] + (q[1] - p[1]) * t, p[2] - sag * 4 * t * (1 - t), p[3] + (q[3] - p[3]) * t }
    end
    local ok = true
    for _, pt in ipairs(pts) do
      if not clear(c, { pt[1] - 0.3, pt[2] - 0.3, pt[3] - 0.3 }, { pt[1] + 0.3, pt[2] + 0.3, pt[3] + 0.3 }) then ok = false end
    end
    if ok then
      local col = rng:int(0, 2) == 0 and { 0.7, 0.2, 0.15 } or st.dark
      for i = 1, #pts - 1 do out.add(tube(pts[i], pts[i + 1], 0.12, col, 4)) end
    end
  end
end

-- 8. torn sections: a scorched breach with peeled plates, bent ribs and sparks
local function torn(c)
  local rng, st, out = c.rng, c.st, c.out
  if rng:int(1, 100) > (st.torn or 30) then return end
  local f = SIDES[rng:int(1, 4)]
  local u0, u1 = lat_range(c, f)
  local s = c.big and (5 + rng:float() * 5) or 0.8
  local u = u0 + 1 + rng:float() * math.max(0, u1 - u0 - s - 2)
  local v = c.imn[2] + (c.big and 3 + rng:float() * math.max(0, c.imx[2] - c.imn[2] - s - 6) or 0.6)
  if not face_clear(c, f, u, u + s, v, v + s, 1) then return end
  local a, b = wall_box(c, f, u, u + s, v, v + s, 0, 0.05)
  out.box(a, b, scale(st.dark, 0.5))
  local axis, sign = f[1], f[2]
  local l = ruinm.lateral(axis)
  for k = 1, c.big and 9 or 3 do
    local pu, pv = u + rng:float() * s, v + rng:float() * s
    local pa = wall_box(c, f, pu, pu, pv, pv, 0.1, 0.1)
    local len = (c.big and 1 or 0.2) + rng:float() * (c.big and 2.5 or 0.4)
    local p = {
      kind = k % 3 == 0 and "box" or "wedge", min = { -len * 0.4, 0, -0.04 }, max = { len * 0.4, len, 0.04 }, low = 0,
      color = scale(st.metal, 0.5 + rng:float() * 0.3), pos = pa,
      yaw = (axis == 1 and sm.pi / 2 or 0) + (rng:float() - 0.5) * 1.2, pitch = sign * (0.5 + rng:float() * 0.9),
      roll = (rng:float() - 0.5) * 1.5,
    }
    out.add(p)
  end
  for k = 1, c.big and 3 or 1 do
    local pu, pv = u + rng:float() * s, v + rng:float() * s
    local pa = wall_box(c, f, pu, pu, pv, pv, 0, 0)
    local pb = { pa[1], pa[2], pa[3] }
    pb[axis] = pb[axis] - sign * (c.big and (1.5 + rng:float() * 2) or 0.4)
    pb[l] = pb[l] + (rng:float() - 0.5) * 2
    pb[2] = pb[2] + (rng:float() - 0.5) * 2
    out.add(bar(pa, pb, c.big and 0.35 or 0.06, scale(st.metal, 0.6)))
    if k == 1 then out.box({ pb[1] - 0.12, pb[2] - 0.12, pb[3] - 0.12 }, { pb[1] + 0.12, pb[2] + 0.12, pb[3] + 0.12 }, { 1, 0.6, 0.2 }, 1) end
  end
end

-- 9. floating debris: tumbling scraps near the walls of big rooms and shafts
local function floating(c)
  local rng, st, out = c.rng, c.st, c.out
  if not c.big then return end
  local n = rng:int(math.floor((st.float or 6) / 2), st.float or 6)
  for _ = 1, n do
    local f = SIDES[rng:int(1, 4)]
    local u0, u1 = lat_range(c, f)
    local u = u0 + 2 + rng:float() * (u1 - u0 - 4)
    local v = c.imn[2] + 2 + rng:float() * (c.imx[2] - c.imn[2] - 4)
    local p = wall_box(c, f, u, u, v, v, 1.5 + rng:float() * 3.5, 0)
    local sz = 0.3 + rng:float() * 1.5
    local a, b = { p[1] - sz, p[2] - sz, p[3] - sz }, { p[1] + sz, p[2] + sz, p[3] + sz }
    if clear(c, a, b) then
      out.add({ kind = rng:int(0, 1) == 0 and "box" or "wedge", min = { -sz, -sz * 0.3, -sz * 0.6 }, max = { sz, sz * 0.3, sz * 0.6 },
                low = 0.2, color = scale(st.metal, 0.6 + rng:float() * 0.4), pos = p, yaw = rng:float() * 6.28,
                pitch = rng:float() * 6.28, roll = rng:float() * 6.28 })
    end
  end
end

-- 10. floor props, standing against the walls and clear of keep-outs
local PROPS = {}
function PROPS.crates(c, x, y, z, s)
  local rng, st, out = c.rng, c.st, c.out
  local n = rng:int(1, 3)
  local h = 0
  for i = 1, n do
    local w = s * (1 - (i - 1) * 0.2)
    local yaw = (rng:float() - 0.5) * 0.6
    out.add({ kind = "box", min = { -w / 2, 0, -w / 2 }, max = { w / 2, w, w / 2 }, color = scale(st.crate, 0.85 + rng:float() * 0.3),
              pos = { x, y + h, z }, yaw = yaw })
    out.add({ kind = "box", min = { -w / 2 - 0.02, w * 0.42, -w / 2 - 0.02 }, max = { w / 2 + 0.02, w * 0.58, w / 2 + 0.02 },
              color = st.hazard, pos = { x, y + h, z }, yaw = yaw })
    h = h + w
  end
end
function PROPS.machine(c, x, y, z, s)
  local rng, st, out = c.rng, c.st, c.out
  local w, d, h = s * (1 + rng:float()), s * 0.8, s * (0.8 + rng:float() * 0.8)
  out.box({ x - w / 2, y, z - d / 2 }, { x + w / 2, y + h, z + d / 2 }, scale(st.metal, 0.7))
  out.box({ x - w / 2 - 0.05 * s, y + h * 0.6, z - d / 2 - 0.05 * s }, { x + w / 2 + 0.05 * s, y + h * 0.7, z + d / 2 + 0.05 * s },
          st.accent, 1)
  out.add({ kind = "cylinder", c = { x + w * 0.25, y + h, z }, r = s * 0.15, h = s * 0.6, seg = 6, color = st.pipe })
  out.add({ kind = "cylinder", c = { x - w * 0.25, y + h, z }, r = s * 0.2, h = s * 0.25, seg = 8, color = st.dark })
end
function PROPS.console(c, x, y, z, s)
  local rng, st, out = c.rng, c.st, c.out
  local yaw = rng:int(0, 3) * sm.pi / 2
  out.add({ kind = "box", min = { -s * 0.6, 0, -s * 0.3 }, max = { s * 0.6, s * 0.7, s * 0.3 }, color = st.dark, pos = { x, y, z },
            yaw = yaw })
  out.add({ kind = "wedge", min = { -s * 0.6, 0, -s * 0.3 }, max = { s * 0.6, s * 0.25, s * 0.3 }, low = 0.2, color = st.metal,
            pos = { x, y + s * 0.7, z }, yaw = yaw })
  out.add({ kind = "box", min = { -s * 0.5, s * 0.75, s * 0.18 }, max = { s * 0.5, s * 1.25, s * 0.24 }, color = st.glyph,
            emissive = 1, pos = { x, y, z }, yaw = yaw })
end
function PROPS.barrels(c, x, y, z, s)
  local rng, st, out = c.rng, c.st, c.out
  for i = 0, rng:int(1, 3) do
    local a = i * 2.1
    out.add({ kind = "cylinder", c = { x + sm.sin(a) * s * 0.5, y, z + sm.cos(a) * s * 0.5 }, r = s * 0.3, h = s * 0.8, seg = 8,
              color = i % 2 == 0 and st.hazard or st.pipe })
  end
end
function PROPS.pods(c, x, y, z, s)
  local st, out = c.st, c.out
  out.add({ kind = "cylinder", c = { x, y, z }, r = s * 0.15, h = s * 0.4, seg = 6, color = st.dark })
  out.add({ kind = "hemisphere", c = { x, y + s * 0.4, z }, r = s * 0.5, h = s * 0.35, seg = 8, rings = 2, color = st.metal })
  out.add({ kind = "sphere", c = { x, y + s * 1.0, z }, r = s * 0.12, h = s * 0.12, seg = 6, rings = 2, color = st.accent,
            emissive = 1 })
end
function PROPS.bunks(c, x, y, z, s)
  local st, out = c.st, c.out
  out.box({ x - s * 0.9, y, z - s * 0.4 }, { x + s * 0.9, y + s * 0.3, z + s * 0.4 }, st.crate)
  out.box({ x - s * 0.9, y + s * 0.8, z - s * 0.4 }, { x + s * 0.9, y + s * 0.95, z + s * 0.4 }, st.crate)
  for _, dx in ipairs({ -0.9, 0.85 }) do
    out.box({ x + s * dx, y, z - s * 0.4 }, { x + s * (dx + 0.05), y + s * 1.1, z - s * 0.35 }, st.dark)
  end
end
function PROPS.planter(c, x, y, z, s)
  local rng, st, out = c.rng, c.st, c.out
  out.box({ x - s * 0.6, y, z - s * 0.6 }, { x + s * 0.6, y + s * 0.5, z + s * 0.6 }, scale(st.metal, 0.9))
  out.box({ x - s * 0.5, y + s * 0.5, z - s * 0.5 }, { x + s * 0.5, y + s * 0.55, z + s * 0.5 }, { 0.3, 0.22, 0.15 })
  out.add({ kind = "cylinder", c = { x, y + s * 0.5, z }, r = s * 0.08, h = s * 1.2, seg = 5, color = { 0.4, 0.3, 0.2 } })
  for i = 0, 2 do
    local a = i * 2.1 + rng:float()
    out.add({ kind = "sphere", c = { x + sm.sin(a) * s * 0.25, y + s * (1.5 + (i % 2) * 0.3), z + sm.cos(a) * s * 0.25 },
              r = s * 0.45, h = s * 0.4, seg = 7, rings = 2, color = scale(st.green or { 0.25, 0.55, 0.3 }, 0.85 + 0.15 * i) })
  end
end
function PROPS.fountain(c, x, y, z, s)
  local st, out = c.st, c.out
  out.add({ kind = "ring", c = { x, y, z }, rin = s * 1.3, r = s * 1.6, h = s * 0.4, seg = 16, color = scale(st.metal, 1.1) })
  out.add({ kind = "cylinder", c = { x, y, z }, r = s * 1.3, h = s * 0.3, seg = 16, color = { 0.35, 0.7, 0.85 }, emissive = 0.4 })
  out.add({ kind = "cylinder", c = { x, y, z }, r = s * 0.25, h = s * 1.4, seg = 8, color = scale(st.metal, 0.9) })
  out.add({ kind = "cone", c = { x, y + s * 1.4, z }, r = s * 0.6, r1 = s * 0.2, h = s * 0.3, seg = 10, color = scale(st.metal, 0.9) })
  out.add({ kind = "sphere", c = { x, y + s * 1.85, z }, r = s * 0.2, h = s * 0.2, seg = 8, rings = 2, color = st.glyph, emissive = 1 })
end
function PROPS.obelisk(c, x, y, z, s)
  local rng, st, out = c.rng, c.st, c.out
  local h = s * (2 + rng:float() * 2)
  out.box({ x - s * 0.5, y, z - s * 0.5 }, { x + s * 0.5, y + s * 0.3, z + s * 0.5 }, st.dark)
  out.add({ kind = "cone", c = { x, y + s * 0.3, z }, r = s * 0.32, r1 = s * 0.18, h = h, seg = 4, color = scale(st.metal, 0.85) })
  for k = 0, 2 do
    out.box({ x - s * 0.3, y + s * 0.8 + k * h * 0.25, z - s * 0.3 }, { x + s * 0.3, y + s * 0.9 + k * h * 0.25, z + s * 0.3 },
            st.glyph, 1)
  end
end
function PROPS.column(c, x, y, z, s)
  local rng, st, out = c.rng, c.st, c.out
  local h = s * (0.8 + rng:float() * 3)
  out.add({ kind = "cylinder", c = { x, y, z }, r = s * 0.45, h = h, seg = 8, color = scale(st.metal, 0.95) })
  if rng:int(0, 1) == 1 then
    -- the fallen top lies beside it
    out.add({ kind = "cylinder", c = { 0, 0, 0 }, r = s * 0.45, h = s * 1.6, seg = 8, color = scale(st.metal, 0.85),
              pos = { x + s * 0.6, y + s * 0.45, z + s * 0.4 }, pitch = sm.pi / 2, yaw = rng:float() * 3 })
  end
  for i = 0, 2 do
    out.add({ kind = "box", min = { -s * 0.2, 0, -s * 0.15 }, max = { s * 0.2, s * 0.25, s * 0.15 }, color = scale(st.metal, 0.7),
              pos = { x - s * 0.6 + i * s * 0.4, y, z - s * 0.7 }, yaw = rng:float() * 3 })
  end
end
M.PROPS = PROPS

local function floor_props(c)
  local rng, st, out = c.rng, c.st, c.out
  if c.r.kind == "shaft" then return end
  local list, n, s
  if c.big and st.furniture == "plaza" then
    list, n, s = { "planter", "obelisk", "column", "planter", "fountain", "column", "planter" }, rng:int(8, 13), 2.6
  elseif c.big then
    list, n, s = { "crates", "machine", "console", "barrels", "crates", "machine" }, rng:int(5, 9), 2.4
  elseif c.r.size[1] >= 2 and c.r.size[3] >= 2 then
    list, n, s = { "crates", "console", st.furniture == "plaza" and "planter" or st.furniture, "barrels" }, rng:int(2, 4), 0.7
  else
    return
  end
  local h = c.imx[2] - c.imn[2]
  s = math.min(s, h / 3.2)
  for _ = 1, n * 3 do
    if n <= 0 or out.full() then break end
    local kind = list[rng:int(1, #list)]
    local f = SIDES[rng:int(1, 4)]
    local u0, u1 = lat_range(c, f)
    local u = u0 + s * 1.5 + rng:float() * math.max(0, u1 - u0 - s * 3)
    local depth = kind == "fountain" and (c.big and 14 + rng:float() * 8 or 2) or s * (0.9 + rng:float() * 0.8)
    local p = wall_box(c, f, u, u, c.imn[2], c.imn[2], depth, depth)
    local r = kind == "fountain" and s * 1.8 or s * 1.3
    local a, b = { p[1] - r, c.imn[2], p[3] - r }, { p[1] + r, c.imn[2] + s * 4.5, p[3] + r }
    local inside = a[1] > c.imn[1] and b[1] < c.imx[1] and a[3] > c.imn[3] and b[3] < c.imx[3]
    if inside and clear(c, a, b) then
      PROPS[kind](c, p[1], c.imn[2], p[3], s)
      c.keep[#c.keep + 1] = { a, b } -- props never stack inside each other
      n = n - 1
    end
  end
end

-- city plazas: two crossing paved walks with lit edges and benches, broken
-- around floor hatches
local function plaza_floor(c)
  local rng, st, out = c.rng, c.st, c.out
  if st.furniture ~= "plaza" or not c.big or c.r.kind == "shaft" then return end
  local y = c.imn[2]
  local pave = scale(st.metal, 1.25)
  for _, along in ipairs({ 1, 3 }) do
    local across = along == 1 and 3 or 1
    local mid = (c.imn[across] + c.imx[across]) / 2 + (rng:float() - 0.5) * 8
    local spans = { { c.imn[along] + 1, c.imx[along] - 1 } }
    for _, h in ipairs(c.holes["-y"]) do
      local h0, h1 = along == 1 and h[1] or h[3], along == 1 and h[2] or h[4]
      local w0, w1 = along == 1 and h[3] or h[1], along == 1 and h[4] or h[2]
      if overlaps(mid - 4, mid + 4, w0 - 1.5, w1 + 1.5) then
        local nxt = {}
        for _, sp in ipairs(spans) do
          if h0 - 1.5 > sp[1] then nxt[#nxt + 1] = { sp[1], math.min(sp[2], h0 - 1.5) } end
          if h1 + 1.5 < sp[2] then nxt[#nxt + 1] = { math.max(sp[1], h1 + 1.5), sp[2] } end
        end
        spans = nxt
      end
    end
    for _, sp in ipairs(spans) do
      if sp[2] - sp[1] > 2 then
        local a, b = {}, {}
        a[along], b[along] = sp[1], sp[2]
        a[across], b[across] = mid - 3, mid + 3
        a[2], b[2] = y, y + 0.06
        out.box(a, b, pave)
        for _, e in ipairs({ mid - 3.2, mid + 3 }) do
          local la, lb = {}, {}
          la[along], lb[along] = sp[1], sp[2]
          la[across], lb[across] = e, e + 0.2
          la[2], lb[2] = y, y + 0.1
          out.box(la, lb, st.accent, 1)
        end
        local u = sp[1] + 4
        while u < sp[2] - 4 do
          for _, side in ipairs({ -1, 1 }) do
            local ba, bb = {}, {}
            ba[along], bb[along] = u, u + 2.2
            ba[across], bb[across] = mid + side * 4.2 - 0.4, mid + side * 4.2 + 0.4
            ba[2], bb[2] = y, y + 0.5
            if clear(c, ba, bb) then out.box(ba, bb, scale(st.metal, 0.8)) end
          end
          u = u + 10
        end
      end
    end
  end
end

-- 11. city overgrowth: vines down the walls and moss on the floor
local function overgrowth(c)
  local rng, st, out = c.rng, c.st, c.out
  if not st.overgrowth or not c.big or rng:int(1, 100) > st.overgrowth then return end
  local g = st.green or { 0.22, 0.55, 0.26 }
  for _, f in ipairs(SIDES) do
    local u0, u1 = lat_range(c, f)
    local u = u0 + 1 + rng:float() * 3
    while u < u1 - 1 do
      if rng:int(1, 100) <= 45 then
        local len = 2 + rng:float() * (c.imx[2] - c.imn[2]) * 0.6
        local top = c.imx[2]
        if face_clear(c, f, u - 0.4, u + 0.4, top - len, top, 0.3) then
          local a, b = wall_box(c, f, u - 0.35, u + 0.35, top - len, top, 0, 0.25)
          out.box(a, b, scale(g, 0.8 + rng:float() * 0.4))
          local la, lb = wall_box(c, f, u - 0.8, u + 0.8, top - len * 0.3, top - len * 0.3 + 1.2, 0, 0.4)
          out.box(la, lb, scale(g, 1.1))
        end
      end
      u = u + 2.5 + rng:float() * 3
    end
  end
  for _ = 1, rng:int(3, 7) do
    local x = c.imn[1] + 2 + rng:float() * (c.imx[1] - c.imn[1] - 4)
    local z = c.imn[3] + 2 + rng:float() * (c.imx[3] - c.imn[3] - 4)
    local w = 2 + rng:float() * 5
    local a, b = { x - w, c.imn[2], z - w * 0.7 }, { x + w, c.imn[2] + 0.06, z + w * 0.7 }
    if clear(c, a, b) and a[1] > c.imn[1] and b[1] < c.imx[1] and a[3] > c.imn[3] and b[3] < c.imx[3] then
      out.box(a, b, scale(g, 0.7))
    end
  end
end

-- 12. outside the hull: raised plates, an exterior conduit and vents on
-- every face that is open to space
local function exterior(c)
  local rng, st, out = c.rng, c.st, c.out
  if not c.big then return end
  local t = c.k.wall
  for _, f in ipairs(SIDES) do
    if exposed(c, f) and #c.holes[ruinm.face_name(f[1], f[2])] == 0 then
      local u0, u1 = lat_range(c, f)
      local u = u0 + 2
      while u < u1 - 6 do
        if rng:int(1, 100) <= 60 then
          local w = 3 + rng:float() * 5
          local v0 = c.imn[2] + 1 + rng:float() * (c.imx[2] - c.imn[2]) * 0.6
          local v1 = math.min(c.imx[2] - 1, v0 + 2 + rng:float() * 6)
          local a, b = wall_box(c, f, u, math.min(u + w, u1 - 1), v0, v1, -t - 0.3 - rng:float() * 0.4, -t)
          out.box(a, b, scale(c.k.color or st.metal, 0.75 + rng:float() * 0.3))
        end
        u = u + 7
      end
      local v = c.imn[2] + 1.5
      local pa = wall_box(c, f, u0 + 1, u0 + 1, v, v, -t - 0.6, 0)
      local pb = wall_box(c, f, u1 - 1, u1 - 1, v, v, -t - 0.6, 0)
      out.add(tube(pa, pb, 0.45, st.pipe, 6))
    end
  end
end

-- all the detail for one room -> parts, sink stats
function M.room(ruin, r, k, origin)
  local c = context(ruin, r, k, origin)
  hatches(c)
  plaza_floor(c)
  strips(c)
  glyphs(c)
  floor_props(c)
  pipes(c)
  beams(c)
  torn(c)
  overgrowth(c)
  wall_panels(c)
  cables(c)
  floating(c)
  exterior(c)
  return c.out.parts, c.out
end

-- detail for one exterior solid: tower window grids, ledges and roofs; truss
-- lattices and solar panels; spine ribs and engine nozzles
-- does tower s hang under the room it is attached to?
function M.hanging(ruin, s, k, origin)
  local host = ruin.rooms[s.room or 0]
  if not host or not origin then return false end
  local rmn = ruinm.room_box(host, k, origin)
  return math.abs(s[2][2] - rmn[2]) < 0.01
end

function M.solid(ruin, s, i, k, origin)
  local st = M.style(k)
  local rng = saucer.rng.new(saucer.seed_child(ruin.seed, "solid_detail", i))
  local out = sink(M.BUDGET.solid)
  local mn, mx = s[1], s[2]
  local size = { mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3] }
  if s.kind == "tower" then
    -- vertical mullions over the lit floor bands turn them into window grids
    for _, axis in ipairs({ 1, 3 }) do
      local l = axis == 1 and 3 or 1
      for _, side in ipairs({ mn[axis] - 0.3, mx[axis] }) do
        local u = mn[l] + 1.6
        while u < mx[l] - 0.5 do
          local a, b = {}, {}
          a[axis], b[axis] = side, side + 0.3
          a[l], b[l] = u, u + 0.5
          a[2], b[2] = mn[2], mx[2]
          out.box(a, b, scale(k.solid_color or st.metal, 0.7))
          u = u + 2.2
        end
        -- dark (unlit) stretches of a few floors
        for _ = 1, rng:int(1, 3) do
          local y0 = mn[2] + rng:float() * size[2] * 0.8
          local u0 = mn[l] + rng:float() * size[l] * 0.5
          local a, b = {}, {}
          a[axis], b[axis] = side - 0.05, side + 0.25
          a[l], b[l] = u0, math.min(mx[l], u0 + 2 + rng:float() * size[l] * 0.5)
          a[2], b[2] = y0, math.min(mx[2], y0 + 6 + rng:float() * 18)
          out.box(a, b, { 0.12, 0.14, 0.2 })
        end
      end
    end
    -- ledges every fourth floor
    local y = mn[2] + 3 + 18
    while y < mx[2] - 4 do
      out.box({ mn[1] - 0.6, y + 1.3, mn[3] - 0.6 }, { mx[1] + 0.6, y + 1.8, mx[3] + 0.6 }, scale(k.solid_color or st.metal, 0.85))
      y = y + 24
    end
    -- the free end (the top, or the bottom of a tower hanging under the
    -- city): a roof garden, or water tanks and a lit landing ring
    local hanging = M.hanging(ruin, s, k, origin)
    local yend = hanging and mn[2] or mx[2]
    local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
    if rng:int(0, 1) == 0 then
      local dy = hanging and -1 or 1
      out.box({ mn[1] + 0.5, math.min(yend, yend + 0.6 * dy), mn[3] + 0.5 }, { mx[1] - 0.5, math.max(yend, yend + 0.6 * dy), mx[3] - 0.5 },
              st.green or { 0.25, 0.55, 0.3 })
      out.add({ kind = "sphere", c = { cx - size[1] * 0.2, yend + 1.8 * dy, cz }, r = 1.4, h = 1.6, seg = 7, rings = 2,
                color = scale(st.green or { 0.25, 0.55, 0.3 }, 1.1) })
    else
      out.add({ kind = "cylinder", c = { cx + size[1] * 0.25, hanging and yend - 2.2 or yend, cz + size[3] * 0.25 }, r = 1.1, h = 2.2,
                seg = 8, color = scale(st.metal, 0.8) })
      out.add({ kind = "ring", c = { cx, hanging and yend - 0.1 or yend, cz }, rin = math.min(size[1], size[3]) * 0.3, r = math.min(size[1], size[3]) * 0.38,
                h = 0.1, seg = 12, color = st.accent, emissive = 1 })
    end
  elseif s.kind == "truss" then
    -- X bracing along the longest axis on two faces
    local long = size[1] >= size[2] and (size[1] >= size[3] and 1 or 3) or (size[2] >= size[3] and 2 or 3)
    local o1 = long == 1 and 2 or 1
    local o2 = long == 3 and 2 or (long == 2 and 3 or 3)
    local step = 4
    local a = mn[long]
    while a + step <= mx[long] + 0.01 and not out.full() do
      for _, side in ipairs({ mn[o2] - 0.2, mx[o2] + 0.2 }) do
        local p, q, p2, q2 = {}, {}, {}, {}
        p[long], q[long], p2[long], q2[long] = a, a + step, a, a + step
        p[o1], q[o1], p2[o1], q2[o1] = mn[o1], mx[o1], mx[o1], mn[o1]
        p[o2], q[o2], p2[o2], q2[o2] = side, side, side, side
        out.add(bar(p, q, 0.3, st.metal))
        out.add(bar(p2, q2, 0.3, st.metal))
      end
      a = a + step
    end
    -- a solar wing at the far end
    local e = {}
    for ax = 1, 3 do e[ax] = (mn[ax] + mx[ax]) / 2 end
    e[long] = mx[long]
    local pa, pb = { e[1] - 1, e[2] - 1, e[3] - 1 }, { e[1] + 1, e[2] + 1, e[3] + 1 }
    pa[o1], pb[o1] = e[o1] - 9, e[o1] + 9
    pa[long], pb[long] = e[long], e[long] + 6
    pa[o2], pb[o2] = e[o2] - 0.08, e[o2] + 0.08
    out.box(pa, pb, { 0.12, 0.18, 0.4 })
    for k2 = 1, 3 do
      local g1, g2 = { pa[1], pa[2], pa[3] }, { pb[1], pb[2], pb[3] }
      g1[o1] = pa[o1] + k2 * 4.5 - 0.1
      g2[o1] = g1[o1] + 0.2
      g1[o2], g2[o2] = pa[o2] - 0.03, pb[o2] + 0.03
      out.box(g1, g2, { 0.7, 0.72, 0.78 })
    end
    out.box({ e[1] - 0.5, e[2] - 0.5, e[3] - 0.5 }, { e[1] + 0.5, e[2] + 0.5, e[3] + 0.5 }, { 1, 0.3, 0.2 }, 1)
  else
    -- spines: rib collars along the long axis, a nozzle cluster at one end
    local long = size[1] >= size[2] and (size[1] >= size[3] and 1 or 3) or (size[2] >= size[3] and 2 or 3)
    local a = mn[long] + 2
    while a < mx[long] - 1 and not out.full() do
      local p, q = { mn[1] - 0.4, mn[2] - 0.4, mn[3] - 0.4 }, { mx[1] + 0.4, mx[2] + 0.4, mx[3] + 0.4 }
      p[long], q[long] = a, a + 0.8
      out.box(p, q, scale(k.solid_color or st.metal, 0.75))
      a = a + 5
    end
    local e = { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
    local r = math.min(size[1] + size[2] + size[3] - size[long], 12) * 0.18
    for k2 = 0, 2 do
      local off = (k2 - 1) * r * 1.8
      local c0 = { e[1], e[2], e[3] }
      local o = long == 1 and 3 or 1
      c0[o] = c0[o] + off
      c0[long] = mn[long]
      local c1 = { c0[1], c0[2], c0[3] }
      c1[long] = mn[long] - r * 1.4
      out.add(tube(c0, c1, r * 0.7, st.dark, 8))
      local g = { c1[1], c1[2], c1[3] }
      g[long] = g[long] - 0.05
      out.add(tube(c1, g, r * 0.55, st.accent, 8, 1))
    end
  end
  return out.parts, out
end

-- sky bridges between neighbouring city towers (too close for the Villa to
-- fly between anyway): a deck with rails and lights underneath
function M.links(ruin, k)
  local st = M.style(k)
  local out = sink(M.BUDGET.links)
  local list = {}
  for i, s in ipairs(ruin.solids or {}) do
    if s.kind == "tower" then list[#list + 1] = { i = i, s = s } end
  end
  for a = 1, #list do
    for b = a + 1, #list do
      local s, q = list[a].s, list[b].s
      for _, axis in ipairs({ 1, 3 }) do
        local o = axis == 1 and 3 or 1
        local gap0, gap1
        if s[2][axis] < q[1][axis] then gap0, gap1 = s[2][axis], q[1][axis] elseif q[2][axis] < s[1][axis] then gap0, gap1 = q[2][axis], s[1][axis] end
        local lo, hi = math.max(s[1][o], q[1][o]), math.min(s[2][o], q[2][o])
        local y0, y1 = math.max(s[1][2], q[1][2]), math.min(s[2][2], q[2][2])
        if gap0 and gap1 - gap0 >= 3 and gap1 - gap0 <= 22 and hi - lo >= 3 and y1 - y0 >= 10 then
          local y = y0 + (y1 - y0) * 0.55
          local m = (lo + hi) / 2
          local p, pq = {}, {}
          p[axis], pq[axis] = gap0, gap1
          p[o], pq[o] = m - 1.4, m + 1.4
          p[2], pq[2] = y, y + 0.6
          out.box(p, pq, scale(k.solid_color or st.metal, 0.9))
          for _, side in ipairs({ m - 1.4, m + 1.3 }) do
            local r0, r1 = {}, {}
            r0[axis], r1[axis] = gap0, gap1
            r0[o], r1[o] = side, side + 0.1
            r0[2], r1[2] = y + 0.6, y + 1.6
            out.box(r0, r1, st.dark)
          end
          local l0, l1 = {}, {}
          l0[axis], l1[axis] = gap0, gap1
          l0[o], l1[o] = m - 0.3, m + 0.3
          l0[2], l1[2] = y - 0.12, y
          out.box(l0, l1, st.accent, 1)
        end
      end
    end
  end
  return out.parts, out
end

return M
