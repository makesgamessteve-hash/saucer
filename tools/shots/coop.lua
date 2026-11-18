-- SPDX-License-Identifier: MIT
-- Co-op screenshots (OpenSpec add-multiplayer-foundation 1.4 and 1.6). Run from the folder that should
-- receive shots_coop/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --local-players 2 --viewports 2
--          --script REPO/tools/shots/coop.lua
-- 1. P1 pushes into P2's parked saucer for 2 s and phases through it for 3 s.
-- 2. Both Seats beam the twin vault's shutter anchor in the same tick: one latches it, the other is
--    told it was beaten to it.
-- 3. Nobody comes for the vault: the hold lets go after 90 s.
-- Staged: the saucers are placed (the flights there are tests/game/tractor.lua's).
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local twin = require("sim.twin")
local tractor = require("sim.tractor")
local vec = require("lib.vec")
local P = function(i) return function() return T.state().players[i] end end
local p1, p2 = P(1), P(2)
local D = "shots_coop/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
local function heard(p, s)
  for _, m in ipairs(p.msgs) do if m.text:find(s, 1, true) then return true end end
  return false
end

T.wait(10)
if #T.state().players < 2 then T.press(2, "use") end
T.wait(10)
ap.wake(T, 1, p1)
ap.wake(T, 2, p2)
ap.take_helm(T, 1, p1)
ap.take_helm(T, 2, p2)

-- 1. a friend parked in the way
local a, b = p1(), p2()
print(string.format('start a %.1f %.1f %.1f', a.ship.pos[1], a.ship.pos[2], a.ship.pos[3]))
-- out in open space, well away from the sector's sites
local away = vec.sub(a.ship.pos, T.state().sector.sites[1].pos)
away[2] = 0
away = vec.scale(vec.norm(away), 700)
a.ship.pos = vec.add(a.ship.pos, { away[1], 150, away[3] })
a.ship.yaw, a.ship.pitch, a.ship.bank = 0, 0, 0
a.ship.vel, b.ship.vel = { 0, 0, 0 }, { 0, 0, 0 }
b.ship.pos = { a.ship.pos[1], a.ship.pos[2], a.ship.pos[3] + 40 }
b.ship.yaw, b.ship.pitch, b.ship.bank = math.pi, 0, 0
T.wait(20)
shot("01_friend_in_the_way")
local pushes = 0
while not game.phased(T.state(), p1(), p2()) and pushes < 600 do
  T.axis(1, "move_z", 1, 1, true)
  T.wait(1)
  pushes = pushes + 1
end
T.axis(1, "move_z", 0, 1, true)
print(string.format("a %.1f %.1f %.1f  b %.1f %.1f %.1f  yaw %.2f  phase %s mode %s", a.ship.pos[1], a.ship.pos[2], a.ship.pos[3], b.ship.pos[1], b.ship.pos[2], b.ship.pos[3], p1().ship.yaw, tostring(T.state().phase), p1().mode))
T.assert(game.phased(T.state(), p1(), p2()), "the pair phases after the push")
print("phased after " .. pushes .. " ticks")
T.wait(5)
shot("02_phased_message")
for _ = 1, 90 do T.axis(1, "move_z", 1, 1, true) T.wait(1) end
T.axis(1, "move_z", 0, 1, true)
T.wait(10)
print(string.format("P1 z %.1f, P2 z %.1f", p1().ship.pos[3], p2().ship.pos[3]))
shot("03_passed_through")

-- 2. the same tick on the same anchor
local site, L
for i = 1, #T.state().sector.sites do
  if not site and twin.layout(game.ruin(i)) then site, L = i, twin.layout(game.ruin(i)) end
end
T.assert(site, "a site with a twin vault")
local ruin = game.ruin(site)
local function cand(get, kind)
  for _, c in ipairs(tractor.candidates(T.state(), get(), site, ruin)) do if c.kind == kind then return c end end
end
local function over(get, c)
  local p = get()
  p.ship.size, p.ship.morph, p.site, p.mode = 2, false, site, "helm"
  p.ship.pos = ap.beam_spot(c.pos, 2)
  p.ship.yaw = ap.beam_yaw(c, 0)
  p.ship.bank, p.ship.pitch, p.ship.vel = 0, 0, { 0, 0, 0 }
end
local ac = cand(p1, "anchor")
over(p1, ac)
over(p2, ac)
T.wait(30)
shot("04_two_seats_over_the_anchor")
T.press(1, "tractor")
T.press(2, "tractor")
T.wait(2)
-- the two key presses land a frame apart: line the second pull up with the first so both finish together
if p1().tractor and p2().tractor then p2().tractor.t = p1().tractor.t end
ap.wait_until(T, 1, function() return not p1().tractor and not p2().tractor end, 1500)
T.wait(10)
local e = T.state().twins and T.state().twins[twin.key(site)]
T.assert(e and e.by > 0, "someone holds the anchor")
local loser = e.by == 1 and 2 or 1
print("holder P" .. e.by .. ", beaten P" .. loser)
T.assert(heard(T.state().players[loser], "got there first"), "the loser is told")
shot("05_same_tick_claim")

-- 3. nobody comes: the hold lets go
local waited = 0
while twin.holder(T.state(), site) and waited < twin.HOLD_TIME + 600 do
  T.wait(60)
  waited = waited + 60
end
T.wait(5)
T.assert(not twin.holder(T.state(), site), "the untaken hold let go")
print("hold let go after " .. waited .. " ticks")
shot("06_hold_timed_out")
print("coop tour done")
