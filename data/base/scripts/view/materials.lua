-- SPDX-License-Identifier: MIT
-- add-material-system: turn the material library (civs/materials.lua) and a civ's material table into the eight
-- per-view shader slots (view:materials). Render-only: nothing here reaches the sim or the state hash.
--   slot 0 plain (the old look, always)    slot 4 the civ's rare material (crystal)
--   slot 1 the civ's dominant material     slot 5 the signature's ring (PIERCE: the wound)
--   slot 2 the dominant one, breathing     slot 6 the civ's decay (plague halls: no vein pulse)
--   slot 3 the civ's accent material       slot 7 floors (chitin plates)
-- With materials off (settings) the engine packs every slot plain and each part shows its vertex colour.
local data = require("lib.data")
local M = {}

M.SLOT = { plain = 0, dominant = 1, lung = 2, accent = 3, rare = 4, ring = 5, decay = 6, floor = 7 }
M.BREATH = 0.45      -- m: the breathing hall's slow swell along the skin's normal (period 3x the wobble's)
M.AMBIENT = 0.22     -- matcap ambient
M.DOMINANT_GLOW = 0.3 -- a dominant crystal's emission scale
M.DOMINANT_TONE = 0.55 -- a dominant crystal's bright ramp, rim and reflection scale (pale quartz halls blew out to white)

function M.library() return data.load("civs/materials.lua") end

-- one library record -> a view:materials slot table (stone and enamel shade as dull metals)
function M.slot(rec, over)
  local k = rec.kind
  local s
  if k == "metal" then
    s = { kind = "metal", reflect = rec.reflect or 0.8, spec = rec.spec or 48, f0 = rec.f0 or 0.5, brushed = rec.brushed,
          ripple = rec.ripple }
  elseif k == "crystal" then
    s = { kind = "crystal", reflect = rec.refract or 0.6, spec = 96, f0 = 0.08, emit = rec.emit or 0.4,
          pulse = rec.pulse or 0.3, sss = rec.rim or rec.hi, sparkle = rec.sparkle }
  elseif k == "organic" then
    local w = rec.wobble or { 0, 4, 8 }
    s = { kind = "organic", reflect = rec.wet or 0.3, spec = 24, f0 = 0.04, wrap = rec.wrap or 0.4, sss = rec.sss or rec.hi,
          wobble = { w[1], w[2], w[3] }, pulse = rec.pulse or 0, emit = rec.emit or 0 }
  else
    s = { kind = "metal", reflect = 0.15, spec = rec.spec or 12, f0 = 0.04 }
  end
  s.lo, s.hi = rec.lo, rec.hi
  for key, v in pairs(over or {}) do s[key] = v end
  return s
end

-- a crystal covering most of the skin: a third of the glow, and its pale ramp, rim and reflection toned down, so a
-- quartz hall reads as frosted glass instead of clipping to white (add-material-system §5)
local function tone(c) return { c[1] * M.DOMINANT_TONE, c[2] * M.DOMINANT_TONE, c[3] * M.DOMINANT_TONE } end
function M.calm_crystal(rec)
  local hi = rec.hi or { 1, 1, 1 }
  return { emit = (rec.emit or 0.4) * M.DOMINANT_GLOW, hi = tone(hi), sss = tone(rec.rim or hi),
           reflect = (rec.refract or 0.6) * M.DOMINANT_TONE }
end

-- a civ's eight slots (index 1-7; slot 0 is plain)
function M.civ_slots(civ)
  local lib = M.library()
  local m = civ.materials
  local function rec(id) return lib[id] or lib.ceramic end
  local slots = {}
  -- add-design-language: a crystal that covers most of the skin glows a third as much (else whole halls blow out)
  local dom = rec(m.dominant.id)
  local calm = dom.kind == "crystal" and M.calm_crystal(dom) or nil
  slots[M.SLOT.dominant] = M.slot(dom, calm)
  local lung = { breath = M.BREATH }
  for k, v in pairs(calm or {}) do lung[k] = v end
  slots[M.SLOT.lung] = M.slot(dom, lung)
  slots[M.SLOT.accent] = M.slot(rec(m.accent.id))
  slots[M.SLOT.rare] = M.slot(rec(m.rare.id))
  slots[M.SLOT.ring] = M.slot(rec(m.signature and m.signature.ring or "wound"))
  slots[M.SLOT.decay] = M.slot(rec(m.decay and m.decay[1] or "flesh_necrotic"), { pulse = 0 })
  slots[M.SLOT.floor] = M.slot(rec("chitin"))
  return M.fate(slots, civ, lib)
end

-- add-material-system §2.3.4: what the civ's fate did to its materials (the decay slot already holds its decay
-- material; this ages the rest). Plague keeps its look (its necrosis is the plague halls' decay slot).
--   war of silence  scorch: every ramp darkened toward soot, metals dulled
--   ascension       crust: the rare crystal blazes, the skin's rim takes the crystal's colour
--   sleep           dormancy: glow, pulse, wobble and breathing nearly stilled
--   flight          stripping: the accent metal stripped dull, the rare crystal dark (taken when they left)
--   schism          split: the breathing half of the skin takes the decay material's ramp
M.SCORCH = 0.55       -- war: ramp scale
M.CRUST = 1.6         -- ascension: rare glow scale
M.DORMANT = 0.25      -- sleep: glow / pulse / wobble scale
M.STRIP = 0.3         -- flight: the accent's reflect and spec scale
local function scale3(c, k) return c and { c[1] * k, c[2] * k, c[3] * k } end
function M.fate(slots, civ, lib)
  local fate = civ.fate or (civ.axes and civ.axes.fate)
  if fate == "war of silence" then
    for i = 1, 7 do
      local s = slots[i]
      s.lo, s.hi = scale3(s.lo, M.SCORCH * 0.7), scale3(s.hi, M.SCORCH)
      if s.kind == "metal" then s.reflect, s.spec = s.reflect * 0.6, math.max(8, s.spec * 0.5) end
    end
  elseif fate == "ascension" then
    local r = slots[M.SLOT.rare]
    r.emit = math.min(1, (r.emit or 0.4) * M.CRUST)
    for _, i in ipairs({ M.SLOT.dominant, M.SLOT.lung }) do slots[i].sss = r.hi end
  elseif fate == "sleep" then
    for i = 1, 7 do
      local s = slots[i]
      if s.emit then s.emit = s.emit * M.DORMANT end
      if s.pulse then s.pulse = s.pulse * M.DORMANT end
      if s.wobble then s.wobble = { s.wobble[1] * M.DORMANT, s.wobble[2] / M.DORMANT, s.wobble[3] } end
      if s.breath then s.breath = s.breath * 0.5 end
    end
  elseif fate == "flight" then
    local a = slots[M.SLOT.accent]
    a.reflect, a.spec = a.reflect * M.STRIP, math.max(8, a.spec * M.STRIP)
    local r = slots[M.SLOT.rare]
    r.emit, r.pulse = 0, 0
  elseif fate == "schism" then
    local d = (lib or M.library())[civ.materials.decay and civ.materials.decay[1] or "flesh_necrotic"] or {}
    local l = slots[M.SLOT.lung]
    l.lo, l.hi = d.lo or l.lo, d.hi or l.hi
  end
  return slots
end

-- the colour a part shows with materials off (and the base the ramp tints with them on): the record's mid ramp
function M.base_color(id)
  local r = M.library()[id]
  if not r then return { 0.6, 0.6, 0.6 } end
  return { (r.lo[1] + r.hi[1] * 2) / 3, (r.lo[2] + r.hi[2] * 2) / 3, (r.lo[3] + r.hi[3] * 2) / 3 }
end

-- add-material-system 5.4: comfort in a headset (WebXR): no sparkle, half the wobble, and no breathing faster than
-- M.XR_BREATH seconds a cycle (the breathing period is three wobble periods)
M.XR_BREATH = 4.0
function M.xr_slots(slots)
  local out = {}
  for i, s in pairs(slots) do
    local c = {}
    for k, val in pairs(s) do c[k] = val end
    c.sparkle = nil
    if s.wobble then c.wobble = { s.wobble[1] * 0.5, math.max(s.wobble[2], M.XR_BREATH / 3), s.wobble[3] } end
    out[i] = c
  end
  return out
end

-- add-material-system 5.3: the sector's sky as a metal outside sees it -> { key, sun, band, seed } (the star from
-- view/lights.lua, the galaxy's band tilted by the sector, stars from the seed)
M.BAND = 0.35
function M.sky(state)
  local seed, sid = math.floor(state.seed or 0) & 0x7fffffff, math.floor(state.sector_id or 1)
  local star = require("view.lights").star(seed, sid)
  local a = ((seed * 31 + sid * 7919) % 3600) / 3600 * math.pi * 2
  local tilt = 0.3 + ((seed + sid * 104729) % 1000) / 1000 * 0.9
  local band = { math.sin(tilt) * math.cos(a), math.cos(tilt), math.sin(tilt) * math.sin(a), M.BAND }
  return { key = "sky:" .. seed .. ":" .. sid, sun = star.dir, band = band, seed = (seed * 131 + sid) % 1000003 }
end

local slot_cache = setmetatable({}, { __mode = "k" })
local xr_cache = setmetatable({}, { __mode = "k" })
-- set a civ's slots and matcap on this view; `time` is render seconds (breathing, glow, pulse); `xr` a headset view
function M.apply(v, civ, time, xr, sky)
  local slots = slot_cache[civ]
  if not slots then
    slots = M.civ_slots(civ)
    slot_cache[civ] = slots
  end
  if xr then
    local x = xr_cache[civ]
    if not x then
      x = M.xr_slots(slots)
      xr_cache[civ] = x
    end
    slots = x
  end
  if sky and saucer.render.skymap then
    local id = saucer.render.skymap(sky.key, { sun = sky.sun, band = sky.band, seed = sky.seed, ambient = 0.04 })
    return v:materials({ time = time, matcap = id, envmap = true, slots = slots })
  end
  local mc = saucer.render.matcap and saucer.render.matcap("matcap:" .. civ.id, civ.matcap or {}, M.AMBIENT) or 0
  return v:materials({ time = time, matcap = mc, envmap = false, slots = slots })
end

return M
