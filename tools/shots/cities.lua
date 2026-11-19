-- SPDX-License-Identifier: MIT
-- City screenshots (OpenSpec add-cities). Run from the folder that should receive shots_cities/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/cities.lua
-- BODY (planet | moon | asteroid) is replaced by tools/shots/cities.sh. Per body: the approach from open
-- space, flying between two towers, inside the largest landmark hall, the undercity, the city map.
-- Staged: the saucer is placed (the flight rules are tests/lua/city_spec.lua's).
local T = saucer.test
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local ruinm = require("sim.ruin")
local ap = require("sim.autopilot")
local vec = require("lib.vec")
local BODY = "planet"
local D = "shots_cities/" .. BODY .. "_"
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
print(string.format("city %s site %d rooms %d districts %d origin %.0f %.0f %.0f", BODY, site, #ruin.rooms, #ruin.city.districts, o[1], o[2], o[3]))

-- 1. the approach: 330 m off the spaceport mouth, a little above the roofs of the low blocks
local port = ruin.city.districts[ruin.city.port]
put({ o[1] + ext[1] / 2, port.pos[2] + 70, o[3] - 330 }, 0, -0.08)
shot("01_approach")
put({ o[1] + ext[1] / 2 + 260, port.pos[2] + 140, o[3] - 520 }, -0.45, -0.1)
shot("01b_approach_wide")

-- 2. between towers: the tallest pair of towers close together
local towers = {}
for _, s in ipairs(ruin.solids) do if s.kind == "tower" then towers[#towers + 1] = s end end
table.sort(towers, function(a, b) return (a[2][2] - a[1][2]) > (b[2][2] - b[1][2]) end)
local best
for i = 1, math.min(#towers, 24) do
  for j = i + 1, math.min(#towers, 24) do
    local a, b = towers[i], towers[j]
    local ca = { (a[1][1] + a[2][1]) / 2, 0, (a[1][3] + a[2][3]) / 2 }
    local cb = { (b[1][1] + b[2][1]) / 2, 0, (b[1][3] + b[2][3]) / 2 }
    local d = vec.dist(ca, cb)
    if d > 40 and d < 400 and (not best or d < best.d) then best = { a = a, b = b, d = d, ca = ca, cb = cb } end
  end
end
if best then
  local mid = { (best.ca[1] + best.cb[1]) / 2, 0, (best.ca[3] + best.cb[3]) / 2 }
  local top = math.min(best.a[2][2], best.b[2][2])
  local dx, dz = best.cb[1] - best.ca[1], best.cb[3] - best.ca[3]
  local yaw = saucer.math.atan2(-dz, dx) -- look along the gap
  local ys = math.max(best.a[1][2], best.b[1][2]) + (top - math.max(best.a[1][2], best.b[1][2])) * 0.6
  put({ mid[1] - dz / best.d * 70, ys, mid[3] + dx / best.d * 70 }, yaw + 0.0, -0.05)
else
  put({ o[1] + ext[1] / 2, port.pos[2] + 100, o[3] + ext[3] / 2 }, 0, -0.1)
end
local inside = vec.copy(p1().ship.pos)
shot("02_between_towers")

-- 3. inside the biggest landmark hall (the reactor's, the palace's or the archive's ground hall)
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
put({ hall.c[1], hall.mn[2] + 7, hall.c[3] - 8 }, 0, 0.05)
shot("03_inside_" .. pick.kind)

-- 4. the undercity: the lowest room there is
local low
for _, r in ipairs(ruin.rooms) do
  local mn, mx = ruinm.room_box(r, kit, o)
  if r.class >= 4 and (not low or mn[2] < low.mn[2]) then low = { mn = mn, mx = mx } end
end
put({ (low.mn[1] + low.mx[1]) / 2, low.mn[2] + 5, (low.mn[3] + low.mx[3]) / 2 - 6 }, 0, 0)
shot("04_undercity")

-- 5. the city map, opened from between the towers (inside the site bounds)
put(inside, 0, -0.08)
T.press(1, "map")
T.wait(5)
shot("05_city_map")

-- 6. the payoff: a dark district, then the same view once its grid is restored (add-cities-2)
local cities = require("sim.cities")
T.press(1, "map") -- close the map
T.wait(5)
local tgt
for _, d in ipairs(ruin.city.districts) do
  if not d.powered and d.id ~= ruin.city.port and d.kind ~= "spaceport" then
    local dd = vec.dist(d.pos, port.pos)
    if not tgt or dd < tgt.dd then tgt = { d = d, dd = dd } end
  end
end
if tgt then
  local d = tgt.d
  local back = { port.pos[1] - d.pos[1], 0, port.pos[3] - d.pos[3] }
  local bl = math.sqrt(back[1] ^ 2 + back[3] ^ 2) + 1e-6
  local from = { d.pos[1] + back[1] / bl * (BODY == "planet" and 230 or 170), d.pos[2] + 60, d.pos[3] + back[3] / bl * (BODY == "planet" and 230 or 170) }
  local yaw = saucer.math.atan2(back[3], -back[1])
  put(from, yaw, -0.05)
  shot("06_grid_dark")
  cities.restore(T.state(), site, d.id)
  T.wait(200)
  shot("07_grid_restored")
  put(from, yaw, -0.05)
  shot("08_grid_restored_b")
end

-- 7. how far it runs: from high above the core, then low in the skyline ring (add-cities-2)
local top = o[2] + ext[2] - 40
put({ o[1] + ext[1] / 2, top, o[3] + 60 }, 0, -0.18)
shot("09_vast_high")
-- low in the ring: 110 m off the -z face of a tall outer tower, at a height clear of every solid
local function clear(pos)
  for _, q in ipairs(ruin.solids) do
    if pos[1] > q[1][1] - 12 and pos[1] < q[2][1] + 12 and pos[2] > q[1][2] - 12 and pos[2] < q[2][2] + 12
       and pos[3] > q[1][3] - 12 and pos[3] < q[2][3] + 12 then return false end
  end
  return true
end
local pick
for _, q in ipairs(ruin.solids) do
  if q.outer and q.apex and q[2][2] - o[2] > 300 and not pick then
    local pos = { (q[1][1] + q[2][1]) / 2, o[2] + (q[2][2] - o[2]) * 0.6, q[1][3] - 110 }
    if q[1][3] - o[3] > ext[3] * 0.5 and clear(pos) then pick = pos end
  end
end
if pick then
  put(pick, 0, -0.04)
  shot("10_skyline_ring")
end

-- 8. transit, the wet undercity and weather (add-cities-2)
local render = require("view.render")
local line = ruin.city.rails[1]
local u = render.train_pos(line, 0, T.state().tick + 24)
put({ o[1] + u * 4 + 2, o[2] + line.y * 4 - 7, o[3] + line.c * 4 - 34 }, 0, 0.3)
shot("11_mag_rail")
local lift = ruin.city.lifts[1]
put({ lift.pos[1] - 45, render.lift_y(lift, T.state().tick) + 6, lift.pos[3] - 45 }, 0.78, 0)
shot("12_lift_shaft")
local canal
for _, r in ipairs(ruin.rooms) do if r.tunnel and not canal then canal = r end end
if canal then
  local mn, mx = ruinm.room_box(canal, kit, o)
  put({ (mn[1] + mx[1]) / 2, mn[2] + 7, (mn[3] + mx[3]) / 2 }, (mx[1] - mn[1]) > (mx[3] - mn[3]) and 1.5708 or 0, 0)
  shot("13_canal")
end
if BODY == "planet" then
  local sc = require("sim.cities")
  T.state().tick = sc.phase(ruin) + sc.STORM_LEN // 2 - 10
  put({ inside[1], inside[2] + 90, inside[3] }, 0, 0.02)
  shot("14_storm")
  local bridge
  for _, bi in ipairs(ruin.city.bridges) do
    local b = ruin.solids[bi]
    local m = { (b[1][1] + b[2][1]) / 2, (b[1][2] + b[2][2]) / 2, (b[1][3] + b[2][3]) / 2 }
    if b.fall == 1 and (not bridge or vec.dist(m, inside) < bridge.d) then bridge = b bridge.d = vec.dist(m, inside) end
  end
  local ft = sc.fall_tick(ruin, bridge)
  T.state().tick = ft - 4
  put({ (bridge[1][1] + bridge[2][1]) / 2, (bridge[1][2] + bridge[2][2]) / 2 + 4, bridge[1][3] - 70 }, 0, -0.05)
  T.wait(40)
  shot("15_bridge_falls")
end
-- 9. mystery and traders (add-cities-2 slice 4)
local clue = ruin.city.clues[1]
require("sim.cities").restore(T.state(), site, clue.district)
put({ clue.pos[1], clue.pos[2] + 1, clue.pos[3] - 14 }, 0, 0)
shot("16_archive_record")
local outpost = T.state().sector.traders[2]
put({ outpost.pos[1] + 40, outpost.pos[2] + 12, outpost.pos[3] - 160 }, -0.2, -0.05)
shot("17_trader_outpost")
-- 10. the grid-restore payoff (add-cities-2 slice 5): dark, beacon up, the wave, done
do
  local cs = require("sim.cities")
  local dd
  for _, pd in ipairs(ruin.city.districts) do
    if not pd.powered and not cs.powered(T.state(), site, ruin, pd.id) and (not dd or vec.dist(pd.pos, inside) < vec.dist(dd.pos, inside)) then dd = pd end
  end
  local cp
  for _, c in ipairs(ruin.city.couplings) do if c.district == dd.id then cp = c.pos end end
  T.state().tick = 300 -- clear weather
  local back = { port.pos[1] - dd.pos[1], 0, port.pos[3] - dd.pos[3] }
  local bl = math.sqrt(back[1] ^ 2 + back[3] ^ 2) + 1e-6
  local k = BODY == "planet" and 260 or 200
  local view = { dd.pos[1] + back[1] / bl * k, dd.pos[2] + 130, dd.pos[3] + back[3] / bl * k }
  local vyaw = saucer.math.atan2(back[3], -back[1])
  put(view, vyaw, -0.14)
  shot("18_restore_0_dark")
  cs.restore(T.state(), site, dd.id)
  T.state().tick = T.state().tick + 0
  put(view, vyaw, -0.14)  -- 20 ticks in: the flicker and the first beacon light
  shot("18_restore_1_flicker")
  T.wait(70)
  shot("18_restore_2_wave")
  T.wait(50)
  shot("18_restore_3_wave_wide")
  T.wait(200)
  shot("18_restore_4_done")
end
print("cities shots done " .. BODY)
