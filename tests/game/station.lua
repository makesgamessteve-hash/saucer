-- SPDX-License-Identifier: MIT
-- Milestone 5: pocket saucer and station visits. Loot the tutorial vault,
-- fly to the trader station and dock, fold the Villa down to the Pocket size
-- (you step out into the arrival hangar with the coin in your hand, then
-- pocket it), walk the concourse to the market and sell loot face to face at
-- a stall, top up the Charge at the chandler, have a drink at the bar, get
-- your pocket picked and run the thief down, then walk to the far hangar,
-- unfold the Villa on its pad and fly away from the station.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local items = require("sim.items")
local trade = require("sim.trade")
local visit = require("sim.visit")
local sg = require("sim.stationgen")
local configs = require("sim.config")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()

-- the Pocket size is refused away from a station
T.press(1, "size3")
T.wait(1)
T.assert(get().ship.size == 1 and said("only works docked"), "no pocketing in open space")

-- 1. loot the tutorial vault (something to sell on foot)
local origin, ruin = st.sector.sites[1].pos, game.ruin(1)
local vault
for _, r in ipairs(ruin.rooms) do if r.kind == "vault" then vault = r end end
local ok, route = ap.enter(T, 1, get, ruin, origin, vault.id)
T.assert(ok, "flew into the vault")
local door = ap.door_center(ap.door_of(ruin, vault.id), ruin.rooms, require("sim.ruin").kit_of(ruin.kit), origin)
local got = ap.grab(T, 1, get, 1, ruin, vault.id, door)
T.assert(got >= 2, "looted the vault (" .. got .. ")")
T.assert(ap.leave(T, 1, get, route), "flew back out")
local sellable = 0
for _, it in ipairs(get().hold) do if items.sellable(it) then sellable = sellable + 1 end end
T.assert(sellable >= 1, "loot to sell")

-- 2. fly to the trader station and dock
local tp = st.sector.trader.pos
T.assert(ap.travel(T, 1, get, { tp[1] + 50, tp[2], tp[3] + 50 }, 6, 6000), "flew to the trader")
T.assert(get().docked == 1, "docked")
local dock_pos = { get().ship.pos[1], get().ship.pos[2], get().ship.pos[3] }

-- 3. pocket the saucer: step out into the arrival hangar, coin in hand
local charge0 = get().ship.charge
T.press(1, "size3")
T.wait(1)
local p = get()
T.assert(p.mode == "foot" and p.station and p.station.coin == "fold", "stepped out; the saucer is folding")
T.assert(p.ship.size == visit.pocket_size() and configs.get(p.ship.size).pocket, "the Pocket configuration")
T.assert(p.ship.charge < charge0, "pocketing costs Charge")
local L = visit.layout(T.state(), p)
T.assert(visit.area(T.state(), p).name == "Arrival hangar", "standing in the arrival hangar")
T.assert(ap.wait_until(T, 1, function() return get().station.coin == "hand" end, 400), "the coin rests in your hand")
T.assert(ap.wait_until(T, 1, function() return get().station.coin == "pocket" end, 200), "and goes into your pocket")
-- no unfolding outside a hangar
T.assert(ap.foot_to(T, 1, get, 0, 6), "walked onto the concourse")
T.assert(visit.area(T.state(), get()).kind == "corridor", "on the concourse")
T.press(1, "size1")
T.wait(1)
T.assert(get().mode == "foot" and said("find a hangar"), "no room to unfold on the concourse")

-- 4. sell loot at a market stall, face to face
local scrap, chandler
for _, s in ipairs(L.stalls) do
  if s.vendor == "scrap" then scrap = s end
  if s.vendor == "chandler" then chandler = s end
end
T.assert(scrap and chandler, "the market has a scrap dealer and a chandler")
T.assert(ap.foot_use(T, 1, get, scrap.spot), "walked to the scrap dealer and spoke up")
T.assert(get().panel.kind == "vendor", "the stall's trade panel")
T.assert(visit.area(T.state(), get()).kind == "market", "in the market")
local c0 = get().credits or 0
local sold = 0
for _ = 1, 6 do
  local any = false
  for _, it in ipairs(get().hold) do
    if not any and visit.vendor_offer(T.state(), get(), visit.vendor_def("scrap"), it) then
      any = ap.pick(T, 1, get, "Sell " .. items.label(it))
      -- add-playtest-recs: a story item (a data core) warns first; sell it anyway
      if any and get().sell_confirm then
        T.assert(get().msgs[#get().msgs].text:find("Wait:", 1, true), "the stall warns before a story item goes")
        any = ap.pick(T, 1, get, "CONFIRM: sell")
      end
      if any then sold = sold + 1 end
    end
  end
  if not any then break end
end
T.assert(sold >= 1 and (get().credits or 0) > c0, "sold " .. sold .. " item(s) on foot for " .. ((get().credits or 0) - c0) .. " c")
T.assert(get().sold_on_foot == sold, "counted as on-foot sales")
T.assert(ap.pick(T, 1, get, "Close"), "closed the stall")
-- the chandler tops the coin's Charge up
T.assert(ap.foot_use(T, 1, get, chandler.spot), "at the chandler")
T.assert(ap.pick(T, 1, get, "Top up"), "asked for Charge")
T.assert(get().ship.charge >= configs.all().max_charge - 1, "the coin's Charge is full")
T.assert(ap.pick(T, 1, get, "Close"), "closed the chandler")

-- 5. a drink at the bar
T.assert(ap.foot_use(T, 1, get, L.bar.spot), "walked to the bar")
T.assert(get().panel.kind == "bar" and visit.area(T.state(), get()).kind == "bar", "the bartender's panel")
T.assert(ap.pick(T, 1, get, "Nebula tea"), "ordered a nebula tea")
T.assert(require("sim.buffs").active(T.state(), get(), "calm"), "calm from the tea")
T.assert(ap.pick(T, 1, get, "Ask about rumours"), "asked about rumours")
T.assert(ap.pick(T, 1, get, "Close"), "closed the bar")

-- 6. the pickpocket: walk over to his haunt holding the coin in your fist (safe
-- from him), turn your back on him, pocket the coin and stand still
local home = visit.layout(T.state(), get()).thief.home
T.press(1, "tractor")
T.wait(1)
T.assert(get().station.coin == "hand" and get().station.held, "the coin is held in the fist")
T.assert(ap.foot_to(T, 1, get, home[1], home[2], 1.5, 4000), "near the hooded figure's haunt")
T.assert(get().station.coin == "hand", "nobody takes a held coin")
local A = require("sim.avatar").layout()
T.axis(1, "turn", 1, (saucer.math.pi / A.turn * 60) // 1)
T.axis(1, "turn", 0, 1)
T.press(1, "tractor")
T.wait(1)
T.assert(get().station.coin == "pocket", "back in the pocket")
T.assert(ap.wait_until(T, 1, function() return get().station.coin == "thief" end, 60 * 90),
  "the pickpocket lifted the saucer (" .. get().station.thief.mode .. ")")
T.assert(get().station.thief.mode == "flee" and said("pocket is light"), "and runs for it")
T.press(1, "size1")
T.wait(1)
T.assert(get().mode == "foot", "no saucer, no unfolding")
T.assert(ap.chase(T, 1, get), "ran him down")
T.assert(said("catch the thief") and get().station.caught == get().station.stolen, "caught him; the saucer is back")
T.assert(get().station.coin == "hand" or get().station.coin == "pocket", "the coin is yours again")

-- save mid-visit and load it back: the visit survives
require("sim.save").write(T.state())
local rec = require("sim.save").read()
local saved = rec and require("sim.save").player(rec, 1)
T.assert(saved and saved.mode == "foot" and saved.station.coin, "the save holds the visit")

-- 7. the far hangar: unfold the Villa on the pad and fly away
local far = sg.hangars(L)[2]
T.assert(far, "a second hangar")
T.assert(ap.foot_to(T, 1, get, far.pad[1], far.pad[2] + 3, 0.6, 4000), "walked to the far hangar")
T.assert(visit.area(T.state(), get()) == far, "standing in the far hangar")
T.press(1, "size1")
T.wait(1)
T.assert(get().station.coin == "grow" and get().ship.size == 1, "the coin is unfolding into the Villa")
T.assert(ap.wait_until(T, 1, function() return get().mode == "helm" end, 400), "aboard at the helm")
T.assert(not get().station and said("far hangar"), "left through the far hangar")
local bay = get().ship.pos
T.assert(require("lib.vec").dist(bay, dock_pos) > 60, "at the far side of the station")
T.assert(get().docked == 1, "still docked at the bay")
local away = require("lib.vec").add(bay, require("lib.vec").scale(require("lib.vec").fwd(get().ship.yaw), 200))
T.assert(ap.fly(T, 1, get, away, 6, 3000), "flew away")
T.assert(not get().docked, "left the station behind")
print(string.format("station: %s sold %d credits %d caught %d charge %d", L.hash, sold, get().credits or 0,
  get().sold_on_foot and 1 or 0, get().ship.charge // 1))
