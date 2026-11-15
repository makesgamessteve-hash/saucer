-- SPDX-License-Identifier: MIT
-- Screenshot tour for milestone 2 (live-in interior). Run from the folder
-- that should receive shots_m2/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/m2.lua
local T = saucer.test
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local L = avatar.layout()
local get = function() return T.state().players[1] end
local D = "shots_m2/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end

T.wait(40)
shot("01_wake_title")
ap.wake(T, 1, get)
-- the bedroom door slides open as you walk up to it
ap.walk_path(T, 1, get, { { 1.0, -3.0, 4.4 }, { 1.0, -3.0, 6.6 }, { 2.2, -3.0, 7.4 } }, 0.3, 900)
ap.look(T, 1, get, 3.1416 - 0.08, -0.1)
T.wait(20)
shot("02a_bedroom_door_closed")
ap.walk_path(T, 1, get, { { 1.0, -3.0, 6.6 }, { 1.0, -3.0, 4.4 }, { 2.7, -3.0, 1.6 } }, 0.3, 900)
ap.walk_to(T, 1, get, "bed_door_s")
ap.walk(T, 1, get, { 2.7, -3.0, -1.2 }, 0.2, 600)
ap.look(T, 1, get, 0.0, -0.05)
T.wait(20)
shot("02b_bedroom_door_open")
T.press(1, "camera")
T.wait(25)
shot("02c_chase_exterior")
T.press(1, "camera")
T.wait(1)
ap.walk_to(T, 1, get, "kitchen")
ap.look(T, 1, get, 1.5708, -0.15)
T.press(1, "use")
T.wait(10)
shot("03_kitchen_cook")
ap.walk_to(T, 1, get, "lab")
ap.look(T, 1, get, 3.1416, -0.25)
shot("04_lab_bench")
ap.walk_to(T, 1, get, "helm")
T.press(1, "use")
T.wait(5)
ap.look(T, 1, get, 0, 0)
shot("05_helm_console")
-- fly toward the derelict a little so the radar and the view change
for _ = 1, 150 do ap.hold(T, 1, { move_z = 1 }) end
for _ = 1, 60 do ap.hold(T, 1, {}) end
shot("06_helm_flying")
T.press(1, "use")
T.wait(2)
ap.walk_path(T, 1, get, { { 0.0, 0.6, 3.0 }, { -1.0, 0.6, 0.5 } }, 0.3, 600)
ap.look(T, 1, get, -2.2, -0.05)
T.wait(10)
shot("07_living_room")
-- fold on foot: rooms pack away one by one, then the hull shrinks
T.press(1, "shrink", 1, true)
local frames = { 10, 22, 34, 46, 60, 80 }
local k = 1
for i = 1, 90 do
  T.wait(1)
  if i == frames[k] then
    T.screenshot(D .. string.format("08_fold_%02d.png", k))
    k = k + 1
  end
end
T.wait(20)
shot("09_seat")
T.press(1, "grow", 1, true)
local uf = { 40, 66, 80, 94, 104 }
k = 1
for i = 1, 110 do
  T.wait(1)
  if i == uf[k] then
    T.screenshot(D .. string.format("10_unfold_%02d.png", k))
    k = k + 1
  end
end
T.wait(30)
T.press(1, "use")
T.wait(2)
ap.walk_to(T, 1, get, "bed")
T.press(1, "use")
T.wait(5)
shot("11_bed_panel")
