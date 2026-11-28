-- SPDX-License-Identifier: MIT
-- Cooking (OpenSpec add-holodeck-home-life). The pantry (p.pantry, id ->
-- count, saved) fills with trader groceries and alien ingredients found in
-- derelicts; a recipe uses some and gives small buffs. Cooking takes a few
-- seconds at the stove (p.cooking, transient) and cannot be interrupted.
local data = require("lib.data")
local buffs = require("sim.buffs")
local M = {}

function M.data() return data.load("home/kitchen.lua") end

function M.ingredient(id)
  for _, g in ipairs(M.data().ingredients) do
    if g.id == id then return g end
  end
  return nil
end

function M.name(id)
  local g = M.ingredient(id)
  return g and g.name or id
end

function M.recipe(id)
  for _, r in ipairs(M.data().recipes) do
    if r.id == id then return r end
  end
  return nil
end

function M.ensure(p)
  if not p.pantry then
    p.pantry = {}
    for k, v in pairs(M.data().starter or {}) do p.pantry[k] = v end
  end
  return p.pantry
end

function M.stock(p, id, n)
  local pan = M.ensure(M.owner(state, p))
  pan[id] = (pan[id] or 0) + n
  if pan[id] <= 0 then pan[id] = nil end
end

-- can this recipe be cooked from the pantry? -> ok, missing ingredient id
function M.owner(state, p)
  return require("sim.layout").house(state, p)
end

function M.can_cook(p, r)
  local pan = M.ensure(M.owner(state, p))
  for _, id in ipairs(saucer.util.sorted_keys(r.needs or {})) do
    if (pan[id] or 0) < r.needs[id] then return false, id end
  end
  return true
end

function M.needs_text(r)
  local parts = {}
  for _, id in ipairs(saucer.util.sorted_keys(r.needs or {})) do
    local n = r.needs[id]
    parts[#parts + 1] = (n > 1 and (n .. " ") or "") .. M.name(id)
  end
  return #parts > 0 and table.concat(parts, " + ") or "nothing"
end

-- start(state, p, id, ctx): takes the ingredients and starts the stove
function M.start(state, p, id, ctx)
  local r = M.recipe(id)
  if not r then return false end
  local host = M.owner(state, p)
  local ok, missing = M.can_cook(host, r)
  if not ok then
    ctx.msg(state, p, "Missing " .. M.name(missing) .. " for " .. r.name)
    ctx.fx(state, p, "denied")
    return false
  end
  for _, k in ipairs(saucer.util.sorted_keys(r.needs or {})) do M.stock(host, k, -r.needs[k]) end
  local s = M.data().cook_seconds or 3
  p.cooking = { recipe = id, left = s, total = s }
  p.panel = false
  ctx.msg(state, p, "Cooking " .. r.name .. "...")
  return true
end

-- step(state, p, dt, ctx) -> the recipe when the meal is ready
function M.step(state, p, dt, ctx)
  local c = p.cooking
  if not c then return nil end
  c.left = c.left - dt
  if c.left > 1e-9 then return nil end
  p.cooking = false
  local r = M.recipe(c.recipe)
  local host = M.owner(state, p)
  local given = {}
  local function feed(q)
    if not q or given[q.index] then return end
    given[q.index] = true
    for _, b in ipairs(saucer.util.sorted_keys(r.buffs or {})) do buffs.give(state, q, b, r.buffs[b]) end
  end
  feed(p)
  feed(host)
  for _, o in ipairs(state.players or {}) do
    if o.visiting == host.index then feed(o) end
  end
  p.meals = (p.meals or 0) + 1
  ctx.msg(state, p, r.text or ("You eat " .. r.name .. "."))
  ctx.fx(state, p, "pickup")
  return r
end

-- kitchen panel rows: every recipe (greyed when something is missing), the pantry
function M.rows(state, p, ctx)
  local rows = {}
  for _, r in ipairs(M.data().recipes) do
    local ok = M.can_cook(M.owner(state, p), r)
    local id = r.id
    rows[#rows + 1] = { text = string.format("Cook %s (%s)", r.name, M.needs_text(r)), enabled = ok,
      act = function(st, pl) M.start(st, pl, id, ctx) end }
  end
  local pan = M.ensure(M.owner(state, p))
  local ids = saucer.util.sorted_keys(pan)
  if #ids == 0 then rows[#rows + 1] = { text = "Pantry: empty", enabled = false } end
  for _, id in ipairs(ids) do
    local g = M.ingredient(id)
    rows[#rows + 1] = { text = string.format("Pantry: %s x%d%s", M.name(id), pan[id], g and g.origin == "alien" and " (alien)" or ""),
      enabled = false }
  end
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

return M
