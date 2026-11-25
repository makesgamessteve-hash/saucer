-- SPDX-License-Identifier: MIT
-- add-relic-stations, add-relic-dungeons: the relic slice's screenshot tour (and, with --script-arg frames, a 9:16
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
local relicv = require("view.relic")
relicv.BUILDS = 1000 -- every room the eye may see is built before the shot
saucer.log.info(string.format("relic-tour: rooms=%d length=%.0f villa_share=%.2f bays=%d chambers=%d levels=%d phenomena=%d",
  #r.rooms, r.relic.length, r.relic.villa_share, #r.relic.bays, #r.relic.chambers, r.relic.levels, #r.relic.phenomena))
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
  -- the game's low-res target is landscape; a 9:16 Reel wants a portrait target (no letterbox)
  saucer.render.settings({ width = 360, height = 640 })
  local n = 0
  local function frame() T.wait(1) T.screenshot(string.format("%sf%04d.png", fd, n)) n = n + 1 end
  local cc, _, cmx = centre(core)
  local path = {
    { door[1] + 60, door[2] + 40, door[3] - 260 }, { door[1], door[2] + 4, door[3] - 60 }, { door[1], door[2], door[3] + 30 },
  }
  for _, h in ipairs(r.relic.route) do
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

-- the door between two rooms -> its world centre and the unit step from a into b
local function door_between(a, b)
  for _, d in ipairs(r.doors) do
    if (d.a == a and d.b == b) or (d.a == b and d.b == a) then
      local c = ap.door_center(d, r.rooms, kit, site.pos)
      local dir = { 0, 0, 0 }
      dir[d.axis] = (d.a == a) and d.sign or -d.sign
      return c, dir, d
    end
  end
end
local function add(p, d, k) return { p[1] + d[1] * k, p[2] + d[2] * k, p[3] + d[3] * k } end

-- --script-arg glow: the quick look at the lamp glows, the heart and the far hull (fix for dark blocky glows)
if mode == "glow" then
  local c, mn, mx = centre(core)
  local route = r.relic.route
  local dc, dir = door_between(route[#route - 1], core)
  park(add(dc, dir, 30), 0)
  look_at(add({ dc[1], dc[2] + 30, dc[3] }, dir, 8), { c[1], mn[2] + 70, c[3] }, 84)
  T.wait(30)
  compare("g1_heart_engine")
  local idol
  for _, s2 in ipairs(r.slots) do if s2.idol then idol = s2 end end
  look_at({ idol.pos[1] + 16, idol.pos[2] + 5, idol.pos[3] - 18 }, { idol.pos[1] - 4, idol.pos[2] + 1, idol.pos[3] + 6 }, 74)
  compare("g2_heart_idol")
  -- the nearest lamps in the heart, from close by
  local lamps = require("view.lights").room_lamps(r, site.pos, i).list
  local best, bd
  for _, l in ipairs(lamps) do
    local p = l.pos
    if p[1] > mn[1] and p[1] < mx[1] and p[2] > mn[2] and p[2] < mx[2] and p[3] > mn[3] and p[3] < mx[3] then
      local d = math.abs(p[2] - (mn[2] + 20))
      if not bd or d < bd then best, bd = l, d end
    end
  end
  if best then
    local p = best.pos
    local from = { p[1] + 14, p[2] + 3, p[3] - 14 }
    for q = 1, 3 do from[q] = math.max(mn[q] + 3, math.min(mx[q] - 3, from[q])) end
    look_at(from, p, 70)
    compare("g3_heart_lamp")
  end
  -- the hall lamps
  local hc, hmn = centre(hall1)
  look_at({ hc[1], floor_of(hall1) + 8, hmn[3] + 4 }, { hc[1], floor_of(hall1) + 10, hc[3] }, 74)
  compare("g4_hall_lamps")
  -- the hull from 450 m and from 150 m
  local sc = set.center
  park({ door[1], door[2], door[3] - 400 }, 0)
  look_at({ sc[1] + 300, sc[2] + 160, sc[3] - 380 }, sc, 62)
  T.wait(4)
  compare("g5_hull_far")
  look_at({ door[1] + 90, door[2] + 40, door[3] - 140 }, { door[1], door[2], door[3] + 40 }, 66)
  T.wait(4)
  compare("g6_hull_near")
  free = nil
  return
end

-- --script-arg styles: add-design-language: the same relic restyled by four civs (the Vyrr and three of seed 42's
-- roster), from the same three viewpoints: a hall, the hull near the maw and the heart
if mode == "styles" then
  local civs = require("sim.civs")
  local u = civs.universe(T.state().seed)
  local picks = { false }
  for _, id in ipairs({ "oquun", "ixalash", "neum" }) do
    for _, c in ipairs(u) do if c.id == id then picks[#picks + 1] = c end end
  end
  for k = #picks + 1, 4 do picks[k] = u[k + 1] end
  local hc, hmn = centre(hall1)
  local c, mn = centre(core)
  local route = r.relic.route
  local dc, dir = door_between(route[#route - 1], core)
  for k, civ in ipairs(picks) do
    relicv.set_style(civ or nil)
    local tag = string.format("s%d_%s", k, civ and civ.id or "vyrr")
    saucer.log.info("styles: " .. tag .. " " .. (civ and (civ.materials.signature.rule .. " " .. civ.language.light.model) or "vyrr"))
    park({ hc[1], floor_of(hall1) + 2, hmn[3] + 30 }, 0)
    look_at({ hc[1] + 6, floor_of(hall1) + 9, hmn[3] + 4 }, { hc[1], floor_of(hall1) + 12, hc[3] }, 74)
    T.wait(6)
    shot(tag .. "_hall")
    park({ door[1], door[2], door[3] - 400 }, 0)
    look_at({ door[1] + 90, door[2] + 40, door[3] - 140 }, { door[1], door[2], door[3] + 40 }, 66)
    T.wait(6)
    shot(tag .. "_hull")
    park(add(dc, dir, 30), 0)
    look_at(add({ dc[1], dc[2] + 30, dc[3] }, dir, 8), { c[1], mn[2] + 70, c[3] }, 84)
    T.wait(10)
    shot(tag .. "_heart")
  end
  relicv.set_style(nil)
  free = nil
  return
end

-- 1. the maw from outside, the Villa in front of it for scale
park({ door[1] + 14, door[2] - 2, door[3] - 70 }, sm.atan2(-0.2, 1))
look_at({ door[1] + 46, door[2] + 9, door[3] - 84 }, { door[1] - 2, door[2] + 3, door[3] + 4 }, 66)
shot("01_maw_exterior")
-- 2. the whole warren from above and aside (every room in full for this one)
do
  local near = relicv.NEAR
  relicv.NEAR = 5000
  local c = set.center
  park({ door[1], door[2], door[3] - 400 }, 0)
  look_at({ c[1] + 640, c[2] + 380, c[3] - 520 }, c, 62)
  T.wait(4)
  shot("02_warren_whole")
  relicv.NEAR = near
end
-- 3. the first hall from its maw door: the scale of a big hall, its cushions and ribs
do
  local h = r.relic.halls[1]
  local c, mn, mx = centre(h)
  park({ c[1] + 20, floor_of(h) + 9, c[3] }, 0.3)
  look_at({ c[1] - 30, floor_of(h) + 30, mn[3] + 6 }, { c[1] + 20, floor_of(h) + 12, mx[3] - 10 }, 82)
  compare("03_first_hall")
end
-- 4. along a trunk into the next hall (the warren goes on and on)
do
  local route = r.relic.route
  local t, nxt
  for k = 3, #route - 1 do
    if r.rooms[route[k]].kind == "trunk" and r.rooms[route[k + 1]].kind == "hall" then t, nxt = route[k], route[k + 1] break end
  end
  local prev = route[2]
  for k = 2, #route do if route[k] == t then prev = route[k - 1] end end
  local c0, dir = door_between(prev, t)
  local c1 = door_between(t, nxt)
  look_at(add(c0, dir, 4), add(c1, dir, 60), 74)
  shot("04_trunk_to_hall")
end
-- 5. a shaft, looking up through it to the level above
do
  local sh = r.relic.shafts[1]
  local c, mn, mx = centre(sh)
  look_at({ c[1] + 6, mn[2] - 30, c[3] + 8 }, { c[1], mx[2] + 40, c[3] }, 84)
  shot("05_shaft_up")
end
-- 6. the breathing hall (the lung), its bays and the locked branch's port
do
  local c, mn, mx = centre(lung)
  local b
  for _, q in ipairs(r.relic.bays) do if q.room == lung then b = q end end
  park({ b.marker[1], b.cradle[2] + 7, b.marker[3] }, 0.4)
  look_at({ mn[1] + 8, floor_of(lung) + 22, mn[3] + 8 }, { mx[1] - 20, floor_of(lung) + 10, mx[3] - 26 }, 80)
  compare("06_breathing_hall")
end
-- 7. a fold bay by a Seat port, the Villa resting in its cradle
do
  local br = r.relic.branches[2] or r.relic.branches[1]
  local b = r.relic.bays[br.bay]
  local pc = br.port.pos
  park({ b.marker[1], b.cradle[2] + 7, b.marker[3] }, 0.6)
  local dx, dz = b.marker[1] - pc[1], b.marker[3] - pc[3]
  local dl = sm.sqrt(dx * dx + dz * dz)
  look_at({ b.marker[1] + dx / dl * 46, b.cradle[2] + 22, b.marker[3] + dz / dl * 46 }, { pc[1], pc[2] - 4, pc[3] }, 74)
  compare("07_fold_bay_port")
end
-- 8. the Seat at a port, then down its passage, then a chamber
do
  local br = r.relic.branches[1]
  local d = r.doors[br.port.door]
  local pc = br.port.pos
  local dir = { 0, 0, 0 }
  dir[d.axis] = d.sign
  local s = get().ship
  s.size = 2
  relicv.SHOW_GHOST = false
  local yaw = sm.atan2(dir[1], dir[3])
  park(add(pc, dir, -5), yaw)
  local side = { dir[3], 0, -dir[1] }
  look_at(add(add(pc, dir, -12), side, 4), pc, 58)
  shot("08_seat_port")
  relicv.SHOW_GHOST = true
  clean = false
  free = nil
  get().cam = "chase"
  park(add(pc, dir, -16), yaw)
  shot("08b_seat_ghost_villa_hud")
  get().cam = "first"
  clean = true
  look_at(add(pc, dir, 1.5), add(pc, dir, 30), 70)
  shot("09_seat_passage")
  local qc, qmn = centre(Q)
  game.open_relic_lock(i, 1)
  T.state().relic_locks = { [i .. ":1"] = true }
  local ld = r.doors[r.relic.locks[1].door]
  local ldir = { 0, 0, 0 }
  ldir[ld.axis] = ld.sign
  look_at(add({ qc[1], qmn[2] + 5.5, qc[3] }, ldir, -4.5), { qc[1], qmn[2] + 1, qc[3] }, 76)
  compare("10_reliquary")
  for _, id in ipairs(r.relic.chambers) do
    if r.rooms[id].kind == "chamber" and id % 3 == 1 then
      local cc, cmn, cmx = centre(id)
      look_at({ cmn[1] + 1.2, cmn[2] + 4, cmn[3] + 1.2 }, { cmx[1] - 1, cmn[2] + 3, cmx[3] - 1 }, 80)
      shot("11_seat_chamber")
      break
    end
  end
  s.size = 1
end
-- 9. the heart: from its door, the whole hall round the engine; then the idol before it
do
  local c, mn, mx = centre(core)
  local route = r.relic.route
  local dc, dir = door_between(route[#route - 1], core)
  park(add(dc, dir, 30), 0)
  look_at(add({ dc[1], dc[2] + 30, dc[3] }, dir, 8), { c[1], mn[2] + 70, c[3] }, 84)
  compare("12_heart_engine")
  look_at({ c[1] - 150, mn[2] + 120, mn[3] + 40 }, { c[1], mn[2] + 60, c[3] }, 80)
  T.wait(90)
  shot("13_heart_engine_high")
  local idol
  for _, s2 in ipairs(r.slots) do if s2.idol then idol = s2 end end
  look_at({ idol.pos[1] + 16, idol.pos[2] + 5, idol.pos[3] - 18 }, { idol.pos[1] - 4, idol.pos[2] + 1, idol.pos[3] + 6 }, 74)
  compare("14_heart_idol")
end
-- 10. phenomena: one of each kind the relic holds, from a little way off
do
  local done = {}
  local n = 15
  for _, ph in ipairs(r.relic.phenomena) do
    if not done[ph.kind] and r.rooms[ph.room].kind ~= "core" then
      done[ph.kind] = true
      local _, mn, mx = centre(ph.room)
      local p = ph.pos
      local from = { (mn[1] + mx[1]) / 2, p[2] + 6, (mn[3] + mx[3]) / 2 }
      local dx, dz = p[1] - from[1], p[3] - from[3]
      local dl = sm.sqrt(dx * dx + dz * dz)
      if dl < 20 then from = { p[1] - 28, p[2] + 6, p[3] - 28 } end
      if ph.kind == "breath" or ph.kind == "shadow" or ph.kind == "procession" then
        from = { (mn[1] + mx[1]) / 2, mn[2] + 14, (mn[3] + mx[3]) / 2 }
      end
      -- the eye stays inside the room, a little off its walls
      for q = 1, 3 do from[q] = math.max(mn[q] + 3, math.min(mx[q] - 3, from[q])) end
      if ph.kind == "breath" then
        -- from across the room, facing the wall the sac grows on
        for q = 1, 3, 2 do
          if math.abs(p[q] - mn[q]) < 2 then from[q] = mx[q] - 4 elseif math.abs(p[q] - mx[q]) < 2 then from[q] = mn[q] + 4 end
        end
      end
      look_at(from, ph.kind == "chimes" and { p[1], mx[2] - 8, p[3] } or p, 70)
      T.wait(20)
      shot(string.format("%02d_phenomenon_%s", n, ph.kind))
      n = n + 1
    end
  end
end
free = nil
