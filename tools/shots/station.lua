-- SPDX-License-Identifier: MIT
-- Screenshot tour for add-huge-stations (the megastructure station). Run from the folder that should receive
-- shots_station/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/station.lua
local T = saucer.test
local ap = require("sim.autopilot")
local dock = require("sim.dock")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local sh = require("sim.stationhull")
local R = require("view.render")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_station/"
local want   -- set to { name = true, ... } to take only those shots
local function shot(name) if want and not want[name] then return end T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function cam(pos, yaw, pitch, fov) free = { pos = pos, yaw = yaw, pitch = pitch or 0, fov = fov or 62, near = 0.1, far = 4000 } end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  cam(from, sm.atan2(dx, dz), sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov)
end
local function bay() return dock.bay(T.state(), 1) end
local function tp() return T.state().sector.trader.pos end
local function rel(x, y, z) local p = tp() return { p[1] + x, p[2] + y, p[3] + z } end

T.wait(40)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local b = bay()
local L = sh.for_trader(T.state(), 1)
local i = L.info
saucer.log.info(string.format("station: R=%d arm=%d pods=%d palette=%s hull=%s", i.R, i.arm, i.pods, i.palette, L.hash))
-- 1. from far away, the saucer for scale
get().ship.pos = rel(190, 80, -215)
get().ship.yaw = sm.atan2(-0.9, 0.36)
look_at(rel(300, 90, -260), rel(-380, 40, 0), 70)
shot("01_far_with_the_saucer")
-- 1b. farther, the whole megastructure
look_at(rel(900, 300, -900), rel(-380, 20, 0), 60)
shot("01b_far_whole_station")
-- 2. approaching: the bay a small mark on the arm
get().ship.pos = { b.mouth[1] + 150, b.mouth[2] + 10, b.mouth[3] + 10 }
look_at(rel(330, 70, 60), rel(-150, 15, 0), 70)
shot("02_approaching_the_bay")
-- 3. a close detail: a docking arm pod and its neighbours
local pods = L.info.pods
look_at(rel(60, 140, -190), rel(-130, 50, 0), 70)
shot("03_close_detail_arm_and_pods")
-- the ring and the hub
look_at(rel(-300, 120, 500), rel(-480, 20, 380), 70)
shot("03b_close_detail_ring")
-- 4. the tractor beam pulling in
get().ship.pos = { b.mouth[1] + 120, b.mouth[2] + 5, b.mouth[3] + 25 }
get().ship.vel = { 0, 0, 0 }
T.wait(100)
look_at(rel(b.hi[1] + 110, 60, 80), rel(b.mouth[1] - 20, 20, 0), 65)
shot("04_tractor_beam_pulling_in")
ap.wait_until(T, 1, function() return get().berth and get().berth.phase == "descend" end, 60 * 30)
look_at({ b.hi[1] + 26, b.floor + 14, b.pad[3] + 14 }, { b.pad[1], b.floor + 7, b.pad[3] }, 70)
shot("05_over_the_pad")
ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 20)
T.wait(80)
look_at({ b.hi[1] - 4, b.floor + 12, b.pad[3] + 24 }, { b.pad[1] - 8, b.floor + 4, b.pad[3] - 6 }, 75)
shot("06_hangar_bay_interior")
look_at({ b.lo[1] + 10, b.floor + 6, b.pad[3] + 26 }, { b.hi[1] - 6, b.floor + 4, b.pad[3] - 12 }, 75)
shot("06b_hangar_bay_interior_cranes_crates")
look_at({ b.pad[1] + 4, b.floor + 20, b.pad[3] - 8 }, { b.pad[1] + 10, b.hi[2], b.pad[3] + 20 }, 75)
shot("06c_hangar_ceiling")
-- walk in: concourse
ap.walk_to_station(T, 1, get, "hatch")
T.press(1, "use")
ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 8)
T.wait(10)
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
shot("07_on_foot_in_the_bay")
ap.ex_to(T, 1, get, { b.lo[1] + 0.2, b.floor, b.door.z }, 0.3, 3000)
T.wait(10)
shot("08_station_concourse")
get().station.body.yaw = sm.pi
T.axis(1, "move_z", 1, 90)
T.wait(80)
T.axis(1, "move_z", 0, 1)
shot("09_concourse_walking")
