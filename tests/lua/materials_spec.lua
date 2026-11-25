-- SPDX-License-Identifier: MIT
-- add-material-system: the material library (civs/materials.lua), the Vyrr's material table and how they become
-- the shader's eight per-view slots (view/materials.lua). Render-only; the engine side has C tests.
local matv = require("view.materials")
local data = require("lib.data")

describe("the material library", function()
  it("gives every record a kind and a dark-to-bright ramp", function()
    local lib = matv.library()
    local n = 0
    local kinds = { metal = true, crystal = true, organic = true, stone = true, enamel = true }
    for id, rec in pairs(lib) do
      n = n + 1
      expect(kinds[rec.kind]).to_be(true)
      for a = 1, 3 do
        expect(rec.lo[a] >= 0 and rec.hi[a] <= 1 and rec.lo[a] <= rec.hi[a]).to_be(true)
      end
      expect(type(id)).to_be("string")
    end
    expect(n >= 20).to_be(true)
    for _, id in ipairs({ "chrome", "amethyst", "membrane", "wound", "flesh_necrotic", "chitin" }) do
      expect(lib[id] ~= nil).to_be(true)
    end
  end)

  it("turns each kind into a slot (stone and enamel shade as dull metals)", function()
    local lib = matv.library()
    local m = matv.slot(lib.chrome)
    expect(m.kind).to_be("metal")
    expect(m.reflect).to_be(lib.chrome.reflect)
    local c = matv.slot(lib.amethyst)
    expect(c.kind).to_be("crystal")
    expect(c.reflect).to_be(lib.amethyst.refract)
    expect(c.emit).to_be(lib.amethyst.emit)
    local o = matv.slot(lib.membrane, { breath = 0.3 })
    expect(o.kind).to_be("organic")
    expect(o.wobble[1]).to_be(lib.membrane.wobble[1])
    expect(o.breath).to_be(0.3)
    local s = matv.slot(lib.basalt)
    expect(s.kind).to_be("metal")
    expect(s.reflect < 0.3).to_be(true)
    local bare = matv.slot({ kind = "organic", lo = { 0, 0, 0 }, hi = { 1, 1, 1 } })
    expect(bare.wobble[1]).to_be(0)
    local bm = matv.slot({ kind = "metal", lo = { 0, 0, 0 }, hi = { 1, 1, 1 } })
    expect(bm.spec).to_be(48)
    local bc = matv.slot({ kind = "crystal", lo = { 0, 0, 0 }, hi = { 1, 1, 1 } })
    expect(bc.sss[1]).to_be(1)
  end)
end)

describe("the Vyrr's materials", function()
  local civ = data.load("civs/relic_slice.lua")
  it("are membrane (dominant), chrome (accent) and amethyst (rare), signed PIERCE", function()
    expect(civ.materials.dominant.id).to_be("membrane")
    expect(civ.materials.accent.id).to_be("chrome")
    expect(civ.materials.rare.id).to_be("amethyst")
    expect(civ.materials.signature.rule).to_be("PIERCE")
    expect(civ.materials.signature.ring).to_be("wound")
  end)

  it("fill the slots: the lung breathes, the decay has no vein pulse, the floors are still", function()
    local slots = matv.civ_slots(civ)
    local S = matv.SLOT
    expect(slots[S.dominant].kind).to_be("organic")
    expect(slots[S.dominant].breath).to_be(nil)
    expect(slots[S.lung].breath).to_be(matv.BREATH)
    expect(slots[S.accent].kind).to_be("metal")
    expect(slots[S.rare].kind).to_be("crystal")
    expect(slots[S.ring].kind).to_be("organic")
    expect(slots[S.ring].pulse > 0).to_be(true)
    expect(slots[S.decay].pulse).to_be(0)
    expect(slots[S.floor].wobble[1]).to_be(0)
    expect(slots[0]).to_be(nil)
  end)

  it("fall back when a civ names materials the library lacks", function()
    local odd = { materials = { dominant = { id = "nope" }, accent = { id = "chrome" }, rare = { id = "amethyst" } } }
    local slots = matv.civ_slots(odd)
    expect(slots[matv.SLOT.dominant].kind).to_be("metal") -- ceramic
    expect(slots[matv.SLOT.ring].kind).to_be("organic")   -- wound by default
  end)

  it("give each part a materials-off colour from its ramp", function()
    local c = matv.base_color("chrome")
    expect(c[1] > 0.5).to_be(true)
    local g = matv.base_color("unknown")
    expect(g[1]).to_be(0.6)
  end)

  it("go on a view with the civ's matcap and render time", function()
    local got
    local v = {}
    function v:materials(t) got = t return 7 end
    expect(matv.apply(v, civ, 2.5)).to_be(7)
    expect(got.time).to_be(2.5)
    expect(got.slots[matv.SLOT.accent].kind).to_be("metal")
    matv.apply(v, civ, 3)
    expect(got.time).to_be(3)
  end)
end)

describe("fate materials", function()
  local civs = require("sim.civs")
  local function as(fate)
    local base = civs.universe(42)[3]
    return setmetatable({ id = "fate_" .. fate, fate = fate }, { __index = base })
  end
  local S = matv.SLOT
  it("leaves the plague's look to its decay slot and ages the others by their fate", function()
    local base = civs.universe(42)[3]
    local plain = matv.civ_slots(as("plague"))
    local lib = matv.library()
    -- war: every ramp darker, metals duller
    local war = matv.civ_slots(as("war of silence"))
    for i = 1, 7 do
      expect(war[i].hi[1] <= plain[i].hi[1] + 1e-9).to_be(true)
      if war[i].kind == "metal" then expect(war[i].reflect < plain[i].reflect).to_be(true) end
    end
    -- ascension: the rare crystal blazes, the skin's rim in its colour
    local asc = matv.civ_slots(as("ascension"))
    expect(asc[S.rare].emit >= (plain[S.rare].emit or 0)).to_be(true)
    expect(asc[S.dominant].sss).to_be(asc[S.rare].hi)
    -- sleep: everything stills
    local sl = matv.civ_slots(as("sleep"))
    for i = 1, 7 do
      if plain[i].pulse and plain[i].pulse > 0 then expect(sl[i].pulse < plain[i].pulse).to_be(true) end
      if plain[i].wobble then expect(sl[i].wobble[1] <= plain[i].wobble[1]).to_be(true) end
    end
    expect(sl[S.lung].breath).to_be(matv.BREATH * 0.5)
    -- flight: the accent stripped, the rare dark
    local fl = matv.civ_slots(as("flight"))
    expect(fl[S.accent].reflect < plain[S.accent].reflect + 1e-9).to_be(true)
    expect(fl[S.rare].emit).to_be(0)
    -- schism: the breathing half takes the decay ramp
    local sc = matv.civ_slots(as("schism"))
    local d = lib[base.materials.decay and base.materials.decay[1] or "flesh_necrotic"]
    expect(sc[S.lung].hi).to_be(d.hi)
    for c = 1, 3 do expect(sc[S.dominant].hi[c]).to_be(plain[S.dominant].hi[c]) end
    -- the library itself is never changed
    expect(matv.library().chrome.reflect).to_be(0.92)
  end)
end)

describe("sparkle, brushing and ripples", function()
  it("carries a crystal's sparkle and a metal's brushing and ripple into its slot", function()
    local lib = matv.library()
    expect(matv.slot(lib.quartz).sparkle).to_be(lib.quartz.sparkle)
    expect(matv.slot(lib.titanium_blue).brushed).to_be(lib.titanium_blue.brushed)
    expect(matv.slot(lib.mercury).ripple).to_be(lib.mercury.ripple)
    -- the slice's materials keep their look (no sparkle on amethyst, no brushing on chrome)
    expect(matv.slot(lib.amethyst).sparkle).to_be(nil)
    expect(matv.slot(lib.chrome).brushed).to_be(nil)
    for id, rec in pairs(lib) do
      if rec.sparkle then expect(rec.kind == "crystal" and rec.sparkle > 0 and rec.sparkle <= 1).to_be(true) end
      if rec.brushed then expect(rec.kind == "metal" and rec.brushed > 0 and rec.brushed <= 1).to_be(true) end
      if rec.ripple then expect(rec.kind == "metal" and rec.ripple > 0 and rec.ripple <= 0.3).to_be(true) end
      expect(type(id)).to_be("string")
    end
  end)
end)

describe("headset comfort", function()
  it("drops the sparkle, halves the wobble and slows the breathing to at least 4 s in a headset", function()
    local civs = require("sim.civs")
    local base = civs.universe(42)[3]
    local c = setmetatable({ id = "xr_test", materials = { dominant = { id = "membrane" }, accent = { id = "silver" },
                                                           rare = { id = "quartz" }, decay = { "flesh_necrotic" } } },
                           { __index = base })
    local slots = matv.civ_slots(c)
    local x = matv.xr_slots(slots)
    local S = matv.SLOT
    expect(slots[S.rare].sparkle ~= nil).to_be(true)
    expect(x[S.rare].sparkle).to_be(nil)
    expect(x[S.dominant].wobble[1]).to_be(slots[S.dominant].wobble[1] * 0.5)
    for _, s in pairs(x) do
      if s.wobble then expect(s.wobble[2] * 3 >= matv.XR_BREATH - 1e-9).to_be(true) end
    end
    -- apply hands the headset its own slots (cached), the flat view the full ones
    local got = {}
    local v = { materials = function(_, t) got[#got + 1] = t return 7 end }
    matv.apply(v, c, 1, true)
    matv.apply(v, c, 1, true)
    matv.apply(v, c, 1, false)
    expect(got[1].slots).to_be(got[2].slots)
    expect(got[1].slots[S.rare].sparkle).to_be(nil)
    expect(got[3].slots[S.rare].sparkle).to_be(slots[S.rare].sparkle)
  end)
end)

describe("sky reflections", function()
  it("reflects the sector's sky outside a relic and the matcap inside", function()
    local st = { seed = 42, sector_id = 3 }
    local a, b = matv.sky(st), matv.sky(st)
    expect(a.key).to_be(b.key)
    expect(a.sun).to_be(require("view.lights").star(42, 3).dir)
    local l = math.sqrt(a.band[1] ^ 2 + a.band[2] ^ 2 + a.band[3] ^ 2)
    expect(math.abs(l - 1) < 1e-6).to_be(true)
    expect(matv.sky({ seed = 42, sector_id = 4 }).key ~= a.key).to_be(true)
    expect(matv.sky({}).key).to_be("sky:0:1")
    local civs = require("sim.civs")
    local got = {}
    local v = { materials = function(_, t) got[#got + 1] = t return 7 end }
    matv.apply(v, civs.vyrr(), 1, false, a)
    matv.apply(v, civs.vyrr(), 1, false, nil)
    expect(got[1].envmap).to_be(saucer.render.skymap ~= nil)
    expect(got[2].envmap).to_be(false)
    if saucer.render.skymap then expect(got[1].matcap > 0).to_be(true) end
  end)
end)
