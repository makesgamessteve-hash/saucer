-- SPDX-License-Identifier: MIT
-- Screenshot tour for milestone 7 (OpenSpec add-on-foot-excursions). Run from
-- the folder that should receive shots_m7/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/m7.lua
-- Played for real (the same route as tests/game/excursion.lua); the only
-- staging is the suit being drained to 12% once you are back in the hall, so
-- the Lifeline does not take two minutes.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ex = require("sim.excursion")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots_m7/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
local function face(q, pitch, ticks)
  local b = get().excursion.body
  ap.ex_look(T, 1, get, saucer.math.atan2(q[1] - b.pos[1], q[3] - b.pos[3]), pitch or 0, ticks or 200)
end
local SHOTS = nil -- e.g. "03 04" while iterating
local function want(n) return not SHOTS or SHOTS:find(n, 1, true) end

T.wait(20)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local ruin, origin = game.ruin(1), T.state().sector.sites[1].pos
local f = ruin.foot
ap.enter(T, 1, get, ruin, origin, f.host)
ap.resize(T, 1, get, ex.seat_size())
local mouth = f.route[1]
ap.fly(T, 1, get, { mouth[1], mouth[2] + 1.3, mouth[3] }, 0.4, 3000)

-- 1. stepping out: the Seat folds down into your hand
T.press(1, "size3")
T.wait(math.floor(60 * 2.4 * 0.5))
if want("01") then T.screenshot(D .. "01_step_out_fold.png") end
ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 400)

-- 2. the crawlspace
ap.ex_to(T, 1, get, f.route[2], 0.3, 1500)
ap.ex_to(T, 1, get, vec.add(f.route[2], vec.scale(vec.sub(f.route[3], f.route[2]), 0.35)), 0.3, 1500)
face(f.route[4], 0)
if want("02") then shot("02_crawlspace") end
ap.ex_path(T, 1, get, { f.route[3], f.route[4] }, 0.3, 2000)
local d = f.delicates[1]
ap.ex_to(T, 1, get, d.pos, 0.5, 1200)
T.press(1, "use")
T.wait(1)

-- 3. the hand-lock, mid-turn
local lock = f.locks[1]
ap.ex_to(T, 1, get, lock.stand, 0.3, 1200)
face(lock.pos, -0.15)
T.press(1, "use")
T.wait(math.floor(60 * ex.tune().lock_time * 0.6))
if want("03") then T.screenshot(D .. "03_hand_lock.png") end
ap.wait_until(T, 1, function() return ex.lock_open(T.state(), 1, lock.id) end, 400)

-- 4. the grid console
local con = f.consoles[1]
ap.ex_to(T, 1, get, con.stand, 0.3, 1200)
face(con.pos, -0.25)
T.press(1, "use")
T.wait(math.floor(60 * ex.tune().console_time * 0.5))
if want("04") then T.screenshot(D .. "04_grid_console.png") end
ap.wait_until(T, 1, function() return ex.grid_down(T.state(), 1) end, 400)

-- 5. back in the hall, the suit runs dry: the Lifeline pulls you back
ap.ex_path(T, 1, get, { f.route[3], f.route[2], f.route[1] }, 0.3, 2000)
get().suit = 12 -- staged
local away = { 0, 0, 0 }
away[f.channel.axis] = -f.channel.sign
ap.ex_look(T, 1, get, saucer.math.atan2(away[1], away[3]), 0, 200)
ap.wait_until(T, 1, function() return (get().suit or 0) < 6 end, 60 * 30)
if want("05") then shot("05_suit_critical") end
ap.wait_until(T, 1, function() return get().mode ~= "foot" end, 60 * 30)
T.wait(math.floor(60 * ex.tune().white * 0.62))
if want("06") then T.screenshot(D .. "06_lifeline_pullback.png") end

-- 6. recover the cache by hand
local cache
for _, c in ipairs(T.state().caches) do if c.lifeline then cache = c end end
T.wait(60)
T.press(1, "size3")
T.wait(1)
ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 400)
local b = get().excursion.body
local back = vec.add(cache.pos, vec.scale(away, 2.6))
ap.ex_to(T, 1, get, { back[1], b.pos[2], back[3] }, 0.3, 800)
face(cache.pos, -0.3)
if want("07") then shot("07_recover_cache") end
ap.ex_to(T, 1, get, cache.pos, 0.4, 1200)
T.press(1, "use")
T.wait(1)

-- 7. deploy, board, and fly the Seat through the shutter the hand-lock opened
ap.ex_look(T, 1, get, saucer.math.atan2(away[1], away[3]), 0, 300)
T.press(1, "grow")
ap.wait_until(T, 1, function() return get().mode == "helm" end, 400)
local sf = f.strong_front
local up = get().ship.pos[2] + 6
ap.fly(T, 1, get, { get().ship.pos[1], up, get().ship.pos[3] }, 0.6, 1500)
ap.fly(T, 1, get, { sf[1], up, sf[3] }, 0.6, 3000)
ap.fly(T, 1, get, sf, 0.4, 3000)
local yaw = saucer.math.atan2(f.slot_pos[1] - sf[1], f.slot_pos[3] - sf[3])
local s = get().ship
local q = vec.sub(s.pos, vec.scale(vec.fwd(yaw), 4))
ap.fly(T, 1, get, q, 0.5, 1500)
ap.look(T, 1, get, yaw, 0, 300)
if want("08") then shot("08_open_shutter") end
