-- SPDX-License-Identifier: MIT
-- Screenshot tour for milestone 5 (OpenSpec add-pocket-station-visits). Run
-- from the folder that should receive shots_m5/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/m5.lua
-- Staged: the loot is put straight into the hold and the saucer starts next
-- to the trader station; everything else (pocketing, walking, trading, the
-- pickpocket, unfolding in the far hangar) is played for real.
local T = saucer.test
local ap = require("sim.autopilot")
local items = require("sim.items")
local visit = require("sim.visit")
local sg = require("sim.stationgen")
local get = function() return T.state().players[1] end
local D = "shots_m5/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
local foot = function() return { mode = "walk", body = get().station.body } end
local function face(x, z, pitch)
  local b = get().station.body
  ap.look(T, 1, foot, saucer.math.atan2(x - b.pos[1], z - b.pos[3]), pitch or 0, 300)
end
local SHOTS = nil -- e.g. "03 04" while iterating
local function want(n) return not SHOTS or SHOTS:find(n, 1, true) end

T.wait(20)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
-- staged: loot in the hold, parked by the trader station
local p = get()
for _, t in ipairs({ { "coil", "Coil", 2 }, { "plate", "Hull Plate", 1 }, { "lens", "Lens", 1 }, { "idol", "Idol", 2 } }) do
  local it = items.stamp(p, { type = t[1], name = t[2] }, t[3], "velari")
  it.hot = false
  p.hold[#p.hold + 1] = it
end
local tp = T.state().sector.trader.pos
p.ship.pos = { tp[1] + 60, tp[2], tp[3] + 60 }
p.ship.yaw = saucer.math.atan2(-1, -1)
T.wait(10)

-- 1. pocketing: the Villa folds down into your hand on the hangar floor
T.press(1, "size3")
T.wait(1)
local L = visit.layout(T.state(), get())
local pad = sg.hangars(L)[1].pad
T.wait(math.floor(60 * 2.4 * 0.42))
if want("01") then T.screenshot(D .. "01_pocketing_fold.png") end
ap.wait_until(T, 1, function() return get().station.coin == "pocket" end, 400)
-- take it out again and hold it in your fist (F)
T.press(1, "tractor")
T.wait(1)
face(pad[1] + 5, pad[2], -0.42)
if want("02") then shot("02_coin_in_hand") end
T.press(1, "tractor")
T.wait(2)

-- 2. the market hall
local market, bar
for _, a in ipairs(L.areas) do
  if a.kind == "market" then market = a end
  if a.kind == "bar" then bar = a end
end
local scrap
for _, s in ipairs(L.stalls) do if s.vendor == "scrap" then scrap = s end end
ap.foot_to(T, 1, get, market.door_at[1] + (market.box[1] > 0 and 2.5 or -2.5), market.door_at[2] - 3)
local c = sg.center(market)
face(c[1] + (market.box[1] > 0 and 6 or -6), c[2] + 4, 0.05)
if want("03") then shot("03_station_market") end

-- 3. an on-foot trade at the scrap dealer
ap.foot_use(T, 1, get, scrap.spot)
face(scrap.keeper[1], scrap.keeper[2], 0.12)
ap.pick(T, 1, get, "Sell Unknown")
T.axis(1, "move_z", -1, 1, true) T.wait(1) T.axis(1, "move_z", 0, 1, true) T.wait(1)
if want("05") then shot("05_trade_on_foot") end
ap.pick(T, 1, get, "Close")

-- 4. the bar and its regulars
ap.foot_to(T, 1, get, bar.door_at[1] + (bar.box[1] > 0 and 1.5 or -1.5), bar.door_at[2])
local bc = L.bar.keeper
face(bc[1], bc[2], 0.0)
if want("04") then shot("04_bar_npcs") end

-- 5. the pickpocket strikes: chase him down the concourse
ap.foot_use(T, 1, get, L.bar.spot)
ap.pick(T, 1, get, "Close")
ap.wait_until(T, 1, function() return get().station.coin == "thief" end, 60 * 90)
for _ = 1, 100 do
  if get().station.thief.mode ~= "flee" then break end
  local b = get().station.body
  local th = get().station.thief.pos
  local q = sg.route(L, { b.pos[1], b.pos[3] }, th)[1]
  local diff = saucer.math.wrap(saucer.math.atan2(q[1] - b.pos[1], q[2] - b.pos[3]) - b.yaw)
  for _, a in ipairs(ap.AXES) do T.axis(1, a, 0, 1, true) end
  T.axis(1, "turn", math.max(-1, math.min(1, -diff * 3)), 1, true)
  T.axis(1, "move_z", 0.8, 1, true)
  T.wait(1)
end
if want("06") then T.screenshot(D .. "06_pickpocket_chase.png") end
ap.chase(T, 1, get)

-- 6. unpocketing in the far hangar
local far = sg.hangars(L)[2]
local door = far.door_at
local inward = { far.pad[1] - door[1], far.pad[2] - door[2] }
local n = saucer.math.sqrt(inward[1] ^ 2 + inward[2] ^ 2)
ap.foot_to(T, 1, get, door[1] + inward[1] / n * 2.5, door[2] + inward[2] / n * 2.5, 0.6, 4000)
face(far.pad[1], far.pad[2], 0.12)
T.wait(5)
T.press(1, "size1")
T.wait(math.floor(60 * 2.2 * 0.55))
if want("07") then T.screenshot(D .. "07_unpocket_far_hangar.png") end
ap.wait_until(T, 1, function() return get().mode == "helm" end, 400)
T.wait(30)
if want("08") then shot("08_aboard_leaving") end
