-- SPDX-License-Identifier: MIT
-- True 3D flight (OpenSpec add-true-3d-flight): from the helm, every input
-- goes through command frames. Lift up and down, hover holds altitude, look
-- up and thrust to climb, look down to dive, bank into a turn, fly over a
-- derelict to a point below another, and bump the underside of a hull.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local flight = require("sim.flight")
local ruinm = require("sim.ruin")
local get = function() return T.state().players[1] end
local function y() return get().ship.pos[2] end
local function hold(axes, n) for _ = 1, n do ap.hold(T, 1, axes) end end

T.wait(30)
T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")

-- straight up on the lift axis (Space / R / gamepad bumper / touch "up")
local y0 = y()
hold({ lift = 1 }, 180)
T.assert(y() > y0 + 40, "lift climbs: " .. y0 .. " -> " .. y())
local x, z = get().ship.pos[1], get().ship.pos[3]
-- release: dampening brakes to a hover that holds altitude
hold({}, 240)
local yh = y()
hold({}, 120)
T.assert(math.abs(y() - yh) < 0.05, "hover holds altitude")
T.assert(math.abs(get().ship.pos[1] - x) < 2 and math.abs(get().ship.pos[3] - z) < 2, "lift is purely vertical")

-- straight down past the start
hold({ lift = -1 }, 360)
T.assert(y() < y0 - 20, "lift descends below the start: " .. y())
hold({}, 240)

-- look up and thrust: forward follows the look pitch
T.assert(ap.look(T, 1, get, get().ship.yaw, 0.9), "looked up")
local before = y()
hold({ move_z = 1 }, 180)
T.assert(y() > before + 30, "climbs where it looks")
T.assert(ap.look(T, 1, get, get().ship.yaw, -0.9), "looked down")
before = y()
hold({ move_z = 1 }, 180)
T.assert(y() < before - 30, "dives where it looks")
T.assert(ap.look(T, 1, get, get().ship.yaw, 0), "levelled the view")
hold({}, 240)

-- bank into a turn, capped, then level out
local peak = 0
for _ = 1, 120 do
  ap.hold(T, 1, { turn = 1, move_z = 0.5 })
  peak = math.max(peak, get().ship.bank)
end
T.assert(peak > flight.BANK_MAX * 0.6 and peak <= flight.BANK_MAX + 1e-9, "banked into the turn: " .. peak)
hold({}, 300)
T.assert(math.abs(get().ship.bank) < 0.01, "levelled out")

-- a long 3D leg: to a point well below site 2, climbing over anything in the way
local st = T.state()
local b2 = game.site_bounds(2)
local below = { (b2[1][1] + b2[2][1]) / 2, b2[1][2] - 60, (b2[1][3] + b2[2][3]) / 2 }
T.assert(ap.travel(T, 1, get, below, 6, 9000), "travelled under site 2")
T.assert(y() < b2[1][2], "is below the site")
print("tick", st.tick, "under site 2 at", y())

-- push straight up into the underside: the hull stops it, nothing passes through
local r2, o2 = game.ruin(2), st.sector.sites[2].pos
local kit = ruinm.kit_of(r2.kit)
local low = r2.rooms[1]
for _, r in ipairs(r2.rooms) do if r.cell[2] < low.cell[2] then low = r end end
local mn, mx = ruinm.room_box(low, kit, o2)
local under = { (mn[1] + mx[1]) / 2, mn[2] - 30, (mn[3] + mx[3]) / 2 }
T.assert(ap.fly(T, 1, get, under, 2, 3000), "under the lowest room")
hold({ lift = 1 }, 600)
local hh = require("sim.config").get(get().ship.size).height / 2
T.assert(y() + hh <= mn[2] + 1e-6, "the underside blocks the climb")
T.assert(math.abs(get().ship.vel[2]) < 0.5, "stopped against the hull")
print("tick", st.tick, "vertical flight done")
