-- SPDX-License-Identifier: MIT
-- The two-window network shot for milestone 9 (tools/shots/m9_net.sh runs a
-- host and a guest on loopback and photographs both windows). Both play the
-- same inputs on their own slot: get up, walk to the helm, lift off and turn
-- toward the other saucer. Then they hold still for the photo.
local T = saucer.test
local ap = require("sim.autopilot")
local NS = saucer.net.status()
local D = NS.delay
local function P(i) return function() return T.state().players[i] end end
local function step(n) T.wait(n or (D + 2)) end
local function until_(f, n)
  for _ = 1, n or 600 do
    if f() then return true end
    T.wait(1)
  end
  return f()
end
T.assert(until_(function() return #T.state().players == 2 end, 240), "the guest joined")
for i = 1, 2 do
  until_(function()
    if P(i)().mode ~= "wake" then return true end
    T.press(i, "use", 1, true)
    step()
    return P(i)().mode ~= "wake"
  end, 60)
end
for i = 1, 2 do
  ap.walk_to(T, i, P(i), "helm", 0.3, 2400)
  T.press(i, "use", 1, true)
  step()
end
for _ = 1, 150 do
  T.axis(1, "lift", 1, 1, true)
  T.axis(2, "lift", 1, 1, true)
  T.wait(1)
end
-- turn each saucer toward the other (one at a time; the sign of "turn" is
-- learned from how the error moves, as inputs land `delay` ticks late)
local function err(i)
  local a, b = P(i)().ship, P(3 - i)().ship
  local want = saucer.math.atan2(b.pos[1] - a.pos[1], b.pos[3] - a.pos[3])
  return (want - a.yaw + math.pi) % (2 * math.pi) - math.pi
end
for i = 1, 2 do
  local sgn = 1
  for k = 1, 900 do
    local e = err(i)
    if math.abs(e) < 0.05 then break end
    T.axis(i, "turn", sgn * (math.abs(e) > 0.4 and 0.5 or 0.15), 1, true)
    T.wait(1)
    if k % 12 == 0 and math.abs(err(i)) > math.abs(e) then sgn = -sgn end
  end
  T.axis(i, "turn", 0, 1, true)
  T.wait(D + 10)
end
T.wait(D + 30)
for i = 1, 2 do
  local a, b = P(i)().ship, P(3 - i)().ship
  print(string.format("P%d yaw %.2f want %.2f dist %.0f", i, a.yaw,
    saucer.math.atan2(b.pos[1] - a.pos[1], b.pos[3] - a.pos[3]), require("lib.vec").dist(a.pos, b.pos)))
end
local st = saucer.net.status()
print(string.format("SHOT READY slot %d tick %d checks %d", NS.slot, T.state().tick, st.checks))
T.wait(60 * 20)
