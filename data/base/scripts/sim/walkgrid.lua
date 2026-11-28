-- SPDX-License-Identifier: MIT
-- A 0.25 m walk raster of the Villa (OpenSpec add-home-layout). Flood-fill
-- from the stair foot must still reach every Use station, door and the hatch
-- after a placement. Autopilot can also path on this raster when the layout
-- has overrides. Pure functions of a layout plus extra solids.
local avatar = require("sim.avatar")
local M = {}

M.CELL = 0.25

local function overlap(x, z, r, box)
  local cx = x < box[1] and box[1] or (x > box[3] and box[3] or x)
  local cz = z < box[2] and box[2] or (z > box[4] and box[4] or z)
  local dx, dz = x - cx, z - cz
  return dx * dx + dz * dz < r * r
end

local function blocked_at(L, d, x, z, extra)
  return avatar.blocked(L, d, x, z, extra, avatar.in_stairs(L, x, z))
end

-- build a per-deck occupancy grid. each deck: { origin, n, open[i] = bool }
-- index i = (iz-1)*n + ix, ix/iz 1-based.
function M.build(L, extra)
  extra = extra or {}
  local decks = {}
  for d, deck in ipairs(L.decks) do
    local R = deck.radius
    local n = math.floor(2 * R / M.CELL + 0.5)
    if n < 4 then n = 4 end
    local origin = -n * M.CELL / 2
    local open = {}
    for iz = 1, n do
      local z = origin + (iz - 0.5) * M.CELL
      for ix = 1, n do
        local x = origin + (ix - 0.5) * M.CELL
        open[(iz - 1) * n + ix] = not blocked_at(L, d, x, z, extra)
      end
    end
    decks[d] = { origin = origin, n = n, open = open, floor = deck.floor, radius = R }
  end
  return decks
end

function M.cell_of(g, x, z)
  local ix = math.floor((x - g.origin) / M.CELL) + 1
  local iz = math.floor((z - g.origin) / M.CELL) + 1
  if ix < 1 or iz < 1 or ix > g.n or iz > g.n then return nil end
  return (iz - 1) * g.n + ix, ix, iz
end

function M.pos_of(g, ix, iz)
  return g.origin + (ix - 0.5) * M.CELL, g.origin + (iz - 0.5) * M.CELL
end

local function neighbors(n, i)
  local ix = ((i - 1) % n) + 1
  local iz = math.floor((i - 1) / n) + 1
  local out = {}
  for dz = -1, 1 do
    for dx = -1, 1 do
      if dx ~= 0 or dz ~= 0 then
        local x, z = ix + dx, iz + dz
        if x >= 1 and z >= 1 and x <= n and z <= n then
          out[#out + 1] = (z - 1) * n + x
        end
      end
    end
  end
  return out
end

-- cells on the main stair flight, used as a vertical link between decks 1 and 2
local function stair_cells(L, g)
  local st = L.stairs
  if not st or not g then return {} end
  local list = {}
  local x0, x1 = math.min(st.low, st.high), math.max(st.low, st.high)
  for iz = 1, g.n do
    for ix = 1, g.n do
      local x, z = M.pos_of(g, ix, iz)
      if x >= x0 and x <= x1 and z >= st.z0 and z <= st.z1 then
        list[#list + 1] = (iz - 1) * g.n + ix
      end
    end
  end
  return list
end

local function belly_cells(L, g)
  local b = L.belly_stairs
  if not b or not g then return {} end
  local list = {}
  local x0, x1 = math.min(b.low, b.high), math.max(b.low, b.high)
  for iz = 1, g.n do
    for ix = 1, g.n do
      local x, z = M.pos_of(g, ix, iz)
      if x >= x0 and x <= x1 and z >= b.z0 and z <= b.z1 then
        list[#list + 1] = (iz - 1) * g.n + ix
      end
    end
  end
  return list
end

-- the cell on another deck with the same hull-local (x, z), or nil

-- open cells of a flight on a deck: { { i, x, z }, ... }
local function flight_open(cells, g)
  local out = {}
  for _, i in ipairs(cells) do
    if g.open[i] then
      local ix = ((i - 1) % g.n) + 1
      local iz = math.floor((i - 1) / g.n) + 1
      local x, z = M.pos_of(g, ix, iz)
      out[#out + 1] = { i = i, x = x, z = z }
    end
  end
  return out
end

-- a stair is a portal: any open cell on one deck's flight links to the
-- nearest open cell on the other (grids have different radii, so the same
-- (x, z) often does not exist on both decks).
local PORTAL_RANGE2 = 5 * 5
local function portals_between(cells_a, ga, da, cells_b, gb, db)
  local map = {} -- "d:i" -> { { od, oi }, ... }
  local function add(d, i, od, oi)
    local k = d .. ":" .. i
    map[k] = map[k] or {}
    map[k][#map[k] + 1] = { od, oi }
  end
  local A, B = flight_open(cells_a, ga), flight_open(cells_b, gb)
  for _, p in ipairs(A) do
    local best, bd
    for _, q in ipairs(B) do
      local dd = (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2
      if dd < PORTAL_RANGE2 and (not bd or dd < bd) then best, bd = q, dd end
    end
    if best then add(da, p.i, db, best.i); add(db, best.i, da, p.i) end
  end
  for _, q in ipairs(B) do
    local best, bd
    for _, p in ipairs(A) do
      local dd = (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2
      if dd < PORTAL_RANGE2 and (not bd or dd < bd) then best, bd = p, dd end
    end
    if best then add(db, q.i, da, best.i); add(da, best.i, db, q.i) end
  end
  return map
end

local function all_portals(L, grids)
  local map = {}
  if grids[1] and grids[2] then
    for k, v in pairs(portals_between(stair_cells(L, grids[1]), grids[1], 1, stair_cells(L, grids[2]), grids[2], 2)) do
      map[k] = v
    end
  end
  if grids[2] and grids[3] then
    for k, v in pairs(portals_between(belly_cells(L, grids[2]), grids[2], 2, belly_cells(L, grids[3]), grids[3], 3)) do
      map[k] = map[k] or {}
      for _, e in ipairs(v) do map[k][#map[k] + 1] = e end
    end
  end
  return map
end

local function same_xz(grids, from_d, i, to_d)
  local g, og = grids[from_d], grids[to_d]
  if not g or not og then return nil end
  local ix = ((i - 1) % g.n) + 1
  local iz = math.floor((i - 1) / g.n) + 1
  local x, z = M.pos_of(g, ix, iz)
  return M.cell_of(og, x, z)
end

-- vertical neighbors of cell i on deck d (the two stair flights)
function M.vertical(L, grids, d, i)
  local out = {}
  if d == 1 or d == 2 then
    for _, j in ipairs(stair_cells(L, grids[d])) do
      if j == i then
        local od = d == 1 and 2 or 1
        local ni = same_xz(grids, d, i, od)
        if ni then out[#out + 1] = { od, ni } end
        break
      end
    end
  end
  if d == 2 or d == 3 then
    for _, j in ipairs(belly_cells(L, grids[d])) do
      if j == i then
        local od = d == 2 and 3 or 2
        local ni = same_xz(grids, d, i, od)
        if ni then out[#out + 1] = { od, ni } end
        break
      end
    end
  end
  return out
end

-- flood from a hull-local point on a deck; returns a set of reached keys "d:i"
function M.flood(L, extra, src)
  local grids = M.build(L, extra)
  local seen, q, head = {}, {}, 1
  local function push(d, i)
    local k = d .. ":" .. i
    if seen[k] then return end
    local g = grids[d]
    if not g or not g.open[i] then return end
    seen[k] = true
    q[#q + 1] = { d, i }
  end
  if src then
    for _, s in ipairs(src) do
      local g = grids[s.deck]
      local i = g and M.cell_of(g, s.x, s.z)
      if i then push(s.deck, i) end
    end
  end
  local portals = all_portals(L, grids)
  while head <= #q do
    local d, i = q[head][1], q[head][2]
    head = head + 1
    local g = grids[d]
    for _, n in ipairs(neighbors(g.n, i)) do push(d, n) end
    for _, e in ipairs(portals[d .. ":" .. i] or {}) do push(e[1], e[2]) end
  end
  return seen, grids
end

function M.stair_source(L)
  local n = L.nav and L.nav.nodes and (L.nav.nodes.stair_foot or L.nav.nodes.stair_low)
  if n then return { { deck = 2, x = n[1], z = n[3] } } end
  local st = L.stairs
  return { { deck = 2, x = math.min(st.low, st.high) + 0.5, z = (st.z0 + st.z1) / 2 } }
end

function M.reached(seen, grids, deck, x, z)
  local g = grids[deck]
  if not g then return false end
  local i = M.cell_of(g, x, z)
  if i and seen[deck .. ":" .. i] then return true end
  -- a station sitting inside a solid (the bench itself) uses the nearest open cell
  if not i then return false end
  local n = g.n
  local ix = ((i - 1) % n) + 1
  local iz = math.floor((i - 1) / n) + 1
  for r = 1, 8 do
    for dz = -r, r do
      for dx = -r, r do
        local x2, z2 = ix + dx, iz + dz
        if x2 >= 1 and z2 >= 1 and x2 <= n and z2 <= n then
          local j = (z2 - 1) * n + x2
          if g.open[j] and seen[deck .. ":" .. j] then return true end
        end
      end
    end
  end
  return false
end

-- can every Use station, door and the hatch still be reached? -> ok, why
function M.stations_ok(L, extra)
  local src = M.stair_source(L)
  local seen, grids = M.flood(L, extra, src)
  for _, st in ipairs(L.stations or {}) do
    if not M.reached(seen, grids, st.deck, st.pos[1], st.pos[3]) then
      return false, "it would block the way to the " .. (st.room or st.kind or "station"):lower()
    end
  end
  for _, door in ipairs(L.doors or {}) do
    local b = door.box
    local x, z = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
    if not M.reached(seen, grids, door.deck, x, z) then
      return false, "it would block the " .. (door.room or "door"):lower() .. " door"
    end
  end
  local hatch = L.hatch_door and (L.nav and L.nav.nodes and L.nav.nodes.hatch)
  if hatch then
    local d = avatar.deck_of(L, { pos = hatch })
    if not M.reached(seen, grids, d, hatch[1], hatch[3]) then
      return false, "it would block the hatch"
    end
  end
  return true
end

-- shortest path of points {x,y,z} between two hull-local positions, or nil
function M.path(L, extra, from, to)
  local src = { { deck = from.deck, x = from.x, z = from.z } }
  local seen, grids = M.flood(L, extra, src)
  local g = grids[to.deck]
  if not g then return nil end
  local goal = M.cell_of(g, to.x, to.z)
  if not goal or not seen[to.deck .. ":" .. goal] then
    -- nearest reached cell to the target
    local best, bd
    for k in pairs(seen) do
      local d, i = k:match("^(%d+):(%d+)$")
      d, i = tonumber(d), tonumber(i)
      if d == to.deck then
        local ix = ((i - 1) % g.n) + 1
        local iz = math.floor((i - 1) / g.n) + 1
        local x, z = M.pos_of(g, ix, iz)
        local dd = (x - to.x) ^ 2 + (z - to.z) ^ 2
        if not bd or dd < bd then best, bd = i, dd end
      end
    end
    goal = best
  end
  if not goal then return nil end
  -- BFS parents were not stored; re-walk a parent BFS just for this path
  local parent, q, head = {}, { { from.deck, M.cell_of(grids[from.deck], from.x, from.z) } }, 1
  if not q[1][2] then return nil end
  parent[from.deck .. ":" .. q[1][2]] = false
  local portals = all_portals(L, grids)
  local found
  while head <= #q do
    local d, i = q[head][1], q[head][2]
    head = head + 1
    if d == to.deck and i == goal then found = true; break end
    local g2 = grids[d]
    local function try(nd, ni)
      if not ni then return end
      local k = nd .. ":" .. ni
      if parent[k] ~= nil then return end
      if not grids[nd] or not grids[nd].open[ni] then return end
      parent[k] = { d, i }
      q[#q + 1] = { nd, ni }
    end
    for _, n in ipairs(neighbors(g2.n, i)) do try(d, n) end
    for _, e in ipairs(portals[d .. ":" .. i] or {}) do try(e[1], e[2]) end
  end
  if not found then return nil end
  local path, d, i = {}, to.deck, goal
  while d do
    local gg = grids[d]
    local ix = ((i - 1) % gg.n) + 1
    local iz = math.floor((i - 1) / gg.n) + 1
    local x, z = M.pos_of(gg, ix, iz)
    table.insert(path, 1, { x, gg.floor, z })
    local p = parent[d .. ":" .. i]
    if not p then break end
    d, i = p[1], p[2]
  end
  return path
end

return M
