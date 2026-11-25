-- SPDX-License-Identifier: MIT
-- add-alien-cities-2 (plan phase 10 part 2) screenshots. Run from the folder that should receive shots_megacity/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/megacity.lua
--   [--script-arg planet|moon|asteroid]
-- The ring from over the core, a canyon avenue, the city's megaform, the footprint from high up and a lit block
-- close by. Staged: a free camera with the HUD and cockpit out of frame (the saucer waits just behind the camera).
local T = saucer.test
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local ap = require("sim.autopilot")
local R = require("view.render")
local hud = require("view.hud")
local sm = saucer.math
local free
local orig_cam = R.camera
R.camera = function(p, xr) if free then return free end return orig_cam(p, xr) end
hud.draw = function() return nil end
local function look(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 62, near = 0.3, far = 12000 }
end
local BODY = (T.arg() ~= "" and T.arg()) or "planet"
local D = "shots_megacity/" .. BODY .. "_"
local function p1() return T.state().players[1] end
local function shot(name)
  -- let the streaming catch up (a few districts a frame)
  T.wait(40)
  T.screenshot(D .. name .. ".png")
  local m = R.stats and R.stats.mega
  if m then print(string.format("  %s: full %d lights %d sil %d culled %d built %d", name, m.full, m.lights, m.sil, m.culled, m.built)) end
  T.wait(1)
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
local p = game.mega_plan(st, site)
local fr = p.frame
local function frame(from, to, fov)
  local d = { from[1] - to[1], from[2] - to[2], from[3] - to[3] }
  local l = math.max(1, sm.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3]))
  local s = p1().ship
  s.pos, s.vel, s.yaw, s.pitch, s.bank = { from[1] + d[1] / l * 30, from[2] + d[2] / l * 30, from[3] + d[3] / l * 30 }, { 0, 0, 0 }, 0, 0, 0
  s.charge = 100
  look(from, to, fov)
  T.wait(2)
end
local function mid(d) return { (d.box[1] + d.box[3]) / 2, fr.y, (d.box[2] + d.box[4]) / 2 } end
-- the megaform and the district farthest from the core
local mf, md
for _, d in ipairs(p.districts) do
  for _, o in ipairs(d.organs) do if o.megaform then mf, md = o, d end end
end
print(string.format("megacity %s: %d core + %d outer districts, span %.0f m, megaform %d m", BODY, #game.ruin(site).city.districts,
  #p.districts, p.span, mf and mf.h or 0))

-- 1. the ring from high over the core, looking out at the megaform's district
local tgt = md and mid(md) or { fr.cx + 6000, fr.y, fr.cz }
frame({ fr.cx, fr.y + 900, fr.cz }, { tgt[1], fr.y + 500, tgt[3] })
shot("01_ring_from_core")

-- 2. a canyon avenue: between two neighbouring outer districts, low, looking down the gap
local a, b
for _, x in ipairs(p.districts) do
  for _, y in ipairs(p.districts) do
    if not a and y.ix == x.ix + 1 and y.iz == x.iz then a, b = x, y end
  end
end
if a then
  local gx = (a.box[3] + b.box[1]) / 2
  frame({ gx, fr.y + 140, a.box[2] - 200 }, { gx, fr.y + 260, a.box[4] + 1500 }, 70)
  shot("02_canyon")
end

-- 3. the megaform from 1.8 km, low
if mf then
  local c = { mf.x0 + mf.w / 2, fr.y, mf.z0 + mf.w2 / 2 }
  local dir = { c[1] - fr.cx, c[3] - fr.cz }
  local l = sm.sqrt(dir[1] * dir[1] + dir[2] * dir[2])
  frame({ c[1] - dir[1] / l * 1800, fr.y + 200, c[3] - dir[2] / l * 1800 }, { c[1], fr.y + mf.h * 0.45, c[3] }, 70)
  shot("03_megaform")
end

-- 4. the footprint from high up: core, ring and horizon band
frame({ fr.cx - p.span * 0.35, fr.y + 5500, fr.cz - p.span * 0.35 }, { fr.cx + p.span * 0.1, fr.y, fr.cz + p.span * 0.1 }, 70)
shot("04_footprint")

-- 5. a lit block close by: the nearest outer district to the core, from 400 m
local near, nd
for _, d in ipairs(p.districts) do
  local m = mid(d)
  local dd = (m[1] - fr.cx) ^ 2 + (m[3] - fr.cz) ^ 2
  if not nd or dd < nd then near, nd = d, dd end
end
local o = near.organs[1]
frame({ o.x0 - 380, fr.y + 160, o.z0 - 380 }, { o.x0 + o.w / 2, fr.y + o.h * 0.4, o.z0 + o.w2 / 2 }, 70)
shot("05_lit_block")
print("megacity shots done")
