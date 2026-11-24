-- SPDX-License-Identifier: MIT
-- add-relic-stations: relic station generation (design civs-and-relics §3, first slice §9). A relic is a dead,
-- civ-built megastructure the Villa flies through: hub halls strung on a spine of trunk corridors, a Core at the
-- far end, fold bays (with power cradles) in the halls, and an optional Seat branch the saucer takes shrunk in
-- place. The slice builds the spine archetype only:
--   maw (34 x 20 m) -> vestibule -> hall 1 -> trunk -> hall 2 (the lung: it breathes, holds the Seat port and four
--   fold bays) -> trunk -> hall 3 (plague-struck) -> trunk -> the Core (128 x 64 x 128 m, the XL idol)
--   Seat branch off hall 2: a 2.6 x 2.1 m port, an 80 m passage of 4 m cells with one elbow, a 12 x 8 x 12 m
--   reliquary behind a Seat-lock (three class-1 finds).
-- The layout lives on the 4 m ruin grid and comes back in the same table shape as sim/ruin.lua's generate (rooms,
-- doors, walls, slots, solids, debris, hash) plus `relic` (archetype, civ, spaces, bays, branches, pockets, locks),
-- so physics, beams, saves and the map need no relic-specific code. Collision is the room boxes' walls only; every
-- visual skin sits outside them (view/relic.lua). Pure: a function of (seed, kit, civ, origin).
local ruinm = require("sim.ruin")
local M = {}

M.MAX_TRIES = 8
-- class minimums (m): { width, height, length } (design §3.3, §5.2)
M.MIN = {
  maw = { 34, 20 }, hall = { 96, 48, 96 }, core = { 128, 64, 128 }, trunk = { 40, 24 }, bay = { 44, 20, 44 },
  passage = { 4, 4 }, port = { 2.6, 2.1 }, reliquary = { 12, 8, 12 },
}
M.CHARGE_MAX = 100

local function room(id, kind, cell, size, class, parent)
  return { id = id, kind = kind, class = class or 4, inclass = class or 4, parent = parent or (id - 1), cell = cell,
           size = size, faces = {} }
end

-- a side door between rooms a and b through axis `axis` (b on the + side when sign > 0): the hole is centred on
-- their lateral overlap and sits on the higher floor
local function side_door(a, b, axis, sign, class)
  local l = axis == 1 and 3 or 1
  local u0, u1 = math.max(a.cell[l], b.cell[l]), math.min(a.cell[l] + a.size[l], b.cell[l] + b.size[l])
  local v0, v1 = math.max(a.cell[2], b.cell[2]), math.min(a.cell[2] + a.size[2], b.cell[2] + b.size[2])
  a.faces[ruinm.face_name(axis, sign)] = true
  b.faces[ruinm.face_name(axis, -sign)] = true
  local at = sign > 0 and a.cell[axis] + a.size[axis] or a.cell[axis]
  return { a = a.id, b = b.id, class = class, axis = axis, sign = sign, lo = u0, hi = u1, vlo = v0, vhi = v1, at = at }
end

-- the world box of a room
local function box(r, kit, origin) return ruinm.room_box(r, kit, origin) end
M.box = box

-- the spine's rooms and doors in cells (x across, y up, z along the spine); `rng` only moves loot and bays
local function layout(kit)
  local S = kit.spine
  local g = kit.grid
  local base = 10                                  -- hall floor level (cells)
  local function cx(w) return (g[1] - w) // 2 end
  local rooms, doors = {}, {}
  local z = 2
  local function add(kind, size, cy, class)
    local r = room(#rooms + 1, kind, { cx(size[1]), cy, z }, { size[1], size[2], size[3] }, class)
    rooms[#rooms + 1] = r
    z = z + size[3]
    return r
  end
  local maw = add("entrance", S.maw, base + (S.hall[2] - S.maw[2]) // 2)
  doors[1] = { a = 0, b = 1, class = 4, axis = 3, sign = 1, lo = maw.cell[1], hi = maw.cell[1] + maw.size[1],
               vlo = maw.cell[2], vhi = maw.cell[2] + maw.size[2] }
  maw.faces["-z"] = true
  local halls, trunks = {}, {}
  local prev = maw
  for h = 1, S.halls do
    local hall = add("hall", S.hall, base)
    hall.hall = h
    halls[h] = hall
    doors[#doors + 1] = side_door(prev, hall, 3, 1, 4)
    local t = add("trunk", S.trunk, base + (S.hall[2] - S.trunk[2]) // 2)
    trunks[h] = t
    doors[#doors + 1] = side_door(hall, t, 3, 1, 4)
    prev = t
  end
  local core = add("core", S.core, base - (S.core[2] - S.hall[2]) // 2)
  doors[#doors + 1] = side_door(prev, core, 3, 1, 4)
  -- the Seat branch off the lung hall's +x wall: passage A out, the elbow, passage B along +z, the reliquary
  local lung = halls[S.lung]
  local py = lung.cell[2] + S.port_rise
  local pz = lung.cell[3] + S.hall[3] // 4 - 1      -- level with the (+x, -z) quadrant's bay marker
  local ax0 = lung.cell[1] + lung.size[1]
  local A = room(#rooms + 1, "passage", { ax0, py, pz }, { S.passage[1] - 1, 1, 1 }, 1, lung.id)
  rooms[#rooms + 1] = A
  local B = room(#rooms + 1, "passage", { ax0 + A.size[1], py, pz }, { 1, 1, S.passage[2] + 1 }, 1, A.id)
  rooms[#rooms + 1] = B
  local R = S.reliquary
  local Q = room(#rooms + 1, "reliquary", { B.cell[1] - (R[1] - 1) // 2, py, B.cell[3] + B.size[3] }, { R[1], R[2], R[3] }, 1,
    B.id)
  rooms[#rooms + 1] = Q
  local port = side_door(lung, A, 1, 1, 1)
  doors[#doors + 1] = port
  doors[#doors + 1] = side_door(A, B, 1, 1, 1)
  local lockdoor = side_door(B, Q, 3, 1, 1)
  doors[#doors + 1] = lockdoor
  return rooms, doors, { halls = halls, trunks = trunks, core = core, maw = maw, lung = lung, A = A, B = B, Q = Q,
                         port = #doors - 2, lock = #doors }
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

-- a fold bay: a 44 x 20 x 44 m box on the hall floor in quadrant (qx, qz), the Seat marker over its centre
local function bay(id, hall, qx, qz, kit, origin)
  local mn, mx = box(hall, kit, origin)
  local floor = mn[2] + kit.wall
  local half = kit.bay.size * kit.cell / 2
  local c = { (mn[1] + mx[1]) / 2 + qx * (mx[1] - mn[1]) / 4, floor, (mn[3] + mx[3]) / 2 + qz * (mx[3] - mn[3]) / 4 }
  return { id = id, room = hall.id, hall = hall.hall, quadrant = { qx, qz },
           lo = { c[1] - half, floor, c[3] - half }, hi = { c[1] + half, floor + 20, c[3] + half },
           marker = { c[1], floor + kit.bay.marker_y, c[3] }, cradle = { c[1], floor, c[3] } }
end

-- loot: kit.loot.hall_finds spread over the halls (two each), the reliquary's class-1 finds, the XL idol in the Core
local function slots(rng, seed, L, kit, origin)
  local out = {}
  local function add(r, pos, max_size, tier, extra)
    local s = { id = #out + 1, room = r.id, pos = pos, max_size = max_size, tier = tier,
                seed = saucer.seed_child(seed, "slot", #out + 1) }
    for k, v in pairs(extra or {}) do s[k] = v end
    out[#out + 1] = s
    return s
  end
  local per = kit.loot.hall_finds // #L.halls
  for hi, h in ipairs(L.halls) do
    local mn, mx = box(h, kit, origin)
    local c = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + 1.5, (mn[3] + mx[3]) / 2 }
    for k = 1, per do
      -- along the spine's centre line, either side of the hall's middle, jittered (never under a bay marker)
      local dz = (k - (per + 1) / 2) * 30 + rng:int(-4, 4)
      local dx = rng:int(-12, 12)
      local sz = kit.loot.hall_size[((hi + k) % #kit.loot.hall_size) + 1]
      add(h, { c[1] + dx, c[2], c[3] + dz }, sz, 2, { hall = h.hall })
    end
  end
  local mn, mx = box(L.Q, kit, origin)
  for k = 1, kit.loot.reliquary_finds do
    add(L.Q, { (mn[1] + mx[1]) / 2 + (k - (kit.loot.reliquary_finds + 1) / 2) * 3, mn[2] + kit.wall + 1.0,
               (mn[3] + mx[3]) / 2 + (k % 2) * 2 - 1 }, 1, 3, { warren = true })
  end
  mn, mx = box(L.core, kit, origin)
  add(L.core, { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + 3.5, (mn[3] + mx[3]) / 2 + 16 }, 4, 3,
    { xl = true, idol = true })
  return out
end

-- the spaces with their class and measured clear size (m), for the validator, the tests and the map
local function spaces(rooms, kit, origin)
  local out = {}
  local cls = { entrance = "maw", hall = "hall", trunk = "trunk", core = "core", passage = "passage",
                reliquary = "reliquary" }
  for _, r in ipairs(rooms) do
    local mn, mx = box(r, kit, origin)
    local t = 2 * kit.wall
    local along = r.kind == "passage" and math.max(r.size[1], r.size[3]) * kit.cell or (mx[3] - mn[3])
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
    if s.class == "hall" or s.class == "core" or s.class == "reliquary" then
      if s.clear[1] < m[1] - 1 or s.clear[2] < m[2] - 1 or s.clear[3] < m[3] - 1 then return false, s.class .. " too small" end
    elseif s.class == "trunk" then
      if s.clear[1] < m[1] - 1 or s.clear[2] < m[2] - 1 then return false, "trunk too narrow" end
    end
  end
  for _, br in ipairs(r.relic.branches) do
    local b = r.relic.bays[br.bay]
    if not b then return false, "port without a bay" end
    local d = 0
    for k = 1, 3 do d = d + (b.marker[k] - br.port.pos[k]) ^ 2 end
    if d > 30 * 30 then return false, "bay too far from its port" end
  end
  if M.charge_plan(r.relic) > M.CHARGE_MAX then return false, "charge plan" end
  if r.relic.villa_share < 0.75 then return false, "villa share" end
  return true
end

function M.try(seed, kit, civ, origin)
  local rng = saucer.rng.new(seed)
  local rooms, doors, L = layout(kit)
  local sl = slots(rng, seed, L, kit, origin)
  local bays = {}
  -- hall 1 and hall 3: one bay each (a seeded quadrant); the lung hall: one per quadrant (four co-op players)
  for _, h in ipairs(L.halls) do
    if h == L.lung then
      for _, q in ipairs({ { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } }) do bays[#bays + 1] = bay(#bays + 1, h, q[1], q[2], kit, origin) end
    else
      bays[#bays + 1] = bay(#bays + 1, h, rng:int(0, 1) * 2 - 1, rng:int(0, 1) * 2 - 1, kit, origin)
    end
  end
  local walls = ruinm.walls(rooms, doors, kit, origin)
  local pc = hole(doors[L.port], kit, origin)
  local lc, lw, lh = hole(doors[L.lock], kit, origin)
  -- the Seat-lock: a shutter in the reliquary's doorway (solid until the Seat turns its socket), the socket 2 m
  -- back up the passage
  local qmn = box(L.Q, kit, origin)
  local shutter = { { lc[1] - lw / 2 - 0.1, lc[2] - lh / 2 - 0.1, qmn[3] - 0.25 },
                    { lc[1] + lw / 2 + 0.1, lc[2] + lh / 2 + 0.1, qmn[3] + kit.wall + 0.25 } }
  local locks = { { id = 1, kind = "seat", door = L.lock, room = L.Q.id, box = shutter,
                    socket = { lc[1], lc[2], qmn[3] - 2.0 }, branch = 1 } }
  -- the nearest bay to the port mouth
  local best, bd = 1, math.huge
  for i, b in ipairs(bays) do
    if b.room == L.lung.id then
      local d = 0
      for k = 1, 3 do d = d + (b.marker[k] - pc[k]) ^ 2 end
      if d < bd then best, bd = i, d end
    end
  end
  local branches = { { id = 1, rooms = { L.A.id, L.B.id, L.Q.id }, reliquary = L.Q.id, bay = best, lock = 1,
                       length = (L.A.size[1] + L.B.size[3]) * kit.cell, port = { door = L.port, pos = pc },
                       finds = kit.loot.reliquary_finds, pockets = {} } }
  local sp = spaces(rooms, kit, origin)
  local villa, seat = 0, 0
  for _, s in ipairs(sp) do
    if s.villa then villa = villa + s.length else seat = seat + s.length end
  end
  local relic = { archetype = "spine", civ_id = civ and civ.id or "vyrr", spaces = sp, bays = bays, branches = branches,
                  pockets = {}, locks = locks, lung = L.lung.id, plague = L.halls[kit.spine.plague].id, core = L.core.id,
                  halls = {}, trunks = {}, villa_share = villa / (villa + seat), length = 0 }
  for i, h in ipairs(L.halls) do relic.halls[i] = h.id end
  for i, t in ipairs(L.trunks) do relic.trunks[i] = t.id end
  local mn = box(L.maw, kit, origin)
  local _, mx = box(L.core, kit, origin)
  relic.length = mx[3] - mn[3]
  local _, reach = ruinm.validate(rooms, doors, sl)
  local r = { seed = seed, kit = kit.id, rooms = rooms, doors = doors, slots = sl, walls = walls, debris = {}, solids = {},
              origin = origin, reach = reach, relic = relic,
              -- the layout is fixed; the seed moves bays and finds, so it is part of the hash (view caches key on it)
              hash = saucer.seed_child(ruinm.layout_hash(rooms, doors, {}), "relic", seed % 1000003) }
  local ok, why = M.validate(r, kit)
  if not ok then return nil, why end
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
