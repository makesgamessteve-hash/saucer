-- SPDX-License-Identifier: MIT
-- add-fun-fixes: the "after" frames: readable HUD text on its plates, the light
-- Watcher at site 1, and a bolt hit with its juice (red frame, shake).
--   cd OUT && saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/funaudit/shots_after.lua
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_fun/after/"
local function snap(name) T.screenshot(D .. name .. ".png") print("FUNSHOT " .. T.state().tick .. " " .. name) end
local function shot(name) T.wait(2) snap(name) T.wait(1) end
local function look_at(q)
  local e = game.viewpoint(get())
  ap.look(T, 1, get, sm.atan2(q[1] - e[1], q[3] - e[3]), ap.pitch_to(e, q), 160)
end
local function last_hit()
  local t
  for _, f in ipairs(get().fx) do if f.sound == "hit" then t = f.tick end end
  return t
end

T.wait(30)
ap.wake(T, 1, get)
T.wait(20)
ap.take_helm(T, 1, get)
shot("01_helm_clear_dome_hud_plates")
-- a dead press: the denied line
T.press(1, "grapple")
shot("02_denied_feedback_text")
-- the Scanner's new job
T.press(1, "scan")
shot("03_scan_finds_readout")

local site = 1
local defs = game.sentries(site)
local wdef = defs[1]
print("FUNSHOT site1 sentries " .. #defs .. " light " .. tostring(wdef and wdef.light))
local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
ap.travel(T, 1, get, ap.route(ruin, origin, wdef.room)[1].pos, 4, 6000)
ap.enter(T, 1, get, ruin, origin, wdef.room)
ap.wait_until(T, 1, function() return T.state().sentries[site][1].st ~= "dormant" end, 900)
look_at(wdef.pos)
shot("10_site1_light_watcher_encounter")
ap.wait_until(T, 1, function() return T.state().sentries[site][1].st == "locked" end, 600)
look_at(wdef.pos)
shot("11_site1_light_watcher_locked")
local h0 = last_hit() or -1
ap.wait_until(T, 1, function() return (last_hit() or -1) > h0 end, 900)
T.wait(1)
snap("12_hit_juice_red_frame_hitstop")
T.wait(4)
snap("13_hit_juice_shake")
T.press(1, "camera") T.wait(6)
h0 = last_hit() or -1
ap.wait_until(T, 1, function() return (last_hit() or -1) > h0 end, 900)
T.wait(2)
snap("14_hit_juice_chase_cam")
T.press(1, "camera") T.wait(1)
-- the HUD's message log over the lit derelict
T.wait(30)
shot("15_hud_text_over_derelict")
print("FUNSHOT done hits " .. tostring(get().hits) .. " hull " .. get().ship.hull)
