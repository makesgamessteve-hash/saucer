-- SPDX-License-Identifier: MIT
-- Screenshot tour for the Meshes group (OpenSpec add-mesh-builder). Run from
-- the folder that should receive shots/:
--   xvfb-run -a saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/meshes.lua
-- Staged by moving the player and the Villa (the script says so): the helm
-- console on foot, the Watcher and the Snatcher of derelict 2 from close by,
-- the Snatcher with its pincers open. The flat HUD stays on in these shots.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local sentry = require("sim.sentry")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots/"
local SHOTS = nil -- e.g. "01 03" while iterating
local function shot(name)
  if SHOTS and not SHOTS:find(name:sub(1, 2), 1, true) then return end
  T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1)
end
-- put the pilot's eye at `eye` looking at `at`
local function stage(eye, at)
  local s = get().ship
  s.vel = { 0, 0, 0 }
  s.pos = vec.copy(eye)
  T.wait(2)
  local e = game.viewpoint(get())
  s.pos = vec.add(s.pos, vec.sub(eye, e))
  T.wait(2)
  e = game.viewpoint(get())
  ap.look(T, 1, get, saucer.math.atan2(at[1] - e[1], at[3] - e[3]), ap.pitch_to(e, at), 30)
end

T.wait(30)
ap.wake(T, 1, get)
saucer.render.settings({ width = 1280, height = 720 })

-- the helm console on foot, close up: the lit panel, the size lever (right) and the throttle orb (left)
T.assert(ap.walk_to(T, 1, get, "helm"), "walked to the helm")
local L = require("sim.avatar").layout()
local desk
for _, fu in ipairs(L.furniture) do if fu.kind == "helm_desk" then desk = fu end end
local body = get().body
local home = vec.copy(body.pos)
local cx = (desk.box[1] + desk.box[3]) / 2
local function stand(x, back)
  ap.walk(T, 1, get, { x, home[2], desk.box[2] - back }, 0.12, 400)
end
stand(cx, 0.75)
ap.look(T, 1, get, 0, -0.62, 60)
shot("05_helm_console_lever_and_orb")
stand(cx + 0.85, 0.6)
ap.look(T, 1, get, 0, -0.95, 60)
shot("06_console_size_lever")
stand(cx - 0.85, 0.6)
ap.look(T, 1, get, 0, -0.95, 60)
shot("07_console_throttle_orb")
ap.look(T, 1, get, 0, 0, 60)
T.assert(ap.take_helm(T, 1, get), "in the seat")

local site = 2
local defs = game.sentries(site)
local w, s
for i, d in ipairs(defs) do
  if d.kind == "watcher" and not w then w = i end
  if d.kind == "snatcher" and not s then s = i end
end
T.assert(w and s, "site 2 has a Watcher and a Snatcher")
local wd = defs[w]

-- the Watcher, looking down its hall; then locked on, its head and eye turned toward you
local f = sentry.dir_of(wd.yaw, 0)
local dyn = T.state().sentries[site][w]
dyn.st = "dormant"
stage(vec.add(wd.pos, { f[1] * 5, -1.6, f[3] * 5 }), wd.pos)
shot("01_watcher_dormant")
dyn.yaw, dyn.pitch, dyn.st = wd.yaw + 0.7, -0.5, "locked"
stage(vec.add(wd.pos, { f[1] * 5, -1.6, f[3] * 5 }), wd.pos)
dyn.yaw, dyn.pitch, dyn.st = wd.yaw + 0.7, -0.5, "locked"
shot("02_watcher_head_and_eye_turned")

-- the Snatcher in its duct, then hunting with the pincers open
local sd = defs[s]
local sdyn = T.state().sentries[site][s]
local sf = sentry.dir_of(sdyn.yaw or sd.yaw or 0, 0)
-- (the Snatcher is moved into the Watcher's hall, where there is room for the camera)
local sp = vec.add(wd.pos, { f[1] * 2.6, -2.0, f[3] * 2.6 })
local eye = vec.add(wd.pos, { f[1] * 5.6, -1.2, f[3] * 5.6 })
local function put() sdyn.pos = vec.copy(sp); sdyn.yaw = wd.yaw + 3.14 + 0.5 end
dyn.st = "dormant"
put()
stage(eye, sp)
put()
shot("03_snatcher_patrolling")
sdyn.st = "chase"
put()
shot("04_snatcher_hunting_pincers_open")
sdyn.st = "dormant"

