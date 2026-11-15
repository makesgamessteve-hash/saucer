-- SPDX-License-Identifier: MIT
-- Deck tour on foot (concept §3.3, v0.4): kitchen and living room under the
-- glass dome, down the stairs to the bedroom, past the bathroom wall to the
-- engine room, back up and over to the helm. Checks collision on both decks.
local T = saucer.test
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local L = avatar.layout()
local get = function() return T.state().players[1] end
local function room() return avatar.room(L, get().body) end
local function deck() return avatar.deck_of(L, get().body) end
local function pause(name)
  print("tick", T.state().tick, name)
  T.wait(40)
end

-- out of bed, through the sliding bedroom door and up the stairs
T.assert(ap.wake(T, 1, get), "got up")
T.assert(room() == "Bedroom" and deck() == 2, "woke up in the bedroom")
T.assert(ap.walk_to(T, 1, get, "dome"), "walked up to the dome deck")

-- kitchen: look out over the island through the dome at space
T.assert(ap.walk_path(T, 1, get, { { 1.5, 0.6, -2.0 }, { 3.0, 0.6, -2.6 } }, 0.3, 600), "walked to the kitchen")
T.assert(room() == "Kitchen" and deck() == 1, "in the kitchen on the dome deck")
T.assert(ap.look(T, 1, get, 0.9, 0.25), "looking out over the kitchen")
pause("kitchen")

-- living room: the island and counters block, the sofa blocks
T.assert(ap.walk_path(T, 1, get, { { -1.0, 0.6, -2.0 }, { -3.2, 0.6, 1.5 } }, 0.3, 600), "walked to the living room")
T.assert(room() == "Living room", "in the living room")
T.assert(ap.look(T, 1, get, -1.9, 0.2), "looking across the living room")
pause("living")
local x0 = get().body.pos[1]
ap.hold(T, 1, {})
for _ = 1, 160 do ap.hold(T, 1, { move_z = 1 }) end
T.assert(get().body.pos[1] > -7.0 - 0.01 and get().body.pos[1] < x0, "the sofa stops the walk")

-- down the stairs to the lower deck
T.assert(ap.walk_path(T, 1, get, { { 1.0, 0.6, -3.6 }, { 4.2, 0.6, -3.6 }, { 4.2, 0.6, -5.2 },
  { 3.3, 0.6, -5.2 }, { -3.6, -3.0, -5.2 } }, 0.3, 900), "walked down the stairs")
T.assert(deck() == 2 and math.abs(get().body.pos[2] + 3.0) < 1e-6, "on the lower deck floor")

-- engine room
T.assert(ap.walk(T, 1, get, { -3.6, -3.0, -2.2 }, 0.3, 600), "walked into the engine room")
T.assert(room() == "Engine room", "in the engine room")
T.assert(ap.look(T, 1, get, 1.35, 0.15), "looking at the engine core")
pause("engine")

-- bedroom through its doorway
T.assert(ap.walk_path(T, 1, get, { { -2.0, -3.0, 0.0 }, { 2.7, -3.0, -0.4 }, { 2.7, -3.0, 1.6 }, { 1.0, -3.0, 2.0 } }, 0.3, 900),
  "walked into the bedroom")
T.assert(room() == "Bedroom", "in the bedroom")
T.assert(ap.look(T, 1, get, 0.75, -0.1), "looking at the bed")
pause("bedroom")
-- the partition wall between bedroom and bathroom blocks
for _ = 1, 120 do ap.hold(T, 1, { move_x = 0, move_z = 0, turn = 0 }) end
T.assert(ap.look(T, 1, get, -1.5708, 0), "facing the partition")
for _ = 1, 90 do ap.hold(T, 1, { move_z = 1 }) end
T.assert(get().body.pos[1] > 0.1, "the partition wall blocks")

-- back up the stairs and over to the helm
local up_ok, up_i = ap.walk_path(T, 1, get, { { 2.7, -3.0, 1.6 }, { 2.7, -3.0, -0.4 }, { 2.7, -3.0, -3.6 }, { -3.6, -3.0, -3.6 },
  { -3.6, -3.0, -5.2 }, { -2.8, -3.0, -5.2 }, { 4.2, 0.6, -5.2 }, { 4.2, 0.6, -3.6 }, { 1.0, 0.6, 2.5 },
  L.helm.stand }, 0.3, 900)
if not up_ok then local b = get().body print("stuck", up_i, b.pos[1], b.pos[2], b.pos[3]) end
T.assert(up_ok, "walked back up to the helm")
T.assert(deck() == 1, "back on the dome deck")
T.press(1, "use")
T.wait(1)
T.assert(get().mode == "helm", "took the helm")
print("tick", T.state().tick, "helm")
T.wait(20)
