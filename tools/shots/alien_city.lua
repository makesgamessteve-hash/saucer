-- SPDX-License-Identifier: MIT
-- add-alien-cities (plan phase 10) screenshots. Run from the folder that should receive shots_alien_city/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/alien_city.lua
--   [--script-arg planet|moon|asteroid]
-- The skyline from high over the approach, a district of the builders' value up close, a machine on a tower, a swarm
-- over an avenue, and the sky lanes from above. Staged: a free camera with the HUD and cockpit out of frame.
local T = saucer.test
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local ruinm = require("sim.ruin")
local ap = require("sim.autopilot")
local citygen = require("sim.citygen")
local phen = require("view.cityphen")
local R = require("view.render")
local hud = require("view.hud")
local sm = saucer.math
-- a free camera with the HUD off: the cockpit stays with the saucer, parked out of frame
local free
local orig_cam = R.camera
R.camera = function(p, xr) if free then return free end return orig_cam(p, xr) end
hud.draw = function() return nil end
local function look(from, to)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = 62, near = 0.3, far = 12000 }
end
local BODY = (T.arg() ~= "" and T.arg()) or "planet"
local D = "shots_alien_city/" .. BODY .. "_"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function p1() return T.state().players[1] end

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
local ruin = game.ruin(site)
local kit = ruinm.kit_of(ruin.kit)
local o = st.sector.sites[site].pos
local ext = { kit.grid[1] * kit.cell, kit.grid[2] * kit.cell, kit.grid[3] * kit.cell }
local function put(pos, yaw, pitch)
  local s = p1().ship
  s.pos, s.vel, s.yaw, s.pitch, s.bank = pos, { 0, 0, 0 }, yaw, pitch or 0, 0
  s.charge = 100
  T.wait(20)
end
-- frame `to` from `from`: the saucer waits just behind the camera (out of frame), so the city streams round it
local function frame(from, to)
  local d = { from[1] - to[1], from[2] - to[2], from[3] - to[3] }
  local l = math.max(1, sm.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3]))
  put({ from[1] + d[1] / l * 30, from[2] + d[2] / l * 30, from[3] + d[3] / l * 30 }, 0, 0)
  look(from, to)
end
local civ = game.civ_of(st.sector.sites[site])
print(string.format("alien_city %s: civ %s massing %s value %s form %s", BODY, tostring(civ and civ.name), tostring(civ and civ.massing),
  tostring(civ and civ.axes and civ.axes.values), ruin.city.style.form))
for _, d in ipairs(ruin.city.districts) do print("  " .. d.label) end

-- 1. the skyline from high over the approach
local port = ruin.city.districts[ruin.city.port]
frame({ o[1] + ext[1] / 2, port.pos[2] + 420, o[3] - 600 }, { o[1] + ext[1] / 2, port.pos[2], o[3] + ext[3] * 0.35 })
shot("01_skyline")

-- 2. a district of the builders' value: its tallest tower in the value's form, from 120 m
local value = civ and civ.axes and civ.axes.values
local best
for _, s in ipairs(ruin.solids) do
  if s.kind == "tower" and not s.outer and s.tier == 1 and s.form ~= ruin.city.style.form then
    if not best or (s[2][2] - s[1][2]) > (best[2][2] - best[1][2]) then best = s end
  end
end
if best then
  local c = { (best[1][1] + best[2][1]) / 2, best[1][2], (best[1][3] + best[2][3]) / 2 }
  frame({ c[1] - 110, c[2] + 70, c[3] - 110 }, { c[1], c[2] + (best[2][2] - best[1][2]) * 0.5, c[3] })
  print("value form " .. tostring(best.form) .. " (" .. tostring(value) .. ")")
  shot("02_value_district")
end

-- 3. a machine cycling on a tower top, and 4. a swarm over an avenue
local mach, swarm
for _, ph in ipairs(phen.place(ruin)) do
  if ph.kind == "machine" and (not mach or ph.pos[2] > mach.pos[2]) then mach = ph end
  if ph.kind == "swarm" and not swarm then swarm = ph end
end
if mach then
  frame({ mach.pos[1] - 45, mach.pos[2] + 18, mach.pos[3] - 45 }, mach.pos)
  shot("03_machine")
end
if swarm then
  frame({ swarm.pos[1] - 120, swarm.pos[2] + 15, swarm.pos[3] - 120 }, swarm.pos)
  shot("04_swarm")
end

-- 5. the sky lanes from above the middle of the core
local lane = ruin.city.lanes[1]
if lane then
  local mid = { (lane.a[1] + lane.b[1]) / 2, lane.a[2], (lane.a[3] + lane.b[3]) / 2 }
  frame({ mid[1] - 300, mid[2] + 120, mid[3] - 300 }, mid)
  shot("05_lanes")
end
print(string.format("alien_city %s: districts %d lanes %d phenomena %d", BODY, #ruin.city.districts, #ruin.city.lanes,
  #phen.place(ruin)))
