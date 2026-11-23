-- SPDX-License-Identifier: MIT
-- Milestone 3: identify and trade. Loot the tutorial derelict's vault, leave
-- (the loot banks), queue an item and the Echo at the lab bench, fly to the
-- trader while the bench works, dock, and sell identified and unidentified
-- items at the trade terminal: prices follow the formula and demand drops
-- with every matching sale. Then sleep to save, spend, and load it back.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local items = require("sim.items")
local trade = require("sim.trade")
local lab = require("sim.lab")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()
local origin = st.sector.sites[1].pos
local ruin = game.ruin(1)
local vault
for _, r in ipairs(ruin.rooms) do if r.kind == "vault" then vault = r end end

-- loot the vault with the Villa (add-fun-fixes: the tutorial derelict keeps one light Watcher)
local ok, route = ap.enter(T, 1, get, ruin, origin, vault.id)
T.assert(ok, "flew the Villa into the vault")
-- add-strategic-sentries: and a light Spotter
T.assert(#game.sentries(1) == 2 and game.sentries(1)[1].light and game.sentries(1)[2].kind == "spotter",
  "the tutorial derelict has one light Watcher and a light Spotter")
local door = ap.door_center(ap.door_of(ruin, vault.id), ruin.rooms, require("sim.ruin").kit_of(ruin.kit), origin)
local got = ap.grab(T, 1, get, 1, ruin, vault.id, door)
T.assert(got >= 2, "picked up the vault's loot and the Echo (" .. got .. ")")
local loot, echo = {}, nil
for _, it in ipairs(get().hold) do
  if it.echo then echo = it elseif not it.home then loot[#loot + 1] = it end
end
T.assert(echo ~= nil and echo.echo == 1, "Echo I is in the hold")
T.assert(#loot >= 1, "and some loot")
for _, it in ipairs(loot) do
  T.assert(not it.ident and items.label(it):find("Unknown", 1, true), "loot comes in unidentified: " .. items.label(it))
  T.assert(it.hot, "fresh loot is hot")
end
T.assert(ap.leave(T, 1, get, route), "flew back out")
T.assert(get().site == 0, "outside the site")
for _, it in ipairs(loot) do T.assert(not it.hot, "leaving banked the loot") end

-- the lab bench: queue the first item and the Echo
T.assert(ap.walk_to_station(T, 1, get, "lab"), "walked to the lab bench")
T.press(1, "use")
T.wait(1)
T.assert(get().panel and get().panel.kind == "lab", "lab panel")
local target = loot[1]
local charge0 = get().ship.charge
T.assert(ap.pick(T, 1, get, "Identify " .. items.label(target)), "queued an item")
T.assert(get().ship.charge < charge0, "identification costs Charge")
T.assert(ap.pick(T, 1, get, "Decode Echo I"), "queued the Echo")
T.assert(#get().lab.queue == 2, "two jobs queued")
T.assert(ap.pick(T, 1, get, "Close"), "closed the panel")

-- fly to the trader while the bench works
T.assert(ap.take_helm(T, 1, get), "back at the helm")
local tp = st.sector.trader.pos
local start = T.state().tick
T.assert(ap.travel(T, 1, get, { tp[1] + 50, tp[2], tp[3] + 50 }, 6, 6000), "flew to the trader")
T.assert(get().docked == 1, "docked")
T.assert(said("Docked at the trader"), "dock message")
T.assert(ap.wait_until(T, 1, function() return target.ident end, 60 * 75), "the bench identified the item")
local took = T.state().tick - start
T.assert(target.ident and items.label(target) == target.name, "identified: " .. target.name)
T.assert(ap.wait_until(T, 1, function() return T.state().mystery.echoes[1].decoded end, 60 * 30), "decoded Echo I")
T.assert(#require("sim.mystery").resonant_sites(T.state().mystery) == 1, "the next site is Resonant")

-- trade terminal: offers follow the formula; Echoes are not for sale
T.assert(ap.walk_to_station(T, 1, get, "trade"), "walked to the trade terminal")
T.press(1, "use")
T.wait(1)
T.assert(get().panel and get().panel.kind == "trade", "trade panel open")
T.assert(require("sim.panel").find(T.state(), get(), echo.name .. " - Not for sale") ~= nil, "the Echo is not for sale")
local offer = trade.offer(T.state(), 1, target)
local e = trade.econ()
local t0 = items.type_of(target.type)
local expect = math.floor(t0.value * e.tier_mult[target.tier] * (1 + trade.affix_sum(target)) *
  (e.civ_rarity[target.civ] or 1) * 1.0 * e.sell_ratio.identified + 0.5)
T.assert(offer == expect, string.format("identified offer %d matches the formula %d", offer, expect))
local credits0 = get().credits
T.assert(ap.pick(T, 1, get, "Sell " .. items.label(target)), "sold the identified item")
T.assert(get().credits == credits0 + offer, "credits went up by the offer")
T.assert(not items.find(get(), target.uid), "the item left the hold")
T.assert(said("(saved)"), "the sale saved the game")
local key = trade.key(target)
local d = trade.demand(T.state(), 1, key)
T.assert(math.abs(d - 0.95) < 0.002, "demand dropped by 0.05 (" .. d .. ")")
-- an unidentified item sells at 40 % with no affix premium
local other = loot[2]
if other then
  local o2 = trade.offer(T.state(), 1, other)
  local t2 = items.type_of(other.type)
  local dem = trade.demand(T.state(), 1, trade.key(other))
  local exp2 = math.floor(t2.value * e.tier_mult[other.tier] * (e.civ_rarity[other.civ] or 1) * dem *
    e.sell_ratio.unidentified + 0.5)
  T.assert(o2 == exp2, string.format("unidentified offer %d = %d", o2, exp2))
  T.assert(ap.pick(T, 1, get, "Sell " .. items.label(other)), "sold an unidentified item")
end
-- buy Charge back
T.assert(ap.pick(T, 1, get, "Refill Charge"), "refilled Charge")
T.assert(ap.pick(T, 1, get, "Close"), "closed the terminal")
local credits1 = get().credits

-- demand recovers over sim time (and sleeping skips 8 hours)
local before = trade.demand(T.state(), 1, key)
T.assert(ap.walk_to(T, 1, get, "bed"), "walked to the bed")
T.press(1, "use")
T.wait(1)
T.assert(ap.pick(T, 1, get, "Sleep"), "slept (and saved)")
T.assert(said("Game saved"), "saved")
local after = trade.demand(T.state(), 1, key)
T.assert(after > before + 0.4 and after <= 1.5, "demand recovered while sleeping (" .. after .. ")")
local saved_tick = T.state().tick
-- change things (queue the rest of the hold at the lab), then load the save back at the bed
local queued = 0
for _, it in ipairs(get().hold) do if not it.ident and not it.echo and not it.home then queued = queued + 1 end end
T.assert(ap.walk_to(T, 1, get, "lab"), "back to the lab")
T.press(1, "use")
T.wait(1)
for _ = 1, queued do ap.pick(T, 1, get, "Identify") end
ap.pick(T, 1, get, "Close")
T.assert(#get().lab.queue == queued, "queued the rest")
T.assert(ap.walk_to(T, 1, get, "bed"), "and to the bed")
T.press(1, "use")
T.wait(1)
T.assert(ap.pick(T, 1, get, "Load"), "loaded")
T.assert(T.state().tick == saved_tick, "back at the save")
T.assert(get().credits == credits1, "credits restored")
T.assert(#get().lab.queue == 0, "the lab queue is as it was at the save")
T.assert(math.abs(trade.demand(T.state(), 1, key) - after) < 1e-9, "trader demand restored")
T.assert(T.state().mystery.echoes[1].decoded, "mystery progress restored")
T.assert(items.find(get(), echo.uid) ~= nil, "the Echo is still in the hold")
print(string.format("trade: identify took %d ticks, sold for %d c, credits %d, loot %d", took, offer, get().credits,
  #loot))
