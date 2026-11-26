-- SPDX-License-Identifier: MIT
-- add-civ-hulls: per-civ hull exterior comparison shots, HUD and cockpit out of frame. Run from the folder that should
-- receive shots_hulls/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/hulls.lua
-- 1. every sector's own trader station from 1.5 km off its box (the civ that built it: sim/hulldress.lua)
-- 2. the same station restyled by each civ of the roster, from 1.5 km and from 600 m
-- 3. a relic restyled by each civ, from 1.5 km and 500 m
-- Works on the code before add-civ-hulls too (the restyles then change nothing on the stations).
local T = saucer.test
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local civs = require("sim.civs")
local sh = require("sim.stationhull")
local ap = require("sim.autopilot")
local R = require("view.render")
local hud = require("view.hud")
local relicv = require("view.relic")
local shv = require("view.stationhull")
local sm = saucer.math
local free
local orig_cam = R.camera
R.camera = function(p, xr) if free then return free end return orig_cam(p, xr) end
hud.draw = function() return nil end
local D = "shots_hulls/"
local function p1() return T.state().players[1] end
local function look(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 62, near = 0.5, far = 20000 }
end
-- park the saucer just behind the camera (the world streams round it) and aim
local function frame(from, to, fov)
  local d = { from[1] - to[1], from[2] - to[2], from[3] - to[3] }
  local l = math.max(1, sm.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3]))
  local s = p1().ship
  s.pos, s.vel = { from[1] + d[1] / l * 40, from[2] + d[2] / l * 40, from[3] + d[3] / l * 40 }, { 0, 0, 0 }
  look(from, to, fov)
end
local function shot(name, wait)
  T.wait(wait or 30)
  T.screenshot(D .. name .. ".png")
  T.wait(1)
end
-- a view of the station's box from `dist` m off its side, a little above and ahead
local function station_view(idx, dist, tag)
  local st = T.state()
  local L = sh.for_trader(st, idx)
  local tr = (st.sector.traders or { st.sector.trader })[idx]
  local e = L.info.extent
  local c = { tr.pos[1] + (e.lo[1] + e.hi[1]) / 2, tr.pos[2] + (e.lo[2] + e.hi[2]) / 2, tr.pos[3] + (e.lo[3] + e.hi[3]) / 2 }
  local from = { c[1] + (e.hi[1] - e.lo[1]) * 0.35, c[2] + dist * 0.25, tr.pos[3] + e.lo[3] - dist }
  frame(from, c, 62)
  shot(tag, 45)
  return L
end

T.wait(10)
ap.wake(T, 1, p1)
ap.take_helm(T, 1, p1)
local st = T.state()
local g = galaxy.generate(st.seed)
local u = civs.universe(st.seed)
-- 1. each sector's station (the first sector of each builder)
local seen = {}
for sid = 1, #g.sectors do
  if sid ~= st.sector.id then game.enter_sector(st, sid) end
  local civ = sh.civ_for and sh.civ_for(st, 1)
  local key = civ and civ.id or tostring(sid)
  if not seen[key] then
    seen[key] = true
    local L = station_view(1, 1500, string.format("a%d_station_%s", sid, key))
    saucer.log.info(string.format("hulls: sector %d station civ=%s family=%s palette=%s motif=%s", sid, key, L.family,
      tostring(L.info.palette), tostring(L.info.motif)))
  end
end
-- 2. the home station restyled by every civ
game.enter_sector(st, 1)
for k, civ in ipairs(u) do
  if sh.set_style then sh.set_style(civ) shv.free_all() end
  station_view(1, 1500, string.format("b%d_%s_station_far", k, civ.id))
  station_view(1, 600, string.format("b%d_%s_station_near", k, civ.id))
end
if sh.set_style then sh.set_style(nil) shv.free_all() end
-- 3. a relic restyled by every civ (the first sector with one)
local rsid, ri
for sid = 1, #g.sectors do
  game.enter_sector(st, sid)
  for i, s in ipairs(st.sector.sites) do if s.relic then rsid, ri = sid, i end end
  if ri then break end
end
T.assert(ri, "a sector with a relic")
local site = st.sector.sites[ri]
local r = game.ruin(ri)
local set = relicv.meshes(r, site.pos)
local c = set.center
for k, civ in ipairs(u) do
  relicv.set_style(civ)
  local far = { c[1] + 1500 * 0.6, c[2] + 300, c[3] - 1500 * 0.8 }
  frame(far, c, 62)
  shot(string.format("c%d_%s_relic_far", k, civ.id), 40)
  local near = { c[1] + set.radius * 0.9 + 350, c[2] + 120, c[3] - set.radius * 0.9 - 350 }
  frame(near, c, 62)
  shot(string.format("c%d_%s_relic_near", k, civ.id), 60)
end
relicv.set_style(nil)
free = nil
saucer.log.info("hulls: done")
