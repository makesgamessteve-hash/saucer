-- SPDX-License-Identifier: MIT
-- Screenshot tour for add-dock-land-eva slice 2 (the station tractor dock). Run from the folder that
-- should receive shots_eva/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/dock.lua
local T = saucer.test
local ap = require("sim.autopilot")
local dock = require("sim.dock")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local R = require("view.render")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_eva/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function cam(pos, yaw, pitch) free = { pos = pos, yaw = yaw, pitch = pitch or 0, fov = 62, near = 0.1, far = 4000 } end
local function look_at(from, to)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  cam(from, sm.atan2(dx, dz), sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)))
end
local function bay() return dock.bay(T.state(), 1) end

T.wait(40)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local b = bay()
-- the station and its bay from outside, before the beam
get().ship.pos = { b.mouth[1] + 300, b.mouth[2] + 30, b.mouth[3] + 200 }
look_at({ b.mouth[1] + 140, b.mouth[2] + 40, b.mouth[3] + 110 }, { b.pad[1] - 20, b.pad[2] + 5, b.pad[3] })
shot("20_station_bay_from_outside")
-- the beam takes over
get().ship.pos = { b.mouth[1] + 45, b.mouth[2] + 5, b.mouth[3] + 25 }
get().ship.vel = { 0, 0, 0 }
T.wait(60)
look_at({ b.mouth[1] + 70, b.mouth[2] + 22, b.mouth[3] + 60 }, { b.mouth[1] - 8, b.mouth[2], b.mouth[3] })
shot("21_tractor_beam_towing_in")
ap.wait_until(T, 1, function() return get().berth and get().berth.phase == "descend" end, 60 * 20)
look_at({ b.hi[1] + 30, b.floor + 16, b.pad[3] + 6 }, { b.pad[1], b.floor + 8, b.pad[3] })
shot("22_over_the_pad")
ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 20)
T.wait(80)
look_at({ b.hi[1] + 14, b.floor + 9, b.pad[3] + 4 }, { b.pad[1], b.floor + 3.5, b.pad[3] })
shot("23_docked_clamps_closed")
look_at({ b.pad[1] + 22, b.floor + 2.4, b.pad[3] - 12 }, { b.pad[1] + 4, b.floor + 0.3, b.pad[3] - 5 })
shot("24_clamp_on_a_foot")
-- the hatch and the stairs onto the bay floor
ap.walk_to_station(T, 1, get, "hatch")
T.press(1, "use")
ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 8)
T.wait(10)
look_at({ b.hi[1] - 2, b.floor + 4, b.pad[3] + 10 }, { b.pad[1] - 12, b.floor + 2.5, b.pad[3] })
shot("25_stairs_to_the_bay_floor")
free = nil
ap.walk_path(T, 1, get, { { 0, -3, -8.2 } }, 0.3, 1500)
ap.look(T, 1, get, sm.pi, 0, 300)
ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14)
ap.hold(T, 1, {})
T.wait(10)
local function ex_look(yaw, pitch)
  for _ = 1, 400 do
    local bd = get().excursion.body
    local dy, dp = sm.wrap(yaw - bd.yaw), pitch - bd.pitch
    if math.abs(dy) < 0.02 and math.abs(dp) < 0.02 then break end
    T.axis(1, "turn", math.max(-1, math.min(1, -dy * 2)), 1, true)
    T.axis(1, "look", math.max(-1, math.min(1, dp * 2)), 1, true)
    T.wait(1)
  end
  T.axis(1, "turn", 0, 1, true)
  T.axis(1, "look", 0, 1, true)
end
ex_look(-sm.pi / 2, 0.05)
shot("26_the_back_door_ahead")
ex_look(sm.pi / 2, 0.15)
shot("27_looking_back_at_the_villa")
ex_look(-sm.pi / 2, 0.05)
ap.ex_to(T, 1, get, { b.lo[1] + 0.2, b.floor, b.door.z }, 0.3, 3000)
T.wait(10)
shot("28_station_concourse")
get().station.body.yaw = sm.pi
T.axis(1, "move_z", 1, 120)
T.wait(100)
T.axis(1, "move_z", 0, 1)
-- fold the Villa and the "no room" prompt
ap.ex_to(T, 1, get, { b.rest[1] + 2, b.floor, b.rest[3] + 16 }, 1, 3000)
ap.wait_until(T, 1, function() return get().door.open == 0 end, 60 * 10)
T.press(1, "shrink")
ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 600)
get().excursion.body.pos = { b.lo[1] + 3, b.floor, b.lo[3] + 6 }
ex_look(-sm.pi / 2, 0.0)
T.press(1, "size1")
T.wait(10)
shot("29_no_room_to_unfold")
get().excursion.body.pos = { b.hi[1] - 6, b.floor, b.rest[3] }
ex_look(-sm.pi / 2, 0.05)
T.press(1, "size1")
T.wait(50)
shot("30_unfolding_in_the_bay")
ap.wait_until(T, 1, function() return get().excursion and get().excursion.coin == "stand" end, 600)
shot("31_standing_again")
