-- SPDX-License-Identifier: MIT
-- Milestone 7: on-foot excursions (OpenSpec add-on-foot-excursions). Fly into
-- the tutorial derelict, fold to the Seat and set it down by a crawlspace,
-- step out (the saucer folds into your pocket), crawl through to the chamber
-- behind it, lift a Delicate find by hand, turn the hand-lock (a shutter in
-- the hall opens for the saucer) and shut the sentry grid down at its
-- console, crawl back out and let the suit run dry: the Lifeline deploys the
-- Seat on your trail and the find stays behind as a cache. Step out again,
-- recover the cache by hand, deploy and board (the hands empty into the
-- hold), then fly the Seat through the door the hand-lock opened and beam up
-- the strongroom's loot.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ex = require("sim.excursion")
local configs = require("sim.config")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()
local ruin, origin = game.ruin(1), st.sector.sites[1].pos
local f = ruin.foot
T.assert(f and #f.locks == 1 and #f.consoles == 1 and #f.delicates == 1, "the derelict has a crawlspace, a hand-lock and a grid console")
T.assert(game.shutter_closed(1, 1), "the strongroom is sealed")
-- the sealed door is solid: a Seat cannot get into the strongroom
local sr, shh = configs.get(ex.seat_size()).diameter / 2, configs.get(ex.seat_size()).height / 2
T.assert(not ap.clear_line(f.strong_front, f.slot_pos, sr, shh), "the shutter blocks the way in")

-- 1. fly in, fold to the Seat, set down at the crawlspace's mouth
T.assert(ap.enter(T, 1, get, ruin, origin, f.host), "flew into the host hall")
T.assert(ap.resize(T, 1, get, ex.seat_size()), "folded to the Seat")
local mouth = f.route[1]
T.assert(ap.fly(T, 1, get, { mouth[1], mouth[2] + 1.3, mouth[3] }, 0.4, 3000), "set the Seat down by the crawlspace")
-- the Seat is far too big for the crawlspace
T.assert(not ap.clear_line(get().ship.pos, f.route[3], sr * 0.95, shh * 0.95), "no saucer fits the crawlspace")

-- 2. step out: the Seat folds into your hand and goes into your pocket
local charge0 = get().ship.charge
T.press(1, "size3")
T.wait(1)
local p = get()
T.assert(p.mode == "foot" and p.excursion and p.excursion.coin == "fold", "stepped out; the saucer is folding")
T.assert(configs.get(p.ship.size).pocket and p.ship.charge < charge0, "the Pocket configuration, for Charge")
T.assert(p.suit > ex.tune().suit.max - 1 and #p.hands == 0, "a full suit, empty hands")
T.assert(ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 400), "the coin is in your pocket")

-- 3. crawl in. No deploying inside the crawlspace
T.assert(ap.ex_to(T, 1, get, f.route[2], 0.3, 1500), "into the crawlspace")
T.assert(get().excursion.body.crouch and get().excursion.area == "crawl", "crouched in the crawlspace")
T.press(1, "grow")
T.wait(1)
T.assert(get().mode == "foot" and said("No room to deploy"), "no room to deploy in a crawlspace")
T.assert(ap.ex_path(T, 1, get, { f.route[3], f.route[4] }, 0.3, 2000), "crawled through to the chamber")
T.assert(get().excursion.area == "chamber" and not get().excursion.body.crouch, "standing up in the chamber")

-- 4. lift the Delicate find by hand (the beam would crush it)
local d = f.delicates[1]
T.assert(ap.ex_to(T, 1, get, d.pos, 0.5, 1200), "at the Delicate find")
T.press(1, "use")
T.wait(1)
T.assert(#get().hands == 1 and get().hands[1].delicate, "the find is in your hands")

-- 5. the hand-lock: hold Use at the coupling; the shutter opens for the saucer
local lock = f.locks[1]
T.assert(ap.ex_to(T, 1, get, lock.stand, 0.3, 1200), "at the hand-lock")
T.assert(ap.ex_work(T, 1, get, function() return ex.lock_open(T.state(), 1, lock.id) end, 400), "turned the hand-lock")
T.assert(not game.shutter_closed(1, 1) and said("shutter grinds open"), "the shutter is open")
T.assert(ap.clear_line(f.strong_front, f.slot_pos, sr, shh), "the way into the strongroom is clear")

-- 6. the grid console (this derelict's grid was dead anyway)
local con = f.consoles[1]
T.assert(ap.ex_to(T, 1, get, con.stand, 0.3, 1200), "at the grid console")
T.assert(ap.ex_work(T, 1, get, function() return ex.grid_down(T.state(), 1) end, 400), "shut the grid down")

-- save mid-excursion: the visit, the suit, the hands and the lock are kept
require("sim.save").write(T.state())
local rec = require("sim.save").read()
local saved = rec and require("sim.save").player(rec, 1)
T.assert(saved and saved.mode == "foot" and saved.excursion and #saved.hands == 1, "the save holds the excursion")
T.assert(require("sim.save").world(rec, T.state().sector).locks["1:1"], "and the turned hand-lock")

-- 7. back out to the hall, then let the suit run dry: the Lifeline
T.assert(ap.ex_path(T, 1, get, { f.route[3], f.route[2], f.route[1] }, 0.3, 2000), "crawled back out")
T.assert(get().excursion.area == "hall", "back in the hall")
local fell = vec.copy(get().excursion.body.pos)
T.assert(ap.wait_until(T, 1, function() return get().mode ~= "foot" end, 60 * 200), "the suit ran out")
p = get()
T.assert(said("SUIT CHARGE 10%"), "the suit warned at 30% and 10%")
T.assert(p.mode == "helm" and p.ship.size == ex.seat_size() and (p.lifelines or 0) == 1 and said("LIFELINE"),
  "the Lifeline pulled you back into the Seat")
T.assert(#p.hands == 0 and p.suit == ex.tune().suit.max, "empty hands, the suit recharged")
local cache
for _, c in ipairs(T.state().caches) do if c.lifeline then cache = c end end
T.assert(cache and #cache.items == 1 and cache.items[1].delicate, "the find stayed behind as a cache")
T.assert(vec.dist(cache.pos, fell) < 1.5, "where you fell")
T.assert(vec.dist(p.ship.pos, fell) < 12 and not ex.in_box(f.crawl, p.ship.pos), "the Seat deployed on your trail")

-- 8. recover the cache: step out again, pick it up, deploy and board
T.wait(30)
T.press(1, "size3")
T.wait(1)
T.assert(get().mode == "foot", "stepped out again")
T.assert(ap.wait_until(T, 1, function() return get().excursion.coin == "pocket" end, 400), "coin pocketed")
T.assert(ap.ex_to(T, 1, get, cache.pos, 0.4, 1200), "walked to the cache")
T.press(1, "use")
T.wait(1)
T.assert(#get().hands == 1 and get().hands[1].delicate, "recovered the cache by hand")
for _, c in ipairs(T.state().caches) do T.assert(not c.lifeline, "the cache is gone") end
local hold0 = #get().hold
-- face the open hall and deploy
local away = { 0, 0, 0 }
away[f.channel.axis] = -f.channel.sign
T.assert(ap.ex_look(T, 1, get, saucer.math.atan2(away[1], away[3]), 0, 300), "turned to the open hall")
T.press(1, "grow")
T.wait(1)
T.assert(get().excursion and get().excursion.coin == "grow", "the coin grows into the Seat")
T.assert(ap.wait_until(T, 1, function() return get().mode == "helm" end, 400), "aboard the Seat")
T.assert(#get().hold == hold0 + 1 and #get().hands == 0, "the hands emptied into the hold")

-- 9. through the door the hand-lock opened: beam up the strongroom's loot
local sf = f.strong_front
local up = get().ship.pos[2] + 6
T.assert(ap.fly(T, 1, get, { get().ship.pos[1], up, get().ship.pos[3] }, 0.6, 1500), "rose off the deck")
T.assert(ap.fly(T, 1, get, { sf[1], up, sf[3] }, 0.6, 3000), "crossed the hall")
T.assert(ap.fly(T, 1, get, sf, 0.4, 3000), "lined up with the strongroom door")
local cand
for _, c in ipairs(require("sim.tractor").candidates(T.state(), get(), 1, ruin)) do
  if c.kind == "slot" and ruin.slots[f.slot] and c.key == "1:" .. f.slot then cand = c end
end
T.assert(cand, "the strongroom's loot")
T.assert(ap.fly(T, 1, get, { f.slot_pos[1], sf[2], f.slot_pos[3] }, 0.4, 3000), "flew into the strongroom")
T.assert(ex.in_box(f.strong, get().ship.pos), "inside the strongroom")
local h1 = #get().hold
T.assert(ap.beam_up(T, 1, get, cand), "beamed it up with the Seat")
T.assert(#get().hold == h1 + 1, "the strongroom's loot is aboard")
print(string.format("excursion: lifelines %d hold %d suit %d charge %d", get().lifelines or 0, #get().hold,
  get().suit // 1, get().ship.charge // 1))
