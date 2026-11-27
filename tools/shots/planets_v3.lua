-- SPDX-License-Identifier: MIT
-- add-generated-planets v3 screenshots: shader-lit globes, terminator, ring roads.
-- Run from the folder that should receive shots:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/planets_v3.lua
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
require("view.planet").warmup(st)
local pl = planet.live()[1]
local p = game.mega_plan(st, site)
local r = game.ruin(site)
local cx, cy, cz = pl.cx, pl.gy, pl.cz
print(string.format("planet: R %.0f rim %.0f heart %.0f centre %.0f %.0f %.0f", pl.R, pl.rim, pl.heart, pl.cx, pl.cy, pl.cz))

st.tick = math.floor(60 * R.CITY_DAY * 0.25)

local star = require("view.lights").star(st.seed, st.sector_id or sid)
local sd = star and star.dir or { 0.6, 0.35, 0.4 }
local sl = math.max(0.2, sm.sqrt(sd[1] * sd[1] + sd[2] * sd[2] + sd[3] * sd[3]))
sd = { sd[1] / sl, sd[2] / sl, sd[3] / sl }
-- a view axis nearly at right angles to the sun, so the terminator crosses the disk
local px, pz = -sd[3], sd[1]
local pln = math.max(0.2, sm.sqrt(px * px + pz * pz))
px, pz = px / pln, pz / pln
local function side_pos(dist, up)
  return {
    pl.cx + px * dist * 0.62 + sd[1] * dist * 0.62,
    pl.cy + up * dist,
    pl.cz + pz * dist * 0.62 + sd[3] * dist * 0.62,
  }
end

-- 1. from space, far: the whole globe, terminator across the disk
frame(side_pos(pl.R * 4.2, 0.18), { pl.cx, pl.cy, pl.cz }, 42, 600000)
shot("01_from_space_far")

-- 2. from space, close: the ice cap, a coast, the terminator and a specular sea
frame(side_pos(pl.R * 2.05, 0.42), { pl.cx, pl.cy + pl.R * 0.72, pl.cz }, 44, 500000)
shot("02_from_space_close")

-- 3. city from above: ring roads and the centre spire
frame({ cx + 2400, cy + 5800, cz + 1800 }, { cx, cy + 40, cz }, 50, 250000)
shot("03_city_from_above")

-- 4. oblique over the downtown
frame({ cx + 2200, cy + 1100, cz + 600 }, { cx - 200, cy + 80, cz }, 60, 200000)
shot("04_city_from_above_oblique")

-- street-level views in three districts
local byrole = {}
for _, d in ipairs(r.city.districts) do
  if d.role and not byrole[d.role] then byrole[d.role] = d end
end
local function street(d, name, height)
  if not d then return end
  local px, pz = d.pos[1], d.pos[3]
  local vx, vz = px - cx, pz - cz
  local vl = math.max(80, sm.sqrt(vx * vx + vz * vz))
  local ox, oz = -vz / vl * 110, vx / vl * 110
  frame({ px + ox, cy + (height or 18), pz + oz },
        { cx * 0.2 + px * 0.8, cy + 40, cz * 0.2 + pz * 0.8 }, 68, 80000)
  shot(name)
end
-- core: from the plaza, look up at the landmark spire and the crown of towers
do
  frame({ cx + 200, cy + 24, cz + 220 }, { cx, cy + 150, cz }, 62, 80000)
  shot("05_street_core")
end
street(byrole.civic or byrole.market, "06_street_civic", 16)
street(byrole.market or byrole.residential, "07_street_market", 16)
street(byrole.industrial or byrole.residential, "08_street_industrial", 16)

-- 9. city edge: look out over the planet's hills and coast, city behind
do
  local ux, uz = cx, cz
  local ul = math.max(1, sm.sqrt(ux * ux + uz * uz))
  local ex = cx + ux / ul * (pl.rim + 900)
  local ez = cz + uz / ul * (pl.rim + 900)
  -- if that lands in the heart bay, go the other way
  if planet.in_heart(pl, ex, ez) then
    ex = cx - ux / ul * (pl.rim + 900)
    ez = cz - uz / ul * (pl.rim + 900)
  end
  local ox, oz = -(ez - cz), ex - cx
  local ol = math.max(1, sm.sqrt(ox * ox + oz * oz))
  frame({ ex + ox / ol * 480, cy + 70, ez + oz / ol * 480 },
        { ex + ox / ol * 80 + ux / ul * 2200, cy - 30, ez + oz / ol * 80 + uz / ul * 2200 }, 58, 150000)
  shot("09_city_edge")
end

print("planet v3 shots done")
