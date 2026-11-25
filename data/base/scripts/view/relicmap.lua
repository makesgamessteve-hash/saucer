-- SPDX-License-Identifier: MIT
-- add-civ-dungeons §3.3: inside a relic the helm radar closes in (M.RANGE) and draws the outline of every room the
-- saucer has been in -- each room's footprint at its floor, as a dotted rectangle, the room it is in now bright, the
-- heart violet -- so a pilot can see the shape of what they explored. A view-side memory (kept per relic for the
-- session), joined with what the state remembers of a relic in normal play (add-relic-stations, plan phase 8:
-- state.relic_rooms, so the map survives a save and a reload).
local ruinm = require("sim.ruin")
local M = {}

M.RANGE = 500        -- m: the radar's range inside a relic
M.STEP = 12          -- m between the dots of an outline
M.MAX_DOTS = 700     -- dots drawn at most (nearest rooms first)
M.SEEN = { 0.35, 0.75, 0.95, 1 }
M.HERE = { 0.7, 1, 1, 1 }
M.HEART = { 0.85, 0.5, 1, 1 }

local seen = setmetatable({}, { __mode = "k" })   -- ruin -> { [room id] = true }

-- note that the saucer is in room `id` of `ruin`
function M.note(ruin, id)
  if not (ruin and id) then return end
  local s = seen[ruin]
  if not s then s = {} seen[ruin] = s end
  s[id] = true
end

-- the rooms of `ruin` the saucer has been in, sorted (plus `extra`, the room ids the state remembers)
function M.visited(ruin, extra)
  local set, out = {}, {}
  for id in pairs(seen[ruin] or {}) do set[id] = true end
  for _, id in ipairs(extra or {}) do if ruin.rooms[id] then set[id] = true end end
  for id in pairs(set) do out[#out + 1] = id end
  table.sort(out)
  return out
end

function M.forget() seen = setmetatable({}, { __mode = "k" }) end

-- the relic and room player p's saucer is in -> ruin, room id, site (nil outside every relic)
function M.inside(state, p)
  if not (p and p.ship and p.ship.pos and state.sector) then return nil end
  local relicv = require("view.relic")
  local i, r, _, set = relicv.near_relic(state, p.ship.pos)
  if not i then return nil end
  local j = relicv.room_index(set, p.ship.pos)
  if not j then return nil end
  return r, j, i
end

-- the dots of the outlines of the visited rooms of `ruin` (world positions) -> { { pos, color } ... }, nearest rooms
-- first, at most M.MAX_DOTS
function M.dots(ruin, here, from, extra)
  local kit = ruinm.kit_of(ruin.kit)
  local rooms = {}
  for _, id in ipairs(M.visited(ruin, extra)) do
    local mn, mx = ruinm.room_box(ruin.rooms[id], kit, ruin.origin)
    local c = { (mn[1] + mx[1]) / 2, mn[2], (mn[3] + mx[3]) / 2 }
    local d = from and ((c[1] - from[1]) ^ 2 + (c[2] - from[2]) ^ 2 + (c[3] - from[3]) ^ 2) or 0
    rooms[#rooms + 1] = { id = id, mn = mn, mx = mx, d = d }
  end
  table.sort(rooms, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.id < b.id end)
  local out = {}
  for _, rm in ipairs(rooms) do
    local color = (rm.id == here and M.HERE) or (rm.id == ruin.relic.core and M.HEART) or M.SEEN
    local y = rm.mn[2] + kit.wall
    local x0, x1, z0, z1 = rm.mn[1] + kit.wall, rm.mx[1] - kit.wall, rm.mn[3] + kit.wall, rm.mx[3] - kit.wall
    local nx = math.max(1, math.floor((x1 - x0) / M.STEP + 0.5))
    local nz = math.max(1, math.floor((z1 - z0) / M.STEP + 0.5))
    for k = 0, nx - 1 do
      local x = x0 + (x1 - x0) * k / nx
      out[#out + 1] = { pos = { x, y, z0 }, color = color }
      out[#out + 1] = { pos = { x1 - (x - x0), y, z1 }, color = color }
    end
    for k = 0, nz - 1 do
      local z = z0 + (z1 - z0) * k / nz
      out[#out + 1] = { pos = { x1, y, z }, color = color }
      out[#out + 1] = { pos = { x0, y, z1 - (z - z0) }, color = color }
    end
    if #out >= M.MAX_DOTS then
      for k = #out, M.MAX_DOTS + 1, -1 do out[k] = nil end
      break
    end
  end
  return out
end

return M
