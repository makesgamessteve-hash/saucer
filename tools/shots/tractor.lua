-- SPDX-License-Identifier: MIT
-- Screenshot tour for the belly tractor beam (OpenSpec add-tractor-beam). Run
-- from the folder that should receive shots_tractor/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/tractor.lua
-- Everything is played for real: fly into the first great hall, hover over
-- the long scrap, walk down to the Tractor Room, trim, pull.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local tractor = require("sim.tractor")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots_tractor/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local SHOTS = nil -- set to e.g. "03 04" while iterating on a few shots
local function want(n) return not SHOTS or SHOTS:find(n, 1, true) end

local st = T.state()
local ruin = game.ruin(1)
local origin = st.sector.sites[1].pos
T.wait(30)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local long, vault
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do
  if c.axis and ruin.rooms[c.room].class >= 4 and not long then long = c end
end
for _, r in ipairs(ruin.rooms) do if r.kind == "vault" then vault = r end end
local vroute = ap.route(ruin, origin, vault.id)
local hi
for i, id in ipairs(ap.chain(ruin, vault.id)) do if id == long.room then hi = i end end
local to_hall = {}
for i = 1, 3 * hi do to_hall[#to_hall + 1] = vroute[i] end
ap.follow(T, 1, get, to_hall, 1500)

-- 1. at the helm over the long scrap, keel across it: the HUD scope says turn
local spot = ap.beam_spot(long.pos, 1)
local wrong = long.axis + 1.05
ap.fly(T, 1, get, spot, 0.3, 1500, { spot[1] + saucer.math.sin(wrong) * 80, spot[2], spot[3] + saucer.math.cos(wrong) * 80 })
ap.wait_until(T, 1, function() return vec.len(get().ship.vel) < 0.2 end, 600)
if want("01") then
  ap.look(T, 1, get, get().ship.yaw, -0.45, 240)
  T.press(1, "tractor")
  shot("01_helm_lineup_hint")
end
-- 2. the Tractor Room from its stair: floor window, sling seat, console arms, cargo tube, racks
T.press(1, "use")
T.wait(2)
ap.walk_to(T, 1, get, "belly_low")
if want("02") then
  ap.look(T, 1, get, 1.45, -0.3, 240)
  shot("02_tractor_room")
end
-- 3. at the console, looking down through the glass: the scope says turn
ap.to_console(T, 1, get)
if want("03") then
  T.wait(40) -- the iris opens to its viewing aperture
  T.press(1, "tractor")
  shot("03_console_misaligned")
end
-- 4. trimmed round: the cone locks onto the scrap, the keel line matches its axis
ap.trim_to(T, 1, get, spot, ap.beam_yaw(long, get().ship.yaw))
if want("04") then shot("04_console_locked") end
-- 5. pulling: the scrap rises up the beam and shrinks, the iris opens
T.press(1, "tractor")
T.wait(math.floor(get().tractor.total * 60 * 0.6))
if want("05") then T.screenshot(D .. "05_pull_shrinking.png") end
ap.wait_until(T, 1, function() return not get().tractor end, 900)
-- 6. the hold racks light a cubby for every item aboard (get up and turn to the port rack)
if want("06") then
  T.press(1, "use")
  T.wait(2)
  ap.walk(T, 1, get, { 0.0, -5.2, 2.0 }, 0.25, 600)
  ap.look(T, 1, get, 0, -0.3, 240)
  shot("06_hold_racks")
end
-- 7. outside: the chase camera watches the Villa beam up the next item in the vault
ap.back_to_helm(T, 1, get)
local rest = {}
for i = 3 * hi + 1, #vroute do rest[#rest + 1] = vroute[i] end
ap.follow(T, 1, get, rest, 1500)
local target
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do
  if c.room == vault.id and c.kind == "slot" and c.item.size >= 2 then target = c end
end
target = target or long
-- face away from the vault's middle so the chase camera hangs back inside the hall
local ruinm = require("sim.ruin")
local mid = ap.room_center(vault, ruinm.kit_of(ruin.kit), origin, 0)
ap.look(T, 1, get, saucer.math.atan2(target.pos[1] - mid[1], target.pos[3] - mid[3]), 0, 300)
ap.hover_over(T, 1, get, target, 4)
ap.to_console(T, 1, get)
T.press(1, "camera")
T.press(1, "tractor")
T.wait(math.floor((get().tractor and get().tractor.total or 1) * 60 * 0.4))
if want("07") then T.screenshot(D .. "07_exterior_beam.png") end
T.press(1, "camera")
ap.wait_until(T, 1, function() return not get().tractor end, 900)
print("tractor shots done, hold " .. #get().hold)
