-- SPDX-License-Identifier: MIT
-- Loot rolls (concept §6). Each player gets their own instance of every slot:
-- instance seed = seed_child(slot_seed, "owner", record_index).
local data = require("lib.data")
local M = {}

M.RARITY = {
  { id = "common", name = "Common", w = 60, mult = 1.0 },
  { id = "rare",   name = "Rare",   w = 30, mult = 1.8 },
  { id = "relic",  name = "Relic",  w = 10, mult = 3.5 },
}

function M.instance_seed(slot_seed, record_index)
  return saucer.seed_child(slot_seed, "owner", record_index)
end

-- category (optional): only base types of that category (a trader's stock of modules)
function M.roll(seed, max_size, tier, category)
  local types, aff = data.load("items/types.lua"), data.load("affixes/affixes.lua")
  local rng = saucer.rng.new(seed)
  local pool = {}
  for _, t in ipairs(types) do
    if t.size <= max_size and (not category or t.category == category) then pool[#pool + 1] = t end
  end
  local t = rng:pick(pool) or types[1]
  local rar = {}
  for i, r in ipairs(M.RARITY) do rar[i] = { v = r, w = r.w + (i > 1 and (tier - 1) * 15 or 0) } end
  local rarity = rng:weighted(rar)
  local item = { type = t.id, size = t.size, rarity = rarity.id, affixes = {}, quirk = false }
  local value = t.value * rarity.mult
  local name = t.name
  if rng:int(1, 100) <= 40 + 20 * (tier - 1) then
    local a = rng:pick(aff.prefixes)
    local v = rng:int(a.min, a.max)
    item.affixes[#item.affixes + 1] = { id = a.id, stat = a.stat, value = v }
    name = a.name .. " " .. name
    value = value + v * 2
  end
  if rng:int(1, 100) <= 25 + 15 * (tier - 1) then
    local a = rng:pick(aff.suffixes)
    local v = rng:int(a.min, a.max)
    item.affixes[#item.affixes + 1] = { id = a.id, stat = a.stat, value = v }
    name = name .. " " .. a.name
    value = value + v * 2
  end
  if rng:int(1, 100) <= 20 then item.quirk = rng:pick(aff.quirks).id end
  item.name = name
  item.value = math.floor(value)
  return item
end

M.SIZE_NAMES = { "S", "M", "L", "XL" }
function M.size_name(c) return M.SIZE_NAMES[c] or "?" end

return M
