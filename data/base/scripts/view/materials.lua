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

-- a civ's eight slots (index 1-7; slot 0 is plain)
function M.civ_slots(civ)
  local lib = M.library()
  local m = civ.materials
  local function rec(id) return lib[id] or lib.ceramic end
  local slots = {}
  -- add-design-language: a crystal that covers most of the skin glows a third as much (else whole halls blow out)
  local dom = rec(m.dominant.id)
  local calm = dom.kind == "crystal" and { emit = (dom.emit or 0.4) * M.DOMINANT_GLOW } or nil
  slots[M.SLOT.dominant] = M.slot(dom, calm)
  slots[M.SLOT.lung] = M.slot(dom, { breath = M.BREATH, emit = calm and calm.emit or nil })
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

local slot_cache = setmetatable({}, { __mode = "k" })
-- set a civ's slots and matcap on this view; `time` is render seconds (breathing, glow, pulse)
function M.apply(v, civ, time)
  local slots = slot_cache[civ]
  if not slots then
    slots = M.civ_slots(civ)
    slot_cache[civ] = slots
  end
  local mc = saucer.render.matcap and saucer.render.matcap("matcap:" .. civ.id, civ.matcap or {}, M.AMBIENT) or 0
  return v:materials({ time = time, matcap = mc, slots = slots })
end

return M
