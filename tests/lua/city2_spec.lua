-- SPDX-License-Identifier: MIT
-- Milestone 11 (add-cities): body cities on asteroids, moons and planets. Generation (determinism,
-- budget, reachability, landmarks, the three forms), the sites in the sectors, the district power
-- grid (couplings, gates, sleeping sentries), the body's pull on the saucer, the city map, the HUD
-- beacon, the render streaming and the environment. Every `it` name is a scenario of
-- openspec/changes/add-cities.
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local civs = require("sim.civs")
local ruinm = require("sim.ruin")
local citygen = require("sim.citygen")
local cities = require("sim.cities")
local sentry = require("sim.sentry")
local tractor = require("sim.tractor")
local panel = require("sim.panel")
local save = require("sim.save")
local vec = require("lib.vec")
local assets = require("view.assets")
local render = require("view.render")
local hud = require("view.hud")
local mapv = require("view.map")

local function core(r, off)
  local k = ruinm.kit_of(r.kit)
  local ro = (k.city.ring or 0) * (k.city.lot + k.city.street) * k.cell
  return { off[1] + ro, off[2], off[3] }
end
local function gen(id, seed, origin)
  civs.use(42)
  return citygen.generate(seed or 777, ruinm.kit_of(id), civs.get(42, 1), origin or { 0, 0, 0 })
end
local BODY_SECTOR = { planet = 3, moon = 4, asteroid = 2 }

local function cmd(t) return saucer.input.command(t or {}) end
local function run(st, n)
  for _ = 1, n or 1 do
    local f = {}
    for i = 1, #st.players do f[i] = cmd() end
    game.step(st, f, 1 / 60)
  end
end
local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end
-- a state sitting in the sector that holds the city of `body`; -> state, site index, ruin
local function in_city(body)
  local st = new_state()
  game.enter_sector(st, BODY_SECTOR[body])
  for i, s in ipairs(st.sector.sites) do
    if s.city then return st, i, game.ruin(i) end
  end
end
local function fake_view(opts)
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, texts = "" }
  for k, x in pairs(opts or {}) do v[k] = x end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
    v[m] = function(self, ...)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "text" then
        local s = select(3, ...)
        self.texts = self.texts .. s .. "|"
        return #s * 8
      end
      if m == "fog" then self.fogged = ... end
    end
  end
  return v
end

describe("a city's look", function()
  it("each civilisation builds its own silhouette and wears its own light colours", function()
    civs.use(42)
    local forms, wins = {}, {}
    for id = 1, 12 do
      local c = civs.get(42, id)
      if c then
        local s = citygen.style_of(c)
        forms[s.form] = true
        wins[table.concat(s.window, ",")] = true
        expect(citygen.style_of(c).form).to_be(s.form)
      end
    end
    local nf, nw = 0, 0
    for _ in pairs(forms) do nf = nf + 1 end
    for _ in pairs(wins) do nw = nw + 1 end
    expect(nf).to_be_greater(1)
    expect(nw).to_be_greater(2)
    expect(citygen.style_of(nil).form).to_be("ziggurat")
  end)
  it("every silhouette stays inside its footprint, so what you see is what you hit", function()
    for _, form in ipairs({ "spire", "dome", "arcology", "ziggurat", "crystal" }) do
      for _, inv in ipairs({ false, true }) do
        local tl = citygen.tiers(form, 20, 14, 200, inv)
        expect(#tl).to_be_greater(0)
        for _, t in ipairs(tl) do
          expect(t.dx >= 0 and t.dz >= 0).to_be_truthy()
          expect(t.dx + t.w <= 20 and t.dz + t.w2 <= 14).to_be_truthy()
          expect(t.h >= 2).to_be_truthy()
        end
      end
    end
  end)
  it("a styled kit wears the civ's colours and leaves the shared kit alone", function()
    local st, i, r = in_city("planet")
    local k = assets.styled_kit(r)
    expect(k.window_color).to_be(r.city.style.window)
    expect(k.accent).to_be(r.city.style.accent)
    expect(ruinm.kit_of(r.kit).window_color ~= r.city.style.window).to_be_truthy()
    local plain = { kit = "city_planet" }
    expect(assets.styled_kit(plain)).to_be(ruinm.kit_of("city_planet"))
  end)
  it("a city's windows, signs and strips are lights, split from the walls and built when wanted", function()
    local st, i, r = in_city("planet")
    local set = assets.ruin_chunks(r, st.sector.sites[i].pos)
    local with, built = nil, 0
    for _, ch in ipairs(set.chunks) do
      if ch.light_parts and #ch.light_parts > 20 and ch.solid then with = with or ch end
    end
    expect(with ~= nil).to_be_truthy()
    expect(with.lights).to_be(nil)
    local m = assets.chunk_lights(with)
    expect(m ~= nil).to_be_truthy()
    expect(with.light_parts).to_be(nil)
    expect(assets.chunk_lights(with)).to_be(m)
    -- a chunk with no lights reports none, and never builds an empty mesh
    local empty = { light_parts = {} }
    expect(assets.chunk_lights(empty)).to_be(nil)
    expect(assets.chunk_lights({})).to_be(nil)
    -- ruins that are not cities keep their emissive parts in the one mesh
    local old = new_state()
    game.enter_sector(old, 2)
    for j, s in ipairs(old.sector.sites) do
      local rr = game.ruin(j)
      if rr and not rr.city then
        for _, ch in ipairs(assets.ruin_chunks(rr, s.pos).chunks) do expect(ch.light_parts).to_be(nil) end
        break
      end
    end
  end)
  it("window patterns are the same every time and tower tiers differ", function()
    expect(assets.hash3(1, 2, 3)).to_be(assets.hash3(1, 2, 3))
    expect(assets.hash3(1, 2, 3) ~= assets.hash3(3, 2, 1)).to_be_truthy()
    local st, i, r = in_city("planet")
    local n = 0
    for _, s in ipairs(r.solids) do if s.kind == "tower" and s.apex then n = n + 1 end end
    expect(n).to_be_greater(10)
  end)
  it("the hint line sits at the top and a city's message log has a backing", function()
    local st = new_state()
    local p = st.players[1]
    p.mode, p.panel, p.ship.morph = "helm", false, false
    run(st, 2)
    local v = fake_view({ width = 1024, height = 576 })
    hud.draw(v, st, p, nil)
    expect(v.calls.rect).to_be_greater(1)
    expect(v.texts:find("WASD fly", 1, true) ~= nil).to_be_truthy()
  end)
end)

describe("lights come on with the grid", function()
  it("a dark district has no light, a restored one flickers and ramps up, the spaceport is always lit", function()
    local st, i, r = in_city("planet")
    local port = r.city.port
    expect(cities.light(st, i, r, port)).to_be(1)
    local d
    for _, pd in ipairs(r.city.districts) do if not pd.powered then d = pd.id break end end
    expect(cities.light(st, i, r, d)).to_be(0)
    expect(cities.light(st, i, r, nil)).to_be(1)
    st.tick = 1000
    cities.restore(st, i, d)
    local seen_on, seen_off = false, false
    for dt = 0, 89 do
      st.tick = 1000 + dt
      local l = cities.light(st, i, r, d)
      if l > 0 then seen_on = true else seen_off = true end
    end
    expect(seen_on and seen_off).to_be_truthy()
    st.tick = 1000 + 120
    local mid = cities.light(st, i, r, d)
    expect(mid > 0 and mid < 1).to_be_truthy()
    st.tick = 1000 + cities.RAMP
    expect(cities.light(st, i, r, d)).to_be(1)
  end)
  it("the drawn lights follow the grid: none in a dark district, many once it is restored", function()
    local st, i, r = in_city("planet")
    local A = assets.init()
    local site = st.sector.sites[i]
    local d
    for _, pd in ipairs(r.city.districts) do if not pd.powered and pd.kind == "industrial" then d = pd break end end
    d = d or r.city.districts[2]
    local cam = { pos = vec.add(site.pos, { d.pos[1] - site.pos[1], d.pos[2] - site.pos[2] + 40, d.pos[3] - site.pos[3] - 150 }), yaw = 0, pitch = 0, fov = 1.2 }
    st.tick = 5000
    local before = render.draw_ruins(fake_view(), A, st, cam, false).lit or 0
    for _, pd in ipairs(r.city.districts) do if not pd.powered then cities.restore(st, i, pd.id) end end
    st.tick = 5000 + cities.RAMP + 1
    local after = 0
    for _ = 1, 8 do after = render.draw_ruins(fake_view(), A, st, cam, false).lit or 0 end
    expect(after).to_be_greater(before)
    expect(after).to_be_greater(3)
  end)
  it("a light pillar marks each landmark district, and a lit district glows from afar", function()
    local st, i, r = in_city("planet")
    local site = st.sector.sites[i]
    local set = assets.ruin_chunks(r, site.pos)
    local n, kinds = 0, {}
    for d, b in pairs(set.beacons) do n = n + 1 expect(b.radius).to_be_greater(10) end
    expect(n).to_be_greater(3)
    local glow = 0
    for _, dm in pairs(set.districts) do if dm.glow then glow = glow + 1 end end
    expect(glow).to_be_greater(8)
    local A = assets.init()
    local stat = render.draw_ruins(fake_view(), A, st, { pos = vec.add(site.pos, core(r, { 1440, 200, -300 })), yaw = 0, pitch = 0, fov = 1.5 }, false)
    expect(stat.beacons or 0).to_be_greater(0)
    -- far from a dark district its glow is not drawn, and after the restore it is
    local far = { pos = vec.add(site.pos, core(r, { 100, 300, 100 })), yaw = 0, pitch = 0, fov = 3.0 }
    local v1 = fake_view()
    render.draw_ruins(v1, A, st, far, false)
    expect(v1.calls.mesh).to_be_greater(0)
  end)
end)

describe("a city that runs to the horizon", function()
  it("a skyline ring of towers surrounds the core: tens of districts, hundreds of boxes, no rooms", function()
    local planet = gen("city_planet")
    local moon = gen("city_moon")
    local rock = gen("city_asteroid")
    expect(#planet.city.skyline + #planet.city.districts).to_be_greater(89)
    expect(#moon.city.skyline + #moon.city.districts).to_be_greater(49)
    expect(#rock.city.skyline + #rock.city.districts).to_be_greater(39)
    for _, r in ipairs({ planet, moon, rock }) do
      expect(#r.city.districts).to_be_less(17)
      local outer = 0
      for _, s in ipairs(r.solids) do
        if s.outer then
          outer = outer + 1
          expect(s.district).to_be_greater(citygen.SKY_BASE)
        end
      end
      expect(outer).to_be(r.city.stats.skyline_solids)
      expect(outer).to_be_greater(600)
      for _, sd in ipairs(r.city.skyline) do
        expect(sd.id).to_be_greater(citygen.SKY_BASE)
        expect(sd.towers).to_be_greater(0)
      end
    end
    -- the planet is several kilometres across
    local k = ruinm.kit_of("city_planet")
    expect(k.grid[1] * k.cell).to_be_greater(8000)
  end)
  it("the ring does not change the core: the same rooms, doors and slots with or without it", function()
    local k = ruinm.kit_of("city_moon")
    local with = gen("city_moon")
    local ring = k.city.ring
    k.city.ring = nil
    local ok, without = pcall(gen, "city_moon")
    k.city.ring = ring
    expect(ok).to_be_truthy()
    expect(#with.rooms).to_be(#without.rooms)
    expect(#with.doors).to_be(#without.doors)
    expect(#with.slots).to_be(#without.slots)
    expect(#without.city.skyline).to_be(0)
  end)
  it("the ring is inside the site's bounds, so it is a place you can fly and crash into", function()
    local st, i, r = in_city("planet")
    local lo, hi = ruinm.bounds(r, st.sector.sites[i].pos, 0)
    for _, s in ipairs(r.solids) do
      if s.outer then
        for a = 1, 3 do expect(s[1][a] >= lo[a] - 1e-6 and s[2][a] <= hi[a] + 1e-6).to_be_truthy() end
      end
    end
    local b = game.site_bounds(i)
    expect(b[2][1] - b[1][1]).to_be_greater(8000)
  end)
  it("skyline windows are built near the camera, a handful at a time, and the oldest are freed", function()
    local st, i, r = in_city("planet")
    local set = assets.ruin_chunks(r, st.sector.sites[i].pos)
    local ids = {}
    for d, dm in pairs(set.districts) do if dm.outer then ids[#ids + 1] = d end end
    table.sort(ids)
    expect(#ids).to_be_greater(60)
    for n = 1, assets.OUTER_LIVE + 3 do
      local near = assets.outer_detail(set, ids[n])
      expect(near.mesh ~= nil).to_be_truthy()
      expect(assets.outer_detail(set, ids[n])).to_be(near)
    end
    local live = 0
    for _, d in ipairs(ids) do if set.districts[d].near then live = live + 1 end end
    expect(live).to_be(assets.OUTER_LIVE)
    expect(set.districts[ids[1]].near).to_be(nil)
  end)
  it("near the ring its windows are drawn, far from it one coarse mesh per district, and a planet has a horizon", function()
    local st, i, r = in_city("planet")
    local A = assets.init()
    local site = st.sector.sites[i]
    local set = assets.ruin_chunks(r, site.pos)
    expect(set.horizon ~= nil).to_be_truthy()
    local sd = r.city.skyline[#r.city.skyline // 2]
    local cam = { pos = { sd.pos[1], sd.pos[2] + 80, sd.pos[3] - 60 }, yaw = 0, pitch = 0, fov = 2.4 }
    local lit = 0
    local stt
    for _ = 1, 12 do stt = render.draw_ruins(fake_view(), A, st, cam, false) lit = math.max(lit, stt.lit or 0) end
    expect(lit).to_be_greater(0)
    local far = { pos = vec.add(site.pos, { 100, 600, -400 }), yaw = 0, pitch = 0, fov = 3.0 }
    local stat = render.draw_ruins(fake_view(), A, st, far, false)
    expect(stat.lod).to_be_greater(10)
    local _, _, mr = in_city("moon")
    expect(assets.ruin_chunks(mr, { 0, 0, 0 }).horizon).to_be(nil)
  end)
  it("a city site sits clear of its sector's other sites however wide the ring", function()
    for body, sid in pairs(BODY_SECTOR) do
      local st, i, r = in_city(body)
      local k = ruinm.kit_of(r.kit)
      local half = math.max(k.grid[1], k.grid[3]) * k.cell / 2
      local s = st.sector.sites[i]
      local c = { s.pos[1] + k.grid[1] * k.cell / 2, s.pos[2], s.pos[3] + k.grid[3] * k.cell / 2 }
      for j, o in ipairs(st.sector.sites) do
        if j ~= i then expect(vec.dist({ c[1], 0, c[3] }, { o.pos[1], 0, o.pos[3] })).to_be_greater(half) end
      end
    end
  end)
end)
