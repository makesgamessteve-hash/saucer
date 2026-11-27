-- SPDX-License-Identifier: MIT
-- add-generated-planets v2 screenshots: smooth globes and concentric cities.
-- Run from the folder that should receive shots:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/planets_v2.lua
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
local function p1() return T.state().players[1] end
local function shot(name)
  T.wait(48)
  T.screenshot(name .. ".png")
  print("shot " .. name)
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
  if sector.city_of(st.seed, id) == "city_planet" then sid = id break end
end
T.assert(sid, "a sector with a planet city")
game.enter_sector(st, sid)
local site
for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
planet.activate(st)
local pl = planet.live()[1]
local p = game.mega_plan(st, site)
local r = game.ruin(site)
local fr, cx, cy, cz = p.frame, pl.cx, pl.gy, pl.cz
print(string.format("planet: R %.0f rim %.0f heart %.0f centre %.0f %.0f %.0f", pl.R, pl.rim, pl.heart, pl.cx, pl.cy, pl.cz))

st.tick = math.floor(60 * R.CITY_DAY * 0.25)

local dx, dz = cx, cz
local l = math.max(1, sm.sqrt(dx * dx + dz * dz))
local star = require("view.lights").star(st.seed, st.sector_id or sid)
local sd = star and star.dir or { dx / l, 0.4, dz / l }
local sl = math.max(0.2, sm.sqrt(sd[1] * sd[1] + sd[2] * sd[2] + sd[3] * sd[3]))

-- 1. from space, far: the whole globe, a round limb
local far = pl.R * 4.2
frame({ pl.cx + sd[1] / sl * far, pl.cy + sd[2] / sl * far, pl.cz + sd[3] / sl * far },
      { pl.cx, pl.cy, pl.cz }, 42, 600000)
shot("01_from_space_far")

-- 2. from space, close: the limb and the surface
local close = pl.R * 1.7
frame({ pl.cx + sd[1] / sl * close, pl.cy + sd[2] / sl * close, pl.cz + sd[3] / sl * close },
      { pl.cx, pl.cy, pl.cz }, 50, 500000)
shot("02_from_space_close")

-- 3-4. the concentric city from above. City fog is thick at altitude, so these
-- shots use a thinner density (shot-only) and a lower, slightly oblique camera.
local saved_fog = R.FOG
R.FOG = 0.00016
-- high and wide enough to read the circular footprint and the rings
frame({ cx + 3200, cy + 5200, cz + 2800 }, { cx, cy + 50, cz }, 52, 250000)
shot("03_city_from_above")

frame({ cx + 1600, cy + 900, cz + 400 }, { cx - 200, cy + 80, cz }, 62, 200000)
shot("04_city_from_above_oblique")
R.FOG = saved_fog

-- street-level views in two or three districts, looking toward the core
local byrole = {}
for _, d in ipairs(r.city.districts) do
  if d.role and not byrole[d.role] then byrole[d.role] = d end
end
local function street(d, name, height)
  if not d then return end
  local px, pz = d.pos[1], d.pos[3]
  local vx, vz = px - cx, pz - cz
  local vl = math.max(80, sm.sqrt(vx * vx + vz * vz))
  -- offset to the side and up, so the camera is in the street, not inside the landmark
  local ox, oz = -vz / vl * 90, vx / vl * 90
  frame({ px + ox, cy + (height or 42), pz + oz },
        { cx * 0.15 + px * 0.85, cy + 50, cz * 0.15 + pz * 0.85 }, 68, 80000)
  shot(name)
end
-- the core: from the plaza, look up at the crown of towers
do
  frame({ cx + 90, cy + 10, cz + 140 }, { cx - 120, cy + 220, cz - 40 }, 70, 80000)
  shot("05_street_core")
end
street(byrole.market or byrole.civic, "06_street_market", 16)
street(byrole.residential or byrole.industrial, "07_street_residential", 16)

print("planet v2 shots done")
