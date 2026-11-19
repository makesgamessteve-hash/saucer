-- SPDX-License-Identifier: MIT
-- Screenshot tour for add-dock-land-eva slice 4 (the EVA kit). Run from the folder that should receive shots_eva/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/eva.lua
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local eva = require("sim.eva")
local vec = require("lib.vec")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_eva/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function body() return get().excursion.body end

T.wait(40)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local PY = -520
game.extra_solids[#game.extra_solids + 1] = { { -140, PY - 20, -140 }, { 140, PY, 140 } }
saucer.physics.add_box({ -140, PY - 20, -140 }, { 140, PY, 140 }, 1)
get().ship.pos = { 0, PY + 40, 0 }
get().ship.yaw = 0.7
T.press(1, "land")
ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 30)
ap.walk_to_station(T, 1, get, "hatch")
T.press(1, "use")
ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 12)
ap.walk_path(T, 1, get, { { 0, -3, -8.0 } }, 0.3, 1500)
ap.look(T, 1, get, sm.pi, 0, 300)
ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14)
ap.hold(T, 1, {})
T.wait(60)
shot("50_helmet_hud_beside_the_villa")

-- turn round and look at the Villa from a little way off
local function look_at_villa()
  local b = body()
  local d = vec.sub(get().ship.pos, b.pos)
  body().yaw, body().pitch = sm.atan2(d[1], d[3]), -0.05
end

-- fly out, then look back
local from = vec.copy(body().pos)
ap.push(T, 1, function() return vec.dist(body().pos, from) > 70 end, 60 * 30, { move_z = 1, lift = 0.35 })
ap.hold(T, 1, {})
T.wait(10)
look_at_villa()
T.wait(20)
shot("51_jetpack_flying_out_looking_back")
T.wait(250)
shot("52_hanging_in_space_far_from_the_villa")

-- low oxygen
get().eva.o2 = 28
T.wait(10)
shot("53_oxygen_low")
get().eva.o2 = 14
T.wait(5)
shot("54_oxygen_critical_assist_engaged")
T.wait(60)
shot("55_return_assist_flying_home")
-- take over, then charge the teleport
T.axis(1, "move_z", 1, 3)
T.wait(5)
ap.hold(T, 1, {})
get().eva.cool = 0
get().hands = { { name = "Relic" }, { name = "Crystal" } }
T.press(1, "home")
T.wait(90)
shot("56_emergency_teleport_charging")
T.wait(70)
shot("57_teleport_flash")
T.wait(60)
shot("58_back_at_the_villa_cooldown")
