-- SPDX-License-Identifier: MIT
-- add-design-language (design civs-and-relics §2): a civ's design language, generated from its trait axes
-- (sim/civroster.lua) and a child seed of the universe seed. Everything is data the views and generators sample:
-- massing and primitive weights, symmetry, fractal depth, organic warp, proportions, aperture, edge, surface, the
-- material palette with its one signature pairing, the palette row, the style card, the light model (from the
-- senses), glyphs and sound. Render-only: nothing here reaches the sim state or the roster hash.
local data = require("lib.data")
local M = {}

function M.tables() return data.load("civs/languages.lua") end
local function lib() return data.load("civs/materials.lua") end
local function sorted_pairs(t) return saucer.util.sorted_pairs(t) end

local function pick(rng, list) -- { {key, weight}, ... } with integer weights
  local total = 0
  for _, e in ipairs(list) do total = total + e[2] end
  if total <= 0 then return list[1][1] end
  local r = rng:int(1, total)
  for _, e in ipairs(list) do
    r = r - e[2]
    if r <= 0 then return e[1] end
  end
  return list[#list][1] -- unreachable
end
M.pick = pick

local function one_of(rng, t) return t[rng:int(1, #t)] end
local function clamp01(x) return math.max(0, math.min(1, x)) end
local function round2(x) return math.floor(x * 100 + 0.5) / 100 end

-- the favourite materials of a civ (tech, values, biology), existing library records only
function M.favourites(axes)
  local T, L = M.tables(), lib()
  local fav = {}
  for _, key in ipairs({ axes.tech, axes.values, axes.biology }) do
    for _, id in ipairs(T.favour[key] or {}) do if L[id] then fav[id] = true end end
  end
  return fav
end

-- materials(rng, axes) -> the §2.3.2 table: dominant, accent, rare, signature { rule, guest, host, ring }, decay
function M.materials(rng, axes)
  local T, L = M.tables(), lib()
  local fav = M.favourites(axes)
  local kw = T.kinds[axes.tech] or { metal = 1, crystal = 1, organic = 1, stone = 1 }
  local function kind_w(id)
    local k = L[id] and L[id].kind or "stone"
    if k == "enamel" then k = "stone" end
    return kw[k] or 0
  end
  -- the signature first (every civ gets exactly one), weighted by the table and how well it fits the civ
  local pairs_w = {}
  for i, p in ipairs(T.odd_pairs) do
    if L[p[1]] and L[p[2]] then
      local fit = 1 + kind_w(p[1]) + kind_w(p[2]) + (fav[p[1]] and 3 or 0) + (fav[p[2]] and 3 or 0)
      pairs_w[#pairs_w + 1] = { i, p[3] * fit }
    end
  end
  local sig = T.odd_pairs[pick(rng, pairs_w)]
  local guest, host, rule = sig[1], sig[2], sig[4]
  -- the rare focal material: a crystal (emissive) unlike both, favourites first
  local rares = {}
  for id, r in sorted_pairs(L) do
    if r.kind == "crystal" and id ~= guest and id ~= host then rares[#rares + 1] = { id, fav[id] and 4 or 1 } end
  end
  local rare = pick(rng, rares)
  local decay = T.decay[axes.fate] or T.decay.plague
  local share = function(a, b) return { round2(a + rng:int(0, 5) / 100), round2(b + rng:int(0, 5) / 100) } end
  return {
    dominant = { id = host, share = share(0.5, 0.65) },
    accent = { id = guest, share = share(0.2, 0.3) },
    rare = { id = rare, share = { 0.03, 0.10 } },
    signature = { rule = rule, guest = guest, host = host, ring = T.ring[rule] or "wound" },
    decay = { decay[1], decay[2] },
  }
end

-- the light model of a civ's senses (§2.5) and three lamp colours from its materials
function M.light(rng, axes, mats)
  local T, L = M.tables(), lib()
  local m = T.light[axes.senses] or T.light.sight
  local function bright(c)
    local mx = math.max(c[1], c[2], c[3], 0.01)
    return { round2(c[1] / mx), round2(c[2] / mx), round2(c[3] / mx) }
  end
  local rare, acc, dom = L[mats.rare.id], L[mats.accent.id], L[mats.dominant.id]
  local key = m.key or bright(rare.rim or rare.hi)
  local lamps = { key, bright(acc.hi), bright(dom.sss or dom.hi) }
  return {
    model = m.model, key = key, lamp_colors = lamps, lamps = m.lamps, k = m.k, haze = m.haze, pools = m.pools,
    orbs = m.orbs or 0, max = T.max_lights,
    -- a little per-civ variety in how far the key lamps carry (render only)
    reach = round2(0.85 + rng:int(0, 30) / 100),
  }
end

-- generate(seed, civ) -> the civ's language (needs civ.axes and civ.index)
function M.generate(seed, civ)
  local T, L = M.tables(), lib()
  local a = civ.axes
  local rng = saucer.rng.new(saucer.seed_child(seed, "language", civ.index or 0))
  local lang = {}
  -- massing: the civ's archetype 0.5, the rest spread over the others
  lang.massing = {}
  for _, k in ipairs(T.massings) do lang.massing[k] = 0 end
  lang.massing[civ.massing or "cluster"] = 0.5
  local left = 0.5
  for i = 1, 3 do
    local k = one_of(rng, T.massings)
    local w = (i < 3) and round2(left * rng:int(30, 60) / 100) or round2(left)
    lang.massing[k] = round2(lang.massing[k] + w)
    left = round2(left - w)
  end
  -- primitives (normalised weights)
  local pw, total = T.primitives[a.biology] or T.primitives.bilateral, 0
  for _, w in sorted_pairs(pw) do total = total + w end
  lang.primitives = {}
  for k, w in sorted_pairs(pw) do lang.primitives[k] = round2(w / total) end
  -- symmetry and fractal depth
  local mode = T.symmetry[a.biology] or "none"
  lang.symmetry = { mode = mode, n = mode == "radial" and one_of(rng, T.radial_n) or (mode == "bilateral" and 2 or 1),
                    jitter = round2(rng:int(0, 10) / 100) }
  local depth = (mode == "fractal") and rng:int(2, 3) or rng:int(0, 1)
  lang.fractal = { depth = depth, scale = depth > 0 and round2(rng:int(30, 45) / 100) or 0 }
  lang.organic = round2(clamp01((T.organic[a.tech] or 0.2) + (T.organic_bio[a.biology] or 0) + rng:int(-5, 5) / 100))
  local tall = ({ tiny = 0.4, human = 0.5, large = 0.6, giant = 0.75, colossal = 0.9 })[a.body_scale] or 0.5
  lang.proportion = { hall_aspect = { 1.0, round2(1.3 + rng:int(0, 50) / 100) }, height_ratio = tall,
                      golden = a.values == "faith" or a.values == "harmony" or a.values == "knowledge" }
  lang.aperture = one_of(rng, T.aperture[a.biology] or { "arch" })
  lang.edge = one_of(rng, T.edge[a.values] or { "chamfer" })
  lang.surface = { ribs = round2(clamp01(lang.organic + rng:int(10, 40) / 100)), panels = round2(clamp01(0.6 - lang.organic)),
                   glyph_bands = round2(rng:int(10, 60) / 100),
                   cilia = (a.biology == "colonial" or a.biology == "serpentine") and round2(rng:int(10, 40) / 100) or 0 }
  lang.materials = M.materials(rng, a)
  lang.palette = { row = "civ_" .. civ.id, accents = 2 }
  lang.style_card = "data/base/art/styles/civ_" .. civ.id .. ".lua"
  lang.light = M.light(rng, a, lang.materials)
  lang.glyphs = { system = one_of(rng, T.glyphs[a.senses] or { "branching_script" }), strokes = { rng:int(2, 4), rng:int(5, 9) },
                  carrier = T.carrier[a.senses] or "emissive_inlay" }
  local dk = L[lang.materials.dominant.id].kind
  lang.sound = { scale = civ.music and civ.music.scale or "minor", drone = T.drone[dk] or "breath",
                 tempo = round2((civ.music and civ.music.tempo or 72) / 120), room_tone = T.room_tone[civ.massing or "cluster"] or "dry" }
  -- the fields the relic slice's views already read (civs/relic_slice.lua)
  lang.edges = lang.edge
  lang.rhythm = lang.surface.ribs >= 0.5 and "ribbed" or "panelled"
  lang.senses = a.senses
  lang.lamp_colors = lang.light.lamp_colors
  return lang
end

-- the matcap a civ's metals reflect (view space lights: x, y, z, intensity), from its light model
function M.matcap(lang)
  local k = lang.light.k
  return { { 0.55, 0.65, 0.55, round2(0.4 + 0.75 * k) }, { -0.7, 0.25, 0.45, round2(0.15 + 0.4 * k) },
           { 0.1, -0.8, 0.4, round2(0.1 + 0.25 * k) } }
end

-- dress(seed, civ): give a civ its language, its material table and its matcap (authored fields win)
function M.dress(seed, civ)
  if civ.language and civ.language.materials then return civ end
  -- the authored civs (data tables shared by every universe) always get the language of seed 0
  local lang = M.generate(civ.generated and seed or 0, civ)
  for k, v in pairs(civ.language or {}) do lang[k] = v end -- an authored civ's pins
  if civ.materials then lang.materials = civ.materials end
  civ.language = lang
  civ.materials = civ.materials or lang.materials
  civ.matcap = civ.matcap or M.matcap(lang)
  return civ
end

return M
