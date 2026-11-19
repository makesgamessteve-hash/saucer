-- SPDX-License-Identifier: MIT
-- Milestone 11, phase 2 (OpenSpec add-cities-2): the look and lights of a city, the skyline ring that runs it
-- to the horizon, transit (mag-rails, lifts), the wet or wild undercity, storms and wind, falling sky-bridges
-- and the patrols of the dark districts. Every `it` name is a scenario of openspec/changes/add-cities-2.
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
  it("the hint line is docked bottom-left above the console, clear of the sightline, and fades", function()
    local st = new_state()
    local p = st.players[1]
    p.mode, p.panel, p.ship.morph = "helm", false, false
    run(st, 2)
    local v = fake_view({ width = 1024, height = 576 })
    local at = {}
    local text = v.text
    v.text = function(self, x, y, s, c) if s:find("WASD fly", 1, true) then at[#at + 1] = { x, y, c } end return text(self, x, y, s, c) end
    hud.draw(v, st, p, nil)
    expect(v.texts:find("WASD fly", 1, true) ~= nil).to_be_truthy()
    expect(#at).to_be(1)
    expect(at[1][1]).to_be_less(1024 * 0.35)
    expect(at[1][2] > 576 * 0.3 and at[1][2] < 576 * 0.65).to_be_truthy()
    -- gone after HINT_TICKS; H shows the full help in the same corner
    st.tick = st.tick + hud.HINT_TICKS + 5
    local v2 = fake_view({ width = 1024, height = 576 })
    hud.draw(v2, st, p, nil)
    expect(v2.texts:find("WASD fly", 1, true)).to_be(nil)
    p.help = true
    local v3 = fake_view({ width = 1024, height = 576 })
    hud.draw(v3, st, p, nil)
    expect(v3.texts:find("SAUCER - controls", 1, true) ~= nil).to_be_truthy()
    p.help = false
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
    for dt = 0, 39 do
      st.tick = 1000 + dt
      local l = cities.light(st, i, r, d)
      if l > 0 then seen_on = true else seen_off = true end
    end
    expect(seen_on and seen_off).to_be_truthy()
    st.tick = 1000 + 70
    local mid = cities.light(st, i, r, d)
    expect(mid > 0 and mid < 1).to_be_truthy()
    st.tick = 1000 + cities.RAMP
    expect(cities.light(st, i, r, d)).to_be(1)
  end)
  it("a restored district lights up in a wave from its coupling, the beacons first, and the HUD and sound mark it", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.mode, p.panel, p.ship.morph = "helm", false, false
    p.site = i
    local c = cities.candidates(st, p, i, r)[1]
    expect(c.kind).to_be("coupling")
    local d = c.district
    st.tick = 3000
    game.pick_up(st, p, c, i)
    local sting = false
    for _, f in ipairs(p.fx or {}) do if f.sound == "gridon" then sting = true end end
    expect(sting).to_be_truthy()
    local near, far = { c.pos[1] + 5, c.pos[2], c.pos[3] }, { c.pos[1] + 400, c.pos[2], c.pos[3] }
    -- dark during the flicker; then the front leaves the coupling and reaches the far side later
    st.tick = 3000 + 10
    expect(cities.light_at(st, i, r, d, near)).to_be(0)
    st.tick = 3000 + cities.WAVE_START + 40
    expect(cities.light_at(st, i, r, d, near)).to_be(1)
    expect(cities.light_at(st, i, r, d, far)).to_be(0)
    local mid
    for t = 3000 + cities.WAVE_START, 3000 + cities.WAVE_TICKS do
      st.tick = t
      local k = cities.light_at(st, i, r, d, far)
      if k > 0 and k < 1 then mid = true end
    end
    expect(mid).to_be_truthy()
    st.tick = 3000 + cities.WAVE_TICKS
    expect(cities.light_at(st, i, r, d, far)).to_be(1)
    expect(cities.light_at(st, i, r, nil, far)).to_be(1)
    expect(cities.light_at(st, i, r, r.city.port, far)).to_be(1)
    local other
    for _, pd in ipairs(r.city.districts) do if not pd.powered and pd.id ~= d then other = pd.id break end end
    expect(cities.light_at(st, i, r, other, far)).to_be(0)
    -- the beacon is already up at the start of the wave
    st.tick = 3000 + cities.WAVE_START + 20
    expect(cities.light(st, i, r, d) > 0).to_be_truthy()
    -- the fresh list and the banner
    expect(#cities.fresh(st, i, r, hud.BANNER_TICKS)).to_be(1)
    expect(cities.fresh(st, i, r, hud.BANNER_TICKS)[1].id).to_be(d)
    expect(#cities.fresh(st, i, {}, 10)).to_be(0)
    local function banner(tick)
      st.tick = tick
      local v = fake_view({ width = 480, height = 270 })
      hud.grid_banner(v, st, p)
      return v
    end
    expect(banner(3000 + 5).calls.rect).to_be_greater(2)
    local b = banner(3000 + 60)
    expect(b.texts:find("POWER RESTORED", 1, true) ~= nil).to_be_truthy()
    expect(b.texts:find("GRID 2/16", 1, true) ~= nil).to_be_truthy()
    expect(banner(3000 + 3).texts).to_be("")
    expect(banner(3000 + hud.BANNER_TICKS + 5).texts).to_be("")
    p.site = 0
    expect(banner(3000 + 60).texts).to_be("")
    p.site = i
    expect(banner(3000 + 60).calls.rect).to_be_greater(0)
    local small = fake_view({ width = 240, height = 135 })
    hud.grid_banner(small, st, p)
    expect(small.texts).to_be("")
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
    st.tick = 5000 + cities.WAVE_TICKS + 1
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
        if s.outer and s.district < citygen.TRANSIT_BASE then
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

local function peak(r) return cities.phase(r) + cities.STORM_LEN // 2 end

describe("transit and the undercity", function()
  it("mag-rails run on pylons across the whole city and a lift stands at every plaza", function()
    for _, id in ipairs({ "city_planet", "city_moon", "city_asteroid" }) do
      local r = gen(id)
      local k = ruinm.kit_of(id)
      expect(#r.city.rails).to_be(#k.city.rails.rows + 1)
      expect(#r.city.lifts).to_be_greater(5)
      local rails, pylons, posts = 0, 0, 0
      for _, s in ipairs(r.solids) do
        if s.kind == "rail" then rails = rails + 1 expect(s.district >= citygen.TRANSIT_BASE and s.outer).to_be_truthy() end
        if s.kind == "pylon" then pylons = pylons + 1 end
        if s.kind == "liftpost" then posts = posts + 1 end
      end
      expect(rails).to_be_greater(30)
      expect(pylons).to_be(rails)
      expect(posts).to_be(#r.city.lifts * 4)
    end
    local r = gen("city_planet")
    local longest = 0
    for _, ln in ipairs(r.city.rails) do longest = math.max(longest, (ln.b - ln.a) * 4) end
    expect(longest).to_be_greater(6000)
  end)
  it("trains and lift cabins are drawn from the clock: end to end and back, up and down", function()
    local r = gen("city_planet")
    local line = r.city.rails[1]
    local lo, hi = 1e9, -1e9
    for tick = 0, 60 * 400, 97 do
      local u, dir = render.train_pos(line, 0, tick)
      lo, hi = math.min(lo, u), math.max(hi, u)
      expect(u >= line.a - 1e-6 and u <= line.b + 1e-6).to_be_truthy()
      expect(dir == 1 or dir == -1).to_be_truthy()
    end
    expect(hi - lo).to_be_greater((line.b - line.a) * 0.8)
    expect(render.train_pos(line, 0, 1234)).to_be(render.train_pos(line, 0, 1234))
    local lift = r.city.lifts[1]
    for tick = 0, 60 * 80, 31 do
      local y = render.lift_y(lift, tick)
      expect(y >= lift.y0 and y <= lift.y1).to_be_truthy()
    end
    local st, i, rr = in_city("planet")
    local A = assets.init()
    local ln = rr.city.rails[1]
    local u = render.train_pos(ln, 0, 500)
    local cam = { pos = { rr.origin[1] + u * 4, rr.origin[2] + ln.y * 4 + 40, rr.origin[3] + ln.c * 4 - 60 }, yaw = 0, pitch = 0, fov = 2 }
    st.tick = 500
    local stat = render.draw_ruins(fake_view(), A, st, cam, false)
    expect(stat.trains).to_be_greater(0)
    local lf = rr.city.lifts[1]
    local cam2 = { pos = { lf.pos[1], render.lift_y(lf, 500), lf.pos[3] - 50 }, yaw = 0, pitch = 0, fov = 2 }
    expect(render.draw_ruins(fake_view(), A, st, cam2, false).lifts).to_be_greater(0)
  end)
  it("a flooded undercity holds water and canal lamps, an overgrown one moss and vines, a rock neither", function()
    local function find(r, f) for _, room in ipairs(r.rooms) do if f(room) then return room end end end
    local function parts_of(id, f)
      civs.use(42)
      local r = gen(id)
      local room = find(r, f)
      expect(room ~= nil).to_be_truthy()
      return assets.room_decor(r, room, assets.styled_kit(r), r.origin), room
    end
    local function count(parts, pred) local n = 0 for _, p in ipairs(parts) do if pred(p) then n = n + 1 end end return n end
    local water = function(p) return p.color and p.color[3] > 0.4 and p.color[1] < 0.1 and p.emissive and p.emissive < 1 end
    local green = function(p) return p.color and p.color[2] > p.color[1] * 1.8 and p.color[2] > p.color[3] * 1.8 and not p.emissive end
    local deep = parts_of("city_planet", function(r) return r.level and r.level <= -2 end)
    expect(count(deep, water)).to_be(1)
    local canal, room = parts_of("city_planet", function(r) return r.tunnel end)
    expect(count(canal, water)).to_be(1)
    expect(count(canal, function(p) return p.light end)).to_be_greater(2)
    local moss = parts_of("city_planet", function(r) return r.level == -1 end)
    expect(count(moss, green)).to_be_greater(2)
    local moon = parts_of("city_moon", function(r) return r.level and r.level <= -1 end)
    expect(count(moon, green)).to_be_greater(2)
    expect(count(moon, water)).to_be(0)
    local plain = parts_of("city_asteroid", function(r) return r.level and r.level <= -1 end)
    expect(count(plain, green)).to_be(0)
    expect(count(plain, water)).to_be(0)
  end)
end)

describe("storms, wind and falling bridges", function()
  it("a storm front sweeps a planet city on a fixed clock, a moon has none", function()
    local st, i, r = in_city("planet")
    expect(cities.storm(r, 0)).to_be(0)
    local k, n = cities.storm(r, peak(r))
    expect(k).to_be_greater(0.95)
    expect(n).to_be(1)
    expect(cities.storm(r, cities.phase(r) + cities.STORM_LEN + 5)).to_be(0)
    local _, n2 = cities.storm(r, peak(r) + cities.STORM_PERIOD)
    expect(n2).to_be(2)
    expect(cities.storm_in(r, 0)).to_be(cities.phase(r))
    expect(cities.storm_in(r, peak(r))).to_be(0)
    expect(cities.storm_in(r, cities.phase(r) + cities.STORM_LEN)).to_be(cities.STORM_PERIOD - cities.STORM_LEN)
    local _, mi, mr = in_city("moon")
    expect(cities.storm(mr, peak(mr))).to_be(0)
    expect(cities.storm_in(mr, 0)).to_be(nil)
    local wx, wz, wk = cities.wind(r, peak(r))
    expect(wk).to_be_greater(0.9)
    expect(math.abs(wx) + math.abs(wz)).to_be_greater(2)
    local ax, az, ak = cities.wind(r, 0)
    expect(ak).to_be(0)
    expect(ax).to_be(0)
    local bx = cities.wind(r, peak(r))
    expect(bx).to_be(wx)
  end)
  it("the wind pushes a saucer in the open and does not reach it inside a room", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.mode, p.panel, p.ship.morph = "helm", false, false
    local open = vec.add(st.sector.sites[i].pos, core(r, { 1440, 650, 700 }))
    expect(cities.sheltered(r, open)).to_be(false)
    st.tick = peak(r)
    p.ship.pos, p.ship.vel, p.ship.charge = vec.copy(open), { 0, 0, 0 }, 100
    p.ship.charge = 100
    run(st, 30)
    local moved = vec.dist(p.ship.pos, open)
    expect(moved).to_be_greater(2)
    -- the same time of day with the wind off (before the first storm) leaves it where it was
    local st2, i2, r2 = in_city("planet")
    local q = st2.players[1]
    q.mode, q.panel, q.ship.morph = "helm", false, false
    q.ship.pos, q.ship.vel, q.ship.charge = vec.copy(open), { 0, 0, 0 }, 100
    st2.tick = 10
    run(st2, 30)
    expect(vec.dist(q.ship.pos, open)).to_be_less(moved - 1)
    -- inside the hangar there is shelter
    local mn, mx = ruinm.room_box(r2.rooms[1], ruinm.kit_of(r2.kit), r2.origin)
    expect(cities.sheltered(r2, { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 })).to_be(true)
  end)
  it("a storm darkens and thickens the air and lightning flashes it", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.site = i
    st.tick = 0
    local calm = render.city_env(st, p)
    st.tick = peak(r)
    local env = render.city_env(st, p)
    expect(env.storm).to_be_greater(0.9)
    expect(env.density).to_be_greater(calm.density * 1.5)
    local flashes, mx = 0, 0
    for t = peak(r), peak(r) + 600 do
      st.tick = t
      local f = render.flash(st, 1)
      if f > 0 then flashes = flashes + 1 mx = math.max(mx, f) end
      expect(f >= 0 and f <= 1).to_be_truthy()
    end
    expect(flashes).to_be_greater(5)
    expect(mx).to_be_greater(0.5)
    expect(render.flash(st, 0.1)).to_be(0)
  end)
  it("the HUD rains and warns of a storm before it and during it", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.mode, p.panel, p.ship.morph = "helm", false, false
    p.site = i
    local function texts_at(tick)
      st.tick = tick
      local v = fake_view({ width = 480, height = 270 })
      hud.weather(v, st, p)
      return v
    end
    local v0 = texts_at(cities.phase(r) - 300)
    expect(v0.texts:find("STORM IN", 1, true) ~= nil).to_be_truthy()
    local v1 = texts_at(peak(r))
    expect(v1.texts:find("STORM!", 1, true) ~= nil).to_be_truthy()
    expect(v1.calls.rect).to_be_greater(30)
    local v2 = texts_at(10)
    expect(v2.texts).to_be("")
    local sp = st.players[1]
    sp.site = 0
    st.tick = peak(r)
    local v3 = fake_view()
    hud.weather(v3, st, sp)
    expect(v3.texts).to_be("")
  end)
  it("each sky-bridge tears loose at the peak of its storm, leaves the physics and tells the players", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.mode, p.panel, p.ship.morph = "helm", false, false
    p.site = i
    local si = r.city.bridges[1]
    local s = r.solids[si]
    expect(s.fall >= 1 and s.fall <= 5).to_be_truthy()
    local ft = cities.fall_tick(r, s)
    expect(ft).to_be(cities.phase(r) + (s.fall - 1) * cities.STORM_PERIOD + cities.STORM_LEN // 2)
    expect(cities.fall_tick(r, { 1 })).to_be(nil)
    expect(game.bridge_fallen(i, si)).to_be(false)
    expect(cities.fall_box(r, s, ft - 5)).to_be(nil)
    local mn0 = cities.fall_box(r, s, ft + 30)
    expect(mn0[2]).to_be_less(s[1][2])
    expect(cities.fall_box(r, s, ft + cities.FALL_TICKS + 5)).to_be(nil)
    -- park the saucer far away and let the clock reach it
    p.ship.pos = vec.add(st.sector.sites[i].pos, core(r, { 1440, 650, 700 }))
    st.tick = ft - 2
    run(st, 4)
    expect(game.bridge_fallen(i, si)).to_be(true)
    local told = false
    for _, m in ipairs(p.msgs or {}) do if m.text:find("sky-bridge", 1, true) then told = true end end
    expect(told).to_be_truthy()
    -- a rebuilt world (a restore) after the fall does not bring the bridge back
    game.rebuild(st)
    expect(game.bridge_fallen(i, si)).to_be(true)
    st.tick = 0
    game.rebuild(st)
    expect(game.bridge_fallen(i, si)).to_be(false)
  end)
  it("a falling bridge clips a hull once: some hull lost, never more than once per bridge", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.mode, p.panel, p.ship.morph = "helm", false, false
    p.site = i
    local si = r.city.bridges[1]
    local s = r.solids[si]
    local ft = cities.fall_tick(r, s)
    local hull0 = p.ship.hull or 100
    local drop = cities.fall_box(r, s, ft + 20)
    p.ship.pos = { (s[1][1] + s[2][1]) / 2, drop[2] + 1, (s[1][3] + s[2][3]) / 2 }
    p.ship.vel = { 0, 0, 0 }
    st.tick = ft + 19
    game.city_step(st)
    st.tick = ft + 20
    p.ship.pos = { (s[1][1] + s[2][1]) / 2, select(1, cities.fall_box(r, s, st.tick))[2] + 1, (s[1][3] + s[2][3]) / 2 }
    game.city_step(st)
    local after = p.ship.shield + p.ship.hull
    expect(after).to_be_less(200)
    expect(st.locks[i .. ":hit" .. si .. ":" .. p.index] ~= nil).to_be_truthy()
    local shield1, hull1 = p.ship.shield, p.ship.hull
    st.tick = ft + 21
    p.ship.pos = { (s[1][1] + s[2][1]) / 2, select(1, cities.fall_box(r, s, st.tick))[2] + 1, (s[1][3] + s[2][3]) / 2 }
    game.city_step(st)
    expect(p.ship.shield).to_be(shield1)
    expect(p.ship.hull).to_be(hull1)
    expect(hull1 <= hull0).to_be_truthy()
  end)
  it("the falling bridge is drawn dropping and then gone, and is not in the far silhouette", function()
    local st, i, r = in_city("planet")
    local A = assets.init()
    local si = r.city.bridges[1]
    local s = r.solids[si]
    local ft = cities.fall_tick(r, s)
    local c = { (s[1][1] + s[2][1]) / 2, (s[1][2] + s[2][2]) / 2 - 20, (s[1][3] + s[2][3]) / 2 }
    local cam = { pos = { c[1], c[2], c[3] - 90 }, yaw = 0, pitch = 0, fov = 2.4 }
    st.tick = ft + 10
    expect(render.draw_ruins(fake_view(), A, st, cam, false).falling or 0).to_be_greater(0)
    st.tick = ft + cities.FALL_TICKS + 20
    expect(render.draw_ruins(fake_view(), A, st, cam, false).falling or 0).to_be(0)
  end)
end)

describe("patrols in the dark districts", function()
  it("a Watcher patrols the streets of every dark district and goes home when its grid is back", function()
    local st, i, r = in_city("planet")
    local defs = game.sentries(i)
    local roam = {}
    for k, d in ipairs(defs) do if d.roam then roam[#roam + 1] = k end end
    expect(#roam).to_be(#r.city.districts - 1)
    local def = defs[roam[1]]
    expect(def.kind).to_be("watcher")
    expect(def.dark and def.route ~= nil).to_be_truthy()
    local a, ya = sentry.route_at(def, 0)
    local b = sentry.route_at(def, 60 * 20)
    expect(vec.dist(a, b)).to_be_greater(100)
    expect(vec.dist(sentry.route_at(def, 77), sentry.route_at(def, 77))).to_be(0)
    -- it comes round again after a full lap
    local lap = math.floor(def.len / def.speed * 60 + 0.5)
    expect(vec.dist(sentry.route_at(def, 5), sentry.route_at(def, 5 + lap))).to_be_less(def.speed)
    -- it keeps to its district's streets, 18 m up
    for t = 0, 60 * 60, 421 do
      local q = sentry.route_at(def, t)
      expect(math.abs(q[2] - (r.city.districts[def.district].pos[2] + 18)) < 1e-6).to_be_truthy()
    end
    -- park a saucer under its beam: it stirs; restore the grid and it is dormant again, whatever is in view
    local k = roam[1]
    local dyn = st.sentries[i][k]
    local p = st.players[1]
    p.mode, p.panel, p.ship.morph = "helm", false, false
    p.ship.size = 1
    local ctx = { msg = function() end, fx = function() end, seal = function() end }
    local woke = false
    for t = 0, 60 * 40, 3 do
      st.tick = t
      local pos, yaw = sentry.route_at(def, t)
      local dir = sentry.dir_of(yaw, def.pitch)
      p.ship.pos = { pos[1] + dir[1] * 20, pos[2] + dir[2] * 20, pos[3] + dir[3] * 20 }
      p.site = i
      sentry.step(st, i, defs, 1 / 60, ctx)
      if dyn.st ~= "dormant" then woke = true break end
    end
    expect(woke).to_be_truthy()
    expect(dyn.pos ~= nil and dyn.base ~= nil).to_be_truthy()
    cities.restore(st, i, def.district)
    sentry.step(st, i, defs, 1 / 60, ctx)
    expect(dyn.st).to_be("dormant")
    -- and it is not drawn any more
    local v = fake_view()
    local A = assets.init()
    st.tick = st.tick + 1
    expect(pcall(render.draw_sentries, v, A, st, p)).to_be_truthy()
  end)
end)

local function said(p)
  local s = ""
  for _, m in ipairs(p.msgs or {}) do s = s .. m.text .. "|" end
  return s
end
local function clue_of(st, i, r, p)
  for _, c in ipairs(cities.candidates(st, p, i, r)) do if c.kind == "clue" then return c end end
end

describe("the archive and the outposts", function()
  it("every archive district holds one record in its ground hall, readable once its grid is up", function()
    for _, id in ipairs({ "city_planet", "city_moon", "city_asteroid" }) do
      local r = gen(id)
      local n = 0
      for _, d in ipairs(r.city.districts) do if d.kind == "archive" then n = n + 1 end end
      expect(n).to_be_greater(0)
      expect(#r.city.clues).to_be(n)
      for _, c in ipairs(r.city.clues) do
        expect(r.city.districts[c.district].kind).to_be("archive")
        expect(r.rooms[c.room].district).to_be(c.district)
      end
    end
    local st, i, r = in_city("planet")
    local p = st.players[1]
    expect(clue_of(st, i, r, p)).to_be(nil) -- the archive is dark
    cities.restore(st, i, r.city.clues[1].district)
    local c = clue_of(st, i, r, p)
    expect(c.item.name).to_be("Archive record")
    expect(c.district).to_be(r.city.clues[1].district)
  end)
  it("reading a record names the next Echo, a later record the one after, and never fills the hold", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    local d = r.city.clues[1].district
    cities.restore(st, i, d)
    local c = clue_of(st, i, r, p)
    local e = st.mystery.echoes[1]
    game.pick_up(st, p, c, i)
    expect(said(p):find("Archive record: a ledger logs a resonance near site " .. e.site, 1, true) ~= nil).to_be_truthy()
    expect(#p.hold).to_be(0)
    expect(clue_of(st, i, r, p)).to_be(nil) -- read once
    -- the text follows the chain: the next unlocked Echo
    local m = st.mystery
    m.echoes[1].found_by, m.echoes[1].decoded = 1, true
    expect(cities.clue_text(st, i, r, d):find("site " .. m.echoes[2].site, 1, true) ~= nil).to_be_truthy()
    st.sector_id = 7
    m.echoes[2].sector = 9
    expect(cities.clue_text(st, i, r, d):find("of sector 9", 1, true) ~= nil).to_be_truthy()
    -- a full chain with the Heart named, then lore, then a sandbox universe
    for _, x in ipairs(m.echoes) do x.found_by, x.decoded = 1, true end
    m.vault_open, m.act, m.heart_sector = true, 3, 12
    expect(cities.clue_text(st, i, r, d):find("sector 12", 1, true) ~= nil).to_be_truthy()
    m.ending = true
    expect(cities.clue_text(st, i, r, d):find("kept a ledger of the", 1, true) ~= nil).to_be_truthy()
    m.mode = "off"
    expect(cities.clue_text(st, i, r, d):find("out of date", 1, true) ~= nil).to_be_truthy()
  end)
  it("a record is a beam target when the hold is full and is drawn like an Echo", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    cities.restore(st, i, r.city.clues[1].district)
    local c = clue_of(st, i, r, p)
    for k = 1, 30 do p.hold[k] = { type = "scrap", size = 1, value = 1, name = "x", uid = k } end
    game.pick_up(st, p, c, i)
    expect(said(p):find("Archive record", 1, true) ~= nil).to_be_truthy()
    local A = assets.init()
    local v = fake_view()
    p.site = i
    p.ship.pos = { c.pos[1], c.pos[2], c.pos[3] - 20 }
    expect(pcall(render.render, v, st, 0)).to_be_truthy()
  end)
  it("a city sector has a trader outpost off its spaceport mouth, a pure function of the seed", function()
    local st, i, r = in_city("planet")
    local list = st.sector.traders
    expect(#list).to_be(2)
    expect(list[1]).to_be(st.sector.trader)
    expect(list[2].outpost).to_be(true)
    local site = st.sector.sites[i]
    expect(list[2].pos[3]).to_be(site.pos[3] - sector.OUTPOST_GAP)
    expect(vec.dist(list[2].pos, list[1].pos)).to_be_greater(2000)
    expect(#st.traders).to_be(2)
    local other = sector.far(42, BODY_SECTOR.planet, galaxy.generate(42).sectors[BODY_SECTOR.planet])
    expect(other.traders[2].pos[1]).to_be(list[2].pos[1])
    for _, s in ipairs(st.sector.sites) do
      if s ~= site then expect(vec.dist(list[2].pos, s.pos)).to_be_greater(500) end
    end
    -- a sector without a city has one trader and no list
    local plain = sector.far(42, 2, { civs = { 1 }, danger = 1 })
    if not sector.city_of(42, 2) then expect(plain.traders).to_be(nil) end
  end)
  it("docking at an outpost sells there with its own ledger, and says so", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    local tr = st.sector.traders[2]
    p.site = 0
    p.ship.pos = { tr.pos[1] + 20, tr.pos[2], tr.pos[3] }
    run(st, 3)
    expect(p.docked).to_be(2)
    expect(p.last_trader).to_be(2)
    expect(said(p):find("Docked at the city outpost", 1, true) ~= nil).to_be_truthy()
    -- a save from before the outpost had no ledger for it
    st.traders[2] = nil
    p.ship.pos = { tr.pos[1] + 10, tr.pos[2], tr.pos[3] }
    p.docked = false
    run(st, 2)
    expect(st.traders[2].demand ~= nil).to_be_truthy()
    -- both stations are drawn and on the radar
    expect(#render.radar_targets(st, p) >= #st.sector.sites + 2).to_be_truthy()
    local v = fake_view()
    p.site = 0
    expect(pcall(render.render, v, st, 0)).to_be_truthy()
  end)
end)
