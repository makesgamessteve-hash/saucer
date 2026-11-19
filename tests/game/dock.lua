-- SPDX-License-Identifier: MIT
-- add-dock-land-eva slice 2: the station's tractor dock. Approach the bay and
-- the beam takes over; pull away and it lets go; ask for a tow and it carries
-- the Villa onto the dock pad, clamps close; out through the hull door into the
-- bay (air, no helmet), into the station and back; fold the Villa into your
-- pocket, refuse an unfold into a wall, unfold it in the station's hangar onto
-- the pad; lift off and ride the beam out.
local T = saucer.test
local ap = require("sim.autopilot")
local dock = require("sim.dock")
local env = require("sim.env")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local get = function() return T.state().players[1] end
local pi = saucer.math.pi
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function bay() return dock.bay(T.state(), 1) end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")

-- approach: fast and far, nothing happens; slow and close, the beam takes over
get().ship.pos = { bay().mouth[1] + 160, bay().mouth[2], bay().mouth[3] }
T.wait(1)
T.assert(get().berth == false, "out of the beam's reach")
get().ship.pos = { bay().mouth[1] + 40, bay().mouth[2] + 5, bay().mouth[3] + 30 }
T.wait(1)
local b = get().berth
T.assert(b and b.phase == "guide" and b.kind == "bay", "the tractor beam takes over")
T.assert(said("TRACTOR BEAM"), "and says so")
T.wait(3)
T.assert(get().berth.phase == "guide" and get().ship.pos[1] < bay().mouth[1] + 40, "towed toward the bay")

-- pulling away lets go
local away = { get().ship.pos[1] - bay().mouth[1], get().ship.pos[3] - bay().mouth[3] }
get().ship.yaw = saucer.math.atan2(away[1], away[2])
get().msgs = {}
T.axis(1, "move_z", 1, 120)
T.wait(100)
T.assert(get().berth == false and get().dock_off, "pulling away cancels the tow")
T.assert(said("pull away"), "and says so")
T.wait(30)
T.assert(get().berth == false, "the beam does not grab again while you are still close")
T.axis(1, "move_z", 0, 1)

-- ask for a tow with the Land button
get().ship.vel = { 0, 0, 0 }
get().ship.pos = { bay().mouth[1] + 40, bay().mouth[2] + 5, bay().mouth[3] + 30 }
T.wait(2)
T.press(1, "land")
T.wait(2)
T.assert(get().berth and get().berth.phase == "guide", "Land asks the beam for a tow")
T.press(1, "land")
T.wait(2)
T.assert(get().berth == false, "Land again cancels it")
get().ship.pos = { bay().mouth[1] + 20, bay().mouth[2], bay().mouth[3] }
get().ship.vel = { 0, 0, 0 }
T.press(1, "land")
T.wait(2)
T.assert(get().berth and get().berth.phase == "guide", "towed in again")
T.assert(ap.wait_until(T, 1, function() return get().berth and get().berth.phase == "descend" end, 60 * 20), "in the bay")
T.assert(ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 20), "touched down on the pad")
local r = bay().rest
local sp = get().ship.pos
T.assert(math.abs(sp[1] - r[1]) < 1e-6 and math.abs(sp[2] - r[2]) < 1e-6 and math.abs(sp[3] - r[3]) < 1e-6, "exactly on the pad")
T.wait(80)
T.assert(get().berth.clamp == 1 and get().berth.kind == "bay", "the clamps are closed")
T.assert(env.at(T.state(), get()).breathable, "the bay has air")

-- out through the hull hatch: no helmet, no airlock cycle
T.assert(ap.walk_to_station(T, 1, get, "hatch"), "walked to the hatch panel")
T.press(1, "use")
T.wait(1)
T.assert(get().door.cycle == false or get().door.cycle == nil or get().door.cycle == 0, "no airlock cycle in a pressurised bay")
T.assert(ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 8), "stairs out")
T.assert(not get().suited, "no helmet in the bay")
T.assert(ap.walk_path(T, 1, get, { { 0, -3, -8.0 } }, 0.3, 1500), "walked to the hatch")
ap.look(T, 1, get, pi, 0, 300)
T.assert(ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14), "down the stairs")
T.assert(get().excursion.coin == "stand" and not get().suited, "on the bay floor, bare-headed")
T.assert(get().excursion.body.pos[2] < bay().floor + 0.5, "feet on the deck")

-- through the bay door into the station and back
T.assert(not ap.ex_to(T, 1, get, { bay().lo[1] + 0.2, bay().floor, bay().door.z }, 0.3, 3000) and get().station, "through the bay door into the station")
T.assert(get().station.coin == "docked" and get().mode == "foot", "the Villa stays docked")
T.assert(get().berth and get().berth.phase == "landed", "and clamped")
get().station.body.yaw = pi
T.axis(1, "move_z", 1, 120)
T.wait(100)
T.axis(1, "move_z", 0, 1)
T.assert(get().excursion and get().station == false, "back in the bay")
T.assert(get().excursion.coin == "stand", "the Villa still stands on its pad")

-- fold the Villa from outside, then try to unfold it into a wall
local b0 = bay()
T.assert(ap.ex_to(T, 1, get, { b0.rest[1] + 2, b0.floor, b0.rest[3] + 16 }, 1, 3000), "walked away from the Villa")
T.assert(ap.wait_until(T, 1, function() return get().door.open == 0 end, 60 * 10), "hatch shut")
T.press(1, "shrink")
T.wait(2)
T.assert(get().excursion.coin == "fold" and get().berth == false, "folds, clamps released")
T.assert(ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 600), "in your pocket")
get().excursion.body.pos = { b0.lo[1] + 3, b0.floor, b0.lo[3] + 6 }
get().excursion.body.yaw = -pi / 2
get().msgs = {}
T.press(1, "size1")
T.wait(2)
T.assert(get().excursion.coin == "pocket" and said("No room"), "no room to unfold into the wall: told so")
-- into the station with the coin in your pocket, and unfold on the hangar's pad
T.assert(not ap.ex_to(T, 1, get, { b0.lo[1] + 0.2, b0.floor, b0.door.z }, 0.3, 3000) and get().station, "in the station again")
T.assert(get().station.coin == "pocket", "the coin is in your pocket")
get().station.body.yaw = pi
T.axis(1, "move_z", 1, 120)
T.wait(100)
T.axis(1, "move_z", 0, 1)
T.assert(get().excursion and get().excursion.coin == "pocket", "back in the bay with the coin")
-- unfold it in the open: clear space ahead
get().excursion.body.pos = { b0.hi[1] - 6, b0.floor, b0.rest[3] }
get().excursion.body.yaw = -pi / 2
T.press(1, "size1")
T.wait(2)
T.assert(get().excursion.coin == "grow" and get().ship.size == 1, "the Villa unfolds")
T.assert(ap.wait_until(T, 1, function() return get().excursion and get().excursion.coin == "stand" end, 600), "and stands on its gear")
T.assert(get().berth.kind == "bay", "on the bay's floor")
local foot = hulldoor.foot_world(T.state(), get())
T.assert(ap.ex_to(T, 1, get, foot, 0.5, 2400), "walked to the stairs' foot")
T.assert(ap.wait_until(T, 1, function() return get().mode == "walk" end, 400), "climbed aboard")
ap.look(T, 1, get, 0, 0, 300)
T.assert(ap.push(T, 1, function() return not get().door.on end, 60 * 14), "up the stairs and onto the deck")
T.press(1, "use")
T.wait(1)
T.assert(ap.wait_until(T, 1, function() return get().door.open == 0 end, 60 * 10), "the hatch closed behind you")

-- lift off and ride the beam out
T.assert(ap.take_helm(T, 1, get), "at the helm")
T.press(1, "land")
T.wait(1)
T.assert(get().berth.phase == "lift", "lifting")
T.assert(ap.wait_until(T, 1, function() return get().berth and get().berth.phase == "release" end, 60 * 10), "clamps open, gear up")
T.assert(ap.wait_until(T, 1, function() return get().berth == false end, 60 * 20), "the beam lets go outside")
T.assert(get().ship.pos[1] > bay().hi[1] + 20 and get().dock_off, "carried out of the bay, and not grabbed again")
print("dock: ok")
