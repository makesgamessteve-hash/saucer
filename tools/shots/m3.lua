-- SPDX-License-Identifier: MIT
-- Screenshot tour for milestone 3 (one sector loop). Run from the folder
-- that should receive shots_m3/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/m3.lua
-- The loot, lab, trade and sentry shots are played for real. The vault shots
-- at the end are staged: the script sets the mystery flags instead of running
-- the whole chain (tests/game/mystery.lua plays that part).
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local get = function() return T.state().players[1] end
local D = "shots_m3/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
local function door_of(ruin, origin, room)
  return ap.door_center(ap.door_of(ruin, room), ruin.rooms, ruinm.kit_of(ruin.kit), origin)
end
local function look_at(q)
  local e = game.viewpoint(get())
  ap.look(T, 1, get, saucer.math.atan2(q[1] - e[1], q[3] - e[3]), ap.pitch_to(e, q), 160)
end

T.wait(30)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
-- the tutorial vault: unknown loot
local r1, o1 = game.ruin(1), T.state().sector.sites[1].pos
local vault
for _, r in ipairs(r1.rooms) do if r.kind == "vault" then vault = r end end
local _, route = ap.enter(T, 1, get, r1, o1, vault.id)
local tractor = require("sim.tractor")
local c = tractor.candidates(T.state(), get(), 1, r1)
for _, x in ipairs(c) do if x.room == vault.id and x.kind == "slot" then look_at(x.pos) break end end
T.wait(10)
shot("01_unknown_loot")
ap.grab(T, 1, get, 1, r1, vault.id, door_of(r1, o1, vault.id))
ap.leave(T, 1, get, route)
-- the lab bench: identify and decode
ap.walk_to_station(T, 1, get, "lab")
T.press(1, "use")
T.wait(1)
ap.pick(T, 1, get, "Identify")
ap.pick(T, 1, get, "Decode")
T.wait(30)
shot("02_lab_bench")
ap.pick(T, 1, get, "Close")
-- to the trader, dock, trade terminal
ap.take_helm(T, 1, get)
local tp = T.state().sector.trader.pos
ap.travel(T, 1, get, { tp[1] + 50, tp[2], tp[3] + 50 }, 6, 6000)
look_at(tp)
T.wait(20)
shot("03_docked_trader")
ap.wait_until(T, 1, function() return #get().lab.queue == 0 end, 60 * 90)
ap.walk_to_station(T, 1, get, "trade")
T.press(1, "use")
T.wait(1)
shot("04_trade_terminal")
ap.pick(T, 1, get, "Sell")
T.wait(5)
shot("05_trade_sold")
ap.pick(T, 1, get, "Close")
-- derelict 2: scan, then the Villa in a Watcher's hall
ap.take_helm(T, 1, get)
local site = 2
local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
local defs = game.sentries(site)
local w, s
for i, d in ipairs(defs) do
  if d.kind == "watcher" and not w then w = i end
  if d.kind == "snatcher" and not s then s = i end
end
local wdef, sdef = defs[w], defs[s]
ap.travel(T, 1, get, ap.route(ruin, origin, wdef.room)[1].pos, 4, 6000)
look_at(origin)
T.press(1, "scan")
T.wait(20)
shot("06_scan_derelict")
_, route = ap.enter(T, 1, get, ruin, origin, wdef.room)
ap.wait_until(T, 1, function() return T.state().sentries[site][w].st == "alert" end, 600)
look_at(wdef.pos)
shot("07_watcher_alert")
ap.wait_until(T, 1, function() return T.state().scan_ready == nil and false or T.state().tick >= get().scan_ready end, 600)
T.press(1, "scan")
ap.wait_until(T, 1, function() return T.state().sentries[site][w].st == "locked" end, 300)
T.wait(50)
look_at(wdef.pos)
shot("08_watcher_locked_cones")
T.press(1, "camera")
T.wait(10)
shot("09_watcher_bolts_chase")
T.press(1, "camera")
T.wait(1)
-- the Seat is below its band; into the duct for hot loot and a Snatcher
ap.resize(T, 1, get, 2)
ap.leave(T, 1, get, route, ap.route(ruin, origin, sdef.room, 2)[1].pos)
_, route = ap.enter(T, 1, get, ruin, origin, sdef.nest_room, 2)
ap.grab(T, 1, get, site, ruin, sdef.nest_room, door_of(ruin, origin, sdef.nest_room))
ap.wait_until(T, 1, function() return T.state().sentries[site][s].st == "locked" end, 900)
look_at(T.state().sentries[site][s].pos)
shot("10_snatcher_locked")
ap.wait_until(T, 1, function() return T.state().sentries[site][s].st == "latched" end, 300)
T.wait(60)
shot("11_snatcher_siphoning")
T.press(1, "jam")
T.wait(8)
shot("12_jammed")
-- staged: the Resonant vault, closed and then open with its Curio
ap.leave(T, 1, get, route)
ap.resize(T, 1, get, 1)
local m = T.state().mystery
m.vault_revealed = true
local vp = T.state().vault.pos
ap.travel(T, 1, get, { vp[1] - 30, vp[2] + 4, vp[3] - 60 }, 6, 6000)
look_at(vp)
T.wait(10)
shot("13_resonant_vault")
m.vault_open, m.solved = true, true
local cp = { vp[1], vp[2] + 2, vp[3] }
local eye_up = game.viewpoint(get())[2] - get().ship.pos[2]
ap.fly(T, 1, get, { cp[1], cp[2] - eye_up, cp[3] - 25 }, 0.8, 1500, cp)
look_at(cp)
T.wait(10)
shot("14_vault_open_curio")
T.press(1, "tractor")
T.wait(60)
shot("15_curio_teaser")
