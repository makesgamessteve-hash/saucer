-- SPDX-License-Identifier: MIT
-- Shields, hull and Fold Retreat (concept §8.1). Nothing is lethal: at hull 0
-- the saucer folds back to the last trader it visited, the hot items stay
-- behind as a recoverable cache, and banked cargo, Echoes and credits are
-- never lost. The dome and the person in it are never affected.
local data = require("lib.data")
local configs = require("sim.config")
local items = require("sim.items")
local M = {}

M.RETREAT_HULL = 30

local function tune() return data.load("sentries/sentries.lua") end

function M.ensure(ship)
  ship.hull = ship.hull or 100
  ship.shield = ship.shield or 100
  ship.since_hit = ship.since_hit or 99
end

-- damage(ship, amount): shields first, then hull; smaller hulls are frailer
function M.damage(ship, amount)
  M.ensure(ship)
  local c = configs.get(ship.size)
  local a = amount / math.max(c.shield or 1, 0.05)
  -- add-playtest-recs: Shield cells (an upgrade) make every shield point soak more
  if (ship.cells or 0) > 0 then
    local u = require("sim.upgrades").def("shield_cells")
    a = a / (1 + ship.cells * (u and u.soak or 0.25))
  end
  ship.since_hit = 0
  if ship.shield >= a then
    ship.shield = ship.shield - a
    return
  end
  local rest = (a - ship.shield) * (c.shield or 1) / math.max(c.hull or 1, 0.05)
  ship.shield = 0
  ship.hull = math.max(0, ship.hull - rest)
end

-- regen(ship, dt, open_space): shields recharge after shield_delay without
-- hits; in open space (outside every site) the hull also mends slowly, at
-- hull_regen per second (playtest-1: before this the hull never mended, so
-- the Steady buff, which scales dt, did nothing for it)
function M.regen(ship, dt, open_space)
  M.ensure(ship)
  local t = tune()
  ship.since_hit = ship.since_hit + dt
  if ship.since_hit >= t.shield_delay and not ship.morph then
    ship.shield = math.min(100, ship.shield + t.shield_regen * require("sim.ship").mult(ship, "shield_regen") * dt)
    if open_space and ship.hull > 0 then
      ship.hull = math.min(100, ship.hull + (t.hull_regen or 0) * dt)
    end
  end
end

-- Fold Retreat: drop the hot items as a cache where the hull failed and fold
-- to the trader. -> the cache (or nil when nothing was hot)
function M.retreat(state, p, trader_pos)
  local ship = p.ship
  local hc = require("sim.hardcore")
  local lost = hc.retreat_losses(state, p)
  local cache
  if #lost > 0 and hc.on(state) then
    -- add-home-among-stars: Hardcore keeps no cache; the cargo is gone
    for _, it in ipairs(lost) do items.remove(p, it.uid) end
    p.lost_for_good = (p.lost_for_good or 0) + #lost
  elseif #lost > 0 then
    cache = { site = p.site, pos = { ship.pos[1], ship.pos[2], ship.pos[3] }, owner = p.record_index, items = {} }
    for _, it in ipairs(lost) do
      items.remove(p, it.uid)
      cache.items[#cache.items + 1] = it
    end
    state.caches = state.caches or {}
    state.caches[#state.caches + 1] = cache
  end
  local off = (p.index - 1) * 40
  ship.pos = { trader_pos[1] + 60 + off, trader_pos[2], trader_pos[3] + 60 }
  ship.vel = { 0, 0, 0 }
  if ship.size ~= 1 then
    ship.size = 1
    ship.morph = false
    ship.t_left = 0
  end
  ship.hull = M.RETREAT_HULL
  ship.shield = 0
  ship.since_hit = 0
  p.tractor = false
  p.latched_by = nil
  p.retreats = (p.retreats or 0) + 1
  M.bill(state, p)
  return cache
end

-- add-playtest-recs (recommendation 7): at danger 2+ a Fold Retreat costs a
-- tow bill. Credits first; the rest comes out of the Charge (never below 0,
-- never anything else). -> credits paid, Charge taken
function M.bill(state, p)
  local g = require("sim.galaxy").sector(state.seed, state.sector_id or 1)
  local bill = (tune().retreat_bill or {})[g and g.danger or 1] or 0
  p.last_bill = nil
  if bill <= 0 then return 0, 0 end
  local paid = math.min(p.credits or 0, bill)
  p.credits = (p.credits or 0) - paid
  local chg = math.min(p.ship.charge, bill - paid)
  p.ship.charge = p.ship.charge - chg
  p.bills = (p.bills or 0) + paid
  p.last_bill = { bill = bill, paid = paid, charge = chg }
  return paid, chg
end

return M
