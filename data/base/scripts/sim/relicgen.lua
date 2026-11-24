-- SPDX-License-Identifier: MIT
-- add-relic-stations, add-relic-dungeons: relic station generation (design civs-and-relics §3, §9). A relic is a
-- dead, civ-built megastructure the Villa flies through like a dungeon: a warren of halls big and small on three to
-- five levels, trunk corridors and shafts between them (loops, dead ends, ways round), Seat branches into chambers
-- only the shrunk saucer reaches, and at the bottom of it all the heart hall (480 x 160 x 480 m) round its engine.
--   the maw (34 x 20 m) opens into the top level's first row; the heart is entered from the lowest level's last row,
--   so the way there crosses most of the warren
--   the lung hall (it breathes) holds four fold bays and the locked reliquary's branch (80 m, a Seat-lock, three
--   class-1 finds); every other Seat branch has a fold bay by its port; one hall on the lowest level is plague-struck
--   phenomena: strange, harmless, render-only sights placed per hall from the civ's list (view/phenomena.lua)
-- The layout lives on the 4 m ruin grid and comes back in the same table shape as sim/ruin.lua's generate (rooms,
-- doors, walls, slots, solids, debris, hash) plus `relic` (archetype, civ, spaces, bays, branches, pockets, locks,
-- heart, levels, phenomena), so physics, beams, saves and the map need no relic-specific code. Collision is the room
-- boxes' walls and the heart's engine column; every visual skin sits outside the walls (view/relic.lua). Pure: a
-- function of (seed, kit, civ, origin).
local ruinm = require("sim.ruin")
local M = {}

M.MAX_TRIES = 8
-- class minimums (m): { width, height, length } (design §3.3, §5.2)
M.MIN = {
  maw = { 34, 20 }, hall = { 54, 30, 54 }, core = { 128, 64, 128 }, trunk = { 38, 22 }, shaft = { 38, 20, 38 },
  bay = { 44, 20, 44 }, passage = { 4, 4 }, port = { 2.6, 2.1 }, reliquary = { 12, 8, 12 }, chamber = { 12, 8, 12 },
}
M.CHARGE_MAX = 100
M.BAY_REACH = 30        -- m: a Seat port's fold bay marker is at most this far from the port

local function room(id, kind, cell, size, class, parent)
  return { id = id, kind = kind, class = class or 4, inclass = class or 4, parent = parent or (id - 1), cell = cell,
           size = size, faces = {} }
end

-- a door between rooms a and b through axis `axis` (b on the + side when sign > 0). Side doors are centred on the
-- rooms' lateral overlap and sit on the higher floor; floor/ceiling doors (axis 2) on their x-z overlap.
local function door(a, b, axis, sign, class)
  a.faces[ruinm.face_name(axis, sign)] = true
  b.faces[ruinm.face_name(axis, -sign)] = true
  local at = sign > 0 and a.cell[axis] + a.size[axis] or a.cell[axis]
  if axis == 2 then
    return { a = a.id, b = b.id, class = class, axis = 2, sign = sign, at = at,
             lo = math.max(a.cell[1], b.cell[1]), hi = math.min(a.cell[1] + a.size[1], b.cell[1] + b.size[1]),
             lo3 = math.max(a.cell[3], b.cell[3]), hi3 = math.min(a.cell[3] + a.size[3], b.cell[3] + b.size[3]),
             vlo = math.max(a.cell[2], b.cell[2]) }
  end
  local l = axis == 1 and 3 or 1
  local u0, u1 = math.max(a.cell[l], b.cell[l]), math.min(a.cell[l] + a.size[l], b.cell[l] + b.size[l])
  local v0, v1 = math.max(a.cell[2], b.cell[2]), math.min(a.cell[2] + a.size[2], b.cell[2] + b.size[2])
  return { a = a.id, b = b.id, class = class, axis = axis, sign = sign, lo = u0, hi = u1, vlo = v0, vhi = v1, at = at }
end
M.door = door

-- the world box of a room
local function box(r, kit, origin) return ruinm.room_box(r, kit, origin) end
M.box = box

-- do two cell boxes overlap once the first is grown by `pad` cells?
local function overlaps(c1, s1, c2, s2, pad)
  for k = 1, 3 do
    if c1[k] - pad >= c2[k] + s2[k] or c2[k] >= c1[k] + s1[k] + pad then return false end
  end
  return true
end

-- the warren's lattice: which nodes hold a hall, and the tree + loop edges between them. The way from the maw's node
-- to a lowest-level last-row node is carved first (a walk that never comes back up), then the rest grows off it.
local function lattice(rng, D)
  local nx, nz, nl = D.lattice[1], D.lattice[2], D.levels
  local function key(i, j, l) return (l * nz + j) * nx + i end
  local filled, order, edges, linked = {}, {}, {}, {}
  local function fill(n)
    if not filled[key(n[1], n[2], n[3])] then
      filled[key(n[1], n[2], n[3])] = n
      order[#order + 1] = n
    end
  end
  local function link(a, b)
    local ka, kb = key(a[1], a[2], a[3]), key(b[1], b[2], b[3])
    local k = math.min(ka, kb) .. ":" .. math.max(ka, kb)
    if linked[k] then return end
    linked[k] = true
    edges[#edges + 1] = { a, b }
  end
  local start = { nx // 2, 0, nl - 1 }
  fill(start)
  -- the main way: every step goes along (+z), across (x) or down a level; it ends on the lowest level's last row
  local cur = start
  while not (cur[2] == nz - 1 and cur[3] == 0) do
    local opts = {}
    if cur[2] < nz - 1 then opts[#opts + 1] = { cur[1], cur[2] + 1, cur[3] } end
    if cur[3] > 0 then opts[#opts + 1] = { cur[1], cur[2], cur[3] - 1 } end
    if cur[1] > 0 and rng:int(1, 3) == 1 then opts[#opts + 1] = { cur[1] - 1, cur[2], cur[3] } end
    if cur[1] < nx - 1 and rng:int(1, 3) == 1 then opts[#opts + 1] = { cur[1] + 1, cur[2], cur[3] } end
    local nxt = opts[rng:int(1, #opts)]
    if filled[key(nxt[1], nxt[2], nxt[3])] then nxt = opts[1] end
    fill(nxt)
    nxt.main = true
    link(cur, nxt)
    cur = nxt
  end
  local function neighbours(n)
    local out = {}
    for _, d in ipairs({ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }) do
      local m = { n[1] + d[1], n[2] + d[2], n[3] + d[3] }
      if m[1] >= 0 and m[1] < nx and m[2] >= 0 and m[2] < nz and m[3] >= 0 and m[3] < nl then
        out[#out + 1] = { m, d[3] ~= 0 }
      end
    end
    return out
  end
  -- grow: a random filled node, a random empty neighbour (levels weighted by D.vertical)
  local want = rng:int(D.nodes[1], D.nodes[2])
  local guard = 0
  while #order < want and guard < 4000 do
    guard = guard + 1
    local n = order[rng:int(1, #order)]
    local nb = neighbours(n)
    local pick = nb[rng:int(1, #nb)]
    if not filled[key(pick[1][1], pick[1][2], pick[1][3])] and (not pick[2] or rng:float() < D.vertical) then
      fill(pick[1])
      link(n, pick[1])
    end
  end
  -- loops: some neighbouring halls get a second way between them
  for _, n in ipairs(order) do
    for _, pick in ipairs(neighbours(n)) do
      local m = pick[1]
      local km, kn = key(m[1], m[2], m[3]), key(n[1], n[2], n[3])
      if filled[km] and km > kn and not linked[math.min(km, kn) .. ":" .. math.max(km, kn)] and rng:float() < D.loops then
        link(n, m)
      end
    end
  end
  return order, edges, start, key
end

-- the warren's rooms and doors in cells (x across, y up, z from the maw toward the heart)
local function layout(rng, kit)
  local D = kit.dungeon
  local order, edges, start, key = lattice(rng, D)
  local rooms, doors = {}, {}
  local function add(kind, cell, size, class, parent)
    local r = room(#rooms + 1, kind, cell, size, class, parent)
    rooms[#rooms + 1] = r
    return r
  end
  local function centre(n) return D.origin[1] + n[1] * D.pitch, D.origin[2] + n[3] * D.level_h, D.origin[3] + n[2] * D.pitch end
  -- the maw first (room 1: the entrance), into the top level's first-row hall (always a big one)
  local hall_of = {}
  local by_node = {}
  local cx, fy, cz = centre(start)
  local big = D.hall_w[#D.hall_w]
  local maw = add("entrance", { cx - D.maw[1] // 2, fy + (D.hall_h[big] - D.maw[2]) // 2, cz - big // 2 - D.maw[3] },
    { D.maw[1], D.maw[2], D.maw[3] }, 4, 0)
  doors[1] = { a = 0, b = 1, class = 4, axis = 3, sign = 1, lo = maw.cell[1], hi = maw.cell[1] + maw.size[1],
               vlo = maw.cell[2], vhi = maw.cell[2] + maw.size[2] }
  maw.faces["-z"] = true
  local halls = {}
  for idx, n in ipairs(order) do
    local x, y, z = centre(n)
    -- the maw's hall is big, and so is every other hall on the main way (the lung is one of them)
    local main = idx == 1 or (n.main and idx % 2 == 0)
    local w = main and big or D.hall_w[rng:int(1, #D.hall_w)]
    local d = main and big or D.hall_w[rng:int(1, #D.hall_w)]
    local h = D.hall_h[math.max(w, d)]
    local hall = add("hall", { x - w // 2, y, z - d // 2 }, { w, h, d }, 4, idx == 1 and maw.id or nil)
    hall.node = { n[1], n[2], n[3] }
    hall.hall = #halls + 1
    halls[#halls + 1] = hall
    by_node[key(n[1], n[2], n[3])] = hall
    hall_of[hall.id] = hall
  end
  doors[#doors + 1] = door(maw, halls[1], 3, 1, 4)
  local trunks, shafts = {}, {}
  for _, e in ipairs(edges) do
    local a, b = by_node[key(e[1][1], e[1][2], e[1][3])], by_node[key(e[2][1], e[2][2], e[2][3])]
    local axis = e[1][1] ~= e[2][1] and 1 or e[1][2] ~= e[2][2] and 3 or 2
    if a.cell[axis] > b.cell[axis] then a, b = b, a end
    if axis == 2 then
      local c = { a.cell[1] + a.size[1] // 2 - D.shaft // 2, a.cell[2] + a.size[2], a.cell[3] + a.size[3] // 2 - D.shaft // 2 }
      local s = add("shaft", c, { D.shaft, b.cell[2] - c[2], D.shaft }, 4, a.id)
      shafts[#shafts + 1] = s
      doors[#doors + 1] = door(a, s, 2, 1, 4)
      doors[#doors + 1] = door(s, b, 2, 1, 4)
    else
      local l = axis == 1 and 3 or 1
      local c, sz = {}, {}
      c[axis], sz[axis] = a.cell[axis] + a.size[axis], b.cell[axis] - (a.cell[axis] + a.size[axis])
      c[l], sz[l] = a.cell[l] + a.size[l] // 2 - D.trunk[1] // 2, D.trunk[1]
      c[2], sz[2] = a.cell[2], D.trunk[2]
      local t = add("trunk", c, sz, 4, a.id)
      t.axis = axis
      trunks[#trunks + 1] = t
      doors[#doors + 1] = door(a, t, axis, 1, 4)
      doors[#doors + 1] = door(t, b, axis, 1, 4)
    end
  end
  -- the heart, past the last row, on the lowest level's floor; every lowest-level last-row hall may open into it
  local H = D.heart
  local ox, oy, oz = centre({ (D.lattice[1] - 1) / 2, D.lattice[2] - 1, 0 })
  local hz = oz + big // 2 + D.heart_gap
  local heart = add("core", { math.floor(ox - H[1] / 2), oy, hz }, { H[1], H[2], H[3] }, 4)
  local into = {}
  for i = 0, D.lattice[1] - 1 do
    local hall = by_node[key(i, D.lattice[2] - 1, 0)]
    if hall then into[#into + 1] = hall end
  end
  for k, hall in ipairs(into) do
    if k == 1 or rng:float() < D.heart_doors then
      local c = { hall.cell[1] + hall.size[1] // 2 - D.trunk[1] // 2, hall.cell[2], hall.cell[3] + hall.size[3] }
      local t = add("trunk", c, { D.trunk[1], D.trunk[2], heart.cell[3] - c[3] }, 4, hall.id)
      t.axis = 3
      t.heart = true
      trunks[#trunks + 1] = t
      doors[#doors + 1] = door(hall, t, 3, 1, 4)
      doors[#doors + 1] = door(t, heart, 3, 1, 4)
    end
  end
  heart.parent = rooms[#rooms].id
  return rooms, doors, { halls = halls, trunks = trunks, shafts = shafts, core = heart, maw = maw }
end

-- the world-space hole of a side door (centre of its opening, w, h) -> centre, w, h
local function hole(d, kit, origin)
  local l = d.axis == 1 and 3 or 1
  local w, h = kit.doors[d.class][1], kit.doors[d.class][2]
  local c = { 0, 0, 0 }
  c[l] = origin[l] + (d.lo + d.hi) / 2 * kit.cell
  c[d.axis] = origin[d.axis] + (d.at or 0) * kit.cell
  c[2] = origin[2] + d.vlo * kit.cell + kit.wall + h / 2
  return c, w, h
end
M.hole = hole

-- a fold bay: a 44 x 20 x 44 m box on a hall's floor centred at world (x, z), the Seat marker over its centre
local function bay(id, hall, x, z, kit, origin)
  local mn = box(hall, kit, origin)
  local floor = mn[2] + kit.wall
  local half = kit.bay.size * kit.cell / 2
  return { id = id, room = hall.id, hall = hall.hall,
           lo = { x - half, floor, z - half }, hi = { x + half, floor + 20, z + half },
           marker = { x, floor + kit.bay.marker_y, z }, cradle = { x, floor, z } }
end
-- the bay in quadrant (qx, qz) of a hall (the lung's four)
local function quad_bay(id, hall, qx, qz, kit, origin)
  local mn, mx = box(hall, kit, origin)
  local b = bay(id, hall, (mn[1] + mx[1]) / 2 + qx * (mx[1] - mn[1]) / 4, (mn[3] + mx[3]) / 2 + qz * (mx[3] - mn[3]) / 4, kit,
    origin)
  b.quadrant = { qx, qz }
  return b
end

-- world rectangles { x0, x1, z0, z1 } of the holes in a room's floor
local function floor_holes(r, doors, rooms, kit, origin)
  return ruinm.face_holes(r, doors, rooms, kit, origin, 2, -1)
end
local function clear_of(holes, x0, x1, z0, z1, pad)
  for _, h in ipairs(holes) do
    if x0 < h[2] + pad and x1 > h[1] - pad and z0 < h[4] + pad and z1 > h[3] - pad then return false end
  end
  return true
end

-- cell-space unit step of a face
local function step(axis, sign)
  local v = { 0, 0, 0 }
  v[axis] = sign
  return v
end

-- a Seat branch off hall H through its face (axis, sign): a port `rise` cells up at lateral cell u, a passage
-- `n1` cells out, an optional elbow toward `turn` (+1/-1 along the other horizontal axis) for `n2` cells, a chamber,
-- and sometimes a second passage and chamber beyond it. Every new room keeps `pad` cells from the big spaces and one
-- from the small ones (and stays inside the grid). -> list of new rooms and doors, or nil
local function branch(rooms, H, axis, sign, u, n1, turn, n2, more, kit, chamber_kind, csize)
  local D = kit.dungeon
  local grid = kit.grid
  local l = axis == 1 and 3 or 1
  local new, nd = {}, {}
  local function fits(c, sz)
    for k = 1, 3 do
      if c[k] < 1 or c[k] + sz[k] > grid[k] - 1 then return false end
    end
    for _, o in ipairs(rooms) do
      if overlaps(c, sz, o.cell, o.size, o.class >= 4 and D.pad or 1) then
        -- the hall it leaves may touch the first passage (and only that one)
        if not (o == H and #new == 0) then return false end
      end
    end
    for _, o in ipairs(new) do
      if overlaps(c, sz, o.cell, o.size, 0) then return false end
    end
    return true
  end
  local id0 = #rooms
  local function put(kind, c, sz, parent)
    if not fits(c, sz) then return nil end
    local r = room(id0 + #new + 1, kind, c, sz, 1, parent)
    new[#new + 1] = r
    return r
  end
  -- a straight run of `n` one-cell steps from cell p along (ax, sg): its box
  local function run(p, ax, sg, n)
    local c, sz = { p[1], p[2], p[3] }, { 1, 1, 1 }
    sz[ax] = n
    if sg < 0 then c[ax] = p[ax] - (n - 1) end
    return c, sz
  end
  local py = H.cell[2] + kit.port_rise
  local p = { 0, py, 0 }
  p[axis] = sign > 0 and H.cell[axis] + H.size[axis] or H.cell[axis] - 1
  p[l] = u
  local A
  do
    local c, sz = run(p, axis, sign, turn and n1 - 1 or n1)
    A = put("passage", c, sz, H.id)
    if not A then return nil end
    nd[#nd + 1] = { H, A, axis, sign }
  end
  local last, lax, lsg = A, axis, sign
  local tip = { p[1], p[2], p[3] }
  tip[axis] = p[axis] + sign * ((turn and n1 - 1 or n1) - 1)
  if turn then
    local q = { tip[1], tip[2], tip[3] }
    q[axis] = tip[axis] + sign
    local c, sz = run(q, l, turn, n2 + 1)
    local B = put("passage", c, sz, A.id)
    if not B then return nil end
    nd[#nd + 1] = { A, B, axis, sign }
    last, lax, lsg = B, l, turn
    tip = { q[1], q[2], q[3] }
    tip[l] = q[l] + turn * n2
  end
  -- the chamber: centred on the passage, its floor on the passage's
  local function chamber(from, fax, fsg, at, kind, cs)
    local o = fax == 1 and 3 or 1
    local c = { 0, at[2], 0 }
    c[fax] = fsg > 0 and at[fax] + 1 or at[fax] - cs[fax]
    c[o] = at[o] - (cs[o] - 1) // 2
    local Q = put(kind, c, { cs[1], cs[2], cs[3] }, from.id)
    if not Q then return nil end
    nd[#nd + 1] = { from, Q, fax, fsg }
    return Q, c
  end
  local Q, qc = chamber(last, lax, lsg, tip, chamber_kind, csize)
  if not Q then return nil end
  local chambers = { Q }
  if more then
    -- out of the chamber's far side: a short passage and a second chamber
    local o = lax == 1 and 3 or 1
    local q = { 0, qc[2], 0 }
    q[lax] = lsg > 0 and qc[lax] + csize[lax] or qc[lax] - 1
    q[o] = qc[o] + (csize[o] - 1) // 2
    local c, sz = run(q, lax, lsg, more)
    local P2 = put("passage", c, sz, Q.id)
    if P2 then
      local t2 = { q[1], q[2], q[3] }
      t2[lax] = q[lax] + lsg * (more - 1)
      local Q2 = chamber(P2, lax, lsg, t2, "chamber", D.chamber)
      if Q2 then
        nd[#nd + 1] = { Q, P2, lax, lsg }
        chambers[2] = Q2
      else
        new[#new] = nil
      end
    end
  end
  return new, nd, chambers
end

-- loot: a find in some halls (hall_share of them, never over a floor hole), the chambers' class-1 finds (one or
-- two each), the locked reliquary's three, the XL idol in the heart before its engine
local function slots(rng, seed, rooms, doors, L, kit, origin)
  local out = {}
  local function add(r, pos, max_size, tier, extra)
    local s = { id = #out + 1, room = r.id, pos = pos, max_size = max_size, tier = tier,
                seed = saucer.seed_child(seed, "slot", #out + 1) }
    for k, v in pairs(extra or {}) do s[k] = v end
    out[#out + 1] = s
    return s
  end
  for hi, h in ipairs(L.halls) do
    if hi > 1 and rng:float() < kit.loot.hall_share then
      local mn, mx = box(h, kit, origin)
      local holes = floor_holes(h, doors, rooms, kit, origin)
      for _ = 1, 6 do
        local x = (mn[1] + mx[1]) / 2 + rng:int(-1, 1) * (mx[1] - mn[1]) / 4 + rng:int(-4, 4)
        local z = (mn[3] + mx[3]) / 2 + rng:int(-1, 1) * (mx[3] - mn[3]) / 4 + rng:int(-4, 4)
        if clear_of(holes, x - 3, x + 3, z - 3, z + 3, 2) then
          add(h, { x, mn[2] + kit.wall + 1.5, z }, kit.loot.hall_size[(hi % #kit.loot.hall_size) + 1], 2, { hall = h.hall })
          break
        end
      end
    end
  end
  for _, q in ipairs(L.chambers) do
    local mn, mx = box(q, kit, origin)
    local n = q.kind == "reliquary" and kit.loot.reliquary_finds or rng:int(kit.loot.chamber_finds[1], kit.loot.chamber_finds[2])
    for k = 1, n do
      add(q, { (mn[1] + mx[1]) / 2 + (k - (n + 1) / 2) * 3, mn[2] + kit.wall + 1.0, (mn[3] + mx[3]) / 2 + (k % 2) * 2 - 1 }, 1, 3,
        { warren = true })
    end
  end
  local mn, mx = box(L.core, kit, origin)
  add(L.core, { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + 3.5, mn[3] + (mx[3] - mn[3]) * 0.22 }, 4, 3, { xl = true, idol = true })
  return out
end

-- the spaces with their class and measured clear size (m), for the validator, the tests and the map
local function spaces(rooms, kit, origin)
  local out = {}
  local cls = { entrance = "maw", hall = "hall", trunk = "trunk", shaft = "shaft", core = "core", passage = "passage",
                reliquary = "reliquary", chamber = "chamber" }
  for _, r in ipairs(rooms) do
    local mn, mx = box(r, kit, origin)
    local t = 2 * kit.wall
    local along = math.max(mx[1] - mn[1], mx[3] - mn[3])
    if r.kind == "shaft" then along = mx[2] - mn[2] end
    out[#out + 1] = { room = r.id, class = cls[r.kind], villa = r.class >= 4,
                      clear = { mx[1] - mn[1] - t, mx[2] - mn[2] - t, mx[3] - mn[3] - t }, length = along }
  end
  return out
end

-- the Charge plan of a full clear: walking the route maw -> Core, every Seat branch is a shrink (cost) at its bay
-- and a regrow at a bay (free on a cradle); Charge spent between two cradle visits must stay within CHARGE_MAX.
-- -> worst spend between cradles, the list of steps
function M.charge_plan(relic, costs)
  costs = costs or { shrink = 20, grow = 10, step_out = 10, deploy = 5 }
  local worst, run, steps = 0, 0, {}
  for _, br in ipairs(relic.branches) do
    run = run + costs.shrink
    steps[#steps + 1] = { "shrink", br.id, costs.shrink }
    for _ in ipairs(br.pockets or {}) do run = run + costs.step_out + costs.deploy end
    worst = math.max(worst, run)
    -- the way back out ends at a fold bay with a cradle: the regrow is free and the cradle refills
    local cradle = relic.bays[br.bay] and relic.bays[br.bay].cradle
    steps[#steps + 1] = { "regrow", br.id, cradle and 0 or costs.grow }
    if cradle then run = 0 else run = run + costs.grow end
    worst = math.max(worst, run)
  end
  return worst, steps
end

-- validation (§5.4): reachability on Villa-class doors, class minimums, fold bays at every Seat port, the Charge
-- plan, the Villa share of the route. -> ok, why
function M.validate(r, kit)
  local ok, reach = ruinm.validate(r.rooms, r.doors, r.slots)
  if not ok then return false, reach end
  -- the Villa never has to fold on the route: every Villa-class room is reached through Villa-class doors only
  -- (ruin.validate's reach lets a saucer shrink through a small door and regrow beyond it)
  local seen, grew = { [0] = true }, true
  while grew do
    grew = false
    for _, d in ipairs(r.doors) do
      if d.class >= 4 and seen[d.a] ~= seen[d.b] then
        seen[d.a], seen[d.b], grew = true, true, true
      end
    end
  end
  for _, room in ipairs(r.rooms) do
    if room.class >= 4 and not seen[room.id] then return false, "villa room " .. room.id .. " not villa-reachable" end
  end
  for _, s in ipairs(r.relic.spaces) do
    local m = M.MIN[s.class]
    if s.class == "hall" or s.class == "core" or s.class == "reliquary" or s.class == "chamber" or s.class == "shaft" then
      if s.clear[1] < m[1] - 1 or s.clear[2] < m[2] - 1 or s.clear[3] < m[3] - 1 then return false, s.class .. " too small" end
    elseif s.class == "trunk" then
        local w = math.min(s.clear[1], s.clear[3])
      if w < m[1] - 1 or s.clear[2] < m[2] - 1 then return false, "trunk too narrow" end
    end
  end
  for _, br in ipairs(r.relic.branches) do
    local b = r.relic.bays[br.bay]
    if not b then return false, "port without a bay" end
    local d = 0
    for k = 1, 3 do d = d + (b.marker[k] - br.port.pos[k]) ^ 2 end
    if d > M.BAY_REACH * M.BAY_REACH then return false, "bay too far from its port" end
  end
  if M.charge_plan(r.relic) > M.CHARGE_MAX then return false, "charge plan" end
  if r.relic.villa_share < 0.75 then return false, "villa share" end
  local D = kit.dungeon
  if r.relic.levels < 3 then return false, "levels" end
  if #r.relic.chambers < D.chambers[1] or #r.relic.chambers > D.chambers[2] then return false, "chambers" end
  local villa = 0
  for _, s in ipairs(r.relic.spaces) do if s.villa then villa = villa + 1 end end
  if villa < 40 or villa > 80 then return false, "villa spaces " .. villa end
  for _, ph in ipairs(r.relic.phenomena) do
    local room = r.rooms[ph.room]
    local mn, mx = box(room, kit, r.origin)
    for k = 1, 3 do
      if ph.pos[k] < mn[k] or ph.pos[k] > mx[k] then return false, "phenomenon outside its room" end
    end
  end
  return true
end

-- the shortest Villa route (door to door, in m) from the maw to the heart, and its rooms
function M.route(r, kit)
  local adj = {}
  for i, d in ipairs(r.doors) do
    if d.class >= 4 then
      adj[d.a] = adj[d.a] or {}
      adj[d.b] = adj[d.b] or {}
      adj[d.a][#adj[d.a] + 1] = { d.b, i }
      adj[d.b][#adj[d.b] + 1] = { d.a, i }
    end
  end
  local function centre(id)
    local mn, mx = box(r.rooms[id], kit, r.origin)
    return { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
  end
  local dist, prev, done = { [1] = 0 }, {}, {}
  local goal = r.relic.core
  while true do
    local best, bd = nil, math.huge
    for id, dd in pairs(dist) do
      if not done[id] and (dd < bd or (dd == bd and id < best)) then best, bd = id, dd end
    end
    if not best or best == goal then break end
    done[best] = true
    local c = centre(best)
    for _, e in ipairs(adj[best] or {}) do
      if e[1] ~= 0 and not done[e[1]] then
        local o = centre(e[1])
        local dd = bd + math.sqrt((o[1] - c[1]) ^ 2 + (o[2] - c[2]) ^ 2 + (o[3] - c[3]) ^ 2)
        if not dist[e[1]] or dd < dist[e[1]] then dist[e[1]], prev[e[1]] = dd, best end
      end
    end
  end
  local path, at = {}, goal
  while at do
    table.insert(path, 1, at)
    at = prev[at]
  end
  return dist[goal], path
end

-- phenomena: strange, harmless sights (render-only) -- some halls and trunks get one, the heart several; kinds are
-- drawn from the civ's list with its weights (language.phenomena), sizes and phases from the seed
M.PHENOMENA = { motes = 1, orbit = 1, eye = 1, procession = 1, breath = 1, ripple = 1, shadow = 1, chimes = 1 }
local function phenomena(rng, rooms, doors, L, kit, origin, civ)
  local weights = civ and civ.language and civ.language.phenomena or M.PHENOMENA
  local kinds, total = {}, 0
  for k, w in pairs(weights) do kinds[#kinds + 1] = { k, w } end
  table.sort(kinds, function(a, b) return a[1] < b[1] end)
  for _, k in ipairs(kinds) do total = total + k[2] end
  local function pick()
    local x = rng:float() * total
    for _, k in ipairs(kinds) do
      x = x - k[2]
      if x <= 0 then return k[1] end
    end
    return kinds[#kinds][1]
  end
  local out = {}
  local function place(r, kind, at)
    local mn, mx = box(r, kit, origin)
    local t = kit.wall
    local pos = {}
    for k = 1, 3 do pos[k] = mn[k] + t + (mx[k] - mn[k] - 2 * t) * at[k] end
    -- a procession runs along the room's long axis; a shadow stands at the far end of it
    local long = (mx[1] - mn[1]) > (mx[3] - mn[3]) and 1 or 3
    if kind == "breath" then
      -- on a door-less side wall
      for _, f in ipairs({ "-x", "+x", "-z", "+z" }) do
        if not r.faces[f] then
          local ax = f:sub(2) == "x" and 1 or 3
          pos[ax] = f:sub(1, 1) == "-" and mn[ax] + t or mx[ax] - t
          break
        end
      end
    end
    out[#out + 1] = { id = #out + 1, kind = kind, room = r.id, pos = pos, long = long,
                      size = math.min(mx[1] - mn[1], mx[3] - mn[3]) * (0.12 + 0.1 * rng:float()),
                      phase = rng:float() * 6.283, seed = rng:int(1, 1000000) }
  end
  for _, r in ipairs(rooms) do
    if (r.kind == "hall" and rng:float() < 0.7) or ((r.kind == "trunk" or r.kind == "shaft") and rng:float() < 0.4) then
      local kind = pick()
      if r.kind ~= "hall" and (kind == "breath" or kind == "shadow") then kind = "procession" end
      place(r, kind, { 0.3 + 0.4 * rng:float(), 0.35 + 0.3 * rng:float(), 0.3 + 0.4 * rng:float() })
    elseif r.kind == "core" then
      -- the heart: four, never inside the engine column (they stand in the hall's outer ring)
      for k = 1, 4 do
        local a = (k - 1) * math.pi / 2 + 0.6
        place(r, pick(), { 0.5 + 0.34 * math.cos(a), 0.25 + 0.4 * rng:float(), 0.5 + 0.34 * math.sin(a) })
      end
    end
  end
  return out
end

function M.try(seed, kit, civ, origin)
  local rng = saucer.rng.new(seed)
  local D = kit.dungeon
  local rooms, doors, L = layout(rng, kit)
  local bays, branches, locks, chambers = {}, {}, {}, {}
  -- the lung: the first big hall on a middle level whose free +x/-x side takes the reliquary's long branch
  local function face_free(h, f) return not h.faces[f] end
  local lung, plague
  for _, h in ipairs(L.halls) do
    if not lung and h.size[1] == D.hall_w[#D.hall_w] and h.size[3] == D.hall_w[#D.hall_w] and not h.faces["-y"]
        and h ~= L.halls[1] then
      for _, f in ipairs({ { 1, 1, "+x", 3 }, { 1, -1, "-x", 3 }, { 3, 1, "+z", 1 }, { 3, -1, "-z", 1 } }) do
        if not lung and face_free(h, f[3]) then
          local u = h.cell[f[4]] + h.size[f[4]] // 4 - 1
          local new, nd, qs = branch(rooms, h, f[1], f[2], u, kit.passage[1], 1, kit.passage[2], nil, kit, "reliquary",
            kit.reliquary)
          if not new then
            u = h.cell[f[4]] + h.size[f[4]] * 3 // 4
            new, nd, qs = branch(rooms, h, f[1], f[2], u, kit.passage[1], -1, kit.passage[2], nil, kit, "reliquary",
              kit.reliquary)
          end
          if new then
            lung = h
            L.lung_branch = { new = new, nd = nd, qs = qs, axis = f[1], sign = f[2] }
          end
        end
      end
    end
  end
  if not lung then return nil, "no lung" end
  for _, h in ipairs(L.halls) do
    if not plague and h.node[3] == 0 and h ~= lung and h ~= L.halls[1] then plague = h end
  end
  plague = plague or L.halls[#L.halls]
  -- the lung's four bays, one per quadrant (four co-op players), unless a floor hole is under one
  local function bay_ok(h, b)
    return clear_of(floor_holes(h, doors, rooms, kit, origin), b.lo[1], b.hi[1], b.lo[3], b.hi[3], 1)
  end
  for _, q in ipairs({ { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } }) do
    local b = quad_bay(#bays + 1, lung, q[1], q[2], kit, origin)
    if bay_ok(lung, b) then bays[#bays + 1] = b end
  end
  local function commit(new, nd)
    for _, r in ipairs(new) do rooms[#rooms + 1] = r end
    local first = #doors + 1
    for _, e in ipairs(nd) do doors[#doors + 1] = door(e[1], e[2], e[3], e[4], 1) end
    return first
  end
  local function nearest_bay(h, pos)
    local best, bd = nil, math.huge
    for i, b in ipairs(bays) do
      if b.room == h.id then
        local d = 0
        for k = 1, 3 do d = d + (b.marker[k] - pos[k]) ^ 2 end
        if d < bd then best, bd = i, d end
      end
    end
    return best
  end
  do
    local lb = L.lung_branch
    local first = commit(lb.new, lb.nd)
    local port, lockdoor = first, first + #lb.nd - 1
    for i, e in ipairs(lb.nd) do
      if e[2] == lb.qs[1] then lockdoor = first + i - 1 end
    end
    local pc = hole(doors[port], kit, origin)
    local lc, lw, lh = hole(doors[lockdoor], kit, origin)
    local Q = lb.qs[1]
    local qmn, qmx = box(Q, kit, origin)
    -- the Seat-lock: a shutter in the reliquary's doorway (solid until the Seat turns its socket), its socket 2 m
    -- back up the passage
    local d = doors[lockdoor]
    local into = d.sign > 0 and qmn[d.axis] or qmx[d.axis]
    local lo, hi = { lc[1] - lw / 2 - 0.1, lc[2] - lh / 2 - 0.1, lc[3] - lw / 2 - 0.1 },
      { lc[1] + lw / 2 + 0.1, lc[2] + lh / 2 + 0.1, lc[3] + lw / 2 + 0.1 }
    lo[d.axis] = math.min(into - 0.25 * d.sign, into + (kit.wall + 0.25) * d.sign)
    hi[d.axis] = math.max(into - 0.25 * d.sign, into + (kit.wall + 0.25) * d.sign)
    local socket = { lc[1], lc[2], lc[3] }
    socket[d.axis] = into - 2.0 * d.sign
    locks[1] = { id = 1, kind = "seat", door = lockdoor, room = Q.id, box = { lo, hi }, socket = socket, branch = 1 }
    local seat_rooms = {}
    for _, r in ipairs(lb.new) do seat_rooms[#seat_rooms + 1] = r.id end
    branches[1] = { id = 1, rooms = seat_rooms, reliquary = Q.id, bay = nearest_bay(lung, pc), lock = 1,
                    length = (kit.passage[1] + kit.passage[2]) * kit.cell, port = { door = port, pos = pc },
                    finds = kit.loot.reliquary_finds, pockets = {} }
    chambers[1] = Q
  end
  -- every other hall (the maw's first one too) tries a Seat branch through a door-less side, its fold bay by the
  -- port; big halls may take a second through the opposite side
  local order = {}
  for _, h in ipairs(L.halls) do if h ~= lung then order[#order + 1] = h end end
  local wantmax = D.chambers[2]
  local function try_hall(h, faces)
    local mn, mx = box(h, kit, origin)
    local half = kit.bay.size * kit.cell / 2
    for _, f in ipairs(faces) do
      local axis, sign, name = f[1], f[2], f[3]
      if face_free(h, name) and #chambers < wantmax then
        local l = axis == 1 and 3 or 1
        -- the bay against this side's wall, centred on it; the port within a few cells of its middle
        local bc = { 0, 0, 0 }
        bc[axis] = sign > 0 and mx[axis] - kit.wall - half - 2 or mn[axis] + kit.wall + half + 2
        bc[l] = (mn[l] + mx[l]) / 2
        local b = bay(#bays + 1, h, bc[1], bc[3], kit, origin)
        local clash = false
        for _, o in ipairs(bays) do
          if o.room == h.id and o.lo[1] < b.hi[1] and o.hi[1] > b.lo[1] and o.lo[3] < b.hi[3] and o.hi[3] > b.lo[3] then clash = true end
        end
        if not clash and bay_ok(h, b) then
          local mid = h.cell[l] + h.size[l] // 2
          for _ = 1, 10 do
            local u = mid + rng:int(-2, 1)
            local turn = rng:int(1, 3) > 1 and (rng:int(0, 1) * 2 - 1) or nil
            local n1 = rng:int(D.out[1], D.out[2]) + (turn and 4 or 0)
            local n2 = rng:int(D.elbow[1], D.elbow[2])
            local more = rng:int(1, 2) == 1 and rng:int(2, 4) or nil
            local new, nd, qs = branch(rooms, h, axis, sign, u, n1, turn, n2, more, kit, "chamber", D.chamber)
            if new then
              bays[#bays + 1] = b
              local first = commit(new, nd)
              local pc = hole(doors[first], kit, origin)
              local seat_rooms = {}
              for _, r in ipairs(new) do seat_rooms[#seat_rooms + 1] = r.id end
              local len = 0
              for _, r in ipairs(new) do if r.kind == "passage" then len = len + math.max(r.size[1], r.size[3]) * kit.cell end end
              branches[#branches + 1] = { id = #branches + 1, rooms = seat_rooms, bay = #bays, length = len,
                                          port = { door = first, pos = pc }, finds = 0, pockets = {} }
              for _, q in ipairs(qs) do chambers[#chambers + 1] = q end
              return true
            end
          end
        end
      end
    end
    return false
  end
  local SIDES = { { 1, 1, "+x" }, { 1, -1, "-x" }, { 3, 1, "+z" }, { 3, -1, "-z" } }
  for _, h in ipairs(order) do
    local faces = {}
    local k = rng:int(0, 3)
    for i = 1, 4 do faces[i] = SIDES[(i + k - 1) % 4 + 1] end
    try_hall(h, faces)
  end
  for _, h in ipairs(order) do
    if h.size[1] == D.hall_w[#D.hall_w] or h.size[3] == D.hall_w[#D.hall_w] then try_hall(h, SIDES) end
  end
  L.chambers = chambers
  L.lung = lung
  -- the heart's engine: a solid column, floor to ceiling, in the middle of the hall
  local hmn, hmx = box(L.core, kit, origin)
  local E = { D.engine[1] * kit.cell / 2, D.engine[2] * kit.cell / 2 }
  local hc = { (hmn[1] + hmx[1]) / 2, (hmn[3] + hmx[3]) / 2 }
  local solids = { { { hc[1] - E[1], hmn[2] + kit.wall, hc[2] - E[2] }, { hc[1] + E[1], hmx[2] - kit.wall, hc[2] + E[2] },
                     kind = "engine", room = L.core.id } }
  local sl = slots(rng, seed, rooms, doors, L, kit, origin)
  local walls = ruinm.walls(rooms, doors, kit, origin)
  local sp = spaces(rooms, kit, origin)
  local villa, seat = 0, 0
  for _, s in ipairs(sp) do
    if s.villa then villa = villa + s.length else seat = seat + s.length end
  end
  local levels = {}
  local nlev = 0
  for _, h in ipairs(L.halls) do
    if not levels[h.node[3]] then levels[h.node[3]], nlev = true, nlev + 1 end
  end
  local chamber_ids = {}
  for _, q in ipairs(chambers) do chamber_ids[#chamber_ids + 1] = q.id end
  local relic = { archetype = "warren", civ_id = civ and civ.id or "vyrr", spaces = sp, bays = bays, branches = branches,
                  pockets = {}, locks = locks, lung = lung.id, plague = plague.id, core = L.core.id, heart = L.core.id,
                  halls = {}, trunks = {}, shafts = {}, chambers = chamber_ids, levels = nlev,
                  villa_share = villa / (villa + seat), length = 0, engine = 1 }
  for i, h in ipairs(L.halls) do relic.halls[i] = h.id end
  for i, t in ipairs(L.trunks) do relic.trunks[i] = t.id end
  for i, t in ipairs(L.shafts) do relic.shafts[i] = t.id end
  local mn = box(L.maw, kit, origin)
  relic.length = hmx[3] - mn[3]
  relic.phenomena = phenomena(rng, rooms, doors, L, kit, origin, civ)
  local _, reach = ruinm.validate(rooms, doors, sl)
  local r = { seed = seed, kit = kit.id, rooms = rooms, doors = doors, slots = sl, walls = walls, debris = {}, solids = solids,
              origin = origin, reach = reach, relic = relic,
              hash = saucer.seed_child(ruinm.layout_hash(rooms, doors, solids), "relic", seed % 1000003) }
  local ok, why = M.validate(r, kit)
  if not ok then return nil, why end
  relic.route_m, relic.route = M.route(r, kit)
  return r
end

-- generate(seed, kit, civ, origin) -> the relic's ruin table (memoized: a restore rebuilds derived data every time)
local memo, memo_n = {}, 0
function M.generate(seed, kit, civ, origin)
  local key = string.format("%s|%s|%s|%g,%g,%g", tostring(seed), kit.id, civ and civ.id or "?", origin[1], origin[2], origin[3])
  if memo[key] then return memo[key] end
  local out, why
  for i = 0, M.MAX_TRIES - 1 do
    out, why = M.try(i == 0 and seed or saucer.seed_child(seed, "retry", i), kit, civ, origin)
    if out then
      out.attempts = i + 1
      break
    end
  end
  if not out then error("relic generation failed: " .. tostring(why)) end
  if memo_n > 16 then memo, memo_n = {}, 0 end
  memo[key] = out
  memo_n = memo_n + 1
  return out
end

return M
