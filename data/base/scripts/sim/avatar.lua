-- SPDX-License-Identifier: MIT
-- The player's body inside their own saucer (concept §3.3, spec saucer-interior).
-- Positions are hull-local (feet), so the body rides along while the saucer
-- flies. Collision is 2D per deck against the layout in saucer/interior.lua:
-- the deck edge is a circle, furniture is boxes and circles, and a straight
-- stair joins the decks. Pure functions over plain tables: deterministic and
-- snapshot friendly.
local data = require("lib.data")
local vec = require("lib.vec")
local sm = saucer.math
local M = {}

function M.layout() return data.load("saucer/interior.lua") end

function M.new(L, pos, yaw)
  L = L or M.layout()
  local p = pos or L.spawn.pos
  return { pos = { p[1], p[2], p[3] }, yaw = yaw or L.spawn.yaw or 0, pitch = 0 }
end

-- hull-local -> world offset for a saucer yaw (same rotation as meshes and the renderer)
function M.rot(yaw, v)
  local c, s = sm.cos(yaw), sm.sin(yaw)
  return { v[1] * c + v[3] * s, v[2], -v[1] * s + v[3] * c }
end

local function in_stairs(L, x, z)
  local st = L.stairs
  return x >= st.low and x <= st.high and z >= st.z0 and z <= st.z1
end
M.in_stairs = in_stairs

local function mid(L) return (L.decks[1].floor + L.decks[2].floor) / 2 end

-- floor height and deck index under (x, z) for a body currently at height y
function M.floor_at(L, x, z, y)
  if in_stairs(L, x, z) then
    local st, lo, hi = L.stairs, L.decks[2].floor, L.decks[1].floor
    local f = lo + (hi - lo) * (x - st.low) / (st.high - st.low)
    return f, f > mid(L) and 1 or 2
  end
  local d = y > mid(L) and 1 or 2
  return L.decks[d].floor, d
end

function M.deck_of(L, body)
  local _, d = M.floor_at(L, body.pos[1], body.pos[3], body.pos[2])
  return d
end

local function box_hit(b, x, z, r)
  local cx = vec.clamp(x, b[1], b[3])
  local cz = vec.clamp(z, b[2], b[4])
  local dx, dz = x - cx, z - cz
  return dx * dx + dz * dz < r * r
end

-- is a body of the layout's radius at (x, z) on deck d blocked? `extra` is an
-- optional list of { deck =, box = } solids (closed doors).
function M.blocked(L, d, x, z, extra)
  local r = L.body_radius
  local edge = L.decks[d].radius - r
  if x * x + z * z > edge * edge then return true end
  for _, e in ipairs(extra or {}) do
    if e.deck == d and box_hit(e.box, x, z, r) then return true end
  end
  for _, f in ipairs(L.furniture) do
    if f.deck == d and f.solid ~= false then
      if f.circle then
        local c = f.circle
        local dx, dz = x - c[1], z - c[2]
        local rr = c[3] + r
        if dx * dx + dz * dz < rr * rr then return true end
      elseif box_hit(f.box, x, z, r) then
        return true
      end
    end
  end
  return false
end

-- try one horizontal move; refuses walls and floor jumps bigger than a step
local function try(L, body, x, z, extra)
  local y = body.pos[2]
  local f, d = M.floor_at(L, x, z, y)
  if math.abs(f - y) > L.step then return false end
  local _, cur = M.floor_at(L, body.pos[1], body.pos[3], y)
  if M.blocked(L, cur, x, z, extra) or M.blocked(L, d, x, z, extra) then return false end
  body.pos = { x, f, z }
  return true
end

-- heading offset from an XR head direction (quantized aim triple), or 0
function M.head_yaw(aim)
  if not aim then return 0 end
  local ax, az = aim[1] or 0, aim[3] or 0
  if ax == 0 and az == 0 then return 0 end
  return sm.atan2(ax, az)
end

-- step(body, input, dt, L, extra) ; input = { move_x, move_z, turn, look, run, aim }
-- extra: closed doors (see M.blocked). Returns the number of blocked axes (0..2)
function M.step(body, input, dt, L, extra)
  L = L or M.layout()
  body.yaw = sm.wrap(body.yaw - (input.turn or 0) * L.turn * dt)
  body.pitch = vec.clamp(body.pitch + (input.look or 0) * L.look * dt, -L.pitch_limit, L.pitch_limit)
  local mx, mz = input.move_x or 0, input.move_z or 0
  if mx == 0 and mz == 0 then return 0 end
  local heading = body.yaw + M.head_yaw(input.aim)
  local f, r = vec.fwd(heading), vec.right(heading)
  local speed = L.walk_speed * (input.run and L.run_factor or 1)
  local dx = (f[1] * mz + r[1] * mx) * speed * dt
  local dz = (f[3] * mz + r[3] * mx) * speed * dt
  local blocked = 0
  if dx ~= 0 and not try(L, body, body.pos[1] + dx, body.pos[3], extra) then blocked = blocked + 1 end
  if dz ~= 0 and not try(L, body, body.pos[1], body.pos[3] + dz, extra) then blocked = blocked + 1 end
  return blocked
end

function M.near_helm(L, body)
  local h = L.helm
  local dx, dz = body.pos[1] - h.seat[1], body.pos[3] - h.seat[3]
  return M.deck_of(L, body) == 1 and dx * dx + dz * dz <= h.use_radius * h.use_radius
end

-- name of the room the body stands in (HUD), or the deck name
function M.room(L, body)
  local d = M.deck_of(L, body)
  local x, z = body.pos[1], body.pos[3]
  for _, r in ipairs(L.rooms) do
    local b = r.box
    if r.deck == d and x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4] then return r.name end
  end
  return L.decks[d].name
end

-- the Use spot (layout station) within reach of the body, nearest first, or nil
function M.station(L, body)
  local d = M.deck_of(L, body)
  local best, bd
  for _, st in ipairs(L.stations or {}) do
    local dx, dz = body.pos[1] - st.pos[1], body.pos[3] - st.pos[3]
    local dd = dx * dx + dz * dz
    if st.deck == d and dd <= st.radius * st.radius and (not bd or dd < bd) then best, bd = st, dd end
  end
  return best
end

function M.station_by_id(L, id)
  for _, st in ipairs(L.stations or {}) do
    if st.id == id then return st end
  end
  return nil
end

-- shortest walk (fewest links) between two nav nodes -> list of points, or nil
function M.nav_path(L, from, to)
  local nodes, adj = L.nav.nodes, {}
  for _, l in ipairs(L.nav.links) do
    adj[l[1]] = adj[l[1]] or {}
    adj[l[2]] = adj[l[2]] or {}
    table.insert(adj[l[1]], l[2])
    table.insert(adj[l[2]], l[1])
  end
  if not nodes[from] or not nodes[to] then return nil end
  local prev, queue, head = { [from] = from }, { from }, 1
  while head <= #queue do
    local n = queue[head]
    head = head + 1
    if n == to then break end
    for _, m in ipairs(adj[n] or {}) do
      if not prev[m] then
        prev[m] = n
        queue[#queue + 1] = m
      end
    end
  end
  if not prev[to] then return nil end
  local path, n = {}, to
  while n ~= from do
    table.insert(path, 1, nodes[n])
    n = prev[n]
  end
  table.insert(path, 1, nodes[from])
  return path
end

-- nearest nav node to a body (same deck)
function M.nav_nearest(L, body)
  local d = M.deck_of(L, body)
  local best, bd
  for _, name in ipairs(M.sorted_keys(L.nav.nodes)) do
    local q = L.nav.nodes[name]
    local qd = q[2] > (L.decks[1].floor + L.decks[2].floor) / 2 and 1 or 2
    local dx, dz = body.pos[1] - q[1], body.pos[3] - q[3]
    local dd = dx * dx + dz * dz
    if qd == d and (not bd or dd < bd) then best, bd = name, dd end
  end
  return best
end

function M.sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

-- eye position (hull-local)
function M.eye(L, body) return { body.pos[1], body.pos[2] + L.eye, body.pos[3] } end

return M
