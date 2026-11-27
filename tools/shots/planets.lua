-- SPDX-License-Identifier: MIT
-- add-generated-planets screenshots. Run from the folder that should receive shots:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/planets.lua
--   [--script-arg planet|moon|asteroid]
local T = saucer.test
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local planet = require("sim.planet")
local ap = require("sim.autopilot")
local R = require("view.render")
local hud = require("view.hud")
local sm = saucer.math
local free
local orig_cam = R.camera
R.camera = function(p, xr) if free then return free end return orig_cam(p, xr) end
hud.draw = function() return nil end
local function look(from, to, fov, far)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)),
           fov = fov or 62, near = 0.3, far = far or 400000 }
end
local BODY = (T.arg() ~= "" and T.arg()) or "planet"
local D = "after/" .. BODY .. "_"
local function p1() return T.state().players[1] end
local function shot(name)
  T.wait(48)
  T.screenshot(D .. name .. ".png")
  print("shot " .. D .. name)
  T.wait(1)
end
local function frame(from, to, fov, far)
  local d = { from[1] - to[1], from[2] - to[2], from[3] - to[3] }
  local l = math.max(1, sm.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3]))
  local s = p1().ship
  s.pos, s.vel, s.yaw, s.pitch, s.bank = { from[1] + d[1] / l * 40, from[2] + d[2] / l * 40, from[3] + d[3] / l * 40 }, { 0, 0, 0 }, 0, 0, 0
  s.charge = 100
  look(from, to, fov, far)
  T.wait(2)
end

T.wait(10)
ap.wake(T, 1, p1)
ap.take_helm(T, 1, p1)
local st = T.state()
local g = galaxy.generate(st.seed)
local sid
for id = 2, #g.sectors do
  if sector.city_of(st.seed, id) == "city_" .. BODY then sid = id break end
end
T.assert(sid, "a sector with a " .. BODY .. " city")
game.enter_sector(st, sid)
local site
for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
planet.activate(st)
local pl = planet.live()[1]
local p = game.mega_plan(st, site)
local fr, cx, cy, cz = p.frame, pl.cx, pl.gy, pl.cz
print(string.format("planet %s: R %.0f rim %.0f heart %.0f centre %.0f %.0f %.0f", BODY, pl.R, pl.rim, pl.heart, pl.cx, pl.cy, pl.cz))

-- midday
st.tick = math.floor(60 * R.CITY_DAY * 0.25)

-- 1. from space, a little sun-side, looking at the whole body
local dx, dz = cx, cz
local l = math.max(1, sm.sqrt(dx * dx + dz * dz))
local star = require("view.lights").star(st.seed, st.sector_id or sid)
local sd = star and star.dir or { dx / l, 0.4, dz / l }
local sl = math.max(0.2, sm.sqrt(sd[1] * sd[1] + sd[2] * sd[2] + sd[3] * sd[3]))
local back = pl.R * 2.4
frame({ pl.cx + sd[1] / sl * back, pl.cy + sd[2] / sl * back, pl.cz + sd[3] / sl * back },
      { pl.cx, pl.cy, pl.cz }, 48, 500000)
shot("01_from_space")

-- 2. from the approach (sector heart), high, the city sitting on the body
frame({ 0, fr.y + 12000, 0 }, { cx, fr.y + 400, cz }, 50, 500000)
shot("02_approach_from_sector")

-- 3. high over the core, looking out over the ring onto the terrain
frame({ cx, cy + 4000, cz }, { cx + dx / l * 18000, cy + 200, cz + dz / l * 18000 }, 62, 200000)
shot("03_high_over_core")

-- 4. the city's edge, slightly below street, looking along the surface
local ex, ez = cx + dx / l * (pl.rim + 400), cz + dz / l * (pl.rim + 400)
frame({ ex, cy - 40, ez }, { ex + dx / l * 4000, cy + 200, ez + dz / l * 4000 }, 70, 200000)
shot("04_edge_on_surface")

-- 5. street-level horizon toward the far side
frame({ cx + dx / l * 400, cy + 80, cz + dz / l * 400 }, { cx + dx / l * 9000, cy + 40, cz + dz / l * 9000 }, 68, 200000)
shot("05_street_horizon")

-- 6. night, high over the core
st.tick = math.floor(60 * R.CITY_DAY * 0.75)
frame({ cx, cy + 1800, cz }, { cx + dx / l * 12000, cy + 200, cz + dz / l * 12000 }, 62, 200000)
shot("06_high_over_core_night")

-- 7. night from space (same sun-side orbit)
frame({ pl.cx + sd[1] / sl * back, pl.cy + sd[2] / sl * back, pl.cz + sd[3] / sl * back },
      { pl.cx, pl.cy, pl.cz }, 48, 500000)
shot("07_from_space_night")

print("planet shots done")
