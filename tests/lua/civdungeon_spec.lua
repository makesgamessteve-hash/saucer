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

describe("heart machines", function()
  local relicv = require("view.relic")
  it("turn three tilted hoops for the Vyrr and the civ's own machine for others", function()
    local v = relicv.machine(relic.civ())
    expect(v.hoops).to_be(3)
    expect(v.speed).to_be(1)
    expect(v.stack).to_be(false)
    expect(relicv.machine(nil).hoops).to_be(3)
    local seen = {}
    for s = 1, 30 do
      for i = 3, #civs.universe(s) do
        local c = civs.universe(s)[i]
        local m = relicv.machine(c)
        expect(m.hoops >= 2 and m.hoops <= relicv.MAX_HOOPS).to_be(true)
        if c.language.symmetry.mode == "radial" then expect(m.hoops).to_be(c.language.symmetry.n) end
        expect(m.stack).to_be(c.massing == "spine" or c.massing == "helix")
        expect(m.glow).to_be(c.language.lamp_colors[1])
        seen[m.hoops] = true
      end
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    expect(n >= 3).to_be(true)
  end)

  it("draws the machine's hoops about the spindle (stacked for spines and helices)", function()
    local r = gen.generate(42, kit(), relic.civ(), ORIGIN)
    local calls = {}
    local fake = { mesh = function(_, _, o) calls[#calls + 1] = o end, billboard = function() end }
    local A = { tex = { glow = 1 } }
    expect(relicv.engine(fake, A, r, 10, {})).to_be(true)
    expect(#calls).to_be(3)
    local c = setmetatable({ id = "stacker", massing = "spine" }, { __index = civs.universe(42)[3] })
    relicv.set_style(c)
    calls = {}
    relicv.engine(fake, A, r, 10, {})
    relicv.set_style(nil)
    local m = relicv.machine(c)
    expect(#calls).to_be(m.hoops)
    for _, o in ipairs(calls) do expect(o.pitch).to_be(0) end
    expect(relicv.engine(fake, A, { solids = {} }, 1, {})).to_be(false)
  end)
end)

describe("hall landmarks", function()
  local lmk = require("view.landmarks")
  local function inside(r, lm)
    local mn, mx = ruinm.room_box(r.rooms[lm.room], kit(), r.origin)
    local reach = lmk.REACH * lm.size
    for k = 1, 3, 2 do
      if lm.pos[k] - reach < mn[k] + lmk.CLEAR or lm.pos[k] + reach > mx[k] - lmk.CLEAR then return false end
    end
    return lm.pos[2] - reach > mn[2] + kit().wall + lmk.CLEAR and lm.pos[2] + reach < mx[2] - 8
  end

  it("hangs one in every big hall of every archetype, clear of the walls, floor and ceiling lamp", function()
    local kinds = {}
    for _, m in ipairs({ "organism", "lattice", "shell", "ring", "helix", "hive", "cluster", "spine", "warren" }) do
      for _, sc in ipairs({ "micro", "human", "titan" }) do
        local c = m == "warren" and relic.civ() or civ_of(m, sc)
        local r = gen.generate(7, kit(), c, ORIGIN)
        local list = lmk.place(r, c)
        expect(#list >= 1).to_be(true)
        local seen = {}
        for _, lm in ipairs(list) do
          expect(r.rooms[lm.room].kind).to_be("hall")
          expect(seen[lm.room]).to_be(nil)
          seen[lm.room] = true
          expect(inside(r, lm)).to_be(true)
          kinds[lm.kind] = true
          -- every part stays in its ball at any time
          for _, t in ipairs({ 0, 3.7, 50, 1234.5 }) do
            for _, o in ipairs(lmk.pose(lm, t)) do
              local d = math.sqrt((o.pos[1] - lm.pos[1]) ^ 2 + (o.pos[2] - lm.pos[2]) ^ 2 + (o.pos[3] - lm.pos[3]) ^ 2)
              expect(d + o.size * 0.5 <= lmk.REACH * lm.size + 1e-6 or o.mesh == "shard" or o.mesh == "vase").to_be(true)
            end
          end
        end
        -- deterministic, and placing changes nothing in the ruin
        expect(#lmk.place(r, c)).to_be(#list)
        expect(r.landmarks).to_be(nil)
      end
    end
    local n = 0
    for _ in pairs(kinds) do n = n + 1 end
    expect(n >= 3).to_be(true)
  end)

  it("picks the kind from the civ's primitives and poses each kind", function()
    expect(lmk.kind({ language = { primitives = { torus = 1 } } }, 5)).to_be("halo")
    expect(lmk.kind({ language = { primitives = { shard = 1, blob = 0 } } }, 9)).to_be("bloom")
    expect(lmk.kind({ language = { primitives = { nothing = 2 } } }, 1)).to_be(lmk.KINDS[2])
    expect(lmk.kind(nil, 0)).to_be(lmk.KINDS[1])
    for _, k in ipairs(lmk.KINDS) do
      local a = lmk.pose({ pos = { 0, 0, 0 }, size = 4, seed = 3, kind = k }, 0)
      local b = lmk.pose({ pos = { 0, 0, 0 }, size = 4, seed = 3, kind = k }, 10)
      expect(#a >= 3).to_be(true)
      local moved = false
      for i = 1, #a do
        if a[i].pos[2] ~= b[i].pos[2] or a[i].pos[1] ~= b[i].pos[1] or a[i].yaw ~= b[i].yaw or a[i].roll ~= b[i].roll then
          moved = true
        end
      end
      expect(moved).to_be(true)
    end
  end)

  it("draws the landmarks of the halls shown (in the civ's materials)", function()
    local c = civs.universe(42)[3]
    local r = gen.generate(42, kit(), c, ORIGIN)
    local list = lmk.place(r, c)
    local calls = 0
    local fake = { mesh = function(_, m, o) expect(m ~= nil).to_be(true) expect(o.scale > 0).to_be(true) calls = calls + 1 end }
    expect(lmk.draw(fake, r, c, {}, 1, {})).to_be(0)
    expect(lmk.draw(fake, r, c, { [list[1].room] = 0 }, 1, {})).to_be(1)
    expect(calls).to_be(#lmk.pose(list[1], 1))
    expect(lmk.draw(fake, r, nil, { [list[1].room] = 0 }, 1, {})).to_be(1)
    lmk.forget()
  end)
end)
