-- SPDX-License-Identifier: MIT
-- Civilizations (concept §5.3, OpenSpec add-wider-dark). A universe has the
-- two hand-tuned civs of civs/civs.lua plus civs generated from the trait
-- tables in civs/traits.lua, each from its own child seed of the universe
-- seed. Nothing here is saved: the list is a pure function of the seed.
local data = require("lib.data")
local M = {}

function M.traits() return data.load("civs/traits.lua") end
function M.fixed() return data.load("civs/civs.lua") end

local function name_of(rng, T)
  local n = rng:pick(T.onsets) .. rng:pick(T.middles) .. rng:pick(T.codas)
  return n:sub(1, 1):upper() .. n:sub(2):lower()
end

-- generate(seed, i) -> one civ (i > #fixed). taken: ids already used
function M.generate(seed, i, taken)
  local T = M.traits()
  local rng = saucer.rng.new(saucer.seed_child(seed, "civ", i))
  local name = name_of(rng, T)
  local id = name:lower()
  if taken and taken[id] then id = id .. i end
  local shape_names = {}
  for k in saucer.util.sorted_pairs(T.shapes) do shape_names[#shape_names + 1] = k end
  local shape = rng:pick(shape_names)
  local doms = {}
  local d1 = rng:int(1, #T.domains)
  local d2 = (d1 + rng:int(0, #T.domains - 2)) % #T.domains + 1
  doms[1], doms[2] = T.domains[d1], T.domains[d2]
  local sl = T.size_lock
  return {
    id = id, name = name, generated = true, index = i,
    body = rng:pick(T.bodies), shape = shape, palette = T.shapes[shape].palette,
    domains = doms, fate = rng:pick(T.fates), temperament = rng:pick(T.temperaments),
    entrance = rng:pick(T.entrances), size_lock = rng:int(sl[1], sl[2]),
    tint = rng:pick(T.tints), kits = T.shapes[shape].kits,
    music = { scale = rng:pick(T.scales), root = rng:int(0, 11), tempo = rng:int(T.tempo[1], T.tempo[2]),
              voice = rng:pick(T.voices) },
    glyph = rng:int(1, 999),
  }
end

local memo = {}
local current = nil
-- the universe the sim runs right now (game.init / rebuild set it), so code
-- that only has a civ id (item labels, prices) can find its civ
function M.use(seed) current = seed end
function M.current() return current end
-- universe(seed) -> the full civ list (memoized per seed)
function M.universe(seed)
  local key = tostring(seed)
  if memo[key] then return memo[key] end
  local out, taken = {}, {}
  for i, c in ipairs(M.fixed()) do
    out[i] = c
    c.index = i
    taken[c.id] = true
  end
  for i = #out + 1, M.traits().count do
    local c = M.generate(seed, i, taken)
    taken[c.id] = true
    out[i] = c
  end
  memo[key] = out
  return out
end

function M.get(seed, i) return M.universe(seed)[i] end

function M.by_id(seed, id)
  -- add-relic-stations: the slice's hard-seeded Vyrr are not in the generated roster
  if id == "vyrr" then return data.load("civs/relic_slice.lua") end
  for _, c in ipairs(M.universe(seed or current or 0)) do
    if c.id == id then return c end
  end
  return nil
end

-- the civ of a site (sites keep an index into the universe list)
function M.of(state, site)
  if site and site.relic_civ then return data.load("civs/relic_slice.lua") end
  return site and M.universe(state.seed)[site.civ] or nil
end

-- a human-readable trait line (the Xenoarchive and the sector map show it)
function M.describe(c)
  return string.format("%s: %s %s builders, %s, %s (%s/%s)", c.name, c.body, c.shape, c.temperament, c.fate,
    c.domains[1], c.domains[2])
end

return M
