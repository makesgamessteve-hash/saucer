-- SPDX-License-Identifier: MIT
-- Screenshot tour for add-alien-stations (works on the older megastructure too, for before/after). Run from the
-- folder that should receive shots_alien/ (OUT below):
--   saucer --root REPO --seed S --windowed --width 1280 --height 720 --script REPO/tools/shots/alien.lua
-- Exterior: the whole station from afar, the saucer in front of it for scale, the hangar approach and a close
-- look at the body; then docked, on foot: the bay, the concourse and up to four chambers of the inside.
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
local D = "shots_alien/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function cam(pos, yaw, pitch, fov) free = { pos = pos, yaw = yaw, pitch = pitch or 0, fov = fov or 62, near = 0.3, far = 9000 } end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  cam(from, sm.atan2(dx, dz), sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov)
end
local function tp() return T.state().sector.trader.pos end
local function rel(x, y, z) local p = tp() return { p[1] + x, p[2] + y, p[3] + z } end

T.wait(40)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local b = dock.bay(T.state(), 1)
local L = sh.for_trader(T.state(), 1)
local i = L.info
local e = i.extent
local len = e.hi[1] - e.lo[1]
local wid = e.hi[3] - e.lo[3]
local c = i.centre
saucer.log.info(string.format("alien-tour: family=%s palette=%s length=%d width=%d height=%d radius=%d pods=%d solids=%d lights=%d",
  tostring(i.family or "ring"), tostring(i.palette), len // 1, wid // 1, (e.hi[2] - e.lo[2]) // 1, i.radius // 1, i.pods, #L.solids, #L.lights))
-- 1. the whole station from afar
-- (from the star's side, near enough that the full hull and its lights are drawn)
do
  local sd = require("view.lights").star(T.state().seed or 0, T.state().sector_id or 1).dir
  local dx, dz = sd[1] + 0.35, sd[3] - 0.5
  local dl = sm.sqrt(dx * dx + dz * dz)
  local dist = math.max(len, wid) * 0.66
  look_at(rel(c[1] + dx / dl * dist, c[2] + dist * 0.32, (c[3] or 0) + dz / dl * dist), rel(c[1], c[2], c[3] or 0), 74)
end
shot("01_whole_station")
-- 2. the saucer in front of it, for scale
get().ship.pos = { b.mouth[1] + 260, b.mouth[2] + 60, b.mouth[3] - 140 }
get().ship.vel = { 0, 0, 0 }
get().ship.yaw = sm.atan2(-1, 0.4)
look_at({ b.mouth[1] + 330, b.mouth[2] + 75, b.mouth[3] - 175 }, rel(c[1] * 0.6, c[2] - 60, 0), 70)
shot("02_saucer_for_scale")
-- 3. the hangar approach: the bay a small mark on the stem
get().ship.pos = { b.mouth[1] + 150, b.mouth[2] + 10, b.mouth[3] + 10 }
look_at(rel(380, 80, 70), rel(-200, 15, 0), 70)
shot("03_hangar_approach")
-- 4. close: the body's front
look_at(rel((i.body_front or i.hub_front or -400) + 260, 260, -520), rel((i.body_front or i.hub_front or -400) - 250, 0, 0), 70)
shot("04_body_close")
-- 5. the tractor beam and the bay
get().ship.pos = { b.mouth[1] + 120, b.mouth[2] + 5, b.mouth[3] + 25 }
get().ship.vel = { 0, 0, 0 }
T.wait(100)
ap.wait_until(T, 1, function() return get().berth and get().berth.phase == "descend" end, 60 * 30)
ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 20)
T.wait(80)
look_at({ b.hi[1] - 4, b.floor + 12, b.pad[3] + 24 }, { b.pad[1] - 8, b.floor + 4, b.pad[3] - 6 }, 75)
shot("05_hangar_bay")
-- walk in
ap.walk_to_station(T, 1, get, "hatch")
T.press(1, "use")
ap.wait_until(T, 1, function() return hulldoor.passable(get()) end, 60 * 8)
T.wait(10)
free = nil
ap.walk_path(T, 1, get, { { 0, -3, -8.2 } }, 0.3, 1500)
ap.look(T, 1, get, sm.pi, 0, 300)
ap.push(T, 1, function() return get().mode == "foot" end, 60 * 14)
ap.hold(T, 1, {})
T.wait(10)
ap.ex_to(T, 1, get, { b.lo[1] + 0.2, b.floor, b.door.z }, 0.3, 3000)
T.wait(20)
local st = get().station
if st then
  local I = visit.layout(T.state(), get())
  saucer.log.info(string.format("alien-tour: inside %d areas", #I.areas))
  local function stand(x, z, tx, tz, pitch)
    st.body.pos = { x, 0, z }
    st.body.yaw = sm.atan2(tx - x, tz - z)
    st.body.pitch = pitch or 0.05
    T.wait(4)
  end
  stand(0, 4, 0, 30)
  shot("06_on_foot_concourse")
  local n = 0
  for _, a in ipairs(I.areas) do
    if n < 5 and (a.kind == "market" or a.kind == "chamber" or (a.alien and n == 1)) then
      local bx = a.box
      local cx, cz = (bx[1] + bx[3]) / 2, (bx[2] + bx[4]) / 2
      local sx = bx[1] + (bx[3] - bx[1]) * 0.12
      local sz = bx[2] + (bx[4] - bx[2]) * 0.12
      stand(sx, sz, cx, cz, a.alien == "shaft" and 0.75 or (a.h > 14 and 0.3 or 0.08))
      n = n + 1
      shot(string.format("%02d_inside_%s", 6 + n, (a.alien or a.kind):gsub("%s", "_")))
    end
  end
end
T.wait(5)
