-- SPDX-License-Identifier: MIT
-- Screenshot tour for the detail pass (OpenSpec add-detail-pass). Run from
-- the folder that should receive shots_detail/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/detail.lua
-- Inside the Villa everything is walked for real. Outside, the vantage
-- points are staged by placing the saucer; flying into the derelict hall is
-- played for real.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots_detail/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function look_at(q)
  local e = game.viewpoint(get())
  ap.look(T, 1, get, saucer.math.atan2(q[1] - e[1], q[3] - e[3]), ap.pitch_to(e, q), 240)
end
local function place(pos, yaw, pitch)
  local s = get().ship
  s.pos, s.vel, s.yaw, s.pitch, s.bank = vec.copy(pos), { 0, 0, 0 }, yaw or s.yaw, pitch or 0, 0
  T.wait(2)
end
local function center_of(i)
  local b = game.site_bounds(i)
  return { (b[1][1] + b[2][1]) / 2, (b[1][2] + b[2][2]) / 2, (b[1][3] + b[2][3]) / 2 }, b
end
local SHOTS = nil -- set to e.g. "03 04" while iterating on a few shots
local function want(n) return not SHOTS or SHOTS:find(n, 1, true) end

T.wait(30)
ap.wake(T, 1, get)
-- 1. the living room: sofa cushions, bookshelf, floor lamp, holo projector, dome frame
if want("01") then
  ap.walk_to(T, 1, get, "living")
  ap.walk(T, 1, get, { -1.4, 0.6, 1.2 }, 0.25, 600)
  ap.look(T, 1, get, -1.85, -0.12)
  shot("01_living_room")
end
-- 2. the kitchen: stove, sink, wall cabinets, pendant lamps over the island
if want("02") then
  ap.walk_to(T, 1, get, "aft")
  ap.walk(T, 1, get, { 2.0, 0.6, -3.2 }, 0.25, 600)
  ap.look(T, 1, get, 1.1, -0.15)
  shot("02_kitchen")
end
-- 3. the lower deck engine room: pipes, tanks, rotors, pistons, ceiling ribs
if want("03") then
  ap.walk_to(T, 1, get, "engine_e")
  ap.walk(T, 1, get, { 3.6, -3.0, -5.6 }, 0.25, 600)
  ap.look(T, 1, get, -0.76, 0.1)
  shot("03_engine_room")
end
-- 4. the bedroom: pillows, throw, reading lights, painting, lamp
if want("04") then
  ap.walk_to(T, 1, get, "bed_door_n")
  ap.walk(T, 1, get, { 1.0, -3.0, 2.2 }, 0.25, 600)
  ap.look(T, 1, get, 0.75, -0.2)
  shot("04_bedroom")
end
-- 5. the bathroom: basin, mirror, towels, tiles
if want("05") then
  ap.walk_to(T, 1, get, "bath_door_n")
  ap.walk(T, 1, get, { -1.2, -3.0, 2.0 }, 0.25, 600)
  ap.look(T, 1, get, -0.9, -0.25)
  shot("05_bathroom")
end
ap.walk_to(T, 1, get, "helm")
ap.take_helm(T, 1, get)
local st = T.state()
local r1, o1 = game.ruin(1), st.sector.sites[1].pos
-- 6. outside: the hull from behind and above (chase camera), thrusters lit
if want("06") then
  local c, b = center_of(1)
  place({ c[1] + 160, c[2] + 40, b[1][3] - 260 }, -0.3, 0.0)
  T.press(1, "camera")
  for _ = 1, 40 do
    T.axis(1, "move_z", 1, 1, true)
    T.axis(1, "lift", 0.5, 1, true)
    T.wait(1)
  end
  T.screenshot(D .. "06_saucer_exterior.png")
  T.press(1, "camera")
end
print("detail tour done at tick", T.state().tick)
