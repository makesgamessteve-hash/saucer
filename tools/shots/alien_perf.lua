-- SPDX-License-Identifier: MIT
-- add-alien-stations frame budget. One scene per run (PHASE, set by tools/shots/alien_perf.sh with sed), FRAMES
-- drawn frames each, run with --frame-stats; works on the older megastructure too (for before/after):
--   orbit  the saucer circles the hangar mouth 450 m out, the hull filling the view (full detail, its lights)
--   wide   the whole station from afar
--   inside on foot in the market, turning round
--   wing   on foot in the alien wing's first chamber, turning round (the market when there is no wing)
local T = saucer.test
local ap = require("sim.autopilot")
local dock = require("sim.dock")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local sh = require("sim.stationhull")
local visit = require("sim.visit")
local R = require("view.render")
local sm = saucer.math
local get = function() return T.state().players[1] end
local PHASE = "orbit"
local FRAMES = 600
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 62, near = 0.3, far = 9000 }
end
T.wait(30)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local st = T.state()
local tp = st.sector.trader.pos
local L = sh.for_trader(st, 1)
local i = L.info
local e = i.extent
local c = { tp[1] + i.centre[1], tp[2] + i.centre[2], tp[3] + (i.centre[3] or 0) }
local b = dock.bay(st, 1)
local s = get().ship
if PHASE == "orbit" then
  for f = 1, FRAMES do
    local a = f / FRAMES * sm.pi * 0.8 - sm.pi * 0.4
    s.pos = { b.mouth[1] + 450 * sm.cos(a), b.mouth[2] + 60, b.mouth[3] + 450 * sm.sin(a) }
    s.vel = { 0, 0, 0 }
    s.yaw = sm.atan2(c[1] - s.pos[1], c[3] - s.pos[3])
    T.wait(1)
  end
elseif PHASE == "wide" then
  local len = math.max(e.hi[1] - e.lo[1], e.hi[3] - e.lo[3])
  for f = 1, FRAMES do
    local a = f / FRAMES * 0.6
    look_at({ c[1] + len * sm.cos(a), c[2] + len * 0.32, c[3] - len * sm.sin(a) }, c, 78)
    T.wait(1)
  end
else
  -- dock on the beam and walk in, as the tour does
  s.pos = { b.mouth[1] + 120, b.mouth[2] + 5, b.mouth[3] + 25 }
  s.vel = { 0, 0, 0 }
  T.wait(100)
  ap.wait_until(T, 1, function() return get().berth and get().berth.phase == "descend" end, 60 * 30)
  ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 20)
  T.wait(60)
  ap.walk_to_station(T, 1, get, "hatch")
  T.press(1, "use")
  ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 8)
  T.wait(10)
  ap.walk_path(T, 1, get, { { 0, -3, -8.2 } }, 0.3, 1500)
  ap.look(T, 1, get, sm.pi, 0, 300)
  ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14)
  ap.hold(T, 1, {})
  ap.ex_to(T, 1, get, { b.lo[1] + 0.2, b.floor, b.door.z }, 0.3, 3000)
  T.wait(20)
  local sta = get().station
  T.assert(sta, "on foot in the station")
  local I = visit.layout(st, get())
  local where
  for _, a in ipairs(I.areas) do
    if PHASE == "inside" and a.kind == "market" and not where then where = a end
    if PHASE == "wing" and a.kind == "chamber" and not where then where = a end
  end
  if not where then for _, a in ipairs(I.areas) do if a.kind == "market" then where = a end end end
  local bx = where.box
  sta.body.pos = { (bx[1] + bx[3]) / 2 + 0.3, 0, (bx[2] + bx[4]) / 2 + 0.3 }
  for f = 1, FRAMES do
    sta.body.yaw = f / FRAMES * sm.tau
    sta.body.pitch = 0.1
    T.wait(1)
  end
  print(string.format("perf %s: %s (%s), %d areas", PHASE, where.name, where.kind, #I.areas))
end
print(string.format("perf %s: %d frames, station %.0f x %.0f x %.0f m", PHASE, FRAMES, e.hi[1] - e.lo[1], e.hi[2] - e.lo[2], e.hi[3] - e.lo[3]))
