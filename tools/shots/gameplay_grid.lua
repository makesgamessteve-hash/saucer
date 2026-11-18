-- SPDX-License-Identifier: MIT
-- Screenshot of the grid console (OpenSpec add-sentries-and-tools-mvp 1.5, gameplay gaps). Run from
-- the folder that should receive shots_gameplay/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/gameplay_grid.lua
-- Played for real (the same route as tests/game/excursion.lua); nothing is staged.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ex = require("sim.excursion")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots_gameplay/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
local function face(q, pitch, ticks)
  local b = get().excursion.body
  ap.ex_look(T, 1, get, saucer.math.atan2(q[1] - b.pos[1], q[3] - b.pos[3]), pitch or 0, ticks or 200)
end

T.wait(20)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local ruin, origin = game.ruin(1), T.state().sector.sites[1].pos
local f = ruin.foot
ap.enter(T, 1, get, ruin, origin, f.host)
ap.resize(T, 1, get, ex.seat_size())
local mouth = f.route[1]
ap.fly(T, 1, get, { mouth[1], mouth[2] + 1.3, mouth[3] }, 0.4, 3000)
T.press(1, "size3")
ap.wait_until(T, 1, function() return get().excursion and get().excursion.coin == "pocket" end, 400)
ap.ex_to(T, 1, get, f.route[2], 0.3, 1500)
ap.ex_path(T, 1, get, { f.route[3], f.route[4] }, 0.3, 2000)
local d = f.delicates[1]
ap.ex_to(T, 1, get, d.pos, 0.5, 1200)
T.press(1, "use")
T.wait(1)
local lock = f.locks[1]
ap.ex_to(T, 1, get, lock.stand, 0.3, 1200)
face(lock.pos, -0.15)
T.press(1, "use")
ap.wait_until(T, 1, function() return ex.lock_open(T.state(), 1, lock.id) end, 600)

-- the grid console: hold Use and the site's sentries stand down until you leave
local con = f.consoles[1]
ap.ex_to(T, 1, get, con.stand, 0.3, 1200)
face(con.pos, -0.25)
T.press(1, "use")
T.wait(math.floor(60 * ex.tune().console_time * 0.5))
T.screenshot(D .. "08_grid_console_working.png")
ap.wait_until(T, 1, function() return ex.grid_down(T.state(), 1) end, 600)
T.assert(ex.grid_down(T.state(), 1), "the grid is down")
T.wait(30)
shot("09_grid_console_down")
print("gameplay grid tour done")
