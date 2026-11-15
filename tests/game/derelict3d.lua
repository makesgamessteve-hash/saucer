-- SPDX-License-Identifier: MIT
-- Multi-level derelict traversal (OpenSpec add-true-3d-flight): fly the
-- Villa into the tutorial derelict, through floor/ceiling hatches and up or
-- down shafts to the room furthest from the entrance level, check that the
-- walls and slabs between levels hold, then fly the same route back out.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end

T.wait(30)
T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()
local r1, o1 = game.ruin(1), st.sector.sites[1].pos
local kit = ruinm.kit_of(r1.kit)

-- the target: reached through at least one hatch, as far above or below the
-- entrance floor as possible, open to a saucer no smaller than the Seat
local function hatches(id)
  local n = 0
  for _, rid in ipairs(ap.chain(r1, id)) do
    if ap.door_of(r1, rid).axis == 2 then n = n + 1 end
  end
  return n
end
local e = r1.rooms[1]
local best, gap = nil, -1
for _, r in ipairs(r1.rooms) do
  local g = math.abs(r.cell[2] - e.cell[2])
  if hatches(r.id) > 0 and r.class >= 2 and g > gap then best, gap = r, g end
end
T.assert(best ~= nil, "the derelict has a room behind a hatch")
T.assert(gap * kit.cell >= 20, "the target is levels away from the entrance: " .. gap * kit.cell .. " m")

print("target", best.id, best.kind, "gap m", gap * kit.cell, "hatches", hatches(best.id))
local ok, route = ap.enter(T, 1, get, r1, o1, best.id)
T.assert(ok, "flew through the hatches to room " .. best.id)
T.assert(ruinm.room_at(r1, o1, get().ship.pos) == best, "inside the target room")
local mn, mx = ruinm.room_box(best, kit, o1)
local c = get().ship.pos
T.assert(c[2] > mn[2] and c[2] < mx[2], "between the target's floor and ceiling")
T.assert(math.abs(c[2] - ruinm.room_box(e, kit, o1)[2]) >= 20, "on a different level from the entrance")

-- the slabs hold: lift into the ceiling and dive at the floor away from any hatch
local size = get().ship.size
local hh = require("sim.config").get(size).height / 2
local function hold(axes, n) for _ = 1, n do ap.hold(T, 1, axes) end end
local function near_hatch(p)
  for _, d in ipairs(r1.doors) do
    if d.axis == 2 and (d.a == best.id or d.b == best.id) then
      local lo1, hi1 = o1[1] + d.lo * kit.cell, o1[1] + d.hi * kit.cell
      local lo3, hi3 = o1[3] + d.lo3 * kit.cell, o1[3] + d.hi3 * kit.cell
      if p[1] > lo1 - 12 and p[1] < hi1 + 12 and p[3] > lo3 - 12 and p[3] < hi3 + 12 then return true end
    end
  end
  return false
end
print("slab check", not near_hatch(c))
if not near_hatch(c) then
  hold({ lift = 1 }, 900)
  T.assert(get().ship.pos[2] + hh <= mx[2] - kit.wall + 1e-6, "the ceiling holds")
  hold({ lift = -1 }, 1500)
  T.assert(get().ship.pos[2] - hh >= mn[2] + kit.wall - 1e-6, "the floor holds")
  T.assert(ap.fly(T, 1, get, c, 1, 1500), "back to the centre")
end

-- the same way back out, size changes and all
if get().ship.size ~= route[#route].size then ap.resize(T, 1, get, route[#route].size) end
T.assert(ap.leave(T, 1, get, route), "flew back out")
T.assert(ruinm.room_at(r1, o1, get().ship.pos) == nil, "outside the derelict")
T.assert(ap.resize(T, 1, get, 1), "back to the Villa")
local _ = vec
