-- SPDX-License-Identifier: MIT
-- Derelict generation, true 3D (concept §5.2, specs ruin-gen and
-- add-true-3d-flight). A mission graph of great halls and vertical shafts
-- (big enough for the whole Villa), side wings, and tight ducts (Seat only)
-- is embedded on a 3D cell grid. Rooms attach through any of the six faces:
-- beside their parent at another level, stacked on top of it, or hanging
-- below it, so layouts branch in X, Y and Z. Doors are holes in side walls
-- (at the higher of the two floors) or in floor/ceiling slabs. The rooms are
-- turned into wall boxes, validated with the room-size reachability search,
-- and must span several levels; up to 8 derived seeds are tried before a
-- fixed (still multi-level) fallback layout. Exterior solids (hull spines,
-- trusses, city towers) are added around the rooms. Deterministic per seed.
local data = require("lib.data")
local M = {}

M.GRID = nil              -- tests may force a grid; otherwise each kit has its own
M.MAX_TRIES = 8
local DIRS = {
  { name = "+z", axis = 3, sign = 1 },
  { name = "+x", axis = 1, sign = 1 },
  { name = "-x", axis = 1, sign = -1 },
  { name = "-z", axis = 3, sign = -1 },
  { name = "+y", axis = 2, sign = 1 },
  { name = "-y", axis = 2, sign = -1 },
}
M.DIRS = DIRS
local AXIS_NAME = { "x", "y", "z" }
local function face_name(axis, sign) return (sign > 0 and "+" or "-") .. AXIS_NAME[axis] end
M.face_name = face_name

local function kit_of(id) return data.load("kits/" .. id .. ".lua") end
M.kit_of = kit_of
function M.grid_of(kit) return M.GRID or kit.grid or { 64, 48, 96 } end

local function new_room(id, class, kit, kind, parent, size)
  local d = size or kit.rooms[class]
  return { id = id, class = class, kind = kind, parent = parent, size = { d[1], d[2], d[3] }, cell = { 0, 0, 0 },
           inclass = class, faces = {} }
end

-- mission graph: a chain from the entrance to the vault through great halls
-- and vertical shafts, wings branching off the chain, and ducts off chain
-- rooms (at least one), some ending in a small cache chamber
function M.graph(rng, kit, civ, first_class)
  local big = kit.big or 4
  local nhalls = math.max(2, rng:int(kit.halls_min, kit.halls_max))
  local kinds = { "entrance" }
  for _ = 2, nhalls - 1 do kinds[#kinds + 1] = "hall" end
  kinds[#kinds + 1] = "vault"
  for _ = 1, rng:int(kit.shafts_min or 0, kit.shafts_max or 0) do
    table.insert(kinds, rng:int(2, #kinds), "shaft")
  end
  local rooms = {}
  for i, k in ipairs(kinds) do
    rooms[i] = new_room(i, i == 1 and (first_class or big) or big, kit, k, i - 1, k == "shaft" and kit.shaft or nil)
  end
  local nchain = #rooms
  for _ = 1, rng:int(kit.wings_min or 0, kit.wings_max or 0) do
    rooms[#rooms + 1] = new_room(#rooms + 1, big, kit, "wing", rng:int(1, nchain), kit.wing)
  end
  for _ = 1, rng:int(kit.ducts_min or 1, kit.ducts_max or 1) do
    local host = rng:int(1, nchain)
    local duct = new_room(#rooms + 1, 1, kit, "side", host)
    rooms[#rooms + 1] = duct
    if kit.chamber and rng:int(1, 100) <= civ.size_lock then
      duct.kind = "duct"
      rooms[#rooms + 1] = new_room(#rooms + 1, 1, kit, "side", duct.id, kit.chamber)
    end
  end
  return rooms
end

-- lateral axis for a side face (x faces run along z and vice versa)
local function lateral(axis) return axis == 1 and 3 or 1 end
M.lateral = lateral

-- the opening a door of `class` needs in each direction across a face (m)
local function need(kit, class)
  local d = kit.doors[class]
  return d[1] + 2 * kit.wall + 0.2, d[2] + 2 * kit.wall + 0.2
end

-- try to put child r next to parent p through face dir with offsets off
-- (lateral jitter in cells; for side faces off[2] is the child's floor
-- relative to the parent's floor). -> cell, door or nil
local function fit(grid, p, r, dir, kit, off)
  local a = dir.axis
  local cell = { 0, 0, 0 }
  cell[a] = dir.sign > 0 and p.cell[a] + p.size[a] or p.cell[a] - r.size[a]
  for k = 1, 3 do
    if k ~= a then
      if k == 2 then cell[k] = p.cell[2] + off[2]
      else cell[k] = p.cell[k] + (p.size[k] - r.size[k]) // 2 + off[k] end
    end
  end
  local function ov(k)
    return math.max(cell[k], p.cell[k]), math.min(cell[k] + r.size[k], p.cell[k] + p.size[k])
  end
  local w, h = need(kit, r.class)
  local door = { a = p.id, b = r.id, class = r.class, axis = a, sign = dir.sign }
  if a == 2 then
    local x0, x1 = ov(1)
    local z0, z1 = ov(3)
    if (x1 - x0) * kit.cell < w or (z1 - z0) * kit.cell < w then return nil end
    door.lo, door.hi, door.lo3, door.hi3 = x0, x1, z0, z1
  else
    local u0, u1 = ov(lateral(a))
    local v0, v1 = ov(2)
    if (u1 - u0) * kit.cell < w or (v1 - v0) * kit.cell < h then return nil end
    door.lo, door.hi, door.vlo, door.vhi = u0, u1, v0, v1
  end
  if not grid:free(cell[1], cell[2], cell[3], r.size[1], r.size[2], r.size[3]) then return nil end
  return cell, door
end
M.fit = fit

-- offsets to try for one face: a random level/jitter first, then aligned ones
local function offsets(rng, kit, p, r, dir)
  local j = kit.jitter or 0
  if dir.axis == 2 then return { { rng:int(-j, j), 0, rng:int(-j, j) }, { 0, 0, 0 } } end
  local l = lateral(dir.axis)
  local dh = p.size[2] - r.size[2]
  local lo, hi = math.min(0, dh), math.max(0, dh)
  local lv = kit.level_jitter or 0
  local function o(v, lj)
    local t = { 0, v, 0 }
    t[l] = lj
    return t
  end
  return { o(rng:int(lo - lv, hi + lv), rng:int(-j, j)), o(dh // 2, 0), o(0, 0), o(dh, 0) }
end

-- a small room runs away from its parent: a duct is long, not wide (and a
-- duct leaving through a floor or ceiling is a vertical chute)
local function shape(r, base, dir, kit)
  if r.class < (kit.big or 4) then
    if dir.axis == 1 then return { base[3], base[2], base[1] } end
    if dir.axis == 2 and base[1] == base[2] then return { base[1], base[3], base[2] } end
  end
  return { base[1], base[2], base[3] }
end

local function link(rooms, doors, p, r, door, dir)
  doors[#doors + 1] = door
  p.faces[dir.name] = true
  r.faces[face_name(dir.axis, -dir.sign)] = true
  r.inclass = r.class
end

function M.embed(rng, rooms, kit, dims)
  dims = dims or M.grid_of(kit)
  local grid = saucer.procgen.grid_new(dims[1], dims[2], dims[3])
  local e = rooms[1]
  e.cell = { (dims[1] - e.size[1]) // 2, (dims[2] - e.size[2]) // 2, 2 }
  if not grid:place(e.cell[1], e.cell[2], e.cell[3], e.size[1], e.size[2], e.size[3], 1) then return nil end
  -- keep the whole approach face clear: nothing is built in front of the hangar
  grid:place(0, 0, 0, dims[1], dims[2], e.cell[3], 9999)
  local doors = { { a = 0, b = 1, class = e.class, axis = 3, sign = 1, lo = e.cell[1], hi = e.cell[1] + e.size[1],
                    vlo = e.cell[2], vhi = e.cell[2] + e.size[2] } }
  e.faces["-z"] = true
  for i = 2, #rooms do
    local r, p = rooms[i], rooms[rooms[i].parent]
    local order = { 1, 2, 3, 4, 5, 6 }
    for k = 6, 2, -1 do
      local j = rng:int(1, k)
      order[k], order[j] = order[j], order[k]
    end
    local base = { r.size[1], r.size[2], r.size[3] }
    local placed = false
    for _, di in ipairs(order) do
      local dir = DIRS[di]
      r.size = shape(r, base, dir, kit)
      for _, off in ipairs(offsets(rng, kit, p, r, dir)) do
        local cell, door = fit(grid, p, r, dir, kit, off)
        if cell then
          r.cell = cell
          grid:place(cell[1], cell[2], cell[3], r.size[1], r.size[2], r.size[3], i)
          link(rooms, doors, p, r, door, dir)
          placed = true
          break
        end
      end
      if placed then break end
    end
    if not placed then return nil end
  end
  return doors, grid
end

-- vertical extent of a layout in cells, and the number of distinct floor
-- levels among the big rooms
function M.span(rooms, kit)
  local lo, hi, floors, n = math.huge, -math.huge, {}, 0
  for _, r in ipairs(rooms) do
    lo = math.min(lo, r.cell[2])
    hi = math.max(hi, r.cell[2] + r.size[2])
    if r.class >= ((kit and kit.big) or 4) and not floors[r.cell[2]] then
      floors[r.cell[2]] = true
      n = n + 1
    end
  end
  return hi - lo, n
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

-- Split a rectangle [u0,u1] x [v0,v1] around rectangular holes {u0,u1,v0,v1}.
-- Columns between hole edges keep what no hole covers; equal neighbouring
-- columns are merged. -> list of { u0, u1, v0, v1 }
local function slab_pieces(u0, u1, v0, v1, holes)
  local cuts = { u0, u1 }
  for _, h in ipairs(holes) do
    if h[1] > u0 and h[1] < u1 then cuts[#cuts + 1] = h[1] end
    if h[2] > u0 and h[2] < u1 then cuts[#cuts + 1] = h[2] end
  end
  table.sort(cuts)
  local out, prev = {}, nil
  for i = 1, #cuts - 1 do
    local a, b = cuts[i], cuts[i + 1]
    if b > a then
      local cover = {}
      for _, h in ipairs(holes) do
        if h[1] <= a and h[2] >= b and h[4] > v0 and h[3] < v1 then
          cover[#cover + 1] = { math.max(h[3], v0), math.min(h[4], v1) }
        end
      end
      table.sort(cover, function(x, y) return x[1] < y[1] end)
      local spans, cur = {}, v0
      for _, c in ipairs(cover) do
        if c[1] > cur then spans[#spans + 1] = { cur, c[1] } end
        if c[2] > cur then cur = c[2] end
      end
      if v1 > cur then spans[#spans + 1] = { cur, v1 } end
      local key = {}
      for _, s in ipairs(spans) do key[#key + 1] = s[1] .. ":" .. s[2] end
      key = table.concat(key, ",")
      if prev and prev.key == key and prev.b == a then
        for _, piece in ipairs(prev.pieces) do piece[2] = b end
        prev.b = b
      else
        local pieces = {}
        for _, s in ipairs(spans) do
          pieces[#pieces + 1] = { a, b, s[1], s[2] }
          out[#out + 1] = pieces[#pieces]
        end
        prev = { key = key, b = b, pieces = pieces }
      end
    end
  end
  return out
end
M.slab_pieces = slab_pieces

-- door hole rectangles on one face of room r, in that face's (u, v) plane:
-- side faces use (lateral, y), floors and ceilings use (x, z)
local function face_holes(r, doors, rooms, kit, origin, axis, sign)
  local holes = {}
  for _, d in ipairs(doors) do
    local mine = (d.b == r.id and d.axis == axis and d.sign == -sign) or (d.a == r.id and d.axis == axis and d.sign == sign)
    if mine then
      local w, h = kit.doors[d.class][1], kit.doors[d.class][2]
      if axis == 2 then
        local cx = origin[1] + (d.lo + d.hi) / 2 * kit.cell
        local cz = origin[3] + (d.lo3 + d.hi3) / 2 * kit.cell
        holes[#holes + 1] = { cx - w / 2, cx + w / 2, cz - w / 2, cz + w / 2 }
      else
        local l = lateral(axis)
        local center = origin[l] + (d.lo + d.hi) / 2 * kit.cell
        local bottom = origin[2] + d.vlo * kit.cell + kit.wall
        holes[#holes + 1] = { center - w / 2, center + w / 2, bottom, bottom + h }
      end
    end
  end
  return holes
end
M.face_holes = face_holes

local FACES = { { 2, -1 }, { 2, 1 }, { 1, -1 }, { 1, 1 }, { 3, -1 }, { 3, 1 } }
M.FACES = FACES

function M.walls(rooms, doors, kit, origin)
  local boxes = {}
  local t = kit.wall
  for _, r in ipairs(rooms) do
    local mn, mx = room_box(r, kit, origin)
    for _, f in ipairs(FACES) do
      local axis, sign = f[1], f[2]
      local holes = face_holes(r, doors, rooms, kit, origin, axis, sign)
      local a0 = sign < 0 and mn[axis] or mx[axis] - t
      local pu, pv, u0, u1, v0, v1
      if axis == 2 then
        pu, pv, u0, u1, v0, v1 = 1, 3, mn[1], mx[1], mn[3], mx[3]
      else
        local l = lateral(axis)
        pu, pv, u0, u1, v0, v1 = l, 2, mn[l], mx[l], mn[2] + t, mx[2] - t
        if axis == 3 then u0, u1 = mn[l] + t, mx[l] - t end
      end
      for _, p in ipairs(slab_pieces(u0, u1, v0, v1, holes)) do
        local bmn, bmx = {}, {}
        bmn[axis], bmx[axis] = a0, a0 + t
        bmn[pu], bmx[pu] = p[1], p[2]
        bmn[pv], bmx[pv] = p[3], p[4]
        boxes[#boxes + 1] = { bmn, bmx, room = r.id }
      end
    end
  end
  return boxes
end

-- crates against door-less walls of larger rooms (render + collision), never
-- over a hole in the floor
function M.debris(rng, rooms, doors, kit, origin)
  local out = {}
  for _, r in ipairs(rooms) do
    if r.class >= 2 and r.kind ~= "shaft" then
      local mn, mx = room_box(r, kit, origin)
      local pits = face_holes(r, doors, rooms, kit, origin, 2, -1)
      for _, f in ipairs({ "+x", "-x", "+z", "-z" }) do
        if not r.faces[f] and rng:int(1, 100) <= 50 and #out < kit.debris * #rooms then
          local s = r.class >= (kit.big or 4) and 5.0 or 1.2
          local c = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall, (mn[3] + mx[3]) / 2 }
          local axis = f:sub(2, 2) == "x" and 1 or 3
          local edge = f:sub(1, 1) == "+" and mx[axis] - kit.wall - s or mn[axis] + kit.wall
          local bmn = { c[1] - s / 2, c[2], c[3] - s / 2 }
          bmn[axis] = edge
          local clear = true
          for _, h in ipairs(pits) do
            if bmn[1] < h[2] + 2 and bmn[1] + s > h[1] - 2 and bmn[3] < h[4] + 2 and bmn[3] + s > h[3] - 2 then
              clear = false
            end
          end
          if clear then out[#out + 1] = { bmn, { bmn[1] + s, bmn[2] + s, bmn[3] + s }, room = r.id } end
        end
      end
    end
  end
  return out
end

-- loot slots: vault 2 (+ the Echo spot), side rooms and wings 1, halls 0..1,
-- shafts none
function M.slots(rng, rooms, kit, origin, seed)
  local out = {}
  for _, r in ipairs(rooms) do
    local n = 0
    if r.kind == "vault" then n = 2
    elseif r.kind == "side" or r.kind == "wing" then n = 1
    elseif r.kind == "hall" then n = rng:int(0, 1) end
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
      -- off-centre so wall-centre crates never hide it, and (add-tractor-beam)
      -- a quarter of the hall in from two walls, so the Villa can hover over it
      r.echo_pos = { (mn[1] + mx[1]) / 2 + (mx[1] - mn[1]) / 4, mn[2] + kit.wall + 0.8, (mn[3] + mx[3]) / 2 + (mx[3] - mn[3]) / 4 }
    end
  end
  return out
end

-- Exterior solids around the rooms: hull spines on ships, trusses on
-- stations, towers standing on and hanging below a city. Each touches a room
-- face but never a door (door faces lead into the neighbouring room's cells).
function M.solids(rng, rooms, kit, grid, origin)
  local out = {}
  local s = kit.solids
  if not s or not grid then return out end
  local n = rng:int(s.min, s.max)
  for _ = 1, n * 6 do
    if #out >= n then break end
    local r = rooms[rng:int(1, #rooms)]
    local dir = DIRS[rng:int(1, 6)]
    local w = rng:int(s.w[1], s.w[2])
    local size = { w, rng:int(s.h[1], s.h[2]), rng:int(s.w[1], s.w[2]) }
    if dir.axis ~= 2 and s.kind == "spine" then size = { size[2], w, size[3] } end
    local cell = {}
    for a = 1, 3 do
      if a == dir.axis then cell[a] = dir.sign > 0 and r.cell[a] + r.size[a] or r.cell[a] - size[a]
      else cell[a] = r.cell[a] + rng:int(1 - size[a], r.size[a] - 1) end
    end
    if grid:free(cell[1], cell[2], cell[3], size[1], size[2], size[3]) then
      grid:place(cell[1], cell[2], cell[3], size[1], size[2], size[3], 7777)
      local mn, mx = {}, {}
      for a = 1, 3 do
        mn[a] = origin[a] + cell[a] * kit.cell
        mx[a] = mn[a] + size[a] * kit.cell
      end
      out[#out + 1] = { mn, mx, kind = s.kind, room = r.id }
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

local function layout_hash(rooms, doors, solids)
  local parts = {}
  for _, r in ipairs(rooms) do
    parts[#parts + 1] = string.format("r%d:%d:%d,%d,%d:%d,%d,%d", r.id, r.class, r.cell[1], r.cell[2], r.cell[3],
      r.size[1], r.size[2], r.size[3])
  end
  for _, d in ipairs(doors) do parts[#parts + 1] = string.format("d%d-%d:%d:%d", d.a, d.b, d.class, d.axis) end
  for _, s in ipairs(solids or {}) do parts[#parts + 1] = string.format("s%g,%g,%g", s[1][1], s[1][2], s[1][3]) end
  return saucer.hash64(table.concat(parts, ";"))
end

M.layout_hash = layout_hash

local function finish(seed, kit, rooms, doors, slots, reach, rng, grid, origin)
  local solids = rng and M.solids(rng, rooms, kit, grid, origin) or {}
  local debris = rng and M.debris(rng, rooms, doors, kit, origin) or {}
  -- add-on-foot-excursions: a crawlspace, a chamber and a sealed strongroom
  -- off one hall (own rng, so the layout above is unchanged)
  local foot = rng and require("sim.footgen").generate(seed, kit, rooms, doors, grid, origin, debris) or nil
  local wall_doors = doors
  if foot then
    wall_doors = {}
    for _, d in ipairs(doors) do wall_doors[#wall_doors + 1] = d end
    for _, d in ipairs(foot.doors) do wall_doors[#wall_doors + 1] = d end
  end
  local walls = M.walls(rooms, wall_doors, kit, origin)
  if foot then
    for _, b in ipairs(foot.walls) do walls[#walls + 1] = b end
    -- the strongroom's loot: small enough for the Seat's mini beam
    slots[#slots + 1] = { id = #slots + 1, room = foot.host, pos = foot.slot_pos, max_size = 1, tier = 2, strong = true,
                          seed = saucer.seed_child(seed, "slot", #slots + 1) }
    foot.slot = #slots
  end
  return { seed = seed, kit = kit.id, rooms = rooms, doors = doors, slots = slots, walls = walls,
           debris = debris, solids = solids, foot = foot, origin = origin,
           hash = layout_hash(rooms, doors, solids), reach = reach }
end

function M.try(seed, kit, civ, origin, first_class)
  local rng = saucer.rng.new(seed)
  local rooms = M.graph(rng, kit, civ, first_class)
  local doors, grid = M.embed(rng, rooms, kit)
  if not doors then return nil, "embed failed" end
  local span, levels = M.span(rooms, kit)
  if span < (kit.min_span or 0) or levels < (kit.min_levels or 1) then return nil, "flat" end
  local slots = M.slots(rng, rooms, kit, origin, seed)
  local ok, why = M.validate(rooms, doors, slots)
  if not ok then return nil, why end
  return finish(seed, kit, rooms, doors, slots, why, rng, grid, origin)
end

-- fallback: entrance hall -> a shaft rising from its ceiling -> a duct vault
-- off the top of the shaft. Hand-placed, always valid, still three levels.
function M.fallback(seed, kit, origin)
  local big = kit.big or 4
  local e = new_room(1, big, kit, "entrance", 0)
  local sh = new_room(2, big, kit, "shaft", 1, kit.shaft or kit.rooms[big])
  local v = new_room(3, 1, kit, "vault", 2)
  local rooms = { e, sh, v }
  local dims = kit.grid or { 64, 48, 96 }
  local grid = saucer.procgen.grid_new(dims[1], dims[2], dims[3])
  e.cell = { (dims[1] - e.size[1]) // 2, 0, 2 }
  grid:place(e.cell[1], e.cell[2], e.cell[3], e.size[1], e.size[2], e.size[3], 1)
  local doors = { { a = 0, b = 1, class = e.class, axis = 3, sign = 1, lo = e.cell[1], hi = e.cell[1] + e.size[1],
                    vlo = e.cell[2], vhi = e.cell[2] + e.size[2] } }
  e.faces["-z"] = true
  local up = DIRS[5]
  local cell, door = fit(grid, e, sh, up, kit, { 0, 0, 0 })
  sh.cell = cell
  grid:place(cell[1], cell[2], cell[3], sh.size[1], sh.size[2], sh.size[3], 2)
  link(rooms, doors, e, sh, door, up)
  local side = DIRS[2]
  v.size = shape(v, v.size, side, kit)
  cell, door = fit(grid, sh, v, side, kit, { 0, sh.size[2] - v.size[2], 0 })
  v.cell = cell
  link(rooms, doors, sh, v, door, side)
  local slots = M.slots(saucer.rng.new(seed), rooms, kit, origin, seed)
  local _, reach = M.validate(rooms, doors, slots)
  local r = finish(seed, kit, rooms, doors, slots, reach, nil, nil, origin)
  r.fallback = true
  return r
end

-- add-cities: a body city (kits/city_<body>.lua) comes from sim/citygen.lua, memoized the same way
local cmemo = {}
function M.generate_city(seed, kit, civ, origin)
  local key = string.format("%s|%s|%s|%g,%g,%g", tostring(seed), kit.id, civ and civ.id or "?", origin[1], origin[2], origin[3])
  if cmemo[key] then return cmemo[key] end
  local out, why = require("sim.citygen").generate(seed, kit, civ, origin)
  if not out then error("city generation failed: " .. tostring(why)) end
  cmemo = { [key] = out }
  return out
end

-- generation is pure: memoize per (seed, kit, civ, origin, first class) so a
-- restore (which rebuilds derived data every time) does not redo the work
local memo, memo_n = {}, 0
function M.generate(seed, kit_id, civ, origin, tries, first_class)
  local ckit = kit_of(kit_id)
  if ckit.city then return M.generate_city(seed, ckit, civ, origin) end
  -- add-relic-stations: a relic's spine comes from sim/relicgen.lua (same table shape, memoized there)
  if ckit.relic then return require("sim.relicgen").generate(seed, ckit, civ, origin) end
  local key = string.format("%s|%s|%s|%g,%g,%g|%s|%s", tostring(seed), kit_id, civ and civ.id or "?", origin[1], origin[2],
    origin[3], tostring(tries), tostring(first_class))
  if not M.GRID and memo[key] then return memo[key] end
  local kit = kit_of(kit_id)
  local out
  for i = 0, (tries or M.MAX_TRIES) - 1 do
    local s = i == 0 and seed or saucer.seed_child(seed, "retry", i)
    local r = M.try(s, kit, civ, origin, first_class)
    if r then
      r.attempts = i + 1
      out = r
      break
    end
  end
  if not out then
    saucer.log.warn("ruin generation fell back to the fixed layout for seed " .. tostring(seed))
    out = M.fallback(seed, kit, origin)
  end
  if not M.GRID then
    if memo_n > 64 then memo, memo_n = {}, 0 end
    memo[key] = out
    memo_n = memo_n + 1
  end
  return out
end

-- bounds of all rooms and exterior solids, padded; used for "inside the site" checks
function M.bounds(ruin, origin, pad)
  local kit = kit_of(ruin.kit)
  local lo, hi = { 1e30, 1e30, 1e30 }, { -1e30, -1e30, -1e30 }
  local function grow(mn, mx)
    for k = 1, 3 do
      if mn[k] < lo[k] then lo[k] = mn[k] end
      if mx[k] > hi[k] then hi[k] = mx[k] end
    end
  end
  for _, r in ipairs(ruin.rooms) do grow(room_box(r, kit, origin)) end
  for _, r in ipairs(ruin.foot and ruin.foot.rooms or {}) do grow(room_box(r, kit, origin)) end
  for _, s in ipairs(ruin.solids or {}) do grow(s[1], s[2]) end
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

-- the room a world point is in (or nil)
function M.room_at(ruin, origin, pos)
  local kit = kit_of(ruin.kit)
  for _, r in ipairs(ruin.rooms) do
    local mn, mx = room_box(r, kit, origin)
    if pos[1] >= mn[1] and pos[1] <= mx[1] and pos[2] >= mn[2] and pos[2] <= mx[2] and pos[3] >= mn[3]
        and pos[3] <= mx[3] then
      return r
    end
  end
  return nil
end

return M
