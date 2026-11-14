-- SPDX-License-Identifier: MIT
-- spec loot
local loot = require("sim.loot")
local mystery = require("sim.mystery")
local sector = require("sim.sector")

describe("loot", function()
  it("each player gets an own, reproducible instance", function()
    local s1, s2 = loot.instance_seed(99, 0), loot.instance_seed(99, 1)
    expect(s1 ~= s2).to_be(true)
    expect(loot.roll(s1, 3, 1)).to_equal(loot.roll(s1, 3, 1))
  end)
  it("respects the slot size class and names affixes", function()
    local affixed, quirky, sizes = 0, 0, {}
    for i = 1, 300 do
      local it = loot.roll(i, 1, 2)
      expect(it.size <= 1).to_be(true)
      expect(it.value).to_be_greater(0)
      if #it.affixes > 0 then affixed = affixed + 1 end
      if it.quirk then quirky = quirky + 1 end
      sizes[it.size] = true
    end
    expect(affixed).to_be_greater(0)
    expect(quirky).to_be_greater(0)
    expect(loot.roll(1, 0, 1).type).to_be("lens") -- nothing fits: first type
  end)
  it("names size classes", function()
    expect(loot.size_name(2)).to_be("M")
    expect(loot.size_name(9)).to_be("?")
  end)
end)

describe("mystery", function()
  it("builds a three Echo chain from the seed", function()
    local m = mystery.generate(42, "on", 3)
    expect(#m.echoes).to_be(3)
    expect(m.echoes[1].text).to_contain("Echo I")
    expect(m.echoes[1].text:find("{", 1, true)).to_be(nil)
    expect(mystery.generate(42, "on", 3)).to_equal(m)
  end)
  it("finds echoes per site and completes", function()
    local m = mystery.generate(1, nil, 2)
    expect(m.mode).to_be("on")
    expect(mystery.echo_at(m, 1)).to_be(1)
    expect(mystery.found(m, 1, 1)).to_be(false)
    expect(mystery.found(m, 1, 1)).to_be(false) -- already found
    expect(mystery.echo_at(m, 1)).to_be(3)
    mystery.found(m, 2, 1)
    expect(mystery.found(m, 3, 2)).to_be(true)
    expect(mystery.echo_at(m, 2)).to_be(nil)
  end)
  it("sandbox mode hides the chain; hints mode points at it", function()
    local m = mystery.generate(1, "off", 3)
    expect(mystery.active(m)).to_be(false)
    expect(mystery.echo_at(m, 1)).to_be(nil)
    m.mode = "hints"
    expect(mystery.hint(m)).to_contain("site 1")
    for i = 1, 3 do mystery.found(m, i, 1) end
    expect(mystery.hint(m)).to_be(nil)
    m.solved = false
    expect(mystery.hint(m)).to_be(nil)
    m.mode = "on"
    expect(mystery.hint(m)).to_be(nil)
  end)
  it("cycles modes", function()
    expect(mystery.next_mode("on")).to_be("hints")
    expect(mystery.next_mode("hints")).to_be("off")
    expect(mystery.next_mode("off")).to_be("on")
    expect(mystery.next_mode("bogus")).to_be("on")
  end)
end)

describe("sector", function()
  it("places three sites deterministically", function()
    local a, b = sector.generate(5), sector.generate(5)
    expect(a).to_equal(b)
    expect(#a.sites).to_be(3)
    expect(a.sites[1].civ).to_be(1)
    expect(a.sites[2].kit).to_be("station")
  end)
end)
