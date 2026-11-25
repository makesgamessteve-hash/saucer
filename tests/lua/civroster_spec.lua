-- SPDX-License-Identifier: MIT
-- add-civ-roster (design §1, §8.1): roster size, trait axes, diversity, history, palimpsest wings, names, lore, hash.
local civs = require("sim.civs")
local R = require("sim.civroster")
local data = require("lib.data")

local function traits() return data.load("civs/traits.lua") end

-- a roster of n generated civs that all share every legacy field (the diversity guard's worst case)
local function clones(n)
  local out = {}
  for i = 1, n do
    out[i] = { id = "c" .. i, name = "C" .. i, generated = true, index = i, body = "human", domains = { "bio", "fold" },
               fate = "sleep", temperament = "proud" }
  end
  return out
end

describe("civ roster", function()
  it("default roster: 8 civs and slots 1-2 are Velari and Oquun", function()
    local u = civs.universe(42)
    expect(#u).to_be(8)
    expect(R.size()).to_be(8)
    expect(u[1].id).to_be("velari")
    expect(u[2].id).to_be("oquun")
    for i = 3, #u do expect(u[i].generated).to_be(true) end
  end)

  it("clamps the roster size to 6..10", function()
    local T = traits()
    local old = T.roster_size
    T.roster_size = 30
    expect(R.size()).to_be(10)
    T.roster_size = 2
    expect(R.size()).to_be(6)
    T.roster_size = nil
    expect(R.size()).to_be(T.count)
    T.roster_size = old
  end)

  it("legacy fields derive", function()
    for _, seed in ipairs({ 1, 42, 7, 99, 1234 }) do
      for _, c in ipairs(civs.universe(seed)) do
        for _, a in ipairs(R.AXES) do expect(c.axes[a]).to_be_truthy() end
        local d = R.derive(c.axes)
        expect(d.body).to_be(c.body)
        expect(d.fate).to_be(c.fate)
        expect(d.domain).to_be(c.domains[1])
        expect(table.concat(d.temperaments, ",")).to_contain(c.temperament)
        local m = traits().axes.social[c.axes.social].massing
        expect(table.concat(m, ",")).to_contain(c.massing)
      end
    end
  end)

  it("every roster over 200 seeds meets the diversity rule", function()
    local scales_seen, massing_seen = {}, {}
    for s = 1, 200 do
      local u = civs.universe(s * 104729 + 3)
      local ok, why = R.check(u)
      if not ok then error("seed " .. s .. " fails " .. tostring(why)) end
      for _, c in ipairs(u) do
        scales_seen[c.axes.body_scale] = true
        massing_seen[c.massing] = true
      end
    end
    local ns, nm = 0, 0
    for _ in pairs(scales_seen) do ns = ns + 1 end
    for _ in pairs(massing_seen) do nm = nm + 1 end
    expect(ns).to_be(5)
    expect(nm).to_be(6)
  end)

  it("the deterministic swap fixes a roster rejection sampling cannot", function()
    local T = traits()
    local D = T.diversity
    local old = D.tries
    D.tries = 1
    local u = { civs.fixed()[1], civs.fixed()[2] }
    for _, c in ipairs(clones(6)) do c.index = #u + 1; u[#u + 1] = c end
    for _, c in ipairs(u) do if c.generated then c.axes, c.massing = R.draw(saucer.rng.new(1), c) end end
    expect(R.check(u)).to_be(false)
    expect(R.badness(u)).to_be_greater(0)
    R.swap(u)
    local before = R.badness(u)
    expect(before).to_be_less(4)
    R.apply(5, u)
    expect(u.tries).to_be(1)
    D.tries = old
    -- every rule is checked
    local a = clones(2)
    for _, c in ipairs(a) do c.axes, c.massing = R.draw(saucer.rng.new(3), c) end
    expect(select(2, R.check(a))).to_be("massings")
    a[1].massing, a[2].massing, a[3] = "ring", "spine", { axes = { body_scale = "human" }, massing = "shell" }
    a[1].axes.body_scale, a[2].axes.body_scale = "human", "human"
    expect(select(2, R.check(a))).to_be("scales")
  end)

  it("draws from every value of an axis whose legacy value is unknown", function()
    local c = { body = "blob", domains = { "song" }, temperament = "odd", fate = "sleep" }
    expect(#R.candidates("body_scale", c)).to_be(5)
    expect(#R.candidates("tech", c)).to_be(6)
    expect(#R.candidates("values", c)).to_be(7)
    expect(#R.candidates("fate", c)).to_be(1)
    expect(R.pick(saucer.rng.new(1), { { "a", 0 }, { "b", 0 } })).to_be("b")
    -- the social structure widens the values a temperament allows
    local p = { temperament = "proud", axes = { social = "council" } }
    expect(#R.candidates("values", p)).to_be(2)
    p.axes.social = "solitary"
    expect(#R.candidates("values", p)).to_be(7)
    p.axes.values = "faith"
    expect(R.valid(p)).to_be(true)
    p.axes.social = "council"
    expect(R.valid(p)).to_be(false)
  end)

  it("same seed same history", function()
    local u = civs.universe(77)
    local h1, h2 = R.history(77, u), R.history(77, u)
    expect(R.hash(u, h1)).to_be(R.hash(u, h2))
    expect(civs.roster_hash(77)).to_be(R.hash(u, h1))
    expect(civs.roster_hash(78) ~= civs.roster_hash(77)).to_be(true)
    expect(R.hash(u)).to_be_truthy()
    local H = R.history_data()
    for i in ipairs(u) do
      local e = h1.civs[i]
      expect(#e.beats >= H.beats[1] and #e.beats <= H.beats[2]).to_be(true)
      expect(e.beats[1].kind).to_be("emergence")
      expect(e.beats[2].kind).to_be("expansion")
      expect(e.beats[#e.beats].kind).to_be("afterlife")
      expect(e.span[1] > e.span[2]).to_be(true)
      expect(e.stations >= H.stations[1] and e.stations <= H.stations[2]).to_be(true)
    end
    -- a relation exactly for each pair whose eras overlap
    for i = 1, #u do
      for j = i + 1, #u do
        local has = h1.relations[i .. ":" .. j] ~= nil
        expect(has).to_be(R.overlap(h1.civs[i], h1.civs[j]))
        if not has then expect(R.relation_of(h1, j, i)).to_be("ignorance") end
      end
    end
  end)

  it("conquest adds wings", function()
    local found, kinds = 0, {}
    for s = 1, 120 do
      local h = civs.history(s)
      for k in pairs(h.relations) do kinds[h.relations[k]] = true end
      for loser, q in saucer.util.sorted_pairs(h.conquests) do
        found = found + 1
        expect(q.share >= 0.10 and q.share <= 0.25).to_be(true)
        expect(civs.relation(s, loser, q.by)).to_be("conquest")
        local wings = 0
        for n = 1, 400 do
          local w = civs.wing(s, loser, n)
          if w then
            wings = wings + 1
            expect(w).to_be(q.by)
          end
        end
        expect(wings / 400).to_be_near(q.share, 0.06)
        expect(civs.wing(s, loser, 3)).to_be(civs.wing(s, loser, 3))
      end
      for i = 1, #civs.universe(s) do
        if not h.conquests[i] then expect(civs.wing(s, i, 1)).to_be(nil) end
      end
      for student, teacher in pairs(h.tutelage) do expect(civs.relation(s, student, teacher)).to_be("tutelage") end
    end
    expect(found).to_be_greater(5)
    for _, k in ipairs({ "trade", "war", "alliance", "tutelage", "conquest" }) do expect(kinds[k]).to_be(true) end
  end)

  it("names a civ from its senses and gives it a trader nickname", function()
    local u = civs.universe(42)
    expect(u[1].endonym).to_be("Velari")
    expect(u[1].exonym).to_be("the Glass-Weight Folk")
    for i = 3, #u do
      expect(u[i].endonym).to_be_truthy()
      expect(u[i].exonym:sub(1, 4)).to_be("the ")
    end
    expect(R.exonym({ axes = { senses = "echo", social = "hive", tech = "resonance", body_scale = "giant" } }))
      .to_be("the Bell-Singers Titans")
    expect(R.exonym({ axes = { senses = "sight", social = "nomad", tech = "?", body_scale = "?" } }))
      .to_be("the Drift-Made Folk")
    expect(R.exonym({ axes = { senses = "sight", social = "?" } })).to_be("the Far-Made Folk")
    local rng = saucer.rng.new(9)
    local e = R.endonym(rng, "echo")
    expect(#e > 2).to_be(true)
    expect(R.endonym(rng, "nonsense")).to_be_truthy()
    local fresh = { id = "x", name = "Xo", generated = false, axes = u[1].axes }
    R.name(42, fresh)
    expect(fresh.endonym).to_be("Xo")
    expect(fresh.exonym).to_be("the Circle-Weight Folk")
  end)

  it("station names are unique in a universe", function()
    local u = civs.universe(42)
    local taken = {}
    for n = 1, 60 do
      local nm = R.station_name(42, u[3], n, taken)
      expect(nm).to_contain(" of ")
    end
    -- a full taken set forces the numbered fallback
    local all = setmetatable({}, { __index = function(_, k) return not k:find("-%d+$") end })
    expect(R.station_name(42, u[3], 1, all)).to_contain("-17")
    expect(R.station_name(42, u[3], 1)).to_contain(" of ")
  end)

  it("writes scanner lore lines", function()
    local seen = {}
    for n = 1, 6 do
      local l = civs.lore(42, 3, n)
      expect(l).to_contain(civs.universe(42)[3].endonym)
      seen[l] = true
    end
    local k = 0
    for _ in pairs(seen) do k = k + 1 end
    expect(k).to_be(3)
    local u = { { endonym = "Zz", fate = "unknown", axes = { values = "faith" } } }
    local h = { civs = { { age = "Long Quiet" } } }
    expect(R.lore(1, u, h, 1, 1)).to_contain("vanished")
    expect(R.lore(1, u, h, 1)).to_contain("Long Quiet")
  end)
end)
