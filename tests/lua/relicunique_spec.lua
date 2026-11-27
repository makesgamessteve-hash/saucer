-- SPDX-License-Identifier: MIT
-- relic-room-shapes: no two relics of one species alike. The metric (sim/relicsig.lua: 1 - IoU of the top-down room
-- plans, the heart left out, minimised over turns and mirrors), the guarantee in play (sim/sector.lua siblings ->
-- sim/relicgen.lua generate) over every relic of many universes, and a run of stations of each species kept unlike
-- each other. tools/relicunique/ runs the same at a few hundred stations per species.
local civs = require("sim.civs")
local gen = require("sim.relicgen")
local ruinm = require("sim.ruin")
local sector = require("sim.sector")
local galaxy = require("sim.galaxy")
local sig = require("sim.relicsig")

local KIT = ruinm.kit_of("relic")
local O = { 0, 0, 0 }
local MASSINGS = { "organism", "lattice", "shell", "ring", "helix", "hive", "cluster", "spine" }
local function civ_of(m) return setmetatable({ id = "uniq_" .. m, massing = m }, { __index = civs.universe(42)[3] }) end
local function fake(cells)
  local set, n = {}, 0
  for _, c in ipairs(cells) do
    set[c[2] * sig.N + c[1]] = true
    n = n + 1
  end
  return { sig = { set = set, n = n } }
end

describe("relic uniqueness", function()
  it("measures alike up to a turn or a mirror, and apart when nothing overlaps", function()
    local h = sig.N // 2
    local L = fake({ { h, h }, { h + 1, h }, { h + 2, h }, { h, h + 1 } })
    local turned = fake({ { h, h }, { h, h + 1 }, { h, h + 2 }, { h - 1, h } })   -- a quarter turn
    local mirrored = fake({ { h, h }, { h - 1, h }, { h - 2, h }, { h, h + 1 } })
    local far = fake({ { 3, 3 }, { 4, 3 } })
    expect(sig.distance(L, L)).to_be(0)
    expect(sig.distance(L, turned)).to_be(0)
    expect(sig.distance(L, mirrored)).to_be(0)
    expect(sig.distance(L, far)).to_be(1)
    expect(sig.distance(fake({}), fake({}))).to_be(0)
    expect(sig.bound(L, far)).to_be(0.5)
    expect(sig.bound(fake({}), fake({}))).to_be(0)
    -- off the edge after a turn: that pixel only counts against
    expect(sig.distance(fake({ { 0, 1 } }), fake({ { 0, 1 } }))).to_be(0)
    local d, i, j = sig.min_pairwise({ L, far, turned })
    expect(d).to_be(0)
    expect(i).to_be(1)
    expect(j).to_be(3)
    expect(sig.min_pairwise({ L })).to_be(1)
    -- a real relic: the heart is left out, the signature cached
    local r = gen.generate(42, KIT, civ_of("ring"), O)
    local s = sig.signature(r)
    expect(sig.signature(r)).to_be(s)
    expect(s.n > 100).to_be(true)
  end)

  it("a relic drawn against its own copy is drawn again, unlike it; no siblings leaves it as it is", function()
    local civ = civ_of("cluster")
    local plain = gen.generate(77, KIT, civ, O)
    expect(gen.generate(77, KIT, civ, O, {})).to_be(plain)
    local again = gen.generate(77, KIT, civ, O, { 77 })
    expect(again ~= plain).to_be(true)
    expect(sig.distance(again, plain) >= sig.MIN_DIST).to_be(true)
    expect(gen.generate(77, KIT, civ, O, { 77 })).to_be(again)   -- memoized
    -- the warren is never redrawn
    local vyrr = require("sim.relic").civ()
    expect(gen.generate(42, KIT, vyrr, O, { 42 })).to_be(gen.generate(42, KIT, vyrr, O))
    -- out of tries: the most distinct draw stands
    local keep = gen.UNIQUE_TRIES
    gen.UNIQUE_TRIES = 1
    local r, d, a = gen.unlike(77, KIT, civ, O, { plain })
    gen.UNIQUE_TRIES = keep
    expect(r.hash).to_be(plain.hash)
    expect(d).to_be(0)
    expect(a).to_be(0)
  end)

  it("every relic in play is unlike every other relic of its species, in many universes", function()
    local pairs_seen = 0
    for _, seed in ipairs({ 42, 7, 1234, 99, 5, 2024, 11, 77, 300, 4096, 31337, 8 }) do
      civs.use(seed)
      local g = galaxy.generate(seed)
      local by = {}
      for sid = 1, #g.sectors do
        local ci = sector.relic_of(seed, sid, g.sectors[sid])
        if ci then
          by[ci] = by[ci] or {}
          local sib = sector.relic_siblings(seed, sid, ci)
          expect(#sib).to_be(#by[ci])
          local civ = civs.get(seed, ci)
          by[ci][#by[ci] + 1] = gen.generate(saucer.seed_child(seed, "relic_site", sid), KIT, civ, O, sib)
        end
      end
      for _, list in pairs(by) do
        if #list > 1 then
          pairs_seen = pairs_seen + 1
          expect(sig.min_pairwise(list) >= sig.MIN_DIST).to_be(true)
        end
      end
    end
    expect(pairs_seen >= 1).to_be(true)
    civs.use(42)
  end)

  it("a run of stations of each species: all unlike each other", function()
    for _, m in ipairs(MASSINGS) do
      local civ = civ_of(m)
      local before = {}
      for s = 1, 8 do
        local r = gen.unlike(saucer.seed_child(4242, m, s), KIT, civ, O, before)
        before[#before + 1] = { sig = sig.signature(r) }
      end
      local d = sig.min_pairwise(before)
      if d < sig.MIN_DIST then error(string.format("%s: two stations only %.3f apart", m, d)) end
    end
  end)

  it("the fold spool draws the sector ahead a relic a tick, and the jump's tick finds it drawn", function()
    local game = require("sim.game")
    local function count(f)
      local n = 0
      debug.sethook(function() n = n + 1 end, "", 1000)
      f()
      debug.sethook()
      return n * 1000
    end
    -- seed 16, sector 6: a relic with an earlier relic of its species (drawn first), and more than one draw in all
    local seed, sid = 16, 6
    civs.use(seed)
    local info = galaxy.generate(seed).sectors[sid]
    local site
    for _, s in ipairs(sector.generate(seed, sid, info).sites) do
      if s.relic then site = s end
    end
    expect(#site.siblings).to_be(1)
    local st = { seed = seed, jump = { to = sid, spool = -1 } }
    local dt = 1 / 60
    game.warm_jump(st, dt)                 -- not spooling yet: nothing
    st.jump.spool = dt / 2
    game.warm_jump(st, dt)                 -- the jump's own tick: nothing
    st.jump = false
    game.warm_jump(st, dt)
    st.jump = { to = sid, spool = 3 }
    local ticks, worst = 0, 0
    for _ = 1, 60 do
      worst = math.max(worst, count(function() game.warm_jump(st, dt) end))
      ticks = ticks + 1
      st.jump.spool = st.jump.spool - dt
    end
    expect(worst < 15000000).to_be(true)   -- one draw a tick: well inside a tick's 20M instructions
    local civ = game.civ_of(site)
    local r
    local cost = count(function() r = ruinm.generate(site.seed, site.kit, civ, site.pos, nil, site.first, site.siblings) end)
    expect(cost < 100000).to_be(true)      -- drawn ahead: the jump only looks it up
    expect(gen.warm(site.seed, KIT, civ, site.pos, site.siblings)).to_be(true)
    expect(sig.distance(r, gen.generate(site.siblings[1], KIT, civ, gen.ORIGIN0)) >= sig.MIN_DIST).to_be(true)
    -- a fresh relic with a sibling takes more than one warm() (one draw each), then stands as generate() draws it
    local calls = 0
    while not gen.warm(9191, KIT, civ, O, { 9192 }) do calls = calls + 1 end
    expect(calls >= 1).to_be(true)
    expect(gen.warm(9191, KIT, civ, O, { 9192 })).to_be(true)
    -- an error that is not warm()'s own yield goes through
    expect(pcall(gen.warm, 1, { id = "nokit" }, civ, O, nil)).to_be(false)
    -- distances are kept per pair
    local a, b = gen.generate(9191, KIT, civ, O, { 9192 }), gen.generate(9192, KIT, civ, gen.ORIGIN0, {})
    expect(sig.distance(a, b)).to_be(sig.distance_raw(a, b))
    expect(sig.distance(a, b)).to_be(sig.distance(a, b))
    civs.use(42)
  end)
end)
