-- add-alien-stations: the alien wing of a station's walkable inside (sim/stationgen.lua), its view
-- (view/station.lua) and its lamps (view/lights.lua)
local sg = require("sim.stationgen")
local sh = require("sim.stationhull")
local vstation = require("view.station")
local lv = require("view.lights")

local FAMS = { "coral", "crystal", "spiral", "shells" }

local function wing_areas(L)
  local out = {}
  for _, a in ipairs(L.areas) do if a.wing then out[#out + 1] = a end end
  return out
end

local function fake_view()
  local v = { lights = {} }
  function v:light(l) self.lights[#self.lights + 1] = l end
  return v
end

describe("the alien wing", function()
  it("grows chambers and passages off the market, every look, named by the family", function()
    local looks, n = {}, 0
    for s = 1, 24 do
      local fam = FAMS[s % 4 + 1]
      local L = sg.generate(saucer.seed_child(7, "station", s), fam)
      expect(L.family).to_be(fam)
      local W = sg.kit().walk.alien
      expect(L.wing >= 4 and L.wing <= W.chambers[2]).to_be(true)
      local chambers = 0
      for _, a in ipairs(wing_areas(L)) do
        if a.kind == "chamber" then
          chambers = chambers + 1
          looks[a.alien] = true
          expect(a.name).to_be(W.names[fam][a.alien])
          if a.alien == "shaft" then expect(a.h >= W.shaft_h[1]).to_be(true) end
        else
          expect(a.kind).to_be("corridor")
          expect(a.alien).to_be("passage")
          expect(a.name).to_be(W.names[fam].passage)
        end
      end
      expect(chambers).to_be(L.wing)
      n = n + #L.areas
    end
    for _, lk in ipairs(sg.LOOKS) do expect(looks[lk]).to_be(true) end
    expect(n / 24 > 13).to_be(true)
  end)

  it("never overlaps another area, and every chamber is reached on foot with clear links", function()
    for s = 1, 30 do
      local L = sg.generate(saucer.seed_child(42, "station", s))
      for i, a in ipairs(L.areas) do
        for j = i + 1, #L.areas do
          local b = L.areas[j]
          local o = a.box[1] < b.box[3] - 0.01 and a.box[3] > b.box[1] + 0.01 and a.box[2] < b.box[4] - 0.01 and a.box[4] > b.box[2] + 0.01
          expect(o).to_be(false)
        end
      end
      local start = sg.center(L.areas[1])
      for _, a in ipairs(wing_areas(L)) do
        if a.kind == "chamber" then
          local c = sg.center(a)
          local path = sg.route(L, start, c)
          expect(#path > 0).to_be(true)
          local last = path[#path]
          expect(math.abs(last[1] - c[1]) < 0.01 and math.abs(last[2] - c[2]) < 0.01).to_be(true)
          local here = start
          for _, q in ipairs(path) do
            expect(sg.clear(L, here, q)).to_be(true)
            here = q
          end
        end
      end
      for _, l in ipairs(L.nav.links) do
        expect(sg.clear(L, L.nav.nodes[l[1]], L.nav.nodes[l[2]])).to_be(true)
      end
    end
  end)

  it("leaves the concourse, the market, the bar and the hangars as they were", function()
    -- these hashes are of the layouts before the wing existed (the main branch's sim/stationgen.lua)
    local want = { "435c6773a1eefc8d", "568e7c2379421538", "efc9d8392617fd42", "9cb23e41553a7028", "2422e0e3eb2718fc", "389e20c9c1e479e1" }
    for s = 1, 6 do
      local L = sg.generate(saucer.seed_child(42, "station", s))
      local parts = {}
      for _, a in ipairs(L.areas) do
        if not a.wing then local b = a.box parts[#parts + 1] = string.format("%s:%.1f,%.1f,%.1f,%.1f", a.kind, b[1], b[2], b[3], b[4]) end
      end
      for _, st in ipairs(L.stalls) do parts[#parts + 1] = string.format("%s:%.2f,%.2f", st.vendor, st.spot[1], st.spot[2]) end
      parts[#parts + 1] = string.format("bar:%.2f,%.2f thief:%.2f,%.2f", L.bar.spot[1], L.bar.spot[2], L.thief.home[1], L.thief.home[2])
      expect(string.format("%016x", saucer.hash64(table.concat(parts, ";"), 1))).to_be(want[s])
    end
  end)

  it("keeps the routes in a chamber clear of its furniture", function()
    local L = sg.generate(saucer.seed_child(42, "station", 2))
    for _, a in ipairs(wing_areas(L)) do
      if a.kind == "chamber" then
        expect(sg.off_paths(L, a, a.box[1] - 5, a.box[2], 0.5)).to_be(false)
        expect(sg.off_paths(L, a, sg.center(a)[1], sg.center(a)[2], 0.5)).to_be(false)
      end
    end
  end)

  it("is the same for the same seed, and cached by seed and family", function()
    local s = saucer.seed_child(9, "station", 1)
    expect(sg.hash(sg.generate(s, "coral"))).to_be(sg.hash(sg.generate(s, "coral")))
    expect(sg.get(s, "coral")).to_be(sg.get(s, "coral"))
    expect(sg.get(s, "crystal") ~= sg.get(s, "coral")).to_be(true)
    expect(sg.get(s).family).to_be(sh.family_of(s))
    -- the home sector's walk-in seeds are the old ones; other sectors' differ
    expect(sg.seed_of(42, 1, 3)).to_be(saucer.seed_child(42, "station", 3))
    expect(sg.seed_of(42, 2, 3) ~= sg.seed_of(42, 1, 3)).to_be(true)
  end)
end)

describe("the alien wing's look", function()
  it("builds every family's chambers, props and growths into the station meshes", function()
    for i, fam in ipairs(FAMS) do
      for s = 1, 2 do
        local L = sg.generate(saucer.seed_child(11 + i, "station", s), fam)
        local c = vstation.colors(L)
        expect(#c.wall).to_be(3)
        local out = {}
        vstation.alien_parts(L, out)
        expect(#out > 100).to_be(true)
        local m = vstation.meshes(L)
        expect(m.ndetail > #out).to_be(true)
        expect(saucer.mesh.info(m.detail).triangles > 0).to_be(true)
      end
    end
    -- a layout without a family (an old save's) still gets colours
    expect(#vstation.colors({ family = "teapot" }).glow).to_be(3)
  end)

  it("lights the wing in its family's colours, up the shafts too", function()
    local L, shaft
    for s = 1, 40 do
      L = sg.generate(saucer.seed_child(5, "station", s), "spiral")
      for _, a in ipairs(L.areas) do if a.alien == "shaft" then shaft = a end end
      if shaft then break end
    end
    expect(shaft).to_be_truthy()
    local c = sg.center(shaft)
    local v = fake_view()
    local n = lv.station_lamps(v, L, { c[1], 2, c[2] })
    expect(n > 0).to_be(true)
    local fam = sh.family("spiral").lamps
    local high, famc = 0, 0
    for _, l in ipairs(v.lights) do
      if l.pos[2] > 15 then high = high + 1 end
      for _, fc in ipairs(fam) do if fc == l.color then famc = famc + 1 end end
    end
    expect(high >= 2).to_be(true)
    expect(famc > 0).to_be(true)
    expect(lv.station_family_lamps({ family = "teapot" })).to_be(lv.PALETTES.alien)
  end)
end)
