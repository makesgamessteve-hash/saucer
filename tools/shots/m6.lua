-- SPDX-License-Identifier: MIT
-- Screenshot tour for milestone 6 (OpenSpec add-presentation-packaging): the
-- same vantage points before and after the art pass. Run from the folder that
-- should receive shots_m6/ (set SAUCER_SHOT_TAG=before|after via the dir):
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/m6.lua
-- The Villa is walked for real; outside, vantage points are staged by placing
-- the saucer (as in tools/shots/detail.lua and m5.lua).
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots_m6/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function quiet() for _, p in ipairs(T.state().players) do p.msgs = {} end end
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
local SHOTS = nil -- e.g. "03 04" while iterating
local function want(n) return not SHOTS or SHOTS:find(n, 1, true) end

T.wait(30)
if want("01") then shot("01_title") end
ap.wake(T, 1, get)
if want("02") then
  ap.walk_to(T, 1, get, "living")
  ap.walk(T, 1, get, { -1.4, 0.6, 1.2 }, 0.25, 600)
  ap.look(T, 1, get, -1.25, -0.22)
  shot("02_dome_living")
end
if want("03") then
  ap.walk_to(T, 1, get, "aft")
  ap.walk(T, 1, get, { 2.0, 0.6, -3.2 }, 0.25, 600)
  ap.look(T, 1, get, 1.1, -0.15)
  shot("03_dome_kitchen")
end
if want("04") then
  ap.walk_to(T, 1, get, "bed_door_n")
  ap.walk(T, 1, get, { 1.0, -3.0, 2.2 }, 0.25, 600)
  ap.look(T, 1, get, 0.75, -0.2)
  shot("04_lower_deck_bedroom")
end
ap.walk_to(T, 1, get, "helm")
ap.take_helm(T, 1, get)
local st = T.state()
local r1, o1 = game.ruin(1), st.sector.sites[1].pos
if want("05") then
  local hall
  for _, r in ipairs(r1.rooms) do if r.kind == "hall" and not hall then hall = r end end
  hall = hall or r1.rooms[1]
  place(vec.add(ruinm.entrance(r1, o1), { 0, 0, -120 }), 0, 0)
  ap.enter(T, 1, get, r1, o1, hall.id)
  T.wait(30)
  quiet()
  shot("05_derelict_hall")
  T.press(1, "camera")
  ap.look(T, 1, get, get().ship.yaw - 0.6, -0.35, 240)
  quiet()
  shot("05b_derelict_hall_chase")
  T.press(1, "camera")
end
if want("06") then
  local c, b = center_of(3)
  place({ b[2][1] + 50, b[2][2] - 30, c[3] }, -1.5708, 0)
  look_at({ c[1], b[2][2] - 40, c[3] })
  T.press(1, "camera")
  quiet()
  shot("06_city_towers")
  T.press(1, "camera")
  local r3, o3 = game.ruin(3), st.sector.sites[3].pos
  local k3 = ruinm.kit_of(r3.kit)
  local plaza
  for _, r in ipairs(r3.rooms) do if r.class >= 4 and r.kind ~= "shaft" and not plaza then plaza = r end end
  local mn, mx = ruinm.room_box(plaza, k3, o3)
  place({ (mn[1] + mx[1]) / 2 - 8, mn[2] + 16, mn[3] + 14 }, 0, 0)
  ap.resize(T, 1, get, 2)
  T.press(1, "camera")
  look_at({ (mn[1] + mx[1]) / 2, mn[2] + 2, (mn[3] + mx[3]) / 2 + 10 })
  quiet()
  shot("06b_city_plaza")
  T.press(1, "camera")
  ap.resize(T, 1, get, 1)
end
-- the station: pocket the saucer in the trader's hangar and walk in
local items = require("sim.items")
local visit = require("sim.visit")
local sg = require("sim.stationgen")
local p = get()
local tp = T.state().sector.trader.pos
p.ship.pos = { tp[1] + 60, tp[2], tp[3] + 60 }
p.ship.yaw = saucer.math.atan2(-1, -1)
T.wait(10)
if want("09") then
  ap.look(T, 1, get, p.ship.yaw + 2.6, 0.25, 240)
  quiet()
  shot("09_space_sky")
end
for _, t in ipairs({ { "coil", "Coil", 2 }, { "lens", "Lens", 1 } }) do
  local it = items.stamp(p, { type = t[1], name = t[2] }, t[3], "velari")
  it.hot = false
  p.hold[#p.hold + 1] = it
end
T.press(1, "size3")
T.wait(1)
local L = visit.layout(T.state(), get())
ap.wait_until(T, 1, function() return get().station and get().station.coin == "pocket" end, 600)
local foot = function() return { mode = "walk", body = get().station.body } end
local function face(x, z, pitch)
  local b = get().station.body
  ap.look(T, 1, foot, saucer.math.atan2(x - b.pos[1], z - b.pos[3]), pitch or 0, 300)
end
local market, bar
for _, a in ipairs(L.areas) do
  if a.kind == "market" then market = a end
  if a.kind == "bar" then bar = a end
end
if want("07") then
  ap.foot_to(T, 1, get, market.door_at[1] + (market.box[1] > 0 and 2.5 or -2.5), market.door_at[2] - 3)
  local c = sg.center(market)
  face(c[1] + (market.box[1] > 0 and 6 or -6), c[2] + 4, 0.05)
  quiet()
  shot("07_station_market")
end
if want("08") then
  ap.foot_to(T, 1, get, bar.door_at[1] + (bar.box[1] > 0 and 1.5 or -1.5), bar.door_at[2])
  local bc = L.bar.keeper
  face(bc[1], bc[2], 0.0)
  quiet()
  shot("08_bar_npcs")
end
print("m6 tour done at tick", T.state().tick)

