-- SPDX-License-Identifier: MIT
-- Milestone 2: the fold is a real packing, not a uniform scale. Shrinking,
-- the Villa keeps its full hull while its rooms pack away one after another
-- (farthest from the pilot first: flatten, then slide into fold-space),
-- then the hull shrinks about the pilot's eye into the Seat. Growing reverses
-- it: the hull grows first, then rooms unpack nearest first.
local T = saucer.test
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local fold = require("sim.fold")
local game = require("sim.game")
local render = require("view.render")
local L = avatar.layout()
local get = function() return T.state().players[1] end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.walk_to(T, 1, get, "kitchen"), "walked to the kitchen")
T.assert(fold.rooms_out(get().ship), "rooms are out in the Villa")

local function count(map, lo, hi)
  local n = 0
  for _, a in pairs(map) do if a >= lo and a <= hi then n = n + 1 end end
  return n
end
local groups = fold.groups(L)
local eye0 = game.viewpoint(get())

T.press(1, "shrink")
T.wait(1)
local s = get().ship
T.assert(s.morph and s.size == 2, "folding toward the Seat")
local amounts, order = fold.amounts(s, L)
local first, last = order[1], order[#order]
T.assert(last.shell, "the deck shells pack last")
-- the first room to pack is the one farthest from the pilot (who stands in the kitchen)
T.assert(first.id ~= "1:Kitchen", "the kitchen around the pilot is not first to go")

local saw_partial, saw_mixed, hull_full_while_packing = false, false, true
local seen_done = {}
local done_order = {}
for _ = 1, 120 do
  T.wait(1)
  s = get().ship
  if not s.morph then break end
  amounts = fold.amounts(s, L)
  local packed, out = count(amounts, 1, 1), count(amounts, 0, 0)
  if count(amounts, 0.01, 0.99) > 0 then saw_partial = true end
  if packed > 0 and out > 0 then saw_mixed = true end
  local t = 1 - s.t_left / s.morph.total
  if t < fold.ROOM_PHASE - 0.02 and render.pose(s).scale ~= 1 then hull_full_while_packing = false end
  for id, a in pairs(amounts) do
    if a >= 1 and not seen_done[id] then seen_done[id] = true; done_order[#done_order + 1] = id end
  end
  -- the eye never moves while the rooms pack around it
  local eye = game.viewpoint(get())
  for k = 1, 3 do T.assert(math.abs(eye[k] - eye0[k]) < 1e-6, "eye stays put") end
end
T.assert(saw_partial, "rooms pass through partly packed states")
T.assert(saw_mixed, "some rooms are packed while others are still out (staggered)")
T.assert(hull_full_while_packing, "the hull holds full size while the rooms pack")
T.assert(#done_order == #groups, "every room packed away")
T.assert(done_order[1] == first.id, "the farthest room finished first")
T.assert(not get().ship.morph and get().ship.size == 2, "settled in the Seat")
T.assert(not fold.rooms_out(get().ship), "no rooms in the Seat")

-- the packing transform: flattened first, then slid to the fold point and gone
local g = groups[1]
local _, sc1 = fold.transform(g, 0.25, { 0, 0, 0 })
local p2, sc2 = fold.transform(g, 0.75, { 0, 0, 0 })
local _, sc3 = fold.transform(g, 1, { 0, 0, 0 })
T.assert(sc1[2] < 1 and sc1[1] == 1, "first it folds flat")
T.assert(sc2[1] < 1 and math.abs(p2[1]) < math.abs(g.anchor[1]) + 1e-9, "then it slides into fold-space")
T.assert(sc3[1] == 0, "and is gone")

-- grow back: the hull grows first, rooms unpack nearest-first afterwards
T.press(1, "grow")
T.wait(1)
s = get().ship
local _, uorder = fold.amounts(s, L)
local unpacked_first
local early_rooms_packed = true
for _ = 1, 140 do
  T.wait(1)
  s = get().ship
  if not s.morph then break end
  local a = fold.amounts(s, L)
  local t = 1 - s.t_left / s.morph.total
  if t < fold.ROOM_PHASE and count(a, 0, 0.999) > 0 then early_rooms_packed = false end
  if not unpacked_first then
    for id, v in pairs(a) do if v < 1 and not unpacked_first then unpacked_first = id end end
  end
end
T.assert(early_rooms_packed, "rooms stay packed while the hull grows")
T.assert(unpacked_first == uorder[#uorder].id, "the decks come back first, then rooms nearest first")
T.assert(fold.rooms_out(get().ship), "rooms are out again")
print(string.format("fold: %d groups, first packed %s", #groups, first.id))
