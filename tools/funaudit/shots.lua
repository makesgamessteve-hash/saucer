-- SPDX-License-Identifier: MIT
-- Fun-audit visual frame audit: boot, peak tension, failure states.
--   cd OUT && saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/funaudit/shots.lua
-- Writes shots_fun/*.png and prints "FUNSHOT tick name" lines.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local vec = require("lib.vec")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_fun/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") print("FUNSHOT " .. T.state().tick .. " " .. name) T.wait(1) end
local function door_of(ruin, origin, room)
  return ap.door_center(ap.door_of(ruin, room), ruin.rooms, ruinm.kit_of(ruin.kit), origin)
end
local function look_at(q)
  local e = game.viewpoint(get())
  ap.look(T, 1, get, sm.atan2(q[1] - e[1], q[3] - e[3]), ap.pitch_to(e, q), 160)
end

T.screenshot(D .. "00_boot_first_frame.png") print("FUNSHOT 0 00_boot_first_frame")
T.wait(30)
shot("01_boot_title_card")
ap.wake(T, 1, get)
T.wait(20)
shot("02_first_control_bedroom")
ap.take_helm(T, 1, get)
shot("03_first_flight_helm")

-- peak tension: a Watcher locks the Villa, then a Snatcher siphons the Seat
local site
for i = 1, #T.state().sector.sites do
  local k = {}
  for _, d in ipairs(game.sentries(i)) do k[d.kind] = true end
  if k.watcher and k.snatcher then site = i break end
end
if site then
  local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
  local defs = game.sentries(site)
  local w, s
  for i, d in ipairs(defs) do
    if d.kind == "watcher" and not w then w = i end
    if d.kind == "snatcher" and not s then s = i end
  end
  local wdef, sdef = defs[w], defs[s]
  ap.travel(T, 1, get, ap.route(ruin, origin, wdef.room)[1].pos, 4, 6000)
  local _, route = ap.enter(T, 1, get, ruin, origin, wdef.room)
  ap.wait_until(T, 1, function() return T.state().sentries[site][w].st == "alert" end, 600)
  look_at(wdef.pos)
  shot("10_tension_watcher_alert_telegraph")
  ap.wait_until(T, 1, function() return T.state().sentries[site][w].st == "locked" end, 300)
  T.wait(50)
  look_at(wdef.pos)
  shot("11_peak_tension_watcher_locked_bolts")
  T.press(1, "camera") T.wait(10)
  shot("12_peak_tension_chase_cam_bolts")
  T.press(1, "camera") T.wait(1)
  ap.resize(T, 1, get, 2)
  ap.leave(T, 1, get, route, ap.route(ruin, origin, sdef.room, 2)[1].pos)
  _, route = ap.enter(T, 1, get, ruin, origin, sdef.nest_room, 2)
  ap.grab(T, 1, get, site, ruin, sdef.nest_room, door_of(ruin, origin, sdef.nest_room))
  ap.wait_until(T, 1, function() return T.state().sentries[site][s].st == "locked" end, 900)
  look_at(T.state().sentries[site][s].pos)
  shot("13_tension_snatcher_locked_loot_at_risk")
  ap.wait_until(T, 1, function() return T.state().sentries[site][s].st == "latched" end, 300)
  T.wait(60)
  shot("14_peak_tension_snatcher_siphoning")
  -- let it steal: failure state "loot lost"
  ap.wait_until(T, 1, function() return T.state().sentries[site][s].st == "flee" end, 400)
  T.wait(10)
  shot("20_failure_loot_stolen")
  -- failure state: Fold Retreat (hull gave out)
  get().ship.hull = 0
  T.wait(3)
  shot("21_failure_fold_retreat")
  T.wait(60)
  shot("22_after_retreat_control_back")
  ap.resize(T, 1, get, 1)
else
  print("FUNSHOT none: no site with both a Watcher and a Snatcher")
end

-- failure state: oxygen out on EVA -> forced emergency teleport
ap.take_helm(T, 1, get)
local PY = -520
local sp = get().ship.pos
local base = { sp[1], sp[2] + PY, sp[3] }
game.extra_solids[#game.extra_solids + 1] = { { base[1] - 140, base[2] - 20, base[3] - 140 }, { base[1] + 140, base[2], base[3] + 140 } }
saucer.physics.add_box({ base[1] - 140, base[2] - 20, base[3] - 140 }, { base[1] + 140, base[2], base[3] + 140 }, 1)
get().ship.pos = { base[1], base[2] + 40, base[3] }
T.press(1, "land")
ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 30)
ap.walk_to_station(T, 1, get, "hatch")
T.press(1, "use")
ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 12)
ap.walk_path(T, 1, get, { { 0, -3, -8.0 } }, 0.3, 1500)
ap.look(T, 1, get, sm.pi, 0, 300)
ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14)
ap.hold(T, 1, {})
if get().excursion then
  local from = vec.copy(get().excursion.body.pos)
  ap.push(T, 1, function() return vec.dist(get().excursion.body.pos, from) > 200 end, 60 * 40, { move_z = 1, lift = 0.35 })
  ap.hold(T, 1, {})
  get().eva.o2 = 12
  T.wait(10)
  shot("30_tension_oxygen_critical")
  get().eva.o2 = 0.2
  get().hands = { { name = "Relic" }, { name = "Crystal" } }
  T.wait(20)
  shot("31_failure_out_of_oxygen_teleport")
  T.wait(80)
  shot("32_failure_after_teleport")
end
print("FUNSHOT done")
