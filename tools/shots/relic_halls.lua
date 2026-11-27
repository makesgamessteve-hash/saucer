-- SPDX-License-Identifier: MIT
-- relic-shape-fixes: stills inside the curved halls of seed 42 sector 3's relic (its builders, the Voaeth, wearing
-- the organism massing: the spiral) and in its decay hall (hall 13: quartz over the whole skin, ascension fate), for
-- before/after comparison of the wall dressing and the calmed decay crystal. Run once per tree:
--   xvfb-run -a -s "-screen 0 1280x720x24" saucer --root TREE --seed 42 --windowed --width 1024 --height 576 \
--     --script tools/shots/relic_halls.lua      (writes ./shots_relic_halls/<name>.png)
local OUT = "shots_relic_halls/"
local PART = nil   -- "corner" or "decay": only those (one set a run: a long run in software GL can crash; sed the value)
local SHOTS = {
  { name = "corner_arc5_across", eye = { 4329, -112, -3031 }, at = { 4377, -105, -3031 }, fov = 85 },
  { name = "corner_arc5_along", eye = { 4329, -112, -3050 }, at = { 4329, -108, -2990 }, fov = 85 },
  { name = "corner_arc9", eye = { 4329, -184, -2611 }, at = { 4285, -180, -2655 }, fov = 80 },
  { name = "corner_arc6_across", eye = { 4329, -112, -2891 }, at = { 4281, -105, -2891 }, fov = 85 },
  { name = "decay_west", eye = { 4040, -259, -2891 }, at = { 3990, -250, -2891 } },
  { name = "decay_up", eye = { 4050, -262, -2891 }, at = { 4050, -200, -2891 }, fov = 90 },
  { name = "decay_ne", eye = { 4050, -262, -2891 }, at = { 4097, -235, -2843 }, fov = 90 },
}
local T = saucer.test
local ap = require("sim.autopilot")
local game = require("sim.game")
local civs = require("sim.civs")
local R = require("view.render")
local relicv = require("view.relic")
local sm = saucer.math
local get = function() return T.state().players[1] end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
require("view.hud").draw = function() return nil end
require("sim.sentry").step = function() end            -- (the sentries stand still)
for _, c in ipairs(civs.universe(42)) do if c.id == "voaeth" then c.massing = "organism" end end
T.wait(5)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
game.enter_sector(T.state(), 3)
T.wait(5)
relicv.BUILDS = 1000
relicv.HOPS = 8
relicv.SHOW_GHOST = false   -- (the ghost Villa of a Seat hangs in the hall: out of the frame)
local Lt = require("sim.lights").of(get())
Lt.head, Lt.flood = true, true
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 75, near = 0.3,
           far = 9000 }
end
for _, sh in ipairs(SHOTS) do
 if not PART or sh.name:find("^" .. PART) then
  local dx, dz = sh.at[1] - sh.eye[1], sh.at[3] - sh.eye[3]
  local d = sm.sqrt(dx * dx + dz * dz)
  if d < 1e-3 then dx, dz, d = -1, 0, 1 end   -- (a look straight up: the saucer goes back along -x)
  local back = sh.back or 14
  -- the saucer (and its lamps) behind the eye, out of the frame
  local s = get().ship
  s.pos, s.vel, s.yaw = { sh.eye[1] - dx / d * back, sh.eye[2] - 5, sh.eye[3] - dz / d * back }, { 0, 0, 0 }, sm.atan2(dx, dz)
  T.wait(20)
  look_at(sh.eye, sh.at, sh.fov)
  T.wait(8)
  T.screenshot(OUT .. sh.name .. ".png")
  T.wait(2)
 end
end
