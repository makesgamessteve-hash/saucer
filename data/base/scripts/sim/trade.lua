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

-- offer(state, trader, item) -> credits (integer), or nil when not for sale
function M.offer(state, trader_idx, item)
  if not items.sellable(item) then return nil end
  local e = econ()
  local t = items.type_of(item.type)
  local base = t and t.value or item.value or 0
  local tier = e.tier_mult[item.tier or 1] or 1
  local aff = item.ident and M.affix_sum(item) or 0
  local rar = e.civ_rarity[item.civ or ""] or 1
  local ratio = item.ident and e.sell_ratio.identified or e.sell_ratio.unidentified
  local v = base * tier * (1 + aff) * rar * M.demand(state, trader_idx, M.key(item)) * ratio
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
  local price = M.offer(state, trader_idx, it)
  if not price then return false, "not for sale" end
  items.remove(p, uid)
  p.credits = (p.credits or 0) + price
  p.sold = (p.sold or 0) + 1
  M.saturate(state, trader_idx, M.key(it))
  return true, price, it
end

function M.refill_cost(p)
  return math.ceil((configs.all().max_charge - p.ship.charge) * econ().charge_price)
end

function M.repair_cost(p)
  return math.ceil((100 - (p.ship.hull or 100)) * econ().repair_price)
end

-- buy as much as the credits allow; -> points bought
function M.refill(p)
  local max = configs.all().max_charge
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
    local price = M.offer(state, tr, it)
    if price then
      rows[#rows + 1] = { text = string.format("Sell %s - %d c", items.label(it), price),
        act = function(st, pl)
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
