-- SPDX-License-Identifier: MIT
-- Screenshot tour for add-dock-land-eva slice 1 (hull door and landing gear). Run from the folder that
-- should receive shots_eva/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/eva.lua
-- The exterior shots use a staged free camera (render.camera is wrapped for the run).
local T = saucer.test
local ap = require("sim.autopilot")
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
-- a camera round the saucer: `ang` radians from the aft direction, `dist` m away, `h` above the ship
local function orbit(ang, dist, h, pitch)
  local s = get().ship
  local a = s.yaw + sm.pi + ang
  cam({ s.pos[1] + sm.sin(a) * dist, s.pos[2] + h, s.pos[3] + sm.cos(a) * dist }, a + sm.pi, pitch)
end

T.wait(40)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local p = get()
local PY = -520
saucer.physics.add_box({ -80, PY - 20, -80 }, { 80, PY, 80 }, 1)
saucer.physics.add_box({ -80, PY, -80 }, { -20, PY + 9, -20 }, 1)
p.ship.pos = { 0, PY + 22, 0 }
p.ship.yaw = 0.7
T.wait(5)
T.press(1, "land")
T.wait(40)
orbit(1.2, 38, -8, 0.05)
shot("01_gear_swinging_out")
ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 30)
orbit(1.2, 38, -2, 0.0)
shot("02_landed_side")
ap.walk_to_station(T, 1, get, "hatch")
T.press(1, "use")
ap.wait_until(T, 1, function() return get().door.open > 0.5 end, 60 * 8)
orbit(0.35, 30, -3, 0.0)
shot("03_hatch_opening")
ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 8)
T.wait(10)
orbit(0.3, 30, -3, 0.0)
shot("04_stairs_out")
orbit(0.6, 16, -5.5, -0.1)
shot("04b_stairs_close")
free = nil
ap.walk_path(T, 1, get, { { 0, -3, -5.5 } }, 0.3, 1500)
ap.look(T, 1, get, sm.pi, -0.18, 300)
shot("05_inside_door_open")
ap.walk_path(T, 1, get, { { 0, -3, -8.2 } }, 0.3, 1500)
ap.look(T, 1, get, sm.pi, -0.45, 300)
shot("06_top_of_stairs")
ap.look(T, 1, get, sm.pi, 0, 300)
ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14)
T.wait(10)
local b = get().excursion.body
ap.look(T, 1, get, b.yaw + sm.pi, 0.15, 300)
shot("07_outside_looking_back")
