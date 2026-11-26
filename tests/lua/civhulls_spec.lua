-- SPDX-License-Identifier: MIT
-- add-civ-hulls: every civ dresses the outside of what it builds its own way (sim/hulldress.lua, civs/hulls.lua): a
-- silhouette motif, a surface pattern from its signature rule, its own materials and signal lights by its light
-- model, on its trader stations (sim/stationhull.lua, view/stationhull.lua) and on its relics seen from afar
-- (view/relic.lua), so two builders read apart from 1.5 km and nothing reads as a dark silhouette.
local game = require("sim.game")
local civs = require("sim.civs")
local hd = require("sim.hulldress")
local sh = require("sim.stationhull")
local dock = require("sim.dock")
local vhull = require("view.stationhull")
local relicv = require("view.relic")
local relic = require("sim.relic")
local assets = require("view.assets")
local vec = require("lib.vec")

local function new_state(seed, slice)
  local st = {}
  game.init(st, { seed = seed or 42, players = 1, relic_slice = slice })
  return st
end
local function view()
  local v = { player = 1, calls = { mesh = 0, billboard = 0 }, sizes = {} }
  function v:materials(t) self.calls.mats = t return 7 end
  function v:mesh(id, o) self.calls.mesh = self.calls.mesh + 1 end
  function v:billboard(tex, p, size) self.calls.billboard = self.calls.billboard + 1 self.sizes[#self.sizes + 1] = { p = p, size = size } end
  return v
end
local function dress_key(d) return table.concat({ d.motif, d.pattern, d.light.kind, d.mats.dominant, d.mats.accent }, "/") end

describe("a civ's hull dress", function()
  it("gives every civ of a roster its own motif, and the whole dress differs between any two", function()
    for _, seed in ipairs({ 42, 7, 1234 }) do
      local u = civs.universe(seed)
      local motifs, dresses = {}, {}
      for i, c in ipairs(u) do
        local d = hd.of(c, seed)
        expect(hd.of(c, seed)).to_be(d)
        if i <= #hd.kit().motifs then
          expect(motifs[d.motif]).to_be(nil)
          motifs[d.motif] = c.id
        end
        local k = dress_key(d)
        expect(dresses[k]).to_be(nil)
        dresses[k] = true
        -- the palette comes from its own materials, never too dark to read
        expect(math.max(d.palette.plate[1], d.palette.plate[2], d.palette.plate[3]) >= 0.5 - 1e-9).to_be(true)
        expect(#d.lamps >= 1).to_be(true)
      end
    end
    -- a civ outside the roster (the slice's Vyrr) still dresses, by its massing's liking
    local vy = hd.of(civs.vyrr(), 42)
    expect(vy.motif).to_be("spines")
    expect(vy.pattern).to_be("studs")
    -- the roster's hand-out: likings first, then the kit's order, wrapping past eight
    local list = {}
    for i = 1, 10 do list[i] = { id = "c" .. i, index = i, massing = "cluster" } end
    local map = hd.assign(list)
    expect(map.c1).to_be("tendrils")
    expect(map.c2).to_be("spines")
    expect(map.c9 ~= nil and map.c10 ~= nil).to_be(true)
    expect(hd.lift({ 0, 0, 0 }, 0.5)[1]).to_be(0)
    expect(hd.base("nope")[1]).to_be(0.6)
  end)

  it("turns a part's +y onto any direction", function()
    for _, d in ipairs({ { 0, 1, 0 }, { 1, 0, 0 }, { 0, 0, -1 }, hd.norm({ 0.3, -0.5, 0.8 }) }) do
      local roll, pitch = hd.orient(d)
      local cr, sr, cp, sp = math.cos(roll), math.sin(roll), math.cos(pitch), math.sin(pitch)
      local v = { -sr, cr * cp, cr * sp }
      for k = 1, 3 do expect(math.abs(v[k] - d[k]) < 1e-6).to_be(true) end
    end
    expect(hd.norm({ 0, 0, 0 })[2]).to_be(1)
  end)

  it("grows every motif and lays every pattern, with lit parts and boxes inside what is drawn", function()
    local d = hd.of(civs.universe(42)[1], 42)
    local P = d.palette
    for _, motif in ipairs(hd.kit().motifs) do
      local out, glow = {}, {}
      local base, dir = { 0, 0, 0 }, hd.norm({ 0.2, 1, 0.1 })
      local tip = hd.element(out, motif, base, dir, 300, 30, P, 8, glow)
      expect(#out > 0).to_be(true)
      expect(#glow > 0).to_be(true)
      for _, q in ipairs(glow) do expect((q.emissive or 0) > 0).to_be(true) end
      expect(vec.dist(base, tip) <= 300 + 1e-6).to_be(true)
      local boxes = hd.boxes({}, motif, base, dir, 300, 30)
      expect(#boxes > 0).to_be(true)
      for _, b in ipairs(boxes) do
        local c = vec.scale(vec.add(b[1], b[2]), 0.5)
        local t = vec.dot(vec.sub(c, base), dir)
        expect(t >= 0 and t <= 300).to_be(true)
        expect(vec.dist(c, vec.add(base, vec.scale(dir, t))) < 30).to_be(true)
        expect(b[2][1] - b[1][1] <= 2 * 30).to_be(true)
      end
    end
    for _, kind in ipairs({ "studs", "crust", "plates", "inlay", "cells", "flow" }) do
      local out, glow = {}, {}
      hd.mark(out, glow, kind, { 0, 0, 0 }, { 0, 0, 1 }, 40, P)
      expect(#glow > 0).to_be(true)
    end
  end)
end)

describe("a station in its builder's dress", function()
  it("keeps the family's shape, box and stream, and adds the crown, crest, pattern and signals", function()
    local u = civs.universe(42)
    for _, fam in ipairs({ "coral", "crystal", "spiral", "shells" }) do
      local plain = sh.generate(4242, "port", 5, false, fam)
      for i = 1, #u, 3 do
        local L = sh.generate(4242, "port", 5, false, fam, u[i])
        expect(L.info.R).to_be(plain.info.R)
        expect(L.info.pods).to_be(plain.info.pods)
        expect(#L.lights).to_be(#plain.lights)
        for k = 1, 3 do
          expect(L.info.extent.lo[k]).to_be(plain.info.extent.lo[k])
          expect(L.info.extent.hi[k]).to_be(plain.info.extent.hi[k])
        end
        -- the station's own solids come first and unchanged; the dress only adds
        for n = 1, #plain.solids do
          for k = 1, 3 do expect(L.solids[n][1][k]).to_be(plain.solids[n][1][k]) end
        end
        expect(#L.solids > #plain.solids).to_be(true)
        expect(L.info.motif).to_be(hd.of(u[i]).motif)
        expect(L.civ).to_be(u[i].id)
        expect(#L.signals >= 8).to_be(true)
        -- inside the box, and nowhere near the hangar's mouth or its approach (all of it behind the cell's back wall)
        local e = L.info.extent
        for n = #plain.solids + 1, #L.solids do
          local b = L.solids[n]
          for k = 1, 3 do
            expect(b[1][k] >= e.lo[k] - 1).to_be(true)
            expect(b[2][k] <= e.hi[k] + 1).to_be(true)
          end
          expect(b[2][1] < L.bay.lo[1] - 40).to_be(true)
        end
        -- the layout pass and the triangles pass agree
        local M = sh.generate(4242, "port", 5, true, fam, u[i])
        expect(M.hash).to_be(L.hash)
        expect(L.hash ~= plain.hash).to_be(true)
        expect(M.info.marks > 10).to_be(true)
        local mats = 0
        for _, q in ipairs(M.parts.core) do if q.mat then mats = mats + 1 end end
        expect(mats > 50).to_be(true)
        for _, q in ipairs(M.parts.far) do expect((q.emissive or 0) > 0).to_be(true) end
      end
    end
    -- the outpost wears it too, at its scale
    local o = sh.generate(99, "outpost", 2, false, "coral", u[2])
    expect(#o.signals > 0).to_be(true)
    expect(o.info.motif).to_be(hd.of(u[2]).motif)
  end)

  it("is built by its sector's first site's civ; a city's outpost by the city's", function()
    local st = new_state(42)
    local c = sh.civ_for(st, 1)
    expect(c.id).to_be(civs.of(st, st.sector.sites[1]).id)
    expect(sh.for_trader(st, 1).civ).to_be(c.id)
    for sid = 2, 7 do
      game.enter_sector(st, sid)
      if st.sector.traders then
        local city
        for _, s in ipairs(st.sector.sites) do if s.city then city = s end end
        expect(sh.civ_for(st, 2).id).to_be(civs.of(st, city).id)
        expect(sh.for_trader(st, 2).civ).to_be(city and civs.of(st, city).id)
        break
      end
    end
    -- a style overrides every station (shot scripts), and clears
    local other = civs.universe(42)[5]
    sh.set_style(other)
    expect(sh.for_trader(st, 1).civ).to_be(other.id)
    sh.set_style(nil)
    expect(sh.civ_for({ sector = { trader = {}, sites = {} } }, 1)).to_be(nil)
  end)

  it("signals blink by the light model and read from kilometres away", function()
    local lamps = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
    for _, kind in ipairs({ "chroma", "ripple", "fog", "arc", "orbit", "dim" }) do
      local seen = {}
      for tick = 0, 600, 7 do
        local a, c = hd.signal_at({ kind = kind, period = 60, phase = 3, k = 2, n = 6, c = lamps[1] }, tick, lamps)
        expect(a >= 0 and a <= 1).to_be(true)
        expect(#c).to_be(3)
        seen[string.format("%.2f", a)] = true
      end
      local n = 0
      for _ in pairs(seen) do n = n + 1 end
      if kind ~= "chroma" then expect(n > 1).to_be(true) end
    end
    -- the chroma cycle runs through the lamps
    local _, c0 = hd.signal_at({ kind = "chroma", period = 90, phase = 0, k = 0, n = 1 }, 0, lamps)
    local _, c1 = hd.signal_at({ kind = "chroma", period = 90, phase = 0, k = 0, n = 1 }, 30, lamps)
    expect(c0[1] ~= c1[1]).to_be(true)
    -- lifted against the fog: e^(density d), capped
    expect(hd.fog_lift(0, 0.0009)).to_be(1)
    expect(math.abs(hd.fog_lift(1500, 0.0009) - 3.857) < 0.02).to_be(true)
    expect(hd.fog_lift(90000, 0.0009)).to_be(hd.kit().signal.boost)
    -- drawn from 5 km, never smaller than the kit's share of their distance
    local st = new_state(42)
    local L = sh.for_trader(st, 1)
    local tp = st.sector.trader.pos
    local e = L.info.extent
    local cam = { pos = { tp[1] + e.hi[1] + 5000, tp[2], tp[3] } }
    local v = view()
    relicv.claimed = nil
    vhull.draw(v, assets.init(), st, cam, 100)
    expect(vhull.stats.signals >= 8).to_be(true)
    local K = hd.kit().signal
    for _, b in ipairs(v.sizes) do
      expect(b.size >= vec.dist(b.p, cam.pos) * K.min_px - 1e-6).to_be(true)
    end
    expect(vhull.signals(v, assets.init(), { signals = {} }, tp, cam, 1)).to_be(0)
    vhull.free_all()
  end)

  it("shades as its builder's materials, or its plain twin when another civ's relic holds the view", function()
    local st = new_state(42)
    local L = sh.for_trader(st, 1)
    local tp = st.sector.trader.pos
    local e = L.info.extent
    local cam = { pos = { tp[1] + e.hi[1] + 300, tp[2], tp[3] } }
    local A = assets.init()
    vhull.free_all()
    local v = view()
    relicv.claimed = nil
    for _ = 1, 8 do relicv.claimed = nil vhull.draw(v, A, st, cam, 100) end
    expect(v.calls.mats ~= nil).to_be(true)
    expect(relicv.claimed).to_be(L.civ_rec)
    -- another civ holds the slots: the plain twins draw (built once, kept)
    local other = civs.universe(42)[6]
    local w = view()
    for _ = 1, 8 do relicv.claimed = other vhull.draw(w, A, st, cam, 100) end
    expect(w.calls.mats).to_be(nil)
    expect(vhull.stats.draws >= 2).to_be(true)
    local id = vhull.mesh(L, "core", false, true)
    expect(vhull.mesh(L, "core", false, true)).to_be(id)
    expect(id ~= vhull.mesh(L, "core", false, false)).to_be(true)
    relicv.claimed = nil
    vhull.free_all()
  end)
end)

describe("a relic in its builder's dress, seen from afar", function()
  it("wears the civ's edges, pattern, motif and lit bands, and differs from civ to civ", function()
    local st = new_state(42, true)
    local i = relic.site_index(st)
    local r = game.ruin(i)
    local site = st.sector.sites[i]
    local set = relicv.meshes(r, site.pos)
    local rm
    for _, x in ipairs(set.rooms) do if x.villa then rm = x break end end
    local u = civs.universe(42)
    local looks = {}
    for _, c in ipairs(u) do
      local parts, tips = relicv.far_parts(rm, c)
      local kinds, lit = {}, 0
      for _, q in ipairs(parts) do
        kinds[#kinds + 1] = q.kind
        if (q.emissive or 0) > 0 then lit = lit + 1 end
      end
      expect(lit > 0).to_be(true)
      expect(#tips >= 1).to_be(true)
      looks[table.concat(kinds, ",") .. hd.of(c).pattern] = true
    end
    local n = 0
    for _ in pairs(looks) do n = n + 1 end
    expect(n >= 6).to_be(true)
    -- the far hull mesh follows a restyle
    local a = relicv.blob(rm, u[1])
    expect(relicv.blob(rm, u[1])).to_be(a)
    local b = relicv.blob(rm, u[2])
    expect(rm.far_civ).to_be(u[2].id)
    expect(b ~= nil).to_be(true)
  end)

  it("draws its far hulls and signals out to the kit's relic range, and nothing beyond", function()
    local st = new_state(42, true)
    local i = relic.site_index(st)
    local r = game.ruin(i)
    local site = st.sector.sites[i]
    local set = relicv.meshes(r, site.pos)
    local A = { pal = {}, tex = { glow = 1 }, unit = 1 }
    local K = hd.kit()
    local d = relicv.NEAR_RELIC + 1500
    local cam = { pos = { set.center[1], set.center[2], set.center[3] - set.radius - d }, yaw = 0, pitch = 0 }
    local v = view()
    local stats = relicv.draw(v, A, st, cam, false, 2)
    expect((stats.blobs or 0) > 0).to_be(true)
    expect((stats.signals or 0) > 0).to_be(true)
    expect(v.calls.mats ~= nil).to_be(true)
    expect(#relicv.signals(set) > 0).to_be(true)
    for _, b in ipairs(v.sizes) do expect(b.size >= vec.dist(b.p, cam.pos) * K.signal.min_px - 1e-6).to_be(true) end
    -- within the near range but outside the rooms: signals too
    local near = relicv.draw(view(), A, st, { pos = { set.center[1], set.center[2], set.center[3] - set.radius - 1500 }, yaw = 0, pitch = 0 }, false, 2)
    expect((near.signals or 0) > 0).to_be(true)
    -- past the relic range nothing draws
    local gone = relicv.draw(view(), A, st, { pos = { set.center[1], set.center[2], set.center[3] - set.radius - K.relic.far - 500 }, yaw = 0, pitch = 0 }, false, 2)
    expect(gone.blobs).to_be(nil)
    expect(relicv.claimed).to_be(nil)
  end)
end)
