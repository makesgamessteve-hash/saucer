-- SPDX-License-Identifier: MIT
-- Saucer upgrades (OpenSpec add-playtest-recs, playtest recommendations 1, 2
-- and 5). Bought at a trade terminal or a station chandler; levels live in
-- p.upgrades[id] (plain data: saved, snapshotted, replayed). Effects:
--   beam_relay    the helm pulls small finds itself (no walk to the Tractor Room)
--   tractor_coils the beam pulls faster
--   hold_racks    more hold slots
--   shield_cells  the shields soak more per point (ship.cells)
--   lab_bench     a second lab job runs at the same time
local data = require("lib.data")
local configs = require("sim.config")
local M = {}

M.RELAY_SIZE = 2 -- the relay lifts size S and M finds

function M.list() return data.load("economy/upgrades.lua") end

function M.def(id)
  for _, u in ipairs(M.list()) do if u.id == id then return u end end
  return nil
end

function M.level(p, id) return (p.upgrades or {})[id] or 0 end

-- price of the next level, or nil at the top
function M.next_price(p, u)
  return u.price[M.level(p, u.id) + 1]
end

-- can p buy the next level of u? -> ok, why ("max", "tier", "credits")
function M.can_buy(p, u)
  local price = M.next_price(p, u)
  if not price then return false, "max" end
  if (p.fold_tier or 1) < (u.needs_tier or 1) then return false, "tier" end
  if (p.credits or 0) < price then return false, "credits" end
  return true, nil, price
end

function M.buy(p, id)
  local u = M.def(id)
  if not u then return false, "unknown" end
  local ok, why, price = M.can_buy(p, u)
  if not ok then return false, why end
  p.credits = p.credits - price
  p.upgrades = p.upgrades or {}
  p.upgrades[id] = M.level(p, id) + 1
  if id == "shield_cells" then p.ship.cells = p.upgrades[id] end
  p.bought = (p.bought or 0) + 1
  p.upgrade_spent = (p.upgrade_spent or 0) + price
  return true, nil, price
end

-- effects -------------------------------------------------------------------
function M.hold_slots(p)
  local base = configs.all().hold_slots
  if not p then return base end
  local u = M.def("hold_racks")
  return base + M.level(p, "hold_racks") * (u and u.slots or 4)
end

function M.pull_factor(p)
  local u = M.def("tractor_coils")
  return 1 / (1 + M.level(p, "tractor_coils") * (u and u.pull or 0.4))
end

function M.lab_slots(p) return 1 + M.level(p, "lab_bench") end

-- may the helm pull this item itself (Villa beam, relay fitted, small item)?
function M.relay(p, item)
  return M.level(p, "beam_relay") > 0 and item ~= nil and (item.size or 1) <= M.RELAY_SIZE
end

-- trade terminal / chandler rows ---------------------------------------------
function M.rows(state, p, ctx)
  local rows = {}
  for _, u in ipairs(M.list()) do
    local lvl, max = M.level(p, u.id), #u.price
    local ok, why, price = M.can_buy(p, u)
    local tag = max > 1 and string.format(" %d/%d", lvl, max) or ""
    local text
    if why == "max" then text = string.format("Upgrade %s%s - fitted", u.name, tag)
    elseif why == "tier" then text = string.format("Upgrade %s - %d c, needs Fold Core T%d", u.name, M.next_price(p, u), u.needs_tier)
    else text = string.format("Upgrade %s%s - %d c", u.name, tag, price or M.next_price(p, u)) end
    local id = u.id
    rows[#rows + 1] = { text = text, enabled = ok, hint = u.desc, act = function(st, pl)
      local done, _, paid = M.buy(pl, id)
      if done then
        local saved = require("sim.save").write(st)
        ctx.msg(st, pl, string.format("Fitted %s (level %d) for %d c%s", u.name, M.level(pl, id), paid,
          saved and " (saved)" or ""))
        ctx.fx(st, pl, "grow")
      end
    end }
  end
  return rows
end

return M
