-- SPDX-License-Identifier: MIT
-- add-relic-locks (plan phase 9): a relic's foot pocket and its hand-lock. Fold to sector 3 (every universe has a
-- relic there), fly the Seat into the chamber a pocket opens off, step out on its floor (the ledge), crawl the
-- crawlspace no saucer fits, stand up in the pocket room, turn the hand-lock: a sealed chamber elsewhere in the relic
-- opens for the Seat. Then crawl back, deploy, board, and the Seat-locks on the other chambers are still shut.
local T = saucer.test
local ap = require("sim.autopilot")
local game = require("sim.game")
local ex = require("sim.excursion")
local relicfoot = require("sim.relicfoot")
local ruinm = require("sim.ruin")
local configs = require("sim.config")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end

T.wait(5)
T.assert(ap.wake(T, 1, get), "woke")
T.assert(ap.take_helm(T, 1, get), "at the helm")
game.enter_sector(T.state(), 3)
T.wait(2)
local state = T.state()
local i
for k, s in ipairs(state.sector.sites) do if s.kit == "relic" then i = k end end
T.assert(i ~= nil, "sector 3 holds a relic")
local site = state.sector.sites[i]
local r = game.ruin(i)
local f = r.foot
T.assert(f and #f.pockets >= 1 and #f.pockets <= 3, "the relic has foot pockets")
T.assert(#f.pockets <= relicfoot.count(game.civ_of(site)), "no more than its builders' body scale allows")
local pk = f.pockets[1]
T.assert(pk.role == "lock" and #f.locks == 1 and f.gated, "the first pocket holds the hand-lock")
T.assert(game.shutter_closed(i, 1), "its chamber is sealed")
local seats = 0
for _, l in ipairs(r.relic.locks) do if l.kind == "seat" then seats = seats + 1 end end
local share = seats / (seats + #f.locks)
T.assert(share >= 0.6 and share <= 0.75, string.format("60-75%% of the locks are Seat-locks (%d of %d)", seats, seats + #f.locks))

local kit = ruinm.kit_of(r.kit)
local sd = configs.get(ex.seat_size())
local sr, shh = sd.diameter / 2, sd.height / 2

-- this test is about the locks: the relic's sentries (tests/game/relic_play.lua's) stand down
local sl = game.sentries(i)
for k = #sl, 1, -1 do sl[k] = nil end

-- 1. fold to the Seat, then into the host chamber; set down at the crawlspace's mouth (the ledge)
T.assert(ap.resize(T, 1, get, ex.seat_size()), "folded to the Seat")
local hmn, hmx = ruinm.room_box(r.rooms[pk.host], kit, site.pos)
local s = get().ship
s.pos, s.vel = { (hmn[1] + hmx[1]) / 2, (hmn[2] + hmx[2]) / 2, (hmn[3] + hmx[3]) / 2 }, { 0, 0, 0 }
T.wait(2)
T.assert(get().site == i, "inside the relic")
local mouth = pk.route[1]
T.assert(ap.fly(T, 1, get, { mouth[1], mouth[2] + 1.3, mouth[3] }, 0.4, 3000), "set the Seat down on the ledge")
T.assert(not ap.clear_line(get().ship.pos, pk.route[3], sr * 0.95, shh * 0.95), "no saucer fits the crawlspace")
T.screenshot("relic_locks_ledge.png")

-- 2. step out
T.press(1, "size3")
T.wait(1)
T.assert(get().mode == "foot", "stepped out onto the ledge")
T.assert(ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 400), "the coin is in your pocket")

-- 3. crawl to the pocket room
T.assert(ap.ex_to(T, 1, get, pk.route[2], 0.3, 1500), "into the crawlspace")
T.assert(get().excursion.area == "crawl" and get().excursion.body.crouch, "crouched in the crawlspace")
T.screenshot("relic_locks_crawl.png")
T.assert(ap.ex_path(T, 1, get, { pk.route[3], pk.route[4] }, 0.3, 2000), "crawled through")
T.assert(get().excursion.area == "pocket" and not get().excursion.body.crouch, "standing in the pocket room")
T.assert(pk.length <= 60, "a short walk: " .. math.floor(pk.length) .. " m")

-- 4. turn the hand-lock: the sealed chamber opens
local lock = f.locks[1]
T.assert(ap.ex_to(T, 1, get, lock.stand, 0.3, 1200), "at the hand-lock")
T.assert(ap.ex_work(T, 1, get, function() return ex.lock_open(T.state(), i, lock.id) end, 400), "turned the hand-lock")
T.assert(not game.shutter_closed(i, 1) and said("sealed chamber grinds open"), "the sealed chamber is open")
T.screenshot("relic_locks_strongroom_lock.png")

-- 5. back out, deploy, board
T.assert(ap.ex_path(T, 1, get, { pk.route[3], pk.route[2], pk.route[1] }, 0.3, 2000), "crawled back out")
local away = { 0, 0, 0 }
away[pk.channel.axis] = -pk.channel.sign
T.assert(ap.ex_look(T, 1, get, saucer.math.atan2(away[1], away[3]), 0, 300), "faced the chamber")
T.press(1, "grow")
T.wait(1)
T.assert(ap.wait_until(T, 1, function() return get().mode == "helm" end, 400), "aboard the Seat")
T.assert(get().site == i, "still in the relic")
-- the Seat-locked chambers stay shut until the Seat turns their sockets
for _, l in ipairs(r.relic.locks) do
  T.assert(not (T.state().relic_locks or {})[tostring(i) .. ":" .. l.id], "Seat-lock " .. l.id .. " still shut")
end
print(string.format("relic_locks: site %d pockets %d seat %d hand %d length %.0f gated %d", i, #f.pockets, seats, #f.locks,
  pk.length, f.gated))
