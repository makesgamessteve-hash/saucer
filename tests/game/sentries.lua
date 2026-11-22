-- SPDX-License-Identifier: MIT
-- Milestone 3: a sentry encounter at derelict 2. Scan it, fly the Villa into
-- a Watcher's hall (Alert for at least 0.75 s, then Locked, stun bolts drain
-- the shields), fold to the Seat (below its size band: it goes Dormant),
-- grab hot loot in a duct, Jam a latching Snatcher, let it steal on the next
-- try and tractor the item back from its nest; then let the Watchers break
-- the Villa's hull: Fold Retreat to the trader, hot items left as a cache,
-- banked cargo kept, and the cache recovered with the Seat.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local items = require("sim.items")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function door_of(ruin, origin, room)
  return ap.door_center(ap.door_of(ruin, room), ruin.rooms, ruinm.kit_of(ruin.kit), origin)
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")

-- a banked item first: one hall item from the tutorial derelict
local r1, o1 = game.ruin(1), T.state().sector.sites[1].pos
local hall1
for _, s in ipairs(r1.slots) do if r1.rooms[s.room].kind == "hall" then hall1 = s.room end end
T.assert(hall1 ~= nil, "tutorial hall has loot")
-- add-fun-fixes: the tutorial hall keeps a light Watcher (tests/lua/funfixes_spec.lua covers it);
-- this script banks one item first, so its grid is shut beforehand to keep the shields full for derelict 2
do
  local adv = require("sim.advsentry")
  T.state().overrides = T.state().overrides or {}
  for _, d in ipairs(game.sentries(1)) do T.state().overrides[adv.key(d)] = T.state().tick end
  for _, dy in ipairs(T.state().sentries[1] or {}) do dy.st = "off" end
end
local ok, route = ap.enter(T, 1, get, r1, o1, hall1)
T.assert(ok, "into the tutorial hall")
T.assert(ap.grab(T, 1, get, 1, r1, hall1, door_of(r1, o1, hall1)) >= 1, "grabbed hall loot")
T.assert(ap.leave(T, 1, get, route), "left")
local banked = get().hold[1]
T.assert(banked and not banked.hot, "that item is banked")

-- derelict 2: three Watchers and a Snatcher
local site = 2
local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
local defs = game.sentries(site)
local watcher, snatcher
for i, d in ipairs(defs) do
  if d.kind == "watcher" and not watcher then watcher = i end
  if d.kind == "snatcher" and not snatcher then snatcher = i end
end
T.assert(watcher and snatcher, "derelict 2 has a Watcher and a Snatcher")
local wdef, sdef = defs[watcher], defs[snatcher]
local function dyn(i) return T.state().sentries[site][i] end

local first = ap.route(ruin, origin, wdef.room)[1]
T.assert(ap.travel(T, 1, get, first.pos, 4, 6000), "flew to derelict 2")
T.press(1, "scan")
T.wait(1)
local nw, ns = require("sim.sentry").summary(defs)
T.assert(nw >= 2, "a huge 3D station has several Watchers (" .. nw .. ")")
T.assert(said(string.format("Scan: site 2, danger 2, %d Watchers, %d Snatcher", nw, ns)), "the scanner reads the site")
T.assert(get().scan_until > T.state().tick, "sentries revealed for 10 s")

-- the Villa in the Watcher's hall
ok, route = ap.enter(T, 1, get, ruin, origin, wdef.room)
T.assert(ok, "the Villa flew into the Watcher's hall")
T.assert(ap.wait_until(T, 1, function() return dyn(watcher).st ~= "dormant" end, 600), "the Watcher noticed the Villa")
T.assert(ap.wait_until(T, 1, function() return dyn(watcher).st == "locked" end, 300), "then Locked")
local in_alert = dyn(watcher).lock_tick - dyn(watcher).alert_tick
T.assert(in_alert >= 45, "at least 0.75 s in Alert first (" .. in_alert .. " ticks)")
T.assert(ap.wait_until(T, 1, function() return get().ship.shield < 100 end, 600), "stun bolts hit the shields")
T.assert(get().ship.hull == 100, "shields take the first hits")

-- fold to the Seat: below the band, the Watcher loses interest within 2 s
T.assert(ap.resize(T, 1, get, 2), "folded to the Seat")
T.assert(ap.wait_until(T, 1, function() return dyn(watcher).st == "dormant" end, 120), "Watcher Dormant within 2 s")

-- out to the duct with the Snatcher, loot its side room (hot cargo)
T.assert(ap.leave(T, 1, get, route, ap.route(ruin, origin, sdef.room, 2)[1].pos), "back out of the hall")
ok, route = ap.enter(T, 1, get, ruin, origin, sdef.nest_room, 2)
T.assert(ok, "the Seat squeezed into the duct")
T.assert(ap.grab(T, 1, get, site, ruin, sdef.nest_room, door_of(ruin, origin, sdef.nest_room)) >= 1, "hot loot in hand")
local hot = items.losable(get())
T.assert(#hot >= 1, "carrying hot cargo")
T.assert(ap.wait_until(T, 1, function() return dyn(snatcher).st == "latched" end, 900), "the Snatcher latched on")
T.assert(ap.wait_until(T, 1, function() return dyn(snatcher).t >= 1.5 end, 200), "1.5 s into the latch")
local n = #get().hold
T.press(1, "jam")
T.wait(1)
T.assert(dyn(snatcher).st == "disabled", "jammed: the Snatcher reboots")
T.assert(#get().hold == n and not get().latched_by, "the latch broke and nothing was taken")
T.assert(said("disabled for 12 s"), "Jammer readout")

-- it reboots, latches again and gets away with an item to its nest
T.assert(ap.wait_until(T, 1, function() return dyn(snatcher).st == "flee" end, 60 * 20), "it stole on the next try")
T.assert(#get().hold == n - 1, "one hot item gone")
T.assert(ap.wait_until(T, 1, function() return #T.state().nests == 1 end, 600), "dropped in its nest")
local nest = T.state().nests[1]
T.assert(nest.item.hot, "the nest item is still the player's")
-- an input API that jams whenever the Snatcher latches on while we fly out
local jams = 0
local guard = setmetatable({ wait = function(k)
  for _ = 1, k or 1 do
    if get().latched_by and T.state().tick >= get().jam_ready then
      T.press(1, "jam")
      jams = jams + 1
    end
    T.wait(1)
  end
end }, { __index = T })
-- tractor it back before it wakes up again (jam it first)
T.wait(30)
local function aim_jam(what)
  T.assert(ap.wait_until(guard, 1, function() return T.state().tick >= get().jam_ready end, 900), "Jammer ready")
  -- track it: it may still be drifting back to its nest
  for _ = 1, 8 do
    local e, q = game.viewpoint(get()), dyn(snatcher).pos
    if ap.look(T, 1, get, saucer.math.atan2(q[1] - e[1], q[3] - e[3]), ap.pitch_to(e, q), 30) then
      local e2, q2 = game.viewpoint(get()), dyn(snatcher).pos
      if require("lib.vec").dist(q, q2) < 0.05 then break end
    end
  end
  T.press(1, "jam")
  T.wait(1)
  T.assert(dyn(snatcher).st == "disabled", what .. " (" .. dyn(snatcher).st .. ", " ..
    require("lib.vec").dist(game.viewpoint(get()), dyn(snatcher).pos) .. " m)")
end
aim_jam("Snatcher jammed in its nest")
local back = ap.grab(guard, 1, get, site, ruin, sdef.nest_room, door_of(ruin, origin, sdef.nest_room),
  function(c) return c.kind == "nest" end)
T.assert(back == 1 and #T.state().nests == 0, "tractored the item back from the nest")
T.assert(#get().hold == n, "the hold is whole again")
-- jam it once more for a head start, then get out of its duct
aim_jam("Snatcher jammed again")

-- out into the Watcher's hall again, unfold the Villa and let the hull break
-- (stay inside the site boundary so the cargo stays hot)
local wroute = ap.route(ruin, origin, wdef.room, 2)
local inner = {}
for i = 3, #route do inner[#inner + 1] = route[i] end
T.assert(ap.leave(guard, 1, get, inner, wroute[3].pos), "out of the duct into the entrance hall")
T.assert(get().site == site and #items.losable(get()) >= 1, "still in the site with hot cargo: site " .. get().site ..
  " hot " .. #items.losable(get()))
local rest = {}
for i = 4, #wroute do rest[#rest + 1] = wroute[i] end
T.assert(ap.follow(T, 1, get, rest, 1500), "the Seat flew on into the Watcher's hall")
T.assert(get().site == site, "still inside the derelict")
local hall_c = ap.room_center(ruin.rooms[wdef.room], ruinm.kit_of(ruin.kit), origin,
  require("sim.config").get(1).height / 2 + 1.5)
local spot = ap.spot_for(hall_c, get().ship.yaw, 2, 1)
T.assert(ap.fly(T, 1, get, spot, 0.3, 1500), "found room for the Villa")
T.assert(ap.resize(T, 1, get, 1), "unfolded the Villa in the hall")
-- add-fun-fixes: carry a second hot find so half survives the fold as a cache
do
  local h = get().hold
  h[#h + 1] = items.stamp(get(), { type = "coil", name = "Spare coil", value = 10, size = 1, hot = true }, 1)
end
local hot_n = #items.losable(get())
T.assert(hot_n >= 1, "hot items aboard")
T.assert(ap.wait_until(T, 1, function() return (get().retreats or 0) == 1 end, 60 * 120), "Fold Retreat at hull 0")
T.assert(said("FOLD RETREAT"), "retreat message")
T.assert(get().site == 0 and get().ship.size == 1, "back outside as the Villa")
local tp = T.state().sector.trader.pos
T.assert(require("lib.vec").dist(get().ship.pos, tp) < 150, "at the trader")
T.assert(#items.losable(get()) == 0, "no hot items left aboard")
T.assert(items.find(get(), banked.uid) ~= nil, "the banked item is safe")
local cache = T.state().caches[1]
-- add-fun-fixes: the fold tears away half the hot cargo (rounded up); the rest is the cache
local torn = math.ceil(hot_n * require("sim.sentry").tune().retreat_lose - 1e-9)
T.assert(get().retreat_lost == torn, "the fold tore away " .. torn .. " of " .. hot_n .. " hot items")
T.assert(said("for good"), "the loss is reported")
T.assert(cache and cache.site == site and #cache.items == hot_n - torn,
  "a cache with the rest of the hot items sits in the derelict (" .. hot_n .. " hot)")

-- recover it with the Seat (the Watchers ignore it)
T.assert(ap.resize(T, 1, get, 2), "folded to the Seat")
first = ap.route(ruin, origin, wdef.room, 2)[1]
T.assert(ap.travel(T, 1, get, first.pos, 3, 60 * 420), "flew back to derelict 2")
ok, route = ap.enter(T, 1, get, ruin, origin, wdef.room, 2)
T.assert(ok, "into the hall")
local cp = cache.pos
local cache_c
for _, c in ipairs(require("sim.tractor").candidates(T.state(), get(), site, ruin)) do
  if c.kind == "cache" then cache_c = c end
end
T.assert(cache_c ~= nil and require("lib.vec").dist(cache_c.pos, cp) < 1e-6, "the cache is a beam target")
T.assert(ap.fly(T, 1, get, { cp[1], cp[2] + 4, cp[3] - 3 }, 0.6, 3000), "flew up near the cache")
T.assert(ap.beam_up(T, 1, get, cache_c), "hovered over the cache and beamed it up with the Seat's mini beam")
T.assert(#T.state().caches == 0 and #items.losable(get()) == hot_n - torn, "recovered the cache")
T.assert(dyn(watcher).st == "dormant", "the Watcher never minded the Seat")
print(string.format("sentries: hits %d, retreats %d, guard jams %d, tick %d", get().hits or 0, get().retreats or 0, jams,
  T.state().tick))
