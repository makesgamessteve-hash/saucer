-- SPDX-License-Identifier: MIT
-- relic-room-shapes: the shapes of a relic's halls. A hall is still a box in the room graph (doors, the map's hit
-- test, the generator), but inside it the walkable floor follows a shape the civ's pattern calls for: an arc of the
-- ring round the heart, a round or many-sided bubble, a diamond, a cut triangle, a cross, a skewed parallelogram or a
-- chamfered octagon. Every door keeps a clear channel to the hall's centre (the autopilot flies door -> centre ->
-- door), and the centre itself stays clear, so the shape never cuts the way through.
--  * collision: the rest of the box is filled with solid boxes, one 4 m cell at a time (merged into strips), and a
--    cell is solid unless its centre and all four corners are free -- the solid never reaches past the shape
--  * the view draws the shape's wall where it is, along a 2 m marching-squares contour (view/relic.lua), outside or
--    on the solid's inner face, so nothing drawn narrows a space the saucer flies
--  * the map draws the same contour (view/relicmap.lua, tools/maps)
-- Coordinates are relic grid cells (x, z), the same cells as room.cell / room.size. Pure.
local ruinm = require("sim.ruin")
local M = {}

local function hypot(x, z) return math.sqrt(x * x + z * z) end

M.KINDS = { "arc", "round", "poly", "diamond", "tri", "cross", "skew", "chamfer" }
-- the shapes each pattern calls for (first: the most common); a relic mixes in a second shape of its own
M.PALETTE = {
  rings = { "arc", "arc", "chamfer" },
  shells = { "round", "round", "poly" },
  helix = { "arc", "arc", "poly" },
  spiral = { "arc", "round", "round" },
  diamond = { "diamond", "diamond", "chamfer" },
  sierpinski = { "tri", "tri", "poly" },
  htree = { "cross", "cross", "chamfer" },
  spine = { "skew", "skew", "chamfer" },
}
M.MIN_FREE = 0.32     -- a shaped hall keeps at least this share of its floor (else it falls back to a chamfer)
M.STEP = 0.5          -- contour sampling, cells
M.DOOR_PAD = 1.5      -- cells of clear floor round a door's opening, all the way to the centre
M.KEEP = { 2.5, 4 }   -- the clear centre's half width (cells): min, max

-- style(rng, pattern) -> this relic's own shape style (drawn from its seed)
function M.style(rng, pattern)
  local pal = M.PALETTE[pattern] or { "chamfer" }
  return {
    primary = pal[rng:int(1, #pal)], second = M.KINDS[rng:int(1, #M.KINDS)], mix = 0.1 + rng:float() * 0.3,
    plain = rng:float() * 0.12,
    p = rng:int(2, 4), sides = ({ 6, 8, 12 })[rng:int(1, 3)], rot = rng:float() * math.pi,
    dia = 1.0 + rng:float() * 0.3, fat = 0.62 + rng:float() * 0.33, tri = rng:int(0, 2), tri_cut = 0.1 + rng:float() * 0.4,
    cross = 0.3 + rng:float() * 0.2, skew = (0.3 + rng:float() * 0.5) * (rng:int(0, 1) * 2 - 1),
    skew_w = 0.45 + rng:float() * 0.25, cham = 1.2 + rng:float() * 0.35,
  }
end

-- the shape's own test, in the box's normalised coordinates (u, v in -1..1) and in cells (x, z)
local function inside_kind(s, x, z)
  local u, v = (x - s.cx) / s.hw, (z - s.cz) / s.hd
  local k = s.kind
  if k == "round" then
    local au, av, pu, pv = math.abs(u), math.abs(v), 1, 1
    for _ = 1, s.p do pu, pv = pu * au, pv * av end   -- integer powers: no pow() in the sim
    return pu + pv <= 1
  elseif k == "poly" then
    for i = 0, s.sides - 1 do
      local a = s.rot + 2 * math.pi * i / s.sides
      if u * math.cos(a) + v * math.sin(a) > math.cos(math.pi / s.sides) * 1.08 then return false end
    end
    return true
  elseif k == "diamond" then
    return math.abs(u) + math.abs(v) <= s.dia
  elseif k == "arc" then
    return math.abs(hypot(x - s.hx, z - s.hz) - s.rr) <= s.band
  elseif k == "tri" then
    return s.tx * u + s.tz * v >= -s.cut
  elseif k == "cross" then
    return math.abs(u) <= s.t or math.abs(v) <= s.t
  elseif k == "skew" then
    return math.abs(v - s.k * u) <= s.w
  end
  -- chamfer
  return math.abs(u) + math.abs(v) <= s.c
end

-- point in a convex polygon (counter-clockwise or clockwise), with a small tolerance
local function in_convex(poly, x, z)
  local sign = 0
  for i = 1, #poly do
    local a, b = poly[i], poly[i % #poly + 1]
    local c = (b[1] - a[1]) * (z - a[2]) - (b[2] - a[2]) * (x - a[1])
    if c > 1e-6 then
      if sign < 0 then return false end
      sign = 1
    elseif c < -1e-6 then
      if sign > 0 then return false end
      sign = -1
    end
  end
  return true
end

-- free(shape, x, z) -> is the cell point (x, z) walkable floor of the shaped hall?
function M.free(s, x, z)
  if x < s.x0 - 1e-6 or x > s.x1 + 1e-6 or z < s.z0 - 1e-6 or z > s.z1 + 1e-6 then return false end
  if inside_kind(s, x, z) then return true end
  for _, q in ipairs(s.keep) do
    if q.rect then
      if x >= q[1] - 1e-6 and x <= q[2] + 1e-6 and z >= q[3] - 1e-6 and z <= q[4] + 1e-6 then return true end
    elseif in_convex(q, x, z) then
      return true
    end
  end
  return false
end

-- free_world(room, kit, origin, x, z) -> the same test for a world point (true for a room without a shape)
function M.free_world(rm, kit, origin, x, z)
  local s = rm.shape
  if not s then return true end
  return M.free(s, (x - origin[1]) / kit.cell, (z - origin[3]) / kit.cell)
end

-- the convex hull of a list of points { x, z } (monotone chain, counter-clockwise)
local function hull(pts)
  table.sort(pts, function(p, q) if p[1] ~= q[1] then return p[1] < q[1] end return p[2] < q[2] end)
  local function turn(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
  local lo, up = {}, {}
  for _, p in ipairs(pts) do
    while #lo >= 2 and turn(lo[#lo - 1], lo[#lo], p) <= 0 do lo[#lo] = nil end
    lo[#lo + 1] = p
  end
  for i = #pts, 1, -1 do
    local p = pts[i]
    while #up >= 2 and turn(up[#up - 1], up[#up], p) <= 0 do up[#up] = nil end
    up[#up + 1] = p
  end
  lo[#lo] = nil
  up[#up] = nil
  for _, p in ipairs(up) do lo[#lo + 1] = p end
  return lo
end
M.hull = hull

-- the channels every door keeps to the hall's centre, and the clear centre. A channel is the door's opening (padded
-- by DOOR_PAD on every side) swept straight to the centre: the hull of that rectangle and the same rectangle moved to
-- the centre, so the channel is at least as wide as the padded door whichever way it runs, and the door -> centre
-- line the autopilot flies stays clear of the solid (which may cut up to one cell into it)
local function keeps(s, rm, doors)
  local out = {}
  local cx, cz = s.cx, s.cz
  local p = M.DOOR_PAD
  for _, d in ipairs(doors) do
    if d.a == rm.id or d.b == rm.id then
      local x0, x1, z0, z1
      if d.axis == 2 then
        x0, x1, z0, z1 = d.lo, d.hi, d.lo3, d.hi3
      elseif d.axis == 1 then
        x0, x1, z0, z1 = d.at, d.at, d.lo, d.hi
      else
        x0, x1, z0, z1 = d.lo, d.hi, d.at, d.at
      end
      x0, x1, z0, z1 = x0 - p, x1 + p, z0 - p, z1 + p
      local tx, tz = cx - (x0 + x1) / 2, cz - (z0 + z1) / 2
      local pts = {}
      for _, q in ipairs({ { x0, z0 }, { x1, z0 }, { x1, z1 }, { x0, z1 } }) do
        pts[#pts + 1] = { q[1], q[2] }
        pts[#pts + 1] = { q[1] + tx, q[2] + tz }
      end
      out[#out + 1] = hull(pts)
    end
  end
  local k = math.max(M.KEEP[1], math.min(M.KEEP[2], math.min(s.hw, s.hd) * 0.22))
  out[#out + 1] = { cx - k, cx + k, cz - k, cz + k, rect = true }
  return out
end

-- the share of the box's floor the shape leaves free (sampled on the contour grid)
function M.free_share(s)
  local n, f = 0, 0
  for x = s.x0 + 0.25, s.x1, M.STEP do
    for z = s.z0 + 0.25, s.z1, M.STEP do
      n = n + 1
      if M.free(s, x, z) then f = f + 1 end
    end
  end
  return n > 0 and f / n or 1
end

-- make(kind, room, doors, style, hx, hz, rng) -> a shape record for one hall
function M.make(kind, rm, doors, S, hx, hz, rng)
  local x0, z0 = rm.cell[1], rm.cell[3]
  local x1, z1 = x0 + rm.size[1], z0 + rm.size[3]
  local s = { kind = kind, x0 = x0, z0 = z0, x1 = x1, z1 = z1, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2,
              hw = (x1 - x0) / 2, hd = (z1 - z0) / 2, hx = hx, hz = hz }
  s.p, s.sides, s.rot, s.dia, s.c = S.p, S.sides, S.rot + rm.id * 0.37, S.dia, S.cham
  s.t, s.k, s.w = S.cross, S.skew, S.skew_w
  -- an arc of the ring through the hall's centre, round the heart
  s.rr = hypot(s.cx - hx, s.cz - hz)
  s.band = math.min(s.hw, s.hd) * S.fat
  -- a triangle's cut: its corner faces the heart, away from it, or alternates
  local dx, dz = s.cx - hx, s.cz - hz
  local sx, sz = dx >= 0 and -1 or 1, dz >= 0 and -1 or 1
  if S.tri == 1 or (S.tri == 2 and rm.id % 2 == 0) then sx, sz = -sx, -sz end
  if rng and rng:float() < 0.3 then sx = -sx end
  s.tx, s.tz, s.cut = sx, sz, S.tri_cut
  s.keep = keeps(s, rm, doors)
  return s
end

-- assign(rng, rooms, doors, protect, hx, hz, S) -> number of halls shaped. protect: room ids that stay boxes (the
-- maw's hall, the lung with its four bays, the heart). Halls only: trunks, shafts and Seat spaces keep their boxes.
function M.assign(rng, rooms, doors, protect, hx, hz, S)
  local n = 0
  for _, rm in ipairs(rooms) do
    if rm.kind == "hall" and not protect[rm.id] then
      local roll = rng:float()
      if roll >= S.plain then
        local kind = (rng:float() < S.mix) and S.second or S.primary
        local s = M.make(kind, rm, doors, S, hx, hz, rng)
        if M.free_share(s) < M.MIN_FREE or M.free_share(s) > 0.97 then s = M.make("chamfer", rm, doors, S, hx, hz, rng) end
        if M.free_share(s) <= 0.97 then
          rm.shape = s
          n = n + 1
        end
      end
    end
  end
  return n
end

-- the solid that fills a shaped hall's box outside its shape -> list of { min, max, room = id, fill = true } (world)
function M.fill(rm, kit, origin)
  local s = rm.shape
  if not s then return {} end
  local mn, mx = ruinm.room_box(rm, kit, origin)
  local y0, y1 = mn[2] + kit.wall, mx[2] - kit.wall
  local spans = {}
  for j = s.z0, s.z1 - 1 do
    local row, i = {}, s.x0
    while i < s.x1 do
      local solid = not (M.free(s, i + 0.5, j + 0.5) and M.free(s, i, j) and M.free(s, i + 1, j) and M.free(s, i, j + 1)
        and M.free(s, i + 1, j + 1))
      if solid then
        local a = i
        while i + 1 < s.x1 do
          local k = i + 1
          local nxt = not (M.free(s, k + 0.5, j + 0.5) and M.free(s, k, j) and M.free(s, k + 1, j) and M.free(s, k, j + 1)
            and M.free(s, k + 1, j + 1))
          if not nxt then break end
          i = k
        end
        row[#row + 1] = { a, i + 1 }
      end
      i = i + 1
    end
    spans[j] = row
  end
  -- merge equal spans on consecutive rows into one box
  local out, open = {}, {}
  local function close(key)
    local o = open[key]
    out[#out + 1] = { { origin[1] + o.a * kit.cell, y0, origin[3] + o.j0 * kit.cell },
                      { origin[1] + o.b * kit.cell, y1, origin[3] + (o.j1 + 1) * kit.cell }, room = rm.id, fill = true }
    open[key] = nil
  end
  for j = s.z0, s.z1 - 1 do
    local seen = {}
    for _, sp in ipairs(spans[j]) do
      local key = sp[1] .. ":" .. sp[2]
      seen[key] = true
      if open[key] then open[key].j1 = j else open[key] = { a = sp[1], b = sp[2], j0 = j, j1 = j } end
    end
    local keys = {}
    for key in pairs(open) do if not seen[key] then keys[#keys + 1] = key end end
    table.sort(keys)
    for _, key in ipairs(keys) do close(key) end
  end
  local keys = {}
  for key in pairs(open) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do close(key) end
  return out
end

-- contour(shape) -> the shape's wall as segments { x0, z0, x1, z1 } in cells: marching squares on a STEP grid inside
-- the box (where the free floor meets the box's own wall there is no segment: the box's wall is drawn already),
-- collinear neighbours merged
function M.contour(s)
  if s.contour_cache then return s.contour_cache end
  local st = M.STEP
  local nx, nz = math.floor((s.x1 - s.x0) / st + 0.5), math.floor((s.z1 - s.z0) / st + 0.5)
  local f = {}
  for i = 0, nx do
    f[i] = {}
    for j = 0, nz do f[i][j] = M.free(s, s.x0 + i * st, s.z0 + j * st) end
  end
  local segs = {}
  local function P(i, j, e)
    -- edge midpoints of cell (i, j): 1 bottom, 2 right, 3 top, 4 left
    local x, z = s.x0 + i * st, s.z0 + j * st
    if e == 1 then return x + st / 2, z elseif e == 2 then return x + st, z + st / 2
    elseif e == 3 then return x + st / 2, z + st else return x, z + st / 2 end
  end
  local TABLE = {
    [1] = { { 4, 1 } }, [2] = { { 1, 2 } }, [3] = { { 4, 2 } }, [4] = { { 2, 3 } }, [5] = { { 4, 1 }, { 2, 3 } },
    [6] = { { 1, 3 } }, [7] = { { 4, 3 } }, [8] = { { 3, 4 } }, [9] = { { 3, 1 } }, [10] = { { 1, 2 }, { 3, 4 } },
    [11] = { { 3, 2 } }, [12] = { { 2, 4 } }, [13] = { { 2, 1 } }, [14] = { { 1, 4 } },
  }
  for i = 0, nx - 1 do
    for j = 0, nz - 1 do
      -- corners: bit 1 (i, j), 2 (i+1, j), 4 (i+1, j+1), 8 (i, j+1); a set bit is SOLID
      local c = (f[i][j] and 0 or 1) + (f[i + 1][j] and 0 or 2) + (f[i + 1][j + 1] and 0 or 4) + (f[i][j + 1] and 0 or 8)
      for _, e in ipairs(TABLE[c] or {}) do
        local ax, az = P(i, j, e[1])
        local bx, bz = P(i, j, e[2])
        segs[#segs + 1] = { ax, az, bx, bz }
      end
    end
  end
  -- merge collinear chains (greedy, by shared end point and same direction)
  local function key(x, z) return string.format("%.3f,%.3f", x, z) end
  local by = {}
  for k, sg in ipairs(segs) do by[key(sg[1], sg[2])] = by[key(sg[1], sg[2])] or {}; table.insert(by[key(sg[1], sg[2])], k) end
  local used, out = {}, {}
  for k, sg in ipairs(segs) do
    if not used[k] then
      used[k] = true
      local a, b = { sg[1], sg[2] }, { sg[3], sg[4] }
      local dx, dz = b[1] - a[1], b[2] - a[2]
      local grow = true
      while grow do
        grow = false
        for _, n in ipairs(by[key(b[1], b[2])] or {}) do
          local o = segs[n]
          if not used[n] then
            local ex, ez = o[3] - o[1], o[4] - o[2]
            if math.abs(ex * dz - ez * dx) < 1e-6 and ex * dx + ez * dz > 0 then
              used[n] = true
              b = { o[3], o[4] }
              grow = true
              break
            end
          end
        end
      end
      out[#out + 1] = { a[1], a[2], b[1], b[2] }
    end
  end
  s.contour_cache = out
  return out
end

-- settle(room, kit, origin, pos, margin, avoid) -> pos moved (x, z only) to the nearest point of the shape's free
-- floor with `margin` metres of free floor round it and clear of the `avoid` rectangles ({ x0, x1, z0, z1 }, world
-- metres: a floor hatch); pos unchanged for a room without a shape or a point already fine
function M.settle(rm, kit, origin, pos, margin, avoid)
  local s = rm.shape
  if not s then return pos end
  local m = (margin or 2) / kit.cell
  local function ok(x, z)
    if not (M.free(s, x, z) and M.free(s, x - m, z) and M.free(s, x + m, z) and M.free(s, x, z - m) and M.free(s, x, z + m)) then
      return false
    end
    local wx, wz, mm = origin[1] + x * kit.cell, origin[3] + z * kit.cell, m * kit.cell
    for _, h in ipairs(avoid or {}) do
      if wx - mm < h[2] and wx + mm > h[1] and wz - mm < h[4] and wz + mm > h[3] then return false end
    end
    return true
  end
  local x, z = (pos[1] - origin[1]) / kit.cell, (pos[3] - origin[3]) / kit.cell
  if ok(x, z) then return pos end
  for r = 0.5, math.max(s.hw, s.hd) * 2, 0.5 do
    local best, bd
    local n = math.max(8, math.floor(r * 6))
    for k = 0, n - 1 do
      local a = 2 * math.pi * k / n
      local px, pz = x + r * math.cos(a), z + r * math.sin(a)
      if ok(px, pz) then
        local d = hypot(px - s.cx, pz - s.cz)
        if not bd or d < bd then best, bd = { px, pz }, d end
      end
    end
    if best then return { origin[1] + best[1] * kit.cell, pos[2], origin[3] + best[2] * kit.cell } end
  end
  return { origin[1] + s.cx * kit.cell, pos[2], origin[3] + s.cz * kit.cell }
end

return M
