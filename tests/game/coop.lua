-- SPDX-License-Identifier: MIT
-- Two local players (run with --local-players 2 --viewports 2): each has an
-- own saucer, size, Charge and loot instances; saucers block each other.
local T = saucer.test
local game = require("sim.game")
local tractor = require("sim.tractor")
local st = T.state()
T.assert(#st.players == 2, "two players")
local p1, p2 = st.players[1], st.players[2]

T.press(2, "shrink")
T.wait(45)
T.assert(T.state().players[2].ship.size == 2, "player 2 shrank")
T.assert(T.state().players[1].ship.size == 1, "player 1 did not")
T.assert(T.state().players[1].ship.charge > T.state().players[2].ship.charge, "Charge is per player")

-- per-player loot: the same slot rolls a different instance for each player
local r = game.ruin(1)
local a = tractor.candidates(T.state(), T.state().players[1], 1, r)
local b = tractor.candidates(T.state(), T.state().players[2], 1, r)
local differs = false
for i = 1, #a do
  if a[i].item.name ~= b[i].item.name or a[i].item.value ~= b[i].item.value then differs = true end
end
T.assert(#a == #b and differs, "each player gets their own loot instances")

-- fly player 2 into player 1 sideways: the hulls must not overlap
for _ = 1, 240 do
  T.axis(2, "move_x", 1, 1, true)
  T.wait(1)
end
local q1, q2 = T.state().players[1].ship, T.state().players[2].ship
local dx = math.abs(q1.pos[1] - q2.pos[1])
T.assert(dx >= 12 + 5 - 0.01, "saucers are solid to each other (dx " .. dx .. ")")
