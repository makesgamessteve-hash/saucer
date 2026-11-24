-- SPDX-License-Identifier: MIT
-- add-relic-stations: the first relic slice's screenshot tour (and, with --script-arg frames, a 9:16 Reel
-- fly-through as numbered frames). Run from the folder that should receive shots_relic/:
--   saucer --root REPO --seed 42 --relic-slice --windowed --width 1280 --height 720 --script REPO/tools/shots/relic_slice.lua
--   saucer --root REPO --seed 42 --relic-slice --windowed --width 540 --height 960 --script REPO/tools/shots/relic_slice.lua \
--          --script-arg frames            (writes shots_relic/frames/f0000.png ...; ffmpeg -i f%04d.png reel.mp4)
-- Scripts run fixed-step, so every frame is a sim tick whatever the GPU's speed.
local T = saucer.test
local ap = require("sim.autopilot")
local relic = require("sim.relic")
local game = require("sim.game")
local ruinm = require("sim.ruin")
local R = require("view.render")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_relic/"
local mode = T.arg and T.arg() or nil
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function cam(pos, yaw, pitch, fov) free = { pos = pos, yaw = yaw, pitch = pitch or 0, fov = fov or 62, near = 0.3, far = 9000 } end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  cam(from, sm.atan2(dx, dz), sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov)
end
-- the HUD stays off for the cinematic shots (on for the Seat shots: the ghost Villa and its prompts)
local hud = require("view.hud")
local hud_draw = hud.draw
local clean = true
hud.draw = function(...) if clean then return nil end return hud_draw(...) end
local function mats(m) saucer.render.settings({ materials = m }) end
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function compare(name)
  mats("full") shot(name .. "_full")
  mats("off") shot(name .. "_off")
  mats("full")
end

T.wait(20)
local i = relic.site_index(T.state())
T.assert(i ~= nil, "run with --relic-slice")
local site = T.state().sector.sites[i]
local r = game.ruin(i)
local kit = ruinm.kit_of(r.kit)
local function rbox(id) return ruinm.room_box(r.rooms[id], kit, site.pos) end
local function centre(id)
  local mn, mx = rbox(id)
  return { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }, mn, mx
end
local function floor_of(id) local _, mn = centre(id) return mn[2] + kit.wall end
local door = ruinm.entrance(r, site.pos)
local set = require("view.relic").meshes(r, site.pos)
saucer.log.info(string.format("relic-tour: rooms=%d length=%.0f villa_share=%.2f bays=%d triangles=%d cushions=%d",
  #r.rooms, r.relic.length, r.relic.villa_share, #r.relic.bays, set.triangles, set.cushions))
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local function park(pos, yaw)
  local s = get().ship
  s.pos, s.vel, s.yaw = { pos[1], pos[2], pos[3] }, { 0, 0, 0 }, yaw or 0
end
local lung = r.relic.lung
local hall1 = r.relic.halls[1]
local core = r.relic.core
local Q = r.relic.branches[1].reliquary

if mode == "frames" then
  -- the Reel: approach the maw, through it, down the spine (the breathing hall, the bays), into the Core
  local fd = D .. "frames/"
  local n = 0
  local function frame() T.wait(1) T.screenshot(string.format("%sf%04d.png", fd, n)) n = n + 1 end
  local cc, _, cmx = centre(core)
  local path = {
    { door[1] + 60, door[2] + 40, door[3] - 260 }, { door[1], door[2] + 4, door[3] - 60 }, { door[1], door[2], door[3] + 30 },
  }
  for _, h in ipairs(r.relic.halls) do
    local c = centre(h)
    path[#path + 1] = { c[1] + 18, floor_of(h) + 14, c[3] - 20 }
    path[#path + 1] = { c[1] - 10, floor_of(h) + 18, c[3] + 30 }
  end
  path[#path + 1] = { cc[1], floor_of(core) + 16, cc[3] - 40 }
  path[#path + 1] = { cc[1] + 30, floor_of(core) + 24, cc[3] + 10 }
  local per = 36
  park({ door[1] + 30, door[2] - 2, door[3] - 120 }, 0)
  for s = 1, #path - 1 do
    local a, b = path[s], path[s + 1]
    local c2 = path[math.min(#path, s + 2)]
    for k = 0, per - 1 do
      local t = k / per
      local e = t * t * (3 - 2 * t)
      local pos = { a[1] + (b[1] - a[1]) * e, a[2] + (b[2] - a[2]) * e, a[3] + (b[3] - a[3]) * e }
      local tgt = { b[1] + (c2[1] - b[1]) * e, b[2] + (c2[2] - b[2]) * e, b[3] + (c2[3] - b[3]) * e }
      look_at(pos, tgt, 72)
      frame()
    end
  end
  saucer.log.info("relic-tour: frames=" .. n)
  return
end

-- 1. the maw from outside, the Villa in front of it for scale
park({ door[1] + 14, door[2] - 2, door[3] - 70 }, sm.atan2(-0.2, 1))
look_at({ door[1] + 62, door[2] + 16, door[3] - 128 }, { door[1] - 4, door[2] + 2, door[3] + 6 }, 64)
shot("01_maw_exterior")
-- 2. the whole spine from above and aside
do
  local c = set.center
  look_at({ c[1] + 560, c[2] + 260, c[3] - 380 }, c, 64)
  shot("02_spine_whole")
end
-- 3. the breathing hall (the lung), its four bays and the Seat port
do
  local c, mn, mx = centre(lung)
  local b = r.relic.bays[5]
  park({ b.marker[1], b.cradle[2] + 7, b.marker[3] }, 0.4)
  look_at({ mn[1] + 8, floor_of(lung) + 22, mn[3] + 8 }, { mx[1] - 20, floor_of(lung) + 10, mx[3] - 26 }, 80)
  compare("03_breathing_hall")
end
-- 4. a fold bay with its cradle, the Villa resting in it
do
  local b = r.relic.bays[3]
  local c = centre(b.room)
  local dx, dz = c[1] - b.marker[1], c[3] - b.marker[3]
  local dl = sm.sqrt(dx * dx + dz * dz)
  park({ b.marker[1], b.cradle[2] + 7, b.marker[3] }, 0.6)
  look_at({ b.marker[1] + dx / dl * 40, b.cradle[2] + 20, b.marker[3] + dz / dl * 40 }, { b.marker[1], b.cradle[2] + 3, b.marker[3] }, 72)
  compare("04_fold_bay_cradle")
end
-- 5. the Seat port and passage (the saucer as the Seat at the port), then the reliquary behind its lock
do
  local br = r.relic.branches[1]
  local pc = br.port.pos
  local s = get().ship
  s.size = 2
  clean = false
  park({ pc[1] - 4, pc[2], pc[3] }, math.pi / 2)
  look_at({ pc[1] - 14, pc[2] + 4, pc[3] - 7 }, { pc[1], pc[2], pc[3] }, 62)
  shot("05_seat_port")
  clean = true
  local B = r.rooms[br.rooms[2]]
  local bmn, bmx = ruinm.room_box(B, kit, site.pos)
  look_at({ (bmn[1] + bmx[1]) / 2, bmn[2] + 2.4, bmn[3] + 1.5 }, { (bmn[1] + bmx[1]) / 2, bmn[2] + 2, bmx[3] }, 70)
  shot("06_seat_passage")
  local qc, qmn, qmx = centre(Q)
  game.open_relic_lock(i, 1)
  T.state().relic_locks = { [i .. ":1"] = true }
  look_at({ qc[1] - 4.5, qmn[2] + 5.5, qmn[3] + 1 }, { qc[1] + 1, qmn[2] + 1, qc[3] + 2 }, 74)
  compare("07_reliquary")
  s.size = 1
end
-- 6. the Core and its idol
do
  local c, mn, mx = centre(core)
  park({ c[1] - 30, floor_of(core) + 10, c[3] - 20 }, 0.7)
  local idol
  for _, s in ipairs(r.slots) do if s.idol then idol = s end end
  look_at({ idol.pos[1] + 16, idol.pos[2] + 5, idol.pos[3] - 18 }, { idol.pos[1] - 4, idol.pos[2] + 1, idol.pos[3] + 6 }, 74)
  compare("08_core_idol")
end
-- 7. a trunk, chrome ribs and spines
do
  local t = r.relic.trunks[1]
  local c, mn = centre(t)
  look_at({ c[1] + 8, floor_of(t) + 14, mn[3] + 4 }, { c[1] - 4, floor_of(t) + 8, c[3] + 40 }, 72)
  compare("09_trunk")
end
free = nil
