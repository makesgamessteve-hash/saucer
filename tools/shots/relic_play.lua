-- SPDX-License-Identifier: MIT
-- add-relic-stations (plan phase 8): a relic in normal play, seed 42 sector 3 (no --relic-slice):
--   xvfb-run -a -s "-screen 0 1280x720x24" saucer --seed 42 --windowed --width 1280 --height 720 \
--     --script tools/shots/relic_play.lua
-- writes shots_relic_play/: approach.png (the relic from outside, 1.5 km), hall.png (a guarded hall with its decay),
-- heart.png, radar.png (the helm HUD with the explored rooms on the radar).
local T = saucer.test
local ap = require("sim.autopilot")
local game = require("sim.game")
local relic = require("sim.relic")
local ruinm = require("sim.ruin")
local R = require("view.render")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_relic_play/"
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function cam(pos, yaw, pitch, fov) free = { pos = pos, yaw = yaw, pitch = pitch or 0, fov = fov or 62, near = 0.3, far = 9000 } end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  cam(from, sm.atan2(dx, dz), sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov)
end
local hud = require("view.hud")
local hud_draw = hud.draw
local clean = true
hud.draw = function(...) if clean then return nil end return hud_draw(...) end
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function park(pos, yaw)
  local s = get().ship
  s.pos, s.vel, s.yaw = { pos[1], pos[2], pos[3] }, { 0, 0, 0 }, yaw or 0
end

T.wait(5)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
game.enter_sector(T.state(), 3)
T.wait(5)
local i
for k, s in ipairs(T.state().sector.sites) do if s.kit == "relic" then i = k end end
local site = T.state().sector.sites[i]
local r = game.ruin(i)
local kit = ruinm.kit_of(r.kit)
require("view.relic").BUILDS = 1000
local door = ruinm.entrance(r, site.pos)
local function centre(id)
  local mn, mx = ruinm.room_box(r.rooms[id], kit, site.pos)
  return { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }, mn, mx
end
saucer.log.info(string.format("relic_play: site %d civ %s rooms %d sentries %d slots %d", i, tostring(site.civ), #r.rooms,
  #game.sentries(i), #r.slots))

-- the approach: the scan picks it up
park({ door[1], door[2] + 100, door[3] - 1500 }, 0)
T.wait(20)
look_at({ door[1] + 300, door[2] + 260, door[3] - 1400 }, { door[1], door[2], door[3] + 200 }, 66)
T.wait(8)
shot("approach")

-- the guarded hall: the one holding the most sentries
local count = {}
for _, d in ipairs(game.sentries(i)) do if d.room then count[d.room] = (count[d.room] or 0) + 1 end end
local best, bn = r.relic.halls[2], -1
for _, h in ipairs(r.relic.halls) do if (count[h] or 0) > bn then best, bn = h, count[h] or 0 end end
for _, h in ipairs({ r.relic.halls[1], best }) do
  local c, mn = centre(h)
  park({ c[1], mn[2] + kit.wall + 8, c[3] }, 0)
  T.wait(12)
end
local c, mn, mx = centre(best)
look_at({ c[1] - (mx[1] - mn[1]) * 0.35, mn[2] + kit.wall + 14, mn[3] + 12 }, { c[1] + 10, mn[2] + kit.wall + 6, c[3] + 20 }, 78)
T.wait(8)
shot("hall")

-- the heart
local hc, hmn = centre(r.relic.core)
park({ hc[1], hmn[2] + kit.wall + 10, hc[3] }, 0)
T.wait(12)
look_at({ hc[1] - 60, hmn[2] + kit.wall + 20, hc[3] - 120 }, { hc[1], hmn[2] + 70, hc[3] }, 84)
T.wait(10)
shot("heart")

-- back in a hall, the HUD on: the radar outlines the explored rooms
free = nil
clean = false
park({ c[1], mn[2] + kit.wall + 8, c[3] }, 0)
T.wait(20)
shot("radar")
saucer.log.info(string.format("relic_play: rooms seen %d", #relic.rooms_seen(T.state(), i)))
