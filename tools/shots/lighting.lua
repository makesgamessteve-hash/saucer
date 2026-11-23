-- SPDX-License-Identifier: MIT
-- Screenshot tour for add-realistic-lighting: tools/shots/lighting.sh BIN REPO OUTDIR [ONLY], or from the folder
-- that should receive shots_light/:
--   xvfb-run -a saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/lighting.lua
-- Staged: the saucer and a free camera are placed (the rules are tested in tests/game/lighting.lua). On a build
-- without the light model (the "before" shots) the light switches are simply missing and those shots repeat.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local sentry = require("sim.sentry")
local dock = require("sim.dock")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local ruinm = require("sim.ruin")
local R = require("view.render")
local vec = require("lib.vec")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_light/"
local only = nil -- a name fragment: take only the shots whose name holds it (tools/shots/lighting.sh)
local function shot(name)
  if only and not name:find(only, 1, true) then return end
  T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1)
end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function cam(pos, yaw, pitch, fov) free = { pos = pos, yaw = yaw, pitch = pitch or 0, fov = fov or 62, near = 0.1, far = 4000 } end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  cam(from, sm.atan2(dx, dz), sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov)
end
-- the light switches (add-realistic-lighting); nil on a build without them
local function lights(head, flood, cabin)
  local l = get().lights
  if not l then return false end
  l.head, l.flood, l.cabin = head, flood, cabin
  return true
end

T.wait(30)
ap.wake(T, 1, get)
-- 1. the Villa's living room, cabin lights on, then off
T.assert(ap.walk_to(T, 1, get, "living"), "walked to the living room")
ap.walk(T, 1, get, { -1.4, 0.6, 1.2 }, 0.25, 600)
ap.look(T, 1, get, -1.85, -0.25)
lights(false, false, true)
shot("01_villa_cabin_lights_on")
lights(false, false, false)
shot("02_villa_cabin_lights_off")
lights(false, false, true)
-- the lower deck (bedroom), lights on and off
T.assert(ap.take_helm(T, 1, get), "in the seat")

-- 2. outside in the sun: the saucer beside the tutorial derelict, chase view from a little way off
local s = get().ship
local site1 = T.state().sector.sites[1]
local r1 = game.ruin(1)
local lo, hi = ruinm.bounds(r1, site1.pos, 0)
s.vel = { 0, 0, 0 }
s.pos = { (lo[1] + hi[1]) / 2 + 40, hi[2] + 25, lo[3] - 60 }
s.yaw = 0.4
T.wait(20)
look_at(vec.add(s.pos, { 30, 14, -38 }), vec.add(s.pos, { -10, -8, 30 }), 70)
shot("03_sunlit_exterior_saucer_and_derelict")
look_at(vec.add(s.pos, { -60, 50, -120 }), { (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2 }, 60)
shot("04_sunlit_exterior_derelict_shadows")
free = nil

-- 3. a derelict hall in the dark: headlights, then floods (staged at site 2's first Watcher)
local site = 2
local wd
for _, d in ipairs(game.sentries(site)) do if d.kind == "watcher" and not wd then wd = d end end
T.assert(wd, "site 2 has a Watcher")
local f = sentry.dir_of(wd.yaw, 0)
local function stage()
  s.vel = { 0, 0, 0 }
  s.pos = vec.add(wd.pos, { f[1] * 26, -2.0, f[3] * 26 })
  s.yaw = sm.atan2(-f[1], -f[3])
  T.wait(2)
end
stage()
lights(false, false, false)
look_at(vec.add(s.pos, vec.add({ f[1] * 9, 7, f[3] * 9 }, { 0, 0, 0 })), vec.add(wd.pos, { 0, -3, 0 }), 72)
shot("05_ruin_dark_no_saucer_lights")
lights(true, false, false)
stage()
shot("06_ruin_headlights")
lights(true, true, false)
stage()
shot("07_ruin_headlights_and_floods")
look_at(vec.add(s.pos, { f[1] * 14 + 6, 10, f[3] * 14 + 6 }), s.pos, 75)
shot("08_ruin_floods_around_the_saucer")
lights(false, false, true)
free = nil

-- 4. the station: the hangar bay inside the megastructure (staged on the pad)
local b = dock.bay(T.state(), 1)
s.vel = { 0, 0, 0 }
s.pos = { b.pad[1], b.floor + 4, b.pad[3] }
T.wait(10)
look_at({ b.hi[1] - 4, b.floor + 12, b.pad[3] + 24 }, { b.pad[1] - 8, b.floor + 4, b.pad[3] - 6 }, 75)
shot("09_station_hangar_interior")
look_at({ b.lo[1] + 10, b.floor + 6, b.pad[3] + 26 }, { b.hi[1] - 6, b.floor + 4, b.pad[3] - 12 }, 75)
shot("10_station_hangar_interior_b")
local tp = T.state().sector.trader.pos
look_at({ tp[1] + 300, tp[2] + 90, tp[3] - 260 }, { tp[1] - 380, tp[2] + 40, tp[3] }, 70)
shot("11_station_exterior_sunlit")
free = nil

-- 5. an alien city: inside its biggest landmark hall, lit by its own coloured lamps
local st = T.state()
local g = galaxy.generate(st.seed)
local sid
for id = 2, #g.sectors do
  if sector.city_of(st.seed, id) == "city_planet" then sid = id break end
end
if sid then
  game.enter_sector(st, sid)
  local csite
  for i, cs in ipairs(st.sector.sites) do if cs.city then csite = i end end
  local ruin = game.ruin(csite)
  local kit = ruinm.kit_of(ruin.kit)
  local o = st.sector.sites[csite].pos
  local want = { reactor = 1, palace = 2, archive = 3, foundry = 4, garden = 5, spaceport = 9 }
  local pick
  for _, d in ipairs(ruin.city.districts) do
    if want[d.kind] and (not pick or want[d.kind] < want[pick.kind]) then pick = d end
  end
  local hall
  for _, r in ipairs(ruin.rooms) do
    if r.district == pick.id and r.class >= 4 then
      local mn, mx = ruinm.room_box(r, kit, o)
      local c = { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
      local d = vec.dist(c, pick.pos)
      if not hall or d < hall.d then hall = { d = d, c = c, mn = mn, mx = mx } end
    end
  end
  local sp = get().ship
  sp.pos, sp.vel, sp.yaw, sp.pitch, sp.bank = { hall.c[1], hall.mn[2] + 7, hall.c[3] - 8 }, { 0, 0, 0 }, 0, 0.05, 0
  sp.charge = 100
  lights(false, false, false)
  T.wait(20)
  shot("12_alien_city_hall_coloured_lights")
  local low
  for _, r in ipairs(ruin.rooms) do
    local mn, mx = ruinm.room_box(r, kit, o)
    if r.class >= 4 and (not low or mn[2] < low.mn[2]) then low = { mn = mn, mx = mx } end
  end
  sp.pos = { (low.mn[1] + low.mx[1]) / 2, low.mn[2] + 5, (low.mn[3] + low.mx[3]) / 2 - 6 }
  sp.vel = { 0, 0, 0 }
  T.wait(20)
  shot("13_alien_city_undercity")
  lights(true, false, false)
  shot("14_alien_city_undercity_headlights")
end
print("lighting shots done")
