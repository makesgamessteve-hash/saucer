-- SPDX-License-Identifier: MIT
-- Screenshots of the optional affine (PS1-style) texture warp, off and on, for the Renderer group
-- (OpenSpec add-retro-renderer-basic, 1.4). Run from the folder that should receive shots/:
--   xvfb-run -a saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/renderer.lua
-- The Villa's rooms are walked for real; the derelict hall is staged by placing the saucer (the
-- script says so). Every view is taken twice from the same pose: warp off, then warp on.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local sentry = require("sim.sentry")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots/"
local function pair(name)
  for _, on in ipairs({ 0, 1 }) do
    saucer.render.settings({ affine = on })
    T.wait(3)
    T.screenshot(D .. name .. (on == 1 and "_warp_on" or "_warp_off") .. ".png")
    T.wait(1)
  end
  saucer.render.settings({ affine = 0 })
end

T.wait(30)
ap.wake(T, 1, get)
saucer.render.settings({ width = 1280, height = 720, affine = 0 })

-- the living room floor and wall at a low angle: the textures swim most on big near polygons
T.assert(ap.walk_to(T, 1, get, "living"), "walked to the living room")
ap.walk(T, 1, get, { -1.4, 0.6, 1.2 }, 0.25, 600)
ap.look(T, 1, get, -1.85, -0.35)
pair("01_living_room")
ap.look(T, 1, get, 0.6, -0.5)
pair("02_living_room_floor")

-- the derelict hall, from the Watcher's end (staged)
T.assert(ap.take_helm(T, 1, get), "in the seat")
local site = 2
local defs = game.sentries(site)
local wd
for _, d in ipairs(defs) do if d.kind == "watcher" and not wd then wd = d end end
T.assert(wd, "site 2 has a Watcher")
local f = sentry.dir_of(wd.yaw, 0)
local s = get().ship
s.vel = { 0, 0, 0 }
s.pos = vec.add(wd.pos, { f[1] * 7, -2.2, f[3] * 7 })
T.wait(2)
local e = game.viewpoint(get())
s.pos = vec.add(s.pos, vec.sub(vec.add(wd.pos, { f[1] * 7, -2.2, f[3] * 7 }), e))
T.wait(2)
e = game.viewpoint(get())
ap.look(T, 1, get, saucer.math.atan2(wd.pos[1] - e[1], wd.pos[3] - e[3]), -0.45, 60)
pair("03_derelict_hall")
ap.look(T, 1, get, saucer.math.atan2(wd.pos[1] - e[1], wd.pos[3] - e[3]) + 1.2, -0.3, 60)
pair("04_derelict_wall")
