-- SPDX-License-Identifier: MIT
-- Before/after shots of every place a bubble/orb billboard is used. HUD off, free camera.
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script this
-- Relic-interior shots: add --relic-slice and --script-arg relic
local T = saucer.test
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local ap = require("sim.autopilot")
local R = require("view.render")
local hud = require("view.hud")
local dock = require("sim.dock")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")
local sm = saucer.math
local free
local orig_cam = R.camera
R.camera = function(p, xr) if free then return free end return orig_cam(p, xr) end
hud.draw = function() return nil end
local function p1() return T.state().players[1] end
local D = "shots_bubbles/"
local function look(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 62, near = 0.3, far = 20000 }
end
local function frame(from, to, fov)
  local d = { from[1] - to[1], from[2] - to[2], from[3] - to[3] }
  local l = math.max(1, sm.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3]))
  local s = p1().ship
  s.pos, s.vel = { from[1] + d[1] / l * 40, from[2] + d[2] / l * 40, from[3] + d[3] / l * 40 }, { 0, 0, 0 }
  s.yaw = sm.atan2(to[1] - from[1], to[3] - from[3])
  look(from, to, fov)
end
local function shot(name, wait)
  T.wait(wait or 30)
  T.screenshot(D .. name .. ".png")
  saucer.log.info("bubbles: " .. name)
  T.wait(1)
end

T.wait(10)
ap.wake(T, 1, p1)
ap.take_helm(T, 1, p1)
local st = T.state()
local arg = (T.arg and T.arg()) or ""

if arg == "relic" then
  local relic = require("sim.relic")
  local i = relic.site_index(st)
  T.assert(i ~= nil, "run with --relic-slice")
  local site = st.sector.sites[i]
  local r = game.ruin(i)
  local kit = ruinm.kit_of(r.kit)
  require("view.relic").BUILDS = 1000
  local function centre(id)
    local mn, mx = ruinm.room_box(r.rooms[id], kit, site.pos)
    return { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }, mn, mx
  end
  -- each phenomenon kind, from inside its room
  local seen = {}
  for _, ph in ipairs(r.relic.phenomena or {}) do
    if not seen[ph.kind] then
      seen[ph.kind] = true
      local c, mn, mx = centre(ph.room)
      local from = { c[1] + (mx[1] - mn[1]) * 0.25, mn[2] + 4, mn[3] + 3 }
      p1().ship.pos, p1().ship.vel = { c[1], c[2], c[3] }, { 0, 0, 0 }
      frame(from, c, 70)
      shot("r_" .. ph.kind, 40)
    end
  end
  -- engine heart / core
  local core = r.relic.core
  if core then
    local c, mn = centre(core)
    frame({ c[1], mn[2] + 6, c[3] - (c[3] - mn[2] and 18 or 18) }, c, 70)
    shot("r_engine", 40)
  end
  -- a lock socket if any
  if r.relic.locks and r.relic.locks[1] then
    local l = r.relic.locks[1]
    local sock = l.socket or l.pos
    if sock then
      frame({ sock[1] + 4, sock[2] + 1.5, sock[3] + 3 }, sock, 65)
      shot("r_lock", 30)
    end
  end
  saucer.log.info("bubbles: relic done")
  return
end

-- 1. sun + saucer thrusters in open space (a derelict in frame)
do
  local site1 = st.sector.sites[1]
  local r1 = game.ruin(1)
  local lo, hi = ruinm.bounds(r1, site1.pos, 0)
  local midp = { (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2 }
  local s = p1().ship
  s.pos = { midp[1] + 40, hi[2] + 20, lo[3] - 50 }
  s.vel = { 18, 4, -6 }
  s.yaw = 0.4
  look(vec.add(s.pos, { 28, 10, -30 }), vec.add(s.pos, { -8, -4, 16 }), 70)
  shot("01_sun_and_thrusters", 40)
  s.vel = { 0, 0, 0 }
end

-- 2. station hull signals from 1.5 km
do
  local sh = require("sim.stationhull")
  local L = sh.for_trader(st, 1)
  local tr = (st.sector.traders or { st.sector.trader })[1]
  local e = L.info.extent
  local c = { tr.pos[1] + (e.lo[1] + e.hi[1]) / 2, tr.pos[2] + (e.lo[2] + e.hi[2]) / 2, tr.pos[3] + (e.lo[3] + e.hi[3]) / 2 }
  frame({ c[1] + (e.hi[1] - e.lo[1]) * 0.35, c[2] + 1500 * 0.25, tr.pos[3] + e.lo[3] - 1500 }, c, 62)
  shot("02_station_signals", 45)
end

-- 3. hangar bay emitters (the dock force-field lights)
do
  local b = dock.bay(st, 1)
  if b then
    frame({ b.hi[1] + 18, b.floor + 10, b.pad[3] + 8 }, { b.pad[1], b.floor + 4, b.pad[3] }, 70)
    shot("03_dock_emitters", 35)
  end
end

-- 4. a Watcher hall: eye light + floor cone
do
  local site, wd = 2
  for _, d in ipairs(game.sentries(site) or {}) do if d.kind == "watcher" and not wd then wd = d end end
  if wd then
    p1().site = site
    local pos = wd.pos
    frame({ pos[1] + 8, pos[2] + 2.2, pos[3] + 10 }, { pos[1], pos[2] + 0.4, pos[3] }, 70)
    shot("04_sentry_cone", 35)
  end
end

-- 5. loot / echo markers inside the first derelict vault or a room with finds
do
  local finds = require("sim.finds")
  local ruin = game.ruin(1)
  local cands = finds.candidates(st, p1(), 1, ruin)
  if #cands == 0 then
    local loot = require("sim.game")
    -- fall back to tractor candidates (scrap, echoes)
    local tractor = require("sim.tractor")
    cands = tractor.candidates(st, p1(), 1, ruin) or {}
  end
  if cands[1] then
    local c = cands[1].pos
    frame({ c[1] + 3.5, c[2] + 1.6, c[3] + 4.5 }, c, 65)
    shot("05_loot_marker", 35)
  else
    saucer.log.info("bubbles: no loot candidates")
  end
end

-- 6-11. a planet city: swarm, pulses, drifters, organ core, warren lamps, sanctum heart
do
  local g = galaxy.generate(st.seed)
  local sid
  for id = 2, #g.sectors do
    if sector.city_of(st.seed, id) == "city_planet" then sid = id break end
  end
  T.assert(sid, "a sector with a planet city")
  game.enter_sector(st, sid)
  local site
  for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
  local p = game.mega_plan(st, site)
  local fr = p.frame
  local function mid(d) return { (d.box[1] + d.box[3]) / 2, fr.y, (d.box[2] + d.box[4]) / 2 } end
  -- swarm over a downtown-adjacent district
  local d0 = p.districts[1]
  local m0 = mid(d0)
  frame({ m0[1] + 90, fr.y + 70, m0[3] - 180 }, { m0[1], fr.y + 50, m0[3] }, 65)
  shot("06_city_swarm", 50)
  -- lane pulses
  if p.lanes and p.lanes[1] then
    local a, b = p.lanes[1].a, p.lanes[1].b
    if not a and p.city then
      -- mega plan may expose lanes differently; city.lanes is on the ruin
    end
  end
  local ruin = game.ruin(site)
  local lane = ruin.city and ruin.city.lanes and ruin.city.lanes[1]
  if lane then
    local midl = { (lane.a[1] + lane.b[1]) / 2, (lane.a[2] + lane.b[2]) / 2, (lane.a[3] + lane.b[3]) / 2 }
    frame({ midl[1] + 80, midl[2] + 40, midl[3] - 200 }, midl, 60)
    shot("07_city_pulses", 45)
  end
  -- drifter
  local megav = require("view.citymega")
  local tt = (T.state().tick + 2 + 40) / 60
  local o = megav.drift_pose(p, p.districts[1], 1, tt)
  frame({ o.pos[1] - 25, o.pos[2] + 10, o.pos[3] - 110 }, o.pos, 60)
  shot("08_city_drifter", 45)
  -- organ hall core
  local od
  for _, d in ipairs(p.districts) do if d.organ and not od then od = d end end
  if od then
    local og, h = od.organ, od.organ.hall
    local c = og.centre
    local from
    if og.side == 1 then from = { h[1] + 12, fr.y + 14, c[3] } elseif og.side == 2 then from = { h[4] - 12, fr.y + 14, c[3] }
    elseif og.side == 3 then from = { c[1], fr.y + 14, h[3] + 12 } else from = { c[1], fr.y + 14, h[6] - 12 } end
    frame(from, c, 75)
    shot("09_organ_core", 45)
  end
  -- warren lamps + sanctum heart
  local wd
  for _, d in ipairs(p.districts) do if d.warren and not wd then wd = d end end
  if wd then
    local w = wd.warren
    local hub = w.spaces[1]
    local hx, hz = (hub[1] + hub[3]) / 2, (hub[2] + hub[4]) / 2
    local sc = w.sanctum
    frame({ hx, w.y0 + 22, hz }, { sc[1], sc[2], sc[3] }, 70)
    shot("10_warren_lamps", 45)
    local dx, dz = sc[1] - hx, sc[3] - hz
    local l = math.max(1, sm.sqrt(dx * dx + dz * dz))
    frame({ sc[1] - dx / l * (sc.size * 0.45), w.y0 + 14, sc[3] - dz / l * (sc.size * 0.45) }, { sc[1], sc[2], sc[3] }, 75)
    shot("11_sanctum_heart", 45)
  end
end

-- 12. site lamps close up: stand near a city or station lamp (already in city; also catch a derelict lamp)
-- already covered somewhat by warren; add a terrace/avenue lamp if organs have nearby fixtures - skip if nothing unique

saucer.log.info("bubbles: done")
