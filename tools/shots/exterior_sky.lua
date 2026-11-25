-- SPDX-License-Identifier: MIT
-- add-material-system 5.3: the relic slice from outside (its metals reflect the sector sky) -> shots_materials/exterior_sky*.png
--   saucer --root REPO --seed 42 --relic-slice --windowed --width 1280 --height 720 --script REPO/tools/shots/exterior_sky.lua
local T = saucer.test
local relic = require("sim.relic")
local game = require("sim.game")
local ruinm = require("sim.ruin")
local R = require("view.render")
local sm = saucer.math
require("view.hud").draw = function() end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
T.wait(20)
local i = relic.site_index(T.state())
local site = T.state().sector.sites[i]
local r = game.ruin(i)
local door = ruinm.entrance(r, site.pos)
require("view.relic").BUILDS = 1000
local function look(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov, near = 0.3, far = 9000 }
end
look({ door[1] + 46, door[2] + 9, door[3] - 84 }, { door[1] - 2, door[2] + 3, door[3] + 4 }, 66)
T.wait(20)
T.screenshot("shots_materials/exterior_sky.png")
T.wait(3)
look({ door[1] + 90, door[2] + 40, door[3] - 140 }, { door[1], door[2], door[3] + 40 }, 66)
T.wait(20)
T.screenshot("shots_materials/exterior_sky_far.png")
T.wait(3)
