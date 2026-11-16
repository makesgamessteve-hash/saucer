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
-- 7. for real: fly the Villa into the tutorial derelict's second great hall
if want("07") then
  local hall
  for _, r in ipairs(r1.rooms) do if r.kind == "hall" and not hall then hall = r end end
  hall = hall or r1.rooms[1]
  place(vec.add(ruinm.entrance(r1, o1), { 0, 0, -120 }), 0, 0)
  local ok = ap.enter(T, 1, get, r1, o1, hall.id)
  print("entered hall", hall.id, ok)
  T.wait(30)
  shot("07_derelict_hall")
  T.press(1, "camera")
  ap.look(T, 1, get, get().ship.yaw - 0.6, -0.35, 240)
  shot("07c_derelict_hall_chase")
  T.press(1, "camera")
  ap.look(T, 1, get, get().ship.yaw + 1.2, 0.15, 240)
  shot("07b_derelict_hall_wall")
end
local function quiet() for _, p in ipairs(T.state().players) do p.msgs = {} end end
-- 8. staged: next to a station truss (lattice, solar wing) and inside a
-- station hall (pipes, crates, machinery, hazard frames), chase camera
if want("08") then
  local r2, o2 = game.ruin(2), st.sector.sites[2].pos
  local k2 = ruinm.kit_of(r2.kit)
  local tr = r2.solids[1]
  for _, s2 in ipairs(r2.solids) do
    if (s2[2][1] - s2[1][1]) + (s2[2][3] - s2[1][3]) > (tr[2][1] - tr[1][1]) + (tr[2][3] - tr[1][3]) then tr = s2 end
  end
  local tc = { (tr[1][1] + tr[2][1]) / 2, (tr[1][2] + tr[2][2]) / 2, (tr[1][3] + tr[2][3]) / 2 }
  place({ tc[1] + 55, tc[2] - 6, tc[3] - 25 }, -1.1, 0)
  look_at({ tc[1], tc[2] + 8, tc[3] })
  T.press(1, "camera")
  quiet()
  shot("08_station_truss")
  T.press(1, "camera")
  local hall
  for _, r in ipairs(r2.rooms) do if r.class >= 4 and r.kind ~= "shaft" and not hall then hall = r end end
  local mn, mx = ruinm.room_box(hall, k2, o2)
  place({ (mn[1] + mx[1]) / 2, mn[2] + 8, mn[3] + 37 }, 0, 0)
  look_at({ (mn[1] + mx[1]) / 2, mn[2] + 9, mx[3] - 4 })
  T.press(1, "camera")
  quiet()
  shot("08b_station_hall")
  T.press(1, "camera")
end
-- 9. staged: the city (site 3) up close: towers, window grids, bridges, roofs (chase camera)
if want("09") then
  local c, b = center_of(3)
  place({ b[2][1] + 50, b[2][2] - 30, c[3] }, -1.5708, 0)
  look_at({ c[1], b[2][2] - 40, c[3] })
  T.press(1, "camera")
  quiet()
  shot("09_city_towers")
  T.press(1, "camera")
end
-- 10. staged: inside a city plaza (planters, fountains, obelisks, overgrowth; chase camera)
if want("10") then
  local r3, o3 = game.ruin(3), st.sector.sites[3].pos
  local k3 = ruinm.kit_of(r3.kit)
  local plaza
  for _, r in ipairs(r3.rooms) do if r.class >= 4 and r.kind ~= "shaft" and not plaza then plaza = r end end
  local mn, mx = ruinm.room_box(plaza, k3, o3)
  place({ (mn[1] + mx[1]) / 2 - 8, mn[2] + 16, mn[3] + 14 }, 0, 0)
  ap.resize(T, 1, get, 2) -- the Seat's chase camera fits inside the plaza
  T.press(1, "camera")
  look_at({ (mn[1] + mx[1]) / 2, mn[2] + 2, (mn[3] + mx[3]) / 2 + 10 })
  quiet()
  shot("10_city_plaza")
  T.press(1, "camera")
end
print("detail tour done at tick", T.state().tick)
