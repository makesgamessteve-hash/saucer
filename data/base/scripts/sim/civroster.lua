-- SPDX-License-Identifier: MIT
-- add-civ-roster (design §1): the roster's trait axes, its diversity guard, its generated history, the names a civ
-- goes by and the scanner's lore lines. sim/civs.lua calls in here; everything is a pure function of the universe
-- seed (child seeds, sorted iteration, integer maths), so the roster hash matches on every platform.
--
-- Compatibility: the legacy fields (body, shape, domains, fate, temperament, ...) are drawn exactly as before, and
-- every axis is drawn from the values consistent with them, so legacy == derive(axes) holds for every civ and old
-- universes keep their sites, kits and music (and both replays).
local data = require("lib.data")
local M = {}

M.AXES = { "body_scale", "biology", "senses", "social", "tech", "values", "fate", "era" }

local function traits() return data.load("civs/traits.lua") end
function M.history_data() return data.load("civs/history.lua") end
local function sorted_pairs(t) return saucer.util.sorted_pairs(t) end

-- the roster size, clamped (design §1.1)
function M.size()
  local T = traits()
  local n = T.roster_size or T.count
  return math.max(T.roster_min or 6, math.min(T.roster_max or 10, n))
end

-- pick(rng, {{key, weight}, ...}) -> key; deterministic, integer weights only
local function pick(rng, list)
  local total = 0
  for _, e in ipairs(list) do total = total + e[2] end
  local r = rng:int(1, total)
  for _, e in ipairs(list) do
    r = r - e[2]
    if r <= 0 then return e[1] end
  end
  return list[#list][1] -- unreachable with positive weights
end
M.pick = pick

local function weight_of(v) return type(v) == "table" and (v.w or 1) or v end
local function contains(t, x)
  for _, y in ipairs(t) do if y == x then return true end end
  return false
end

-- the candidates (key, weight) of one axis given the civ's legacy fields
function M.candidates(axis, c)
  local A = traits().axes
  local out = {}
  if axis == "fate" then
    return { { c.fate, 1 } }
  end
  for k, v in sorted_pairs(A[axis]) do
    local ok = true
    if axis == "body_scale" then ok = v.body == c.body
    elseif axis == "tech" then ok = (c.domains and c.domains[1]) == k
    elseif axis == "values" then
      local soc = c.axes and A.social[c.axes.social]
      ok = contains(v, c.temperament) or (soc ~= nil and contains(soc.temper, c.temperament))
    end
    if ok then out[#out + 1] = { k, weight_of(axis == "values" and 1 or v) } end
  end
  if #out == 0 then -- an unknown legacy value (a mod's): every value of the axis
    for k, v in sorted_pairs(A[axis]) do out[#out + 1] = { k, weight_of(axis == "values" and 1 or v) } end
  end
  return out
end

-- the legacy fields an axis set implies (the "derive" direction the spec names)
function M.derive(axes)
  local A = traits().axes
  local d = { body = A.body_scale[axes.body_scale] and A.body_scale[axes.body_scale].body, fate = axes.fate }
  d.domain = axes.tech
  d.temperaments = {}
  for _, t in ipairs(A.values[axes.values] or {}) do d.temperaments[#d.temperaments + 1] = t end
  for _, t in ipairs(A.social[axes.social] and A.social[axes.social].temper or {}) do
    d.temperaments[#d.temperaments + 1] = t
  end
  return d
end

-- draw(rng, c) -> axes, massing for civ c (legacy fields already set)
function M.draw(rng, c)
  local axes = {}
  c.axes = axes -- values read the social structure drawn just before them
  for _, a in ipairs(M.AXES) do axes[a] = pick(rng, M.candidates(a, c)) end
  local soc = traits().axes.social[axes.social]
  return axes, soc.massing[rng:int(1, #soc.massing)]
end

local function shared(a, b)
  local n = 0
  for _, k in ipairs(M.AXES) do if a.axes[k] == b.axes[k] then n = n + 1 end end
  return n
end
M.shared = shared

-- check(roster) -> ok, why
function M.check(roster)
  local D = traits().diversity
  local massings, scales, nm, ns = {}, {}, 0, 0
  for _, c in ipairs(roster) do
    if not massings[c.massing] then massings[c.massing], nm = true, nm + 1 end
    if not scales[c.axes.body_scale] then scales[c.axes.body_scale], ns = true, ns + 1 end
  end
  if nm < D.massings then return false, "massings" end
  if ns < D.scales then return false, "scales" end
  for i = 1, #roster do
    for j = i + 1, #roster do
      if shared(roster[i], roster[j]) > D.shared then return false, "shared", i, j end
    end
  end
  return true
end

-- the deterministic swap (design §1.1): walk every generated civ through every candidate value of every axis (in a
-- fixed order) and keep a change whenever it lowers the roster's distance to the diversity rule
local function badness(roster)
  local D = traits().diversity
  local massings, scales, nm, ns, over = {}, {}, 0, 0, 0
  for _, c in ipairs(roster) do
    if not massings[c.massing] then massings[c.massing], nm = true, nm + 1 end
    if not scales[c.axes.body_scale] then scales[c.axes.body_scale], ns = true, ns + 1 end
  end
  for i = 1, #roster do
    for j = i + 1, #roster do over = over + math.max(0, shared(roster[i], roster[j]) - D.shared) end
  end
  return over + math.max(0, D.massings - nm) * 4 + math.max(0, D.scales - ns) * 4
end
M.badness = badness

local function set(c, a, v)
  c.axes[a] = v
  if a == "social" then c.massing = traits().axes.social[v].massing[1] end
end

-- one civ: the best strict improvement over every single value change, then over every pair of changes (a pair
-- gets out of the local minima where one change fixes a pair of civs and breaks another)
-- valid(c): the civ's values still allow its temperament (a social change can take that away)
local function valid(c)
  for _, cand in ipairs(M.candidates("values", c)) do
    if cand[1] == c.axes.values then return true end
  end
  return false
end
M.valid = valid

local function improve(roster, c)
  local A = traits().axes
  local best, choice = badness(roster), nil
  local save_axes, save_m = {}, c.massing
  for _, a in ipairs(M.AXES) do save_axes[a] = c.axes[a] end
  local function restore()
    for _, a in ipairs(M.AXES) do c.axes[a] = save_axes[a] end
    c.massing = save_m
  end
  for i, a in ipairs(M.AXES) do
    for _, ca in ipairs(M.candidates(a, c)) do
      set(c, a, ca[1])
      local b = valid(c) and badness(roster) or math.huge
      if b < best then best, choice = b, { { a, ca[1] } } end
      for j = i + 1, #M.AXES do
        local a2 = M.AXES[j]
        for _, cb in ipairs(M.candidates(a2, c)) do
          set(c, a2, cb[1])
          b = valid(c) and badness(roster) or math.huge
          if b < best then best, choice = b, { { a, ca[1] }, { a2, cb[1] } } end
        end
        c.axes[a2] = save_axes[a2]
        c.massing = (a2 == "social") and save_m or c.massing
      end
      restore()
    end
  end
  if choice then
    for _, ch in ipairs(choice) do set(c, ch[1], ch[2]) end
  end
  -- the social structure's other massings
  for _, mm in ipairs(A.social[c.axes.social].massing) do
    local before, oldm = badness(roster), c.massing
    c.massing = mm
    if badness(roster) >= before then c.massing = oldm end
  end
end

function M.swap(roster)
  for _ = 1, 6 do
    if badness(roster) == 0 then break end
    for _, c in ipairs(roster) do
      if c.generated and badness(roster) > 0 then improve(roster, c) end
    end
  end
  return roster
end

-- apply(seed, roster): give every generated civ its axes (rejection-sampled, then the swap)
function M.apply(seed, roster)
  local D = traits().diversity
  local try = 0
  while true do
    try = try + 1
    for _, c in ipairs(roster) do
      if c.generated then
        local rng = saucer.rng.new(saucer.seed_child(saucer.seed_child(seed, "civ_axes", c.index), "try", try))
        c.axes, c.massing = M.draw(rng, c)
      end
    end
    if M.check(roster) or try >= D.tries then break end
  end
  if not M.check(roster) then M.swap(roster) end
  roster.tries = try
  return roster
end

-- names (design §1.4) ------------------------------------------------------------------------------------------------
function M.endonym(rng, senses)
  local P = traits().phonology[senses] or traits().phonology.sight
  local n = P[1][rng:int(1, #P[1])] .. P[2][rng:int(1, #P[2])] .. P[3][rng:int(1, #P[3])]
  return n:sub(1, 1):upper() .. n:sub(2):lower()
end

function M.exonym(c)
  local E = traits().exonym
  local first = (c.axes.senses ~= "sight" and E.first[c.axes.senses]) or E.first[c.axes.social] or "Far"
  local second = E.second[c.axes.tech] or "Made"
  return string.format("the %s-%s %s", first, second, E.third[c.axes.body_scale] or "Folk")
end

function M.name(seed, c)
  if not c.generated then -- the authored civs keep their own name and nickname in every universe
    c.endonym = c.endonym or c.name
    c.exonym = c.exonym or M.exonym(c)
    return
  end
  local rng = saucer.rng.new(saucer.seed_child(seed, "civ_name", c.index))
  c.endonym = M.endonym(rng, c.axes.senses)
  c.exonym = M.exonym(c)
end

-- station_name(seed, civ, n, taken) -> "<function word> of <glyph word>", unique in taken
function M.station_name(seed, c, n, taken)
  local T = traits()
  local rng = saucer.rng.new(saucer.seed_child(saucer.seed_child(seed, "station_name", c.index), "n", n))
  for k = 1, 32 do
    local nm = T.station_words[rng:int(1, #T.station_words)] .. " of " .. M.endonym(rng, c.axes.senses)
    if k > 16 then nm = nm .. "-" .. k end
    if not (taken and taken[nm]) then
      if taken then taken[nm] = true end
      return nm
    end
  end
  return nil -- unreachable: the numbered fallback is unique
end

-- history (design §1.3) ----------------------------------------------------------------------------------------------
local BEATS = { "emergence", "expansion", "contacts", "golden age", "catastrophe", "afterlife" }

local function span(rng, c)
  local E = traits().era_kyr[c.axes.era]
  local L = M.history_data().span_kyr
  local a = rng:int(E[2], E[1])
  return { a, math.max(0, a - rng:int(L[1], L[2])) } -- from, to (kyr before now); a > to
end

local function overlap(x, y) return x.span[1] > y.span[2] and y.span[1] > x.span[2] end
M.overlap = overlap

local function relation(rng, a, b)
  local H = M.history_data()
  local w = {}
  for k, v in sorted_pairs(H.relations) do w[k] = v end
  for _, c in ipairs({ a, b }) do
    for k, v in sorted_pairs(H.temperament[c.temperament] or {}) do w[k] = w[k] + v end
    for k, v in sorted_pairs(H.value[c.axes.values] or {}) do w[k] = w[k] + v end
  end
  local list = {}
  for k, v in sorted_pairs(w) do list[#list + 1] = { k, v } end
  return pick(rng, list)
end

-- history(seed, roster) -> { civs = { [i] = { span, beats, stations, age } }, relations = { "i:j" = rel },
--   conquests = { [loser] = { by = winner, share = 0.1..0.25 } }, tutelage = { [student] = teacher } }
function M.history(seed, roster)
  local H = M.history_data()
  local rng = saucer.rng.new(saucer.seed_child(seed, "history", 0))
  local h = { civs = {}, relations = {}, conquests = {}, tutelage = {} }
  for i, c in ipairs(roster) do
    local e = { span = span(rng, c) }
    local n = rng:int(H.beats[1], H.beats[2])
    e.beats = {}
    for k = 1, n do
      local idx = k
      if n < #BEATS and k >= 3 then idx = k + (#BEATS - n) end -- short histories skip contacts / golden age
      if k == n then idx = #BEATS end
      local t = e.span[1] - math.floor((e.span[1] - e.span[2]) * (k - 1) / math.max(1, n - 1))
      e.beats[k] = { kind = BEATS[idx], kyr = t }
    end
    e.stations = rng:int(H.stations[1], H.stations[2])
    e.age = H.ages[rng:int(1, #H.ages)]
    h.civs[i] = e
  end
  for i = 1, #roster do
    for j = i + 1, #roster do
      roster[i].span, roster[j].span = h.civs[i].span, h.civs[j].span
      if overlap(h.civs[i], h.civs[j]) then
        local r = relation(rng, roster[i], roster[j])
        h.relations[i .. ":" .. j] = r
        -- the elder (earlier from) is the conqueror / teacher
        local elder, younger = i, j
        if h.civs[j].span[1] > h.civs[i].span[1] then elder, younger = j, i end
        if r == "conquest" and not h.conquests[younger] then
          local s = H.wing_share
          local share = (math.floor(s[1] * 100) + rng:int(0, math.floor((s[2] - s[1]) * 100))) / 100
          h.conquests[younger] = { by = elder, share = share }
        elseif r == "tutelage" and not h.tutelage[younger] then
          h.tutelage[younger] = elder
        end
      end
    end
  end
  for _, c in ipairs(roster) do c.span = nil end
  return h
end

-- relation(h, i, j) -> the relation of two civs ("ignorance" when their eras never touched)
function M.relation_of(h, i, j)
  if i > j then i, j = j, i end
  return h.relations[i .. ":" .. j] or "ignorance"
end

-- wing(seed, h, civ_index, relic_n) -> the conqueror's index when relic n of this civ carries a later wing
function M.wing(seed, h, ci, n)
  local q = h.conquests[ci]
  if not q then return nil end
  local rng = saucer.rng.new(saucer.seed_child(saucer.seed_child(seed, "wing", ci), "n", n))
  if rng:int(1, 100) <= math.floor(q.share * 100 + 0.5) then return q.by end
  return nil
end

-- lore(seed, roster, h, i, n) -> one scanner lore line about civ i (n picks the template)
function M.lore(seed, roster, h, i, n)
  local H = M.history_data()
  local c, e = roster[i], h.civs[i]
  local verb = H.fate_verb[c.fate] or "vanished"
  local k = ((n or 1) - 1) % #H.lore + 1
  local name = c.endonym or c.name
  if k == 1 then return string.format(H.lore[1], e.age, name, verb) end
  if k == 2 then return string.format(H.lore[2], name, e.age, verb) end
  return string.format(H.lore[3], c.axes.values, name, e.age)
end

-- hash ---------------------------------------------------------------------------------------------------------------
local function fnv(hsh, s)
  for k = 1, #s do hsh = ((hsh ~ s:byte(k)) * 16777619) & 0xffffffff end
  return hsh
end
M.fnv = fnv

-- hash(roster, h) -> a 32-bit integer over every civ's id, axes, names and the whole history
function M.hash(roster, h)
  local x = 2166136261
  for i, c in ipairs(roster) do
    x = fnv(x, c.id .. "|" .. (c.endonym or "") .. "|" .. (c.exonym or "") .. "|" .. (c.massing or ""))
    for _, a in ipairs(M.AXES) do x = fnv(x, a .. "=" .. tostring(c.axes and c.axes[a])) end
    local e = h and h.civs[i]
    if e then
      x = fnv(x, e.span[1] .. ":" .. e.span[2] .. ":" .. e.stations .. ":" .. e.age)
      for _, b in ipairs(e.beats) do x = fnv(x, b.kind .. b.kyr) end
    end
  end
  if h then
    for k, r in sorted_pairs(h.relations) do x = fnv(x, k .. r) end
    for k, q in sorted_pairs(h.conquests) do x = fnv(x, k .. ">" .. q.by .. "@" .. q.share) end
    for k, t in sorted_pairs(h.tutelage) do x = fnv(x, k .. "<" .. t) end
  end
  return x
end

return M
