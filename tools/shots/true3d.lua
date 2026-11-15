-- SPDX-License-Identifier: MIT
-- Screenshot tour for true 3D flight (OpenSpec add-true-3d-flight). Run from
-- the folder that should receive shots_3d/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/true3d.lua
-- Flying into the tutorial derelict and its shaft is played for real; the
-- outside vantage points (above, below, the city) are staged by placing the
-- saucer, which the script says where it does.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots_3d/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
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
ap.take_helm(T, 1, get)
local st = T.state()
local r1, o1 = game.ruin(1), st.sector.sites[1].pos

-- 1. staged: hovering above the tutorial derelict, looking down past the helm
if want("01") then
  local c, b = center_of(1)
  place({ c[1] - 40, b[2][2] + 70, b[1][3] + 60 }, 0.25, -0.55)
  T.press(1, "camera")
  shot("01_above_derelict")
  T.press(1, "camera")
end
-- 2. staged: below it, looking up at its underside
if want("02") then
  local c, b = center_of(1)
  place({ c[1] - 40, b[1][2] - 45, b[1][3] + 50 }, 0.35, 0.95)
  shot("02_below_derelict")
end
-- 3-4. for real: fly the Villa into the derelict to its first shaft, then look up and down it
local shaft
for _, r in ipairs(r1.rooms) do if r.kind == "shaft" and not shaft then shaft = r end end
if shaft and (want("03") or want("04")) then
  place(vec.add(ruinm.entrance(r1, o1), { 0, 0, -120 }), 0, 0)
  local ok = ap.enter(T, 1, get, r1, o1, shaft.id)
  print("entered shaft", ok)
  local k = ruinm.kit_of(r1.kit)
  local mn, mx = ruinm.room_box(shaft, k, o1)
  local s = get().ship
  if want("03") then
    ap.look(T, 1, get, s.yaw, 1.3, 240)
    shot("03_shaft_looking_up")
  end
  if want("04") then
    -- the Villa's floor hides what is below it: fold to the Seat near the top
    -- of the shaft and look down it over the Seat's shoulder (chase camera)
    local top = { (mn[1] + mx[1]) / 2, mx[2] - k.wall - 10, (mn[3] + mx[3]) / 2 }
    ap.fly(T, 1, get, top, 2, 1500)
    ap.resize(T, 1, get, 2)
    ap.look(T, 1, get, get().ship.yaw, -1.2, 240)
    T.press(1, "camera")
    shot("04_shaft_looking_down")
    T.press(1, "camera")
    ap.resize(T, 1, get, 1)
  end
end
-- 5. staged: the floating city of site 3 from a distance, sprawling up and down
if want("05") then
  local c, b = center_of(3)
  local dz = b[2][3] - b[1][3]
  place({ c[1] + 140, c[2] - 90, b[1][3] - dz * 0.6 }, 0, 0)
  look_at({ c[1], c[2] + 30, c[3] })
  shot("05_city_vertical")
end
-- 6. the 3D radar on the helm desk: contacts on stalks above and below the disc
if want("06") then
  local c = center_of(1)
  place({ c[1] + 300, c[2] + 160, c[3] - 700 }, -0.4, -0.7)
  shot("06_helm_3d_radar")
end
-- 7. for real: fold to the Seat and squeeze into a tight duct
if want("07") then
  local duct
  for _, r in ipairs(r1.rooms) do if r.class == 1 and not duct then duct = r end end
  place(vec.add(ruinm.entrance(r1, o1), { 0, 0, -120 }), 0, 0)
  local route = ap.route(r1, o1, duct.id)
  local n = #route
  ap.follow(T, 1, get, { table.unpack(route, 1, n - 3) }, 1500)
  ap.resize(T, 1, get, 2)
  ap.follow(T, 1, get, { table.unpack(route, n - 2, n - 1) }, 1500)
  shot("07_seat_in_duct")
end
-- 8. a banked climbing turn outside: the whole saucer leans into it
if want("08") then
  local c, b = center_of(1)
  place({ c[1] + 160, c[2] + 40, b[1][3] - 220 }, -0.5, 0.0)
  ap.resize(T, 1, get, 1)
  T.press(1, "camera")
  for _ = 1, 50 do
    T.axis(1, "turn", 0.6, 1, true)
    T.axis(1, "move_x", 1, 1, true)
    T.axis(1, "move_z", 1, 1, true)
    T.axis(1, "lift", 0.6, 1, true)
    T.wait(1)
  end
  T.screenshot(D .. "08_banked_climb.png")
  T.press(1, "camera")
end
print("true3d tour done at tick", T.state().tick)
