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
  ship.since_hit = 0
  if ship.shield >= a then
    ship.shield = ship.shield - a
    return
  end
  local rest = (a - ship.shield) * (c.shield or 1) / math.max(c.hull or 1, 0.05)
  ship.shield = 0
  ship.hull = math.max(0, ship.hull - rest)
end

function M.regen(ship, dt)
  M.ensure(ship)
  local t = tune()
  ship.since_hit = ship.since_hit + dt
  if ship.since_hit >= t.shield_delay and not ship.morph then
    ship.shield = math.min(100, ship.shield + t.shield_regen * dt)
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
  return cache
end

return M
