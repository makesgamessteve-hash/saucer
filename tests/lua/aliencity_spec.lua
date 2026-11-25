-- SPDX-License-Identifier: MIT
-- add-alien-cities (plan phase 10, design civs-and-relics §4): civ-shaped cities. Towers in the builders' massing form,
-- ordinary districts by what the builders valued (archive spires, treasury vaults, cathedral organs, brood warrens,
-- fortress terraces, foundry trenches, choir bowls), sky lanes between districts and the city's harmless phenomena
-- (view/cityphen.lua): swarms over the avenues, machines cycling on towers, pulses down the sky lanes.
local civs = require("sim.civs")
local ruinm = require("sim.ruin")
local citygen = require("sim.citygen")
local vec = require("lib.vec")
local phen = require("view.cityphen")

local function gen(id, seed, civ)
  civs.use(42)
  return citygen.generate(seed or 777, ruinm.kit_of(id), civ == nil and civs.get(42, 1) or civ, { 0, 0, 0 })
end
local function copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

describe("alien cities", function()
  it("builds every civ form inside its footprint, the first tier the full footprint", function()
    for form in pairs(citygen.FORMS) do
      for _, sz in ipairs({ { 12, 12, 24 }, { 14, 30, 100 }, { 22, 13, 40 } }) do
        local w, w2, h = sz[1], sz[2], sz[3]
        for _, inv in ipairs({ false, true }) do
          local tl = citygen.tiers(form, w, w2, h, inv)
          expect(#tl >= 3 and #tl <= 6).to_be(true)
          for _, t in ipairs(tl) do
            expect(t.dx >= 0 and t.dz >= 0 and t.dx + t.w <= w and t.dz + t.w2 <= w2).to_be(true)
            expect(t.dy >= -1e-6 and t.dy + t.h <= h + 1e-6).to_be(true)
          end
          if not inv then
            expect(tl[1].w == w and tl[1].w2 == w2 and tl[1].dy == 0).to_be(true)
            expect(tl[1].h >= citygen.base_height(form, h)).to_be(true)
          end
        end
      end
      expect(citygen.BASE_FRAC[form] ~= nil).to_be(true)
    end
  end)

  it("takes the tower form from the builders' massing, else from the old shape", function()
    for massing, form in pairs(citygen.MASSING_FORMS) do
      expect(citygen.style_of({ massing = massing, glyph = 2 }).form).to_be(form)
      expect(citygen.FORMS[form] ~= nil).to_be(true)
    end
    expect(citygen.style_of({ shape = "crystalline" }).form).to_be("spire")
    expect(citygen.style_of(nil).form).to_be("ziggurat")
    expect(citygen.base_height("ziggurat", 100)).to_be(30)
    expect(citygen.base_height("spire", 100)).to_be(42)
  end)

  it("gives ordinary districts the builders' values, landmarks keep theirs", function()
    local own, total = 0, 0
    for _, seed in ipairs({ 777, 42, 7, 1234 }) do
      for _, id in ipairs({ "city_planet", "city_moon", "city_asteroid" }) do
        local civ = civs.get(42, 1 + seed % 6)
        local r = gen(id, seed, civ)
        local value = civ.axes and civ.axes.values or "craft"
        for _, d in ipairs(r.city.districts) do
          if d.value then
            total = total + 1
            if d.value == value then own = own + 1 end
            expect(d.archetype).to_be(citygen.ARCHETYPES[d.value].label)
            expect(d.label).to_be(string.format("D%d %s", d.id, d.archetype))
            expect(d.kind == "market" or d.kind == "residential" or d.kind == "industrial").to_be(true)
          else
            expect(d.archetype).to_be(nil)
          end
        end
      end
    end
    expect(total > 20).to_be(true)
    expect(own / total >= 0.45 and own / total <= 0.85).to_be(true)
    local ds = citygen.archetypes(1, { { id = 1 }, { id = 2, landmark = true } }, "nonsense")
    expect(ds[1].value ~= nil).to_be(true)
    expect(ds[2].value).to_be(nil)
  end)

  it("draws the value's form in its districts and leaves rooms and doors as they were", function()
    local civ = civs.get(42, 1)
    local r = gen("city_planet", 777, civ)
    local forms = {}
    for _, s in ipairs(r.solids) do if s.kind == "tower" and not s.outer then forms[s.form] = true end end
    local base = citygen.style_of(civ).form
    local n = 0
    for f in pairs(forms) do if f ~= base then n = n + 1 end end
    expect(forms[base]).to_be(true)
    expect(n >= 1).to_be(true)
    -- the same city by builders of another massing and value: the same rooms, doors and slots
    local other = copy(civ)
    other.massing = civ.massing == "hive" and "lattice" or "hive"
    other.axes = copy(civ.axes or {})
    other.axes.values = (civ.axes and civ.axes.values) == "faith" and "craft" or "faith"
    local r2 = gen("city_planet", 777, other)
    expect(#r2.rooms).to_be(#r.rooms)
    expect(#r2.doors).to_be(#r.doors)
    expect(#r2.slots).to_be(#r.slots)
    for i = 1, #r.rooms do expect(vec.dist(r.rooms[i].cell, r2.rooms[i].cell)).to_be(0) end
  end)

  it("runs a sky lane between every pair of neighbouring districts, high over the towers", function()
    local r = gen("city_planet", 777)
    local kit = ruinm.kit_of("city_planet")
    local by = {}
    for _, d in ipairs(r.city.districts) do by[d.dz * 1000 + d.dx] = d end
    local want = 0
    for _, d in ipairs(r.city.districts) do
      if by[d.dz * 1000 + d.dx + 1] then want = want + 1 end
      if by[(d.dz + 1) * 1000 + d.dx] then want = want + 1 end
    end
    expect(#r.city.lanes).to_be(want)
    local top = -math.huge
    for _, s in ipairs(r.solids) do if s.kind == "tower" and not s.outer then top = math.max(top, s[2][2]) end end
    for _, l in ipairs(r.city.lanes) do
      expect(l.a[2]).to_be(l.b[2])
      expect(l.a[2] > kit.city.ground * kit.cell).to_be(true)
      expect(l.from ~= l.to).to_be(true)
    end
    expect(r.city.lanes[1].a[2] >= top - kit.cell * 8).to_be(true)
  end)

  it("places swarms, machines and lane pulses, all harmless functions of the clock", function()
    local r = gen("city_planet", 777)
    local list = phen.place(r)
    expect(phen.place(r)).to_be(list)
    local kinds = {}
    for _, ph in ipairs(list) do kinds[ph.kind] = (kinds[ph.kind] or 0) + 1 end
    expect(kinds.swarm).to_be(#r.city.districts)
    expect(kinds.pulse).to_be(#r.city.lanes)
    expect((kinds.machine or 0) >= 1).to_be(true)
    for _, ph in ipairs(list) do
      local eye = ph.pos and vec.add(ph.pos, { 5, 0, 0 }) or ph.a
      for _, t in ipairs({ 0, 3.7, 61.2 }) do
        local a, b = phen.pose(ph, t, eye), phen.pose(ph, t, eye)
        expect(#a > 0).to_be(true)
        for i, o in ipairs(a) do
          expect(vec.dist(o.pos, b[i].pos)).to_be(0)   -- pure
          if ph.kind == "swarm" then expect(vec.dist(o.pos, eye) >= phen.PART - 1e-6).to_be(true) end
          if ph.kind == "pulse" then
            local along = vec.dist(ph.a, o.pos) + vec.dist(o.pos, ph.b)
            expect(math.abs(along - vec.dist(ph.a, ph.b)) < 1e-3).to_be(true)
          end
          if ph.kind == "machine" then expect(vec.dist(o.pos, ph.pos) <= ph.size * 1.5).to_be(true) end
        end
      end
    end
    -- the eye right on a mote: it still parts
    local sw = list[1]
    local first = phen.pose(sw, 0, sw.pos)[1]
    expect(phen.pose(sw, 0, first.pos)[1] ~= nil).to_be(true)
    expect(#phen.pose({ kind = "pulse", a = { 0, 0, 0 }, b = { 0, 0, 0 }, seed = 1 }, 1, { 0, 0, 0 })).to_be(0)
    -- drawing: only what is near the eye
    local drew = { mesh = 0, bb = 0 }
    local v = { mesh = function() drew.mesh = drew.mesh + 1 end, billboard = function() drew.bb = drew.bb + 1 end }
    local A = { tex = { glow = 1 }, pal = { base = 1 } }
    local d1 = r.city.districts[1]
    local n = phen.draw(v, A, r, { pos = { d1.pos[1], d1.pos[2] + 40, d1.pos[3] } }, 2.0)
    expect(n >= 2 and n < #list + 1).to_be(true)
    expect(drew.bb > 0).to_be(true)
    expect(phen.draw(v, A, r, { pos = { 1e6, 0, 1e6 } }, 2.0)).to_be(0)
    local r0 = { seed = 3, solids = {}, city = { districts = {}, lanes = {} } }
    expect(#phen.place(r0)).to_be(0)
    expect(phen.draw(v, A, r0, { pos = { 0, 0, 0 } }, 0)).to_be(0)
  end)
end)
