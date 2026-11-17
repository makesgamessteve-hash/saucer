-- SPDX-License-Identifier: MIT
-- Milestone 8 (add-wider-dark), the Done-when: four local players share a
-- sector in split screen, each in their own saucer, and the party follows the
-- multi-sector mystery. Run with --coop (one local player; three more join
-- by pressing a button on their own slot, as gamepads or a split keyboard
-- would). Act I (three Echoes, the Resonant vault) is the milestone 3 chain,
-- driven end to end by tests/game/mystery.lua, so it is set as solved here;
-- everything after it is played through command frames: the party fold jumps
-- (proposed on the sector map, agreed by everyone), the Witness Echo behind
-- the translation gate, the Heart Key, the Heart site and the ending vote.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local mystery = require("sim.mystery")
local galaxy = require("sim.galaxy")
local archive = require("sim.archive")
local civs = require("sim.civs")
local heart = require("sim.heart")
local items = require("sim.items")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")

local function P(i) return function() return T.state().players[i] end end
local m = function() return T.state().mystery end
local function said(i, s)
  for _, x in ipairs(P(i)().msgs or {}) do if x.text:find(s, 1, true) then return true end end
  return false
end

-- 1. three more players join on their own slots, each in a new saucer
T.assert(#T.state().players == 1, "one player to start")
T.assert(ap.wake(T, 1, P(1)), "P1 got up")
for i = 2, 4 do
  T.press(i, "use")
  T.wait(1)
  T.assert(#T.state().players == i, "P" .. i .. " joined")
end
for i = 2, 4 do T.assert(ap.wake(T, i, P(i)), "P" .. i .. " got up") end
for i = 1, 4 do
  for k = i + 1, 4 do
    local a, b = P(i)(), P(k)()
    T.assert(a.ship ~= b.ship and vec.dist(a.ship.pos, b.ship.pos) > 20, "P" .. i .. " and P" .. k .. " fly their own saucers")
  end
end
T.screenshot("widerdark_4p.png")

-- 2. Act I is solved (see tests/game/mystery.lua): the vault is open
local mm = m()
for i, e in ipairs(mm.echoes) do
  if (e.sector or 1) == 1 then
    mystery.found(mm, i, 1)
    if mystery.decodable(mm, i) then mystery.decode(mm, i) end
  end
end
mystery.open_vault(mm)
T.assert(mm.act == 2 and mm.vault_open, "Act II: the vault is open")
local wi = mystery.index_of(mm, "witness")
local ki = mystery.index_of(mm, "heart_key")
local we, ke = mm.echoes[wi], mm.echoes[ki]
local g = galaxy.generate(T.state().seed)
T.assert(we.sector == g.spine[2] and ke.sector == g.spine[3] and mm.heart_sector == g.spine[4],
  "the chain runs across the spine of sectors")
T.assert(mystery.resonant_sectors(mm)[g.spine[2]], "the Witness's sector is Resonant on the map")

-- 3. a party fold jump: P1 proposes on the map, the others agree
local function jump(to)
  local name = g.sectors[to].name
  for i = 1, 4 do
    T.assert(ap.take_helm(T, i, P(i)), "P" .. i .. " at the helm")
    T.assert(ap.resize(T, i, P(i), 1), "P" .. i .. " in the Villa")
  end
  T.press(1, "map")
  T.wait(1)
  T.assert(P(1)().panel and P(1)().panel.kind == "map", "P1 opened the sector map")
  T.assert(ap.pick(T, 1, P(1), name), "P1 proposed the jump to " .. name)
  T.assert(T.state().jump and T.state().jump.to == to, "a jump is proposed")
  for i = 2, 4 do
    T.press(i, "map")
    T.wait(1)
    T.assert(ap.pick(T, i, P(i), "Agree: "), "P" .. i .. " agreed")
  end
  -- folding needs Charge: saucers low after a dive recharge in open space first
  T.assert(ap.wait_until(T, 1, function() return T.state().sector_id == to end, 60 * 120), "the party folded to " .. name)
  for i = 1, 4 do
    T.assert(P(i)().site == 0 and said(i, "Fold jump complete"), "P" .. i .. " arrived in " .. name)
  end
end

-- add-home-among-stars: danger-3 sectors keep a Warden (tests/lua/widerdark_spec.lua
-- covers it). This script follows the mystery chain, so the party's Override
-- spike has already shut the sector's Wardens down for good.
local function wardens_off()
  local adv = require("sim.advsentry")
  for si = 1, #T.state().sector.sites do
    for k, d in ipairs(game.sentries(si)) do
      if d.kind == "warden" then
        T.state().overrides = T.state().overrides or {}
        T.state().overrides[adv.key(d)] = T.state().tick
        T.state().sentries[si][k].st = "off"
      end
    end
  end
end

-- fetch the Echo at a site of this sector with player pi (the Seat)
local function fetch(pi, site, size)
  local get = P(pi)
  local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
  local room
  for _, r in ipairs(ruin.rooms) do if r.echo_pos then room = r.id end end
  T.assert(room ~= nil, "site " .. site .. " hosts an Echo")
  T.assert(mystery.echo_at(m(), site, T.state().sector_id) ~= nil, "the Echo at site " .. site .. " is unlocked")
  T.assert(ap.take_helm(T, pi, get), "at the helm")
  T.assert(ap.resize(T, pi, get, 1), "the Villa for the trip")
  T.assert(ap.travel(T, pi, get, ap.route(ruin, origin, room, size)[1].pos, 4, 60 * 150), "flew to site " .. site)
  -- the Shroud hides the saucer from Watchers and Clamps on the way in
  T.press(pi, "shroud")
  T.wait(1)
  T.assert(get().shroud, "P" .. pi .. " raised the Shroud")
  local ok, route = ap.enter(T, pi, get, ruin, origin, room, size)
  T.assert(ok, "flew into site " .. site .. "'s Echo room")
  local door = ap.door_center(ap.door_of(ruin, room), ruin.rooms, ruinm.kit_of(ruin.kit), origin)
  T.assert(ap.grab(T, pi, get, site, ruin, room, door, function(c) return c.kind == "echo" end) == 1,
    "tractored the Echo at site " .. site)
  T.assert(ap.leave(T, pi, get, route), "back out of site " .. site)
  if get().shroud then
    T.press(pi, "shroud")
    T.wait(1)
  end
  T.assert(not get().shroud, "Shroud down")
  T.assert(get().site == 0, "in open space (site " .. get().site .. ")")
end

-- 4. Act II: the Witness, behind the translation gate
jump(g.spine[2])
fetch(1, we.site, 2)
T.assert(said(1, "Echo IV"), "the Witness Echo is aboard")
local function decode(idx, expect_ok)
  local get = P(1)
  T.assert(ap.take_helm(T, 1, get), "at the helm")
  T.assert(ap.resize(T, 1, get, 1), "unfolded the Villa")
  T.assert(ap.walk_to_station(T, 1, get, "lab"), "walked to the lab bench")
  T.press(1, "use")
  T.wait(1)
  local name = mystery.item(m(), idx).name
  local ok = ap.pick(T, 1, get, "Decode " .. name)
  T.assert(ap.pick(T, 1, get, "Close"), "closed the bench")
  if expect_ok then
    T.assert(ok, "queued " .. name)
    T.assert(ap.wait_until(T, 1, function() return m().echoes[idx].decoded end, 60 * 40), "decoded " .. name)
  end
  return ok
end
local gate = civs.by_id(T.state().seed, we.gate_civ)
T.assert(gate ~= nil and archive.best(T.state(), gate.id) < mystery.GATE, "the gate civ is barely archived")
decode(wi, false)
T.assert(not m().echoes[wi].decoded and said(1, "Xenoarchive"), "the Witness speaks " .. gate.name .. ": translation needed")
-- the party files finds of the gate civ (identifying is driven by tests/game/trade.lua)
local cat = archive.catalog(gate)
local need = math.ceil(#cat * mystery.GATE / 100)
for k = 1, need do
  local it = items.stamp(P(2)(), { type = cat[k], civ = gate.id }, 1, nil)
  archive.record(T.state(), P(2)(), it, { msg = function() end, fx = function() end })
end
T.assert(archive.best(T.state(), gate.id) >= mystery.GATE, "P2's Xenoarchive reaches the gate")
decode(wi, true)
T.assert(m().act == 3, "Act III: the Witness names the Heart")

-- 5. Act III: the Heart Key, one more sector in
jump(g.spine[3])
wardens_off()
fetch(2, ke.site, 2)
T.assert(heart.key_item(T.state(), P(2)()) ~= nil, "P2 carries the Heart Key")
jump(g.spine[4])
wardens_off()
T.assert(T.state().sector.sites[heart.site(T.state())].heart, "the Heart site is in this sector")

-- 6. the Heart: P2 carries the Key to the core, P1 comes along; both vote
local hi = heart.site(T.state())
local core, _, croom = heart.core(T.state())
local ruin, origin = game.ruin(hi), T.state().sector.sites[hi].pos
local routes = {}
for _, pi in ipairs({ 2, 1 }) do
  local get = P(pi)
  T.assert(ap.take_helm(T, pi, get), "P" .. pi .. " at the helm")
  T.assert(ap.travel(T, pi, get, ap.route(ruin, origin, croom, 2)[1].pos, 4, 60 * 150), "P" .. pi .. " flew to the Heart")
  -- the jump spent Charge: top up in open space before the dive
  T.assert(ap.wait_until(T, pi, function() return get().ship.charge >= 60 end, 60 * 90), "P" .. pi .. " recharged")
  -- the Heart's route climbs a shaft and leaves it by a door at the top:
  -- climb in the middle of the shaft first, then cross to the door
  local route = {}
  for k, w in ipairs(ap.route(ruin, origin, croom, 2)) do
    local prev = route[#route]
    if prev and math.abs(w.pos[2] - prev.pos[2]) > 10
      and math.abs(w.pos[1] - prev.pos[1]) + math.abs(w.pos[3] - prev.pos[3]) > 3 then
      route[#route + 1] = { pos = { prev.pos[1], w.pos[2], prev.pos[3] }, tol = 1.0, size = w.size }
    end
    route[#route + 1] = w
  end
  T.assert(ap.resize(T, pi, get, 2), "P" .. pi .. " in the Seat")
  T.assert(ap.travel(T, pi, get, route[1].pos, 3), "P" .. pi .. " at the Heart's entry")
  -- P2 goes all the way to the core; P1 waits just inside the entrance
  if pi == 1 then
    local short = {}
    for k = 1, 3 do short[k] = route[k] end
    route = short
  end
  local ok = ap.follow(T, pi, get, route, 1500)
  routes[pi] = route
  local q = get()
  T.assert(ok, string.format("P%d flew into the Heart's core room (at %.1f m from %s, site %d, clamped %s, shroud %s, CHG %d, size %d)",
    pi, vec.dist(q.ship.pos, route[#route].pos), tostring(#route), q.site, tostring(q.clamped_by ~= nil),
    tostring(q.shroud), q.ship.charge // 1, q.ship.size))
end
T.assert(ap.wait_until(T, 2, function() return m().heart_open end, 600), "the Heart opened to the Key")
T.assert(m().last_key_by == 2, "P2 set the last Key")
T.assert(#heart.present(T.state()) == 2, "two players inside the Heart site")
local endings = m().endings
T.screenshot("widerdark_heart.png")
local function vote(pi, e)
  T.press(pi, "map")
  T.wait(1)
  T.assert(ap.pick(T, pi, P(pi), "Vote on an ending"), "P" .. pi .. " opened the vote")
  T.assert(P(pi)().panel and P(pi)().panel.kind == "heart", "P" .. pi .. "'s vote panel")
  T.assert(ap.pick(T, pi, P(pi), e.title), "P" .. pi .. " voted " .. e.id)
end
vote(1, endings[1])
T.assert(not m().ending, "one vote of two: no ending yet")
vote(2, endings[2])
T.assert(m().ending == endings[2].id, "a tie goes to whoever set the last Key: " .. tostring(m().ending))
T.assert(m().act == 4, "the mystery is over")
for i = 1, 4 do T.assert(said(i, "ENDING: " .. endings[2].title), "P" .. i .. " saw the ending") end
local carried = 0
for _, pi in ipairs({ 1, 2 }) do
  for _, it in ipairs(P(pi)().hold) do if it.name == mystery.centerpiece(m()).name then carried = carried + 1 end end
end
T.assert(carried == 2, "both players inside carry the centerpiece home")
T.assert(ap.leave(T, 1, P(1), routes[1]), "P1 back out of the Heart")
T.assert(P(1)().site == 0, "P1 is back in open space")
print(string.format("widerdark: ending %s at tick %d, sectors visited %d", m().ending, T.state().tick,
  (function() local n = 0 for _ in pairs(T.state().visited) do n = n + 1 end return n end)()))
