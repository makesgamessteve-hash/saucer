-- SPDX-License-Identifier: MIT
-- The fold (concept §3.1-3.2, milestone 2): when the Villa reconfigures into
-- the Seat, every room packs itself away into fold-space one after another,
-- farthest from the player first, and only then does the hull shrink about
-- the player's eye. Unfolding plays it backwards: the hull grows first, then
-- the rooms unpack, nearest first. Pure functions of the ship's morph record,
-- so the sim, the renderer and the tests all agree on what is packed.
local configs = require("sim.config")
local avatar = require("sim.avatar")
local M = {}

M.ROOM_PHASE = 0.5   -- share of the transition the rooms take
M.WINDOW = 0.22      -- share of the transition one room takes to pack
M.FLAT = 0.5         -- packing: first flatten (0..FLAT), then slide into fold-space

-- fold groups: every layout room (one entry per deck/name), then the decks themselves
function M.groups(L)
  local out, seen = {}, {}
  for _, r in ipairs(L.rooms) do
    local key = r.deck .. ":" .. r.name
    if not seen[key] then
      seen[key] = true
      local b = r.box
      local R = L.decks[r.deck].radius
      local x0, z0 = math.max(b[1], -R), math.max(b[2], -R)
      local x1, z1 = math.min(b[3], R), math.min(b[4], R)
      out[#out + 1] = { id = key, name = r.name, deck = r.deck, box = { x0, z0, x1, z1 },
                        anchor = { (x0 + x1) / 2, L.decks[r.deck].floor, (z0 + z1) / 2 } }
    end
  end
  for d, deck in ipairs(L.decks) do
    out[#out + 1] = { id = d .. ":deck", name = deck.name, deck = d, box = { -deck.radius, -deck.radius, deck.radius, deck.radius },
                      anchor = { 0, deck.floor, 0 }, shell = true }
  end
  return out
end

-- which group a furniture piece (or any hull-local x, z on a deck) belongs to
function M.group_of(L, deck, x, z)
  for _, r in ipairs(L.rooms) do
    local b = r.box
    if r.deck == deck and x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4] then return deck .. ":" .. r.name end
  end
  return deck .. ":deck"
end

local function has_rooms(size) return configs.get(size).interior and true or false end

-- the player's eye in the hull-local frame of the config that has rooms
function M.eye_local(ship)
  local m = ship.morph
  local base_pos, base_yaw = ship.pos, ship.yaw
  if has_rooms(m.from) and not has_rooms(ship.size) then base_pos, base_yaw = m.pos, m.yaw end
  local d = { m.eye[1] - base_pos[1], m.eye[2] - base_pos[2], m.eye[3] - base_pos[3] }
  return avatar.rot(-base_yaw, d)
end

-- order in which the groups pack (farthest from the eye first); decks go last
function M.order(L, eye)
  local list = {}
  for i, g in ipairs(M.groups(L)) do
    local dx, dz = g.anchor[1] - eye[1], g.anchor[3] - eye[3]
    local dy = (g.anchor[2] - eye[2]) * 2
    list[#list + 1] = { g = g, d = g.shell and -1 or dx * dx + dy * dy + dz * dz, i = i }
  end
  table.sort(list, function(a, b)
    if a.d ~= b.d then return a.d > b.d end
    return a.i < b.i
  end)
  local out = {}
  for k, e in ipairs(list) do out[k] = e.g end
  return out
end

local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

-- amounts(ship, L) -> { [group id] = packed 0..1 }, ordered group list (or nil)
-- 0 = the room is out and usable, 1 = it is folded away.
function M.amounts(ship, L)
  L = L or avatar.layout()
  local out = {}
  local groups = M.groups(L)
  if not ship.morph then
    local v = has_rooms(ship.size) and 0 or 1
    for _, g in ipairs(groups) do out[g.id] = v end
    return out
  end
  local m = ship.morph
  local from_rooms, to_rooms = has_rooms(m.from), has_rooms(ship.size)
  if from_rooms == to_rooms then
    for _, g in ipairs(groups) do out[g.id] = from_rooms and 0 or 1 end
    return out
  end
  local order = M.order(L, M.eye_local(ship))
  local n = #order
  local t = 1 - ship.t_left / m.total
  local span = M.ROOM_PHASE - M.WINDOW
  for k, g in ipairs(order) do
    local start = n > 1 and (k - 1) * span / (n - 1) or 0
    if from_rooms then
      out[g.id] = clamp01((t - start) / M.WINDOW)
    else
      -- unfold: the hull grows in the first half, then rooms unpack nearest first
      local j = n - k
      local s2 = M.ROOM_PHASE + (n > 1 and j * span / (n - 1) or 0)
      out[g.id] = 1 - clamp01((t - s2) / M.WINDOW)
    end
  end
  return out, order
end

-- are the rooms of this saucer out (Villa, not reconfiguring)?
function M.rooms_out(ship)
  return has_rooms(ship.size) and not ship.morph
end

-- How to draw one group at packed amount a: hull-local position of its
-- anchor and a per-axis scale. It first folds flat onto its floor, then slides
-- toward the fold point (the player's eye at floor level) and shrinks to nothing.
function M.transform(g, a, fold_point)
  local anchor = g.anchor
  if a <= 0 then return { anchor[1], anchor[2], anchor[3] }, { 1, 1, 1 } end
  local flat = clamp01(a / M.FLAT)
  local slide = clamp01((a - M.FLAT) / (1 - M.FLAT))
  local sy = 1 - 0.92 * flat
  local sxz = 1 - slide
  local fp = fold_point or { 0, anchor[2], 0 }
  local pos = {
    anchor[1] + (fp[1] - anchor[1]) * slide,
    anchor[2] + (fp[2] - anchor[2]) * slide,
    anchor[3] + (fp[3] - anchor[3]) * slide,
  }
  return pos, { sxz, sy * (1 - slide), sxz }
end

return M
