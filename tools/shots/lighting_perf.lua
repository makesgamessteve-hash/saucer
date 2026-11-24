-- SPDX-License-Identifier: MIT
-- add-realistic-lighting perf loop: 4 staged scenes x FRAMES frames (Villa interior, sunlit exterior by the
-- station, a derelict hall with headlights and floods on, a planet city hall). Run with --frame-stats:
--   xvfb-run -a saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --frame-stats [--shadows q] \
--     --script REPO/tools/shots/lighting_perf.lua
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local sentry = require("sim.sentry")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")
local sm = saucer.math
local get = function() return T.state().players[1] end
local FRAMES = 240
local function lights(h, f, c) local l = get().lights if l then l.head, l.flood, l.cabin = h, f, c end end
T.wait(30)
ap.wake(T, 1, get)
T.assert(ap.walk_to(T, 1, get, "living"), "walked to the living room")
ap.look(T, 1, get, -1.85, -0.25)
lights(false, false, true)
T.wait(FRAMES)
T.assert(ap.take_helm(T, 1, get), "in the seat")
local s = get().ship
local tp = T.state().sector.trader.pos
s.vel = { 0, 0, 0 }
s.pos = { tp[1] + 190, tp[2] + 80, tp[3] - 215 }
s.yaw = sm.atan2(-0.9, 0.36)
T.wait(FRAMES)
local wd
for _, d in ipairs(game.sentries(2)) do if d.kind == "watcher" and not wd then wd = d end end
local f = sentry.dir_of(wd.yaw, 0)
s.vel = { 0, 0, 0 }
s.pos = vec.add(wd.pos, { f[1] * 20, -2.0, f[3] * 20 })
s.yaw = sm.atan2(-f[1], -f[3])
lights(true, true, true)
T.wait(FRAMES)
local st = T.state()
local g = galaxy.generate(st.seed)
for id = 2, #g.sectors do
  if sector.city_of(st.seed, id) == "city_planet" then game.enter_sector(st, id) break end
end
local csite
for i, cs in ipairs(st.sector.sites) do if cs.city then csite = i end end
local ruin = game.ruin(csite)
local kit = ruinm.kit_of(ruin.kit)
local o = st.sector.sites[csite].pos
local big
for _, r in ipairs(ruin.rooms) do
  if r.class >= 4 then
    local mn, mx = ruinm.room_box(r, kit, o)
    big = { mn = mn, mx = mx }
    break
  end
end
get().ship.pos = { (big.mn[1] + big.mx[1]) / 2, big.mn[2] + 7, (big.mn[3] + big.mx[3]) / 2 }
get().ship.vel = { 0, 0, 0 }
lights(true, false, true)
T.wait(FRAMES)
print("lighting perf done")
