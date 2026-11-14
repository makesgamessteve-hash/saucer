-- SPDX-License-Identifier: MIT
-- Derelict generation (concept §5.2, spec ruin-gen): a mission graph of
-- great halls (big enough for the whole Villa) with tight ducts branching off
-- (Seat only) is embedded on a cell grid, turned into wall boxes with door
-- holes, then validated with the room-size reachability search. Up to 8
-- derived seeds are tried before a fixed fallback layout.
local data = require("lib.data")
local M = {}

M.GRID = { 64, 8, 96 }
M.MAX_TRIES = 8
M.FALLBACK_GRID = { 64, 8, 96 }
local DIRS = {
  { name = "+z", axis = 3, sign = 1 },
  { name = "+x", axis = 1, sign = 1 },
  { name = "-x", axis = 1, sign = -1 },
  { name = "-z", axis = 3, sign = -1 },
}

local function kit_of(id) return data.load("kits/" .. id .. ".lua") end
M.kit_of = kit_of

local function new_room(id, class, kit, kind, parent, size)
  local d = size or kit.rooms[class]
  return { id = id, class = class, kind = kind, parent = parent, size = { d[1], d[2], d[3] }, cell = { 0, 0, 0 },
           inclass = class, faces = {} }
end

-- mission graph: a chain of great halls from the entrance to the vault, plus
-- ducts off random halls (at least one), some ending in a small cache chamber
function M.graph(rng, kit, civ, first_class)
  local big = kit.big or 4
  local nhalls = rng:int(kit.halls_min, kit.halls_max)
  local nducts = rng:int(kit.ducts_min or 1, kit.ducts_max or 1)
  local rooms = { new_room(1, first_class or big, kit, "entrance", 0) }
  for i = 2, nhalls do
    rooms[i] = new_room(i, big, kit, i == nhalls and "vault" or "hall", i - 1)
  end
  for _ = 1, nducts do
    local host = rng:int(1, nhalls)
    local duct = new_room(#rooms + 1, 1, kit, "side", host)
    rooms[#rooms + 1] = duct
    if kit.chamber and rng:int(1, 100) <= civ.size_lock then
      duct.kind = "duct"
      rooms[#rooms + 1] = new_room(#rooms + 1, 1, kit, "side", duct.id, kit.chamber)
    end
  end
  return rooms
end

-- lateral axis for a face on `axis` (x faces run along z and vice versa)
local function lateral(axis) return axis == 1 and 3 or 1 end

-- try to put child next to parent through face dir; returns cell or nil
local function fit(grid, parent, child, dir, kit)
  local a, l = dir.axis, lateral(dir.axis)
  local cell = { 0, 0, 0 }
  if dir.sign > 0 then cell[a] = parent.cell[a] + parent.size[a]
  else cell[a] = parent.cell[a] - child.size[a] end
  cell[l] = parent.cell[l] + (parent.size[l] - child.size[l]) // 2
  cell[2] = 0
  -- the shared face must be wide enough for the door between them
  local lo = math.max(cell[l], parent.cell[l])
  local hi = math.min(cell[l] + child.size[l], parent.cell[l] + parent.size[l])
  local door = kit.doors[child.class]
  if (hi - lo) * kit.cell - 2 * kit.wall < door[1] + 0.2 then return nil end
  if not grid:free(cell[1], cell[2], cell[3], child.size[1], child.size[2], child.size[3]) then return nil end
  return cell, lo, hi
end

function M.embed(rng, rooms, kit, dims)
  dims = dims or M.GRID
  local grid = saucer.procgen.grid_new(dims[1], dims[2], dims[3])
  local e = rooms[1]
  e.cell = { (dims[1] - e.size[1]) // 2, 0, 2 }
  if not grid:place(e.cell[1], e.cell[2], e.cell[3], e.size[1], e.size[2], e.size[3], 1) then return nil end
  -- keep the approach to the hangar door clear of other rooms
  grid:place(e.cell[1], 0, 0, e.size[1], dims[2], e.cell[3], 9999)
  local doors = { { a = 0, b = 1, class = e.class, axis = 3, sign = 1, lo = e.cell[1], hi = e.cell[1] + e.size[1] } }
  e.faces["-z"] = true
  for i = 2, #rooms do
    local r, p = rooms[i], rooms[rooms[i].parent]
    local order = { 1, 2, 3, 4 }
    for k = 4, 2, -1 do
      local j = rng:int(1, k)
      order[k], order[j] = order[j], order[k]
    end
    local placed = false
    local base = { r.size[1], r.size[2], r.size[3] }
    for _, di in ipairs(order) do
      local dir = DIRS[di]
      -- small rooms run away from their parent (a duct is long, not wide)
      if r.class < (kit.big or 4) and dir.axis == 1 then r.size = { base[3], base[2], base[1] }
      else r.size = { base[1], base[2], base[3] } end
      local cell, lo, hi = fit(grid, p, r, dir, kit)
      if cell then
        r.cell = cell
        grid:place(cell[1], cell[2], cell[3], r.size[1], r.size[2], r.size[3], i)
        doors[#doors + 1] = { a = p.id, b = r.id, class = r.class, axis = dir.axis, sign = dir.sign, lo = lo, hi = hi }
        p.faces[dir.name] = true
        r.faces[(dir.sign > 0 and "-" or "+") .. (dir.axis == 1 and "x" or "z")] = true
        r.inclass = r.class
        placed = true
        break
      end
    end
    if not placed then return nil end
  end
  return doors
end

-- world-space box of a room's cells
local function room_box(r, kit, origin)
  local mn, mx = {}, {}
  for k = 1, 3 do
    mn[k] = origin[k] + r.cell[k] * kit.cell
    mx[k] = mn[k] + r.size[k] * kit.cell
  end
  return mn, mx
end
M.room_box = room_box

-- split a wall slab (u along lateral axis, v vertical) around floor-level holes
local function slab_pieces(u0, u1, v0, v1, holes)
  table.sort(holes, function(x, y) return x[1] < y[1] end)
  local out, cur = {}, u0
  for _, h in ipairs(holes) do
    if h[1] > cur then out[#out + 1] = { cur, h[1], v0, v1 } end
    if h[3] < v1 then out[#out + 1] = { h[1], h[2], h[3], v1 } end
    if h[2] > cur then cur = h[2] end
  end
  if u1 > cur then out[#out + 1] = { cur, u1, v0, v1 } end
  return out
end
M.slab_pieces = slab_pieces

-- door hole rectangles (lateral range, top) on a room face
local function face_holes(r, doors, rooms, kit, origin, axis, sign)
  local holes = {}
  local mn = room_box(r, kit, origin)
  for _, d in ipairs(doors) do
    local mine = (d.b == r.id and d.axis == axis and d.sign == -sign) or (d.a == r.id and d.axis == axis and d.sign == sign)
    if mine then
      local w, h = kit.doors[d.class][1], kit.doors[d.class][2]
      local l = lateral(axis)
      local center = origin[l] + (d.lo + d.hi) / 2 * kit.cell
      holes[#holes + 1] = { center - w / 2, center + w / 2, mn[2] + kit.wall + h }
    end
  end
  return holes
end
M.face_holes = face_holes

function M.walls(rooms, doors, kit, origin)
  local boxes = {}
  local t = kit.wall
  local function add(mn, mx) boxes[#boxes + 1] = { mn, mx } end
  for _, r in ipairs(rooms) do
    local mn, mx = room_box(r, kit, origin)
    add({ mn[1], mn[2], mn[3] }, { mx[1], mn[2] + t, mx[3] })
    add({ mn[1], mx[2] - t, mn[3] }, { mx[1], mx[2], mx[3] })
    for _, f in ipairs({ { 1, -1 }, { 1, 1 }, { 3, -1 }, { 3, 1 } }) do
      local axis, sign = f[1], f[2]
      local l = lateral(axis)
      local a0 = sign < 0 and mn[axis] or mx[axis] - t
      local u0, u1 = mn[l], mx[l]
      if axis == 3 then u0, u1 = mn[l] + t, mx[l] - t end
      local holes = face_holes(r, doors, rooms, kit, origin, axis, sign)
      for _, p in ipairs(slab_pieces(u0, u1, mn[2] + t, mx[2] - t, holes)) do
        local bmn, bmx = {}, {}
        bmn[axis], bmx[axis] = a0, a0 + t
        bmn[l], bmx[l] = p[1], p[2]
        bmn[2], bmx[2] = p[3], p[4]
        add(bmn, bmx)
      end
    end
  end
  return boxes
end

-- crates against door-less walls of larger rooms (render + collision)
function M.debris(rng, rooms, kit, origin)
  local out = {}
  for _, r in ipairs(rooms) do
    if r.class >= 2 then
      local mn, mx = room_box(r, kit, origin)
      for _, f in ipairs({ "+x", "-x", "+z", "-z" }) do
        if not r.faces[f] and rng:int(1, 100) <= 50 and #out < kit.debris * #rooms then
          local s = r.class >= (kit.big or 4) and 5.0 or 1.2
          local c = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall, (mn[3] + mx[3]) / 2 }
          local axis = f:sub(2, 2) == "x" and 1 or 3
          local edge = f:sub(1, 1) == "+" and mx[axis] - kit.wall - s or mn[axis] + kit.wall
          local bmn = { c[1] - s / 2, c[2], c[3] - s / 2 }
          bmn[axis] = edge
          out[#out + 1] = { bmn, { bmn[1] + s, bmn[2] + s, bmn[3] + s } }
        end
      end
    end
  end
  return out
end

-- loot slots: vault 2 (+ the Echo spot), side rooms 1, halls 0..1
function M.slots(rng, rooms, kit, origin, seed)
  local out = {}
  for _, r in ipairs(rooms) do
    local n = 0
    if r.kind == "vault" then n = 2 elseif r.kind == "side" then n = 1 elseif r.kind == "hall" then n = rng:int(0, 1) end
    local mn, mx = room_box(r, kit, origin)
    local big = r.class >= (kit.big or 4)
    for k = 1, n do
      local cx = (mn[1] + mx[1]) / 2 + (k - (n + 1) / 2) * math.min(big and 10 or 3, (mx[1] - mn[1]) / 4)
      local cz = (mn[3] + mx[3]) / 2
      out[#out + 1] = {
        id = #out + 1, room = r.id, pos = { cx, mn[2] + kit.wall + (big and 1.5 or 1.0), cz },
        max_size = math.min(r.inclass, 3), tier = (r.kind == "vault" or r.kind == "side") and 2 or 1,
        seed = saucer.seed_child(seed, "slot", #out + 1),
      }
    end
    if r.kind == "vault" then
      -- off-centre so wall-centre crates never hide it
      r.echo_pos = { (mn[1] + mx[1]) / 2 + (mx[1] - mn[1]) / 4, mn[2] + kit.wall + 0.8, mx[3] - kit.wall - 1.2 }
    end
  end
  return out
end

-- reachability check over the room graph; node 1 is open space (class 4)
function M.validate(rooms, doors, slots)
  local rc, edges = { 4 }, {}
  for i, r in ipairs(rooms) do rc[i + 1] = r.class end
  for _, d in ipairs(doors) do edges[#edges + 1] = { d.a + 1, d.b + 1, d.class } end
  local reach = saucer.procgen.reachable(rc, edges, 1, 4, 1)
  for i = 1, #rooms do
    if not reach[i + 1] then return false, "room " .. i .. " unreachable" end
  end
  for _, s in ipairs(slots) do
    if s.max_size > reach[s.room + 1] then return false, "slot " .. s.id .. " too big" end
  end
  return true, reach
end

local function layout_hash(rooms, doors)
  local parts = {}
  for _, r in ipairs(rooms) do
    parts[#parts + 1] = string.format("r%d:%d:%d,%d,%d:%d,%d,%d", r.id, r.class, r.cell[1], r.cell[2], r.cell[3],
      r.size[1], r.size[2], r.size[3])
  end
  for _, d in ipairs(doors) do parts[#parts + 1] = string.format("d%d-%d:%d", d.a, d.b, d.class) end
  return saucer.hash64(table.concat(parts, ";"))
end

function M.try(seed, kit, civ, origin, first_class)
  local rng = saucer.rng.new(seed)
  local rooms = M.graph(rng, kit, civ, first_class)
  local doors = M.embed(rng, rooms, kit)
  if not doors then return nil, "embed failed" end
  local slots = M.slots(rng, rooms, kit, origin, seed)
  local ok, why = M.validate(rooms, doors, slots)
  if not ok then return nil, why end
  local boxes = M.walls(rooms, doors, kit, origin)
  local debris = M.debris(rng, rooms, kit, origin)
  return { seed = seed, kit = kit.id, rooms = rooms, doors = doors, slots = slots, walls = boxes, debris = debris,
           hash = layout_hash(rooms, doors), reach = why }
end

-- fallback: great hall -> duct vault, always valid
function M.fallback(seed, kit, origin)
  local rooms = { new_room(1, kit.big or 4, kit, "entrance", 0), new_room(2, 1, kit, "vault", 1) }
  local rng = saucer.rng.new(seed)
  local doors = M.embed(rng, rooms, kit, M.FALLBACK_GRID)
  local slots = M.slots(rng, rooms, kit, origin, seed)
  local ok, reach = M.validate(rooms, doors, slots)
  return { seed = seed, kit = kit.id, rooms = rooms, doors = doors, slots = slots,
           walls = M.walls(rooms, doors, kit, origin), debris = {}, hash = layout_hash(rooms, doors),
           reach = reach, fallback = true }
end

function M.generate(seed, kit_id, civ, origin, tries, first_class)
  local kit = kit_of(kit_id)
  for i = 0, (tries or M.MAX_TRIES) - 1 do
    local s = i == 0 and seed or saucer.seed_child(seed, "retry", i)
    local r = M.try(s, kit, civ, origin, first_class)
    if r then
      r.attempts = i + 1
      return r
    end
  end
  saucer.log.warn("ruin generation fell back to the fixed layout for seed " .. tostring(seed))
  return M.fallback(seed, kit, origin)
end

-- bounds of all rooms, padded; used for "inside the site" checks
function M.bounds(ruin, origin, pad)
  local kit = kit_of(ruin.kit)
  local lo, hi = { 1e30, 1e30, 1e30 }, { -1e30, -1e30, -1e30 }
  for _, r in ipairs(ruin.rooms) do
    local mn, mx = room_box(r, kit, origin)
    for k = 1, 3 do
      if mn[k] < lo[k] then lo[k] = mn[k] end
      if mx[k] > hi[k] then hi[k] = mx[k] end
    end
  end
  for k = 1, 3 do
    lo[k] = lo[k] - pad
    hi[k] = hi[k] + pad
  end
  return lo, hi
end

-- entrance door center (world), for spawning / camera helpers
function M.entrance(ruin, origin)
  local kit = kit_of(ruin.kit)
  local e = ruin.rooms[1]
  local mn, mx = room_box(e, kit, origin)
  local h = kit.doors[e.class][2]
  return { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + h / 2, mn[3] }
end

return M
