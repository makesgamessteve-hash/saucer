-- SPDX-License-Identifier: MIT
-- The Xenoarchive (concept §6.2, §9; OpenSpec add-wider-dark): a per-player
-- catalog of every civ you have met. A civ's catalog is the item types of
-- its domains; identifying an item of that civ at the lab bench files its
-- type. At 25 / 50 / 100% you get a lore page on the shelf, a blueprint
-- (+15% when you sell that civ's relics) and the civ's signature piece.
-- The Witness Echo of the mystery only translates once a present player's
-- archive holds 25% of its civ. Plain data in p.archive and p.met (saved).
local data = require("lib.data")
local civs = require("sim.civs")
local M = {}

M.STEPS = { 25, 50, 100 }
M.BLUEPRINT_BONUS = 0.15

-- catalog(civ) -> sorted list of item type ids
function M.catalog(civ)
  local out = {}
  if not civ then return out end
  for _, t in ipairs(data.load("items/types.lua")) do
    for _, d in ipairs(civ.domains or {}) do
      if t.domain == d then
        out[#out + 1] = t.id
        break
      end
    end
  end
  return out
end

function M.ensure(p)
  p.archive = p.archive or {}
  p.met = p.met or {}
  p.archive_rewards = p.archive_rewards or {}
  return p.archive
end

function M.meet(p, civ)
  M.ensure(p)
  if not civ or p.met[civ.id] then return false end
  p.met[civ.id] = true
  return true
end

function M.percent(state, p, civ_id)
  local civ = civs.by_id(state.seed, civ_id)
  local cat = M.catalog(civ)
  if #cat == 0 then return 0 end
  local have = (p.archive or {})[civ_id] or {}
  local n = 0
  for _, t in ipairs(cat) do if have[t] then n = n + 1 end end
  return math.floor(n * 100 / #cat)
end

-- the best archive among the players present (the translation gate)
function M.best(state, civ_id)
  local best = 0
  for _, p in ipairs(state.players) do best = math.max(best, M.percent(state, p, civ_id)) end
  return best
end

function M.has_blueprint(p, civ_id)
  local r = p.archive_rewards and p.archive_rewards[civ_id]
  return r ~= nil and r["50"] == true
end

local function reward(state, p, civ, step, ctx)
  local r = p.archive_rewards[civ.id] or {}
  p.archive_rewards[civ.id] = r
  local k = tostring(step)
  if r[k] then return false end
  r[k] = true
  if step == 25 then
    require("sim.books").add(p, "lore:" .. civ.id)
    ctx.msg(state, p, "Xenoarchive 25%: a " .. civ.name .. " lore page is on your shelf")
  elseif step == 50 then
    ctx.msg(state, p, string.format("Xenoarchive 50%%: %s blueprint, their relics sell for %d%% more", civ.name,
      math.floor(M.BLUEPRINT_BONUS * 100 + 0.5)))
  else
    local items = require("sim.items")
    local it = items.stamp(p, { type = "signature", name = civ.name .. " signature piece", size = 1, value = 260,
      rarity = "relic", category = "curio", ident = true, unique = true }, 3, civ.id)
    it.hot = false
    p.hold[#p.hold + 1] = it
    ctx.msg(state, p, "Xenoarchive 100%: the " .. civ.name .. " signature piece is in your hold")
  end
  ctx.fx(state, p, "echo")
  return true
end

-- record(state, p, item, ctx) -> true when a new entry was filed
function M.record(state, p, item, ctx)
  M.ensure(p)
  if not item or not item.civ or not item.type then return false end
  local civ = civs.by_id(state.seed, item.civ)
  if not civ then return false end
  p.met[civ.id] = true
  local inside = false
  for _, t in ipairs(M.catalog(civ)) do if t == item.type then inside = true end end
  if not inside then return false end
  local have = p.archive[civ.id] or {}
  p.archive[civ.id] = have
  if have[item.type] then return false end
  have[item.type] = true
  local pct = M.percent(state, p, civ.id)
  ctx.msg(state, p, string.format("Xenoarchive: %s filed under %s (%d%%)", item.type, civ.name, pct))
  for _, step in ipairs(M.STEPS) do
    if pct >= step then reward(state, p, civ, step, ctx) end
  end
  return true
end

-- panel rows: one line per civ met (percent and traits), then Close
function M.rows(state, p)
  M.ensure(p)
  local rows = {}
  for _, civ in ipairs(civs.universe(state.seed)) do
    if p.met[civ.id] then
      local pct = M.percent(state, p, civ.id)
      local cat = M.catalog(civ)
      local have = p.archive[civ.id] or {}
      local got = {}
      for _, t in ipairs(cat) do got[#got + 1] = have[t] and t or "?" end
      rows[#rows + 1] = { text = string.format("%-8s %3d%%  %s", civ.name, pct, table.concat(got, " ")), enabled = false }
      rows[#rows + 1] = { text = "  " .. civ.body .. " " .. civ.shape .. ", " .. civ.temperament .. ", " .. civ.fate,
        enabled = false }
    end
  end
  if #rows == 0 then rows[1] = { text = "No civilizations met yet", enabled = false } end
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

return M
