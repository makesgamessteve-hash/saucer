-- SPDX-License-Identifier: MIT
-- add-dock-land-eva slice 1: the hull door and landing gear. Land the Villa
-- on a platform in open space, refuse a landing over a drop-off and over a
-- slope, open the hatch (never while flying; the suit seals first in vacuum),
-- walk down the stairs, fold the Villa into your pocket from outside, unfold
-- it again, climb back in and lift off.
local T = saucer.test
local ap = require("sim.autopilot")
local game = require("sim.game")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local excursion = require("sim.excursion")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
-- a big flat platform far from every site, and a pillar for the slope case
local PY = -520
local function solid(mn, mx)
  game.extra_solids[#game.extra_solids + 1] = { mn, mx }
  saucer.physics.add_box(mn, mx, 1)
end
solid({ -80, PY - 20, -80 }, { 80, PY, 80 })
solid({ 200, PY - 20, -80 }, { 360, PY, 80 })
solid({ 200, PY, -80 }, { 360, PY + 2.4, -30 }) -- a step under part of the hull

-- the hatch will not open while flying
get().ship.pos = { 0, PY + 60, 0 }
T.press(1, "use")
T.wait(1)
T.assert(get().mode == "walk", "stood up from the helm")
T.assert(ap.walk_to(T, 1, get, "hatch", 0.5), "walked to the hatch panel")
T.press(1, "use")
T.wait(2)
T.assert(get().door == false or get().door.goal == 0, "the hatch stays shut while the saucer flies")
T.assert(said("Land first"), "and says why")
T.assert(ap.take_helm(T, 1, get), "back at the helm")

-- no ground under the gear: over the platform's edge
get().ship.pos = { 77, PY + 40, 0 }
T.press(1, "land")
T.wait(2)
T.assert(get().berth == false and said("No ground"), "no landing with a foot over the drop")
-- too steep: a step under part of the hull
get().ship.pos = { 280, PY + 40, -30 }
get().msgs = {}
T.press(1, "land")
T.wait(2)
T.assert(get().berth == false and said("too steep") or said("Too steep"), "no landing on a slope")

-- land on the platform
get().ship.pos = { 0, PY + 40, 0 }
get().ship.yaw = 0.7
get().msgs = {}
T.press(1, "land")
T.wait(5)
T.assert(get().berth and get().berth.phase == "descend", "settling on the gear")
T.assert(get().berth.legs > 0, "the legs swing out")
T.assert(ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 30), "touched down")
local ship = get().ship
T.assert(math.abs(ship.pos[2] - (PY + landing.tune().leg_len)) < 1e-6, "standing on its legs at the gear height")
T.assert(get().berth.legs == 1, "gear fully down")
-- anchored: pushing the stick does nothing
T.axis(1, "move_z", 1, 60)
T.wait(30)
T.assert(math.abs(get().ship.pos[1]) < 1e-6 and math.abs(get().ship.pos[3]) < 1e-6, "anchored to the ground")
T.axis(1, "move_z", 0, 1)

-- the hatch: stand up, the suit seals (vacuum), then it opens
T.assert(ap.walk_to_station(T, 1, get, "hatch"), "walked to the hatch panel")
T.press(1, "use")
T.wait(1)
local d = get().door
T.assert(d and d.cycle ~= false and d.open == 0, "the airlock cycles before the door moves")
T.assert(ap.wait_until(T, 1, function() return get().door.goal == 1 end, 200), "the hatch opens once the suit is sealed")
T.assert(get().suited, "suited in vacuum")
T.assert(ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 8), "leaves slid apart, stairs out")
local dr = get().door
T.assert(dr.drop > 3.5 and dr.drop < 5 and dr.steps >= 14, "stairs reach the platform: " .. dr.drop .. " m in " .. dr.steps)

-- down the stairs
local total = hulldoor.total(get())
T.assert(ap.walk_path(T, 1, get, { { 0, -3, -8.0 } }, 0.3, 1500), "walked to the hatch")
ap.look(T, 1, get, saucer.math.pi, 0, 300)
T.assert(ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14), "walked down the stairs onto the platform")
local p = get()
T.assert(p.excursion and p.excursion.coin == "stand", "the Villa stands behind you")
T.assert(p.excursion.body.pos[2] > PY - 0.5 and p.excursion.body.pos[2] < PY + 0.5, "feet on the ground")
T.assert(p.suited, "helmet on outside")

-- walk away: the hatch shuts behind you once it has been open long enough
local b = p.excursion.body
T.assert(ap.ex_to(T, 1, get, { b.pos[1] + 30 * saucer.math.sin(b.yaw), b.pos[2], b.pos[3] + 30 * saucer.math.cos(b.yaw) }, 1, 1500),
  "walked away from the Villa")
T.assert(ap.wait_until(T, 1, function() return get().door.open == 0 end, 60 * 10), "the stairs fold and the hatch shuts")

-- fold the Villa into your hand, from outside
local charge0 = get().ship.charge
T.press(1, "shrink")
T.wait(2)
T.assert(get().excursion.coin == "fold" and get().ship.size == excursion.pocket_size(), "the Villa folds into your hand")
T.assert(get().berth == false and get().ship.charge < charge0, "the gear is gone and it cost Charge")
T.assert(ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 600), "and goes into your pocket")

-- unfold it again in front of you
T.press(1, "grow")
T.wait(2)
T.assert(get().excursion.coin == "grow" and get().ship.size == 1, "the Villa unfolds")
T.assert(ap.wait_until(T, 1, function() return get().excursion and get().excursion.coin == "stand" end, 600), "and stands on its gear")
T.assert(landing.landed(get()), "landed where it grew")

-- back to the stairs and in
local foot = hulldoor.foot_world(T.state(), get())
T.assert(ap.ex_to(T, 1, get, foot, 0.5, 2400), "walked to the stairs' foot")
T.assert(ap.wait_until(T, 1, function() return get().mode == "walk" end, 400), "climbed the stairs into the Villa")
T.assert(get().door.on, "on the stairs")
ap.look(T, 1, get, 0, 0, 300)
T.assert(ap.push(T, 1, function() return not get().door.on end, 60 * 14), "up the stairs and onto the deck")
T.assert(not get().door.on, "back on the deck")
T.press(1, "use")
T.wait(1)
T.assert(ap.wait_until(T, 1, function() return get().door.open == 0 end, 60 * 10), "the hatch closed behind you")
T.assert(ap.take_helm(T, 1, get), "at the helm")
T.press(1, "land")
T.wait(1)
T.assert(get().berth and get().berth.phase == "lift", "lifting off")
T.assert(ap.wait_until(T, 1, function() return get().berth == false end, 60 * 10), "gear up")
T.assert(get().ship.pos[2] > PY + landing.tune().leg_len + 2, "clear of the ground")
print("hatch: ok")
