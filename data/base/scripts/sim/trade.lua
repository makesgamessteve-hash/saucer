-- SPDX-License-Identifier: MIT
-- Trader prices and demand (concept §7, milestone 3). Demand lives per
-- trader and (category, civ) as { d, at } and recovers lazily: the value at
-- sim minute `now` is min(cap, d + recover x (now - at)). Pure functions over
-- state.traders; the sim decides when to call them.
local data = require("lib.data")
local vec = require("lib.vec")
local clock = require("sim.clock")
local items = require("sim.items")
local configs = require("sim.config")
local M = {}

local function econ() return data.load("economy/economy.lua") end
M.econ = econ

function M.new_traders(sector)
  local out = {}
  for i = 1, #(sector.traders or { sector.trader }) do out[i] = { demand = {} } end
  return out
end

function M.key(item) return (item.category or "curio") .. ":" .. (item.civ or "none") end

function M.demand(state, trader_idx, key)
  local e = econ().demand
  local tr = state.traders and state.traders[trader_idx]
  local entry = tr and tr.demand[key]
  if not entry then return e.start end
  local now = clock.minutes(state)
  return math.min(e.cap, entry.d + e.recover * (now - entry.at))
end

-- after a matching sale
function M.saturate(state, trader_idx, key)
  local e = econ().demand
  local now = clock.minutes(state)
  local cur = M.demand(state, trader_idx, key)
  state.traders[trader_idx].demand[key] = { d = math.max(e.floor, cur - e.drop), at = now }
end

function M.affix_sum(item)
  local s = 0
  for _, a in ipairs(item.affixes or {}) do s = s + a.value / 100 end
  return s
end

-- offer(state, trader, item[, p]) -> credits (integer), or nil when not for sale.
-- add-wider-dark: with p, reputation and Xenoarchive blueprints raise it; a
-- "restore" ending of the mystery raises the cause civ's relics for everyone
function M.offer(state, trader_idx, item, p)
  if not items.sellable(item) then return nil end
  local e = econ()
  local t = items.type_of(item.type)
  local base = t and t.value or item.value or 0
  local tier = e.tier_mult[item.tier or 1] or 1
  local aff = item.ident and M.affix_sum(item) or 0
  local rar = e.civ_rarity[item.civ or ""] or 1
  local ratio = item.ident and e.sell_ratio.identified or e.sell_ratio.unidentified
  local v = base * tier * (1 + aff) * rar * M.demand(state, trader_idx, M.key(item)) * ratio
  if p then v = v * require("sim.requests").price_factor(state, p, trader_idx, item) end
  local m = state.mystery
  if m and m.ending and item.civ and items.civ_name(item.civ) == m.vars.civ then
    v = v * require("sim.mystery").effect(m, "civ_price")
  end
  return math.floor(v + 0.5)
end

-- the trader this saucer is docked at (in range, outside any site), or nil
function M.docked_at(state, p)
  if p.site ~= 0 then return nil end
  local range = econ().dock_range
  local list = state.sector.traders or { state.sector.trader }
  for i, tr in ipairs(list) do
    if vec.dist(tr.pos, p.ship.pos) <= range then return i end
  end
  return nil
end

function M.sell(state, p, trader_idx, uid)
  local it = items.find(p, uid)
  if not it then return false, "gone" end
  local price = M.offer(state, trader_idx, it, p)
  if not price then return false, "not for sale" end
  items.remove(p, uid)
  p.credits = (p.credits or 0) + price
  p.sold = (p.sold or 0) + 1
  M.saturate(state, trader_idx, M.key(it))
  return true, price, it
end

-- add-trading-mvp 1.2 (gameplay gaps): the trader's modules. The shelf is a pure function of the world seed, the
-- sector, the trader and the hour of the clock (so it needs no stored list and saves nothing until something is
-- bought); state.traders[i].sold = { epoch = n, [slot] = true } remembers what has gone this restock.
-- -> list of { slot, item, price, sold }
function M.epoch(state) return clock.minutes(state) // econ().stock_minutes end

function M.stock(state, trader_idx)
  local e = econ()
  local epoch = M.epoch(state)
  local tr = state.traders and state.traders[trader_idx]
  local sold = tr and tr.sold and tr.sold.epoch == epoch and tr.sold or {}
  local tier = math.min(3, 1 + ((state.sector_id or 1) - 1) // 2)
  local base = saucer.seed_child(saucer.seed_child(state.seed or 0, "stock", (state.sector_id or 1) * 64 + trader_idx), "epoch", epoch)
  local out = {}
  for k = 1, e.stock_count do
    local item = require("sim.loot").roll(saucer.seed_child(base, "slot", k), 2, tier, "module")
    item.quirk = false -- the trader vouches for what it sells
    item.tier = tier
    local t = items.type_of(item.type)
    local price = math.floor((t and t.value or item.value) * (e.tier_mult[tier] or 1) * (1 + M.affix_sum(item)) * e.stock_markup + 0.5)
    out[k] = { slot = k, item = item, price = price, sold = sold[k] == true }
  end
  return out
end

-- buy_stock(state, p, trader_idx, slot) -> ok, why ("gone", "sold", "hold full", "credits"), item
function M.buy_stock(state, p, trader_idx, slot)
  local entry = M.stock(state, trader_idx)[slot]
  if not entry then return false, "gone" end
  if entry.sold then return false, "sold" end
  if #p.hold >= require("sim.upgrades").hold_slots(p) then return false, "hold full" end
  if (p.credits or 0) < entry.price then return false, "credits" end
  p.credits = p.credits - entry.price
  local tr = state.traders[trader_idx]
  if not tr.sold or tr.sold.epoch ~= M.epoch(state) then tr.sold = { epoch = M.epoch(state) } end
  tr.sold[slot] = true
  local it = items.stamp(p, entry.item, entry.item.tier, nil)
  it.ident, it.hot = true, false
  p.hold[#p.hold + 1] = it
  p.bought = (p.bought or 0) + 1
  return true, nil, it
end

-- add-playtest-recs (recommendation 11): story items warn before a sale.
-- -> the warning, or nil for ordinary loot
function M.story_warning(it)
  if require("sim.lab").is_core(it) then
    return "decode it at your lab bench first: it holds a holodeck program"
  end
  if it.home and it.home.kind == "module" then return "it upgrades your holodeck (holodeck panel)" end
  if it.home and it.home.kind == "program" then return "it is a holodeck program core" end
  return nil
end

-- the first pick on a story item only warns; a second pick sells it.
-- -> true when the sale may go ahead
function M.confirm_sale(state, p, it, ctx)
  local why = M.story_warning(it)
  if not why or p.sell_confirm == it.uid then
    p.sell_confirm = nil
    return true
  end
  p.sell_confirm = it.uid
  ctx.msg(state, p, string.format("Wait: %s - %s. Pick Sell again to sell it anyway.", items.label(it), why))
  ctx.fx(state, p, "denied")
  return false
end

-- sell row text: story items are marked, and spelled out once armed
function M.sell_text(p, it, price)
  if M.story_warning(it) then
    if p.sell_confirm == it.uid then return string.format("CONFIRM: sell %s - %d c", items.label(it), price) end
    return string.format("Sell %s - %d c (story item!)", items.label(it), price)
  end
  return string.format("Sell %s - %d c", items.label(it), price)
end

function M.refill_cost(p)
  return math.ceil((require("sim.ship").max_charge(p.ship) - p.ship.charge) * econ().charge_price)
end

function M.repair_cost(p)
  return math.ceil((100 - (p.ship.hull or 100)) * econ().repair_price)
end

-- buy as much as the credits allow; -> points bought
function M.refill(p)
  local max = require("sim.ship").max_charge(p.ship)
  local need = max - p.ship.charge
  local price = econ().charge_price
  local cost = math.ceil(need * price)
  if cost <= 0 then return 0 end
  if (p.credits or 0) >= cost then
    p.ship.charge = max
    p.credits = p.credits - cost
    return need
  end
  local n = math.floor((p.credits or 0) / price)
  if n <= 0 then return 0 end
  p.ship.charge = p.ship.charge + n
  p.credits = p.credits - n * price
  return n
end

function M.repair(p)
  local need = 100 - (p.ship.hull or 100)
  local afford = math.floor((p.credits or 0) / econ().repair_price)
  local n = math.floor(math.min(need, afford))
  if n <= 0 then return 0 end
  p.ship.hull = p.ship.hull + n
  p.credits = p.credits - n * econ().repair_price
  return n
end

-- add-holodeck-home-life: the home shop (home/shop.lua)
function M.shop()
  local list = data.load("home/shop.lua")
  -- add-home-among-stars: furniture and seed prices live in home/decor.lua
  for _, e in ipairs(list) do
    if e.price == nil then
      local d = e.kind == "furniture" and require("sim.decor").furniture(e.id) or require("sim.decor").seed(e.id)
      e.price = d and d.price or 0
    end
  end
  return list
end

local function shop_name(e)
  if e.kind == "ingredient" then return string.format("%d %s", e.n or 1, require("sim.kitchen").name(e.id)) end
  if e.kind == "program" then
    local pr = require("sim.holo").program(e.id)
    return "holo program " .. (pr and pr.name or e.id)
  end
  if e.kind == "module" then
    local m = data.load("home/holo_modules.lua")[e.id]
    return m and m.name or e.id
  end
  if e.kind == "furniture" then return require("sim.decor").furniture(e.id).name:lower() end
  if e.kind == "seed" then return string.format("%d %s seeds", e.n or 1, require("sim.decor").seed(e.id).name) end
  local b = require("sim.books").def(e.id)
  return b and b.title or e.id
end
M.shop_name = shop_name

-- can p buy shop entry e? -> ok, why
function M.can_buy(p, e)
  if e.kind == "program" and require("sim.holo").has(p, e.id) then return false, "owned" end
  if e.kind == "book" and require("sim.books").has(p, e.id) then return false, "owned" end
  if e.kind == "module" and #p.hold >= require("sim.upgrades").hold_slots(p) then return false, "hold full" end
  if (p.credits or 0) < e.price then return false, "credits" end
  return true
end

-- buy(p, e) -> ok, why: pays and delivers (ingredients to the pantry,
-- programs to the holodeck library, books to the shelf, modules to the hold)
function M.buy(p, e)
  local ok, why = M.can_buy(p, e)
  if not ok then return false, why end
  p.credits = p.credits - e.price
  if e.kind == "ingredient" then require("sim.kitchen").stock(p, e.id, e.n or 1)
  elseif e.kind == "program" then require("sim.holo").unlock(p, e.id)
  elseif e.kind == "book" then require("sim.books").add(p, e.id)
  elseif e.kind == "furniture" then require("sim.decor").buy_furniture(p, e.id)
  elseif e.kind == "seed" then require("sim.decor").buy_seeds(p, e.id, e.n)
  else
    local it = items.stamp(p, require("sim.finds").item({ kind = e.kind, id = e.id }), 1, nil)
    it.hot = false
    p.hold[#p.hold + 1] = it
  end
  p.bought = (p.bought or 0) + 1
  return true
end

-- trade terminal rows: sell each hold item (Echoes are not for sale), buy
-- Charge and hull repair. Every transaction saves the game at once.
function M.rows(state, p, ctx)
  local tr = M.docked_at(state, p)
  if not tr then
    return { { text = "No trader in range. Dock at a trader station first.", enabled = false },
             { text = "Close", act = function(_, pl) pl.panel = false end } }
  end
  local rows = { { text = string.format("Credits: %d c", p.credits or 0), enabled = false } }
  for _, it in ipairs(p.hold) do
    local uid = it.uid
    local price = M.offer(state, tr, it, p)
    if price then
      rows[#rows + 1] = { text = M.sell_text(p, it, price), hint = M.story_warning(it),
        act = function(st, pl)
          local cur = items.find(pl, uid)
          if cur and not M.confirm_sale(st, pl, cur, ctx) then return end
          local ok, got, sold = M.sell(st, pl, tr, uid)
          if ok then
            local saved = require("sim.save").write(st)
            ctx.msg(st, pl, string.format("Sold %s for %d c%s", items.label(sold), got, saved and " (saved)" or ""))
            ctx.fx(st, pl, "bank")
          end
        end }
    else
      rows[#rows + 1] = { text = items.label(it) .. " - Not for sale", enabled = false }
    end
  end
  -- add-wider-dark: the trader's requests, reputation and Fold Core upgrades
  for _, r in ipairs(require("sim.requests").rows(state, p, tr, ctx)) do rows[#rows + 1] = r end
  -- gameplay gaps: the trader's shelf of saucer modules (identified, no quirks), then your own upgrades
  for _, e in ipairs(M.stock(state, tr)) do
    local it, slot = e.item, e.slot
    local text = e.sold and string.format("%s - sold", it.name) or string.format("Buy module %s%s - %d c", it.name,
      require("sim.modules").effects(it), e.price)
    local why = e.sold and "sold" or (#p.hold >= require("sim.upgrades").hold_slots(p) and "hold full")
      or ((p.credits or 0) < e.price and "credits") or nil
    rows[#rows + 1] = { text = text, enabled = why == nil, hint = why and ("Cannot buy: " .. why) or "Install it at the lab bench",
      act = function(st, pl)
        local ok, _, bought = M.buy_stock(st, pl, tr, slot)
        if ok then
          local saved = require("sim.save").write(st)
          ctx.msg(st, pl, string.format("Bought %s%s: install it at the lab bench", bought.name, saved and " (saved)" or ""))
          ctx.fx(st, pl, "bank")
        end
      end }
  end
  -- add-playtest-recs: saucer upgrades (beam relay, coils, racks, cells, a second bench)
  for _, r in ipairs(require("sim.upgrades").rows(state, p, ctx)) do rows[#rows + 1] = r end
  for _, e in ipairs(M.shop()) do
    local ok, why = M.can_buy(p, e)
    local entry = e
    rows[#rows + 1] = { text = string.format("Buy %s - %d c%s", shop_name(e), e.price, why == "owned" and " (owned)" or ""),
      enabled = ok, act = function(st, pl)
        if M.buy(pl, entry) then
          local saved = require("sim.save").write(st)
          ctx.msg(st, pl, string.format("Bought %s%s", shop_name(entry), saved and " (saved)" or ""))
          ctx.fx(st, pl, "bank")
        end
      end }
  end
  local rc, hc = M.refill_cost(p), M.repair_cost(p)
  rows[#rows + 1] = { text = string.format("Refill Charge - %d c", rc), enabled = rc > 0 and (p.credits or 0) > 0,
    act = function(st, pl)
      local n = M.refill(pl)
      ctx.msg(st, pl, string.format("Bought %d Charge", math.floor(n + 0.5)))
      require("sim.save").write(st)
    end }
  rows[#rows + 1] = { text = string.format("Repair hull - %d c", hc), enabled = hc > 0 and (p.credits or 0) > 0,
    act = function(st, pl)
      local n = M.repair(pl)
      ctx.msg(st, pl, string.format("Repaired %d hull", n))
      require("sim.save").write(st)
    end }
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

return M
