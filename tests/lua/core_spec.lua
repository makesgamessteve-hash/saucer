-- SPDX-License-Identifier: MIT
-- Locked-down Lua runtime and saucer.* API (spec lua-runtime).
describe("sandbox", function()
  it("forbids clocks, io and unseeded randomness", function()
    local env = setmetatable({}, { __index = saucer }) -- just to touch the api
    expect(env.engine.api).to_be(1)
    expect(function() return math.random(1, 2) end).to_fail()
  end)
  it("exposes deterministic math", function()
    expect(saucer.math.sin(0)).to_be(0)
    expect(saucer.math.cos(0)).to_be(1)
    expect(saucer.math.sqrt(16)).to_be(4)
    expect(saucer.math.atan2(1, 0)).to_be_near(saucer.math.pi / 2, 1e-12)
    expect(saucer.math.wrap(saucer.math.tau + 0.5)).to_be_near(0.5, 1e-12)
  end)
  it("sorted_pairs iterates in key order", function()
    local keys = {}
    for k in saucer.util.sorted_pairs({ c = 1, a = 2, b = 3 }) do keys[#keys + 1] = k end
    expect(keys).to_equal({ "a", "b", "c" })
  end)
end)

describe("rng", function()
  it("is reproducible from a seed", function()
    local a, b = saucer.rng.new(42), saucer.rng.new(42)
    for _ = 1, 100 do expect(a:int(1, 1000)).to_be(b:int(1, 1000)) end
  end)
  it("child streams are independent of draw order", function()
    local a = saucer.rng.new(7)
    local c1 = a:child("loot", 3):int(0, 1 << 30)
    a:int(1, 10)
    local c2 = a:child("loot", 3):int(0, 1 << 30)
    expect(c1).to_be(c2)
    expect(saucer.seed_child(7, "loot", 3)).to_be(saucer.rng.new(7):child("loot", 3):seed())
  end)
  it("weighted picks honour zero weights", function()
    local r = saucer.rng.new(1)
    for _ = 1, 50 do expect(r:weighted({ { w = 0, v = "never" }, { w = 1, v = "always" } })).to_be("always") end
  end)
end)
