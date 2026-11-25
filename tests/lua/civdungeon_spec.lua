-- SPDX-License-Identifier: MIT
-- add-civ-dungeons (plan phase 6): each civ's relic is laid out by its massing archetype's room grammar
-- (civs/dungeons.lua) and its body scale; the slice's Vyrr keep the kit's warren.
local civs = require("sim.civs")
local gen = require("sim.relicgen")
local ruinm = require("sim.ruin")
local relic = require("sim.relic")

local ORIGIN = { 0, -4000, 0 }
local function kit() return ruinm.kit_of("relic") end
local function civ_of(massing, scale)
  local base = civs.universe(42)[3]
  return setmetatable({ id = "t_" .. massing .. "_" .. scale, massing = massing,
                        axes = setmetatable({ body_scale = scale }, { __index = base.axes }) }, { __index = base })
end
local function stats(r)
  local max_hall = 0
  for _, id in ipairs(r.relic.halls) do max_hall = math.max(max_hall, r.rooms[id].size[1]) end
  return { rooms = #r.rooms, loops = #r.doors - #r.rooms, levels = r.relic.levels, halls = #r.relic.halls,
           shafts = #r.relic.shafts, chambers = #r.relic.chambers, max_hall = max_hall,
           heart = r.rooms[r.relic.core].size }
end

describe("civ dungeons", function()
  it("keeps the slice's Vyrr on the kit's warren", function()
    local v = relic.civ()
    expect(gen.archetype(v)).to_be(nil)
    expect(gen.styled(kit(), v)).to_be(kit())
    expect(gen.styled(kit(), nil)).to_be(kit())
    local r = gen.generate(42, kit(), v, ORIGIN)
    expect(r.relic.archetype).to_be("warren")
    -- a civ without a language, or with an archetype the grammar does not know, falls back
    expect(gen.archetype({ id = "bare" })).to_be(nil)
    expect(gen.archetype(setmetatable({ massing = "nonsense" }, { __index = civs.universe(42)[3] }))).to_be("cluster")
  end)

  it("lays every archetype out by its own grammar, the heart reachable from the maw", function()
    local S = {}
    for _, m in ipairs({ "organism", "lattice", "shell", "ring", "helix", "hive", "cluster", "spine" }) do
      local r = gen.generate(11, kit(), civ_of(m, "human"), ORIGIN)
      expect(r.relic.archetype).to_be(m)
      local ok = gen.validate(r, gen.styled(kit(), civ_of(m, "human")))
      expect(ok).to_be(true)
      expect(#r.relic.route > 2).to_be(true)
      expect(r.relic.route[#r.relic.route]).to_be(r.relic.core)
      S[m] = stats(r)
    end
    -- measurable differences: the lattice loops most, the organism least; the helix stacks the most levels
    expect(S.lattice.loops > S.organism.loops * 2).to_be(true)
    expect(S.helix.levels > S.ring.levels).to_be(true)
    expect(S.helix.levels >= 5).to_be(true)
    expect(S.hive.halls >= S.cluster.halls).to_be(true)
    expect(S.hive.max_hall <= 18 * 4).to_be(true)
  end)

  it("gives big bodies bigger halls and heart, tiny bodies small halls", function()
    local tiny = stats(gen.generate(5, kit(), civ_of("spine", "tiny"), ORIGIN))
    local giant = stats(gen.generate(5, kit(), civ_of("spine", "giant"), ORIGIN))
    expect(tiny.max_hall <= 18).to_be(true)
    expect(giant.max_hall).to_be(24)
    expect(giant.heart[1] > tiny.heart[1]).to_be(true)
    expect(tiny.heart[1] * 4 >= 128 and tiny.heart[2] * 4 >= 64).to_be(true)
    expect(giant.chambers <= 22).to_be(true)
  end)

  it("is deterministic and memoizes the styled kit", function()
    local c = civ_of("ring", "large")
    local k1, k2 = gen.styled(kit(), c), gen.styled(kit(), c)
    expect(k1).to_be(k2)
    expect(k1.dungeon.mask).to_be("ring")
    expect(k1.dungeon.level_h >= k1.dungeon.hall_h[24] + 6).to_be(true)
    local a = gen.try(3, kit(), c, ORIGIN)
    local b = gen.try(3, kit(), c, ORIGIN)
    if a then expect(a.hash).to_be(b.hash) end
    expect(gen.generate(3, kit(), c, ORIGIN).hash).to_be(gen.generate(3, kit(), c, ORIGIN).hash)
  end)
end)
