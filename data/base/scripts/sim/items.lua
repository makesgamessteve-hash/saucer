-- SPDX-License-Identifier: MIT
-- Items in a hold (concept §6): identification, display names, hot/banked
-- state and Echoes. An item is a plain table rolled by sim.loot plus
-- { uid, tier, civ, category, ident, hot } added when it is picked up.
local data = require("lib.data")
local M = {}

M.ROMAN = { "I", "II", "III", "IV", "V" }

local function type_of(id)
  for _, t in ipairs(data.load("items/types.lua")) do
    if t.id == id then return t end
  end
  return nil
end
M.type_of = type_of

local function civ_name(id)
  local c = id and require("sim.civs").by_id(nil, id)
  return c and c.name or "Unknown"
end
M.civ_name = civ_name

-- stamp a freshly tractored item with where it came from
function M.stamp(p, item, tier, civ_id)
  p.next_uid = (p.next_uid or 0) + 1
  item.uid = p.next_uid
  item.tier = item.tier or tier or 1
  item.civ = item.civ or civ_id
  local t = type_of(item.type)
  item.category = item.category or (t and t.category) or "curio"
  if item.ident == nil then item.ident = false end
  return item
end

function M.is_echo(item) return item.echo ~= nil end

function M.sellable(item)
  -- add-holodeck-home-life: books and ingredient crates go home, they are not sold
  return not item.echo and not item.unique and not (item.home and (item.value or 0) <= 0)
end

-- what the HUD and panels call it
function M.label(item)
  if item.home and item.home.kind == "program" then
    return item.ident and ("Data core: " .. (item.home.title or item.home.id)) or "Data core (undecoded)"
  end
  if item.echo or item.unique or item.ident or not item.category then return item.name end
  local cat = item.category:sub(1, 1):upper() .. item.category:sub(2)
  return string.format("Unknown %s %s T%d", civ_name(item.civ), cat, item.tier or 1)
end

function M.find(p, uid)
  for i, it in ipairs(p.hold) do
    if it.uid == uid then return it, i end
  end
  return nil
end

function M.remove(p, uid)
  local _, i = M.find(p, uid)
  if i then return table.remove(p.hold, i) end
  return nil
end

-- hot items that can be lost (never Echoes or unique Curios)
function M.losable(p)
  local out = {}
  for _, it in ipairs(p.hold) do
    if it.hot and not it.echo and not it.unique then out[#out + 1] = it end
  end
  return out
end

function M.count_hot(p)
  local n = 0
  for _, it in ipairs(p.hold) do if it.hot then n = n + 1 end end
  return n
end

return M
