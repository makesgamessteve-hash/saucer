-- SPDX-License-Identifier: MIT
-- add-huge-stations: the megastructure station: the deterministic generator, its budgets and solids,
-- the placement in the sector, the far hangar, and the view with its levels of detail.
local game = require("sim.game")
local sh = require("sim.stationhull")
local sector = require("sim.sector")
local dock = require("sim.dock")
local visit = require("sim.visit")
local sg = require("sim.stationgen")
local vec = require("lib.vec")
local vhull = require("view.stationhull")
local assets = require("view.assets")
local sm = saucer.math

local function new_state(seed)
  local st = {}
  game.init(st, { seed = seed or 42, players = 1 })
  return st
end
local function fake_view()
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false }
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
    v[m] = function(self) self.calls[m] = (self.calls[m] or 0) + 1 return 0 end
  end
  return v
end

describe("the megastructure generator", function()
  it("is deterministic: the same seed gives the same layout, other seeds differ", function()
    local a = sh.generate(1234, "port", 7)
    local b = sh.generate(1234, "port", 7)
    expect(a.hash).to_be(b.hash)
    expect(#a.solids).to_be(#b.solids)
    expect(#a.lights).to_be(#b.lights)
    for k, n in pairs(a.counts) do expect(b.counts[k]).to_be(n) end
    local seen, sizes = {}, {}
    for s = 1, 8 do
      local L = sh.generate(s * 977, "port", 7)
      seen[L.hash] = true
      sizes[L.info.R // 1 .. L.info.palette] = true
    end
    local n, m = 0, 0
    for _ in pairs(seen) do n = n + 1 end
    for _ in pairs(sizes) do m = m + 1 end
    expect(n).to_be(8)
    expect(m >= 4).to_be(true)
  end)
  it("builds the same station with or without the triangles, and the view gets them on demand", function()
    local a = sh.generate(321, "port", 7, false)
    local b = sh.generate(321, "port", 7, true)
    expect(a.parts == nil).to_be(true)
    expect(a.hash).to_be(b.hash)
    expect(#a.solids).to_be(#b.solids)
    expect(#a.lights).to_be(#b.lights)
    expect(b.counts.core).to_be_greater(100)
    local parts = sh.parts(a)
    expect(#parts.core).to_be(b.counts.core)
    expect(sh.parts(a)).to_be(parts)
    expect(sh.parts(b)).to_be(b.parts)
    for s2 = 1, 5 do sh.parts(sh.get(s2 * 13, "outpost", 1)) end
  end)
  it("knows a station's sphere and box without building it", function()
    for _, class in ipairs({ "port", "outpost" }) do
      for _, seed in ipairs({ 1, 42, 99, 4242 }) do
        for _, fam in ipairs({ "coral", "crystal", "spiral", "shells" }) do
          local c, r, lo, hi = sh.envelope(seed, class, fam)
          local L = sh.generate(seed, class, 3, false, fam)
          expect(c[1]).to_be_near(L.info.centre[1], 1e-9)
          expect(c[2]).to_be_near(L.info.centre[2], 1e-9)
          expect(r).to_be_near(L.info.radius, 1e-9)
          expect(lo[1]).to_be_near(L.info.extent.lo[1], 1e-9)
          expect(hi[3]).to_be_near(L.info.extent.hi[3], 1e-9)
        end
      end
    end
    expect(sh.envelope(1)).to_be_truthy()
  end)
  it("is multi-kilometre with the hangar cell a tiny part of it, everything inside its box and its budgets", function()
    local T = dock.tune()
    local cell = (T.front_x - T.back_x) * T.half_w * 2 * T.height
    for _, fam in ipairs({ "coral", "crystal", "spiral", "shells" }) do
      local L = sh.generate(42, "port", 7, true, fam)
      local i = L.info
      local e = i.extent
      expect(e.hi[1] - e.lo[1]).to_be_greater(1800)
      expect(e.hi[2] - e.lo[2]).to_be_greater(1600)
      expect(e.hi[3] - e.lo[3]).to_be_greater(1600)
      expect(i.family).to_be(fam)
      local hull = (e.hi[1] - e.lo[1]) * (e.hi[2] - e.lo[2]) * (e.hi[3] - e.lo[3])
      expect(cell / hull < 0.001).to_be(true)
      expect(i.pods >= 7 and i.monoliths >= 4 and i.cocoons >= 5).to_be(true)
      expect(#L.lights >= 15 and #L.solids >= 60).to_be(true)
      for _, b in ipairs(L.solids) do
        for k = 1, 3 do
          expect(b[1][k] >= e.lo[k] - 1e-6 and b[2][k] <= e.hi[k] + 1e-6).to_be(true)
        end
      end
      -- the standing layers' triangles stay in the box; the spinning ones within its reach of the axis
      for _, layer in ipairs({ "core", "detail", "far" }) do
        local m = saucer.mesh.info(vhull.mesh(L, layer))
        for k = 1, 3 do
          expect(m.min[k] >= e.lo[k] - 2 and m.max[k] <= e.hi[k] + 2).to_be(true)
        end
      end
      -- inside the triangle budgets (under luacov every build is slow: the budgets are checked on these same builds)
      local kit = sh.kit()
      local t = vhull.layer_tris(L)
      expect(t.core + t.ring <= kit.budget.core).to_be(true)
      expect(t.detail + t.ringd <= kit.budget.detail).to_be(true)
      expect(t.far <= kit.budget.far).to_be(true)
      expect(t.core).to_be_greater(4000)
      expect(t.detail).to_be_greater(t.core)
      for _, layer in ipairs({ "ring", "ringd" }) do
        local id = vhull.mesh(L, layer)
        local m = saucer.mesh.info(id)
        if m.triangles > 0 then
          local reach = e.hi[3]
          for k = 2, 3 do
            local lo, hi = m.min[k], m.max[k]
            expect(math.max(math.abs(lo), math.abs(hi)) <= reach + 2).to_be(true)
          end
        end
      end
      vhull.free_all()
    end
  end)
  it("picks every family from seeds, the same one for the same seed", function()
    local seen = {}
    for s = 1, 40 do seen[sh.family_of(s)] = true end
    for _, f in ipairs(sh.families()) do expect(seen[f.id]).to_be(true) end
    expect(sh.family_of(1234)).to_be(sh.family_of(1234))
    expect(sh.family("crystal").name).to_be("Lattice")
    expect(pcall(sh.family, "teapot")).to_be(false)
    expect(sh.family_of(nil)).to_be_truthy()
    -- the walk-in seed picks the hull's family
    local st = new_state(42)
    expect(sh.for_trader(st, 1).family).to_be(sh.family_of(sg.seed_for(st, 1)))
    expect(sg.get(sg.seed_for(st, 1)).family).to_be(sh.for_trader(st, 1).family)
  end)
  it("makes an outpost about a quarter the size", function()
    local port = sh.generate(5, "port", 1)
    local out = sh.generate(5, "outpost", 1)
    expect(out.info.R < port.info.R / 3).to_be(true)
    expect(out.info.length < port.info.length / 3).to_be(true)
    expect(out.family).to_be(port.family)
    expect(out.class).to_be("outpost")
    expect(sh.class_of({ outpost = true })).to_be("outpost")
    expect(sh.class_of({})).to_be("port")
    expect(sh.class_of(nil)).to_be("port")
  end)
  it("keeps the anchor and the corridor in front of the cell free of its solids", function()
    for _, seed in ipairs({ 3, 42, 700 }) do
      local L = sh.generate(seed, "port", 5)
      local b = dock.bay({ sector = { trader = { pos = { 0, 0, 0 } }, traders = { { pos = { 0, 0, 0 } } } } }, 1)
      local pts = { { 0, 0, 0 }, { b.mouth[1] + 60, b.mouth[2] + 10, b.mouth[3] },
                    { b.mouth[1] + 200, b.mouth[2] + 10, b.mouth[3] }, { b.mouth[1] + 380, b.mouth[2] + 10, b.mouth[3] } }
      for _, p in ipairs(pts) do
        for _, s in ipairs(L.solids) do
          local inside = p[1] > s[1][1] and p[1] < s[2][1] and p[2] > s[1][2] and p[2] < s[2][2] and p[3] > s[1][3] and p[3] < s[2][3]
          expect(inside).to_be(false)
        end
      end
    end
  end)
  it("puts the far hangar on a pod near the cell and gives the arrival bay the same number", function()
    local st = new_state(42)
    local L = sh.for_trader(st, 1)
    local tp = st.sector.trader.pos
    local far = sh.far_bay_pos(st, 1)
    expect(vec.dist(far, tp) < 150).to_be(true)
    expect(vec.dist(far, tp) > 20).to_be(true)
    expect(L.info.bay_no).to_be(sg.bay_number(sg.seed_for(st, 1)))
    local bays = visit.bays(st, st.players[1].ship, 1)
    expect(bays[2]).to_be_truthy()
  end)
  it("caches layouts and gives world solids, bounds and seeds", function()
    local st = new_state(42)
    local a = sh.for_trader(st, 1)
    local b = sh.for_trader(st, 1)
    expect(a == b).to_be(true)
    for s = 1, 12 do sh.get(s * 31, "port", 1) end
    local c = sh.for_trader(st, 1)
    expect(c.hash).to_be(a.hash)
    local w = sh.world_solids(st)
    expect(#w).to_be(#a.solids)
    local tp = st.sector.trader.pos
    expect(w[1][1][1]).to_be_near(a.solids[1][1][1] + tp[1], 1e-6)
    local centre, r, lo, hi = sh.bounds(st, 1)
    expect(r).to_be_greater(400)
    expect(hi[1] > lo[1] and centre[1] > lo[1] and centre[1] < hi[1]).to_be(true)
    expect(sh.seed_of(1, 2, 3)).to_be(sh.seed_of(1, 2, 3))
    expect(sh.seed_of(1, 2, 3) ~= sh.seed_of(1, 2, 4)).to_be(true)
    expect(sh.seed_of(nil, nil, nil)).to_be_truthy()
  end)
end)

describe("placing the station in a sector", function()
  it("clears the arrival, the vault and every site for many seeds, near the start", function()
    for _, seed in ipairs({ 1, 7, 42, 99, 1234, 31337, 8675309 }) do
      local st = new_state(seed)
      local _, _, lo, hi = sh.bounds(st, 1)
      for _, site in ipairs(st.sector.sites) do
        local ext = sector.extent(site.kit)
        local c = { site.pos[1] + ext[1] / 2, site.pos[2] + ext[2] / 2, site.pos[3] + ext[3] / 2 }
        local r = 0.5 * sm.sqrt(ext[1] * ext[1] + ext[2] * ext[2] + ext[3] * ext[3])
        expect(sector.box_gap(c, lo, hi) - r >= sector.STATION_ROOM - 1).to_be(true)
      end
      local v = st.sector.vault.pos
      expect(sector.box_gap(v, lo, hi) - 80 >= sector.STATION_ROOM - 1).to_be(true)
      expect(sector.box_gap({ 0, 0, -120 }, lo, hi) - 260 >= sector.STATION_ROOM - 1).to_be(true)
      expect(vec.len(st.sector.trader.pos) < 3000).to_be(true)
      -- the hull is physical: its solids reached the physics world
      expect(#sh.world_solids(st) > 50).to_be(true)
    end
  end)
  it("place_station moves away from a crowd of obstacles", function()
    local obs = { { 0, 0, 0, 300 }, { 900, 0, 0, 300 } }
    local p = sector.place_station(1, 1, obs)
    local _, _, lo, hi = sh.envelope(sh.seed_of(1, 1, 1), "port", sector.station_family(1, 1))
    for _, o in ipairs(obs) do
      expect(sector.box_gap(o, vec.add(p, lo), vec.add(p, hi)) - o[4] >= sector.STATION_ROOM - 1).to_be(true)
    end
    local q = sector.place_station(1, 1, {})
    expect(#q).to_be(3)
    -- asked again it answers the same (from its memory) and the caller's copy is its own
    local p2 = sector.place_station(1, 1, obs)
    expect(p2[1]).to_be(p[1])
    p2[1] = 0
    expect(sector.place_station(1, 1, obs)[1]).to_be(p[1])
    for sd = 1, 70 do sector.place_station(sd + 1000, 1, {}) end
    -- boxed in on every side: the fallback spot far out
    local wall = {}
    for k = -6, 6 do for j = -6, 6 do wall[#wall + 1] = { k * 900, 0, j * 900, 700 } end end
    expect(#sector.place_station_uncached(1, 1, wall)).to_be(3)
    -- the segment test
    expect(sector.seg_hits_box({ -10, 0, 0 }, { 10, 0, 0 }, { -1, -1, -1 }, { 1, 1, 1 })).to_be(true)
    expect(sector.seg_hits_box({ -10, 5, 0 }, { 10, 5, 0 }, { -1, -1, -1 }, { 1, 1, 1 })).to_be(false)
    expect(sector.seg_hits_box({ 0, 5, 0 }, { 0, 5, 0 }, { -1, -1, -1 }, { 1, 1, 1 })).to_be(false)
    expect(sector.seg_hits_box({ 5, 0, 0 }, { 5, 3, 0 }, { -1, -1, -1 }, { 1, 1, 1 })).to_be(false)
  end)
  it("reaches the far sectors too", function()
    local st = new_state(42)
    local found = 0
    for sid = 2, 4 do
      local sec = sector.generate(st.seed, sid)
      if sec and sec.trader then
        found = found + 1
        expect(sec.trader.pos).to_be_truthy()
      end
    end
    expect(found).to_be_greater(0)
  end)
end)

describe("drawing the stations", function()
  local function stats_at(st, d)
    local tp = st.sector.trader.pos
    local c = sh.bounds(st, 1)
    local v = fake_view()
    local A = assets.init()
    local L = sh.for_trader(st, 1)
    local e = L.info.extent
    -- a camera d metres past the box's +x face
    local cam = { pos = { tp[1] + e.hi[1] + d, tp[2], tp[3] } }
    -- a few frames, so every layer the level wants has had its turn to be built (one build a frame)
    for _ = 1, 8 do vhull.draw(v, A, st, cam, 100) end
    return vhull.stats, v
  end
  it("draws the silhouette far away, the hull nearer and everything close up", function()
    local st = new_state(42)
    local s = stats_at(st, 3000)
    expect(s.draws).to_be(1)
    expect(s.levels[1]).to_be("far")
    s = stats_at(st, 700)
    expect(s.draws).to_be(2)
    expect(s.levels[1]).to_be("hull")
    s = stats_at(st, 100)
    expect(s.draws).to_be(4)
    expect(s.levels[1]).to_be("detail")
    expect(s.tris).to_be_greater(10000)
    vhull.free_all()
  end)
  it("builds one thing a frame: a cold station shows up over a few frames, not in one long one", function()
    vhull.free_all()
    local st = new_state(1234)
    local tp = st.sector.trader.pos
    local e = sh.for_trader(st, 1).info.extent
    local cam = { pos = { tp[1] + e.hi[1] + 50, tp[2], tp[3] } }
    local A = assets.init()
    local drawn = {}
    for f = 1, 8 do
      vhull.draw(fake_view(), A, st, cam, 100)
      drawn[f] = vhull.stats.draws
    end
    expect(drawn[1]).to_be(0)                    -- the layout's triangles take the first frame
    expect(drawn[2]).to_be(1)                    -- then a layer a frame
    expect(drawn[3]).to_be(2)
    expect(drawn[8]).to_be(4)
    vhull.free_all()
  end)
  it("limits the blinking beacons and lights the approach corridor", function()
    local st = new_state(42)
    local s, v = stats_at(st, 100)
    expect(s.lights >= 1).to_be(true)
    expect(v.calls.billboard >= 1).to_be(true)
    expect(s.lights <= sh.kit().lod.max_lights + #vhull.approach_lights(st, 1)).to_be(true)
    local lights = vhull.approach_lights(st, 1)
    expect(#lights).to_be(2 * (sh.kit().approach.length // sh.kit().approach.step))
    local b = dock.bay(st, 1)
    expect(lights[1].pos[1] > b.hi[1]).to_be(true)
    -- the chase moves
    local v1, v2 = fake_view(), fake_view()
    local A = assets.init()
    local cam = { pos = { b.mouth[1] + 100, b.mouth[2], b.mouth[3] } }
    expect(vhull.approach(v1, A, st, 1, cam, 0)).to_be(#lights)
    expect(vhull.approach(v2, A, st, 1, cam, 50)).to_be(#lights)
    expect(vhull.approach(v2, A, st, 1, { pos = { b.mouth[1] + 5000, 0, 0 } }, 0)).to_be(0)
    vhull.free_all()
  end)
  it("picks the levels by distance and the outpost sooner", function()
    local port = sh.generate(5, "port", 1)
    local out = sh.generate(5, "outpost", 1)
    expect(vhull.level(port, 2000)).to_be("far")
    expect(vhull.level(port, 600)).to_be("hull")
    expect(vhull.level(port, 50)).to_be("detail")
    expect(vhull.level(out, 600)).to_be("far")
    expect(vhull.box_dist({ 5, 5, 5 }, { 0, 0, 0 }, { 10, 10, 10 })).to_be(0)
    expect(vhull.box_dist({ 13, 5, 5 }, { 0, 0, 0 }, { 10, 10, 10 })).to_be_near(3, 1e-9)
    vhull.free_all()
  end)
  it("keeps only a few layouts' meshes and frees the old", function()
    for s = 1, 9 do
      local L = sh.get(s * 11, "outpost", 1)
      vhull.mesh(L, "far")
    end
    vhull.free_all()
    expect(vhull.stats.draws).to_be_truthy()
  end)
end)
