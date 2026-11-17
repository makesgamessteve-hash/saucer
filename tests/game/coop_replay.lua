-- SPDX-License-Identifier: MIT
-- add-wider-dark: a short local co-op session driven only by command frames,
-- recorded as tests/replays/coop_seed42.srep (slots 4). Three players join on
-- their own slots, wake, take their helms and use the new tools; the replay
-- test then plays it back and checks the state hash every 60 ticks.
local T = saucer.test
local ap = require("sim.autopilot")
local function P(i) return function() return T.state().players[i] end end

for i = 2, 3 do
  T.press(i, "use")
  T.wait(1)
  T.assert(#T.state().players == i, "P" .. i .. " joined")
end
for i = 1, 3 do T.assert(ap.wake(T, i, P(i)), "P" .. i .. " got up") end
for i = 1, 3 do T.assert(ap.take_helm(T, i, P(i)), "P" .. i .. " at the helm") end
T.axis(2, "lift", 1)
T.axis(3, "move_z", 1)
T.wait(120)
T.axis(2, "lift", 0)
T.axis(3, "move_z", 0)
T.press(1, "shroud")
T.wait(60)
T.assert(P(1)().shroud, "P1 shrouded")
T.press(2, "decoy")
T.press(3, "map")
T.wait(60)
T.assert(P(3)().panel and P(3)().panel.kind == "map", "P3 opened the sector map")
T.press(3, "map")
T.wait(30)
