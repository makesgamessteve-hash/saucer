-- SPDX-License-Identifier: MIT
-- Screenshot tour for milestone 8 (OpenSpec add-wider-dark). Run from the
-- folder that should receive shots_m8/:
--   saucer --root REPO --seed 42 --coop --windowed --width 1600 --height 900 --script REPO/tools/shots/m8.lua
-- Played on command frames where it is cheap (joins, the map, the party fold
-- jump, the flight into a hive ruin and the Heart). Staged through the API,
-- to keep the tour short: a few finds filed in the Xenoarchive, Act I and II
-- of the mystery marked solved, the Heart Key handed to P2, the hop from Salt
-- Hollow to the Heart, and Charge topped up before the dive.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local mystery = require("sim.mystery")
local galaxy = require("sim.galaxy")
local archive = require("sim.archive")
local civs = require("sim.civs")
local heart = require("sim.heart")
local items = require("sim.items")
local configs = require("sim.config")
local D = "shots_m8/"
local function P(i) return function() return T.state().players[i] end end
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
local function full(i) P(i)().ship.charge = configs.all().max_charge end
local g = galaxy.generate(T.state().seed)
-- turn saucer i (at the helm) until it faces saucer j
local function face(i, j)
  local function err()
    local a, b = P(i)().ship, P(j)().ship
    local want = saucer.math.atan2(b.pos[1] - a.pos[1], b.pos[3] - a.pos[3])
    return (want - a.yaw + math.pi) % (2 * math.pi) - math.pi
  end
  local sgn = 1
  for k = 1, 600 do
    local e = err()
    if math.abs(e) < 0.04 then break end
    T.axis(i, "turn", sgn * (math.abs(e) > 0.3 and 0.6 or 0.2))
    T.wait(1)
    if k % 8 == 0 and math.abs(err()) > math.abs(e) then sgn = -sgn end
  end
  T.axis(i, "turn", 0)
  T.wait(10)
end

-- 1. a second player joins on their own slot: vertical split
T.wait(20)
T.press(2, "use")
T.wait(2)
for i = 1, 2 do ap.wake(T, i, P(i)) end
for i = 1, 2 do ap.take_helm(T, i, P(i)) end
T.axis(1, "lift", 1) T.axis(2, "lift", 1)
T.wait(90)
T.axis(1, "lift", 0) T.axis(2, "lift", 0)
face(1, 2)
face(2, 1)
shot("01_coop_2p")

-- 2. the sector map (P1) beside the galaxy graphic
T.press(1, "map")
T.wait(2)
shot("02_sector_map")

-- 3. the Xenoarchive, after a few finds of two civs are filed
for _, ci in ipairs({ 1, 2 }) do
  local c = civs.get(T.state().seed, ci)
  local cat = archive.catalog(c)
  for k = 1, math.min(#cat, ci == 1 and 5 or 2) do
    local it = items.stamp(P(1)(), { type = cat[k], civ = c.id }, 1, nil)
    archive.record(T.state(), P(1)(), it, { msg = function() end, fx = function() end })
  end
end
ap.pick(T, 1, P(1), "Xenoarchive")
shot("03_xenoarchive")
T.press(1, "map")
T.wait(2)

-- 4. a party fold jump to Salt Hollow: P1 proposes, P2 agrees, the spool
for i = 1, 2 do ap.resize(T, i, P(i), 1) full(i) end
local to = g.spine[2]
T.press(1, "map")
T.wait(2)
ap.pick(T, 1, P(1), g.sectors[to].name)
T.press(2, "map")
T.wait(2)
ap.pick(T, 2, P(2), "Agree: ")
ap.wait_until(T, 1, function() local j = T.state().jump return j and j.spool and j.spool >= 0 and j.spool < 0.8 end, 60 * 20)
shot("04_fold_jump")
ap.wait_until(T, 1, function() return T.state().sector_id == to end, 60 * 20)

-- 5. a hive ruin, the third kit: P1 flies in, decoys out, a Clamp wakes
local site
for i = 1, #T.state().sector.sites do
  if game.ruin(i) and game.ruin(i).kit == "hive" then site = site or i end
end
local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
local clamp
for _, d in ipairs(game.sentries(site)) do if d.kind == "clamp" then clamp = clamp or d end end
ap.take_helm(T, 1, P(1))
ap.travel(T, 1, P(1), ap.route(ruin, origin, clamp.room, 2)[1].pos, 4, 60 * 150)
shot("05_hive_kit")
full(1)
ap.resize(T, 1, P(1), 2)
T.press(1, "decoy")
T.wait(30)
ap.enter(T, 1, P(1), ruin, origin, clamp.room, 2)
ap.wait_until(T, 1, function() return P(1)().clamped_by ~= nil end, 60 * 8)
shot("06_clamp_decoy")

-- 6. the Heart: Acts I-II solved and the Key aboard P2 (staged); P2 flies in
local m = T.state().mystery
for i, e in ipairs(m.echoes) do
  if (e.sector or 1) == 1 then mystery.found(m, i, 1) if mystery.decodable(m, i) then mystery.decode(m, i) end end
end
mystery.open_vault(m)
local wi, ki = mystery.index_of(m, "witness"), mystery.index_of(m, "heart_key")
mystery.found(m, wi, 1)
mystery.decode(m, wi)
mystery.found(m, ki, 2)
P(2)().hold[#P(2)().hold + 1] = items.stamp(P(2)(), mystery.item(m, ki), 1, nil)
P(1)().clamped_by = nil
game.enter_sector(T.state(), g.spine[4])
T.wait(30)
local hi = heart.site(T.state())
local core, _, croom = heart.core(T.state())
ruin, origin = game.ruin(hi), T.state().sector.sites[hi].pos
for _, pi in ipairs({ 2, 1 }) do
  local get = P(pi)
  ap.take_helm(T, pi, get)
  ap.travel(T, pi, get, ap.route(ruin, origin, croom, 2)[1].pos, 4, 60 * 150)
  full(pi)
  local route = {}
  for _, w in ipairs(ap.route(ruin, origin, croom, 2)) do
    local prev = route[#route]
    if prev and math.abs(w.pos[2] - prev.pos[2]) > 10
      and math.abs(w.pos[1] - prev.pos[1]) + math.abs(w.pos[3] - prev.pos[3]) > 3 then
      route[#route + 1] = { pos = { prev.pos[1], w.pos[2], prev.pos[3] }, tol = 1.0, size = w.size }
    end
    route[#route + 1] = w
  end
  ap.resize(T, pi, get, 2)
  ap.travel(T, pi, get, route[1].pos, 3)
  if pi == 1 then route = { route[1], route[2], route[3] } end
  ap.follow(T, pi, get, route, 1500)
end
ap.wait_until(T, 2, function() return T.state().mystery.heart_open end, 600)
T.wait(60)
shot("07_heart_site")

-- 7. two more players join at the Heart: four saucers, four views
for i = 3, 4 do
  T.press(i, "use")
  T.wait(2)
end
for i = 3, 4 do ap.wake(T, i, P(i)) end
for i = 3, 4 do ap.take_helm(T, i, P(i)) end
T.axis(3, "lift", 1) T.axis(4, "lift", 1)
T.wait(90)
T.axis(3, "lift", 0) T.axis(4, "lift", 0)
face(3, 4)
face(4, 3)
shot("08_coop_4p")
print("m8 tour done")
