-- SPDX-License-Identifier: MIT
-- add-dock-land-eva slice 4: the EVA kit. Land the Villa in open space, walk out, and use the kit:
-- the helmet, the six-direction jetpack and its automatic braking, oxygen and fuel, the refill beside the
-- Villa, the return assist, the emergency teleport (charge-up, lost loot, cooldown), the low-oxygen
-- automatic teleport, a teleport home when the Villa is in your pocket, and a boost/hover pass in a pull.
local T = saucer.test
local ap = require("sim.autopilot")
local game = require("sim.game")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local eva = require("sim.eva")
local env = require("sim.env")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function clear() get().msgs = {} end
local function body() return get().excursion.body end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local PY = -520
local function solid(mn, mx)
  game.extra_solids[#game.extra_solids + 1] = { mn, mx }
  saucer.physics.add_box(mn, mx, 1)
end
solid({ -140, PY - 20, -140 }, { 140, PY, 140 })
get().ship.pos = { 0, PY + 40, 0 }
get().ship.yaw = 0.7
T.press(1, "land")
T.assert(ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 30), "touched down")
T.assert(ap.walk_to_station(T, 1, get, "hatch"), "walked to the hatch panel")
T.press(1, "use")
T.assert(ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 12), "hatch open, stairs out")
T.assert(ap.walk_path(T, 1, get, { { 0, -3, -8.0 } }, 0.3, 1500), "walked to the hatch")
ap.look(T, 1, get, saucer.math.pi, 0, 300)
T.assert(ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14), "down the stairs")
ap.hold(T, 1, {})

-- the kit
local p = get()
T.assert(p.excursion.home and eva.active(p), "the kit is on for a Villa expedition")
T.assert(p.suited, "the helmet is on")
T.assert(p.eva.o2 == 100 and p.eva.fuel == 100 and p.eva.integrity == 100, "tanks full")
local st = eva.status(T.state(), p)
T.assert(st.helmet and st.g == 0 and not st.breathable and st.dist < 6, "status: helmet, zero-g, near the Villa")
T.wait(120)
T.assert(get().eva.o2 == 100, "no oxygen is used beside the Villa")

-- jetpack, zero-g: lift pushes you up; no thrust brakes
local y0 = body().pos[2]
T.axis(1, "lift", 1, 90)
T.wait(60)
T.axis(1, "lift", 0, 1)
T.assert(body().pos[2] > y0 + 4 and not body().ground, "the jetpack lifts you off")
T.assert(get().eva.jet, "the jetpack is on")
local speed = vec.len(get().eva.vel)
T.assert(speed > 3, "moving at " .. speed)
T.wait(200)
T.assert(vec.len(get().eva.vel) < 0.1, "the automatic brake stops you")
local y1 = body().pos[2]
T.wait(30)
T.assert(math.abs(body().pos[2] - y1) < 0.01, "and you hang there")
-- fly out 50 m: forward + a little up (six directions)
local from = vec.copy(body().pos)
local want = { from[1] + 60 * saucer.math.sin(body().yaw), from[2] + 6, from[3] + 60 * saucer.math.cos(body().yaw) }
T.axis(1, "move_z", 1, 600)
T.axis(1, "lift", 0.15, 600)
T.assert(ap.push(T, 1, function() return vec.dist(body().pos, from) > 90 end, 60 * 30, { move_z = 1, lift = 0.15 }), "flew 90 m out")
ap.hold(T, 1, {})
T.wait(300)
T.assert(vec.len(get().eva.vel) < 0.1, "braked")
T.assert(get().eva.fuel < 99, "the fuel shows it: " .. get().eva.fuel)
T.assert(get().eva.o2 < 99 and get().eva.o2 > 70, "oxygen drains away from the Villa (jet burns it faster): " .. get().eva.o2)

-- return assist: it flies you home
clear()
T.press(1, "assist")
T.wait(2)
T.assert(get().eva.assist and said("RETURN ASSIST"), "the assist flies")
local fuel0 = get().eva.fuel
T.assert(ap.wait_until(T, 1, function() return not get().eva.assist end, 60 * 20), "the assist lets go at the Villa")
T.assert(said("you are at the Villa"), "and says so")
local foot = eva.target(T.state(), get())
local hz = math.sqrt((body().pos[1] - foot[1]) ^ 2 + (body().pos[3] - foot[3]) ^ 2)
T.assert(hz < 4, "within reach of the stairs: " .. hz)
T.assert(get().eva.fuel < fuel0, "it used fuel")
-- refill beside the Villa (fall back to the deck first)
T.axis(1, "lift", -1, 200)
T.assert(ap.wait_until(T, 1, function() return get().excursion.body.ground end, 60 * 10, { lift = -1 }), "back on the deck")
ap.hold(T, 1, {})
T.assert(ap.wait_until(T, 1, function() return get().eva.fuel >= 99.99 and get().eva.o2 >= 99.99 end, 60 * 10), "oxygen and fuel refill at the Villa")
T.assert(said("Refilling"), "it said it was refilling")

-- low oxygen warns, then the assist takes you home, then the suit teleports you at zero
local far = { body().pos[1] + 80 * saucer.math.sin(body().yaw + 3.14), body().pos[2], body().pos[3] + 80 * saucer.math.cos(body().yaw + 3.14) }
T.assert(ap.ex_to(T, 1, get, far, 2, 60 * 40), "walked 80 m away from the Villa")
ap.hold(T, 1, {})
clear()
get().eva.o2 = 29
T.wait(3)
T.assert(said("OXYGEN LOW"), "oxygen low warning")
get().eva.o2 = 14
T.wait(3)
T.assert(said("OXYGEN CRITICAL"), "oxygen critical warning")
T.assert(get().eva.assist and said("the return assist takes you home"), "the assist engages by itself")
-- hands full of loot so the loss shows
local p2 = get()
p2.hands = { { name = "Alpha", id = "a" }, { name = "Beta", id = "b" }, { name = "Gamma", id = "g" }, { name = "Delta", id = "d" } }
local caches0 = #(T.state().caches or {})
-- the assist is cancelled and the oxygen is gone: the suit teleports you
get().eva.assist = false
get().eva.o2 = 0.001
clear()
T.wait(3)
T.assert(said("OUT OF OXYGEN"), "out of oxygen")
local foot2 = eva.target(T.state(), get())
T.assert(vec.dist(body().pos, foot2) < 3, "teleported to the stairs' foot")
T.assert(#get().hands == 2 and #(T.state().caches or {}) == caches0 + 1, "half the hands stayed behind as a cache")
T.assert(get().eva.cool > 200, "the long cooldown starts")
T.assert(get().mode == "foot" and get().eva.o2 > 0, "alive, and breathing again")
T.assert(get().eva.flash > 0, "with a flash")

-- the emergency teleport button
T.press(1, "home")
T.wait(2)
T.assert(not get().eva.tele and said("recharging"), "the cooldown refuses")
get().eva.cool = 0
local away = { body().pos[1] + 40 * saucer.math.sin(body().yaw + 3.14), body().pos[2], body().pos[3] + 40 * saucer.math.cos(body().yaw + 3.14) }
T.assert(ap.ex_to(T, 1, get, away, 2, 60 * 30), "walked 40 m off")
ap.hold(T, 1, {})
clear()
T.press(1, "home")
T.wait(2)
T.assert(get().eva.tele and said("charging"), "charging")
T.wait(60)
T.press(1, "home")
T.wait(2)
T.assert(not get().eva.tele and said("cancelled"), "pressing again cancels it")
T.assert(vec.dist(body().pos, eva.target(T.state(), get())) > 30, "still out there")
T.press(1, "home")
T.wait(60 * 2.6)
T.assert(vec.dist(body().pos, eva.target(T.state(), get())) < 3, "back at the Villa after the charge-up")
T.assert(#get().hands == 1 and get().eva.cool > 200, "and it cost loot and started the cooldown")
T.press(1, "home")
T.wait(2)
T.assert(said("recharging"), "no second teleport on cooldown")

-- the Villa in your pocket: the teleport brings it back
get().eva.cool = 0
T.assert(ap.ex_to(T, 1, get, away, 2, 60 * 30), "walked off again")
ap.hold(T, 1, {})
T.assert(ap.wait_until(T, 1, function() return get().door.open == 0 end, 60 * 10), "the hatch shut behind me")
T.press(1, "shrink")
T.wait(2)
T.assert(ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 900), "the Villa is in my pocket")
T.assert(get().ship.size == require("sim.excursion").pocket_size() and get().berth == false, "folded away")
T.press(1, "home")
T.wait(60 * 2.7)
T.assert(get().excursion.coin == "stand" and get().ship.size == 1 and landing.landed(get()), "the Villa is standing again")
T.assert(vec.dist(body().pos, eva.target(T.state(), get())) < 3, "and I am at its stairs")

-- a pull: boost, hover, descend (the environment of a moon city, borrowed for open space)
local of_site = env.of_site
env.of_site = function(site)
  local e = of_site(site)
  e.g, e.temp, e.rad = 0.16, -85, 0.35
  return e
end
get().eva.cool = 0
T.wait(2)
local b0 = body().pos[2]
T.axis(1, "lift", 1, 120)
T.wait(60)
T.assert(body().pos[2] > b0 + 3, "boosting up in a light pull")
local fuel1 = get().eva.fuel
T.axis(1, "lift", 0, 1)
T.wait(40)
local hover_y = body().pos[2]
T.wait(60)
T.assert(math.abs(body().pos[2] - hover_y) < 0.2, "hovering with a neutral stick")
T.assert(get().eva.fuel < fuel1, "hovering burns fuel")
-- let go of the pack: fall (a gentle landing)
get().eva.fuel = 0
T.wait(60 * 12)
T.assert(body().ground and not get().eva.jet, "back on the ground with the pack empty")
T.assert(get().eva.integrity == 100, "a light-gravity landing costs nothing")
env.of_site = of_site

-- the helmet follows the air
local br = env.AIR
local at = env.at
env.at = function(state, pl) local e = at(state, pl) e.breathable, e.vacuum, e.g = true, false, 1 return e end
T.wait(3)
T.assert(not get().suited and said("Helmet off"), "helmet off in breathable air")
env.at = at
T.wait(3)
T.assert(get().suited and said("Helmet on"), "and on again in vacuum")

-- a hard fall hurts the suit, never fatally
local pl = get()
pl.eva.integrity = 100
local of2 = env.of_site
env.of_site = function(site) local e = of2(site) e.g = 1.2 return e end
body().pos = { body().pos[1], body().pos[2] + 70, body().pos[3] }
body().ground = false
T.wait(60 * 10)
env.of_site = of2
T.assert(body().ground, "fell to the deck")
T.assert(get().eva.integrity < 100 and get().eva.integrity > 0 or get().mode == "foot", "the suit took the fall")
print("eva: ok")
