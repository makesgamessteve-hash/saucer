-- SPDX-License-Identifier: MIT
-- add-design-language (design civs-and-relics §2, §8.2): every civ's design language, its signature rules on a
-- relic's skin (never inside a flyable box), the light model from the senses and the Vyrr as the grammar's output.
local civs = require("sim.civs")
local lang = require("sim.language")
local ruinm = require("sim.ruin")
local relic = require("sim.relic")
local relicv = require("view.relic")
local lights = require("view.lights")
local matv = require("view.materials")

local ORIGIN = { 0, -4000, 0 }
local function gen42() return ruinm.generate(42, "relic", relic.civ(), ORIGIN) end
local function kit() return ruinm.kit_of("relic") end
local function lib() return matv.library() end

local FIELDS = { "massing", "primitives", "symmetry", "fractal", "organic", "proportion", "aperture", "edge", "surface",
                 "materials", "palette", "style_card", "light", "glyphs", "sound" }

-- a civ like c with its signature rule forced (and its own id, so the view caches it apart)
local function with_rule(c, rule)
  local m = {}
  for k, v in pairs(c.materials) do m[k] = v end
  m.signature = { rule = rule, guest = m.signature.guest, host = m.signature.host,
                  ring = lang.tables().ring[rule] }
  local out = {}
  for k, v in pairs(c) do out[k] = v end
  out.id, out.materials = c.id .. "_" .. rule:lower(), m
  return out
end

-- a rough AABB of a part (oriented parts: their position +- their biggest extent)
local function aabb(part)
  if part.kind == "box" then return part.min, part.max end
  if part.kind == "patch" then -- its four corners and its bulge's top (along u x v)
    local c, u, v, h = part.c, part.u, part.v, part.h
    local n = { u[2] * v[3] - u[3] * v[2], u[3] * v[1] - u[1] * v[3], u[1] * v[2] - u[2] * v[1] }
    local l = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
    local mn, mx = {}, {}
    for a = 1, 3 do
      local top = c[a] + (u[a] + v[a]) / 2 + h * n[a] / l
      mn[a] = math.min(c[a], c[a] + u[a], c[a] + v[a], c[a] + u[a] + v[a], top)
      mx[a] = math.max(c[a], c[a] + u[a], c[a] + v[a], c[a] + u[a] + v[a], top)
    end
    return mn, mx
  end
  -- an oriented part (view/relic ORIENT): its +y runs along an axis direction from pos; lateral extent its radius plus
  -- its offset and tilt
  local p, c, h, r = part.pos or { 0, 0, 0 }, part.c or { 0, 0, 0 }, part.h or 0, part.r or 0
  local ax, sg = 2, 1
  for dir, o in pairs(relicv.ORIENT) do
    if part.pos and o.roll == (part.roll or 0) and o.pitch == (part.pitch or 0) then
      ax, sg = ({ x = 1, y = 2, z = 3 })[dir:sub(2)], dir:sub(1, 1) == "+" and 1 or -1
    end
  end
  local y0, y1 = c[2], c[2] + h
  if part.kind == "sphere" then y0, y1 = c[2] - h, c[2] + h end
  local lat = r + math.abs(c[1]) + math.abs(c[3]) + 0.4 * h
  local mn, mx = {}, {}
  for a = 1, 3 do
    if a == ax then
      local e0, e1 = p[a] + sg * y0, p[a] + sg * y1
      mn[a], mx[a] = math.min(e0, e1), math.max(e0, e1)
    else
      mn[a], mx[a] = p[a] - lat, p[a] + lat
    end
  end
  return mn, mx
end

describe("design language", function()
  it("every civ has a language", function()
    for _, seed in ipairs({ 1, 42, 7, 51, 900 }) do
      for _, c in ipairs(civs.universe(seed)) do
        for _, f in ipairs(FIELDS) do
          if c.language[f] == nil then error(c.id .. " has no " .. f) end
        end
        local m = c.materials
        for _, k in ipairs({ "dominant", "accent", "rare" }) do expect(lib()[m[k].id] ~= nil).to_be(true) end
        expect(lib()[m.rare.id].kind).to_be("crystal")
        expect(lib()[m.signature.ring] ~= nil).to_be(true)
        expect(m.signature.host).to_be(m.dominant.id)
        expect(m.signature.guest).to_be(m.accent.id)
        expect(#c.language.lamp_colors).to_be(3)
        expect(c.language.light.max <= 16).to_be(true)
        expect(#c.matcap).to_be(3)
        local sum = 0
        for _, w in pairs(c.language.massing) do sum = sum + w end
        expect(sum).to_be_near(1, 0.02)
      end
    end
    -- the same seed gives the same language; an authored civ's is the same in every universe
    local a, b = civs.universe(42)[5].language, lang.generate(42, civs.universe(42)[5])
    expect(a.materials.dominant.id).to_be(b.materials.dominant.id)
    expect(a.aperture).to_be(b.aperture)
    expect(civs.universe(1)[1].language).to_be(civs.universe(2)[1].language)
  end)

  it("draws every signature rule and pulls materials by tech focus", function()
    local rules, organic_dom, bio = {}, 0, 0
    for s = 1, 60 do
      for i, c in ipairs(civs.universe(s * 13)) do
        if i > 2 then
          rules[c.materials.signature.rule] = true
          if c.axes.tech == "bio" then
            bio = bio + 1
            if lib()[c.materials.dominant.id].kind == "organic" then organic_dom = organic_dom + 1 end
          end
        end
      end
    end
    for _, r in ipairs({ "PIERCE", "INLAY", "ENCASE", "PLATE", "CRUST", "FLOW" }) do expect(rules[r]).to_be(true) end
    expect(organic_dom / bio > 0.5).to_be(true)
    -- an unknown tech focus or senses still gets a language
    local odd = { id = "odd", index = 3, generated = true, massing = "ring",
                  axes = { body_scale = "?", biology = "?", senses = "?", social = "?", tech = "?", values = "?", fate = "?", era = "?" } }
    local l = lang.generate(5, odd)
    expect(l.light.model).to_be("chromatic")
    expect(l.symmetry.mode).to_be("none")
    expect(lang.pick(saucer.rng.new(1), { { "a", 0 } })).to_be("a")
  end)

  it("echo civs use ripple lighting", function()
    local echo, sight
    for s = 1, 40 do
      for _, c in ipairs(civs.universe(s)) do
        if c.axes.senses == "echo" and not echo then echo = c end
        if c.axes.senses == "sight" and c.generated and not sight then sight = c end
      end
    end
    expect(echo.language.light.model).to_be("ripple")
    expect(sight.language.light.model).to_be("chromatic")
    local r = gen42()
    relicv.set_style(echo)
    local le = relicv.lamps(r, ORIGIN)
    relicv.set_style(sight)
    local ls = relicv.lamps(r, ORIGIN)
    relicv.set_style(nil)
    local function total(list)
      local t = 0
      for _, l in ipairs(list) do t = t + l.intensity end
      return t
    end
    expect(#le < #ls).to_be(true)
    expect(total(le) < total(ls) * 0.3).to_be(true)
    expect(le[1].model).to_be("ripple")
    -- the ripple sweeps (dark between pulses), an orbit lamp circles its post, an arc flickers
    local l = { pos = { 0, 0, 0 }, model = "ripple", phase = 0 }
    local lo, hi = 1, 0
    for t = 0, 4, 0.05 do
      local k = lights.animate(l, t, 1)
      lo, hi = math.min(lo, k), math.max(hi, k)
    end
    expect(lo < 0.2 and hi > 0.9).to_be(true)
    local _, p = lights.animate({ pos = { 0, 0, 0 }, model = "orbit", phase = 1 }, 3, 1)
    expect(math.sqrt(p[1] ^ 2 + p[3] ^ 2)).to_be_near(lights.ORBIT, 0.01)
    local flick = {}
    for t = 0, 2, 1 / 11 do flick[lights.animate({ pos = { 0, 0, 0 }, model = "arc", phase = 2 }, t, 1)] = true end
    expect(flick[1.0] and flick[0.35]).to_be(true)
    expect(select(1, lights.animate({ pos = { 0, 0, 0 }, model = "dark" }, 1, 0.5))).to_be(0.5)
  end)

  it("skins never change envelopes: every rule's parts stay out of every flyable box", function()
    local r = gen42()
    local k = kit()
    local inner = {}
    for _, room in ipairs(r.rooms) do
      local mn, mx = ruinm.room_box(room, k, ORIGIN)
      inner[#inner + 1] = { { mn[1] + k.wall, mn[2] + k.wall, mn[3] + k.wall }, { mx[1] - k.wall, mx[2] - k.wall, mx[3] - k.wall } }
    end
    local base = civs.universe(42)[3]
    for _, rule in ipairs({ "PIERCE", "CRUST", "PLATE", "ENCASE", "INLAY", "FLOW" }) do
      local all = relicv.parts(r, ORIGIN, with_rule(base, rule))
      local bad, n = 0, 0
      for _, part in ipairs(all.ext) do
        if not part.skin then
          n = n + 1
          local mn, mx = aabb(part)
          for _, b in ipairs(inner) do
            local cut = true
            for a = 1, 3 do if mn[a] >= b[2][a] - 0.01 or mx[a] <= b[1][a] + 0.01 then cut = false end end
            if cut then bad = bad + 1 end
          end
        end
      end
      if bad > 0 then error(rule .. ": " .. bad .. " parts reach into a flyable box") end
      expect(n > 50).to_be(true)
    end
  end)

  it("restyles a relic: another civ's colours, ribs and signature", function()
    local r = gen42()
    local vy = relicv.parts(r, ORIGIN)
    local other = with_rule(civs.universe(42)[3], "PLATE")
    other.id = other.id .. "_panel"
    other.language = setmetatable({ rhythm = "panelled" }, { __index = other.language })
    local pl = relicv.parts(r, ORIGIN, other)
    local cc = relicv.colors(other)
    expect(cc.rib).to_be(relicv.RIB_PANEL)
    expect(cc.rule).to_be("PLATE")
    local plates = 0
    for _, part in ipairs(pl.ext) do if part.kind == "cylinder" and part.r == 3.4 then plates = plates + 1 end end
    expect(plates > 20).to_be(true)
    local function count(set)
      local n = 0
      for _, e in ipairs(set.rooms) do n = n + #e.parts end
      return n
    end
    expect(count(pl) < count(vy)).to_be(true) -- fewer ribs
    -- the style override reaches the meshes and the lamps; clearing it restores the Vyrr
    relicv.set_style(other)
    expect(relicv.civ_of(r).id).to_be(other.id)
    local set = relicv.meshes(r, ORIGIN)
    expect(set.civ.id).to_be(other.id)
    relicv.ensure(set, 1)
    relicv.set_style(nil)
    expect(set.rooms[1].mesh).to_be(nil)
    expect(relicv.civ_of(r).id).to_be("vyrr")
  end)

  it("re-expresses the Vyrr through the grammar (its authored fields are pins)", function()
    local v = civs.vyrr()
    expect(v.language.materials).to_be(v.materials)
    expect(v.materials.signature.rule).to_be("PIERCE")
    expect(v.language.edges).to_be("round")
    expect(v.language.light.model).to_be("chromatic")
    expect(v.language.symmetry.mode).to_be("none") -- serpentine
    expect(v.language.organic > 0.6).to_be(true)
    expect(relic.civ()).to_be(v)
    expect(lang.dress(0, v)).to_be(v)
  end)
end)

describe("design language slots", function()
  it("calms a dominant crystal's glow", function()
    local c = { id = "glassy", materials = { dominant = { id = "quartz" }, accent = { id = "gold" }, rare = { id = "amethyst" },
                                             signature = { ring = "vein" }, decay = { "basalt" } } }
    local s = matv.civ_slots(c)
    expect(s[matv.SLOT.dominant].emit).to_be_near(0.15 * matv.DOMINANT_GLOW, 1e-6)
    expect(s[matv.SLOT.lung].emit).to_be_near(0.15 * matv.DOMINANT_GLOW, 1e-6)
    expect(s[matv.SLOT.dominant].hi[1]).to_be_near(0.95 * matv.DOMINANT_TONE, 1e-6)
    expect(s[matv.SLOT.lung].sss[3]).to_be_near(1.0 * matv.DOMINANT_TONE, 1e-6)
    expect(s[matv.SLOT.dominant].reflect).to_be_near(0.8 * matv.DOMINANT_TONE, 1e-6)
    expect(s[matv.SLOT.lung].breath).to_be(matv.BREATH)
    expect(s[matv.SLOT.rare].hi[1]).to_be(matv.library().amethyst.hi[1])
    expect(matv.civ_slots(civs.vyrr())[matv.SLOT.dominant].emit).to_be(0.55)
  end)
end)
