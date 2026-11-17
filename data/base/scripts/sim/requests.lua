-- SPDX-License-Identifier: MIT
-- Trader requests and reputation (concept §7; OpenSpec add-wider-dark).
-- Every trader posts three requests ("any tier 2+ curio of the Velari",
-- "an optics module"). They are shared world state on state.traders[i]
-- (the first player to deliver claims one; a new one is posted at once).
-- Delivering pays twice the trader's offer and earns reputation with that
-- trader (per player, p.rep["<sector>:<trader>"]). Reputation raises your
-- sale prices there and unlocks Fold Core upgrades.
local items = require("sim.items")
local civs = require("sim.civs")
local M = {}

M.PER_TRADER = 3
M.CATS = { "curio", "module", "material", "tool" }
M.LEVELS = { [0] = "Stranger", "Known", "Trusted", "Partner" }
M.PAY = 2
M.MIN_PAY = 40
M.REP_BONUS = 0.05 -- per reputation level, on sale prices (up to 3 levels)

local function post(state, sid, ti, n)
  local rng = saucer.rng.new(saucer.seed_child(state.seed, "request", sid * 1000 + ti * 100 + n))
  local g = require("sim.galaxy").sector(state.seed, sid)
  local cat = M.CATS[rng:int(1, #M.CATS)]
  local civ = nil
  if rng:int(1, 100) <= 60 and g then civ = civs.get(state.seed, g.civs[rng:int(1, #g.civs)]).id end
  return { n = n, cat = cat, civ = civ, tier = rng:int(1, 2) }
end

-- make sure every trader of this sector has its requests posted
function M.ensure(state)
  local sid = state.sector_id or 1
  for ti, tr in ipairs(state.traders or {}) do
    tr.requests = tr.requests or {}
    tr.posted = tr.posted or 0
    while #tr.requests < M.PER_TRADER do
      tr.posted = tr.posted + 1
      tr.requests[#tr.requests + 1] = post(state, sid, ti, tr.posted)
    end
  end
end

function M.label(state, r)
  local c = r.civ and civs.by_id(state.seed, r.civ)
  return string.format("any tier %d+ %s%s", r.tier, r.cat, c and (" of the " .. c.name) or "")
end

function M.matches(r, it)
  if it.echo or it.unique or it.home then return false end
  if (it.category or "curio") ~= r.cat then return false end
  if r.civ and it.civ ~= r.civ then return false end
  return (it.tier or 1) >= r.tier
end

function M.rep_key(state, ti) return tostring(state.sector_id or 1) .. ":" .. ti end
function M.rep(state, p, ti) return (p.rep or {})[M.rep_key(state, ti)] or 0 end
function M.best_rep(p)
  local best = 0
  for _, v in pairs(p.rep or {}) do best = math.max(best, v) end
  return best
end
function M.level(n) return M.LEVELS[math.min(n, #M.LEVELS)] end

-- sale price factor from reputation at trader ti (and the Xenoarchive blueprint)
function M.price_factor(state, p, ti, it)
  local k = 1 + M.REP_BONUS * math.min(3, M.rep(state, p, ti))
  if it and it.civ and require("sim.archive").has_blueprint(p, it.civ) then k = k + require("sim.archive").BLUEPRINT_BONUS end
  return k
end

-- deliver(state, p, ti, ri, uid) -> ok, pay
function M.deliver(state, p, ti, ri, uid, ctx)
  local tr = state.traders[ti]
  local r = tr and tr.requests[ri]
  local it = items.find(p, uid)
  if not r or not it or not M.matches(r, it) then return false end
  local trade = require("sim.trade")
  local base = trade.offer(state, ti, it) or 0
  local pay = math.max(M.MIN_PAY, base * M.PAY)
  pay = math.floor(pay * require("sim.mystery").effect(state.mystery, "request_pay") + 0.5)
  items.remove(p, uid)
  p.credits = (p.credits or 0) + pay
  p.rep = p.rep or {}
  local key = M.rep_key(state, ti)
  p.rep[key] = (p.rep[key] or 0) + 1
  table.remove(tr.requests, ri)
  M.ensure(state)
  ctx.msg(state, p, string.format("Request filled: +%d c, reputation %s", pay, M.level(p.rep[key])))
  ctx.fx(state, p, "bank")
  return true, pay
end

-- trade terminal rows for requests (and Fold Core upgrades)
function M.rows(state, p, ti, ctx)
  local rows = { { text = string.format("Reputation here: %s (%d)", M.level(M.rep(state, p, ti)), M.rep(state, p, ti)),
                   enabled = false } }
  for ri, r in ipairs(state.traders[ti].requests or {}) do
    local found
    for _, it in ipairs(p.hold) do if M.matches(r, it) then found = it break end end
    local uid = found and found.uid
    rows[#rows + 1] = { text = "Request: " .. M.label(state, r) .. (found and (" - deliver " .. items.label(found)) or ""),
      enabled = found ~= nil, act = function(st, pl)
        M.deliver(st, pl, ti, ri, uid, ctx)
        require("sim.save").write(st)
      end }
  end
  -- add-wider-dark: restock decoy flares
  local dt = require("sim.sentry").tune().decoy
  local price = dt.price or 60
  rows[#rows + 1] = { text = string.format("Decoy flares x%d - %d c (you have %d)", dt.start, price, p.decoys or 0),
    enabled = (p.credits or 0) >= price and (p.decoys or 0) < dt.start * 3, act = function(st, pl)
      pl.credits = pl.credits - price
      pl.decoys = (pl.decoys or 0) + dt.start
      ctx.msg(st, pl, string.format("Bought %d decoy flares", dt.start))
      ctx.fx(st, pl, "bank")
    end }
  local galaxy = require("sim.galaxy")
  local tiers = galaxy.tune().core
  local nxt = tiers[(p.fold_tier or 1) + 1]
  if nxt then
    local ok = (p.credits or 0) >= nxt.price and M.rep(state, p, ti) >= nxt.rep
    rows[#rows + 1] = { text = string.format("Fold Core tier %d (%d hops) - %d c, needs %s", (p.fold_tier or 1) + 1,
      nxt.hops, nxt.price, M.level(nxt.rep)), enabled = ok, act = function(st, pl)
        pl.credits = pl.credits - nxt.price
        pl.fold_tier = (pl.fold_tier or 1) + 1
        ctx.msg(st, pl, string.format("Fold Core upgraded: tier %d", pl.fold_tier))
        ctx.fx(st, pl, "grow")
        require("sim.save").write(st)
      end }
  end
  return rows
end

return M
