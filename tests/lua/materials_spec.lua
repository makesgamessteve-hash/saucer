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
