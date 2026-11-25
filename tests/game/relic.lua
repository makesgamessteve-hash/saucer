-- SPDX-License-Identifier: MIT
-- add-relic-stations, add-relic-dungeons (run with --relic-slice): the Vyrr warren relic is added to the sector and
-- the party starts at its maw. Fold bays: regrowing from the Seat in a cradle bay is free at any yaw, a Villa resting
-- in one refills 1 Charge a second; the Seat-lock opens for the Seat only and stays open across a restore; the
-- reliquary's finds pay double and the Core's XL idol needs the Villa's beam; no sentries; the materials setting
-- never changes the state hash.
local T = saucer.test
local ap = require("sim.autopilot")
local relic = require("sim.relic")
local game = require("sim.game")
local ruinm = require("sim.ruin")
local shipm = require("sim.ship")
local tractor = require("sim.tractor")
local configs = require("sim.config")
local get = function() return T.state().players[1] end

T.wait(5)
local state = T.state()
local i = relic.site_index(state)
T.assert(i ~= nil, "the relic site is in the sector")
local site = state.sector.sites[i]
T.assert(site.kit == "relic" and site.relic_civ == "vyrr", "a Vyrr relic")
local r = game.ruin(i)
T.assert(r and r.relic and r.relic.archetype == "warren", "a warren relic")
T.assert(#game.sentries(i) == 0, "no sentries in the slice")
T.assert(r.relic.length >= 1000, "over a kilometre deep: " .. r.relic.length)
T.assert(#r.relic.chambers >= 15 and r.relic.levels >= 3, "Seat chambers on three or more levels")
T.assert(r.relic.route_m >= 1000, "the heart is at least 1 km of route from the maw: " .. r.relic.route_m)
-- the party starts outside the maw
local door = ruinm.entrance(r, site.pos)
T.assert(math.abs(get().ship.pos[3] - (door[3] - 90)) < 1, "the saucer waits outside the maw")

T.assert(ap.wake(T, 1, get), "woke")
T.assert(ap.take_helm(T, 1, get), "at the helm")

local function park(pos, yaw, size)
  local s = get().ship
  s.pos, s.vel, s.yaw = { pos[1], pos[2], pos[3] }, { 0, 0, 0 }, yaw or 0
  if size then s.size = size end
  T.wait(2)
end
local function settle() for _ = 1, 400 do T.wait(1) if not get().ship.morph then return end end end

-- 1. a lung bay: regrow from the Seat at eight yaws, never paying
local bay
for _, b in ipairs(r.relic.bays) do if not bay and b.room == r.relic.lung and b.quadrant then bay = b end end
T.assert(bay ~= nil, "a bay in the breathing hall")
for k = 0, 7 do
  local yaw = k * math.pi / 4
  park({ bay.marker[1], bay.cradle[2] + 7, bay.marker[3] }, yaw, 1)
  get().ship.charge = 100
  T.press(1, "shrink")
  settle()
  T.assert(get().ship.size == 2, "shrank to the Seat at yaw " .. k)
  -- nose the Seat over the cradle's marker, the way a pilot would
  local s = get().ship
  local eye = shipm.eye_world(s.pos, s.yaw, 2)
  local c = shipm.center_for_eye({ bay.marker[1], bay.marker[2], bay.marker[3] }, s.yaw, 2)
  park(c, s.yaw)
  T.assert(relic.cradle_of(T.state(), get()) ~= nil, "the Seat is in the cradle bay")
  T.assert(relic.free_regrow(T.state(), get(), 1), "growing here is free")
  local before = get().ship.charge
  T.press(1, "grow")
  settle()
  T.assert(get().ship.size == 1, "regrew to the Villa at yaw " .. k .. " (" .. tostring(eye[1]) .. ")")
  T.assert(get().ship.charge >= before - 1e-6, "regrowing in a cradle bay costs nothing")
end

-- 2. the cradle refills a resting Villa at 1 Charge a second
park({ bay.marker[1], bay.cradle[2] + 7, bay.marker[3] }, 0, 1)
get().ship.charge = 40
T.assert(relic.cradle_regen(T.state(), get()) == relic.CRADLE_REGEN, "a Villa in a bay regenerates")
T.wait(120)
local gained = get().ship.charge - 40
T.assert(gained > 1.8 and gained < 2.2, "about 1 Charge a second in a cradle bay: " .. gained)

-- 3. outside the bays a regrow costs its usual price (and nothing refills inside the relic)
local hall1 = r.rooms[r.relic.halls[1]]
local hmn, hmx = ruinm.room_box(hall1, ruinm.kit_of("relic"), site.pos)
local mid = { (hmn[1] + hmx[1]) / 2, hmn[2] + 0.5 + 14, (hmn[3] + hmx[3]) / 2 }
park(mid, 0, 1)
if relic.cradle_of(T.state(), get()) then park({ mid[1], mid[2], mid[3] + 30 }, 0, 1) end
T.assert(relic.cradle_of(T.state(), get()) == nil, "away from the bays")
T.assert(relic.cradle_regen(T.state(), get()) == nil, "no cradle regeneration outside a bay")
get().ship.charge = 100
T.press(1, "shrink")
settle()
local gpos, fits = relic.ghost(T.state(), get())
T.assert(gpos ~= nil and fits, "the ghost Villa shows green in a Villa-class space")
local before = get().ship.charge
T.press(1, "grow")
settle()
T.assert(get().ship.size == 1, "regrew in the hall")
local paid = before - get().ship.charge
T.assert(paid > shipm.cost(2, 1) - 0.5, "a regrow outside a bay pays: " .. paid)

-- 4. the Seat-lock: closed until the Seat holds Use at its socket
local lock = r.relic.locks[1]
T.assert(game.relic_lock_closed(i, lock.id), "the reliquary's Seat-lock starts shut")
T.assert(not relic.lock_open(T.state(), i, lock.id), "not open yet")
-- the Villa cannot reach a socket inside a 4 m passage, and a Villa at the helm is not offered it
T.assert(relic.socket_near(T.state(), get()) == nil, "no socket for the Villa")
get().ship.charge = 100
T.press(1, "shrink")
settle()
local s = get().ship
-- nose the Seat up to the socket along the lock's passage (the socket is 2 m short of the shutter)
local ld = r.doors[lock.door]
local dir = { 0, 0, 0 }
dir[ld.axis] = ld.sign
local lyaw = saucer.math.atan2(dir[1], dir[3])
local leye = { lock.socket[1] - dir[1] * 1.5, lock.socket[2], lock.socket[3] - dir[3] * 1.5 }
park(shipm.center_for_eye(leye, lyaw, 2), lyaw)
T.assert(relic.socket_near(T.state(), get()) == lock, "the Seat's nose is at the socket")
T.press(1, "use", 30)
T.assert(game.relic_lock_closed(i, lock.id), "a short press is not enough")
T.wait(5)
T.assert(get().relic_turn == nil, "letting go resets the turn")
T.press(1, "use", math.ceil(relic.LOCK_TIME * 60) + 4)
T.assert(relic.lock_open(T.state(), i, lock.id), "holding Use turns the lock")
T.assert(not game.relic_lock_closed(i, lock.id), "its shutter is no longer solid")
local snap = T.snapshot()
T.restore(snap)
T.assert(not game.relic_lock_closed(i, lock.id), "the lock stays open across a restore")

-- 5. loot: three reliquary finds and the chambers' (class 1, paid double), the hall finds, the XL idol for the Villa's
-- beam
local cands = tractor.candidates(T.state(), get(), i, r)
local warren, hall, idol = 0, 0, nil
for _, c in ipairs(cands) do
  local slot = c.kind == "slot" and r.slots[tonumber(c.key:match(":(%d+)$"))] or nil
  if not slot then -- not one of the relic's own slots
  elseif c.item.xl then idol = c
  elseif slot and slot.warren then
    warren = warren + 1
    T.assert(c.item.size == 1, "a reliquary find fits the Seat's beam")
  else hall = hall + 1 end
end
local want_w, want_h = 0, 0
for _, sl in ipairs(r.slots) do
  if sl.warren then want_w = want_w + 1 elseif not sl.idol then want_h = want_h + 1 end
end
T.assert(warren == want_w and warren >= 3 + 15, "every reliquary and chamber find: " .. warren)
T.assert(hall == want_h and hall >= 3, "the hall finds: " .. hall)
T.assert(idol and idol.item.size == 4 and idol.item.value >= 1800, "the Core's XL idol")
T.assert(idol.item.size > tractor.beam_of(get().ship).class, "the Seat cannot lift the idol")
T.assert(idol.item.size <= configs.get(1).tractor_class, "the Villa's beam can")

-- 6. the materials setting is render-only: runs with them full, lite and off end in the same state (compared as
-- snapshots: T.state_hash also mixes in the engine's tick, which a restore inside a script does not rewind)
local start = T.snapshot()
local function run(m)
  T.restore(start)
  saucer.render.settings({ materials = m })
  T.axis(1, "move_z", -1, 40)
  T.axis(1, "turn", 1, 30)
  T.wait(80)
  return T.snapshot()
end
local s_full = run("full")
local s_off = run("off")
local s_lite = run("lite")
T.assert(s_full == s_off and s_off == s_lite, "materials full, lite and off end in one state")
T.assert(saucer.render.settings().materials == "lite", "the setting took")
saucer.render.settings({ materials = "full" })
-- 7. the heart is reachable: the Villa flies in at the maw and through the warren (its doors, trunks and shafts) to
-- the heart, never folding
relic.to_maw(T.state(), i)
get().ship.size = 1
T.wait(2)
local t0 = T.state().tick
-- (the heart's centre is its engine column: the last waypoint is just inside its door instead)
local route = ap.route(r, site.pos, r.relic.core)
route[#route] = nil
T.assert(ap.travel(T, 1, get, route[1].pos, 3), "at the maw")
local ok, at = ap.follow(T, 1, get, route, 1500)
T.assert(ok, "flew from the maw to the heart (stuck at waypoint " .. tostring(at) .. ")")
T.assert(ruinm.room_at(r, site.pos, get().ship.pos) == r.rooms[r.relic.core], "the Villa is in the heart")
T.assert(get().ship.size == 1, "as the Villa all the way")
local flown = (T.state().tick - t0) / 60
saucer.log.info(string.format("relic: length=%.0f villa_share=%.2f bays=%d chambers=%d route=%.0fm flight=%.0fs (%d waypoints) gained=%.2f paid=%.1f snapshot=%d bytes",
  r.relic.length, r.relic.villa_share, #r.relic.bays, #r.relic.chambers, r.relic.route_m, flown, #route, gained, paid, #s_full))
