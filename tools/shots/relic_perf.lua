-- SPDX-License-Identifier: MIT
-- add-material-system / add-relic-stations frame budget: FRAMES frames flying the Vyrr relic from the maw down the
-- spine into the Core (the camera on rails, the saucer riding along), with materials set from --script-arg
-- (full, lite or off). Run with --relic-slice --frame-stats; tools/shots/relic_perf.sh runs full and off and
-- prints their work-time p95 and the ratio.
local T = saucer.test
local ap = require("sim.autopilot")
local relic = require("sim.relic")
local game = require("sim.game")
local ruinm = require("sim.ruin")
local R = require("view.render")
local sm = saucer.math
local get = function() return T.state().players[1] end
local FRAMES = 600
local mode = (T.arg and T.arg()) or "full"
saucer.render.settings({ materials = mode })
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 70, near = 0.3, far = 9000 }
end
T.wait(20)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local st = T.state()
local i = relic.site_index(st)
T.assert(i ~= nil, "run with --relic-slice")
local site = st.sector.sites[i]
local r = game.ruin(i)
local kit = ruinm.kit_of(r.kit)
local door = ruinm.entrance(r, site.pos)
local core = r.rooms[r.relic.core]
local cmn, cmx = ruinm.room_box(core, kit, site.pos)
local a = { door[1], door[2] + 6, door[3] - 120 }
local b = { (cmn[1] + cmx[1]) / 2, door[2] + 6, (cmn[3] + cmx[3]) / 2 }
for f = 1, FRAMES do
  local t = (f - 1) / (FRAMES - 1)
  local pos = { a[1] + (b[1] - a[1]) * t + 14 * sm.sin(t * 9), a[2] + 4 * sm.sin(t * 5), a[3] + (b[3] - a[3]) * t }
  local s = get().ship
  s.pos, s.vel, s.yaw = { pos[1], pos[2] - 4, pos[3] + 30 }, { 0, 0, 0 }, 0
  look_at(pos, { pos[1] - 10 * sm.sin(t * 7), pos[2] - 2, pos[3] + 60 }, 72)
  T.wait(1)
end
saucer.log.info("perf relic: materials=" .. mode .. " frames=" .. FRAMES)
